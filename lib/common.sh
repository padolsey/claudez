#!/usr/bin/env bash
set -Eeuo pipefail

need() { command -v "$1" >/dev/null || { printf '[provision:ERROR] missing dependency: %s\n' "$1" >&2; exit 1; }; }
log()  { printf '[provision] %s\n' "$*"; }
die()  { printf '[provision:ERROR] %s\n' "$*" >&2; exit 1; }

# Defaults file -> per-user overrides -> project env (if provided via caller)
load_env() {
  set -a
  : "${PROJECT_ENV:=}"  # optional
  ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  [ -f "$ROOT_DIR/conf/defaults.env" ] && . "$ROOT_DIR/conf/defaults.env"
  [ -f "$HOME/.provisionrc" ] && . "$HOME/.provisionrc"
  [ -n "$PROJECT_ENV" ] && [ -f "$PROJECT_ENV" ] && . "$PROJECT_ENV"
  set +a
}

trap 'code=$?; [ $code -ne 0 ] && echo "[provision] aborted ($code)"; exit $code' EXIT
