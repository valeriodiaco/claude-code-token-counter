#!/usr/bin/env bash
set -euo pipefail

# Claude Code Token Counter — Installer
# Installs claude-token-log and claude-token-report to ~/.local/bin/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${1:-$HOME/.local/bin}"

GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}  Claude Code Token Counter — Install${NC}"
echo "  $(printf '%0.s=' {1..42})"
echo ""

mkdir -p "$INSTALL_DIR"

# Install executables
for cmd in claude-token-log claude-token-report; do
    cp "$SCRIPT_DIR/$cmd" "$INSTALL_DIR/$cmd"
    chmod +x "$INSTALL_DIR/$cmd"
    echo -e "  ${GREEN}Installed${NC} $cmd → $INSTALL_DIR/$cmd"
done

# Install library
LIB_DIR="$INSTALL_DIR"
cp "$SCRIPT_DIR/token-logger.lib.sh" "$LIB_DIR/token-logger.lib.sh"
echo -e "  ${GREEN}Installed${NC} token-logger.lib.sh → $LIB_DIR/token-logger.lib.sh"

# Check PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo ""
    echo -e "  ${DIM}Add to your shell config:${NC}"
    echo -e "  ${BOLD}export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
fi

echo ""
echo -e "${GREEN}Done!${NC} Usage:"
echo ""
echo "  # Run claude and log tokens:"
echo "  claude-token-log -p \"your prompt\""
echo ""
echo "  # View usage report:"
echo "  claude-token-report"
echo ""
echo "  # In your scripts (sourceable library):"
echo "  source $LIB_DIR/token-logger.lib.sh"
echo "  run_claude_with_logging --tag \"my-job\" -- -p \"prompt\""
echo ""
