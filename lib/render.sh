#!/usr/bin/env bash
set -Eeuo pipefail

# Render a template with envsubst; if output path given, write to it.
# Only substitute NODE_VERSION variable to avoid affecting script content
render() {
  local src="$1" dst="$2"
  envsubst '$NODE_VERSION $NAME $DOMAIN_BASE $TRAEFIK_NETWORK $TRAEFIK_ENTRYPOINT $MEM_RESERVATION $MEM_LIMIT $CPU_LIMIT $CLAUDE_NAME' < "$src" > "$dst"
  echo "$dst"
}
