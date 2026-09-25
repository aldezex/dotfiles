#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# Weekly (7-day) rate limit usage, when the client reports it (Claude.ai
# subscription usage; absent for API-key-only sessions, so this degrades
# gracefully to "7d: --").
WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
if [ -n "$WEEK_PCT" ]; then
  WEEK_STR=$(printf "7d: %.0f%%" "$WEEK_PCT")
  if [ -n "$WEEK_RESET" ]; then
    RESET_FMT=$(date -d "@$WEEK_RESET" "+%a %H:%M" 2>/dev/null)
    [ -n "$RESET_FMT" ] && WEEK_STR="$WEEK_STR (resets $RESET_FMT)"
  fi
else
  WEEK_STR="7d: --"
fi

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git --no-optional-locks rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git --no-optional-locks branch --show-current 2>/dev/null)"

echo -e "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH"
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ⏱️ ${MINS}m ${SECS}s | ${WEEK_STR}"
