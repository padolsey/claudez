#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"

echo "claudez installer"
echo "================="
echo ""

# Check if we need sudo
if [ -w "$INSTALL_DIR" ]; then
  SUDO=""
else
  SUDO="sudo"
  echo "Note: Will use sudo for installation to $INSTALL_DIR"
fi

# Create symlinks
echo "Creating symlinks..."
$SUDO ln -sf "$SCRIPT_DIR/bin/claudez" "$INSTALL_DIR/claudez"
$SUDO ln -sf "$SCRIPT_DIR/bin/cz" "$INSTALL_DIR/cz"

echo ""
echo "✅ Installation complete!"
echo ""
echo "Commands available:"
echo "  claudez - Main command (short for Claude Zones)"
echo "  cz      - Short alias"
echo ""

# Optional API key setup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Optional: API Key Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "claudez supports multiple AI providers:"
echo "  • Anthropic (Claude Code) - Recommended for beginners"
echo "  • OpenRouter - 75+ models, free tier available"
echo "  • OpenAI - GPT-4o, o1, etc."
echo ""
echo "You can set up keys now or later when creating your first zone."
echo ""
read -p "Would you like to set up API keys now? [y/N] " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
  CONFIG_DIR="${HOME}/.config/claudez"
  mkdir -p "$CONFIG_DIR"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "1. Anthropic API Key (for Claude Code)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Get your key at: https://console.anthropic.com/"
  echo ""
  read -p "Enter your Anthropic API key (or press Enter to skip): " -s ANTHROPIC_KEY
  echo

  if [ -n "$ANTHROPIC_KEY" ]; then
    # Validate format
    if [[ "$ANTHROPIC_KEY" =~ ^sk-ant- ]]; then
      echo "$ANTHROPIC_KEY" > "$CONFIG_DIR/anthropic_key"
      chmod 600 "$CONFIG_DIR/anthropic_key"
      echo "✅ Anthropic key saved to $CONFIG_DIR/anthropic_key"
    else
      echo "⚠️  Warning: Key doesn't match expected format (sk-ant-...)"
      echo "   Key was NOT saved. Please check and set it manually later."
    fi
  else
    echo "⏭️  Skipped Anthropic key"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "2. OpenRouter API Key (for 75+ models)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Get your FREE key at: https://openrouter.ai/keys"
  echo ""
  read -p "Enter your OpenRouter API key (or press Enter to skip): " -s OPENROUTER_KEY
  echo

  if [ -n "$OPENROUTER_KEY" ]; then
    # Validate format
    if [[ "$OPENROUTER_KEY" =~ ^sk-or-v1- ]]; then
      echo "$OPENROUTER_KEY" > "$CONFIG_DIR/openrouter_key"
      chmod 600 "$CONFIG_DIR/openrouter_key"
      echo "✅ OpenRouter key saved to $CONFIG_DIR/openrouter_key"
    else
      echo "⚠️  Warning: Key doesn't match expected format (sk-or-v1-...)"
      echo "   Key was NOT saved. Please check and set it manually later."
    fi
  else
    echo "⏭️  Skipped OpenRouter key"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "3. OpenAI API Key (for GPT-4o, o1, etc.)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Get your key at: https://platform.openai.com/api-keys"
  echo ""
  read -p "Enter your OpenAI API key (or press Enter to skip): " -s OPENAI_KEY
  echo

  if [ -n "$OPENAI_KEY" ]; then
    # Validate format
    if [[ "$OPENAI_KEY" =~ ^sk- ]]; then
      echo "$OPENAI_KEY" > "$CONFIG_DIR/openai_key"
      chmod 600 "$CONFIG_DIR/openai_key"
      echo "✅ OpenAI key saved to $CONFIG_DIR/openai_key"
    else
      echo "⚠️  Warning: Key doesn't match expected format (sk-...)"
      echo "   Key was NOT saved. Please check and set it manually later."
    fi
  else
    echo "⏭️  Skipped OpenAI key"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "API Key Setup Complete!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  echo ""
  echo "No problem! You can set up API keys later by:"
  echo "  • Running: cz myapp (you'll be prompted)"
  echo "  • Manually: echo 'sk-ant-...' > ~/.config/claudez/anthropic_key"
fi

echo ""
echo "Next steps:"
echo "  1. Run: ./setup-traefik.sh"
echo "  2. Try: claudez --help"
