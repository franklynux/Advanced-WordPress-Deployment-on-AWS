#!/bin/bash

# Update the package list to ensure we have the latest information about available packages
sudo apt-get update -y

# Install required packages:
# mysql-client: for connecting to the MySQL database
# apache2: the web server to host WordPress
# php: the programming language WordPress is written in
# libapache2-mod-php: allows Apache to handle PHP files
# Various PHP extensions required for WordPress functionality
sudo apt install mysql-client apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y

# Set environment variables for MySQL connection
# These will be used to connect to the RDS instance and for WordPress configuration
export MYSQL_HOST="your-RDS-enpoint-URL"
export MYSQL_USER="admin"
export MYSQL_PASSWORD="admin123"
export MYSQL_DATABASE="WordPressDB"

# Connect to MySQL and run a series of commands:
# 1. Create the WordPress database if it doesn't exist
# 2. Create the MySQL user if it doesn't exist
# 3. Grant all privileges on the WordPress database to the user
# 4. Flush privileges to ensure the changes take effect immediately
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EXIT;
MYSQL_SCRIPT

# Start the Apache web server and enable it to start automatically on system boot
sudo systemctl start apache2
sudo systemctl enable apache2

# Change to the /tmp directory where we'll download and extract WordPress
cd /tmp

# Download the latest version of WordPress
sudo wget https://wordpress.org/latest.tar.gz

# Extract the WordPress archive
sudo tar xzf latest.tar.gz

# Copy WordPress files to Apache's web root directory
# The -a option preserves file attributes, -v provides verbose output, and -P shows progress
sudo rsync -avP /tmp/wordpress/ /var/www/html/

# Remove the default Apache index.html to prevent it from taking precedence over WordPress
sudo rm /var/www/html/index.html

# Change to Apache's web root directory where WordPress is now located
cd /var/www/html/

# Create WordPress configuration file from the provided sample
sudo cp wp-config-sample.php wp-config.php

# Update the WordPress configuration file with our database details
# sed is used to find and replace the placeholder values in the config file
sudo sed -i "s/database_name_here/${MYSQL_DATABASE}/" wp-config.php
sudo sed -i "s/username_here/${MYSQL_USER}/" wp-config.php
sudo sed -i "s/password_here/${MYSQL_PASSWORD}/" wp-config.php
sudo sed -i "s/localhost/${MYSQL_HOST}/" wp-config.php

# Fetch unique salt values from the WordPress API and append them to the config file
# These salts are used to secure cookies and passwords in WordPress
sudo curl -s https://api.wordpress.org/secret-key/1.1/salt/ | sudo tee -a wp-config.php

# Set correct ownership and permissions for WordPress files
# www-data is the user Apache runs as
sudo chown -R www-data:www-data /var/www/html/
# Set directory permissions to 755 (rwxr-xr-x)
sudo find /var/www/html -type d -exec chmod 755 {} \;
# Set file permissions to 644 (rw-r--r--)
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Enable .htaccess overrides in Apache config
# This allows WordPress to manage its own rewrite rules for pretty permalinks
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Enable Apache rewrite module, which is required for WordPress permalinks
sudo a2enmod rewrite

# Restart Apache to apply all the changes we've made
sudo systemctl restart apache2

# Verify database connection and show tables (if any)
# This helps confirm that the WordPress database is accessible
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -e "USE $MYSQL_DATABASE; SHOW TABLES;"

# Display PHP version to ensure it's correctly installed
php -v

# Print completion messages and instructions for the user
echo "WordPress installation is complete. Visit your server's public IP to complete the installation."
echo "If you see the Apache2 default page, try accessing http://your-server-ip/wp-admin/install.php"
echo "Check Apache2 error logs with: sudo tail -f /var/log/apache2/error.log"