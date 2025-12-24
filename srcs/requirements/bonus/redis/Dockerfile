# Redis - In-memory data store for WordPress caching
# Base: Debian Bookworm (as required by subject)

FROM debian:bookworm

# Install Redis server
# redis-server: The actual Redis database server
RUN apt-get update && apt-get install -y --no-install-recommends \
    redis-server \
    && rm -rf /var/lib/apt/lists/*

# Configure Redis for Docker:
# 1. bind 0.0.0.0 - Listen on all interfaces (needed for Docker networking)
# 2. protected-mode no - Allow connections from other containers
# 3. maxmemory 256mb - Limit memory usage (adjust based on your needs)
# 4. maxmemory-policy allkeys-lru - When full, remove least recently used keys
RUN sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf && \
    sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf && \
    echo "maxmemory 256mb" >> /etc/redis/redis.conf && \
    echo "maxmemory-policy allkeys-lru" >> /etc/redis/redis.conf

# Redis default port
EXPOSE 6379

# Run Redis server in foreground (not as daemon)
CMD ["redis-server", "--bind", "0.0.0.0", "--protected-mode", "no"]
