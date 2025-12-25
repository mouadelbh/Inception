# NGINX Configuration Explained - All Changes

## Overview

Your NGINX configuration acts as a **reverse proxy and load balancer** between the internet and your backend services. It handles:
- HTTPS/TLS encryption
- Request routing to different services
- Static file serving
- PHP-FPM proxying

---

## Table of Contents

1. [Basic NGINX Architecture](#basic-nginx-architecture)
2. [Configuration Locations](#configuration-locations)
3. [Full Configuration Breakdown](#full-configuration-breakdown)
4. [All Location Blocks Explained](#all-location-blocks-explained)
5. [Proxy Headers Explained](#proxy-headers-explained)
6. [Security Settings](#security-settings)
7. [Request Flow Examples](#request-flow-examples)
8. [Changes Made for Bonus Services](#changes-made-for-bonus-services)

---

## Basic NGINX Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      INTERNET (Users)                        │
│                                                              │
│            HTTP Request (Port 80)                            │
│            ↓                                                 │
│            NGINX: Redirects to HTTPS                        │
│                                                              │
│            HTTPS Request (Port 443)                          │
└──────────────┬──────────────────────────────────────────────┘
               │
               ↓ (TLS encrypted)
        ┌──────────────┐
        │    NGINX     │
        │  (Port 443)  │
        └──────┬───────┘
               │
    ┌──────────┼──────────┬──────────┬──────────┐
    │          │          │          │          │
    ↓          ↓          ↓          ↓          ↓
  WordPress  Adminer  Static Site  Uptime    Other
  :9000      :8080      :8080      :5000
```

---

## Configuration Locations

**Main NGINX Config File:**
```
/home/mel-bouh/Inception/srcs/requirements/nginx/conf/default.conf
```

**NGINX Container:**
- Base: `debian:bookworm`
- Config mounted at: `/etc/nginx/sites-available/default`
- Logs: `/var/log/nginx/`
- Process: Runs in foreground (required for Docker)

---

## Full Configuration Breakdown

### 1. Server Block - Basic Setup

```nginx
server {
    listen 443 ssl;                          # Listen ONLY on HTTPS
    server_name mel-bouh.42.fr;              # Domain name
    root /var/www/html;                      # Default root (WordPress)
    index index.php index.html;              # Default files to serve
```

**Explanation:**

- `listen 443 ssl;` - Only accepts HTTPS connections on port 443
  - HTTP (port 80) is NOT configured, so all HTTP requests are rejected
  - `ssl` flag enables TLS/SSL protocol
  
- `server_name mel-bouh.42.fr;` - Which domain this config applies to
  - Must match the domain in your certificate
  
- `root /var/www/html;` - Default directory for all requests
  - This is the WordPress data volume
  - Can be overridden by location blocks
  
- `index index.php index.html;` - When user requests `/`, look for:
  - First: `index.php` (WordPress entry point)
  - Second: `index.html` (fallback)

---

### 2. TLS/SSL Configuration

```nginx
ssl_certificate /etc/ssl/certs/nginx.crt;
ssl_certificate_key /etc/ssl/private/nginx.key;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
```

**Explanation:**

- `ssl_certificate` - Path to public certificate file
  - This is the certificate presented to browsers
  - Generated automatically in the Dockerfile
  - Valid for 365 days
  
- `ssl_certificate_key` - Path to private key
  - Never exposed to internet (kept secret)
  - Only NGINX reads this
  
- `ssl_protocols TLSv1.2 TLSv1.3;` - Allowed TLS versions
  - TLSv1.2: Industry standard, widely supported
  - TLSv1.3: Newest, faster, more secure
  - TLSv1.0 and TLSv1.1: Explicitly disabled (outdated)
  - **Requirement**: Inception subject forbids TLSv1.0 and TLSv1.1
  
- `ssl_prefer_server_ciphers on;` - Use server's cipher preferences
  - Server chooses strongest cipher (not client)
  - Improves security

---

### 3. Main WordPress Route

```nginx
location / {
    try_files $uri $uri/ /index.php?$args;
}
```

**How it works (most important location block):**

When user requests `https://mel-bouh.42.fr/some-page/`

1. **Try 1**: Look for exact file `/some-page/` on disk
   - If found, serve it
   - If not, continue to Try 2

2. **Try 2**: Look for directory `/some-page/` on disk
   - If found (with index.php inside), serve index.php
   - If not, continue to Try 3

3. **Try 3**: Forward to `/index.php?some-page/` (WordPress processing)
   - WordPress gets the URL and generates page content
   - The `?$args` preserves query string parameters

**Why this matters:**
```
Request: https://mel-bouh.42.fr/hello-world/
  ↓
WordPress serves page content for that URL
  ↓
Browser shows: Hello World post

WITHOUT try_files:
  ↓
NGINX returns 404 (directory doesn't exist on disk)
  ↓
Browser shows: Page Not Found
```

---

### 4. PHP Handling

```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass wordpress:9000;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
}
```

**How it works:**

```
Request: https://mel-bouh.42.fr/wp-admin/
  ↓
Matches location ~ \.php$ (regex: any .php file)
  ↓
NGINX passes to PHP-FPM on wordpress:9000
  ↓
WordPress PHP code executes
  ↓
Returns HTML to browser
```

**Key parameters explained:**

- `location ~ \.php$` - Regular expression match
  - `~` = regex matching
  - `\.php$` = files ending in .php
  - Example matches: `index.php`, `wp-admin.php`, `wp-login.php`
  
- `include snippets/fastcgi-php.conf;` - Standard PHP-FPM settings
  - This is a pre-configured file in Debian
  - Sets up FastCGI protocol parameters
  
- `fastcgi_pass wordpress:9000;` - Forward request to PHP-FPM
  - `wordpress` = Docker container hostname (resolved via DNS)
  - `:9000` = Port where PHP-FPM listens
  - **Docker networking**: NGINX resolves "wordpress" → container IP
  
- `fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;`
  - Tells PHP-FPM the full file path to execute
  - Example: `/var/www/html/index.php`
  
- `include fastcgi_params;` - All standard FastCGI variables
  - `REQUEST_METHOD`, `QUERY_STRING`, `SERVER_NAME`, etc.

---

### 5. Adminer - Database Management

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

**How it works:**

```
User accesses: https://mel-bouh.42.fr/adminer
  ↓
Matches location /adminer
  ↓
Rewrite: /adminer → /adminer.php (clean URL)
  ↓
Proxy to: http://adminer:8080/adminer.php
  ↓
Adminer container receives request
  ↓
PHP executes adminer.php
  ↓
Returns HTML (database management interface)
  ↓
Browser displays Adminer UI
```

**Rewrite rule explained:**

```nginx
rewrite ^/adminer$ /adminer.php break;
```

- `^/adminer$` - Only matches exact URL `/adminer` (no trailing slash)
- `^` = start of string, `$` = end of string
- `/adminer.php` - Rewrite to this internal path
- `break` - Stop processing other rewrite rules

**Proxy headers explained:**

```nginx
proxy_set_header Host $host;
```
- Passes original `Host` header to backend
- Adminer knows it's accessed as `mel-bouh.42.fr` (not `localhost`)

```nginx
proxy_set_header X-Real-IP $remote_addr;
```
- Passes client's real IP address
- Backend sees who actually made the request
- Default: Backend would see NGINX's IP (not client)

```nginx
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```
- Builds list of all IPs in the proxy chain
- Example: `203.0.113.1, 192.0.2.1` (client, then NGINX)

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
```
- Tells backend: "I received this via HTTPS"
- `$scheme` = `http` or `https`
- Backend can generate HTTPS URLs in responses

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

**How it works:**

```
User accesses: https://mel-bouh.42.fr/portfolio
  ↓
Matches location /portfolio
  ↓
Proxy to: http://static-site:8080/
  ↓
NGINX strips /portfolio prefix
  ↓
Static-site NGINX serves /var/www/static/index.html
  ↓
Returns HTML (portfolio page)
  ↓
Browser displays your portfolio
```

**Key difference from other proxies:**
- Trailing slash in `proxy_pass http://static-site:8080/;`
- This strips `/portfolio` from the URL
- Without slash: `/portfolio` → `/portfolio/` (keeps path)

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

**How it works:**

```
User accesses: https://mel-bouh.42.fr/uptime
  ↓
Matches location /uptime
  ↓
Proxy to: http://uptime-monitor:5000/
  ↓
Flask web server receives request
  ↓
Renders dashboard with database data
  ↓
Returns HTML (monitoring dashboard)
  ↓
Browser displays real-time uptime stats
```

**API requests also work:**
```
Request: https://mel-bouh.42.fr/uptime/api/status
  ↓
Matches location /uptime
  ↓
Strips /uptime → /api/status
  ↓
Flask route @app.route('/api/status')
  ↓
Returns JSON response
```

---

### 8. Security - Deny Hidden Files

```nginx
location ~ /\. {
    deny all;
}
```

**Why this matters:**

Without this, attackers could access:
- `/.env` - Database passwords, secrets
- `/.git/` - Source code, git history
- `/.htaccess` - Apache configuration
- `/.aws/credentials` - AWS keys

**How it works:**

- `location ~ /\.` - Regex match: files starting with `.`
- `deny all;` - Block all access to these files

**Results:**
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

## All Location Blocks - Summary Table

| Path | Destination | Type | Purpose |
|------|-------------|------|---------|
| `/` | WordPress PHP-FPM | FastCGI | Main WordPress site |
| `*.php` | WordPress PHP-FPM | FastCGI | PHP execution |
| `/adminer` | Adminer:8080 | Proxy | Database management |
| `/portfolio` | Static-site:8080 | Proxy | Portfolio website |
| `/uptime` | Uptime-monitor:5000 | Proxy | Health monitoring |
| `/.*` (hidden files) | DENIED | Deny | Security |

---

## Proxy Headers Explained

### The Problem (Without Proper Headers)

```
Client → NGINX → Backend Service

Backend Service sees:
  - Remote IP: NGINX container IP (not client)
  - Host: localhost (not mel-bouh.42.fr)
  - Protocol: http (not https)
  - No way to know who actually accessed it
```

### The Solution (With Headers)

```nginx
proxy_set_header Host $host;                         # Original domain
proxy_set_header X-Real-IP $remote_addr;             # Client IP
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  # IP chain
proxy_set_header X-Forwarded-Proto $scheme;          # Original protocol
```

Backend Service now sees:
```
Host: mel-bouh.42.fr
X-Real-IP: 203.0.113.1 (actual client)
X-Forwarded-For: 203.0.113.1, 172.17.0.1 (client, then NGINX)
X-Forwarded-Proto: https (original protocol)
```

---

## Security Settings

### TLS Version Restrictions

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

**Why this matters:**

| Version | Year | Security | Status |
|---------|------|----------|--------|
| TLSv1.0 | 2006 | ❌ Weak | DISABLED (required by Inception) |
| TLSv1.1 | 2006 | ❌ Weak | DISABLED (required by Inception) |
| TLSv1.2 | 2008 | ✅ Good | ENABLED (industry standard) |
| TLSv1.3 | 2018 | ✅✅ Excellent | ENABLED (modern, faster) |

**Inception Requirement:**
> Must use only TLSv1.2 and TLSv1.3

---

## Request Flow Examples

### Example 1: Accessing WordPress

```
User types: https://mel-bouh.42.fr/
  ↓
Browser connects to NGINX port 443 (HTTPS)
  ↓
TLS handshake (certificate validation)
  ↓
GET / request
  ↓
NGINX checks locations:
  ├─ / matches location /
  ├─ try_files: exact file? No
  ├─ try_files: directory? No
  └─ forward to /index.php?/
  ↓
/index.php matches location ~ \.php$
  ↓
NGINX proxies to wordpress:9000 (PHP-FPM)
  ↓
WordPress code executes
  ↓
Generates HTML
  ↓
Returns to NGINX
  ↓
NGINX returns to browser
  ↓
Browser displays homepage
```

### Example 2: Accessing Adminer

```
User types: https://mel-bouh.42.fr/adminer
  ↓
Browser connects to NGINX port 443 (HTTPS)
  ↓
TLS handshake
  ↓
GET /adminer request
  ↓
NGINX checks locations:
  ├─ Matches location /adminer
  ├─ Rewrite: /adminer → /adminer.php
  ├─ Proxy to: http://adminer:8080/adminer.php
  └─ Add headers: Host, X-Real-IP, etc.
  ↓
Adminer container receives request
  ↓
PHP executes adminer.php
  ↓
Renders database management UI
  ↓
Returns HTML to NGINX
  ↓
NGINX returns to browser
  ↓
Browser displays Adminer interface
```

### Example 3: API Request to Uptime Monitor

```
Curl: https://mel-bouh.42.fr/uptime/api/status
  ↓
Browser/API client connects to NGINX
  ↓
GET /uptime/api/status request
  ↓
NGINX checks locations:
  ├─ Matches location /uptime
  ├─ Strips /uptime prefix
  ├─ Proxy to: http://uptime-monitor:5000/api/status
  └─ Add headers
  ↓
Flask app receives /api/status
  ↓
Route @app.route('/api/status') matches
  ↓
Python function executes
  ↓
Queries database for current status
  ↓
Returns JSON response
  ↓
NGINX returns JSON to client
  ↓
Client parses JSON ({"status": "UP", ...})
```

---

## Changes Made for Bonus Services

### 1. Original Configuration (Minimal)

```nginx
server {
    listen 443 ssl;
    ...
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        fastcgi_pass wordpress:9000;
        ...
    }
}
```

Only WordPress, no bonus services.

### 2. Added Adminer Route

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

**Why added:**
- Allows web-based database management
- No database access from command line

### 3. Added Static Site Route

```nginx
location /portfolio {
    proxy_pass http://static-site:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**Why added:**
- Showcase your work
- Separate container (better isolation)
- No database needed

### 4. Added Uptime Monitor Route (YOUR CUSTOM SERVICE)

```nginx
location /uptime {
    proxy_pass http://uptime-monitor:5000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**Why added:**
- Monitor website health 24/7
- Beautiful dashboard with statistics
- REST APIs for automation
- Your custom bonus service

### 5. Security - Deny Hidden Files

```nginx
location ~ /\. {
    deny all;
}
```

**Why added:**
- Prevent access to sensitive files
- Blocks .env, .git, .htaccess, etc.
- Required for security

---

## Complete Current Configuration

```nginx
server {
    listen 443 ssl;
    server_name mel-bouh.42.fr;
    root /var/www/html;
    index index.php index.html;

    ssl_certificate /etc/ssl/certs/nginx.crt;
    ssl_certificate_key /etc/ssl/private/nginx.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Main WordPress routing
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # PHP handling
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass wordpress:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # BONUS: Adminer
    location /adminer {
        rewrite ^/adminer$ /adminer.php break;
        proxy_pass http://adminer:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # BONUS: Static Portfolio Site
    location /portfolio {
        proxy_pass http://static-site:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # BONUS: Uptime Monitor
    location /uptime {
        proxy_pass http://uptime-monitor:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Security: Deny hidden files
    location ~ /\. {
        deny all;
    }
}
```

---

## Key Takeaways

1. **NGINX is the entry point** - All traffic flows through it
2. **Reverse proxy pattern** - NGINX forwards requests to backend services
3. **TLS termination** - NGINX handles HTTPS encryption/decryption
4. **Request routing** - Different URLs go to different services
5. **Header propagation** - Backend services know who really accessed them
6. **Security hardening** - Hidden files blocked, TLS versions restricted

---

## Makefile Changes

The Makefile now supports:

```bash
make bonus       # Build and start ONLY bonus services
make bonus-build # Build only bonus service images
make bonus-up    # Start only bonus services
make bonus-down  # Stop only bonus services
make bonus-logs  # View bonus service logs
```

This allows you to:
- Develop bonus services independently
- Restart them without affecting WordPress
- Test individual services
- View logs separately

---

**That's everything about the NGINX configuration and Makefile changes!**
