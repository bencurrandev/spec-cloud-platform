#!/bin/bash
# =============================================================================
# Patio Application - LAMP Stack Installation Script
# =============================================================================
# Purpose: Install and configure Apache 2.4, PHP 8.1, and dependencies
# Target: Ubuntu 22.04 LTS
# Compliance: ac-001 (security), dp-001 (TLS 1.2+)
# =============================================================================

set -e # Exit on error
set -x # Print commands for debugging

# PARAMETERS
# -----------------------------------------------------------------------------
ENVIRONMENT=${1:-dev} # dev, staging, or prod

echo "====================================================================="
echo "Installing LAMP stack for Patio application - Environment: $ENVIRONMENT"
echo "====================================================================="

# UPDATE SYSTEM
# -----------------------------------------------------------------------------
echo ">>> Updating system packages..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# INSTALL APACHE 2.4
# -----------------------------------------------------------------------------
echo ">>> Installing Apache 2.4..."
sudo apt-get install -y apache2

# Enable required Apache modules
sudo a2enmod rewrite
sudo a2enmod ssl
sudo a2enmod headers
sudo a2enmod proxy
sudo a2enmod proxy_http

# Configure Apache security settings
sudo sed -i 's/ServerTokens OS/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
sudo sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf

# Disable directory listing (security hardening)
sudo sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/' /etc/apache2/apache2.conf

# INSTALL PHP 8.1
# -----------------------------------------------------------------------------
echo ">>> Installing PHP 8.1 and extensions..."
sudo apt-get install -y php8.1 php8.1-fpm php8.1-cli php8.1-common

# Install PHP extensions for Patio application
sudo apt-get install -y \
  php8.1-mysql \
  php8.1-redis \
  php8.1-gd \
  php8.1-curl \
  php8.1-mbstring \
  php8.1-xml \
  php8.1-zip \
  php8.1-intl \
  php8.1-bcmath \
  libapache2-mod-php8.1

# Configure PHP settings for Patio application
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 10M/' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/post_max_size = 8M/post_max_size = 12M/' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;date.timezone =/date.timezone = America\/New_York/' /etc/php/8.1/apache2/php.ini

# Enable opcache for performance
sudo sed -i 's/;opcache.enable=1/opcache.enable=1/' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=128/' /etc/php/8.1/apache2/php.ini

# Security: Disable dangerous PHP functions
sudo sed -i 's/;disable_functions =/disable_functions = exec,passthru,shell_exec,system,proc_open,popen/' /etc/php/8.1/apache2/php.ini

# INSTALL COMPOSER
# -----------------------------------------------------------------------------
echo ">>> Installing Composer..."
cd /tmp
curl -sS https://getcomposer.org/installer -o composer-setup.php
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# INSTALL MYSQL CLIENT
# -----------------------------------------------------------------------------
echo ">>> Installing MySQL client..."
sudo apt-get install -y mysql-client-8.0

# INSTALL REDIS TOOLS
# -----------------------------------------------------------------------------
echo ">>> Installing Redis tools..."
sudo apt-get install -y redis-tools

# INSTALL AZURE CLI (for Key Vault access)
# -----------------------------------------------------------------------------
echo ">>> Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# INSTALL MONITORING AGENT (per obs-001)
# -----------------------------------------------------------------------------
echo ">>> Installing Azure Monitor agent..."
wget https://raw.githubusercontent.com/Microsoft/OMS-Agent-for-Linux/master/installer/scripts/onboard_agent.sh
sudo sh onboard_agent.sh -w <WORKSPACE_ID> -s <WORKSPACE_KEY> -d opinsights.azure.com
rm onboard_agent.sh

# CONFIGURE SSL/TLS (per dp-001 v1.0.0)
# -----------------------------------------------------------------------------
echo ">>> Configuring SSL/TLS 1.2+ minimum..."

# Generate self-signed certificate for development (production will use Let's Encrypt)
if [ "$ENVIRONMENT" == "dev" ]; then
  echo ">>> Generating self-signed SSL certificate for dev..."
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/patio-dev.key \
    -out /etc/ssl/certs/patio-dev.crt \
    -subj "/C=US/ST=State/L=City/O=Patio/CN=patio-dev.local"
fi

# Configure Apache SSL settings (TLS 1.2+ only per dp-001)
sudo cat > /etc/apache2/conf-available/ssl-hardening.conf <<EOF
# SSL/TLS Hardening per dp-001 v1.0.0
SSLProtocol -all +TLSv1.2 +TLSv1.3
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
SSLHonorCipherOrder on
SSLCompression off
SSLSessionTickets off

# HSTS (HTTP Strict Transport Security)
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

# Security headers
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
EOF

sudo a2enconf ssl-hardening

# CREATE VIRTUAL HOST FOR PATIO APPLICATION
# -----------------------------------------------------------------------------
echo ">>> Creating Apache virtual host for Patio application..."

sudo cat > /etc/apache2/sites-available/patio.conf <<EOF
<VirtualHost *:80>
    ServerName patio.example.com
    ServerAdmin admin@patio.example.com

    # Redirect HTTP to HTTPS
    Redirect permanent / https://patio.example.com/

    ErrorLog \${APACHE_LOG_DIR}/patio-error.log
    CustomLog \${APACHE_LOG_DIR}/patio-access.log combined
</VirtualHost>

<VirtualHost *:443>
    ServerName patio.example.com
    ServerAdmin admin@patio.example.com

    DocumentRoot /var/www/patio/public

    <Directory /var/www/patio/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # SSL Configuration
    SSLEngine on
$(if [ "$ENVIRONMENT" == "dev" ]; then
    echo "    SSLCertificateFile /etc/ssl/certs/patio-dev.crt"
    echo "    SSLCertificateKeyFile /etc/ssl/private/patio-dev.key"
else
    echo "    SSLCertificateFile /etc/letsencrypt/live/patio.example.com/fullchain.pem"
    echo "    SSLCertificateKeyFile /etc/letsencrypt/live/patio.example.com/privkey.pem"
fi)

    # Logging
    ErrorLog \${APACHE_LOG_DIR}/patio-ssl-error.log
    CustomLog \${APACHE_LOG_DIR}/patio-ssl-access.log combined

    # Health check endpoint (for load balancer probe)
    Alias /health /var/www/html/health.php
</VirtualHost>
EOF

# Create health check endpoint
sudo mkdir -p /var/www/html
sudo cat > /var/www/html/health.php <<EOF
<?php
// Simple health check for load balancer
http_response_code(200);
echo json_encode(['status' => 'healthy', 'timestamp' => time()]);
EOF

# Enable site and disable default
sudo a2ensite patio.conf
sudo a2dissite 000-default.conf

# Create application directory structure
sudo mkdir -p /var/www/patio/public
sudo chown -R www-data:www-data /var/www/patio
sudo chmod -R 755 /var/www/patio

# CONFIGURE LOG SHIPPING TO AZURE MONITOR (per audit-001)
# -----------------------------------------------------------------------------
echo ">>> Configuring log shipping to Azure Monitor..."

# Configure rsyslog to forward Apache logs
sudo cat >> /etc/rsyslog.d/95-patio-logs.conf <<EOF
# Ship Apache logs to Azure Monitor
\$ModLoad imfile
\$InputFileName /var/log/apache2/patio-access.log
\$InputFileTag apache-access
\$InputFileStateFile stat-apache-access
\$InputFileSeverity info
\$InputRunFileMonitor

\$InputFileName /var/log/apache2/patio-error.log
\$InputFileTag apache-error
\$InputFileStateFile stat-apache-error
\$InputFileSeverity error
\$InputRunFileMonitor
EOF

sudo systemctl restart rsyslog

# CONFIGURE FIREWALL
# -----------------------------------------------------------------------------
# Note: NSG handles network-level firewall, but configure local firewall anyway
echo ">>> Configuring UFW firewall..."
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp  # SSH
sudo ufw allow 80/tcp  # HTTP
sudo ufw allow 443/tcp # HTTPS

# INSTALL CERTBOT FOR LET'S ENCRYPT (production only)
# -----------------------------------------------------------------------------
if [ "$ENVIRONMENT" == "prod" ] || [ "$ENVIRONMENT" == "staging" ]; then
  echo ">>> Installing Certbot for Let's Encrypt SSL certificates..."
  sudo apt-get install -y certbot python3-certbot-apache
  
  # Note: Actual certificate generation must be done post-deployment
  # with proper DNS configuration: sudo certbot --apache -d patio.example.com
fi

# RESTART SERVICES
# -----------------------------------------------------------------------------
echo ">>> Restarting Apache..."
sudo systemctl restart apache2
sudo systemctl enable apache2

# VERIFY INSTALLATION
# -----------------------------------------------------------------------------
echo ">>> Verifying installation..."
echo "Apache version:"
apache2 -v

echo "PHP version:"
php -v

echo "MySQL client version:"
mysql --version

echo "Composer version:"
composer --version

echo "Redis tools version:"
redis-cli --version

echo "Azure CLI version:"
az --version

# CLEANUP
# -----------------------------------------------------------------------------
echo ">>> Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get clean

echo "====================================================================="
echo "LAMP stack installation completed successfully!"
echo "====================================================================="
echo "Next steps:"
echo "1. Deploy Patio PHP application code to /var/www/patio"
echo "2. Configure environment variables from Key Vault"
echo "3. Run database migrations"
echo "4. Test application at https://patio.example.com"
echo "====================================================================="
