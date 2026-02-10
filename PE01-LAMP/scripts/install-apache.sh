#!/bin/bash
set -e

echo "=== Instalando Apache ==="

# Actualizar lista de paquetes
apt-get update

# Instalar Apache
apt-get install -y apache2

# Habilitar módulos necesarios
a2enmod rewrite
a2enmod ssl

# Crear virtual host personalizado
echo "=== Configurando Virtual Host ==="
cat > /etc/apache2/sites-available/lamp-server.conf <<EOF
<VirtualHost *:80>
    ServerName lamp-server
    ServerAlias lamp-server.local
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/lamp-server_error.log
    CustomLog \${APACHE_LOG_DIR}/lamp-server_access.log combined
</VirtualHost>
EOF

# Deshabilitar sitio por defecto y habilitar el nuevo
a2dissite 000-default.conf
a2ensite lamp-server.conf

# Habilitar y iniciar Apache
systemctl enable apache2
systemctl start apache2

# Verificar que Apache está funcionando
systemctl status apache2 --no-pager

echo "Apache instalado correctamente con virtual host personalizado"
