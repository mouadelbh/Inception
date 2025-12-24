# Static Website - Simple NGINX serving HTML/CSS
# This is for the Inception bonus: static site without PHP

FROM debian:bookworm

# Install NGINX only - no PHP needed for static content!
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# Copy our static files (HTML, CSS, JS, images)
COPY html/ /var/www/static/

# Create a simple NGINX config for static files
RUN echo 'server { \n\
    listen 8080; \n\
    server_name localhost; \n\
    root /var/www/static; \n\
    index index.html; \n\
    \n\
    location / { \n\
        try_files $uri $uri/ =404; \n\
    } \n\
}' > /etc/nginx/sites-available/default

# Expose port 8080
EXPOSE 8080

# Run NGINX in foreground (required for Docker - no daemon mode)
# -g 'daemon off;' keeps NGINX in foreground so container doesn't exit
CMD ["nginx", "-g", "daemon off;"]
