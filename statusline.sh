#!/bin/bash

# ─────────────────────────────────────────
# Claude Lifeline — Statusline + Obsidian Logger
# https://github.com/lokesh2021/claude-lifeline
# ─────────────────────────────────────────
#
# Environment variables:
#   OBSIDIAN_VAULT          — Path to your Obsidian vault (optional, enables logging)
#   ANTHROPIC_ADMIN_API_KEY — Anthropic Admin API key (optional, enables API spend tracking)
#
# Context rot thresholds based on Claude Opus 4.6 Context Management Spec v1.0:
#   0-50%: Healthy | 50-75%: Attention | 75-90%: Checkpoint | 90-95%: Critical | 95%+: Emergency

input=$(cat)

# ── Extract core fields from JSON ──
MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
SESSION_COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
SESSION_DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# ── Token count (sum all types) ──
CACHE_READ_TOKENS=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
USED_TOKENS=$(echo "$input" | jq -r '
  ((.context_window.current_usage.input_tokens // 0) +
   (.context_window.current_usage.cache_creation_input_tokens // 0) +
   (.context_window.current_usage.cache_read_input_tokens // 0) +
   (.context_window.current_usage.output_tokens // 0))
')

# ── Cache hit rate ──
if [ "$USED_TOKENS" -gt 0 ]; then
  CACHE_PCT=$(echo "$CACHE_READ_TOKENS $USED_TOKENS" | awk '{printf "%d", ($1/$2)*100}')
else
  CACHE_PCT="0"
fi

# ── Session duration ──
SESSION_TOTAL_SECS=$((SESSION_DURATION_MS / 1000))
SESSION_MINS=$((SESSION_TOTAL_SECS / 60))
if [ "$SESSION_MINS" -ge 60 ]; then
  DURATION_FMT="$((SESSION_MINS / 60))h$((SESSION_MINS % 60))m"
elif [ "$SESSION_MINS" -gt 0 ]; then
  DURATION_FMT="${SESSION_MINS}m"
else
  DURATION_FMT="${SESSION_TOTAL_SECS}s"
fi

# ── Cost per 1k tokens (real-time) ──
if [ "$USED_TOKENS" -gt 0 ] && [ "$(echo "$SESSION_COST > 0" | bc -l 2>/dev/null)" = "1" ]; then
  COST_PER_1K=$(echo "$SESSION_COST $USED_TOKENS" | awk '{printf "%.4f", ($1 / $2) * 1000}')
else
  COST_PER_1K="0.0000"
fi

SESSION_COST_FMT=$(printf "%.4f" "$SESSION_COST")
TOKEN_DISPLAY=$(echo "$USED_TOKENS" | awk '{printf "%dk", $1/1000}')

# ── Context window size in k ──
CTX_LIMIT_K=$(echo "$CTX_SIZE" | awk '{printf "%dk", $1/1000}')

# ── GitHub username (cached 60 min) ──
GH_CACHE="$HOME/.claude/.gh_user_cache"
if [ ! -f "$GH_CACHE" ] || [ $(find "$GH_CACHE" -mmin +60 2>/dev/null | wc -l) -gt 0 ]; then
  GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
  echo "$GH_USER" > "$GH_CACHE"
else
  GH_USER=$(cat "$GH_CACHE" 2>/dev/null || echo "")
fi

# ── Anthropic Admin API — total API key spend (cached 5 min) ──
API_COST_CACHE="$HOME/.claude/.api_cost_cache"
API_COST_AGE=$(find "$API_COST_CACHE" -mmin +5 2>/dev/null | wc -l)

if [ ! -f "$API_COST_CACHE" ] || [ "$API_COST_AGE" -gt 0 ]; then
  if [ -n "$ANTHROPIC_ADMIN_API_KEY" ]; then
    START_DATE=$(date -u +"%Y-%m-01T00:00:00Z")
    END_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    API_COST_RAW=$(curl -s \
      "https://api.anthropic.com/v1/organizations/cost_report?starting_at=${START_DATE}&ending_at=${END_DATE}" \
      --header "anthropic-version: 2023-06-01" \
      --header "x-api-key: $ANTHROPIC_ADMIN_API_KEY" 2>/dev/null)

    # API returns cents — divide by 100 to get dollars
    API_TOTAL=$(echo "$API_COST_RAW" | jq -r '
      [.data[].results[]?.amount // "0"] | map(tonumber) | add // 0
    ' 2>/dev/null | awk '{printf "%.2f", $1 / 100}')

    echo "${API_TOTAL:-0.00}" > "$API_COST_CACHE"
  else
    # Fallback: accumulate session costs locally if no Admin API key
    LOCAL_LOG="$HOME/.claude/.session_cost_total"
    PREV_TOTAL=$(cat "$LOCAL_LOG" 2>/dev/null || echo "0")
    echo "$PREV_TOTAL" > "$API_COST_CACHE"
  fi
fi

API_TOTAL=$(cat "$API_COST_CACHE" 2>/dev/null || echo "0.00")

# ── Build colored context progress bar ──
BAR_WIDTH=12
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))

# ANSI color codes based on threshold tier
if [ "$PCT" -ge 95 ]; then
  BAR_COLOR="\033[41;37;1m"  # red bg, white bold (flash effect)
elif [ "$PCT" -ge 90 ]; then
  BAR_COLOR="\033[31m"       # red
elif [ "$PCT" -ge 75 ]; then
  BAR_COLOR="\033[38;5;208m" # orange
elif [ "$PCT" -ge 50 ]; then
  BAR_COLOR="\033[33m"       # yellow
else
  BAR_COLOR="\033[32m"       # green
fi
RESET="\033[0m"
DIM="\033[2m"

FILLED_STR=""
EMPTY_STR=""
[ "$FILLED" -gt 0 ] && FILLED_STR=$(printf "%${FILLED}s" | tr ' ' '█')
[ "$EMPTY"  -gt 0 ] && EMPTY_STR=$(printf "%${EMPTY}s" | tr ' ' '░')
BAR="${BAR_COLOR}${FILLED_STR}${RESET}${DIM}${EMPTY_STR}${RESET}"

# ── Context rot status (Claude Opus 4.6 Context Management Spec v1.0) ──
if [ "$PCT" -ge 95 ]; then
  STATUS="${BAR_COLOR}◉◉ EMERGENCY${RESET}"
elif [ "$PCT" -ge 90 ]; then
  STATUS="${BAR_COLOR}● CRITICAL${RESET}"
elif [ "$PCT" -ge 75 ]; then
  STATUS="${BAR_COLOR}● CHECKPOINT${RESET}"
elif [ "$PCT" -ge 50 ]; then
  STATUS="${BAR_COLOR}● ATTENTION${RESET}"
else
  STATUS="${BAR_COLOR}● healthy${RESET}"
fi

# ── Git branch + dirty state ──
WORK_DIR=$(echo "$input" | jq -r '.workspace.current_dir // "."')
GIT_BRANCH=$(git -C "$WORK_DIR" branch --show-current 2>/dev/null || echo "")
GIT_DIRTY=$(git -C "$WORK_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
DIRTY_MARK=""
[ "${GIT_DIRTY:-0}" -gt 0 ] && DIRTY_MARK="*"
GIT_PREFIX=""
[ -n "$GIT_BRANCH" ] && GIT_PREFIX=" | ⎇ ${GIT_BRANCH}${DIRTY_MARK}"

# ── GitHub prefix ──
GH_PREFIX=""
[ -n "$GH_USER" ] && GH_PREFIX="@${GH_USER} | "

# ── Output to statusline (two rows) ──
# Row 1: user | model | [colored bar] pct% | health status | branch
# Row 2: $/1k · tokens/limit | session cost · API cost
ROW1="${GH_PREFIX}${MODEL} | ${BAR} ${PCT}%% | ${STATUS}${GIT_PREFIX}"
ROW2="${DIM}\$${COST_PER_1K}/1k · ${TOKEN_DISPLAY}/${CTX_LIMIT_K} · cache:${CACHE_PCT}%%${RESET}  ${DIM}\$${SESSION_COST_FMT} session · \$${API_TOTAL} API · ${DURATION_FMT}${RESET}"
printf "${ROW1}\n${ROW2}\n"

# ── Daily token & cost tracker ──
_LIFELINE_DIR="$HOME/.claude/.lifeline"
mkdir -p "$_LIFELINE_DIR"
_LOG_DATE=$(date +"%Y-%m-%d")
_DAILY_LOG="${_LIFELINE_DIR}/${_LOG_DATE}.tsv"
_STATE_FILE="${_LIFELINE_DIR}/.state"
_NOW_EPOCH=$(date +%s)

# Read last state: "last_cost last_epoch"
_LAST_COST=$(awk '{print $1}' "$_STATE_FILE" 2>/dev/null || echo "0")
_LAST_EPOCH=$(awk '{print $2}' "$_STATE_FILE" 2>/dev/null || echo "0")

# Log if: 5+ min elapsed, cost grew $0.005+, or new session detected (cost reset)
_LOG=0
[ $((_NOW_EPOCH - _LAST_EPOCH)) -ge 300 ] && _LOG=1
awk "BEGIN{exit !(($SESSION_COST+0) - ($_LAST_COST+0) >= 0.005)}" 2>/dev/null && _LOG=1
awk "BEGIN{exit !(($_LAST_COST+0) > 0.005 && ($SESSION_COST+0) < 0.001)}" 2>/dev/null && _LOG=1

if [ "$_LOG" = "1" ]; then
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$(date +%H:%M:%S)" "$MODEL" "$USED_TOKENS" "$SESSION_COST_FMT" "$CACHE_PCT" "${GIT_BRANCH:-—}" \
    >> "$_DAILY_LOG"
  printf "%s %s\n" "$SESSION_COST_FMT" "$_NOW_EPOCH" > "$_STATE_FILE"
fi

# ── Write to Obsidian vault ──
if [ -n "$OBSIDIAN_VAULT" ] && [ -d "$OBSIDIAN_VAULT" ]; then
  OBSIDIAN_DIR="${OBSIDIAN_VAULT}/Claude Sessions"
  mkdir -p "$OBSIDIAN_DIR"

  DATE=$(date +"%Y-%m-%d")
  TIME=$(date +"%H:%M:%S")
  OBSIDIAN_FILE="${OBSIDIAN_DIR}/Claude Sessions — ${DATE}.md"

  # Create file with header if it doesn't exist
  if [ ! -f "$OBSIDIAN_FILE" ]; then
    cat > "$OBSIDIAN_FILE" << EOF
# Claude Code Sessions — ${DATE}

> Auto-generated by Claude Code statusline. Updates in real-time.

## Today's Summary

| Time | Model | Context% | \$/1k tokens | Session \$ | Tokens | Git Branch | Status |
|------|-------|----------|-------------|-----------|--------|------------|--------|
EOF
  fi

  # Plaintext status for Obsidian (no ANSI)
  if [ "$PCT" -ge 95 ]; then OBS_STATUS="EMERGENCY"
  elif [ "$PCT" -ge 90 ]; then OBS_STATUS="CRITICAL"
  elif [ "$PCT" -ge 75 ]; then OBS_STATUS="CHECKPOINT"
  elif [ "$PCT" -ge 50 ]; then OBS_STATUS="ATTENTION"
  else OBS_STATUS="healthy"
  fi

  # Append new row (avoids duplicate timestamps by checking last line)
  LAST_TIME=$(tail -1 "$OBSIDIAN_FILE" | grep -o "^| [0-9:]*" | tr -d '| ')
  if [ "$LAST_TIME" != "$TIME" ]; then
    echo "| $TIME | $MODEL | ${PCT}% | \$$COST_PER_1K | \$$SESSION_COST_FMT | ~$TOKEN_DISPLAY | ${GIT_BRANCH:-—} | $OBS_STATUS |" >> "$OBSIDIAN_FILE"
  fi

  # Update/append API total footer
  grep -v "API Key Total" "$OBSIDIAN_FILE" > /tmp/cc_obs_tmp && mv /tmp/cc_obs_tmp "$OBSIDIAN_FILE"
  echo "" >> "$OBSIDIAN_FILE"
  echo "**API Key Total (month-to-date):** \$${API_TOTAL}" >> "$OBSIDIAN_FILE"
fi
