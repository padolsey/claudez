#!/usr/bin/env bash
set -Eeuo pipefail
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_network() {
  local net="$1"
  if ! docker network inspect "$net" >/dev/null 2>&1; then
    log "Docker network '$net' not found; creating."
    docker network create "$net" >/dev/null
  fi
}

wait_running() {
  local name="$1"; local tries="${2:-30}"
  log "Waiting for container '$name' to be running…"
  for i in $(seq 1 "$tries"); do
    state=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "")
    [ "$state" = "running" ] && { log "Container is running."; return 0; }
    sleep 1
  done
  [ "$tries" -eq 0 ] && return 0
  die "Container '$name' did not reach running state."
}

health_vanilla_inside() {
  local name="$1"; local tries="${2:-15}"
  log "Sanity: vanilla server inside container on :9000…"
  for i in $(seq 1 "$tries"); do
    if docker exec -u appuser "$name" bash -lc 'wget -qO- http://127.0.0.1:9000 >/dev/null 2>&1'; then
      log "OK: vanilla responds inside container."; return 0
    fi
    sleep 2
  done
  log "WARNING: vanilla did not respond inside container."
}

health_traefik_route() {
  local host="$1"; local tries="${2:-20}"
  log "Sanity: Traefik route for ${host} via HTTPS…"
  for i in $(seq 1 "$tries"); do
    if curl -fsSk --resolve "${host}:443:127.0.0.1" "https://${host}/" >/dev/null 2>&1; then
      log "OK: Traefik route is live."; return 0
    fi
    sleep 2
  done
  log "WARNING: Traefik route not responding yet (DNS/propagation or Traefik down?)."
}
