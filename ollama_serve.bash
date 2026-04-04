#!/bin/bash
# Start Ollama + think:false proxy for Docker/OpenClaw
# Ollama on :11434 (all interfaces), proxy on :11435 injects think:false
# OpenClaw config points at :11435 via the proxy

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Start the think:false proxy in the background
node "$SCRIPT_DIR/ollama_proxy.cjs" 11435 11434 &
PROXY_PID=$!
echo "Ollama proxy started (PID $PROXY_PID) on :11435 -> :11434"

# Start Ollama on all interfaces (foreground)
export OLLAMA_HOST=0.0.0.0
export OLLAMA_KEEP_ALIVE=-1
trap "kill $PROXY_PID 2>/dev/null" EXIT
exec ollama serve
