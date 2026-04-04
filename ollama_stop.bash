#!/bin/bash
# Stop Ollama to free up the Gemma 4 ~28 GB for other things

ollama stop gemma4:31b   # unloads model from memory
# killall ollama           # stops the server + proxy

# The stop command gracefully unloads the model first. If you just
# want to free the memory but keep the server running,
#   ollama stop gemma4:31b
# alone is enough.
