# FTP Server - vsftpd (Very Secure FTP Daemon)
# Allows file upload/download to WordPress files

FROM debian:bookworm

# Install vsftpd - a secure, fast FTP server
RUN apt-get update && apt-get install -y --no-install-recommends \
    vsftpd \
    && rm -rf /var/lib/apt/lists/*

# Copy our setup script and config
COPY tools/setup.sh /usr/local/bin/setup.sh
COPY tools/vsftpd.conf /etc/vsftpd.conf

RUN chmod +x /usr/local/bin/setup.sh

# Create directory for vsftpd
RUN mkdir -p /var/run/vsftpd/empty

# FTP ports:
# 21: Control connection (commands)
# 21100-21110: Passive mode data ports
EXPOSE 21 21100-21110

ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["vsftpd", "/etc/vsftpd.conf"]
