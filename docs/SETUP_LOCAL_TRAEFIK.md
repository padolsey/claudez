# Local Traefik Setup

This guide sets up a local Traefik instance for the claudez tool on your MacBook/Linux machine.

## Quick Setup

Run these commands to set up Traefik for local development:

```bash
# 1. Create Docker network
docker network create local_dev

# 2. Create Traefik directory
mkdir -p ~/claudez-traefik
cd ~/claudez-traefik

# 3. Create Traefik configuration
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

# 4. Create docker-compose file
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

# 5. Start Traefik
docker compose up -d

# 6. Verify it's running
docker ps | grep traefik-local
```

## Verify Setup

```bash
# Check Traefik is running
curl http://localhost:8080/api/rawdata | jq '.routers' 2>/dev/null || echo "Traefik is running"

# Optional: Visit dashboard
# http://localhost:8080/dashboard/
```

## What This Does

- Creates a Docker network named `local_dev` for sandbox communication
- Runs Traefik on port 8080 for HTTP traffic
- Enables automatic container discovery (watches Docker socket)
- Routes `*.localhost` subdomains to containers (e.g., `myapp.localhost:8080`)

## Differences from Remote Setup

**Remote (Production):**
- Ports 80/443 (HTTP/HTTPS)
- Let's Encrypt SSL certificates
- Public domain routing

**Local (Development):**
- Port 8080 only (HTTP)
- No SSL needed
- `*.localhost` routing (zero DNS config)

## Troubleshooting

**Port 8080 already in use:**
```bash
# Find what's using it
lsof -ti:8080

# Change Traefik port (edit both files)
# traefik.yml:     address: ":8090"
# docker-compose.yml:  - "8090:8090"
```

**Traefik won't start:**
```bash
docker logs traefik-local
# Check for errors

# Recreate from scratch
docker compose down
docker compose up -d
```

**Container network issues:**
```bash
# Recreate network
docker network rm local_dev
docker network create local_dev

# Restart Traefik
docker compose restart
```

## Management Commands

```bash
# Stop Traefik
cd ~/claudez-traefik && docker compose stop

# Start Traefik
cd ~/claudez-traefik && docker compose start

# View logs
docker logs -f traefik-local

# Remove completely
cd ~/claudez-traefik && docker compose down
docker network rm local_dev
```

## Next Steps

Once Traefik is running:

```bash
# Create your first sandbox
claudez create myapp

# Access it at:
# http://myapp.localhost:8080         (prod)
# http://dev-myapp.localhost:8080     (dev)
# http://vanilla-myapp.localhost:8080 (vanilla)
```
