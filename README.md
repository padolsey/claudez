# claudez (Claude Zones)

A tool for spinning up isolated, persistent **Claude Code** development environments on your local machine or remote server.

**What's a "zone"?** A zone is an isolated Docker container running Claude Code with a pre-scaffolded Next.js 15 project, dedicated resources (3-5GB RAM), and automatic subdomain routing. Think of it as a disposable workspace where Claude can build without touching your main system.

## Why this exists

I wanted to prototype rapidly with Claude Code without worrying about:
- **Blast radius** - Claude accessing my entire filesystem
- **Context pollution** - Claude seeing all my projects at once
- **Resource leaks** - Orphaned processes, ports, and node_modules everywhere
- **Port conflicts** - Multiple projects fighting for :3000
- **Dependency conflicts** - Different Node versions, global packages colliding

This tool creates lightweight zones where Claude can work safely and cleanly. Each zone gets:
- **Isolated environment** with automatic HTTP routing via subdomains
- **Resource limits** (3GB RAM, 1 CPU core - prevents runaway builds)
- **Persistent tmux sessions** (survives SSH disconnects)
- **Pre-scaffolded Next.js project** ready to modify
- **Clean lifecycle management** (create, stop, start, destroy)

Think of it as "containerized rapid prototyping" - spin up a zone, let Claude build in it, iterate fast, and clean up when done.

## Prerequisites

1. **Docker** installed and running
2. **Traefik** reverse proxy (see setup below)
3. **Anthropic API key** ([get one here](https://console.anthropic.com/))

## Quick Start

**TL;DR for local development:**
```bash
# 1. Install Docker, then:
git clone https://github.com/padolsey/claudez.git && cd claudez
./install.sh
./setup-traefik.sh

# 2. Set API key (pick one):
export ANTHROPIC_API_KEY="sk-ant-..."        # Option A: env var
echo "sk-ant-..." > ~/.config/claudez/anthropic_key  # Option B: file

# 3. Create and enter a zone:
claudez myapp  # Creates and enters the zone (shorthand for 'spawn')
tclaude        # Starts Claude inside the zone (persistent tmux session)
```

### Detailed Setup Instructions

Choose your deployment mode:

<details>
<summary><strong>🖥️  Local Mode (Laptop/Workstation)</strong> - Click to expand</summary>

### Local Setup (5 minutes)

Perfect for local development on macOS/Linux. Uses `localhost` with no SSL setup required.

#### 1. Install Docker

**macOS:**
```bash
# Install Docker Desktop
# Download from: https://docker.com/products/docker-desktop
# Or via Homebrew:
brew install --cask docker
```

**Linux:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

#### 2. Clone and install claudez

```bash
cd ~
git clone https://github.com/padolsey/claudez.git
cd claudez
./install.sh
```

#### 3. Set up Traefik

```bash
./setup-traefik.sh
# Auto-detects local mode and finds available port (tries 8080 first)
# If port 8080 is in use, automatically selects next available port
```

#### 4. Store your Anthropic API key

See [API Key Setup](#api-key-setup) below for all options.

#### 5. Create your first zone

```bash
claudez create myapp

# You'll see:
# ✅ Sandbox ready
#    PROD:    http://myapp.localhost:8080
#    DEV:     http://dev-myapp.localhost:8080
#    VANILLA: http://vanilla-myapp.localhost:8080

# Enter the zone
claudez enter myapp

# Inside container, start Claude:
tclaude
```

Open `http://vanilla-myapp.localhost:8080` to verify routing works.

</details>

<details>
<summary><strong>☁️  Remote Mode (VPS/Server)</strong> - Click to expand</summary>

### Remote Setup (10 minutes)

Perfect for deployment on a VPS with a real domain. Uses HTTPS with automatic Let's Encrypt certificates.

#### Prerequisites
- A domain name (e.g., `grok.foo`)
- DNS configured with wildcard: `*.yourdomain.com` → your server IP
- Port 80 and 443 open in firewall

#### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

#### 2. Clone and install claudez

```bash
cd ~
git clone https://github.com/padolsey/claudez.git
cd claudez
./install.sh
```

#### 3. Configure your domain

```bash
echo "DOMAIN_BASE=yourdomain.com" > ~/.claudezrc
```

That's it! This single line automatically enables:
- HTTPS with Let's Encrypt
- Port 443 routing
- SSL certificate auto-renewal

#### 4. Set up Traefik

```bash
./setup-traefik.sh
# Auto-detects remote mode and configures HTTPS with Let's Encrypt
# You'll be prompted for an email for certificate notifications
```

#### 5. Store your Anthropic API key

See [API Key Setup](#api-key-setup) below for all options.

#### 6. Create your first zone

```bash
claudez create myapp

# You'll see:
# ✅ Sandbox ready
#    PROD:    https://myapp.yourdomain.com
#    DEV:     https://dev-myapp.yourdomain.com
#    VANILLA: https://vanilla-myapp.yourdomain.com

# Enter the zone
claudez enter myapp

# Inside container, start Claude:
tclaude
```

Open `https://vanilla-myapp.yourdomain.com` to verify routing and SSL work.

</details>

## API Key Setup

claudez needs your Anthropic API key to run Claude Code inside zones. Choose one method:

**Option 1: Environment variable (recommended)**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# Add to ~/.bashrc or ~/.zshrc to persist
```

**Option 2: Config file (XDG standard location)**
```bash
mkdir -p ~/.config/claudez
echo "sk-ant-..." > ~/.config/claudez/anthropic_key
chmod 600 ~/.config/claudez/anthropic_key
```

**Option 3: Custom location**
```bash
# Set KEY_FILE in ~/.claudezrc to point anywhere
echo 'KEY_FILE=/path/to/your/key' >> ~/.claudezrc
```

The key is read once during `claudez create` and injected into the zone's `.env` file. Priority: env var → config file → custom path.

## How it works

1. You run `claudez create myapp` (or `cz create myapp`)
2. The tool detects your mode based on `DOMAIN_BASE`:
   - Contains `localhost` → **Local mode** (HTTP, no SSL)
   - Real domain → **Remote mode** (HTTPS, Let's Encrypt)
3. Generates a Docker container with:
   - Node.js 20, Claude Code, tmux, pm2, pnpm
   - **Pre-scaffolded Next.js 15 project** (App Router, TypeScript, Tailwind CSS v4)
   - All dependencies cached for fast startup
4. Traefik detects container labels and creates routes:
   - **Local**: `http://myapp.localhost:8080` → port 3000 (prod)
   - **Remote**: `https://myapp.yourdomain.com` → port 3000 (prod)
   - Plus dev and vanilla variants for both modes
5. You enter the zone and run `tclaude` to start Claude in a persistent tmux session
6. Inner Claude finds a ready-to-use Next.js project in `/workspace/app/`

## Quick Reference

**Creating zones:**
```bash
claudez myapp                     # Shorthand: create + enter (spawn)
claudez create myapp              # Create only (3GB memory)
claudez create bigapp --large     # Large (5GB memory)
claudez spawn myapp               # Create + enter (explicit)
# Short alias works too:
cz myapp
```

**Daily workflow:**
```bash
claudez enter myapp               # Attach to zone (on your machine)
tclaude                           # Start/reattach Claude in tmux (inside container)
claudez ls                        # List all zones (on your machine)
claudez stop myapp                # Stop when idle (on your machine)
```

**Available inside zones:**
- `claude` - Run Claude directly (dies on disconnect)
- `tclaude` - Run Claude in persistent tmux session (survives disconnects, auto-logs to `/workspace/.claude-logs/`)

**Access your apps:**
Each zone gets three URLs (use whichever you need):
- **Production** (`myapp`) - port 3000: Built Next.js app (`pnpm build && pnpm start`)
- **Development** (`dev-myapp`) - port 8000: Hot-reload dev server (`pnpm dev`)
- **Vanilla** (`vanilla-myapp`) - port 9000: Static HTML test page (verify routing works)

**Local mode**: `http://myapp.localhost:8080`, `http://dev-myapp.localhost:8080`, `http://vanilla-myapp.localhost:8080`

**Remote mode**: `https://myapp.yourdomain.com`, `https://dev-myapp.yourdomain.com`, `https://vanilla-myapp.yourdomain.com`

## Available commands

**All `claudez` commands run on your host machine** (outside containers). Commands like `tclaude`, `claude`, and `pm2` run inside zones after you `claudez enter`.

### Management
- `claudez create <name> [--verify] [--large]` — Build and start a new zone
- `claudez spawn <name> [--verify] [--large]` — Create and enter in one command
- `claudez ls` — List all zones with status
- `claudez rm <name> [--force]` — Permanently delete a zone
- `claudez reset <name>` — Remove and recreate from scratch

### Lifecycle
- `claudez start <name>` — Start a stopped container
- `claudez stop <name>` — Stop a running container
- `claudez restart <name>` — Restart a container

### Development
- `claudez enter <name>` — Open shell and attach to Claude session (tmux)
- `claudez shell <name>` — Open normal shell without starting Claude
- `claudez exec <name> <cmd>` — Run a command in the container
- `claudez logs <name> [options]` — View container logs

### Monitoring
- `claudez status <name>` — Health checks (container + routing)

## Resource Limits & Security

Each zone container has:
- **3GB RAM limit** (standard) or **5GB** (with `--large` flag)
- **1.5GB RAM guaranteed** (memory reservation)
- **1 CPU core** - prevents CPU hogging
- **Dropped capabilities** - minimal privileges
- **Persistent workspace** - `/workspace` survives restarts

Inner Claude is pre-configured with guidance in `/workspace/CLAUDE.md` explaining:
- Pre-scaffolded Next.js 15 project ready to use
- Environment constraints and best practices
- How to use pm2 correctly (never run `npm start` directly!)
- Persistence boundaries

## Sessions persist

- The container provides **tmux** for persistent sessions
- Use `tclaude` to run Claude in tmux (wraps: `tmux new-session -A -s claude 'claude'`)
- If your SSH/terminal drops, the tmux session **keeps running**
- Re-enter the container and run `tclaude` again to reattach instantly

## Recommended Workflows

### Daily Development

**Starting work:**
```bash
# Attach to existing zone
claudez enter myproject

# Inside container, start/attach to Claude
tclaude
```

If your connection drops, just run `claudez enter myproject` and `tclaude` again - Claude is still running.

**Managing multiple zones:**
```bash
# See what's running
claudez ls

# Stop idle zones
claudez stop oldproject

# Start when needed
claudez start oldproject
```

### When builds fail with OOM

```bash
# Recreate with --large flag (5GB instead of 3GB)
claudez rm myproject
claudez create myproject --large
```

## Common commands inside the zone

**Run these AFTER `claudez enter <name>`** (inside the container):

- Dev Next.js:
  ```bash
  pm2 start "pnpm dev -- --hostname 0.0.0.0 --port 8000" --name nextjs-dev --cwd /workspace/app
  ```

- Prod Next.js:
  ```bash
  pnpm build --prefix /workspace/app &&
  pm2 start "pnpm start" --name nextjs-prod --cwd /workspace/app
  ```

## Troubleshooting

### Container exited unexpectedly
Inner Claude probably ran `npm start` in the foreground, killing the main process. The container auto-restarts. Use `claudez enter <name>` to reattach.

### Traefik route not working
```bash
# Check Traefik is running
docker ps | grep traefik

# Check routing
claudez status myapp

# View Traefik logs
docker logs traefik

# Verify network
docker network inspect claudez
```

### Disk space warnings
```bash
claudez exec myapp "du -sh /workspace/* | sort -rh | head -10"
claudez exec myapp "rm -rf /workspace/app/node_modules"
claudez exec myapp "rm -rf /workspace/app/.next"
```

### Memory/CPU issues
```bash
# Real-time stats
docker stats myapp-app

# If OOM killed, recreate with --large
claudez rm myapp
claudez create myapp --large
```

### Port conflicts

**setup-traefik.sh automatically finds an available port** (tries 8080, 8081, 8082... up to 8099).

If you need a specific port:
```bash
# Set your preferred port
echo "DOMAIN_BASE=localhost:9000" > ~/.claudezrc
./setup-traefik.sh  # Will use 9000 or next available

# Find what's using a port
lsof -ti:8080
```

## Deployment Modes

claudez automatically detects which mode to use based on your `DOMAIN_BASE` setting:

| Setting | Mode | Protocol | Port | SSL |
|---------|------|----------|------|-----|
| `localhost:8080` (default) | Local | HTTP | 8080 | No |
| `yourdomain.com` | Remote | HTTPS | 443 | Yes (Let's Encrypt) |

**To switch modes**: Just set `DOMAIN_BASE` in `~/.claudezrc`

```bash
# Remote mode
echo "DOMAIN_BASE=grok.foo" > ~/.claudezrc

# Back to local mode
echo "DOMAIN_BASE=localhost:8080" > ~/.claudezrc
```

Everything else (SSL config, Traefik entrypoints, certificate resolvers) is automatically configured.

## Customize

- **Change deployment mode**: Set `DOMAIN_BASE` in `~/.claudezrc`
- **Change zones directory**: Set `APPS_DIR` in `~/.claudezrc` (default: `~/.local/share/claudez/zones`)
- **Change Node version**: Edit `conf/defaults.env` (`NODE_VERSION=20`)
- **Change network name**: Set `TRAEFIK_NETWORK` in `~/.claudezrc`
- **Customize Claude guidance**: Edit `templates/CLAUDE.md.tmpl`

## Cleanup

**Delete an app permanently:**
```bash
claudez rm myapp
```

**Reset an app (delete and recreate):**
```bash
claudez reset myapp
```

## Project Structure

- `bin/` — thin, single-purpose commands (one file per subcommand)
- `lib/` — shared helpers (env loading, docker utilities, template rendering)
- `templates/` — all generated files (Dockerfile, compose, etc.)
- `conf/defaults.env` — repo defaults; override in `~/.claudezrc`
- `docs/` — detailed setup guides

## Ops notes

- **Use tmux** inside containers for persistent sessions
- **Never commit secrets** - `.env` files are gitignored
- **Health checks**: `claudez status <name>` validates container + routing
- **Shell access**:
  - `claudez enter <name>` - attach to Claude in tmux
  - `claudez shell <name>` - normal bash without Claude
- **Debug**: `claudez logs <name> -f` for container logs

## FAQ

**Q: How do I switch between local and remote mode?**
A: Just set `DOMAIN_BASE` in `~/.claudezrc`. If it contains `localhost`, you're in local mode. Otherwise, remote mode with HTTPS.

**Q: Can I use a custom port for local mode?**
A: Yes! Set `DOMAIN_BASE=localhost:9000` (or any port) and run `./setup-traefik.sh` to reconfigure.

**Q: Do I need to reconfigure anything when switching modes?**
A: Just run `./setup-traefik.sh` after changing `DOMAIN_BASE`. Everything else auto-configures.

**Q: Can I run multiple zones at once?**
A: Yes! Each gets its own subdomain: `app1.localhost:8080`, `app2.localhost:8080`, etc.

**Q: What if I want to use Python/Go/Rust instead of Node?**
A: Edit `templates/Dockerfile.tmpl` to install your runtime. Or fork for multi-runtime support.

**Q: Can I import an existing project?**
A: Yes - create a zone, then `docker cp` your project into `~/.local/share/claudez/zones/<name>/workspace/app/`

## Contributing

This is a personal tool, but contributions welcome:
1. Fork the repo
2. Create a feature branch
3. Test thoroughly
4. Submit a PR

## License

MIT
