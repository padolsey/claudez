# Claude Sandbox Provisioner

A tool for spinning up isolated, persistent **Claude Code** development environments with automatic HTTPS routing.

## Why this exists

I wanted to ship small tools and apps from my iPad—no local IDE, no fussing with Netlify/GitHub integrations, no switching to my laptop. Just SSH in, tell Claude what to build, and have it live at `https://myapp.yourdomain.com` immediately.

This is a personal deployment system optimized for that workflow: provision a sandbox, let Claude build in it autonomously, iterate rapidly, and share the URL. You focus on architecture and product decisions; Claude handles implementation.

Each sandbox gets:
- Auto-configured HTTPS via Traefik + Let's Encrypt
- Isolated resources (won't crash each other or the host)
- Security sandboxing (dropped capabilities, resource limits—reduces risk of AI doing something destructive to your server)
- Persistent tmux sessions (survives SSH disconnects)
- Pre-scaffolded Next.js project ready to modify
- Git access to private repos (your SSH keys work transparently)

Think Heroku-style deployment, but local and designed for rapid prototyping with Claude as your hands-off junior dev. Sandboxes keep experimentation safe and iteration fast. No code editing required unless you want to.

## Quick Reference

**Creating sandboxes:**
```bash
provision create myapp              # Standard (3GB memory)
provision create bigapp --large     # Large (5GB memory)
provision spawn myapp               # Create + enter in one command
```

**Daily workflow:**
```bash
provision enter myapp               # Attach to sandbox
cc                                  # Start Claude (inside container)
provision ls                        # List all sandboxes
provision stop myapp                # Stop when idle
```

**Monitoring:**
- Status page: `https://status.<your-domain>` (shows memory, CPU, disk, processes)
- Check health: `provision status myapp`
- View logs: `provision logs myapp -f`

**Capacity:**
- **Max sandboxes:** 12 standard (3GB) or 8 large (5GB)
- **Current usage:** Check status page "Commit Limit" metric
- **When >75%:** Stop idle sandboxes or remove unused ones

**Memory issues:**
- If build OOMs: Recreate with `--large` flag
- Check memory logs: `provision exec myapp "cat /workspace/.debug/memory.log"`
- Monitor status page: Yellow = warning, Red = critical

## Prerequisites

Before using this tool, your server needs:

1. **Docker** and **docker compose** installed
2. **Traefik** reverse proxy running with:
   - A Docker network named `edge` (or customize `TRAEFIK_NETWORK` in config)
   - Let's Encrypt configured for automatic SSL
   - Listening for container labels to route traffic
3. **DNS** wildcard record pointing `*.<your-domain>` to your server
4. **Anthropic API key** stored securely on the host

If you don't have Traefik set up yet, you'll need to deploy it first as the reverse proxy layer that handles all HTTPS routing and certificates.

## Fresh Ubuntu Server Setup

Starting with a clean **Ubuntu 22.04+** server? Run this to install everything:

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 2. Create Traefik network
docker network create edge

# 3. Deploy Traefik with Let's Encrypt
mkdir -p ~/traefik
cat > ~/traefik/docker-compose.yml <<'EOF'
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    networks:
      - edge
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
      - ./traefik.yml:/traefik.yml:ro
    environment:
      - TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL=your@email.com

networks:
  edge:
    external: true
EOF

cat > ~/traefik/traefik.yml <<'EOF'
global:
  checkNewVersion: false
  sendAnonymousUsage: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    network: edge
    exposedByDefault: false

certificatesResolvers:
  letsencrypt:
    acme:
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
EOF

# Edit email in docker-compose.yml
nano ~/traefik/docker-compose.yml  # Change your@email.com

# Start Traefik
cd ~/traefik && docker compose up -d

# 4. Configure DNS
# Point *.yourdomain.com to your server's IP (A record in your DNS provider)
# Verify with: dig vanilla-test.yourdomain.com

# 5. Store your Anthropic API key
sudo install -D -m 600 /dev/stdin /root/ANTHROPIC_KEY.txt
# Paste your key, then press Ctrl+D

# 6. Clone this tool
cd ~
git clone git@github.com:padolsey/provision.git

# 7. (Optional) Create global alias
echo "alias provision='~/provision/bin/provision'" >> ~/.bashrc
source ~/.bashrc
# Or for system-wide: sudo ln -s ~/provision/bin/provision /usr/local/bin/provision

# 8. Configure your domain
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=yourdomain.com
EOF
# Edit with your actual domain
nano ~/.provisionrc

# 9. Set up monitoring and protections (one-time)
~/provision/bin/provision setup-status-page
~/provision/bin/provision protect-services
(crontab -l 2>/dev/null; echo "@reboot ~/provision/bin/provision protect-services") | crontab -

# 10. Create your first sandbox
~/provision/bin/provision create myapp

# 11. Enter and start Claude
~/provision/bin/provision enter myapp
# Inside: run 'cc' to attach Claude in tmux

# 12. Monitor your sandboxes
# Visit https://status.yourdomain.com (shows memory, CPU, disk, processes)
```

**What you need before starting:**
- Fresh Ubuntu 22.04+ server (Hetzner, DigitalOcean, AWS, etc.)
- Domain name with DNS access
- Anthropic API key ([get one here](https://console.anthropic.com/))
- SSH access to your server

**DNS Setup:**
In your DNS provider (Cloudflare, Route53, etc.), add:
- **A Record**: `*.yourdomain.com` → `your.server.ip.address`

Verify DNS propagation: `dig vanilla-myapp.yourdomain.com` should return your server IP.

## How it works

1. You run `provision create myapp`
2. The tool generates a Docker container with:
   - Node.js 20 (full image with build tools), Claude Code, tmux, pm2, pnpm
   - **Pre-scaffolded Next.js 15 project** (App Router, TypeScript, Tailwind CSS v4)
   - Build tools pre-installed (build-essential, python3, procps) for native module compilation
   - All dependencies cached in Docker image for fast startup
   - SSH access to private repos (host keys mounted read-only)
3. Traefik detects the container labels and creates routes:
   - `https://myapp.example.com` → port 3000 (prod)
   - `https://dev-myapp.example.com` → port 8000 (dev)
   - `https://vanilla-myapp.example.com` → port 9000 (auto-running vanilla app)
4. Let's Encrypt automatically provisions SSL certificates
5. Container startup automatically initializes the Next.js project from cached template (~6 seconds)
6. You enter the sandbox and run `cc` to start Claude in a persistent tmux session
7. Inner Claude finds a ready-to-use Next.js project in `/workspace/app/`

## Quick start

1. **Put your Anthropic key** on the host (default path):

```bash
sudo install -D -m 600 /dev/stdin /root/ANTHROPIC_KEY.txt
# paste your key, Ctrl+D to end
```

Or change `KEY_FILE` in `conf/defaults.env` or `~/.provisionrc`.

2. **Create a sandbox**:

```bash
provision/bin/provision create myapp
```

3. **List your apps** (optional):

```bash
provision/bin/provision ls
```

4. **Enter + start Claude** (tmux auto-attach):

```bash
provision/bin/provision enter myapp
# Inside container, 'cc' attaches to session "claude"
```

If your client drops (Termius/mosh), just re-run the same command to reattach.

**Routes**
- PROD: `https://myapp.<DOMAIN_BASE>` → :3000
- DEV: `https://dev-myapp.<DOMAIN_BASE>` → :8000
- VANILLA: `https://vanilla-myapp.<DOMAIN_BASE>` → :9000 (auto-running)

## Why sessions persist

- The container installs **tmux** and provides `cc` which runs:
  - `tmux new-session -A -s <name> 'claude'`
- If your SSH/mosh/Termius session drops, the tmux session **keeps running**.
- Re-enter the container and run `cc` again to reattach instantly.

## Resource Limits & Security

Each sandbox container has:
- **3GB RAM limit** (standard) or **5GB** (with `--large` flag) - handles Next.js builds
- **1.5GB RAM guaranteed** (memory reservation) - protected from host memory pressure
- **1 CPU core** - prevents CPU hogging
- **PM2 log rotation** - max 10MB per log, 5 files retained, compressed
- **Disk monitoring** - warns at 80% usage on startup
- **Auto-save watchdog** - `pm2 save` runs every 5 minutes
- **Health checks** - vanilla server monitored every 30s
- **Dropped capabilities** - container runs with minimal privileges
- **OOM protection** - sandboxes killed first, system services protected
- **Secrets protection** - comprehensive `.gitignore` prevents accidental commits

**Host-level protections:**
- **16GB swap space** - prevents hard OOM failures
- **Strict memory overcommit** - kernel enforces 40GB allocation limit
- **Sandbox quota** - max 12 sandboxes (prevents overprovisioning)
- **Status page** - real-time monitoring at `https://status.<your-domain>`

Inner Claude is pre-configured with guidance in `/workspace/CLAUDE.md` explaining:
- **Pre-scaffolded Next.js 15 project** ready to use in `/workspace/app/`
- Environment constraints and best practices
- How to use pm2 correctly (never run `npm start` directly!)
- Persistence boundaries (/workspace vs ephemeral)
- Security reminders (don't log API keys, be mindful of costs)
- Git access to private repos (SSH keys and tools pre-configured)

## Skipping Claude onboarding **every time**

On boot, the container:
- Reads `ANTHROPIC_API_KEY` from `.env`
- Writes `~/.claude.json` with:
  - `hasCompletedOnboarding: true`
  - your API key tail in `customApiKeyResponses.approved`
- Result: Claude starts immediately, uses your key, and never pesters you.

**Optional persistence:**
We symlink `/home/appuser/.claude.json` → `/workspace/.claude/claude.json`.
If you want sticky preferences across rebuilds, keep that file in your bind mount.

## Available commands

### Management
- `provision create <name> [--verify] [--large]` — Build and start a new sandbox
  - `--verify`: Wait for Traefik routing and verify connectivity
  - `--large`: Use 5GB memory limit for heavy builds (default: 3GB)
- `provision spawn <name> [--verify] [--large]` — Create and enter in one command
- `provision ls` — List all provisioned apps with status and URLs
- `provision rm <name> [--force]` — Permanently delete an app (container, image, and directory)
- `provision reset <name>` — Remove and recreate an app from scratch

### Lifecycle
- `provision start <name>` — Start a stopped container
- `provision stop <name> [--force]` — Stop a running container
- `provision restart <name> [--force]` — Restart a container

### Development
- `provision enter <name>` — Open shell and attach to Claude session (tmux)
- `provision shell <name>` — Open normal shell without starting Claude
- `provision exec <name> <cmd>` — Run a command in the container as appuser
- `provision logs <name> [options]` — View container logs (supports `-f`, `--tail`, etc.)
- `provision status <name>` — Health checks (vanilla server + Traefik routing)

### Monitoring & Operations
- `provision setup-status-page [interval]` — Deploy status page at `https://status.<domain>`
  - Shows host resources, container stats, memory pressure, PM2 processes
  - Optional interval in seconds (default: 30s)
- `provision protect-services` — Protect Docker/Traefik/SSH from OOM killer
  - Run once after setup, then add to crontab for persistence

### Examples
```bash
# Standard sandbox (3GB memory)
provision create myapp
provision enter myapp

# Large sandbox for complex builds (5GB memory)
provision create bigapp --large
provision enter bigapp

# One-command creation + entry
provision spawn myapp

# Quick operations
provision logs myapp -f --tail 50
provision exec myapp "pnpm install"
provision restart myapp --force

# Monitoring
provision ls                    # List all sandboxes
provision status myapp          # Check health
# Visit https://status.grok.foo  # Real-time monitoring dashboard

# Cleanup
provision stop myapp     # Save resources
provision rm myapp       # Delete entirely
```

## Recommended Workflows

### Initial Server Setup

After completing the [Fresh Ubuntu Server Setup](#fresh-ubuntu-server-setup), run these one-time operations:

```bash
# 1. Deploy status page for monitoring
provision setup-status-page

# 2. Protect critical services from OOM
provision protect-services

# 3. Make OOM protection persistent across reboots
(crontab -l 2>/dev/null; echo "@reboot /root/provision/bin/provision protect-services") | crontab -

# 4. Create your first sandbox
provision create myproject
provision enter myproject
```

Visit `https://status.grok.foo` to monitor your sandboxes in real-time.

### Daily Development Workflow

**Starting work:**
```bash
# Attach to existing sandbox (reconnects to Claude session)
provision enter myproject

# Inside container, attach to Claude tmux session
cc
```

If your SSH/network drops, just run `provision enter myproject` again - your Claude session is still running.

**Managing multiple sandboxes:**
```bash
# See what's running
provision ls

# Stop idle sandboxes to save resources
provision stop oldproject

# Start when needed again
provision start oldproject
```

**When builds fail with OOM:**
```bash
# Check status page: https://status.grok.foo
# Look at "Commit Limit" - if >75%, stop some sandboxes

# If build needs more memory, recreate with --large flag
provision rm myproject
provision create myproject --large  # 5GB instead of 3GB
```

### Capacity Management

**Understanding your limits:**
- Host: 30GB RAM + 16GB swap = 40GB commit limit
- Standard sandbox: 3GB limit, 1.5GB reserved
- Large sandbox: 5GB limit, 1.5GB reserved
- **Safe capacity: ~12 sandboxes** (or 8 large)

**When approaching capacity:**
```bash
# Check status page - if "Commit Limit" is yellow/red:

# 1. Stop idle sandboxes
provision ls
provision stop sandbox1 sandbox2 sandbox3

# 2. Or remove unused ones
provision rm old-prototype

# 3. Monitor via status page
# Visit https://status.grok.foo - check host commit % drops
```

**Quota reached error:**
```
Maximum sandboxes (12) reached. Current: 12

This limit protects host stability. To create new sandboxes:
- Stop idle ones: provision stop <name>
- Remove unused ones: provision rm <name>
```

### Debugging Workflow

**Sandbox won't start:**
```bash
provision logs myapp --tail 50
# Look for errors in startup sequence
```

**Claude session crashed:**
```bash
# Check automatic session logs
provision shell myapp
tail -500 /workspace/.claude-logs/claude-*.log
```

**Build hit OOM:**
```bash
# Check if memory pressure was logged
provision exec myapp "cat /workspace/.debug/memory.log"

# If file exists, you hit memory limits
# Recreate with --large flag
```

**Disk space issues:**
```bash
# Check what's using space
provision exec myapp "du -sh /workspace/* | sort -rh | head -10"

# Clean up
provision exec myapp "rm -rf /workspace/app/node_modules"
provision exec myapp "rm -rf /workspace/app/.next"
```

**Status page shows high memory:**
- Yellow (75%): Start planning to stop idle sandboxes
- Red (>90%): Immediately stop sandboxes or risk OOM
- Check which sandbox is using most: Look at individual container cards

### Maintenance Tasks

**Weekly:**
```bash
# Check status page for trends
# Any sandboxes consistently hitting >80% memory? Consider --large

# Clean up stopped containers
provision ls | grep stopped
provision rm unused-sandbox-1 unused-sandbox-2
```

**Monthly:**
```bash
# Check disk usage
df -h /opt/apps

# If >80%, investigate large workspaces
du -sh /opt/apps/* | sort -rh | head -10

# Remove old sandboxes
provision rm old-prototype-from-january
```

**After server reboot:**
```bash
# OOM protection is auto-applied via crontab
# Status page systemd timer auto-starts
# All sandboxes auto-start (restart: unless-stopped)

# Just verify everything came back
provision ls
# Visit https://status.grok.foo
```

## Maintainable structure

- `bin/` — thin, single-purpose commands (one file per subcommand)
- `lib/` — shared helpers (env loading, docker utilities, template rendering)
- `templates/` — all generated files live here; we render with `envsubst`
- `conf/defaults.env` — repo defaults; override in `~/.provisionrc`
- `status-page/` — status monitoring page (HTML, metrics collector)

## Logging & Debugging

Each sandbox has **three automatic logging layers** for emergency recovery and debugging:

### 1. Session Logs (tmux)
- **Location:** `/workspace/.claude-logs/` (inside container)
- **Captures:** Full terminal I/O (both user input and Claude output)
- **Retention:** Persistent, stored in bind mount
- **Access:**
  ```bash
  provision shell myapp
  cat /workspace/.claude-logs/claude-*.log | tail -500
  ```
- **Survives:** Crashes, OOM kills, network disconnects

### 2. Container Logs (Docker)
- **Captures:** Container stdout/stderr
- **Retention:** 5 files × 100MB each (500MB total)
- **Access:**
  ```bash
  provision logs myapp -f --tail 100
  # or directly:
  docker logs myapp-app
  ```

### 3. Memory Pressure Logs
- **Location:** `/workspace/.debug/memory.log` (inside container)
- **Captures:** When available memory drops below 100MB, logs top 15 processes
- **Purpose:** Diagnose what caused OOM kills
- **Access:**
  ```bash
  provision exec myapp "cat /workspace/.debug/memory.log"
  ```

**Recovery workflow:** If a session crashes, check session logs first (most detailed), then memory logs (if OOM suspected), then container logs (for startup issues).

## Troubleshooting

### Container exited unexpectedly
Inner Claude probably ran `npm start` or similar in the foreground, killing the main process. The container auto-restarts. Use `provision enter <name>` to reattach and check `/workspace/CLAUDE.md` for guidance.

### Traefik route not working
- Check DNS: `dig vanilla-myapp.yourdomain.com` should point to your server
- Verify Traefik is running: `docker ps | grep traefik`
- Check routing: `provision status <name>` tests HTTPS connectivity
- View Traefik logs: `docker logs traefik`

### Disk space warnings
Inner Claude installed too many dependencies or build artifacts are large:
```bash
provision exec myapp "du -sh /workspace/* | sort -rh | head -10"
provision exec myapp "npm prune"
provision exec myapp "rm -rf /workspace/app/.next"
```

### Memory/CPU issues
Standard containers are limited to 3GB RAM (5GB with `--large` flag) and 1 CPU.

**Check resource usage:**
```bash
# Real-time stats
docker stats myapp-app

# Or check status page
# Visit https://status.grok.foo
```

**If OOM killed:**
```bash
# Check memory pressure logs
provision exec myapp "cat /workspace/.debug/memory.log"

# If file exists and shows low memory warnings, you need more RAM
# Recreate with --large flag
provision rm myapp
provision create myapp --large  # 5GB limit
```

**Memory best practices:**
- Standard (3GB): Handles most Next.js apps (up to ~100 pages)
- Large (5GB): For complex builds with heavy dependencies
- Check status page regularly - if a sandbox consistently uses >80%, consider --large

### PM2 processes not persisting
Inner Claude forgot to run `pm2 save`. The watchdog runs it every 5 minutes, but manual save is safer:
```bash
provision exec myapp "pm2 save"
```

### Session crashed or lost work
Check the automatic session logs to see what happened before the crash:
```bash
provision shell myapp
tail -500 /workspace/.claude-logs/claude-*.log
```

## Ops notes (strong opinions)

- **Use mosh** from iPad (Termius supports it) **and** tmux in-container.
  Mosh handles flaky networks; tmux guarantees Claude survives client death.
- **Secrets**: Prefer Docker secrets or a root-only `:ro` bind mount. Never commit keys.
- **Health checks**: `provision status <name>` validates vanilla + Traefik routing.
- **Shell access**: Use `provision shell <name>` for normal bash without Claude, or `provision enter <name>` to attach Claude in tmux.
- **Debug**:
  - `provision logs <name> -f` to follow container logs (pm2 is quiet for vanilla, by design)
  - `provision enter <name>` to open a shell and run `cc` to attach Claude
  - Inside tmux: `Ctrl-b d` to detach without killing Claude
  - Check disk usage: `provision exec <name> "/usr/local/bin/check-disk.sh"`

## Common commands inside the sandbox

- Dev Next.js:
  ```bash
  pm2 start "npm run dev -- --hostname 0.0.0.0 --port 8000" --name nextjs-dev --cwd /workspace/app
  ```

- Prod Next.js:
  ```bash
  npm run build --prefix /workspace/app &&
  pm2 start "npm run start --prefix /workspace/app" --name nextjs-prod
  ```

## Customize

- Change Node version in `conf/defaults.env` (`NODE_VERSION=20`)
- Alter Traefik network/name there too
- Tweak `CLAUDE.md.tmpl` for your house rules

## Cleanup

**Delete an app permanently:**
```bash
provision rm myapp
```
Removes container, image, and app directory. Use `--force` to skip confirmation.

**Reset an app (delete and recreate):**
```bash
provision reset myapp
```
Removes everything and recreates from scratch with fresh Next.js bootstrap.
