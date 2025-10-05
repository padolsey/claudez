#!/usr/bin/env bash
set -Eeuo pipefail

need() { command -v "$1" >/dev/null || { printf '[claudez:ERROR] missing dependency: %s\n' "$1" >&2; exit 1; }; }
log()  { printf '[claudez] %s\n' "$*"; }
die()  { printf '[claudez:ERROR] %s\n' "$*" >&2; exit 1; }
confirm() {
  local prompt="${1:-Continue?}"
  printf '[claudez] %s [y/N] ' "$prompt" >&2
  read -r response
  [[ "$response" =~ ^[Yy]$ ]] || die "Cancelled."
}

# Defaults file -> per-user overrides -> project env (if provided via caller)
load_env() {
  set -a
  : "${PROJECT_ENV:=}"  # optional
  ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  [ -f "$ROOT_DIR/conf/defaults.env" ] && . "$ROOT_DIR/conf/defaults.env"
  [ -f "$HOME/.claudezrc" ] && . "$HOME/.claudezrc"
  [ -n "$PROJECT_ENV" ] && [ -f "$PROJECT_ENV" ] && . "$PROJECT_ENV"
  set +a
}

# Mode detection helpers
is_local_mode() {
  [[ "$DOMAIN_BASE" =~ localhost ]]
}

get_protocol() {
  if is_local_mode; then
    echo "http"
  else
    echo "https"
  fi
}

get_traefik_port() {
  if is_local_mode; then
    # Extract port from localhost:8090
    echo "${DOMAIN_BASE#*:}"
  else
    echo "443"
  fi
}

get_traefik_entrypoint() {
  if is_local_mode; then
    echo "web"
  else
    echo "websecure"
  fi
}

get_domain_without_port() {
  # Strip port from domain if present (localhost:8090 -> localhost)
  echo "${DOMAIN_BASE%:*}"
}

trap 'code=$?; [ $code -ne 0 ] && echo "[claudez] aborted ($code)"; exit $code' EXIT
