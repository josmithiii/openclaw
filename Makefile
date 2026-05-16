IMAGE := openclaw:local
GATEWAY := openclaw-gateway
CLI := openclaw-cli
AGENT ?= main

.DEFAULT_GOAL := help

CLAUDE_HOST_DIR ?= $(HOME)/.openclaw-claude
CLAUDE_MODEL ?= claude-cli/claude-opus-4-7
BUILD_ARGS ?= --build-arg OPENCLAW_INSTALL_CLAUDE_CLI=1

.PHONY: help build rebuild pnpm up down restart cli chat task shell tui \
        oup odown ostatus \
        claude-setup claude-login claude-wire \
        logs logs-cli status inspect doctor lsws lsvs lsvsns sessions \
        workspace-sync clean clean-workspace images prune

help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-20s %s\n", $$1, $$2}'

# — Build —

pnpm: ## Compile TypeScript (pnpm build)
	pnpm build

build: ## Build the Docker image (BUILD_ARGS includes claude-cli by default)
	docker build $(BUILD_ARGS) -t $(IMAGE) .

rebuild: ## Build the Docker image (no cache)
	docker build --no-cache $(BUILD_ARGS) -t $(IMAGE) .

# — Container lifecycle —

up: ## Start the gateway in background
	docker compose up -d $(GATEWAY)

oup: ## Start the ollama server (idempotent)
	./ollama_serve.bash &

odown: ## Stop the ollama server and think:false proxy
	@pids=$$(lsof -t -iTCP:11434,11435 -sTCP:LISTEN 2>/dev/null); \
	if [ -n "$$pids" ]; then kill $$pids && echo "ollama/proxy stopped (pids: $$pids)"; \
	else echo "ollama not running"; fi

ostatus: ## Show whether ollama and proxy are listening
	@for port in 11434 11435; do \
		if lsof -iTCP:$$port -sTCP:LISTEN -nP >/dev/null 2>&1; then \
			echo ":$$port UP  ($$(lsof -iTCP:$$port -sTCP:LISTEN -nP | awk 'NR==2 {print $$1, "pid", $$2}'))"; \
		else echo ":$$port DOWN"; fi; \
	done

down: ## Stop and remove all containers
	docker compose down

restart: ## Recreate the gateway (down + up)
	docker compose down && docker compose up -d $(GATEWAY)

# — Interactive —

cli: ## Run an interactive CLI container (fresh, removed on exit)
	docker compose run --rm $(CLI)

shell: ## Open a bash shell in the gateway container
	docker compose exec $(GATEWAY) bash

tui: ## Start the openclaw CLI/TUI inside the running gateway container
	docker compose exec $(GATEWAY) node dist/index.js tui

# — Anthropic Pro/Max plan (claude-cli backend) —

claude-setup: ## One-shot: ensure dirs/mount, OAuth login, wire to OpenClaw, set primary model
	@mkdir -p $(CLAUDE_HOST_DIR)
	@if ! docker compose exec $(GATEWAY) test -d /home/node/.claude 2>/dev/null; then \
		echo ">> .claude mount not present in running container — run: make down && make up"; exit 1; \
	fi
	@if ! docker compose exec $(GATEWAY) sh -c 'command -v claude' >/dev/null 2>&1; then \
		echo ">> claude CLI not in image — rebuild with: make build (or make rebuild)"; exit 1; \
	fi
	@echo ">> Step 1/3: Claude OAuth (paste the URL into your Mac browser, then paste the code back)"
	$(MAKE) claude-login
	@echo ">> Step 2/3: wire claude-cli into OpenClaw"
	$(MAKE) claude-wire
	@echo ">> Step 3/3: set primary model to $(CLAUDE_MODEL)"
	docker compose exec $(GATEWAY) node dist/index.js config set agents.defaults.model.primary $(CLAUDE_MODEL)
	@echo ">> Done. Run 'make tui' to use it."

claude-login: ## Run `claude` in the gateway container so you can /login (interactive OAuth)
	docker compose exec -it $(GATEWAY) claude

claude-wire: ## Tell OpenClaw to use the host's logged-in Claude CLI (no API key needed)
	docker compose exec $(GATEWAY) node dist/index.js models auth login --provider anthropic --method cli --set-default

# — Observe —

logs: ## Tail gateway logs
	docker compose logs -f $(GATEWAY)

logs-cli: ## Tail CLI logs
	docker compose logs -f $(CLI)

status: ## Show container and health status
	docker compose ps

inspect: ## Show container mounts
	@for svc in $(GATEWAY) $(CLI); do \
		echo "=== $$svc ==="; \
		docker inspect openclaw-$$svc-1 --format '{{range .Mounts}}  {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' 2>/dev/null || echo "  (not running)"; \
	done

lsws: ## List workspace contents inside the gateway
	docker compose exec $(GATEWAY) ls /home/node/.openclaw/workspace/

lsvs: ## List visible services using lsof
	lsof -iTCP -sTCP:LISTEN -nP | grep -E '127\.0\.0\.1|\*:'

lsvsns: ## List visible services using netstat
	netstat -anv -p tcp | grep LISTEN

# — OpenClaw commands —

doctor dr: ## Run openclaw doctor inside the gateway
	docker compose exec $(GATEWAY) node dist/index.js doctor

chat: ## Open interactive CLI container (alias for `cli`)
	docker compose run --rm $(CLI)

task: ## One-shot agent query (usage: make task Q="summarize this codebase")
	docker compose exec $(GATEWAY) node dist/index.js agent -m "$(Q)"

sessions: ## List recent session files for AGENT (default: main)
	docker compose exec $(GATEWAY) ls -lt /home/node/.openclaw/agents/$(AGENT)/sessions/

# — Workspace —

workspace-sync: ## Ensure workspace dir exists
	@mkdir -p $${OPENCLAW_WORKSPACE_DIR:?Set OPENCLAW_WORKSPACE_DIR}
	@echo "Workspace dir: $$OPENCLAW_WORKSPACE_DIR"

clean: ## Remove exited openclaw containers
	@ids=$$(docker ps -aq -f name=openclaw-openclaw- -f status=exited); \
	if [ -n "$$ids" ]; then docker rm $$ids; else echo "No exited openclaw containers."; fi

clean-workspace: ## Wipe workspace contents
	echo 'SAY THIS: rm -rf $${OPENCLAW_WORKSPACE_DIR:?Set OPENCLAW_WORKSPACE_DIR}/*'

# — MLX (host-side; shared wrapper at ~/bin/mlx_serve) —

mup: ## Start MLX (default: Gemma 4 31B 4-bit; idempotent)
	$$HOME/bin/mlx_serve &

mup3: ## Swap MLX to Gemma 3 27B 4-bit
	@$(MAKE) mdown && $$HOME/bin/mlx_serve mlx-community/gemma-3-27b-it-4bit &

mup3s: ## Swap MLX to Gemma 3 12B 4-bit (small/fast)
	@$(MAKE) mdown && $$HOME/bin/mlx_serve mlx-community/gemma-3-12b-it-4bit &

mup4f: ## Swap MLX to Gemma 4 31B bf16 (full precision, ~60 GB)
	@$(MAKE) mdown && $$HOME/bin/mlx_serve mlx-community/gemma-4-31b-it-bf16 &

mdown: ## Stop the host MLX server
	@pids=$$(lsof -t -iTCP:8765 -sTCP:LISTEN 2>/dev/null); \
	if [ -n "$$pids" ]; then kill $$pids && echo "mlx stopped (pids: $$pids)"; \
	else echo "mlx not running"; fi

mstatus: ## Show whether MLX server is listening
	@if lsof -iTCP:8765 -sTCP:LISTEN -nP >/dev/null 2>&1; then \
		echo ":8765 UP  ($$(lsof -iTCP:8765 -sTCP:LISTEN -nP | awk 'NR==2 {print $$1, "pid", $$2}'))"; \
	else echo ":8765 DOWN"; fi

# — Docker housekeeping —

images: ## List openclaw-related Docker images
	docker images openclaw

prune: ## Remove dangling images and stopped containers
	docker container prune -f && docker image prune -f
