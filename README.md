# claudez (Claude Zones)

A tool for spinning up isolated, persistent **Claude Code** development environments on your local machine.

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

## Quick Reference

**Creating zones:**
```bash
claudez create myapp              # Standard (3GB memory)
claudez create bigapp --large     # Large (5GB memory)
claudez spawn myapp               # Create + enter in one command
# Or use the short alias:
cz create myapp
```

**Daily workflow:**
```bash
claudez enter myapp               # Attach to zone
cc                                # Start Claude (inside container)
claudez ls                        # List all zones
claudez stop myapp                # Stop when idle
```

**Access your apps:**
- Production: `http://myapp.localhost:8080`
- Development: `http://dev-myapp.localhost:8080`
- Vanilla demo: `http://vanilla-myapp.localhost:8080`

## Prerequisites

1. **Docker** installed and running
2. **Traefik** reverse proxy (see setup below)
3. **Anthropic API key** ([get one here](https://console.anthropic.com/))

## Quick Start (5 minutes)

### 1. Install Docker

**macOS:**
```bash
# Install Docker Desktop from https://docker.com/products/docker-desktop
# Or via Homebrew:
brew install --cask docker
```

**Linux:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Set up Traefik (local reverse proxy)

```bash
# Create network
docker network create local_dev

# Create Traefik directory
mkdir -p ~/provision-traefik
cd ~/provision-traefik

# Create config
cat > traefik.yml <<'EOF'
global:
  checkNewVersion: false
  sendAnonymousUsage: false

entryPoints:
  web:
    address: ":8080"

providers:
  docker:
    network: local_dev
    exposedByDefault: false

api:
  dashboard: true
  insecure: true
EOF

# Create docker-compose file
cat > docker-compose.yml <<'EOF'
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik-local
    restart: unless-stopped
    ports:
      - "8080:8080"
    networks:
      - local_dev
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro

networks:
  local_dev:
    external: true
EOF

# Start Traefik
docker compose up -d
```

**See detailed Traefik setup instructions:** [docs/SETUP_LOCAL_TRAEFIK.md](docs/SETUP_LOCAL_TRAEFIK.md)

### 3. Store your Anthropic API key

```bash
# Create key file (use default location)
sudo mkdir -p /root
sudo install -D -m 600 /dev/stdin /root/ANTHROPIC_KEY.txt
# Paste your key, then press Ctrl+D

# Or use custom location in ~/.provisionrc
mkdir -p ~/.config/provision
echo "your-api-key-here" > ~/.config/provision/anthropic_key
chmod 600 ~/.config/provision/anthropic_key
```

### 4. Clone and set up claudez

```bash
cd ~
git clone https://github.com/padolsey/claudez.git
cd claudez

# Run the installer:
./install.sh

# This will:
# - Create symlinks in /usr/local/bin for both 'claudez' and 'cz'
# - Make commands globally available
```

### 5. Create your first zone

```bash
claudez create myapp
# Or: cz create myapp

# You'll see:
# ✅ Zone ready
#    PROD:    http://myapp.localhost:8080
#    DEV:     http://dev-myapp.localhost:8080
#    VANILLA: http://vanilla-myapp.localhost:8080

# Enter the zone
claudez enter myapp

# Inside container, start Claude:
cc
```

Open `http://vanilla-myapp.localhost:8080` to verify routing works.

## How it works

1. You run `claudez create myapp` (or `cz create myapp`)
2. The tool generates a Docker container with:
   - Node.js 20, Claude Code, tmux, pm2, pnpm
   - **Pre-scaffolded Next.js 15 project** (App Router, TypeScript, Tailwind CSS v4)
   - All dependencies cached for fast startup
3. Traefik detects container labels and creates routes:
   - `http://myapp.localhost:8080` → port 3000 (prod)
   - `http://dev-myapp.localhost:8080` → port 8000 (dev)
   - `http://vanilla-myapp.localhost:8080` → port 9000 (demo)
4. Modern browsers automatically resolve `*.localhost` to `127.0.0.1` (zero DNS config!)
5. You enter the zone and run `cc` to start Claude in a persistent tmux session
6. Inner Claude finds a ready-to-use Next.js project in `/workspace/app/`

## Available commands

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

- The container runs **tmux** and provides `cc` which runs: `tmux new-session -A -s claude 'claude'`
- If your SSH/terminal drops, the tmux session **keeps running**
- Re-enter the container and run `cc` again to reattach instantly

## Recommended Workflows

### Daily Development

**Starting work:**
```bash
# Attach to existing zone
claudez enter myproject

# Inside container, attach to Claude
cc
```

If your connection drops, just run `claudez enter myproject` again - Claude is still running.

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
docker ps | grep traefik-local

# Check routing
claudez status myapp

# View Traefik logs
docker logs traefik-local

# Verify network
docker network inspect local_dev
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

### Port 8080 already in use
```bash
# Find what's using it
lsof -ti:8080

# Change Traefik port in ~/provision-traefik/
# Edit both traefik.yml and docker-compose.yml
```

## Customize

- Change Node version: Edit `conf/defaults.env` (`NODE_VERSION=20`)
- Change network/domain: Edit `TRAEFIK_NETWORK` and `DOMAIN_BASE` in `conf/defaults.env`
- Customize Claude guidance: Edit `templates/CLAUDE.md.tmpl`

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

## Local Development Mode

This tool is designed for **local prototyping** on your MacBook/Linux machine.

**Benefits:**
- No domain/DNS setup required
- No SSL certificates needed
- Faster iteration (no network latency)
- Safe experimentation (isolated from production systems)
- Clean resource management (no leaked processes/ports)

**Access pattern:**
- Apps accessible at `http://<name>.localhost:8080`
- Uses built-in browser resolution (Chrome, Firefox, Safari all support `*.localhost`)
- All traffic stays on your machine (127.0.0.1)

**Differences from remote deployment:**
- Remote version would use real domains + Let's Encrypt SSL
- This version uses HTTP + localhost (simpler, zero config)
- Same isolation, resource limits, and lifecycle management

## FAQ

**Q: Can I use a custom domain instead of localhost?**
A: Yes, but you'll need to set up DNS and SSL. The remote deployment mode (not covered here) supports this.

**Q: Why port 8080 instead of 80?**
A: Port 80 requires root. Port 8080 works without sudo and is standard for local dev.

**Q: Can I run multiple zones at once?**
A: Yes! Each gets its own subdomain: `app1.localhost:8080`, `app2.localhost:8080`, etc.

**Q: What if I want to use Python/Go/Rust instead of Node?**
A: Edit `templates/Dockerfile.tmpl` to install your runtime. Or fork for multi-runtime support.

**Q: Can I import an existing project?**
A: Yes - create a zone, then `docker cp` your project into `/opt/apps/<name>/workspace/app/`

## Contributing

This is a personal tool, but contributions welcome:
1. Fork the repo
2. Create a feature branch
3. Test thoroughly
4. Submit a PR

## License

MIT
