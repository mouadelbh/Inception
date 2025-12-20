*This project has been created as part of the 42 curriculum by mel-bouh.*

# Inception

## Description

Inception is a comprehensive Docker infrastructure project that sets up a complete web services stack running WordPress with a MariaDB database and Nginx web server. The project demonstrates containerization best practices, networking, persistent storage, and infrastructure automation using Docker Compose.

The main goal is to create a production-ready Docker environment that manages multiple services in isolation while allowing them to communicate securely through Docker networks and persist data through volumes.

## Instructions

### Prerequisites
- Docker Engine (version 20.10+)
- Docker Compose (version 1.29+)
- Unix-like operating system (Linux, macOS, or WSL2)
- Git

### Installation & Execution

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd Inception
   ```

2. **Configure environment variables:**
   ```bash
   # The .env file is already provided with the following variables:
   DOMAIN_NAME=mel-bouh.42.fr
   WP_DB_HOST=mariadb
   WP_DB_DATABASE=wordpress
   WP_DB_USER=mel-bouh
   WP_DB_PASSWORD=mel-bouh123
   WP_DB_ROOT_PASSWORD=password123
   WP_ADMIN_USER=mel-bouh
   WP_ADMIN_PASSWORD=mel-bouh123
   WP_ADMIN_EMAIL=mel-bouh@42.fr
   ```

3. **Build and start the project:**
   ```bash
   make re          # Full reset, rebuild, and start
   # OR
   make build       # Just build images
   make up          # Start containers
   ```

4. **Verify the setup:**
   ```bash
   make test        # Run comprehensive tests
   make ps          # Check running containers
   ```

5. **Access the services:**
   - Website: `https://mel-bouh.42.fr`
   - WordPress Admin: `https://mel-bouh.42.fr/wp-admin`
   - Database: MariaDB running on port 3306 (internal only)

### Common Commands

```bash
make help        # Show all available commands
make up          # Start containers
make down        # Stop and remove containers
make restart     # Restart containers
make logs        # View container logs
make stop        # Stop containers without removing
make start       # Start stopped containers
make clean       # Remove containers and volumes
make test        # Run test suite
```

## Project Architecture

### Docker Implementation Details

This project uses Docker containerization for the following advantages:

#### Virtual Machines vs Docker
- **VMs**: Full OS overhead, slower startup (minutes), larger disk footprint
- **Docker**: Lightweight containers, instant startup (seconds), minimal overhead, shared kernel
- **Choice**: Docker chosen for efficiency and rapid development cycles

#### Secrets vs Environment Variables
- **Environment Variables**: Easy to configure, accessible across containers, suitable for non-sensitive settings
- **Docker Secrets**: Better for sensitive data in Swarm mode, requires orchestration overhead
- **Choice**: Environment variables (.env file) for development simplicity; secrets should be used in production

#### Docker Network vs Host Network
- **Host Network**: Direct access to host ports, security risks, less isolation
- **Docker Network**: Custom bridge network, isolated communication, service discovery via DNS
- **Choice**: Custom Docker network (inception) for security and clean service isolation

#### Docker Volumes vs Bind Mounts
- **Bind Mounts**: Direct filesystem binding, performance dependent on host, simpler debugging
- **Docker Volumes**: Managed by Docker, better performance, portable across hosts
- **Choice**: Docker volumes for database and WordPress data persistence; bind mounts could be used for development

### Services Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network                            │
│                    (inception)                               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │              │  │              │  │                  │  │
│  │   Nginx      │  │  WordPress   │  │     MariaDB      │  │
│  │              │  │  (PHP-FPM)   │  │                  │  │
│  │ Port 443     │  │ Port 9000    │  │ Port 3306        │  │
│  │              │  │ (internal)   │  │ (internal)       │  │
│  │              │  │              │  │                  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│       │                    │                    │             │
│       │                    │                    │             │
│  Reverse Proxy        FastCGI Request       TCP Connection   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         │
    Host Machine
   SSL Certificates
```

### Data Persistence

- **MariaDB Data**: Stored in `mariadb_data` volume (persists at `/home/mel-bouh/data/mysql`)
- **WordPress Data**: Stored in `wordpress_data` volume (persists at `/home/mel-bouh/data/www`)
- **Configuration**: Stored in image layers and .env file

## Resources

### Docker Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Networking Guide](https://docs.docker.com/network/)
- [Docker Volumes Documentation](https://docs.docker.com/storage/volumes/)

### MariaDB
- [MariaDB Official Documentation](https://mariadb.com/documentation/)
- [MariaDB Docker Official Image](https://hub.docker.com/_/mariadb)
- [MariaDB Configuration Guide](https://mariadb.com/kb/en/mariadb-configuration/)

### WordPress
- [WordPress Documentation](https://wordpress.org/support/)
- [WordPress CLI Documentation](https://developer.wordpress.org/cli/commands/)
- [WordPress Codex](https://codex.wordpress.org/)

### Nginx
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Nginx Configuration Examples](https://nginx.org/en/docs/http/server_names.html)
- [SSL/TLS with Nginx](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)

### Useful Tutorials
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [WordPress on Docker](https://docs.docker.com/samples/wordpress/)

## AI Usage

AI assistance was utilized for the following tasks:

1. **Dockerfile Optimization**: Generation of efficient multi-stage builds and dependency management
2. **Shell Script Development**: Creation and debugging of initialization scripts for database setup and WordPress installation
3. **Docker Compose Configuration**: Structuring services, networking, and volume definitions
4. **Nginx Configuration**: Reverse proxy setup, SSL/TLS certificate handling, and FastCGI configuration
5. **Makefile Creation**: Development of build automation and test commands
6. **Documentation**: README and documentation file generation with best practices
7. **Troubleshooting**: Debugging connection issues, initialization logic, and container communication

## License

This project is part of the 42 School curriculum.
