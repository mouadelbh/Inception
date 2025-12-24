#!/bin/bash
set -e

# Create FTP user if it doesn't exist
# Uses environment variables FTP_USER and FTP_PASSWORD
if ! id "$FTP_USER" &>/dev/null; then
    echo "Creating FTP user: $FTP_USER"
    
    # Create user with home directory pointing to WordPress files
    useradd -m -d /var/www/html -s /bin/bash "$FTP_USER"
    
    # Set password
    echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
    
    # Make sure the user owns the WordPress directory
    chown -R "$FTP_USER:$FTP_USER" /var/www/html
    
    echo "FTP user created successfully"
else
    echo "FTP user $FTP_USER already exists"
fi

# Set passive mode address (your server's IP)
# In a VM, this should be the VM's IP
if [ -n "$FTP_PASV_ADDRESS" ]; then
    echo "pasv_address=$FTP_PASV_ADDRESS" >> /etc/vsftpd.conf
else
    # Default to localhost for local testing
    echo "pasv_address=127.0.0.1" >> /etc/vsftpd.conf
fi

echo "Starting vsftpd FTP server..."
exec "$@"
