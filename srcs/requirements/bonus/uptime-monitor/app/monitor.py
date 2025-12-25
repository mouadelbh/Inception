#!/usr/bin/env python3
"""
Uptime Monitor - Website Health Monitoring Service

This service:
1. Continuously checks if the WordPress site is running and healthy
2. Monitors HTTPS connectivity and certificate validity
3. Measures response times for performance tracking
4. Stores historical data in SQLite database
5. Provides a web dashboard showing uptime statistics
6. Logs all checks with timestamps and status codes

Architecture:
- Main thread: Runs Flask web server (port 5000)
- Background thread: Performs health checks every 30 seconds
- SQLite database: Stores all check results persistently
"""

import sqlite3
import threading
import time
import json
import os
import ssl
from datetime import datetime, timedelta
from requests.adapters import HTTPAdapter
from urllib3.util.ssl_ import create_urllib3_context
import requests
from flask import Flask, render_template, jsonify

# Configuration
TARGET_URL = "https://mel-bouh.42.fr"
CHECK_INTERVAL = 30  # Seconds between health checks
DB_PATH = "/data/uptime.db"
LOG_PATH = "/data/monitor.log"

# Flask app initialization
app = Flask(__name__)

# ============================================================================
# DATABASE SETUP AND OPERATIONS
# ============================================================================

def init_database():
    """
    Initialize SQLite database for storing health check results.
    
    Database schema explanation:
    - id: Auto-incrementing primary key
    - timestamp: When the check was performed (ISO format)
    - status: "UP" or "DOWN"
    - response_time: Time taken to connect in milliseconds
    - status_code: HTTP status code (200, 502, etc.) or None if unreachable
    - error: Error message if check failed (connection error, timeout, etc.)
    - cert_expiry: Days until SSL certificate expires
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS health_checks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                status TEXT NOT NULL,
                response_time INTEGER,
                status_code INTEGER,
                error TEXT,
                cert_expiry INTEGER,
                UNIQUE(timestamp)
            )
        ''')
        
        conn.commit()
        conn.close()
        
        log("Database initialized successfully")
    except Exception as e:
        log(f"ERROR: Database initialization failed: {str(e)}")

def log(message):
    """
    Log messages with timestamps to both file and console.
    
    Format: YYYY-MM-DD HH:MM:SS - Message
    File: /data/monitor.log (persistent across container restarts)
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_message = f"{timestamp} - {message}"
    print(log_message)
    
    try:
        with open(LOG_PATH, "a") as f:
            f.write(log_message + "\n")
    except Exception as e:
        print(f"ERROR: Could not write to log file: {str(e)}")

def insert_health_check(status, response_time, status_code, error, cert_expiry):
    """
    Insert a health check result into the database.
    
    Args:
        status: "UP" or "DOWN"
        response_time: Time in milliseconds
        status_code: HTTP response code
        error: Error message or None
        cert_expiry: Days until cert expires or None
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        timestamp = datetime.now().isoformat()
        
        cursor.execute('''
            INSERT INTO health_checks 
            (timestamp, status, response_time, status_code, error, cert_expiry)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (timestamp, status, response_time, status_code, error, cert_expiry))
        
        conn.commit()
        conn.close()
    except Exception as e:
        log(f"ERROR: Could not insert health check: {str(e)}")

def get_health_checks(hours=24):
    """
    Retrieve health check history from the database.
    
    Args:
        hours: How many hours back to retrieve (default: 24 hours)
    
    Returns:
        List of dictionaries with check results
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        since = (datetime.now() - timedelta(hours=hours)).isoformat()
        
        cursor.execute('''
            SELECT * FROM health_checks 
            WHERE timestamp > ? 
            ORDER BY timestamp DESC
        ''', (since,))
        
        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        
        return results
    except Exception as e:
        log(f"ERROR: Could not retrieve health checks: {str(e)}")
        return []

def get_statistics(hours=24):
    """
    Calculate uptime statistics from health check history.
    
    Returns:
        Dictionary with:
        - uptime_percentage: % of time service was UP
        - total_checks: Number of checks performed
        - up_count: Number of successful checks
        - down_count: Number of failed checks
        - avg_response_time: Average response time in ms
        - last_check: Timestamp of most recent check
        - last_status: UP or DOWN
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        since = (datetime.now() - timedelta(hours=hours)).isoformat()
        
        # Total checks
        cursor.execute('SELECT COUNT(*) FROM health_checks WHERE timestamp > ?', (since,))
        total_checks = cursor.fetchone()[0]
        
        # Up checks
        cursor.execute('SELECT COUNT(*) FROM health_checks WHERE timestamp > ? AND status = "UP"', (since,))
        up_count = cursor.fetchone()[0]
        
        # Average response time
        cursor.execute('SELECT AVG(response_time) FROM health_checks WHERE timestamp > ? AND status = "UP"', (since,))
        avg_response = cursor.fetchone()[0] or 0
        
        # Last check
        cursor.execute('SELECT status, timestamp FROM health_checks ORDER BY timestamp DESC LIMIT 1')
        last_check = cursor.fetchone()
        
        conn.close()
        
        uptime_percentage = (up_count / total_checks * 100) if total_checks > 0 else 0
        
        return {
            "uptime_percentage": round(uptime_percentage, 2),
            "total_checks": total_checks,
            "up_count": up_count,
            "down_count": total_checks - up_count,
            "avg_response_time": round(avg_response, 2),
            "last_check": last_check[1] if last_check else None,
            "last_status": last_check[0] if last_check else "UNKNOWN"
        }
    except Exception as e:
        log(f"ERROR: Could not calculate statistics: {str(e)}")
        return {}

# ============================================================================
# HEALTH CHECK LOGIC
# ============================================================================

def check_certificate_validity(url):
    """
    Check SSL certificate validity and expiration date.
    
    How it works:
    1. Extract hostname from URL (mel-bouh.42.fr)
    2. Create SSL context (allows self-signed for testing)
    3. Get certificate from the server
    4. Extract expiration date
    5. Calculate days until expiry
    
    Returns:
        Days until certificate expires, or None if failed
    """
    try:
        # Extract hostname from URL
        hostname = url.replace("https://", "").replace("http://", "").split("/")[0]
        
        # Create SSL context that accepts self-signed certificates
        context = create_urllib3_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        # Get certificate
        import socket
        sock = socket.create_connection((hostname, 443), timeout=5)
        ssock = context.wrap_socket(sock, server_hostname=hostname)
        cert = ssock.getpeercert()
        ssock.close()
        
        # Parse expiration date
        if 'notAfter' in cert:
            cert_expiry_str = cert['notAfter']
            # Format: 'Dec 25 10:30:00 2025 GMT'
            cert_expiry = datetime.strptime(cert_expiry_str, '%b %d %H:%M:%S %Y %Z')
            days_until_expiry = (cert_expiry - datetime.now()).days
            return max(0, days_until_expiry)
    except Exception as e:
        log(f"WARNING: Could not check certificate: {str(e)}")
    
    return None

def perform_health_check():
    """
    Perform a single health check on the target website.
    
    Process:
    1. Send HTTPS GET request to target URL
    2. Measure response time
    3. Check HTTP status code (200 = healthy)
    4. Verify SSL certificate
    5. Store result in database
    6. Log the outcome
    
    Status determination:
    - UP: Status code 200-299 (success) and responds within 30 seconds
    - DOWN: Non-2xx status code, timeout, or connection refused
    - DOWN: Any exception (DNS failure, SSL error, etc.)
    
    Returns: None (stores result in database)
    """
    start_time = time.time()
    response_time = None
    status = "DOWN"
    status_code = None
    error = None
    cert_expiry = None
    
    try:
        # Create session with timeout
        session = requests.Session()
        
        # Verify SSL but handle self-signed certs
        response = session.get(
            TARGET_URL,
            timeout=10,  # 10 second timeout
            verify=False  # Allow self-signed certificates
        )
        
        response_time = int((time.time() - start_time) * 1000)  # Convert to milliseconds
        status_code = response.status_code
        
        # Determine status based on HTTP response code
        if 200 <= status_code < 300:
            status = "UP"
            log(f"✓ Website is UP - Status {status_code} - Response time: {response_time}ms")
        else:
            status = "DOWN"
            error = f"HTTP {status_code}"
            log(f"✗ Website is DOWN - Status {status_code}")
        
        # Check certificate validity
        cert_expiry = check_certificate_validity(TARGET_URL)
        if cert_expiry is not None:
            log(f"  SSL Certificate expires in {cert_expiry} days")
    
    except requests.exceptions.Timeout:
        response_time = int((time.time() - start_time) * 1000)
        error = "Request timeout (>10s)"
        status = "DOWN"
        log(f"✗ Website is DOWN - Connection timeout")
    
    except requests.exceptions.ConnectionError as e:
        response_time = int((time.time() - start_time) * 1000)
        error = "Connection refused"
        status = "DOWN"
        log(f"✗ Website is DOWN - Connection error: {str(e)}")
    
    except Exception as e:
        response_time = int((time.time() - start_time) * 1000)
        error = str(e)
        status = "DOWN"
        log(f"✗ Website is DOWN - Exception: {str(e)}")
    
    # Store the result in database
    insert_health_check(status, response_time, status_code, error, cert_expiry)

# ============================================================================
# BACKGROUND MONITORING THREAD
# ============================================================================

def monitor_thread():
    """
    Continuous monitoring thread that runs in the background.
    
    Process:
    1. Runs indefinitely (until container stops)
    2. Every 30 seconds: Performs health check
    3. Stores result in database
    4. Logs outcome
    5. Never blocks Flask web server
    
    Thread properties:
    - Daemon thread: Stops when main thread stops
    - Non-blocking: Doesn't interfere with Flask
    - Error handling: Logs exceptions, continues running
    """
    log("Starting background monitoring thread...")
    
    while True:
        try:
            perform_health_check()
            time.sleep(CHECK_INTERVAL)
        except Exception as e:
            log(f"ERROR: Monitoring thread exception: {str(e)}")
            time.sleep(CHECK_INTERVAL)

# ============================================================================
# FLASK WEB INTERFACE
# ============================================================================

@app.route('/')
def dashboard():
    """
    Render the main dashboard HTML page.
    
    Returns:
        HTML template with embedded real-time data
    """
    stats_24h = get_statistics(hours=24)
    stats_7d = get_statistics(hours=168)  # 7 days
    last_checks = get_health_checks(hours=24)[:50]  # Last 50 checks
    
    return render_template(
        'dashboard.html',
        stats_24h=stats_24h,
        stats_7d=stats_7d,
        last_checks=last_checks,
        target_url=TARGET_URL,
        check_interval=CHECK_INTERVAL
    )

@app.route('/api/status')
def api_status():
    """
    REST API endpoint returning current status as JSON.
    
    Response format:
    {
        "status": "UP" or "DOWN",
        "timestamp": "2025-12-25T10:30:00.123456",
        "response_time_ms": 145,
        "uptime_24h_percent": 99.5,
        "checks_24h": 2880
    }
    
    Used by:
    - External monitoring systems
    - Third-party dashboards
    - Mobile apps
    - Webhook alerts
    """
    stats = get_statistics(hours=24)
    last_checks = get_health_checks(hours=1)
    
    latest = last_checks[0] if last_checks else None
    
    return jsonify({
        "status": latest['status'] if latest else "UNKNOWN",
        "timestamp": latest['timestamp'] if latest else None,
        "response_time_ms": latest['response_time'] if latest else None,
        "uptime_24h_percent": stats.get('uptime_percentage', 0),
        "total_checks_24h": stats.get('total_checks', 0),
        "last_error": latest['error'] if latest and latest['error'] else None,
        "cert_days_remaining": latest['cert_expiry'] if latest and latest['cert_expiry'] else None
    })

@app.route('/api/history')
def api_history():
    """
    REST API endpoint returning full health check history as JSON.
    
    Response:
        Array of health check objects with timestamps
    
    Used for:
    - Creating custom graphs
    - Data analysis
    - Integration with monitoring platforms
    """
    hours = request.args.get('hours', 24, type=int)
    checks = get_health_checks(hours=hours)
    return jsonify(checks)

@app.route('/api/stats')
def api_stats():
    """
    REST API endpoint returning calculated statistics.
    
    Response:
    {
        "uptime_percentage": 99.95,
        "total_checks": 2880,
        "up_count": 2879,
        "down_count": 1,
        "avg_response_time": 142.5,
        "last_check": "2025-12-25T10:30:00",
        "last_status": "UP"
    }
    """
    hours = request.args.get('hours', 24, type=int)
    stats = get_statistics(hours=hours)
    return jsonify(stats)

@app.route('/health')
def health():
    """
    Health check endpoint for orchestration tools (Docker, Kubernetes).
    
    Returns:
        - Status 200 if Flask is running
        - Used by: docker-compose health checks
    """
    return jsonify({"status": "Flask web server is running"}), 200

# ============================================================================
# APPLICATION STARTUP
# ============================================================================

if __name__ == '__main__':
    log("=" * 60)
    log("UPTIME MONITOR - Starting up")
    log("=" * 60)
    log(f"Target URL: {TARGET_URL}")
    log(f"Check interval: {CHECK_INTERVAL} seconds")
    log(f"Database: {DB_PATH}")
    log(f"Log file: {LOG_PATH}")
    log("=" * 60)
    
    # Initialize database
    init_database()
    
    # Start background monitoring thread
    monitor = threading.Thread(target=monitor_thread, daemon=True)
    monitor.start()
    log("Background monitoring thread started")
    
    # Start Flask web server
    log("Starting Flask web server on port 5000...")
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)
