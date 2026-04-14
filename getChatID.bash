#!/bin/bash
# Print the most recent Telegram chat ID from BBBot logs or session state
# Strips ANSI codes before searching

ID=$(docker logs openclaw-openclaw-gateway-1 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -o 'chat=[0-9]*' | tail -1 | cut -d= -f2)

if [ -z "$ID" ]; then
  # Fallback: check sessions.json for telegram direct chat IDs
  ID=$(cat ~/.openclaw/agents/main/sessions/sessions.json 2>/dev/null | grep -o 'telegram:direct:[0-9]*' | head -1 | cut -d: -f3)
fi

if [ -z "$ID" ]; then
  echo "*** No Telegram chat ID found — send a message to @MyBot first" >&2
  exit 1
fi

echo "$ID"
