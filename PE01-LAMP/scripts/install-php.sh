#!/bin/bash
set -e

echo "=== Instalando PHP ==="

# Actualizar lista de paquetes
apt-get update

# Instalar PHP y extensiones necesarias
apt-get install -y php php-mysql php-curl php-gd php-mbstring php-xml libapache2-mod-php

# Habilitar módulo PHP en Apache
a2enmod php7.4 2>/dev/null || a2enmod php8.0 2>/dev/null || a2enmod php8.1 2>/dev/null || a2enmod php8.2 2>/dev/null || echo "Módulo PHP ya habilitado"

# Reiniciar Apache para aplicar cambios
systemctl restart apache2

# Verificar versión de PHP instalada
php -v

echo "PHP instalado correctamente con todas las extensiones"
