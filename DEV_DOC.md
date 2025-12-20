# DEVELOPER DOCUMENTATION

## Overview

This document provides technical guidance for developers to understand the project architecture, set up the development environment, build and launch the infrastructure, and manage containers and data.

## Table of Contents
1. [Environment Setup](#environment-setup)
2. [Building and Launching](#building-and-launching)
3. [Container Management](#container-management)
4. [Volume and Data Management](#volume-and-data-management)
5. [Configuration Details](#configuration-details)
6. [Debugging and Troubleshooting](#debugging-and-troubleshooting)

## Environment Setup

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 1.29+
- Git
- Make
- Text editor (VS Code, vim, nano, etc.)
- bash/zsh shell

### Setting Up from Scratch

```bash
# 1. Clone the repository
git clone <repository-url>
cd Inception

# 2. Verify Docker installation
docker --version
docker compose --version

# 3. Ensure directories exist for volumes
mkdir -p ~/data/mysql
mkdir -p ~/data/www

# 4. Review and configure .env file
cat .env
# Edit if needed:
# nano .env

# 5. Verify directory structure
tree -L 3
# Should show:
# .
# ├── Makefile
# ├── README.md
# ├── docker-compose.yml
# ├── .env
# ├── requirements/
# │   ├── mariadb/
# │   │   ├── Dockerfile
# │   │   ├── conf/
# │   │   └── tools/
# │   ├── wordpress/
# │   │   ├── Dockerfile
# │   │   ├── conf/
# │   │   └── tools/
# │   └── nginx/
# │       ├── Dockerfile
# │       ├── conf/
# │       └── tools/
```

### Environment Variables (.env)

The `.env` file contains all configuration:

```bash
# Domain
DOMAIN_NAME=mel-bouh.42.fr

# Database Configuration
WP_DB_HOST=mariadb
WP_DB_DATABASE=wordpress
WP_DB_USER=mel-bouh
WP_DB_PASSWORD=mel-bouh123
WP_DB_ROOT_PASSWORD=password123

# WordPress Admin
WP_ADMIN_USER=mel-bouh
WP_ADMIN_PASSWORD=mel-bouh123
WP_ADMIN_EMAIL=mel-bouh@42.fr
```

**Important**: Change these credentials before production deployment!

### Development Configuration

For development, you can override settings:

```bash
# Set temporary environment variable
export WP_ADMIN_PASSWORD="dev_password"

# Or create .env.local (not committed)
echo "WP_ADMIN_PASSWORD=dev_password" > .env.local
```

## Building and Launching

### Using Makefile (Recommended)

```bash
# Full rebuild and start (clean everything first)
make re

# Just build images
make build

# Start containers
make up

# Check status
make ps

# Run comprehensive tests
make test
```

### Using Docker Compose Directly

```bash
# Build images
docker compose build

# Start in detached mode
docker compose up -d

# Start in foreground (see logs)
docker compose up

# Stop
docker compose down

# Remove volumes too
docker compose down -v

# View logs
docker compose logs -f
```

### Build Process Explained

1. **MariaDB Image Build**
   - Base: Debian Bookworm
   - Installs MariaDB server
   - Creates necessary directories and socket
   - Copies configuration and setup script

2. **WordPress Image Build**
   - Base: Debian Bookworm
   - Installs PHP-FPM and extensions
   - Downloads WP-CLI for automation
   - Creates WordPress directory

3. **Nginx Image Build**
   - Base: Debian Bookworm
   - Installs Nginx and OpenSSL
   - Generates self-signed SSL certificates
   - Copies Nginx configuration

4. **Container Startup Order**
   - MariaDB starts first (depended on by others)
   - WordPress starts after MariaDB connection
   - Nginx starts in parallel with WordPress

## Container Management

### Executing Commands in Containers

```bash
# Run command in container
docker exec <container-name> <command>

# Interactive shell
docker exec -it <container-name> bash

# Examples
docker exec wordpress ls -la /var/www/html
docker exec mariadb mysql -u root -ppassword123 -e "SHOW DATABASES;"
docker exec nginx nginx -t  # Test nginx config
```

### Container-Specific Operations

**MariaDB Operations**
```bash
# Access MySQL CLI
docker exec -it mariadb bash -c "unset MYSQL_HOST && mysql -u root -ppassword123"

# Run SQL query
docker exec mariadb mysql -u root -ppassword123 -e "SELECT DATABASE();"

# Dump database
docker exec mariadb mysqldump -u root -ppassword123 wordpress > backup.sql

# Check MariaDB logs
docker logs mariadb
```

**WordPress Operations**
```bash
# Access WordPress directory
docker exec -it wordpress bash

# Use WP-CLI
docker exec wordpress wp plugin list --path=/var/www/html --allow-root

# Check WordPress version
docker exec wordpress wp --version --path=/var/www/html --allow-root

# Update WordPress
docker exec wordpress wp core update --path=/var/www/html --allow-root
```

**Nginx Operations**
```bash
# Test Nginx configuration
docker exec nginx nginx -t

# Reload Nginx config
docker exec nginx nginx -s reload

# View Nginx logs
docker logs nginx

# Check SSL certificate
docker exec nginx openssl x509 -in /etc/ssl/certs/nginx.crt -text -noout
```

### Container Monitoring

```bash
# Real-time resource usage
docker stats

# Container details
docker inspect <container-name>

# View container processes
docker top <container-name>

# Check container port bindings
docker port <container-name>
```

## Volume and Data Management

### Docker Volumes Used

1. **mariadb_data**
   - **Mount Path**: `/var/lib/mysql`
   - **Host Path**: `/home/mel-bouh/data/mysql`
   - **Purpose**: Persistent database storage

2. **wordpress_data**
   - **Mount Path**: `/var/www/html`
   - **Host Path**: `/home/mel-bouh/data/www`
   - **Purpose**: Persistent WordPress files and uploads

### Volume Operations

```bash
# List all volumes
docker volume ls

# Inspect volume details
docker volume inspect inception_mariadb_data
docker volume inspect inception_wordpress_data

# View volume contents
docker run -v inception_mariadb_data:/data busybox ls -la /data

# Backup volume
docker run --rm -v inception_wordpress_data:/source -v $(pwd):/backup \
  busybox tar czf /backup/wordpress_backup.tar.gz -C /source .

# Restore volume
docker run --rm -v inception_wordpress_data:/target -v $(pwd):/backup \
  busybox tar xzf /backup/wordpress_backup.tar.gz -C /target

# Remove unused volumes
docker volume prune

# Remove specific volume
docker volume rm inception_mariadb_data
```

### Data Persistence Explanation

- **Database**: MariaDB stores data in `/var/lib/mysql` (volume mounted)
- **WordPress**: Files stored in `/var/www/html` (volume mounted)
- **Configurations**: Docker images, .env file

When containers stop:
- Data in volumes persists
- Containers can be removed and recreated without data loss
- Use `make clean` to remove everything including volumes

## Configuration Details

### Dockerfile Analysis

**MariaDB Dockerfile**
```dockerfile
# Base image
FROM debian:bookworm

# Install MariaDB
RUN apt-get update && apt-get install -y mariadb-server

# Create necessary directories
RUN mkdir -p /run/mysqld /var/lib/mysql /var/log/mysql
RUN chown -R mysql:mysql /run/mysqld /var/lib/mysql /var/log/mysql

# Copy configuration
COPY /conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["mariadbd", "--user=mysql", "--bind-address=0.0.0.0", "--console"]
```

**WordPress Dockerfile**
```dockerfile
# Base image
FROM debian:bookworm

# Install PHP and dependencies
RUN apt-get update && apt-get install -y \
    php php-fpm php-mysql php-cli php-curl php-gd \
    php-mbstring php-xml php-zip mariadb-client curl unzip

# Install WP-CLI
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    -o /usr/local/bin/wp && chmod +x /usr/local/bin/wp

# Create WordPress directory
RUN mkdir -p /var/www/html

COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

WORKDIR /var/www/html
ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["php-fpm8.2", "-F"]
```

**Nginx Dockerfile**
```dockerfile
# Base image
FROM debian:bookworm

# Install Nginx and OpenSSL
RUN apt-get update && apt-get install -y nginx openssl && \
    rm -rf /var/lib/apt/lists/*

# Generate self-signed SSL certificate
RUN openssl req -newkey rsa:2048 -nodes \
    -keyout /etc/ssl/private/nginx.key -x509 -days 365 \
    -out /etc/ssl/certs/nginx.crt \
    -subj "/C=MA/ST=BE/O=1337/CN=mel-bouh.42.fr"

COPY conf/default.conf /etc/nginx/sites-available/default
COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["nginx", "-g", "daemon off;"]
```

### Initialization Scripts

**MariaDB Setup (setup.sh)**
- Unsets MYSQL_HOST environment variable to avoid connection conflicts
- Starts MariaDB daemon
- Checks if WordPress database exists
- If first run: Sets root password, creates WordPress database and user
- Restarts MariaDB for normal operation

**WordPress Setup (setup.sh)**
- Waits for MariaDB connection
- Downloads WordPress from wordpress.org
- Creates wp-config.php from wp-config-sample.php
- Substitutes database credentials
- Installs WordPress core with WP-CLI
- Creates additional users
- Installs Blocksy theme

**Nginx Setup (setup.sh)**
- Validates Nginx configuration
- Starts Nginx as main process

### Docker Compose Configuration

```yaml
services:
  mariadb:
    build: ./requirements/mariadb
    container_name: mariadb
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - inception
    env_file: .env
    restart: unless-stopped

  wordpress:
    build: ./requirements/wordpress
    container_name: wordpress
    depends_on:
      - mariadb
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - inception
    env_file: .env
    restart: unless-stopped

  nginx:
    build: ./requirements/nginx
    container_name: nginx
    depends_on:
      - wordpress
    ports:
      - "80:80"
      - "443:443"
    networks:
      - inception
    restart: unless-stopped

volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/mel-bouh/data/mysql

  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/mel-bouh/data/www

networks:
  inception:
    driver: bridge
```

## Debugging and Troubleshooting

### Enable Debug Mode

```bash
# Add to .env for verbose output
export DEBUG=1

# View Docker buildkit output
export DOCKER_BUILDKIT=0
docker compose build --no-cache
```

### Checking Service Health

```bash
# 1. Check container status
docker compose ps

# 2. Check container logs
docker compose logs --tail 50

# 3. Test MariaDB
docker exec mariadb mysql -u root -ppassword123 -e "SHOW DATABASES;"

# 4. Test WordPress files
docker exec wordpress ls -la /var/www/html | head -20

# 5. Test Nginx configuration
docker exec nginx nginx -t

# 6. Test network connectivity
docker exec wordpress ping mariadb
docker exec wordpress ping nginx
```

### Common Issues and Solutions

**Issue: "Connection refused" on startup**
```bash
# Solution: Wait for services to initialize (10-15 seconds)
sleep 15
make test
```

**Issue: Port already in use**
```bash
# Solution: Find and stop conflicting service
sudo lsof -i :443
sudo lsof -i :80
docker compose down -v
```

**Issue: Database not initializing**
```bash
# Solution: Check MariaDB logs
docker logs mariadb
# Remove and rebuild
docker compose down -v
make re
```

**Issue: WordPress files not downloaded**
```bash
# Solution: Check WordPress logs
docker logs wordpress
# Verify internet connection and disk space
df -h ~/data/
```

**Issue: Nginx not proxying to PHP-FPM**
```bash
# Solution: Check Nginx config
docker exec nginx nginx -t
# Verify WordPress container is running
docker exec nginx ping wordpress
```

### Accessing Container Shells

```bash
# MariaDB shell
docker exec -it mariadb bash

# WordPress shell
docker exec -it wordpress bash

# Nginx shell
docker exec -it nginx bash

# MySQL prompt (inside mariadb container)
docker exec -it mariadb bash -c "mysql -u root -ppassword123"
```

### Inspecting Configuration Files

```bash
# MariaDB config
docker exec mariadb cat /etc/mysql/mariadb.conf.d/50-server.cnf

# WordPress config
docker exec wordpress cat /var/www/html/wp-config.php

# Nginx config
docker exec nginx cat /etc/nginx/sites-available/default

# PHP-FPM config
docker exec wordpress cat /etc/php/8.2/fpm/pool.d/www.conf
```

### Performance Profiling

```bash
# Monitor resource usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check disk usage
du -sh /home/mel-bouh/data/mysql
du -sh /home/mel-bouh/data/www

# Check database size
docker exec mariadb mysql -u root -ppassword123 -e \
  "SELECT table_schema, ROUND(SUM(data_length+index_length)/1024/1024, 2) \
   FROM information_schema.TABLES GROUP BY table_schema;"
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [MariaDB Container Setup](https://hub.docker.com/_/mariadb)
- [WordPress Docker Setup](https://docs.docker.com/samples/wordpress/)
- [Nginx Container Documentation](https://hub.docker.com/_/nginx)

## Contributing

When modifying the project:
1. Test changes with `make test`
2. Verify logs with `make logs`
3. Document configuration changes in this file
4. Update version numbers in relevant files
5. Test full rebuild with `make re`
