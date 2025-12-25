# Uptime Monitor - Complete Documentation

## Overview

The Uptime Monitor is your **custom bonus service** for the Inception project. It continuously monitors your WordPress website's health and availability 24/7, providing real-time statistics and historical data through a beautiful web dashboard.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture](#architecture)
3. [How It Works](#how-it-works)
4. [Features](#features)
5. [REST API](#rest-api)
6. [Technical Details](#technical-details)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Start All Services (Including Uptime Monitor)

```bash
cd /home/mel-bouh/Inception
make re                    # Clean rebuild and start
# or
docker compose up -d       # Start all containers
```

### Access the Dashboard

```bash
# Via HTTPS (production)
https://mel-bouh.42.fr/uptime

# Via HTTP (if testing locally)
http://localhost:5000
```

### Verify It's Running

```bash
# Check container status
docker compose ps

# View logs
docker compose logs -f uptime-monitor

# Test API endpoint
curl https://mel-bouh.42.fr/uptime/api/status | jq
```

---

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────┐
│           Uptime Monitor Container                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │      Main Thread: Flask Web Server              │   │
│  │      • Listens on 0.0.0.0:5000                  │   │
│  │      • Serves HTML dashboard                    │   │
│  │      • Provides REST APIs                       │   │
│  │      • Non-blocking (async handling)            │   │
│  └─────────────────────────────────────────────────┘   │
│                        ↕                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │   Background Thread: Monitoring Engine          │   │
│  │   • Wakes every 30 seconds                      │   │
│  │   • Sends HTTPS GET request                     │   │
│  │   • Measures response time                      │   │
│  │   • Checks certificate expiry                   │   │
│  │   • Inserts results into SQLite                 │   │
│  └─────────────────────────────────────────────────┘   │
│                        ↕                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │    SQLite Database: /data/uptime.db             │   │
│  │    • Persistent storage                         │   │
│  │    • Health check history                       │   │
│  │    • Survives container restarts                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
         ↓
    NGINX (Reverse Proxy)
         ↓
    User's Browser
```

### Container Configuration

```yaml
# docker-compose.yml
uptime-monitor:
  container_name: uptime-monitor
  build:
    context: ./requirements/bonus/uptime-monitor
  networks:
    - inception          # Connected to Docker bridge
  expose:
    - "5000"            # Internal port (not exposed externally)
  volumes:
    - uptime_monitor_data:/data  # Persistent data storage
  restart: unless-stopped
```

### Shared Volume

```bash
# Host path
/home/mel-bouh/data/uptime-monitor/

# Contains:
uptime.db           # SQLite database with check history
monitor.log         # Log file with all operations
```

---

## How It Works

### Startup Process (When Container Starts)

```
1. Docker starts uptime-monitor container
2. Python 3 runtime initializes
3. Flask module imported
4. SQLite database checked/created
5. Background monitoring thread spawned (daemon)
6. Flask web server starts on port 5000
7. Monitor thread begins health checks (1 every 30s)
8. Dashboard accessible at http://uptime-monitor:5000/
```

### Monitoring Cycle (Every 30 Seconds)

```python
while True:
    start_time = time.time()
    
    try:
        # 1. Create HTTPS connection
        session = requests.Session()
        
        # 2. Send GET request with 10-second timeout
        response = session.get(
            "https://mel-bouh.42.fr",
            timeout=10,
            verify=False  # Accept self-signed certs
        )
        
        # 3. Measure response time
        response_time_ms = (time.time() - start_time) * 1000
        
        # 4. Check HTTP status code
        status_code = response.status_code
        
        # Status determination:
        if 200 <= status_code < 300:
            status = "UP"
        else:
            status = "DOWN"
        
        # 5. Extract and verify SSL certificate
        cert_expiry_days = check_certificate_validity()
        
        # 6. Store in database
        db.insert(
            timestamp=now(),
            status=status,
            response_time=response_time_ms,
            status_code=status_code,
            cert_expiry=cert_expiry_days
        )
        
        # 7. Log result
        print(f"✓ {status} ({response_time_ms}ms)")
    
    except requests.exceptions.Timeout:
        db.insert(status="DOWN", error="Timeout")
        print("✗ DOWN (Timeout)")
    
    except requests.exceptions.ConnectionError:
        db.insert(status="DOWN", error="Connection refused")
        print("✗ DOWN (Connection error)")
    
    except Exception as e:
        db.insert(status="DOWN", error=str(e))
        print(f"✗ DOWN ({e})")
    
    # 8. Sleep until next check
    time.sleep(30)
```

### User Accesses Dashboard

```
1. User opens: https://mel-bouh.42.fr/uptime

2. NGINX receives HTTPS request on port 443
   ↓
3. NGINX matches location /uptime
   ↓
4. NGINX proxies to: http://uptime-monitor:5000/
   ↓
5. Flask receives request in main thread
   ↓
6. Route handler queries SQLite database:
   - SELECT * FROM health_checks 
     WHERE timestamp > now() - 24 hours
   ↓
7. Calculates statistics:
   - uptime_percentage = (up_count / total_count) * 100
   - avg_response_time = SUM(response_time) / count
   - last_check = MAX(timestamp)
   ↓
8. Renders HTML template with data
   ↓
9. Returns HTML to NGINX
   ↓
10. NGINX sends to browser
    ↓
11. Browser displays dashboard with:
    - Live status indicator (green/red pulse)
    - Uptime percentage
    - Recent check history table
    - Performance graphs
```

---

## Features

### 1. Real-Time Status

**What it shows:**
- Current status: UP or DOWN
- Pulsing indicator (green = running, red = failed)
- Last check timestamp
- Response time in milliseconds

**Example:**
```
Status: UP ⦿ (pulsing green)
Last Check: 2025-12-25T10:30:00
Response Time: 145ms
```

### 2. 24-Hour Statistics

**Cards displayed:**
- **Uptime Percentage**: 99.95% (time UP / total time)
- **Total Checks**: 2,880 (one per 30 seconds × 24 hours)
- **Successful**: 2,879 checks (green badge)
- **Failed**: 1 check (red badge)
- **Avg Response Time**: 142.5ms

### 3. 7-Day Statistics

- Same metrics as 24-hour
- Shows trends over a week
- Useful for capacity planning

### 4. Check History Table

**Displays last 50 checks:**
```
Timestamp            Status  Response Time  HTTP Code  Details
2025-12-25T10:30:00  UP ✓    145ms         200        OK
2025-12-25T10:00:00  UP ✓    156ms         200        OK
2025-12-25T09:30:00  DOWN ✗  NULL          NULL       Connection timeout
2025-12-25T09:00:00  UP ✓    142ms         200        OK
```

### 5. SSL Certificate Monitoring

- Displays days until certificate expires
- Warns in advance of expiration
- Example: "Cert expires in 365 days"

### 6. REST APIs

- Machine-readable endpoints
- JSON responses
- Perfect for:
  - External dashboards
  - Automation scripts
  - Alert systems
  - Mobile apps

---

## REST API

### Endpoint: GET /api/status

**Returns current status only**

```bash
curl https://mel-bouh.42.fr/uptime/api/status | jq
```

**Response:**
```json
{
  "status": "UP",
  "timestamp": "2025-12-25T10:30:00.123456",
  "response_time_ms": 145,
  "uptime_24h_percent": 99.95,
  "total_checks_24h": 2880,
  "last_error": null,
  "cert_days_remaining": 365
}
```

**Use cases:**
- Simple up/down checks
- Integration with monitoring tools
- Discord/Slack webhook triggers

---

### Endpoint: GET /api/stats

**Returns calculated statistics**

```bash
# Last 24 hours (default)
curl https://mel-bouh.42.fr/uptime/api/stats

# Last 7 days
curl https://mel-bouh.42.fr/uptime/api/stats?hours=168

# Last 30 days (720 hours)
curl https://mel-bouh.42.fr/uptime/api/stats?hours=720
```

**Response:**
```json
{
  "uptime_percentage": 99.95,
  "total_checks": 2880,
  "up_count": 2879,
  "down_count": 1,
  "avg_response_time": 142.5,
  "last_check": "2025-12-25T10:30:00.123456",
  "last_status": "UP"
}
```

**Use cases:**
- SLA reporting
- Performance analysis
- Trend visualization
- Capacity planning

---

### Endpoint: GET /api/history

**Returns full check history**

```bash
# Last 24 hours (default)
curl https://mel-bouh.42.fr/uptime/api/history

# Last 7 days
curl https://mel-bouh.42.fr/uptime/api/history?hours=168
```

**Response:**
```json
[
  {
    "id": 2880,
    "timestamp": "2025-12-25T10:30:00.123456",
    "status": "UP",
    "response_time": 145,
    "status_code": 200,
    "error": null,
    "cert_expiry": 365
  },
  {
    "id": 2879,
    "timestamp": "2025-12-25T10:00:00.987654",
    "status": "UP",
    "response_time": 156,
    "status_code": 200,
    "error": null,
    "cert_expiry": 365
  },
  ...
]
```

**Use cases:**
- Creating custom graphs
- Data analysis
- Integration with third-party tools
- Exporting to CSV/JSON

---

## Technical Details

### Database Schema

```sql
CREATE TABLE health_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL,
    response_time INTEGER,
    status_code INTEGER,
    error TEXT,
    cert_expiry INTEGER
);
```

**Column Explanations:**

| Column | Type | Meaning |
|--------|------|---------|
| id | INTEGER | Auto-incrementing ID |
| timestamp | TEXT | ISO 8601 format, unique per check |
| status | TEXT | "UP" or "DOWN" |
| response_time | INTEGER | Milliseconds (145, 200, null) |
| status_code | INTEGER | HTTP code (200, 502, null if DOWN) |
| error | TEXT | Error message if failed |
| cert_expiry | INTEGER | Days until SSL cert expires |

### Logging

**Log file location:**
```bash
/data/monitor.log
```

**Log format:**
```
2025-12-25 10:30:00 - ✓ Website is UP - Status 200 - Response time: 145ms
2025-12-25 10:30:00 -   SSL Certificate expires in 365 days
2025-12-25 10:00:00 - ✓ Website is UP - Status 200 - Response time: 156ms
2025-12-25 09:30:00 - ✗ Website is DOWN - Connection timeout
```

**View logs:**
```bash
# Live logs
docker compose logs -f uptime-monitor

# Log file
docker exec uptime-monitor cat /data/monitor.log
```

### Configuration

**Key constants in monitor.py:**

```python
TARGET_URL = "https://mel-bouh.42.fr"  # Website to monitor
CHECK_INTERVAL = 30                    # Seconds between checks
DB_PATH = "/data/uptime.db"           # Database location
LOG_PATH = "/data/monitor.log"        # Log file location
```

**To modify, edit:**
```bash
/home/mel-bouh/Inception/srcs/requirements/bonus/uptime-monitor/app/monitor.py
```

Then rebuild:
```bash
docker compose build uptime-monitor
docker compose up -d uptime-monitor
```

### Performance Specifications

**Memory Usage:**
- Flask server: ~50MB
- Python runtime: ~30MB
- SQLite database: ~5-10MB (for ~60 days of data)
- **Total: ~100MB**

**CPU Usage:**
- Monitoring thread: <1% (mostly sleeping)
- Flask server: <1% (idle between requests)
- **Total: <2% CPU**

**Network Usage:**
- 1 check per 30 seconds
- ~5KB per check
- **Total: ~14.4MB per day**

**Database Size:**
- ~500 bytes per check
- 2,880 checks per day
- ~1.4MB per day
- ~43MB per month
- **Storage grows linearly**

### Threading Model

**Main Thread (Flask):**
```
├─ Listens for HTTP requests
├─ Renders dashboards
├─ Serves API responses
├─ Non-blocking (async handling)
└─ Stays alive as long as Flask runs
```

**Monitor Thread (Daemon):**
```
├─ Runs in background
├─ Doesn't block main thread
├─ Wakes every 30 seconds
├─ Performs health check
├─ Inserts result
├─ Goes back to sleep
└─ Auto-stops when container stops
```

**SQLite (Thread-safe):**
```
├─ Both threads access same database
├─ SQLite handles locking automatically
├─ Main thread: Read (queries for dashboard)
├─ Monitor thread: Write (inserts new checks)
└─ No race conditions
```

---

## Troubleshooting

### Issue: Dashboard shows "No data yet"

**Cause:** Container is new, hasn't completed first check yet

**Solution:**
```bash
# Wait 60 seconds for first few checks
docker compose logs uptime-monitor | tail -20
```

### Issue: Shows DOWN but website is UP

**Cause:** Could be several things:

```bash
# Check container logs
docker compose logs uptime-monitor

# Test URL directly
curl -k https://mel-bouh.42.fr

# Test from container
docker exec uptime-monitor curl -k https://mel-bouh.42.fr
```

**Common reasons:**
- Website is down (legitimate)
- Self-signed cert issues (should work with verify=False)
- Network connectivity problem
- DNS resolution failure

### Issue: Certificate expiry shows NULL

**Cause:** Certificate checking failed (not critical)

**Solution:**
```bash
# Check logs for SSL errors
docker compose logs uptime-monitor | grep -i ssl

# Verify cert manually
openssl s_client -connect mel-bouh.42.fr:443 -dates
```

### Issue: Dashboard is slow/laggy

**Cause:** Probably have months of history (large database)

**Solution:**
```bash
# Clean old data (optional - this deletes history older than 30 days)
docker exec uptime-monitor python3 -c "
import sqlite3
from datetime import datetime, timedelta
db = sqlite3.connect('/data/uptime.db')
cutoff = (datetime.now() - timedelta(days=30)).isoformat()
db.execute('DELETE FROM health_checks WHERE timestamp < ?', (cutoff,))
db.commit()
print('Cleaned old data')
"

# Or rebuild database
docker exec uptime-monitor rm /data/uptime.db
docker compose restart uptime-monitor
```

### Issue: NGINX returns 502 Bad Gateway

**Cause:** Uptime monitor container is down

**Solution:**
```bash
# Check if container is running
docker compose ps | grep uptime-monitor

# Restart it
docker compose up -d uptime-monitor

# Check logs for errors
docker compose logs uptime-monitor
```

### Issue: Can't access at /uptime path

**Cause:** NGINX config not updated

**Solution:**
```bash
# Verify NGINX config
cat /home/mel-bouh/Inception/srcs/requirements/nginx/conf/default.conf | grep -A 10 "BONUS: Uptime"

# If missing, check git status
git status

# If not staged, rebuild NGINX
docker compose build nginx
docker compose up -d nginx
```

---

## Advanced Usage

### Integrate with Discord Webhook

Create a script to send alerts:

```python
import requests
import json

def send_discord_alert(status, response_time):
    webhook_url = "https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"
    
    if status == "DOWN":
        message = {
            "content": f"🚨 Website is DOWN!",
            "embeds": [{
                "color": 16711680,  # Red
                "title": "Uptime Monitor Alert",
                "description": f"mel-bouh.42.fr is currently unavailable"
            }]
        }
    else:
        message = {
            "content": f"✅ Website is UP ({response_time}ms)",
            "embeds": [{
                "color": 65280,  # Green
                "title": "Uptime Monitor Status",
                "description": f"Response time: {response_time}ms"
            }]
        }
    
    requests.post(webhook_url, json=message)
```

### Export Data to CSV

```bash
docker exec uptime-monitor python3 -c "
import sqlite3
import csv

db = sqlite3.connect('/data/uptime.db')
cursor = db.execute('SELECT * FROM health_checks')

with open('/data/export.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['ID', 'Timestamp', 'Status', 'Response Time', 'HTTP Code', 'Error', 'Cert Expiry'])
    writer.writerows(cursor)

print('Exported to /data/export.csv')
"
```

### Monitor Multiple URLs

To monitor additional services (Redis, Adminer, etc.), you would extend `monitor.py`:

```python
TARGETS = {
    'wordpress': 'https://mel-bouh.42.fr',
    'adminer': 'https://mel-bouh.42.fr/adminer',
    'portfolio': 'https://mel-bouh.42.fr/portfolio',
}

# Check each target and store with name
for name, url in TARGETS.items():
    # Run health check
    # Insert with target_name column
```

---

## Summary

**Uptime Monitor is:**
- ✅ Automated 24/7 monitoring
- ✅ Historical data storage
- ✅ Beautiful web dashboard
- ✅ REST APIs for integration
- ✅ SSL certificate tracking
- ✅ Production-ready

**Accessible at:**
```
https://mel-bouh.42.fr/uptime
```

**Logs available in:**
```
/data/monitor.log (in container)
/home/mel-bouh/data/uptime-monitor/monitor.log (on host)
```

**API Endpoints:**
```
/api/status   - Current status (JSON)
/api/stats    - Statistics (JSON)
/api/history  - Full history (JSON)
```

---

**Your Inception project now has complete infrastructure monitoring!**
