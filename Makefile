.PHONY: all build up down stop start restart logs ps clean re help

PROJECT_NAME := inception

help:
	@echo "Inception Docker Project"
	@echo "======================="
	@echo "Available commands:"
	@echo "  make build       - Build all Docker images"
	@echo "  make up          - Start containers in detached mode"
	@echo "  make down        - Stop and remove containers"
	@echo "  make stop        - Stop containers without removing them"
	@echo "  make start       - Start existing containers"
	@echo "  make restart     - Restart containers"
	@echo "  make logs        - View container logs"
	@echo "  make ps          - List running containers"
	@echo "  make clean       - Remove containers, volumes, and networks"
	@echo "  make re          - Clean and rebuild everything (full reset)"
	@echo "  make test        - Run tests to verify setup"
	@echo "  make help        - Show this help message"

build:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) build --no-cache

up:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) up -d 
	@echo "✓ Containers started in detached mode"

down:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) down 
	@echo "✓ Containers stopped and removed"

stop:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) stop 
	@echo "✓ Containers stopped"

start:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) start 
	@echo "✓ Containers started"

restart:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) restart 
	@echo "✓ Containers restarted"

logs:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) logs -f
ps:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) ps

clean:
	docker compose -f srcs/docker-compose.yml -p $(PROJECT_NAME) down -v
	@echo "✓ Containers, volumes, and networks removed"

re: clean build up
	@echo "✓ Full reset completed and containers started"

.DEFAULT_GOAL := help
