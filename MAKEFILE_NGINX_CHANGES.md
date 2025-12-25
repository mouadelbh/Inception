# Makefile & NGINX Changes Summary

## ✅ What Was Changed

### 1. Makefile - Added Bonus Service Commands

Your Makefile now supports **isolated bonus service management**.

#### New Commands Available

```bash
make bonus              # Build and start ONLY bonus services
make bonus-build        # Build only bonus service images
make bonus-up           # Start only bonus services
make bonus-down         # Stop only bonus services
make bonus-logs         # View bonus service logs
```

#### Why This Matters

**Before:**
- All commands affected all services (main + bonus)
- Couldn't restart bonus without restarting WordPress
- Couldn't test one bonus service independently

**After:**
- Bonus commands ONLY affect bonus containers
- Main services (MariaDB, WordPress, NGINX) unaffected
- Test/develop bonus services independently
- Faster iteration and debugging

#### Makefile Implementation

```makefile
# In the .PHONY declaration:
.PHONY: all build up down ... bonus-build bonus-up bonus-down bonus-logs

# New variable for bonus data directory:
DATA_BONUS_DIR := /home/mel-bouh/data/uptime-monitor

# Create bonus data directory if needed:
$(DATA_BONUS_DIR):
	@mkdir -p $@
	@echo "✓ Created bonus data directory: $@"

# Build only bonus services:
bonus-build: $(DATA_BONUS_DIR)
	@echo "Building bonus services only..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) build --no-cache adminer redis ftp static-site uptime-monitor
	@echo "✓ Bonus service images built successfully"

# Start only bonus services:
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

# Stop only bonus services:
bonus-down:
	@echo "Stopping bonus services only..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) stop adminer redis ftp static-site uptime-monitor
	@echo "✓ Bonus services stopped"

# View logs from bonus services:
bonus-logs:
	@echo "Displaying bonus service logs (Ctrl+C to exit)..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) logs -f adminer redis ftp static-site uptime-monitor
```

---

## NGINX Configuration - Complete Explanation

### Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    Your Browser                           │
│                  (Wants to visit site)                   │
└────────────────────┬─────────────────────────────────────┘
                     │
                     │ HTTPS Request (Port 443)
                     │ Encrypted
                     ↓
        ┌─────────────────────────┐
        │     NGINX Container     │
        │   Reverse Proxy + TLS   │
        │      Port 443 HTTPS     │
        └────────┬────────────────┘
                 │
         ┌───────┼───────┬──────────┬────────────┐
         │       │       │          │            │
         ↓       ↓       ↓          ↓            ↓
       "/" "/*.php" "/adminer" "/portfolio" "/uptime"
         │       │       │          │            │
         ↓       ↓       ↓          ↓            ↓
     WordPress WordPress Adminer StaticSite Uptime-Monitor
     :9000     :9000    :8080      :8080       :5000
```

### Configuration File Location

```
/home/mel-bouh/Inception/srcs/requirements/nginx/conf/default.conf
```

---

## All NGINX Location Blocks Explained

### 1. Server Block - Main Configuration

```nginx
server {
    listen 443 ssl;                          # Only HTTPS
    server_name mel-bouh.42.fr;              # Your domain
    root /var/www/html;                      # WordPress root
    index index.php index.html;              # Default files
```

**What it does:**
- Only accepts connections on HTTPS (port 443)
- HTTP (port 80) requests are not handled
- All requests use `mel-bouh.42.fr` configuration
- Default directory is WordPress `/var/www/html`

---

### 2. TLS/SSL Configuration

```nginx
ssl_certificate /etc/ssl/certs/nginx.crt;
ssl_certificate_key /etc/ssl/private/nginx.key;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
```

**What it does:**
- Loads SSL certificate (public key)
- Loads SSL private key (secret)
- Only allows TLS 1.2 and 1.3 (blocks outdated TLS 1.0 and 1.1)
- Uses server's strong cipher preferences

**Security note:**
This is a **Inception requirement** - you must use TLSv1.2+ only.

---

### 3. Root Location / (WordPress)

```nginx
location / {
    try_files $uri $uri/ /index.php?$args;
}
```

**How it works step-by-step:**

When user visits `https://mel-bouh.42.fr/hello-world/`:

1. **Step 1**: Try exact file `/hello-world/` 
   - Not found → Continue
   
2. **Step 2**: Try directory `/hello-world/`
   - Not found → Continue
   
3. **Step 3**: Forward to `/index.php?hello-world/`
   - WordPress handles the URL
   - Generates the page content
   - Returns HTML

**Why this matters:**
- WordPress URLs are "pretty" (no .php)
- WordPress handles routing internally
- NGINX forwards unknown requests to WordPress

---

### 4. PHP Handler

```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass wordpress:9000;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
}
```

**How it works:**

When user requests any `.php` file:

1. NGINX identifies it as PHP file
2. Can't execute PHP itself
3. Forwards to PHP-FPM on `wordpress:9000`
4. PHP-FPM executes the code
5. Returns output to NGINX
6. NGINX sends to browser

**Example:**
```
Request: https://mel-bouh.42.fr/wp-admin/
  → Matches try_files in location /
  → Forwards to /index.php?wp-admin/
  → Matches location ~ \.php$
  → Sends to PHP-FPM
  → WordPress code runs
  → Returns admin page
```

---

### 5. Adminer - Database Management UI

```nginx
location /adminer {
    rewrite ^/adminer$ /adminer.php break;
    proxy_pass http://adminer:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**What it does:**

```
User visits: https://mel-bouh.42.fr/adminer
  ↓
NGINX matches location /adminer
  ↓
Rewrites URL: /adminer → /adminer.php (internal)
  ↓
Proxies to Adminer container on port 8080
  ↓
Adminer returns database management UI
  ↓
Browser displays interface
```

**Rewrite rule breakdown:**
- `^/adminer$` - Exactly match `/adminer`
- `^` and `$` - Beginning and end of URL
- Prevents rewriting `/adminer/` or `/adminers`

**Headers explained:**
- `Host: mel-bouh.42.fr` - Adminer knows the real domain
- `X-Real-IP: 203.0.113.1` - Adminer knows the client IP
- `X-Forwarded-For: 203.0.113.1, 172.17.0.1` - Full proxy chain
- `X-Forwarded-Proto: https` - Adminer knows it came via HTTPS

**Why these headers matter:**
Without them, Adminer thinks:
- Domain is `localhost`
- Client IP is NGINX's IP (not the real user)
- Protocol is HTTP (even though user used HTTPS)

---

### 6. Static Portfolio Site

```nginx
location /portfolio {
    proxy_pass http://static-site:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**What it does:**

```
User visits: https://mel-bouh.42.fr/portfolio
  ↓
NGINX matches location /portfolio
  ↓
Proxies to Static-site container on port 8080
  ↓
(Note: Trailing slash strips /portfolio from path)
  ↓
Static-site serves /var/www/static/index.html
  ↓
Browser displays portfolio page
```

**Key difference: Trailing slash**

Compare these:
```nginx
# WITH trailing slash (used here):
proxy_pass http://static-site:8080/;
# Request: /portfolio → Stripped → /

# WITHOUT trailing slash:
proxy_pass http://static-site:8080;
# Request: /portfolio → Kept → /portfolio
```

---

### 7. Uptime Monitor - Health Monitoring (YOUR CUSTOM SERVICE)

```nginx
location /uptime {
    proxy_pass http://uptime-monitor:5000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**What it does:**

```
User visits: https://mel-bouh.42.fr/uptime
  ↓
NGINX matches location /uptime
  ↓
Proxies to Uptime-monitor on port 5000
  ↓
Flask web server renders dashboard
  ↓
Browser displays monitoring statistics
```

**API endpoints work too:**

```
Request: https://mel-bouh.42.fr/uptime/api/status
  ↓
Matches location /uptime
  ↓
Proxies to uptime-monitor:5000/api/status
  ↓
Flask route @app.route('/api/status') handles it
  ↓
Returns JSON: {"status": "UP", ...}
  ↓
Browser receives JSON
```

---

### 8. Security - Block Hidden Files

```nginx
location ~ /\. {
    deny all;
}
```

**What it does:**

Blocks all files starting with `.` (hidden files):
- `/.env` - Database passwords
- `/.git/` - Source code repository
- `/.htaccess` - Server configuration
- `/.aws/` - Cloud credentials

**Example:**

```
Request: https://mel-bouh.42.fr/.env
  ↓
Matches location ~ /\.
  ↓
NGINX returns: 403 Forbidden
  ↓
Browser: Access Denied
```

---

## Summary: NGINX Request Routing

```
URL Request                    → Matched Location      → Destination         → Service
─────────────────────────────────────────────────────────────────────────────────────
https://mel-bouh.42.fr/       → location /            → /index.php?/        → WordPress PHP
https://mel-bouh.42.fr/admin/ → location /            → /index.php?admin/   → WordPress PHP
https://mel-bouh.42.fr/wp-admin.php → location ~ \.php$ → PHP-FPM 9000   → WordPress
https://mel-bouh.42.fr/adminer → location /adminer    → adminer:8080        → Adminer
https://mel-bouh.42.fr/portfolio → location /portfolio → static-site:8080   → Static Site
https://mel-bouh.42.fr/uptime  → location /uptime     → uptime-monitor:5000 → Uptime Monitor
https://mel-bouh.42.fr/.env    → location ~ /\.       → DENIED              → None
```

---

## How to Use the New Makefile Commands

### Scenario 1: Quick Bonus Service Restart

You modified the Uptime Monitor code. Quick restart:

```bash
make bonus-down     # Stop bonus services (WordPress keeps running)
# Edit code...
make bonus-up       # Restart bonus services
```

### Scenario 2: Check If All Bonus Services Are Running

```bash
make bonus-logs     # View live logs from all 5 bonus services
```

### Scenario 3: Full System Restart (Including WordPress)

```bash
make re             # Full system reset (traditional command)
```

### Scenario 4: Rebuild Just One Bonus Service

Still need to use docker-compose directly:

```bash
docker compose -f srcs/docker-compose.yml build uptime-monitor
docker compose -f srcs/docker-compose.yml up -d uptime-monitor
```

But for testing multiple bonus services together:

```bash
make bonus          # All 5 bonus services
```

---

## Bonus Service Dependency Map

```
NGINX (Main Entry Point)
  │
  ├─→ /adminer ─────→ Adminer Container ─→ MariaDB
  ├─→ /portfolio ───→ Static-site Container
  ├─→ /uptime ──────→ Uptime-monitor Container ─→ SQLite
  ├─→ / ────────────→ WordPress Container ──────┐
  │                                             │
  └──────────────────────────────────────────→ MariaDB
                                                │
                           Redis ◄─────────────┘
                           FTP ◄────────────────┘
```

**Important:**
- Adminer needs MariaDB running
- Uptime Monitor doesn't depend on anything
- FTP needs WordPress files (shared volume)
- Redis optional for WordPress (caching)

---

## Complete Makefile Usage

```bash
# MAIN COMMANDS (affect all services):
make              # Start everything (default)
make build        # Build all images
make up           # Start all services
make down         # Stop all services
make restart      # Restart all services
make logs         # View all logs
make ps           # List all containers
make clean        # Remove containers and volumes
make fclean       # Remove containers, volumes, AND data
make re           # Full clean + rebuild

# BONUS COMMANDS (affect only bonus services):
make bonus        # Build and start bonus services
make bonus-build  # Build bonus images only
make bonus-up     # Start bonus services
make bonus-down   # Stop bonus services
make bonus-logs   # View bonus logs

# UTILITIES:
make hosts        # Add domain to /etc/hosts
make help         # Show all commands
```

---

## Summary of Changes

### Makefile Changes
✅ Added 5 bonus-specific commands  
✅ Updated help text  
✅ New variable: `DATA_BONUS_DIR`  
✅ New targets: `bonus`, `bonus-build`, `bonus-up`, `bonus-down`, `bonus-logs`  

### NGINX Changes
✅ Added `/adminer` location block  
✅ Added `/portfolio` location block  
✅ Added `/uptime` location block (YOUR CUSTOM SERVICE)  
✅ Added security block for hidden files  
✅ All bonus services properly proxied with headers  

### Benefits
✅ Bonus services isolated from main infrastructure  
✅ Faster testing and development  
✅ Cleaner command-line experience  
✅ Better understanding of each service's purpose  
✅ Easy to debug individual services  

---

**Everything is now properly organized and documented!**
