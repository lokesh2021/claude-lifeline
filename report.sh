#!/bin/bash

# ─────────────────────────────────────────
# Claude Lifeline — Weekly Report
# https://github.com/lokesh2021/claude-lifeline
# ─────────────────────────────────────────
#
# Usage: claude-lifeline-report
#
# Reads ~/.claude/.lifeline/YYYY-MM-DD.tsv logs written by claude-lifeline
# and prints a weekly summary table to the terminal.
#
# TSV columns: time | model | tokens | session_cost | cache_pct | branch

LIFELINE_DIR="$HOME/.claude/.lifeline"

BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# ── Cross-platform date offset ──
_date_offset() {
  local days_ago=$1 fmt=$2
  if date -v-1d +%Y-%m-%d &>/dev/null 2>&1; then
    date -v-${days_ago}d +"$fmt"          # BSD (macOS)
  else
    date -d "-${days_ago} days" +"$fmt"   # GNU (Linux)
  fi
}

# ── Header ──
echo ""
printf "${BOLD}Claude Lifeline — Weekly Report${RESET}\n"
printf "${DIM}%s – %s${RESET}\n" "$(_date_offset 6 '%b %d')" "$(date +'%b %d, %Y')"
printf "${DIM}%s${RESET}\n" "────────────────────────────────────────────────────"
echo ""
printf "${BOLD}%-15s %-10s %-10s %-10s %s${RESET}\n" "Day" "Tokens" "Cost" "Cache%" "Sessions"
printf "${DIM}%s${RESET}\n" "────────────────────────────────────────────────────"

WEEK_TOKENS=0
WEEK_COST="0"
WEEK_SESSIONS=0
WEEK_CACHE_SUM=0
WEEK_CACHE_DAYS=0
PEAK_COST="0"
PEAK_DAY=""
ALL_BRANCHES=""
ALL_MODELS=""

for i in 6 5 4 3 2 1 0; do
  DATE=$(_date_offset "$i" '%Y-%m-%d')
  LABEL=$(_date_offset "$i" '%a %b %d')
  LOG="$LIFELINE_DIR/${DATE}.tsv"

  if [ -f "$LOG" ] && [ -s "$LOG" ]; then
    # Aggregate from TSV with awk
    # Session detection: cost drops from >0.005 to <0.001 = new session
    read DAY_COST DAY_TOKENS DAY_CACHE DAY_SESSIONS < <(awk -F'\t' '
      BEGIN { total=0; peak=0; prev=0; sess=1; max_tok=0; csum=0; n=0 }
      {
        cost=$4+0; tok=$3+0; cache=$5+0
        if (tok  > max_tok) max_tok = tok
        csum += cache; n++
        if (prev > 0.005 && cost < 0.001) { total += prev; sess++; peak=0 }
        if (cost > peak) peak = cost
        prev = cost
      }
      END {
        total += peak
        avg = (n > 0) ? int(csum/n) : 0
        printf "%.4f %d %d %d\n", total, max_tok, avg, sess
      }
    ' "$LOG")

    TOKENS_K=$(awk "BEGIN{printf \"%dk\", $DAY_TOKENS/1000}")
    printf "%-15s %-10s %-10s %-10s %s\n" \
      "$LABEL" "$TOKENS_K" "\$$DAY_COST" "${DAY_CACHE}%" "$DAY_SESSIONS"

    WEEK_TOKENS=$((WEEK_TOKENS + DAY_TOKENS))
    WEEK_COST=$(awk "BEGIN{printf \"%.4f\", $WEEK_COST + $DAY_COST}")
    WEEK_SESSIONS=$((WEEK_SESSIONS + DAY_SESSIONS))
    WEEK_CACHE_SUM=$((WEEK_CACHE_SUM + DAY_CACHE))
    WEEK_CACHE_DAYS=$((WEEK_CACHE_DAYS + 1))

    if awk "BEGIN{exit !($DAY_COST > $PEAK_COST)}"; then
      PEAK_COST="$DAY_COST"
      PEAK_DAY="$LABEL"
    fi

    ALL_BRANCHES="$ALL_BRANCHES$(cut -f6 "$LOG")\n"
    ALL_MODELS="$ALL_MODELS$(cut -f2 "$LOG")\n"
  else
    printf "%-15s %-10s %-10s %-10s %s\n" "$LABEL" "—" "—" "—" "0"
  fi
done

printf "${DIM}%s${RESET}\n" "────────────────────────────────────────────────────"

WEEK_TOKENS_K=$(awk "BEGIN{printf \"%dk\", $WEEK_TOKENS/1000}")
AVG_CACHE=0
[ "$WEEK_CACHE_DAYS" -gt 0 ] && AVG_CACHE=$((WEEK_CACHE_SUM / WEEK_CACHE_DAYS))
printf "${BOLD}%-15s %-10s %-10s %-10s %s${RESET}\n" \
  "Weekly Total" "$WEEK_TOKENS_K" "\$$WEEK_COST" "${AVG_CACHE}% avg" "$WEEK_SESSIONS sessions"

# ── Peak day ──
if [ -n "$PEAK_DAY" ]; then
  echo ""
  printf "Peak day: ${CYAN}%s${RESET} (\$%s)\n" "$PEAK_DAY" "$PEAK_COST"
fi

# ── Top branches ──
echo ""
printf "${DIM}Top branches:${RESET}\n"
echo -e "$ALL_BRANCHES" | grep -v -e "^—$" -e "^$" | sort | uniq -c | sort -rn | head -5 | \
  awk '{printf "  %s×  %s\n", $1, $2}'

# ── Models ──
echo ""
printf "${DIM}Models used:${RESET}\n"
echo -e "$ALL_MODELS" | grep -v "^$" | sort -u | while read -r m; do
  COUNT=$(echo -e "$ALL_MODELS" | grep -c "^${m}$" 2>/dev/null || echo 0)
  printf "  %s  (%s entries)\n" "$m" "$COUNT"
done

echo ""
