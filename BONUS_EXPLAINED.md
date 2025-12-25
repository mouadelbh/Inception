# BONUS SERVICES - DEEP DIVE EXPLANATION

## Table of Contents
1. [Implemented Bonus Services](#implemented-bonus-services)
2. [1. Adminer - Database Management](#1-adminer---database-management)
3. [2. Redis - Object Caching](#2-redis---object-caching)
4. [3. FTP Server - File Management](#3-ftp-server---file-management)
5. [4. Static Site - Portfolio](#4-static-site---portfolio)
6. [Proposed Custom Service](#proposed-custom-service)
7. [Implementation Guide](#implementation-guide)

---

## Implemented Bonus Services

You currently have **4 bonus services** implemented. The Inception subject requires at least 3 bonus services for maximum points. Let's understand each one in detail.

---

## 1. Adminer - Database Management

### What is Adminer?
Adminer is a **single-file PHP database management tool** - it's like phpMyAdmin but much lighter (just one 500KB PHP file vs dozens of files).

### Why Do We Need It?

**Problem**: Your MariaDB database is inside a container with no direct access. You need to:
- View database tables
- Execute SQL queries
- Export/import data
- Debug database issues
- Manage WordPress database without CLI

**Solution**: Adminer provides a web-based GUI to manage your database.

### How It Works (Low Level)

#### Architecture:
```
Browser (You)
    ↓ HTTPS
NGINX (port 443)
    ↓ HTTP reverse proxy
Adminer Container (port 8080)
    ↓ PHP processes adminer.php
    ↓ MySQL protocol (port 3306)
MariaDB Container
```

#### Step-by-Step Process:

1. **You access**: `https://mel-bouh.42.fr/adminer`

2. **NGINX receives request** and matches this location block:
   ```nginx
   location /adminer {
       proxy_pass http://adminer:8080;
   }
   ```

3. **NGINX proxies** the request to `adminer:8080` (Docker internal DNS resolves "adminer" to container IP)

4. **Adminer container** runs PHP's built-in web server:
   ```bash
   php -S 0.0.0.0:8080 -t /var/www/html
   ```
   - `-S 0.0.0.0:8080`: Listen on all interfaces, port 8080
   - `-t /var/www/html`: Document root (where adminer.php lives)

5. **PHP executes** `adminer.php`:
   - Renders HTML form for database login
   - You enter: Server=`mariadb`, Username=`mel-bouh`, Password, Database=`wordpress`
   - Adminer connects to MariaDB using PHP's `mysqli` extension
   - Queries database and displays results in HTML

#### Why This Design?

- **Lightweight**: Single PHP file (500KB) vs phpMyAdmin (11MB+)
- **Secure**: Only accessible through NGINX (HTTPS), not directly exposed
- **Isolated**: Runs in its own container, can't affect other services
- **No persistence needed**: No data to save, just a tool

#### Network Communication:
```
adminer container → mariadb container
Protocol: MySQL wire protocol (TCP)
Port: 3306 (internal Docker network)
DNS: Docker resolves "mariadb" to container IP
```

### Usage:
1. Visit: `https://mel-bouh.42.fr/adminer`
2. Login with:
   - System: MySQL
   - Server: `mariadb`
   - Username: `mel-bouh`
   - Password: `mel-bouh123`
   - Database: `wordpress`

---

## 2. Redis - Object Caching

### What is Redis?
Redis is an **in-memory key-value data store**. Think of it as a super-fast RAM-based database.

### Why Do We Need It?

**Problem**: WordPress is slow because:
- Every page request hits the database multiple times
- Complex queries take time (JOIN operations)
- Database is on disk (slow I/O)
- Same queries repeat for every visitor

**Solution**: Redis caches database results in RAM (1000x faster than disk).

### How It Works (Low Level)

#### Without Redis (Slow):
```
User requests page
    ↓
WordPress
    ↓ Query database (10ms)
MariaDB (disk I/O)
    ↓ Return results
WordPress renders page
    ↓
Send to user
```

#### With Redis (Fast):
```
User requests page
    ↓
WordPress checks Redis first
    ↓
Redis (RAM) → Returns cached data (0.1ms) ✓
    ↓ (cache hit)
WordPress renders page immediately
    ↓
Send to user

If cache miss:
    ↓ Query database (10ms)
MariaDB
    ↓ Store result in Redis
Redis
    ↓ Return to WordPress
```

#### Redis Configuration Explained:

```bash
bind 0.0.0.0              # Listen on all interfaces (Docker requires this)
protected-mode no          # Allow connections from other containers
maxmemory 256mb           # Limit memory usage to 256MB
maxmemory-policy allkeys-lru  # When full, remove Least Recently Used keys
```

**Why these settings?**
- `bind 0.0.0.0`: Docker containers need to connect from different IPs
- `protected-mode no`: Redis won't accept connections from other IPs by default
- `maxmemory 256mb`: Prevents Redis from eating all your RAM
- `allkeys-lru`: Automatically removes old cached data when memory is full

#### How WordPress Uses Redis:

1. **WordPress plugin** (Redis Object Cache) installed
2. **First request**: Data not in Redis
   - WordPress queries MariaDB
   - Stores result in Redis with key like: `wp:posts:123`
   - Returns data to user
3. **Second request**: Data in Redis
   - WordPress checks Redis first
   - Gets data instantly from RAM
   - Skips database entirely
4. **Cache invalidation**: When you update a post
   - WordPress deletes the Redis key
   - Next request will fetch fresh data from database
   - Stores new version in Redis

#### Communication Protocol:

```
WordPress → Redis
Protocol: RESP (Redis Serialization Protocol)
Port: 6379
Commands:
  - GET key → Retrieve cached data
  - SET key value → Store data
  - DEL key → Delete cache
  - EXPIRE key seconds → Auto-delete after time
```

#### What Gets Cached?

- Database query results
- Post content and metadata
- User sessions
- Menu items
- Sidebar widgets
- Theme settings
- Plugin data

#### Performance Impact:

| Operation | Without Redis | With Redis | Speedup |
|-----------|---------------|------------|---------|
| Page load | 500ms | 50ms | 10x |
| Database queries | 50/page | 5/page | 10x |
| Memory usage | Low | +256MB | - |

### Why This Design?

- **Speed**: RAM is 1000x faster than disk
- **Scalability**: Handles thousands of concurrent users
- **Automatic**: Plugin handles everything, no manual configuration
- **Volatile**: Data loss on restart is OK (just a cache, not primary storage)

---

## 3. FTP Server - File Management

### What is FTP?
FTP (File Transfer Protocol) is a network protocol for **uploading and downloading files** between computers.

### Why Do We Need It?

**Problem**: WordPress files are inside a Docker container:
- Can't easily edit theme files
- Can't upload large media files through WordPress admin
- Need command-line access just to view files
- Designers want to edit CSS/HTML directly

**Solution**: FTP server allows file access using familiar FTP clients (FileZilla, Cyberduck, etc.)

### How It Works (Low Level)

#### FTP Architecture:
```
FTP Client (FileZilla on your computer)
    ↓
Port 21 (Control connection - commands)
    ↓
vsftpd (FTP server in container)
    ↓
Port 21100-21110 (Data connections - actual files)
    ↓
Shared Volume: /var/www/html (WordPress files)
```

#### Two Types of Connections:

**1. Control Connection (Port 21)**:
- Sends commands: LOGIN, LIST, DELETE, UPLOAD
- Stays open entire session
- Text-based protocol

**2. Data Connection (Port 21100-21110)**:
- Transfers actual file data
- Opens/closes for each file
- Binary or ASCII mode

#### vsftpd Configuration Explained:

```properties
# Security
anonymous_enable=NO        # No anonymous login (require username/password)
local_enable=YES           # Allow system users to login
write_enable=YES           # Allow uploads/deletions

# Chroot Jail (Security)
chroot_local_user=YES      # Lock users to their home directory
allow_writeable_chroot=YES # Allow writing in chroot (WordPress needs this)
```

**What is chroot?**
- "Change root" - makes `/var/www/html` appear as `/` to the FTP user
- User can't navigate to `/etc` or `/root` (security!)
- They only see WordPress files

**Passive Mode** (Required for Docker):
```properties
pasv_enable=YES           # Enable passive mode
pasv_min_port=21100       # Minimum port for data connections
pasv_max_port=21110       # Maximum port for data connections
pasv_address=<your-vm-ip> # Public IP address
```

**Why passive mode?**
- **Active mode**: Server connects to client (NAT blocks this)
- **Passive mode**: Client connects to server (works through NAT)

#### Setup Script Explained:

```bash
#!/bin/bash
# Create FTP user
useradd -m -d /var/www/html -s /bin/bash "$FTP_USER"
```
- `-m`: Create home directory
- `-d /var/www/html`: Home is WordPress directory
- `-s /bin/bash`: Shell (needed for login)

```bash
echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
```
- Sets the user's password from environment variable

```bash
chown -R "$FTP_USER:$FTP_USER" /var/www/html
```
- Makes FTP user owner of all WordPress files
- Allows read/write access

#### Connection Flow:

1. **Client connects** to port 21:
   ```
   CLIENT: Connect to ftp.example.com:21
   SERVER: 220 Welcome to vsftpd
   CLIENT: USER ftpuser
   SERVER: 331 Please specify password
   CLIENT: PASS password123
   SERVER: 230 Login successful
   ```

2. **Client lists files**:
   ```
   CLIENT: PASV (enter passive mode)
   SERVER: 227 Entering Passive Mode (192,168,1,100,82,100)
           ↑ Means connect to 192.168.1.100:21100
   CLIENT: LIST (send list command)
   CLIENT: Connects to port 21100
   SERVER: Sends file list through port 21100
   SERVER: 226 Directory send OK
   ```

3. **Client uploads file**:
   ```
   CLIENT: PASV
   SERVER: 227 Entering Passive Mode (...)
   CLIENT: STOR theme.css
   CLIENT: Connects to data port
   CLIENT: Sends file data
   SERVER: Writes to /var/www/html/wp-content/themes/.../theme.css
   SERVER: 226 Transfer complete
   ```

#### Why Ports 21100-21110?

- FTP needs multiple ports for parallel transfers
- Each file transfer = new data connection
- Range of 11 ports = 11 simultaneous transfers
- Docker must expose these ports: `ports: ["21:21", "21100-21110:21100-21110"]`

#### Shared Volume:

```yaml
volumes:
  - wordpress_data:/var/www/html
```

- **Same volume** as WordPress container
- FTP writes → WordPress reads immediately
- Real-time synchronization
- No file copying needed

### Usage:

**FileZilla Connection:**
- Host: `ftp://mel-bouh.42.fr` (or your VM IP)
- Port: `21`
- Username: `$FTP_USER` (from .env)
- Password: `$FTP_PASSWORD` (from .env)

**Common Tasks:**
- Edit `wp-content/themes/*/style.css` - Update theme styles
- Upload to `wp-content/uploads/` - Add media files
- Download `wp-config.php` - Backup configuration

---

## 4. Static Site - Portfolio

### What is It?
A simple **static HTML/CSS website** served by NGINX - your personal portfolio/resume page.

### Why Do We Need It?

**Problem**: WordPress is overkill for a simple portfolio:
- Requires database
- Requires PHP processing
- Slower
- More complex

**Solution**: Pure HTML/CSS served directly by NGINX (fastest possible).

### How It Works (Low Level)

#### Architecture:
```
Browser
    ↓ HTTPS
NGINX (main container)
    ↓ HTTP proxy
Static-Site Container (NGINX on port 8080)
    ↓
Serves: /var/www/static/index.html (from disk)
```

#### Why Separate Container?

- **Isolation**: Keeps your portfolio separate from WordPress
- **Independence**: Can restart WordPress without affecting portfolio
- **Clean architecture**: One service = one container
- **Different NGINX config**: Portfolio doesn't need PHP

#### Static-Site NGINX Config:

```nginx
server {
    listen 8080;                     # Internal port (not exposed to internet)
    root /var/www/static;            # Serve files from this directory
    index index.html;                # Default file
    
    location / {
        try_files $uri $uri/ =404;   # Serve file or 404
    }
}
```

**How `try_files` works:**
1. Try `$uri` - If `/about.html` → serve `about.html`
2. Try `$uri/` - If `/about/` → serve `about/index.html`
3. Else `=404` - Return 404 error

#### Main NGINX Proxy Config:

```nginx
location /portfolio {
    proxy_pass http://static-site:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

**Request Flow:**
1. User: `https://mel-bouh.42.fr/portfolio`
2. Main NGINX strips `/portfolio` prefix
3. Proxies to `http://static-site:8080/`
4. Static-site NGINX serves `/var/www/static/index.html`
5. Response goes back through proxy chain

#### Why Not Serve Directly from Main NGINX?

You could, but separating has benefits:
- **Bonus points**: Subject requires separate container
- **Clean separation**: WordPress files vs portfolio files
- **Easy updates**: Rebuild only static-site container
- **Portability**: Can move portfolio to different server easily

#### What's in the Static Files?

**index.html**:
- Personal profile with avatar
- Skills list (C, C++, Docker, etc.)
- 42 projects showcase
- Contact information
- Pure HTML5 semantic markup

**style.css**:
- Modern gradient design (dark theme)
- Responsive layout (mobile-friendly)
- CSS animations (hover effects)
- Flexbox/Grid layout
- No JavaScript needed (fast!)

### Usage:
Visit: `https://mel-bouh.42.fr/portfolio`

### Performance:

| Metric | Static Site | WordPress |
|--------|-------------|-----------|
| Response time | 5ms | 500ms |
| Database queries | 0 | 20+ |
| Memory usage | 10MB | 200MB |
| Requests/second | 10,000+ | 100 |

**Why so fast?**
- No PHP processing (just read file from disk)
- No database queries
- No server-side rendering
- NGINX serves files directly from memory cache
- HTML already pre-rendered

---

## Network Architecture

All bonus services communicate through Docker's internal bridge network:

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Bridge Network                     │
│                      (inception)                             │
│                                                               │
│  ┌──────────┐   ┌───────────┐   ┌────────┐   ┌──────────┐  │
│  │ MariaDB  │───│ WordPress │───│ NGINX  │───│ Outside  │  │
│  │  :3306   │   │   :9000   │   │  :443  │   │ Internet │  │
│  └──────────┘   └───────────┘   └────────┘   └──────────┘  │
│       ↑               ↑             ↑  ↑                     │
│       │               │             │  │                     │
│  ┌────┴────┐     ┌───┴────┐   ┌────┴──┴─────┐              │
│  │ Adminer │     │ Redis  │   │ Static Site  │              │
│  │  :8080  │     │ :6379  │   │    :8080     │              │
│  └─────────┘     └────────┘   └──────────────┘              │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    FTP Server                            ││
│  │  :21 (control) + :21100-21110 (data)                    ││
│  │  Shared volume: wordpress_data                          ││
│  └─────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────┘

External Ports Exposed:
- 443 → NGINX (HTTPS)
- 21 → FTP (Control)
- 21100-21110 → FTP (Data)

Internal Communication:
- All services use Docker DNS (e.g., "mariadb" resolves to container IP)
- No hardcoded IPs
- Bridge network isolates from host
```

---

## Proposed Custom Service

The Inception subject requires **"a service of your own"**. Here's a professional suggestion:

### Service: Application Monitoring Dashboard (Grafana + Prometheus)

#### What It Does:
Real-time monitoring and visualization of your infrastructure:
- Container resource usage (CPU, RAM, disk)
- Website response times
- Database query performance
- Redis cache hit rates
- Traffic statistics

#### Why This Service?

**Practical Value:**
- Real DevOps tool used in production
- Demonstrates understanding of monitoring
- Shows complete infrastructure management
- Useful for debugging and optimization

**Technical Depth:**
- Time-series database (Prometheus)
- Data visualization (Grafana)
- Metrics collection from all containers
- Custom dashboards with PromQL queries

#### Architecture:

```
┌─────────────────────────────────────────────────────┐
│                  All Containers                     │
│  (NGINX, WordPress, MariaDB, Redis, etc.)          │
└──────────────┬──────────────────────────────────────┘
               │ Expose metrics
               ↓
┌─────────────────────────────────────────────────────┐
│              Prometheus (port 9090)                  │
│  - Scrapes metrics every 15s                        │
│  - Stores time-series data                          │
│  - Provides query API                               │
└──────────────┬──────────────────────────────────────┘
               │ Query data
               ↓
┌─────────────────────────────────────────────────────┐
│              Grafana (port 3000)                     │
│  - Beautiful dashboards                             │
│  - Real-time graphs                                 │
│  - Alerts and notifications                         │
└─────────────────────────────────────────────────────┘
```

### Alternative Simpler Service: Website Uptime Monitor

#### What It Does:
Constantly checks if your WordPress site is up and healthy:
- HTTP health checks every 30 seconds
- Logs response times
- Detects downtime
- Sends alerts (email/webhook)
- Historical uptime statistics

#### Why This Service?

**Simpler to implement:**
- Single Python/Go script
- Lightweight (10MB container)
- Easy to understand
- Practical usefulness

**Good for learning:**
- HTTP requests and APIs
- Cron-like scheduling
- Logging and alerting
- Container-to-container communication

---

## Implementation Guide

### Option 1: Grafana + Prometheus (Advanced)

I can help you implement a complete monitoring stack with:

1. **Prometheus Container**: Collects metrics
2. **Grafana Container**: Visualizes data
3. **Node Exporter**: System metrics (CPU, RAM, disk)
4. **cAdvisor**: Docker container metrics
5. **Custom Dashboard**: Pre-configured panels

**Dashboard Features:**
- Real-time CPU/Memory usage per container
- Network traffic graphs
- Database connection pool status
- Redis cache statistics
- NGINX request rate and response times
- WordPress PHP-FPM pool status

### Option 2: Uptime Monitor (Beginner-Friendly)

I can create a simple but effective uptime monitor:

**Features:**
- Checks `https://mel-bouh.42.fr/` every 30s
- Measures response time
- Verifies SSL certificate validity
- Logs results to file (persistent volume)
- Simple web UI showing status (up/down + history)
- Can send webhook notifications (Discord/Slack)

**Technologies:**
- Python Flask (web UI)
- Requests library (HTTP checks)
- SQLite (log storage)
- Simple HTML dashboard

---

## What Would You Like?

### Quick Decision Matrix:

| Feature | Grafana+Prometheus | Uptime Monitor |
|---------|-------------------|----------------|
| Complexity | High | Low |
| Learning value | Very high | Moderate |
| Setup time | 2-3 hours | 30 minutes |
| Real-world use | Production-grade | Hobbyist/startup |
| Coolness factor | 🔥🔥🔥 | 🔥 |

**My recommendation:** 
- If you want to impress and learn advanced DevOps: **Grafana + Prometheus**
- If you want something practical and quick: **Uptime Monitor**

I can implement either one with full documentation and explanations. Which would you prefer?

---

## Summary

### Current Bonus Services:

1. **Adminer** ✅ - Database management web UI
2. **Redis** ✅ - WordPress object caching (10x performance boost)
3. **FTP** ✅ - File management for WordPress files
4. **Static Site** ✅ - Portfolio/resume website

### What You Need:

5. **Custom Service** ❌ - Your own choice of service

All bonus services work together in a Docker network, each serving a specific purpose:
- Adminer: Database management tool
- Redis: Performance optimization
- FTP: File access for developers/designers
- Static Site: Showcase your work

Each container is isolated, communicates via Docker networking, and follows the principle of "one service per container."

---

**Ready to implement your custom service? Let me know which option you prefer, and I'll guide you through the complete implementation with low-level explanations!**
