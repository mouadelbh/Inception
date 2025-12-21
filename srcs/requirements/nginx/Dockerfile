FROM debian:bookworm

RUN apt-get update && apt-get install nginx openssl -y \
    && rm -rf /var/lib/apt/lists/*

RUN openssl req -newkey rsa:2048 -nodes \
    -keyout /etc/ssl/private/nginx.key -x509 \
    -days 365 -out /etc/ssl/certs/nginx.crt \
    -subj "/C=MA/ST=BE/O=1337/CN=mel-bouh.42.fr"

COPY conf/default.conf /etc/nginx/sites-available/default
COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["nginx", "-g", "daemon off;"]
