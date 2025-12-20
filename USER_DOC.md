# USER DOCUMENTATION

## Overview

This document provides a complete guide for end users and administrators to understand, manage, and use the Inception Docker infrastructure.

## Services Provided

The Inception stack provides three main services:

### 1. **Nginx Web Server**
- **Purpose**: Handles HTTP/HTTPS traffic and forwards requests to WordPress
- **Port**: 443 (HTTPS) and 80 (HTTP redirects to HTTPS)
- **Status**: Essential for accessing the website

### 2. **WordPress Application**
- **Purpose**: Content management system for the website
- **Access**: Available through Nginx at `https://mel-bouh.42.fr`
- **Admin Panel**: `https://mel-bouh.42.fr/wp-admin`
- **Port**: 9000 (internal PHP-FPM port, not exposed to host)

### 3. **MariaDB Database**
- **Purpose**: Stores all WordPress data, user information, and content
- **Port**: 3306 (internal only, not accessible from host)
- **Status**: Must be running for WordPress to function

## Getting Started

### Starting the Project

```bash
# Option 1: Full reset (recommended for first run)
make re

# Option 2: Just start existing containers
make up

# Option 3: Build then start
make build
make up
```

**Wait 10-15 seconds** for all services to initialize before accessing the website.

### Stopping the Project

```bash
# Option 1: Stop without removing containers (faster restart)
make stop

# Option 2: Stop and remove everything (clean shutdown)
make down

# Option 3: Complete cleanup (removes volumes too)
make clean
```

### Monitoring Services

```bash
# Check if services are running
make ps

# View real-time logs
make logs

# View logs for specific service
docker compose logs mariadb    # Database logs
docker compose logs wordpress  # WordPress logs
docker compose logs nginx      # Web server logs
```

## Accessing the Website

### Website
- **URL**: `https://mel-bouh.42.fr`
- **Note**: Uses self-signed SSL certificate; your browser may show a security warning (this is normal)
- **SSL Warning**: Click "Advanced" → "Proceed" or "I understand the risks" to continue

### WordPress Administration Panel
- **URL**: `https://mel-bouh.42.fr/wp-admin`
- **Admin Username**: `mel-bouh`
- **Admin Password**: `mel-bouh123` (configured in `.env` file)

### Features Available
- Create and manage pages/posts
- Install themes and plugins
- Manage users and roles
- View website statistics
- Configure website settings

## Managing Credentials

### Environment Variables
All credentials are stored in the `.env` file at the project root:

```
# WordPress Admin
WP_ADMIN_USER=mel-bouh
WP_ADMIN_PASSWORD=mel-bouh123
WP_ADMIN_EMAIL=mel-bouh@42.fr

# WordPress Database User
WP_DB_USER=mel-bouh
WP_DB_PASSWORD=mel-bouh123

# MariaDB Root User
WP_DB_ROOT_PASSWORD=password123
```

### Changing Credentials

**⚠️ Important**: Credentials should be changed in production!

To change the WordPress admin password:
1. Log in to `https://mel-bouh.42.fr/wp-admin`
2. Go to Users → Your Profile
3. Enter new password and save

To change database credentials (advanced):
1. Modify `.env` file
2. Run `make re` to rebuild and reinitialize
3. **Warning**: This will reset the database!

## Checking Service Status

### Quick Health Check
```bash
# Run automated tests
make test
```

This will verify:
- ✓ MariaDB is running and accessible
- ✓ WordPress database exists
- ✓ WordPress tables are created
- ✓ WordPress is configured
- ✓ All containers are running

### Manual Service Verification

**Check MariaDB Connection**
```bash
docker exec mariadb bash -c "unset MYSQL_HOST && mysql -u root -ppassword123 -e 'SHOW DATABASES;'"
```
Expected output should show: `wordpress` database listed

**Check WordPress Configuration**
```bash
docker exec wordpress cat /var/www/html/wp-config.php | grep "DB_"
```
Expected output: Database name, user, and host configuration

**Check Nginx Configuration**
```bash
docker exec nginx cat /etc/nginx/sites-available/default | grep "server_name"
```
Expected output: Your domain name

### Viewing Container Logs

```bash
# All services
docker compose logs

# Last 50 lines
docker compose logs --tail 50

# Follow logs in real-time
docker compose logs -f

# Specific service
docker compose logs wordpress
docker compose logs mariadb
docker compose logs nginx
```

## Troubleshooting

### "Connection Refused" Error
- **Cause**: Services not fully initialized
- **Solution**: Wait 10-15 seconds after `make up` and try again

### Website Shows "Bad Gateway" Error
- **Cause**: WordPress container not running or PHP-FPM unavailable
- **Solution**: 
  ```bash
  docker compose ps              # Check status
  make logs                      # View error messages
  make restart                   # Restart services
  ```

### Database Connection Error
- **Cause**: MariaDB not started or credentials wrong
- **Solution**:
  ```bash
  make test                      # Run diagnostic tests
  docker compose logs mariadb    # Check database logs
  ```

### SSL Certificate Warning
- **Cause**: Self-signed certificate (expected behavior)
- **Solution**: 
  - Click through the security warning in browser
  - In production, replace with valid certificate from trusted CA

### Ports Already in Use
- **Cause**: Another service using port 443 or 80
- **Solution**:
  ```bash
  sudo lsof -i :443   # See what's using port 443
  sudo lsof -i :80    # See what's using port 80
  # Kill conflicting service or change Inception port in docker-compose.yml
  ```

## Data Persistence

### Where is My Data Stored?

- **WordPress Files**: `/home/mel-bouh/data/www/`
- **Database Files**: `/home/mel-bouh/data/mysql/`
- **Configuration**: `.env` file at project root

### Backing Up Data

```bash
# Backup WordPress files
tar -czf wordpress_backup.tar.gz /home/mel-bouh/data/www/

# Backup database
docker exec mariadb mysqldump -u root -ppassword123 wordpress > wordpress_backup.sql

# Backup everything
tar -czf inception_backup.tar.gz /home/mel-bouh/data/ .env
```

### Restoring Data

```bash
# Restore WordPress files
tar -xzf wordpress_backup.tar.gz -C /

# Restore database
docker exec -i mariadb mysql -u root -ppassword123 wordpress < wordpress_backup.sql
```

## Performance Monitoring

### Check Container Resource Usage
```bash
docker stats
```

### Check Disk Space
```bash
df -h /home/mel-bouh/data/
du -sh /home/mel-bouh/data/*
```

### Check Network Connectivity Between Services
```bash
docker exec wordpress ping mariadb    # Should succeed
docker exec wordpress ping nginx      # Should succeed
```

## Updating and Maintenance

### Update WordPress
1. Log in to WordPress admin
2. Go to Dashboard → Updates
3. Install available updates

### Update WordPress Plugins
1. Log in to WordPress admin
2. Go to Plugins → Update Available
3. Click "Update Now"

### Clean Up Unused Data
```bash
# Remove old logs (if needed)
docker compose logs --no-stream > /dev/null

# Remove unused volumes and networks
make clean
```

## Need Help?

Refer to:
- `DEV_DOC.md` - For technical/developer issues
- `README.md` - For project overview
- Docker logs: `make logs`
- Container shell: `docker exec -it wordpress bash`
