# Local Development Adaptation Plan

## Context & Motivation

### Current State
The provision system is designed for **remote servers** with:
- Public domains + wildcard DNS (`*.yourdomain.com`)
- Traefik reverse proxy with Let's Encrypt SSL
- HTTPS-only routing
- Assumes deployment to public internet

### The Question
**Is this useful on a local machine (MacBook/Linux)?**

Initial answer: **Not in current form.** The remote-server assumptions (DNS, SSL, public domains) add complexity without local value.

However, there ARE real problems when prototyping with Claude Code locally:
1. **Blast radius** - Claude has access to entire filesystem, could break things
2. **Context pollution** - Sees all projects, harder to focus
3. **Dependency conflicts** - Different projects need different tool versions
4. **Resource monitoring** - No easy way to limit/track Claude's resource usage
5. **Cleanup** - Orphaned node_modules, processes, ports everywhere after prototyping
6. **Port conflicts** - Multiple projects can't all use :3000
7. **State management** - Hard to pause/resume/track multiple prototype sessions

### The Opportunity
**Adapt this tool for local use** by:
- Stripping remote-server assumptions (DNS, SSL)
- Keeping the valuable parts (isolation, resource limits, lifecycle management)
- Using local domain idioms (`*.localhost`)
- Maintaining familiar subdomain routing pattern

---

## Technical Approach

### Chosen Strategy: `*.localhost:8080` + Simplified Traefik

**Why this approach:**
- Modern browsers auto-resolve `*.localhost` to `127.0.0.1` (zero configuration!)
- Keeps subdomain routing pattern familiar (matches remote version)
- Minimal code changes (~50-100 lines across 5-6 files)
- No `/etc/hosts` modifications needed
- No per-app configuration

**Result:**
```bash
provision create myapp
# Access at:
# - http://myapp.localhost:8080 (prod)
# - http://dev-myapp.localhost:8080 (dev)
# - http://vanilla-myapp.localhost:8080 (vanilla)

provision create otherapp
# - http://otherapp.localhost:8080
# No port conflicts, clean separation
```

### Alternatives Considered

#### Option 1: Simple Port Mapping
**Approach:** Remove Traefik, use direct port mappings
**Pros:** Simplest possible (~80% less code)
**Cons:** Port conflicts - only one sandbox at a time OR manual port management
**Verdict:** Too limiting for multi-sandbox workflows

#### Option 2: Dynamic Port Allocation
**Approach:** Auto-assign port ranges (myapp: 3000-3002, otherapp: 3003-3005)
**Pros:** No conflicts, localhost-only
**Cons:** Have to remember which port = which app, loses routing elegance
**Verdict:** Workable but inferior UX

#### Option 3a: `.local` via `/etc/hosts`
**Approach:** Add entries to `/etc/hosts`, use reverse proxy
**Pros:** Clean URLs like `myapp.local`
**Cons:** Requires sudo, manual per-app config
**Verdict:** Too much friction

#### Option 3b: `*.localhost` (CHOSEN)
**Approach:** Use browser's built-in `*.localhost` → `127.0.0.1` resolution
**Pros:** Zero config, subdomain pattern, clean
**Cons:** Requires `:8080` suffix in URLs
**Verdict:** Best balance of simplicity + UX

#### Option 3c: dnsmasq
**Approach:** System-level DNS for custom TLD (e.g., `*.sandbox`)
**Pros:** Cleanest URLs, most flexible
**Cons:** One-time system setup, overkill for this use case
**Verdict:** Save for v2 if users want it

#### Path-based routing
**Approach:** `localhost:8080/myapp`, `/otherapp`
**Pros:** Single domain
**Cons:** Apps need basePath config, breaks isolation illusion
**Verdict:** Awkward for full apps, rejected

---

## Implementation Plan

### Phase 1: Core Networking Changes

#### 1.1 Update Traefik Configuration
**Goal:** Remove SSL, use single HTTP entrypoint

**Changes:**
- Use `:8080` instead of `:80/:443`
- Remove Let's Encrypt resolver
- Remove HTTPS redirect
- Keep Docker provider (container label discovery)

**New Traefik config:**
```yaml
entryPoints:
  web:
    address: ":8080"

providers:
  docker:
    network: local_dev
    exposedByDefault: false
```

#### 1.2 Update Docker Compose Template
**File:** `templates/docker-compose.yml.tmpl`

**Changes:**
- Remove all TLS/certresolver labels
- Change `entrypoints=websecure` → `entrypoints=web`
- Update Host rules: `${NAME}.${DOMAIN_BASE}` → `${NAME}.localhost`
- Keep port definitions (internal :3000, :8000, :9000)
- Change network from `edge` → `local_dev`

**Before:**
```yaml
- "traefik.http.routers.${NAME}.rule=Host(`${NAME}.${DOMAIN_BASE}`)"
- "traefik.http.routers.${NAME}.entrypoints=websecure"
- "traefik.http.routers.${NAME}.tls.certresolver=letsencrypt"
```

**After:**
```yaml
- "traefik.http.routers.${NAME}.rule=Host(`${NAME}.localhost`)"
- "traefik.http.routers.${NAME}.entrypoints=web"
```

#### 1.3 Update Configuration Defaults
**File:** `conf/defaults.env`

**Changes:**
```bash
# OLD:
DOMAIN_BASE=grok.foo
TRAEFIK_NETWORK=edge

# NEW:
DOMAIN_BASE=localhost:8080
TRAEFIK_NETWORK=local_dev
```

### Phase 2: Documentation & User Guidance

#### 2.1 Update Claude Context File
**File:** `templates/CLAUDE.md.tmpl`

**Changes:**
- Update URL examples: `https://myapp.grok.foo` → `http://myapp.localhost:8080`
- Remove references to "public URLs" or "sharing links"
- Emphasize local development workflow
- Update routing section:
  ```markdown
  ## Routing & Ports
  - **Production:** http://${CLAUDE_NAME}.localhost:8080 → container :3000
  - **Development:** http://dev-${CLAUDE_NAME}.localhost:8080 → container :8000
  - **Vanilla static:** http://vanilla-${CLAUDE_NAME}.localhost:8080 → container :9000
  ```

#### 2.2 Update README
**File:** `README.md`

**Add section:**
```markdown
## Local Development Mode

This tool runs in local mode, designed for prototyping on your MacBook/Linux machine.

**Access pattern:**
- Apps are accessible at `http://<name>.localhost:8080`
- Uses built-in browser resolution (no DNS configuration needed)
- All traffic stays on your machine (127.0.0.1)

**Benefits over remote version:**
- No domain/DNS setup required
- No SSL certificates needed
- Faster iteration (no network latency)
- Safe experimentation (isolated from production systems)

**Prerequisites:**
1. Docker installed
2. Traefik running locally (instructions below)
3. Anthropic API key

**Quick start:**
[Adapt existing quick start with localhost URLs]
```

### Phase 3: Code Cleanup

#### 3.1 Remove Remote-Only Features
**Files to modify:**

**`bin/provision-create`:**
- Remove `health_traefik_route` (assumes public DNS)
- Simplify to just check container health
- Update success message with localhost URLs

**`bin/provision-status`:**
- Remove external DNS checks
- Keep internal container health checks

**`bin/provision-setup-status-page`:**
- **Option A:** Remove entirely (less critical locally)
- **Option B:** Adapt to serve on `http://status.localhost:8080`
- **Decision:** Keep and adapt (still useful for resource monitoring)

**`bin/provision-protect-services`:**
- Remove or mark optional (OOM protection less critical on local machine with swap)

#### 3.2 Update Output Messages
**Files:** All `bin/provision-*` scripts

**Pattern:**
```bash
# OLD:
echo "✅ Available at https://myapp.${DOMAIN_BASE}"

# NEW:
echo "✅ Available at http://myapp.localhost:8080"
```

**Search/replace:**
- `https://` → `http://`
- `${DOMAIN_BASE}` context awareness
- Update all example commands in help text

### Phase 4: Traefik Setup Script

#### 4.1 Create Local Traefik Setup
**New file:** `bin/setup-local-traefik` (or integrate into main README)

**Purpose:** One-time setup for local Traefik instance

**Script:**
```bash
#!/usr/bin/env bash
# Setup local Traefik for provision sandboxes

mkdir -p ~/provision-traefik
cd ~/provision-traefik

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

cat > traefik.yml <<'EOF'
entryPoints:
  web:
    address: ":8080"

providers:
  docker:
    network: local_dev
    exposedByDefault: false
EOF

docker network create local_dev 2>/dev/null || true
docker compose up -d

echo "✅ Traefik running on http://localhost:8080"
echo "   Dashboard: http://localhost:8080/dashboard/"
```

### Phase 5: Testing & Validation

#### 5.1 Test Scenarios
1. **Basic creation:** `provision create test1` → verify http://test1.localhost:8080
2. **Multiple sandboxes:** Create test2, test3 → no conflicts
3. **Enter/exit:** `provision enter test1` → Claude starts correctly
4. **Port routing:** All three ports work per sandbox
5. **Resource limits:** Memory/CPU limits still enforced
6. **Lifecycle:** stop/start/restart commands work
7. **Cleanup:** `provision rm` fully removes sandbox

#### 5.2 Edge Cases
- Port 8080 already in use (detect, error message)
- Traefik not running (detect, helpful error)
- Docker network missing (auto-create)
- Browser compatibility (`*.localhost` on Safari, Firefox, Chrome)

---

## Files Modified Summary

### Configuration
- `conf/defaults.env` - Domain/network changes

### Templates
- `templates/docker-compose.yml.tmpl` - Remove TLS labels
- `templates/CLAUDE.md.tmpl` - Update URLs and guidance
- `templates/vanilla.index.html.tmpl` - Update displayed URLs

### Scripts
- `bin/provision-create` - Remove DNS checks, update messages
- `bin/provision-status` - Simplify health checks
- `bin/provision-setup-status-page` - Adapt to localhost (optional)
- All other `bin/provision-*` - Update help text URLs

### Documentation
- `README.md` - Complete rewrite for local usage
- New: `local_plan.md` (this file)
- New: `bin/setup-local-traefik` or integrate into README

### Estimated Changes
- **Lines modified:** ~50-100
- **Files changed:** 5-8
- **New files:** 1-2
- **Deleted files:** 0-1 (maybe protect-services)
- **Complexity:** Low-medium (mostly find/replace)

---

## Migration Path

### For Existing Users (Remote → Local)
**Not applicable** - These are different use cases. Remote users keep their setup.

### For New Users (Local-First)
1. Install Docker
2. Run Traefik setup script
3. Add Anthropic API key
4. `provision create myapp`
5. Open `http://myapp.localhost:8080`

**No DNS, no SSL, no domain registration needed.**

---

## Future Enhancements (V2)

### Optional Features
1. **dnsmasq integration** - Custom TLD like `*.sandbox` without `:8080`
2. **Direct port mode** - Skip Traefik, use dynamic port allocation for minimal deps
3. **Host integration** - Mount ~/.gitconfig, ~/.ssh with smarter defaults
4. **Project import** - `provision create myapp --from ~/Projects/existing-app`
5. **Resource presets** - `--tiny`, `--standard`, `--large`, `--xl` memory profiles
6. **Multi-runtime** - Not just Node, support Python, Go, Rust sandboxes
7. **Snapshot/restore** - Save sandbox state, restore later
8. **Template library** - Pre-configured stacks (Next.js, Remix, SvelteKit, etc.)

### Possible Fork Strategy
- **`provision-remote`** - Keep current version for servers
- **`provision-local`** - This adaptation for local dev
- Share core lib/, diverge on networking/docs

---

## Open Questions

1. **Traefik vs alternatives?**
   - Traefik: Keep existing, just simplify config
   - Caddy: Simpler syntax, easier for locals, but requires rewrite
   - nginx: Classic, stable, but more verbose config
   - **Decision:** Stick with Traefik for now, document Caddy as alternative

2. **Status page locally?**
   - Still useful for monitoring multiple sandboxes
   - Adapt to http://status.localhost:8080
   - **Decision:** Keep and adapt

3. **OOM protection locally?**
   - Less critical (MacOS/Linux have swap)
   - But still prevents runaway processes freezing machine
   - **Decision:** Make optional, document as "recommended"

4. **API key storage?**
   - Remote: `/root/ANTHROPIC_KEY.txt` (server-specific)
   - Local: Maybe `~/.config/provision/anthropic_key`?
   - Or keep same path, let users decide
   - **Decision:** Add `KEY_FILE` auto-detection: check `~/.config/provision/key` first, fallback to `/root/...`

5. **Docker Desktop on Mac - networking quirks?**
   - `*.localhost` should work in Docker Desktop 4.0+
   - Older versions might need `host.docker.internal`
   - **Decision:** Document minimum Docker Desktop version (4.0+)

---

## Success Criteria

### Must Have
- ✅ Sandboxes accessible via `http://*.localhost:8080`
- ✅ No port conflicts between sandboxes
- ✅ Zero DNS/SSL configuration required
- ✅ All lifecycle commands work (create/enter/stop/rm)
- ✅ Resource limits enforced (memory/CPU)
- ✅ Works on MacOS and Linux

### Should Have
- ✅ Clear error messages if Traefik not running
- ✅ Updated documentation for local workflow
- ✅ Status page adapted for localhost
- ✅ One-command Traefik setup script

### Nice to Have
- 🔄 Alternative direct-port mode (no Traefik)
- 🔄 Automatic Traefik setup on first `provision create`
- 🔄 Caddy config example in docs
- 🔄 Project import from existing directories

---

## Timeline Estimate

- **Phase 1** (Core networking): 2-3 hours
- **Phase 2** (Documentation): 1-2 hours
- **Phase 3** (Code cleanup): 1-2 hours
- **Phase 4** (Traefik setup): 1 hour
- **Phase 5** (Testing): 2-3 hours

**Total: 7-11 hours** for complete local adaptation

---

## Conclusion

**Is this worth doing?**

**Yes, if targeting local prototyping with Claude Code.** The problems are real (isolation, resource limits, cleanup, port management), and the adaptation is straightforward (~8 hours work).

**The value prop becomes:**
> "Safe, isolated, resource-limited sandboxes for rapid prototyping with AI coding agents on your local machine. No DNS, no SSL, no server required."

**Key insight:** The remote version solved deployment problems. The local version solves **experimentation safety** problems. Different use case, same architecture, minimal changes needed.
