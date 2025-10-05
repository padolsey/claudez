# Remote Server Installation Changes

## Summary: One Required Change

**For remote servers, you MUST create `~/.provisionrc` to override the new local defaults.**

---

## What Changed

### Before (Original)
```bash
# conf/defaults.env (committed to repo)
DOMAIN_BASE=grok.foo
TRAEFIK_NETWORK=edge
APPS_DIR=/opt/apps
```

**Installation:** Clone repo and run `provision create myapp` - worked immediately.

### After (Current - Dual Mode)
```bash
# conf/defaults.env (committed to repo)
DOMAIN_BASE=localhost:8090      # ← Changed to local mode
TRAEFIK_NETWORK=local_dev       # ← Changed for local
APPS_DIR=/opt/apps              # ← Same
```

**Installation:** Clone repo, **create `~/.provisionrc`**, then run `provision create myapp`.

---

## Required Changes for Remote Servers

### ⚠️ CRITICAL: Create ~/.provisionrc

**On your remote server, you MUST create this file:**

```bash
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=yourdomain.com
TRAEFIK_NETWORK=edge
EOF
```

Replace `yourdomain.com` with your actual domain.

### Why Is This Required?

The repo defaults have changed to **local mode** (localhost:8090) to make local development zero-config. Remote servers must now **override** these defaults.

---

## Updated Remote Installation Steps

### Original Installation (Before)
```bash
# 1. Install prerequisites
curl -fsSL https://get.docker.com | sh
docker network create edge

# 2. Deploy Traefik with Let's Encrypt
# ... (Traefik setup)

# 3. Store API key
sudo install -D -m 600 /dev/stdin /root/ANTHROPIC_KEY.txt

# 4. Clone repo
git clone git@github.com:padolsey/provision.git

# 5. Create sandbox
~/provision/bin/provision create myapp
# ✅ Worked - used grok.foo default
```

### New Installation (Current)
```bash
# 1. Install prerequisites
curl -fsSL https://get.docker.com | sh
docker network create edge

# 2. Deploy Traefik with Let's Encrypt
# ... (Traefik setup)

# 3. Store API key
sudo install -D -m 600 /dev/stdin /root/ANTHROPIC_KEY.txt

# 4. Clone repo
git clone git@github.com:padolsey/provision.git

# 5. ⭐ NEW STEP: Create ~/.provisionrc
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=yourdomain.com
TRAEFIK_NETWORK=edge
EOF

# 6. Create sandbox
~/provision/bin/provision create myapp
# ✅ Works - uses ~/.provisionrc overrides
```

---

## What Happens Without ~/.provisionrc?

### Bad Scenario: Remote Server Without Override

```bash
# Server: Ubuntu 22.04, public IP, DNS configured
provision create myapp

# What happens:
# ❌ Creates containers with Host(`myapp.localhost`)
# ❌ Uses HTTP instead of HTTPS
# ❌ No TLS certificates requested
# ❌ Traefik looks for wrong network (local_dev)
# ❌ Routes don't work

# Result: Broken deployment
```

### Good Scenario: Remote Server With Override

```bash
# Create ~/.provisionrc first
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=myserver.com
TRAEFIK_NETWORK=edge
EOF

provision create myapp

# What happens:
# ✅ Creates containers with Host(`myapp.myserver.com`)
# ✅ Uses HTTPS with Let's Encrypt
# ✅ TLS certresolver labels added
# ✅ SSH mount added for private repos
# ✅ Traefik finds edge network
# ✅ Routes work perfectly

# Result: Working deployment
```

---

## Comparison Table

| Aspect | Before | After | Change Impact |
|--------|--------|-------|---------------|
| **Default Domain** | `grok.foo` | `localhost:8090` | Remote servers MUST override |
| **Default Network** | `edge` | `local_dev` | Remote servers MUST override |
| **Apps Directory** | `/opt/apps` | `/opt/apps` | No change |
| **Template Logic** | Static | Dynamic (mode-aware) | Transparent - no impact |
| **TLS Labels** | Always included | Added if remote mode | Transparent - no impact |
| **SSH Mount** | Always included | Added if remote mode | Transparent - no impact |
| **Health Checks** | HTTPS only | HTTP or HTTPS based on mode | Transparent - no impact |

---

## Migration for Existing Remote Deployments

### If You Already Have a Remote Server Running Provision

**Scenario 1: Haven't Updated Yet (Still Using Original Code)**

✅ **No action needed** - Keep using current commit, or update when ready

**Scenario 2: Just Updated to Latest Code**

⚠️ **Action required:**

```bash
# On your remote server
cd ~/provision
git pull

# Create override config
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=yourdomain.com
TRAEFIK_NETWORK=edge
EOF

# Test with new sandbox
provision create test-remote-mode

# If working, recreate existing sandboxes
provision reset myapp
provision reset otherapp
```

**Scenario 3: Sandboxes Created After Update (Without ~/.provisionrc)**

🚨 **Broken - must fix:**

```bash
# 1. Create proper config
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=yourdomain.com
TRAEFIK_NETWORK=edge
EOF

# 2. Recreate all sandboxes
provision ls
provision reset sandbox1
provision reset sandbox2
# etc.
```

---

## Detection Script

To check if your remote server is properly configured:

```bash
#!/bin/bash
# save as: check-remote-config.sh

cd ~/provision
source conf/defaults.env
[ -f ~/.provisionrc ] && source ~/.provisionrc

echo "Current configuration:"
echo "  DOMAIN_BASE: $DOMAIN_BASE"
echo "  TRAEFIK_NETWORK: $TRAEFIK_NETWORK"
echo ""

if [[ "$DOMAIN_BASE" =~ localhost ]]; then
  echo "❌ ERROR: Using local mode defaults on remote server!"
  echo "   Action: Create ~/.provisionrc with your domain"
  exit 1
else
  echo "✅ Remote mode configured correctly"
  echo "   Sandboxes will be created at: https://*.${DOMAIN_BASE}"
fi
```

**Usage:**
```bash
bash check-remote-config.sh
```

---

## Updated Remote Installation Documentation

**Should be added to README or separate REMOTE_SETUP.md:**

```markdown
## Remote Server Installation

### Prerequisites
- Ubuntu 22.04+ with public IP
- Domain with wildcard DNS (`*.yourdomain.com` → server IP)
- Anthropic API key

### Installation Steps

1. **Install Docker**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Create Docker Network**
   ```bash
   docker network create edge
   ```

3. **Deploy Traefik**
   ```bash
   mkdir -p ~/traefik
   cd ~/traefik

   cat > traefik.yml <<'EOF'
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

   cat > docker-compose.yml <<'EOF'
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

   # Edit email
   nano docker-compose.yml  # Change your@email.com

   # Start Traefik
   docker compose up -d
   ```

4. **Store Anthropic API Key**
   ```bash
   sudo install -D -m 600 /dev/stdin /root/ANTHROPIC_KEY.txt
   # Paste your key, Ctrl+D
   ```

5. **Clone Provision**
   ```bash
   cd ~
   git clone git@github.com:padolsey/provision.git
   ```

6. **⭐ Configure for Remote Mode**
   ```bash
   cat > ~/.provisionrc <<'EOF'
   DOMAIN_BASE=yourdomain.com
   TRAEFIK_NETWORK=edge
   EOF

   # Edit with your actual domain
   nano ~/.provisionrc
   ```

7. **Create Alias (Optional)**
   ```bash
   echo "alias provision='~/provision/bin/provision'" >> ~/.bashrc
   source ~/.bashrc
   ```

8. **Create First Sandbox**
   ```bash
   provision create myapp

   # Should see:
   # ✅ Sandbox ready
   #    PROD:    https://myapp.yourdomain.com
   #    DEV:     https://dev-myapp.yourdomain.com
   #    VANILLA: https://vanilla-myapp.yourdomain.com
   ```

9. **Verify**
   ```bash
   # Wait for Let's Encrypt (30-60 seconds)
   curl https://vanilla-myapp.yourdomain.com

   # Should return HTML, not certificate error
   ```

### ⚠️ Critical: Step 6 is Required

Without `~/.provisionrc`, provision will use **local mode** defaults and create broken remote deployments.
```

---

## FAQ

### Q: Why change the defaults to local mode?

**A:** Local development is now the primary use case and benefits from zero-config. Remote deployments are still fully supported via `~/.provisionrc`.

### Q: Can I change the repo defaults back to remote?

**A:** Yes, edit `conf/defaults.env`:
```bash
DOMAIN_BASE=grok.foo  # or leave as variable
TRAEFIK_NETWORK=edge
```

But this breaks local mode for contributors.

### Q: What if I have multiple remote servers?

**A:** Each server needs its own `~/.provisionrc`:

```bash
# server1.example.com
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=server1.example.com
TRAEFIK_NETWORK=edge
EOF

# server2.example.com
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=server2.example.com
TRAEFIK_NETWORK=edge
EOF
```

### Q: Can I use the same code for both local and remote?

**A:** Yes! That's the whole point. The code auto-detects based on `DOMAIN_BASE`.

- Local machine: `DOMAIN_BASE=localhost:8090` (default)
- Remote server: `DOMAIN_BASE=yourdomain.com` (via `~/.provisionrc`)

---

## Summary

### For Remote Servers

**ONE REQUIRED CHANGE:**
```bash
cat > ~/.provisionrc <<'EOF'
DOMAIN_BASE=yourdomain.com
TRAEFIK_NETWORK=edge
EOF
```

**Everything else is identical to before.**

### For New Remote Deployments

Add Step 6 to your installation docs: Create `~/.provisionrc` with your domain.

### For Existing Remote Deployments

Create `~/.provisionrc` and recreate sandboxes (if updated after this change).

---

## Recommendation for Repo Maintainer

**Consider adding a bootstrap script:**

```bash
# bin/provision-init-remote
#!/usr/bin/env bash
set -euo pipefail

read -p "Enter your domain (e.g., example.com): " DOMAIN
read -p "Traefik network name [edge]: " NETWORK
NETWORK="${NETWORK:-edge}"

cat > ~/.provisionrc <<EOF
DOMAIN_BASE=$DOMAIN
TRAEFIK_NETWORK=$NETWORK
EOF

echo "✅ Remote mode configured"
echo "   Domain: $DOMAIN"
echo "   Network: $NETWORK"
echo ""
echo "You can now run: provision create myapp"
```

**Usage:**
```bash
~/provision/bin/provision-init-remote
# Enter your domain: myserver.com
# Traefik network name [edge]:
# ✅ Remote mode configured
```

This makes remote setup more explicit and less error-prone.
