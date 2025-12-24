.PHONY: all build up down stop start restart logs ps clean fclean re help hosts

PROJECT_NAME := inception
DOCKER_COMPOSE := docker compose -f srcs/docker-compose.yml
DATA_DIR := /home/mel-bouh/data
DOMAIN := mel-bouh.42.fr

# Default target - just run 'make' to start everything
all : up

help:
	@echo "Inception Docker Project"
	@echo "======================="
	@echo "Available commands:"
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
