#!/bin/bash

# WordPress Installation Script for Amazon Linux 2 AMI
# This script automates the process of setting up a WordPress site on an EC2 instance
# running Amazon Linux 2, using an external RDS MySQL database.

# Update the system
# This ensures we have the latest security updates and package information
sudo yum update -y

# Install necessary packages
# amazon-linux-extras provides access to the LAMP stack components
# We're installing Apache, MariaDB (MySQL), and PHP 7.2
sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
sudo yum install -y httpd mariadb-server

# Set environment variables for database connection
# IMPORTANT: Replace these values with your actual RDS instance details
export MYSQL_HOST="database-1.cpcgwweaw5ve.us-east-1.rds.amazonaws.com"
export MYSQL_USER="admin"
export MYSQL_PASSWORD="admin123"
export MYSQL_DATABASE="wordpressDB"

# Create database and user in the RDS instance
# This script creates the WordPress database and grants necessary permissions
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EXIT;
MYSQL_SCRIPT

# Start and enable Apache web server
# This ensures Apache starts now and also after system reboots
sudo systemctl start httpd
sudo systemctl enable httpd

# Download and install WordPress
# We're downloading the latest WordPress version and extracting it to the web root
cd /tmp
sudo wget https://wordpress.org/latest.tar.gz
sudo tar xzf latest.tar.gz
sudo rsync -avP /tmp/wordpress/ /var/www/html/
sudo rm /var/www/html/index.html  # Remove default Apache index page

# Configure WordPress
# Here we're setting up the wp-config.php file with our database details
cd /var/www/html/
sudo cp wp-config-sample.php wp-config.php
sudo sed -i "s/database_name_here/${MYSQL_DATABASE}/" wp-config.php
sudo sed -i "s/username_here/${MYSQL_USER}/" wp-config.php
sudo sed -i "s/password_here/${MYSQL_PASSWORD}/" wp-config.php
sudo sed -i "s/localhost/${MYSQL_HOST}/" wp-config.php

# Add secret keys to wp-config.php
# These keys are used by WordPress for security features
sudo curl -s https://api.wordpress.org/secret-key/1.1/salt/ | sudo tee -a wp-config.php

# Set correct ownership and permissions
# This ensures Apache can read and write to the WordPress files as needed
sudo chown -R apache:apache /var/www/html/
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Configure Apache to allow .htaccess overrides
# This is necessary for WordPress permalinks to work correctly
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
sudo systemctl restart httpd

# Verify database connection
# This command will list all tables in the WordPress database if the connection is successful
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -e "USE $MYSQL_DATABASE; SHOW TABLES;"

# Check PHP version
# This is useful for verification and troubleshooting
php -v

# Installation complete
echo "WordPress installation is complete. Visit your server's public IP to complete the installation."
echo "If you see the Apache default page, try accessing http://your-server-ip/wp-admin/install.php"
echo "Check Apache error logs with: sudo tail -f /var/log/httpd/error_log"
