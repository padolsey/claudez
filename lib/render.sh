#!/usr/bin/env bash
set -Eeuo pipefail

# Render a template with envsubst; if output path given, write to it.
render() {
  local src="$1" dst="$2"
  envsubst < "$src" > "$dst"
  echo "$dst"
}
