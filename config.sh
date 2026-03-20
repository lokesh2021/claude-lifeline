#!/bin/bash

# ─────────────────────────────────────────
# Claude Lifeline — Configure Display
# https://github.com/lokesh2021/claude-lifeline
# ─────────────────────────────────────────
#
# Run anytime to change what's shown in the statusline:
#   claude-lifeline-config

CONFIG_DIR="$HOME/.claude/.lifeline"
CONFIG_FILE="$CONFIG_DIR/config"
mkdir -p "$CONFIG_DIR"

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
NC='\033[0m'

# ── yn <label> <var> <default>  →  prints "VAR=value" to stdout ──
yn() {
  local label=$1 var=$2 default=$3
  local bracket
  [ "$default" = "1" ] && bracket="Y/n" || bracket="y/N"
  printf "    %-44s [%s] " "$label" "$bracket"
  read -r -n 1 reply
  echo ""
  case "$reply" in
    [Yy]) echo "${var}=1" ;;
    [Nn]) echo "${var}=0" ;;
    *)    echo "${var}=${default}" ;;
  esac
}

# ── Main config loop ──
while true; do
  echo ""
  echo -e "${BOLD}Claude Lifeline${NC} — Configure Display"
  echo -e "${DIM}─────────────────────────────────────────${NC}"
  echo ""
  echo "How much do you want to see in your statusline?"
  echo ""
  echo -e "  ${BOLD}1)${NC} Simple"
  echo -e "     ${DIM}Claude Sonnet 4.6  ████░░░░░░░░ 33%%  ● healthy${NC}"
  echo ""
  echo -e "  ${BOLD}2)${NC} Moderate"
  echo -e "     ${DIM}Claude Sonnet 4.6  ████░░░░░░░░ 33%%  ● healthy  ⎇ main${NC}"
  echo -e "     ${DIM}\$0.0031 session · 14m${NC}"
  echo ""
  echo -e "  ${BOLD}3)${NC} All  ${DIM}(default)${NC}"
  echo -e "     ${DIM}@you  Claude Sonnet 4.6  ████░░░░░░░░ 33%%  ● healthy  ⎇ main*${NC}"
  echo -e "     ${DIM}\$0.0001/1k · 24k/200k · cache:16%%  \$0.0031 session · \$1.23 API · 14m${NC}"
  echo ""
  echo -e "  ${BOLD}4)${NC} Custom — pick exactly what to show"
  echo ""
  read -p "Select [1-4] (default 3): " -n 1 CHOICE
  echo ""
  echo ""

  case "$CHOICE" in
    1)
      printf "SHOW_GH_USER=0\nSHOW_MODEL=1\nSHOW_BAR=1\nSHOW_PCT=1\nSHOW_STATUS=1\nSHOW_BRANCH=0\nSHOW_COST_PER_1K=0\nSHOW_TOKENS=0\nSHOW_CACHE=0\nSHOW_SESSION_COST=0\nSHOW_API_COST=0\nSHOW_DURATION=0\n" > "$CONFIG_FILE"
      echo -e "  ${GREEN}✓${NC} Simple mode saved."
      ;;

    2)
      printf "SHOW_GH_USER=0\nSHOW_MODEL=1\nSHOW_BAR=1\nSHOW_PCT=1\nSHOW_STATUS=1\nSHOW_BRANCH=1\nSHOW_COST_PER_1K=0\nSHOW_TOKENS=1\nSHOW_CACHE=0\nSHOW_SESSION_COST=1\nSHOW_API_COST=0\nSHOW_DURATION=1\n" > "$CONFIG_FILE"
      echo -e "  ${GREEN}✓${NC} Moderate mode saved."
      ;;

    4)
      echo -e "  Configure each data point — press Enter to keep the default in [brackets]:"
      echo ""
      {
        yn "GitHub username  (@you)"                        SHOW_GH_USER       1
        yn "Model name"                                     SHOW_MODEL         1
        yn "Context bar  (████░░░░░░░░)"                   SHOW_BAR           1
        yn "Context percentage"                             SHOW_PCT           1
        yn "Health status  (healthy / ATTENTION / …)"      SHOW_STATUS        1
        yn "Git branch + dirty indicator  (⎇ main*)"       SHOW_BRANCH        1
        yn "Cost per 1k tokens"                             SHOW_COST_PER_1K   1
        yn "Token count / context limit  (45k/200k)"        SHOW_TOKENS        1
        yn "Cache hit rate  (cache:67%%)"                   SHOW_CACHE         1
        yn "Session cost"                                   SHOW_SESSION_COST  1
        yn "API spend month-to-date"                        SHOW_API_COST      1
        yn "Session duration  (14m)"                        SHOW_DURATION      1
      } > "$CONFIG_FILE"
      echo ""
      echo -e "  ${GREEN}✓${NC} Custom config saved."
      ;;

    *)
      printf "SHOW_GH_USER=1\nSHOW_MODEL=1\nSHOW_BAR=1\nSHOW_PCT=1\nSHOW_STATUS=1\nSHOW_BRANCH=1\nSHOW_COST_PER_1K=1\nSHOW_TOKENS=1\nSHOW_CACHE=1\nSHOW_SESSION_COST=1\nSHOW_API_COST=1\nSHOW_DURATION=1\n" > "$CONFIG_FILE"
      echo -e "  ${GREEN}✓${NC} All mode saved."
      ;;
  esac

  echo ""
  read -p "  Change your selection? [y/N] " -n 1 REDO
  echo ""
  [[ "$REDO" =~ ^[Yy]$ ]] || break

done

echo ""
echo -e "${DIM}Restart Claude Code to apply your changes.${NC}"
echo -e "${DIM}Run ${NC}claude-lifeline-config${DIM} anytime to update preferences.${NC}"
echo ""
