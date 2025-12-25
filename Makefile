.PHONY: all build up down stop start restart logs ps clean fclean re help hosts bonus-build bonus-up bonus-down bonus-logs

PROJECT_NAME := inception
DOCKER_COMPOSE := docker compose -f srcs/docker-compose.yml
DATA_DIR := /home/mel-bouh/data
DATA_BONUS_DIR := /home/mel-bouh/data/uptime-monitor
DOMAIN := mel-bouh.42.fr

# Default target - just run 'make' to start everything
all : up

help:
	@echo "Inception Docker Project"
	@echo "======================="
	@echo "Available commands:"
	@echo ""
	@echo "MAIN SERVICES:"
	@echo "  make             - Build and start containers (default)"
	@echo "  make build       - Build all Docker images"
	@echo "  make up          - Build and start containers in detached mode"
	@echo "  make down        - Stop and remove containers"
	@echo "  make stop        - Stop containers without removing them"
	@echo "  make start       - Start existing containers"
	@echo "  make restart     - Restart containers"
	@echo "  make logs        - View container logs"
	@echo "  make ps          - List running containers"
	@echo "  make clean       - Remove containers, volumes, and networks"
	@echo "  make fclean      - Full clean: remove containers, volumes, networks AND data"
	@echo "  make re          - Full clean and rebuild everything"
	@echo ""
	@echo "BONUS SERVICES (Isolated):"
	@echo "  make bonus       - Build and start ONLY bonus services (Adminer, Redis, FTP, Static, Uptime)"
	@echo "  make bonus-build - Build only bonus service images"
	@echo "  make bonus-up    - Build and start only bonus services"
	@echo "  make bonus-down  - Stop only bonus services"
	@echo "  make bonus-logs  - View bonus service logs"
	@echo ""
	@echo "UTILITIES:"
	@echo "  make hosts       - Add $(DOMAIN) to /etc/hosts"
	@echo "  make help        - Show this help message"

# Add domain to /etc/hosts (requires sudo)
hosts:
	@if grep -q "$(DOMAIN)" /etc/hosts; then \
		echo "✓ $(DOMAIN) already in /etc/hosts"; \
	else \
		echo "127.0.0.1	$(DOMAIN)" | sudo tee -a /etc/hosts > /dev/null; \
		echo "✓ Added $(DOMAIN) to /etc/hosts"; \
	fi

# Create data directories if they don't exist
$(DATA_DIR)/mysql $(DATA_DIR)/www:
	@mkdir -p $@
	@echo "✓ Created directory: $@"

build:
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) build --no-cache

up: $(DATA_DIR)/mysql $(DATA_DIR)/www
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) up -d --build
	@echo "✓ Containers built and started in detached mode"

down:
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down
	@echo "✓ Containers stopped and removed"

stop:
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) stop
	@echo "✓ Containers stopped"

start:
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) start
	@echo "✓ Containers started"

restart:
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) restart
	@echo "✓ Containers restarted"

logs:
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) logs -f

ps:
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) ps

# clean: stops containers and removes volumes (but keeps data on disk)
clean:
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down -v
	@echo "✓ Containers, volumes, and networks removed"

# fclean: full clean including data directories (fresh start)
fclean: clean
	@sudo rm -rf $(DATA_DIR)
	@echo "✓ Data directories removed: $(DATA_DIR)"

# re: full reset - clean everything and rebuild from scratch
re: fclean up
	@echo "✓ Full reset completed and containers started"

# ============================================================================
# BONUS SERVICES - ISOLATED TARGETS
# ============================================================================
# These commands only affect the bonus services:
# - Adminer (database management)
# - Redis (caching)
# - FTP (file management)
# - Static Site (portfolio)
# - Uptime Monitor (health monitoring) ← CUSTOM SERVICE
#
# The main services (MariaDB, WordPress, NGINX) are NOT affected
# This allows you to develop/test bonus services independently
# ============================================================================

# Create bonus data directory if it doesn't exist
$(DATA_BONUS_DIR):
	@mkdir -p $@
	@echo "✓ Created bonus data directory: $@"

# Build only bonus service images
bonus-build: $(DATA_BONUS_DIR)
	@echo "Building bonus services only..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) build --no-cache adminer redis ftp static-site uptime-monitor
	@echo "✓ Bonus service images built successfully"

# Start/create only bonus services (no rebuild of main services)
bonus-up: $(DATA_BONUS_DIR)
	@echo "Starting bonus services only..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) up -d adminer redis ftp static-site uptime-monitor
	@echo "✓ Bonus services started"
	@echo ""
	@echo "Bonus services are now running:"
	@echo "  • Adminer (DB):      https://mel-bouh.42.fr/adminer"
	@echo "  • Static Site:       https://mel-bouh.42.fr/portfolio"
	@echo "  • Uptime Monitor:    https://mel-bouh.42.fr/uptime"
	@echo "  • Redis:             redis:6379 (internal)"
	@echo "  • FTP:               ftp://mel-bouh.42.fr:21"

# Alias: 'make bonus' = 'make bonus-up'
bonus: bonus-up

# Stop only bonus services (keep main services running)
bonus-down:
	@echo "Stopping bonus services only..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) stop adminer redis ftp static-site uptime-monitor
	@echo "✓ Bonus services stopped"

# View logs from bonus services only
bonus-logs:
	@echo "Displaying bonus service logs (Ctrl+C to exit)..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) logs -f adminer redis ftp static-site uptime-monitor

