# Adminer - Lightweight Database Management Tool
# Base: Debian Bookworm (penultimate stable as required by subject)

FROM debian:bookworm

# Update and install required packages:
# - php: The PHP interpreter (Adminer is a PHP application)
# - php-mysqli: PHP extension for MySQL/MariaDB connections
# - wget: To download Adminer
# - ca-certificates: For HTTPS downloads
RUN apt-get update && apt-get install -y --no-install-recommends \
    php \
    php-mysqli \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create directory for Adminer
# /var/www/html is the standard web root
WORKDIR /var/www/html

# Download Adminer (single PHP file)
# We use a specific version for reproducibility (not 'latest' as forbidden by subject)
RUN wget -q https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php \
    -O adminer.php

# Expose port 8080 (PHP built-in server will listen here)
EXPOSE 8080

# Start PHP's built-in web server
# -S 0.0.0.0:8080 = Listen on all interfaces, port 8080
# This is a simple server suitable for Adminer (not for production apps)
CMD ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]
