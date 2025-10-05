#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

load_env

MODE=""
if is_local_mode; then
  MODE="local"
else
  MODE="remote"
fi

echo "claudez Traefik Setup"
echo "====================="
echo ""
echo "Detected mode: $MODE"
echo "Domain: $DOMAIN_BASE"
echo "Network: $TRAEFIK_NETWORK"
echo ""

# Check if Traefik is already running
if docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
  echo "⚠️  Traefik container 'traefik' is already running."
  echo ""
  read -p "Reconfigure and restart? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
  docker stop traefik
  docker rm traefik
fi

# Create network if it doesn't exist
if ! docker network ls --format '{{.Name}}' | grep -q "^${TRAEFIK_NETWORK}$"; then
  echo "Creating Docker network: $TRAEFIK_NETWORK"
  docker network create "$TRAEFIK_NETWORK"
else
  echo "✓ Network '$TRAEFIK_NETWORK' already exists"
fi

# Create Traefik directory
TRAEFIK_DIR="$HOME/claudez-traefik"
mkdir -p "$TRAEFIK_DIR"
cd "$TRAEFIK_DIR"

if [ "$MODE" = "local" ]; then
  echo ""
  echo "Setting up LOCAL mode (HTTP, no SSL)..."
  echo ""

  # Extract port from localhost:8080
  PORT="${DOMAIN_BASE#*:}"
  PORT="${PORT:-8080}"

  # Create local traefik.yml
  cat > traefik.yml <<EOF
global:
  checkNewVersion: false
  sendAnonymousUsage: false

entryPoints:
  web:
    address: ":${PORT}"

providers:
  docker:
    network: ${TRAEFIK_NETWORK}
    exposedByDefault: false

api:
  dashboard: true
  insecure: true
EOF

  # Create local docker-compose.yml
  cat > docker-compose.yml <<EOF
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "${PORT}:${PORT}"
    networks:
      - ${TRAEFIK_NETWORK}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro

networks:
  ${TRAEFIK_NETWORK}:
    external: true
EOF

  echo "✓ Created configuration in $TRAEFIK_DIR"
  echo ""
  echo "Starting Traefik..."
  docker compose up -d

  echo ""
  echo "✅ Traefik is running in LOCAL mode"
  echo ""
  echo "Your apps will be accessible at:"
  echo "  http://<name>.localhost:${PORT}"
  echo ""
  echo "Dashboard: http://localhost:${PORT}/dashboard/"

else
  echo ""
  echo "Setting up REMOTE mode (HTTPS with Let's Encrypt)..."
  echo ""

  # Prompt for email
  read -p "Email for Let's Encrypt notifications: " EMAIL
  if [ -z "$EMAIL" ]; then
    echo "Error: Email is required for Let's Encrypt"
    exit 1
  fi

  # Create letsencrypt directory
  mkdir -p letsencrypt
  touch letsencrypt/acme.json
  chmod 600 letsencrypt/acme.json

  # Create remote traefik.yml
  cat > traefik.yml <<EOF
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
    network: ${TRAEFIK_NETWORK}
    exposedByDefault: false

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${EMAIL}
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web

api:
  dashboard: true
  insecure: true
EOF

  # Create remote docker-compose.yml
  cat > docker-compose.yml <<EOF
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard
    networks:
      - ${TRAEFIK_NETWORK}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./letsencrypt:/letsencrypt:rw

networks:
  ${TRAEFIK_NETWORK}:
    external: true
EOF

  echo "✓ Created configuration in $TRAEFIK_DIR"
  echo ""
  echo "Starting Traefik..."
  docker compose up -d

  echo ""
  echo "✅ Traefik is running in REMOTE mode"
  echo ""
  echo "Your apps will be accessible at:"
  echo "  https://<name>.${DOMAIN_BASE}"
  echo ""
  echo "Dashboard: http://$(hostname -I | awk '{print $1}'):8080/dashboard/"
  echo ""
  echo "⚠️  Make sure your DNS is configured:"
  echo "  *.${DOMAIN_BASE} → $(hostname -I | awk '{print $1}')"
fi

echo ""
echo "Next steps:"
echo "  claudez create myapp"
echo "  claudez ls"
