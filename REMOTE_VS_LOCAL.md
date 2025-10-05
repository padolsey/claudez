# Remote vs Local Mode Comparison

## Overview

The provision tool has been adapted from **remote server deployment** to **local development** mode. Here's what changed and how to restore remote functionality.

---

## Key Differences

### 1. Networking & Domains

| Aspect | Remote (Original) | Local (Current) |
|--------|------------------|-----------------|
| **Domain** | `yourdomain.com` (public) | `localhost:8090` (local) |
| **DNS Required** | Yes (wildcard `*.yourdomain.com`) | No (browser built-in) |
| **SSL/TLS** | Yes (Let's Encrypt) | No (HTTP only) |
| **Port** | 80/443 (standard HTTP/HTTPS) | 8090 (local dev port) |
| **Network Name** | `edge` | `local_dev` |
| **Traefik Entrypoint** | `websecure` (HTTPS) | `web` (HTTP) |

### 2. Access URLs

**Remote:**
```
https://myapp.yourdomain.com          (prod)
https://dev-myapp.yourdomain.com      (dev)
https://vanilla-myapp.yourdomain.com  (vanilla)
```

**Local:**
```
http://myapp.localhost:8090           (prod)
http://dev-myapp.localhost:8090       (dev)
http://vanilla-myapp.localhost:8090   (vanilla)
```

### 3. Traefik Configuration

**Remote (Required):**
```yaml
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

certificatesResolvers:
  letsencrypt:
    acme:
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

**Local (Current):**
```yaml
entryPoints:
  web:
    address: ":8090"

# No SSL configuration needed
```

### 4. Prerequisites

**Remote:**
- Ubuntu/Linux server with public IP
- Domain name with DNS access
- Wildcard DNS record (`*.yourdomain.com`)
- Let's Encrypt for SSL certificates
- Docker + Docker Compose
- Traefik on ports 80/443

**Local:**
- macOS/Linux machine
- Docker Desktop
- Traefik on any available port
- No domain, no DNS, no SSL

---

## Changed Files Summary

### Core Configuration (2 files)

**1. `conf/defaults.env`**
```diff
- DOMAIN_BASE=grok.foo
+ DOMAIN_BASE=localhost:8090

- TRAEFIK_NETWORK=edge
+ TRAEFIK_NETWORK=local_dev
```

### Templates (3 files)

**2. `templates/docker-compose.yml.tmpl`**
- **Removed:** All `.tls.certresolver=letsencrypt` labels (3 places)
- **Changed:** `entrypoints=websecure` → `entrypoints=web` (3 places)
- **Changed:** `Host(\`${NAME}.${DOMAIN_BASE}\`)` → `Host(\`${NAME}.localhost\`)` (3 places)
- **Result:** 12 lines removed/modified

**3. `templates/CLAUDE.md.tmpl`**
- Updated all URL examples from `https://` to `http://`
- Changed domain references from `${DOMAIN_BASE}` to `localhost:8090`
- Added "Local development" context note

**4. `templates/vanilla.index.html.tmpl`**
- Updated displayed URLs to `http://*.localhost:8090` pattern
- Added clickable navigation links

### Library Functions (1 file)

**5. `lib/docker.sh`**
```diff
- curl -fsSk --resolve "${host}:443:127.0.0.1" "https://${host}/"
+ curl -fsS "http://${host}:8080/"
```
Changed health check from HTTPS to HTTP

### Scripts (2 files)

**6. `bin/provision-create`**
- Updated success message URLs from `https://` to `http://`
- Changed health check call to use `${NAME}.localhost`

**7. `bin/provision-status`**
- Updated health check domain from `${DOMAIN_BASE}` to `localhost`

### Documentation (1 file)

**8. `README.md`**
- Complete rewrite for local development focus
- Simplified from 666 lines to 412 lines
- Removed remote deployment instructions
- Added quick start for local setup

---

## Restoring Remote Mode

To restore the original remote deployment functionality, you have two options:

### Option A: Per-User Override (Recommended)

Keep the codebase as-is (local-first) but configure for remote via `~/.provisionrc`:

```bash
# Create remote config
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=yourdomain.com
TRAEFIK_NETWORK=edge
APPS_DIR=/opt/apps
KEY_FILE=/root/ANTHROPIC_KEY.txt
EOF
```

Then set up remote Traefik with SSL:
```bash
# On your server
docker network create edge

# Deploy Traefik with Let's Encrypt
# (see original README for full config)
```

### Option B: Git Branch Strategy

Create separate branches for each mode:

```bash
# Current state = local mode
git checkout -b local-mode
git add .
git commit -m "Local development mode"

# Restore remote mode
git checkout main
git checkout HEAD -- conf/defaults.env lib/docker.sh templates/*.tmpl bin/provision-*
git commit -m "Restore remote mode defaults"

# Switch between modes:
git checkout local-mode   # For local dev
git checkout main         # For remote deployment
```

### Option C: Revert Changes

To fully revert to original remote mode:

```bash
cd /Users/james/proj/provision

# Revert all changes
git checkout HEAD -- conf/defaults.env
git checkout HEAD -- lib/docker.sh
git checkout HEAD -- templates/docker-compose.yml.tmpl
git checkout HEAD -- templates/CLAUDE.md.tmpl
git checkout HEAD -- templates/vanilla.index.html.tmpl
git checkout HEAD -- bin/provision-create
git checkout HEAD -- bin/provision-status
git checkout HEAD -- README.md

# Remove local additions
rm docs/SETUP_LOCAL_TRAEFIK.md
rm IMPLEMENTATION_SUMMARY.md
rm REMOTE_VS_LOCAL.md
```

---

## Will Remote Mode Still Work?

**Short Answer:** **No, not with current defaults. But easily restored.**

### Why It Won't Work As-Is:

1. **Hardcoded localhost references** in templates
   - `Host(\`${NAME}.localhost\`)` instead of `Host(\`${NAME}.${DOMAIN_BASE}\`)`
   - Templates are now hardcoded to `.localhost` domains

2. **HTTP-only health checks**
   - `curl -fsS "http://${host}:8080/"` won't work for HTTPS servers
   - Missing `--resolve` flag for DNS testing

3. **Wrong network name**
   - Expects `local_dev` instead of `edge`

4. **Port mismatch**
   - Hardcoded `:8080` in health checks
   - Remote servers use port 443

### What's Needed to Restore:

1. **Update `conf/defaults.env`:**
   ```bash
   DOMAIN_BASE=yourdomain.com
   TRAEFIK_NETWORK=edge
   ```

2. **Fix template hardcoding:**

   In `templates/docker-compose.yml.tmpl`, change:
   ```yaml
   - "traefik.http.routers.${NAME}.rule=Host(`${NAME}.localhost`)"
   ```
   Back to:
   ```yaml
   - "traefik.http.routers.${NAME}.rule=Host(`${NAME}.${DOMAIN_BASE}`)"
   ```

3. **Restore TLS labels** (3 places):
   ```yaml
   - "traefik.http.routers.${NAME}.entrypoints=websecure"
   - "traefik.http.routers.${NAME}.tls.certresolver=letsencrypt"
   ```

4. **Fix health check in `lib/docker.sh`:**
   ```bash
   curl -fsSk --resolve "${host}:443:127.0.0.1" "https://${host}/"
   ```

---

## Dual-Mode Support (Future Enhancement)

To support BOTH modes without manual changes, consider:

### 1. Auto-Detection in `lib/common.sh`:

```bash
# Detect mode based on DOMAIN_BASE
is_local_mode() {
  [[ "$DOMAIN_BASE" =~ localhost ]]
}

# Use in health checks
if is_local_mode; then
  curl -fsS "http://${host}:8080/"
else
  curl -fsSk --resolve "${host}:443:127.0.0.1" "https://${host}/"
fi
```

### 2. Conditional Templates:

Use environment-based template selection:
```bash
if is_local_mode; then
  ENTRYPOINT="web"
  PROTOCOL="http"
else
  ENTRYPOINT="websecure"
  PROTOCOL="https"
fi
```

### 3. Mode Selection Command:

```bash
provision config --mode local   # Switch to local mode
provision config --mode remote  # Switch to remote mode
```

---

## Migration Path

### From Local → Remote:

1. Deploy to a server with public IP
2. Set up DNS wildcard
3. Update `~/.provisionrc` with your domain
4. Deploy remote Traefik with Let's Encrypt
5. Manually fix hardcoded `.localhost` in templates

### From Remote → Local:

Already done! Current state is local-ready.

---

## Summary

| What Changed | Lines Modified | Breaking for Remote? |
|--------------|----------------|---------------------|
| Domain config | 2 | Yes - need to override |
| TLS removal | 9 | Yes - breaks HTTPS |
| Health checks | 6 | Yes - wrong protocol |
| Hardcoded localhost | 6 | **YES - CRITICAL** |
| Documentation | ~450 | No - just docs |

**Total Breaking Changes:** 23 lines across 5 files

**Effort to Restore Remote:** Low (~30 minutes)

**Best Approach:** Use `~/.provisionrc` to override defaults + manually fix `.localhost` template hardcoding

---

## Recommendation

**For maintainability, create two branches:**

```bash
# Keep both modes
git branch local-mode    # Current state
git branch remote-mode   # Revert changes

# Tag releases
git tag v1.0.0-local
git tag v1.0.0-remote
```

This allows easy switching without losing either implementation.
