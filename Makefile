# Claude Code — local observability stack (Docker Compose)
# Copy this folder anywhere and run `make up`. macOS (Apple Silicon) + Docker Desktop.

SHELL := /bin/bash
COMPOSE := docker compose
SCRIPTS := ./scripts

.DEFAULT_GOAL := help

.PHONY: help up down restart status check logs ps patch unpatch clean pull config urls

help: ## Show this help
	@echo "Claude Code observability stack (Docker)"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quickstart:  make up   then open http://localhost:3000"

up: ## Preflight, patch Claude settings, start the stack, verify health
	@bash $(SCRIPTS)/preflight.sh
	@echo "==> Patching Claude Code settings (~/.claude/settings.json)"
	@python3 $(SCRIPTS)/patch-claude-settings.py
	@echo "==> Starting stack"
	@$(COMPOSE) up -d
	@bash $(SCRIPTS)/healthcheck.sh --wait || true
	@$(MAKE) --no-print-directory urls

down: ## Stop the stack (keeps data volumes)
	@$(COMPOSE) down

restart: ## Restart all services
	@$(COMPOSE) restart

status: ## Show container status + one-shot health report
	@$(COMPOSE) ps
	@echo ""
	@bash $(SCRIPTS)/healthcheck.sh || true

check: ## Health-check the stack without starting it (is grafana/otel/loki up?)
	@bash $(SCRIPTS)/healthcheck.sh

ps: ## List stack containers
	@$(COMPOSE) ps

logs: ## Tail logs from all services (Ctrl-C to exit)
	@$(COMPOSE) logs -f

pull: ## Pull pinned images
	@$(COMPOSE) pull

config: ## Validate and render the compose config
	@$(COMPOSE) config

patch: ## (Re)apply the Claude Code OTEL settings patch only
	@python3 $(SCRIPTS)/patch-claude-settings.py

unpatch: ## Remove the Claude Code OTEL settings patch
	@python3 $(SCRIPTS)/patch-claude-settings.py --revert

clean: ## Stop the stack, DELETE data volumes, and revert Claude settings
	@$(COMPOSE) down -v
	@python3 $(SCRIPTS)/patch-claude-settings.py --revert
	@echo "==> Removed containers, volumes, and Claude OTEL settings."

urls:
	@echo ""
	@echo "    Grafana:     http://localhost:3000  (anonymous Viewer; admin/admin to edit)"
	@echo "      Claude Code:    http://localhost:3000/d/claude-code-metrics"
	@echo "      Model Usage:    http://localhost:3000/d/claude-code-deep-usage"
	@echo "      Skills Usage:   http://localhost:3000/d/claude-code-skills"
	@echo "    Prometheus:  http://localhost:9090"
	@echo "    Loki:        http://localhost:3100"
	@echo "    OTLP intake: http://127.0.0.1:4318  (Claude Code -> collector)"
	@echo ""
	@echo "    RESTART Claude Code so the new OTEL env vars take effect."
