IMAGE := openclaw:local
GATEWAY := openclaw-gateway
CLI := openclaw-cli

.DEFAULT_GOAL := help

.PHONY: help build rebuild pnpm up down restart cli shell \
        logs logs-cli status inspect doctor \
        workspace-sync clean clean-workspace images prune

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-20s %s\n", $$1, $$2}'

# — Build —

pnpm: ## Compile TypeScript (pnpm build)
	pnpm build

build: ## Build the Docker image
	docker build -t $(IMAGE) .

rebuild: ## Build the Docker image (no cache)
	docker build --no-cache -t $(IMAGE) .

# — Container lifecycle —

up: ## Start the gateway in background
	docker compose up -d $(GATEWAY)

down: ## Stop and remove all containers
	docker compose down

restart: ## Recreate the gateway (down + up)
	docker compose down && docker compose up -d $(GATEWAY)

# — Interactive —

cli: ## Run an interactive CLI container (fresh, removed on exit)
	docker compose run --rm $(CLI)

shell: ## Open a bash shell in the gateway container
	docker compose exec $(GATEWAY) bash

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

# — OpenClaw commands —

doctor: ## Run openclaw doctor inside the gateway
	docker compose exec $(GATEWAY) node dist/index.js doctor

# — Workspace —

workspace-sync: ## Ensure workspace dir exists
	@mkdir -p $${OPENCLAW_WORKSPACE_DIR:?Set OPENCLAW_WORKSPACE_DIR}
	@echo "Workspace dir: $$OPENCLAW_WORKSPACE_DIR"

clean: ## Remove exited openclaw containers
	@ids=$$(docker ps -aq -f name=openclaw-openclaw- -f status=exited); \
	if [ -n "$$ids" ]; then docker rm $$ids; else echo "No exited openclaw containers."; fi

clean-workspace: ## Wipe workspace contents
	echo 'SAY THIS: rm -rf $${OPENCLAW_WORKSPACE_DIR:?Set OPENCLAW_WORKSPACE_DIR}/*'

# — Docker housekeeping —

images: ## List openclaw-related Docker images
	docker images openclaw

prune: ## Remove dangling images and stopped containers
	docker container prune -f && docker image prune -f
