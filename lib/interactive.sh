#!/usr/bin/env bash
# Interactive prompts and UI helpers for claudez

log_section() {
  local title="$1"
  echo ""
  echo "╭────────────────────────────────────────────────────────╮"
  printf "│  %-54s│\n" "$title"
  echo "╰────────────────────────────────────────────────────────╯"
  echo ""
}

has_openrouter_key() {
  [ -n "${OPENROUTER_API_KEY:-}" ] && return 0
  local key_file="${OPENROUTER_API_KEY_FILE/#\~/$HOME}"
  [ -f "$key_file" ] && [ -s "$key_file" ] && return 0
  return 1
}

has_anthropic_key() {
  [ -n "${ANTHROPIC_API_KEY:-}" ] && return 0
  local key_file="${KEY_FILE/#\~/$HOME}"
  [ -f "$key_file" ] && [ -s "$key_file" ] && return 0
  return 1
}

show_success_box() {
  local zone_name="$1"
  local agent="$2"
  local protocol="$3"
  local domain="$4"
  local models="${5:-}"

  echo ""
  echo "╭────────────────────────────────────────────────────────╮"
  printf "│  🎉 Zone '%-46s' ready! │\n" "$zone_name"
  echo "│                                                        │"
  printf "│  Agent: %-46s │\n" "$agent"
  echo "│                                                        │"
  echo "│  URLs:                                                 │"
  printf "│    Production: %-39s │\n" "${protocol}://${zone_name}.${domain}"
  printf "│    Dev Server: %-39s │\n" "${protocol}://dev-${zone_name}.${domain}"
  echo "│                                                        │"
  echo "│  Quick Start:                                          │"
  printf "│    %-50s │\n" "claudez enter $zone_name"

  if [ "$agent" = "OpenCode" ]; then
    printf "│    %-50s │\n" "opencode"
    if [ -n "$models" ]; then
      echo "│                                                        │"
      echo "│  Available Models (Ctrl+x m to switch):               │"
      for model in $models; do
        printf "│    • %-48s │\n" "$model"
      done
    fi
  else
    printf "│    %-50s │\n" "tclaude"
  fi

  echo "╰────────────────────────────────────────────────────────╯"
  echo ""
}

interactive_openrouter_setup() {
  log_section "OpenRouter API Key Required"

  echo "OpenRouter gives you access to 75+ models with one API key."
  echo "Get your free key at: https://openrouter.ai/keys"
  echo ""

  # Optionally open browser
  if command -v xdg-open >/dev/null 2>&1 || command -v open >/dev/null 2>&1; then
    read -p "Open in browser? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      (command -v xdg-open >/dev/null 2>&1 && xdg-open "https://openrouter.ai/keys" 2>/dev/null) || \
      (command -v open >/dev/null 2>&1 && open "https://openrouter.ai/keys" 2>/dev/null) || true
      sleep 2
    fi
  fi

  echo ""
  read -p "Paste your OpenRouter API key: " -s OPENROUTER_API_KEY
  echo ""

  if [ -z "$OPENROUTER_API_KEY" ]; then
    die "No API key provided. Cancelled."
  fi

  # Validate format
  if [[ ! "$OPENROUTER_API_KEY" =~ ^sk-or-v1- ]]; then
    log "⚠  Warning: Key doesn't match expected format (sk-or-v1-...)"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && die "Cancelled."
  fi

  log "✓ API key received (${OPENROUTER_API_KEY:0:15}...)"

  # Offer to save
  echo ""
  read -p "Save this key for future zones? [Y/n] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    mkdir -p "$(dirname "${OPENROUTER_API_KEY_FILE/#\~/$HOME}")"
    echo "$OPENROUTER_API_KEY" > "${OPENROUTER_API_KEY_FILE/#\~/$HOME}"
    chmod 600 "${OPENROUTER_API_KEY_FILE/#\~/$HOME}"
    log "✓ Saved to ${OPENROUTER_API_KEY_FILE}"
  fi

  export OPENROUTER_API_KEY
}

interactive_custom_provider_setup() {
  log_section "Custom Provider Setup"

  read -p "Provider name: " CUSTOM_PROVIDER_NAME
  read -p "API base URL: " CUSTOM_BASE_URL
  read -s -p "API key: " CUSTOM_API_KEY
  echo ""

  if [ -z "$CUSTOM_PROVIDER_NAME" ] || [ -z "$CUSTOM_BASE_URL" ] || [ -z "$CUSTOM_API_KEY" ]; then
    die "All fields are required for custom provider setup"
  fi

  export CUSTOM_PROVIDER_NAME
  export CUSTOM_BASE_URL
  export CUSTOM_API_KEY

  log "✓ Custom provider configured: $CUSTOM_PROVIDER_NAME"
}
