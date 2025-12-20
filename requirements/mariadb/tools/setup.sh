#!/bin/bash
set -e

# Unset MYSQL_HOST to prevent connection issues within the container
# The mysql client reads this env var and tries to connect to the named host
# For initialization, we use socket-based connections instead
unset MYSQL_HOST

mkdir -p /run/mysqld /var/log/mysql
chown -R mysql:mysql /run/mysqld /var/log/mysql

is_first_run=0

mysqld_safe --user=mysql --datadir=/var/lib/mysql --log-error=/var/log/mysql/error.log &
temp_pid="$!"

until mysqladmin --socket=/var/run/mysqld/mysqld.sock ping --silent 2>/dev/null; do
    sleep 1
done

if ! mysql --socket=/var/run/mysqld/mysqld.sock -h localhost -e "SELECT 1 FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${WP_DB_DATABASE}'" 2>/dev/null | grep -q 1; then
    is_first_run=1
fi

if [ "$is_first_run" -eq 1 ]; then
    mysqladmin --socket=/var/run/mysqld/mysqld.sock -h localhost shutdown 2>/dev/null || true
    wait "$temp_pid" 2>/dev/null || true
    sleep 2
    
    echo "First run -- initializing MariaDB with WordPress database"
    
    mysqld_safe --user=mysql --datadir=/var/lib/mysql --log-error=/var/log/mysql/error.log --skip-grant-tables &
    temp_pid="$!"
    
    until mysqladmin --socket=/var/run/mysqld/mysqld.sock ping --silent 2>/dev/null; do
        sleep 1
    done
    
    echo "Setting root password"
    # First flush privileges to load the grant tables
    mysql --socket=/var/run/mysqld/mysqld.sock -h localhost -e "FLUSH PRIVILEGES;"
    # Then set the root password
    mysql --socket=/var/run/mysqld/mysqld.sock -h localhost -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${WP_DB_ROOT_PASSWORD}';"
    
    echo "Creating WordPress database and user"
    mysql --socket=/var/run/mysqld/mysqld.sock -h localhost -uroot -p"${WP_DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${WP_DB_DATABASE};
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${WP_DB_DATABASE}.* TO '${WP_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    
    # Shut down and restart normally
    mysqladmin --socket=/var/run/mysqld/mysqld.sock -h localhost -uroot -p"${WP_DB_ROOT_PASSWORD}" shutdown 2>/dev/null || true
    wait "$temp_pid" 2>/dev/null || true
    sleep 2
fi

echo "Starting MariaDB normally"
exec "$@"