# Uptime Monitor - Website Health Monitoring Service
# Base: Debian Bookworm (as required by subject)

FROM debian:bookworm

# Install Python and required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements file
COPY app/requirements.txt .

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application files
COPY app/ .

# Create data directory for SQLite database and logs
RUN mkdir -p /data

# Expose port 5000 for Flask web interface
EXPOSE 5000

# Run the uptime monitor
CMD ["python3", "monitor.py"]
