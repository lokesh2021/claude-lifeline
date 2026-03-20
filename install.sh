#!/bin/bash

# ─────────────────────────────────────────
# Claude Lifeline — Installer
# https://github.com/lokesh2021/claude-lifeline
# ─────────────────────────────────────────

set -e

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${BOLD}Claude Lifeline${NC} — Installer"
echo -e "${DIM}─────────────────────────────────────${NC}"
echo ""

# ── Check dependencies ──
MISSING=()

if ! command -v jq &>/dev/null; then
  MISSING+=("jq")
fi

if ! command -v gh &>/dev/null; then
  MISSING+=("gh (GitHub CLI)")
fi

if ! command -v bc &>/dev/null; then
  MISSING+=("bc")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  echo -e "${YELLOW}Missing dependencies:${NC}"
  for dep in "${MISSING[@]}"; do
    echo -e "  ${RED}✗${NC} $dep"
  done
  echo ""
  echo -e "Install with: ${CYAN}brew install jq gh${NC} (macOS) or ${CYAN}apt install jq gh bc${NC} (Linux)"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# ── Ensure ~/.claude exists ──
mkdir -p "$HOME/.claude"

# ── Copy scripts ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cp "$SCRIPT_DIR/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"
echo -e "${GREEN}✓${NC} Installed statusline to ~/.claude/statusline.sh"

cp "$SCRIPT_DIR/report.sh" "$HOME/.claude/claude-lifeline-report"
chmod +x "$HOME/.claude/claude-lifeline-report"
echo -e "${GREEN}✓${NC} Installed weekly report to ~/.claude/claude-lifeline-report"

# ── Auto-configure settings.json ──
SETTINGS_FILE="$HOME/.claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  if jq -e '.statusLine' "$SETTINGS_FILE" &>/dev/null; then
    echo -e "${YELLOW}!${NC} statusLine already configured in settings.json — skipping"
  else
    TMP=$(mktemp)
    jq '. + {"statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh"}}' "$SETTINGS_FILE" > "$TMP"
    mv "$TMP" "$SETTINGS_FILE"
    echo -e "${GREEN}✓${NC} Added statusLine config to settings.json"
  fi
else
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
EOF
  echo -e "${GREEN}✓${NC} Created settings.json with statusLine config"
fi

# ── Optional: Environment variables ──
echo ""
echo -e "${BOLD}Optional Configuration${NC}"
echo -e "${DIM}These environment variables enable extra features.${NC}"
echo -e "${DIM}You can skip these and add them later to your shell profile.${NC}"
echo ""

# Admin API key
echo ""
echo -e "${DIM}An Anthropic Admin API key enables month-to-date API spend tracking.${NC}"
echo -e "${DIM}Get one at: https://console.anthropic.com/settings/admin-keys${NC}"
read -p "Anthropic Admin API key (leave blank to skip): " ADMIN_KEY
if [ -n "$ADMIN_KEY" ]; then
  EXPORT_KEY="export ANTHROPIC_ADMIN_API_KEY=\"$ADMIN_KEY\""
fi

# ── Write to shell profile ──
if [ -n "$EXPORT_KEY" ]; then
  echo ""

  if [ -f "$HOME/.zshrc" ]; then
    PROFILE="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    PROFILE="$HOME/.bashrc"
  elif [ -f "$HOME/.bash_profile" ]; then
    PROFILE="$HOME/.bash_profile"
  else
    PROFILE="$HOME/.zshrc"
  fi

  read -p "Add env vars to $PROFILE? (Y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "" >> "$PROFILE"
    echo "# Claude Lifeline" >> "$PROFILE"
    [ -n "$EXPORT_KEY" ] && echo "$EXPORT_KEY" >> "$PROFILE"
    echo -e "${GREEN}✓${NC} Added environment variables to $PROFILE"
    echo -e "${DIM}  Run: source $PROFILE${NC}"
  else
    echo ""
    echo "Add this to your shell profile manually:"
    [ -n "$EXPORT_KEY" ] && echo "  $EXPORT_KEY"
  fi
fi

echo ""
echo -e "${GREEN}${BOLD}Done!${NC} Restart Claude Code to see your statusline."
echo -e "${DIM}Weekly report: ~/.claude/claude-lifeline-report${NC}"
echo -e "${DIM}For help: https://github.com/lokesh2021/claude-lifeline${NC}"
echo ""
