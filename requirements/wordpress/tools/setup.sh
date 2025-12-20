#!/bin/bash
set -e

until mysql -h ${WP_DB_HOST} -u ${WP_DB_USER} -p${WP_DB_PASSWORD} -e "SELECT 1"; do
  echo "Waiting for MariaDB..."
  sleep 5
done

if [ ! -f "/var/www/html/wp-config-sample.php" ]; then
    echo "WordPress not found in volume, downloading..."
    curl -O https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz -C /var/www/html --strip-components=1
    rm latest.tar.gz
    chown -R www-data:www-data /var/www/html
fi

if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "Configuring WordPress..."
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sed -i "s/database_name_here/${WP_DB_DATABASE}/g" /var/www/html/wp-config.php
    sed -i "s/username_here/${WP_DB_USER}/g" /var/www/html/wp-config.php
    sed -i "s/password_here/${WP_DB_PASSWORD}/g" /var/www/html/wp-config.php
    sed -i "s/localhost/${WP_DB_HOST}/g" /var/www/html/wp-config.php
fi

if ! wp core is-installed --path=/var/www/html --allow-root; then
    echo "Installing WordPress automatically..."

    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --path=/var/www/html \
        --allow-root

    wp user create mouad mouad@mail.com \
        --role=editor \
        --user_pass=mouad123 \
        --path=/var/www/html \
        --allow-root

    wp theme install blocksy --activate \
        --path=/var/www/html \
        --allow-root

    echo "WordPress installed automatically!"
else
    echo "WordPress already installed."
fi

echo "Starting PHP-FPM..."

sed -i 's|^listen = .*|listen = 9000|' /etc/php/8.2/fpm/pool.d/www.conf

exec "$@"