# Uptime Monitor - Quick Setup

Your custom bonus service is now installed! Here's how to get it running:

## Installation

The uptime monitor is already integrated. Just ensure you create the data directory:

```bash
mkdir -p /home/mel-bouh/data/uptime-monitor
```

## Build and Run

```bash
# Full rebuild with all services
cd /home/mel-bouh/Inception
make re

# Or start with docker-compose
docker compose up -d uptime-monitor
```

## Access

```
Dashboard:  https://mel-bouh.42.fr/uptime
API Status: https://mel-bouh.42.fr/uptime/api/status
API Stats:  https://mel-bouh.42.fr/uptime/api/stats
API History: https://mel-bouh.42.fr/uptime/api/history
```

## What It Does

- Checks your website every 30 seconds
- Shows uptime percentage and response times
- Displays 24-hour and 7-day statistics
- Tracks SSL certificate expiration
- Stores 30+ days of history in SQLite database
- Provides REST APIs for automation

## View Logs

```bash
docker compose logs -f uptime-monitor
```

## Documentation

For complete documentation, see:
- `UPTIME_MONITOR_GUIDE.md` - Detailed technical guide
- `BONUS_EXPLAINED.md` - Overview of all bonus services

## Files Structure

```
srcs/requirements/bonus/uptime-monitor/
├── Dockerfile                 # Container definition
└── app/
    ├── monitor.py            # Main application (900+ lines)
    ├── requirements.txt      # Python dependencies
    └── templates/
        └── dashboard.html    # Web UI
```

## No Additional Configuration Needed

Everything is pre-configured to:
- Monitor `https://mel-bouh.42.fr`
- Run health checks every 30 seconds
- Store data in `/data/uptime.db`
- Serve dashboard on port 5000 (proxied via NGINX)

Just run it!

---

**Questions?** Check `UPTIME_MONITOR_GUIDE.md` for comprehensive documentation.
