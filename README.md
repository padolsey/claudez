# Claude Sandbox Provisioner (split, sane, and durable)

This repo creates/enters **Claude Code** sandboxes (Docker + Traefik) with:
- Zero onboarding/OAuth prompts (uses your `ANTHROPIC_API_KEY`)
- A tmux-backed `cc` wrapper so Claude sessions **survive disconnects**
- Clean, maintainable split: `bin/` + `lib/` + `templates/` + `conf/`

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

3. **Enter + start Claude** (tmux auto-attach):

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

## Maintainable structure

- `bin/` — thin, single-purpose commands (`create`, `enter`, `reset`, `status`)
- `lib/` — shared helpers (env loading, docker utilities, template rendering)
- `templates/` — all generated files live here; we render with `envsubst`
- `conf/defaults.env` — repo defaults; override in `~/.provisionrc`

## Ops notes (strong opinions)

- **Use mosh** from iPad (Termius supports it) **and** tmux in-container.
  Mosh handles flaky networks; tmux guarantees Claude survives client death.
- **Secrets**: Prefer Docker secrets or a root-only `:ro` bind mount. Never commit keys.
- **Health checks**: `provision status <name>` validates vanilla + Traefik routing.
- **Debug**:
  - `docker logs <container>` (pm2 is quiet for vanilla, by design)
  - `docker exec -it <container> bash` then `cc` to attach Claude
  - Inside tmux: `Ctrl-b d` to detach without killing Claude

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

## Uninstall / Reset

```bash
provision/bin/provision reset myapp
```

This removes the container, image, and app dir, then recreates it clean.
