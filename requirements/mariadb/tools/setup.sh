#!/bin/bash
set -e

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

if [ -z "$(ls -A /var/lib/mysql)" ]; then
    echo "First run -- initializing MariaDB data directory"

    mysql_install_db --user=mysql --datadir=/var/lib/mysql

    mysqld_safe --user=mysql --datadir=/var/lib/mysql &
    pid="$!"

    until mysqladmin ping --silent; do
        sleep 1
    done

    echo "Setting root password"
    mysql -uroot -e "
        ALTER USER 'root'@'localhost'
        IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
    "

    echo "Creating WordPress database and user"
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    echo "Stopping temporary MariaDB"
    mysqladmin -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown

    wait "$pid"
fi

echo "Starting MariaDB normally"
exec "$@"