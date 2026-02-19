#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Instalando Apache ==="
apt-get install -y apache2

echo "=== Instalando PHP y extensiones ==="
apt-get install -y php libapache2-mod-php php-mysql php-curl php-gd \
  php-mbstring php-xml php-xmlrpc php-zip php-intl php-opcache

echo "=== Instalando cliente MySQL para pruebas desde web-server ==="
apt-get install -y mysql-client

echo "=== Habilitando módulos Apache ==="
a2enmod rewrite
a2enmod headers

echo "=== Configurando PHP OPcache ==="
# Habilitar OPcache para mejorar rendimiento
cat >> /etc/php/7.4/apache2/php.ini <<EOF

; OPcache Configuration
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
EOF

echo "=== Descargando WordPress ==="
cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
rm latest.tar.gz

echo "=== Instalando WordPress ==="
rm -rf /var/www/html/*
cp -r wordpress/* /var/www/html/
rm -rf /tmp/wordpress

echo "=== Configurando permisos ==="
chown -R www-data:www-data /var/www/html
find /var/www/html/ -type d -exec chmod 755 {} \;
find /var/www/html/ -type f -exec chmod 644 {} \;

echo "=== Configurando Apache VirtualHost ==="
cat > /etc/apache2/sites-available/wordpress.conf <<'EOF'
<VirtualHost *:80>
    ServerName web-server
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/wordpress_error.log
    CustomLog ${APACHE_LOG_DIR}/wordpress_access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf
a2ensite wordpress.conf

echo "=== Reiniciando Apache ==="
systemctl restart apache2

echo "=== Apache y PHP instalados ==="
echo "WordPress descargado en /var/www/html"
echo "OPcache habilitado"

