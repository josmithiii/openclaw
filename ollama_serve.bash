#!/bin/bash
# Start Ollama + think:false proxy for Docker/OpenClaw
# Ollama on :11434 (all interfaces), proxy on :11435 injects think:false
# OpenClaw config points at :11435 via the proxy

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ollama_up=0
proxy_up=0
lsof -iTCP:11434 -sTCP:LISTEN -n -P >/dev/null 2>&1 && ollama_up=1
lsof -iTCP:11435 -sTCP:LISTEN -n -P >/dev/null 2>&1 && proxy_up=1

if [ "$ollama_up" = 1 ] && [ "$proxy_up" = 1 ]; then
    echo "*** ollama (:11434) and proxy (:11435) already running — nothing to do"
    exit 0
fi

if [ "$ollama_up" = 1 ] && [ "$proxy_up" = 0 ]; then
    echo "*** proxy down but ollama up — starting proxy only"
    exec node "$SCRIPT_DIR/ollama_proxy.cjs" 11435 11434
fi

if [ "$ollama_up" = 0 ] && [ "$proxy_up" = 1 ]; then
    echo "*** ollama down but proxy up on :11435 — kill the stale proxy first: make odown"
    exit 1
fi

# Start the think:false proxy in the background
node "$SCRIPT_DIR/ollama_proxy.cjs" 11435 11434 &
PROXY_PID=$!
echo "Ollama proxy started (PID $PROXY_PID) on :11435 -> :11434"

# Start Ollama on all interfaces (foreground)
export OLLAMA_HOST=0.0.0.0
export OLLAMA_KEEP_ALIVE=-1
trap "kill $PROXY_PID 2>/dev/null" EXIT
exec ollama serve
