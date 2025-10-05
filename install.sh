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
echo "Try: claudez --help"
