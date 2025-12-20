FROM debian:bookworm

RUN apt-get update \
 && apt-get install -y mariadb-server \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/mysqld /var/lib/mysql /var/log/mysql \
 && chown -R mysql:mysql /run/mysqld /var/lib/mysql /var/log/mysql

COPY /conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["mariadbd", "--user=mysql", "--bind-address=0.0.0.0", "--console"]