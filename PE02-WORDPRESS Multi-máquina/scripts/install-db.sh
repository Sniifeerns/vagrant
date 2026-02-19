#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Instalando MySQL ==="
apt-get install -y mysql-server

echo "=== Configurando MySQL para acceso remoto ==="
# Cambiar bind-address para escuchar en todas las interfaces
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# Reiniciar MySQL
systemctl restart mysql

# Esperar a que MySQL esté completamente iniciado
sleep 5

echo "=== Creando base de datos y usuario ==="
mysql <<EOF
-- Crear base de datos
CREATE DATABASE IF NOT EXISTS wordpress_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuario con acceso desde red privada
CREATE USER IF NOT EXISTS 'wp_user'@'192.168.56.%' IDENTIFIED BY 'wp_secure_pass';

-- Otorgar permisos
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'192.168.56.%';
FLUSH PRIVILEGES;

-- Verificar
SHOW DATABASES;
SELECT User, Host FROM mysql.user WHERE User='wp_user';
EOF

echo "=== Configurando seguridad MySQL ==="
# Asegurar que root solo puede acceder desde localhost
mysql <<EOF
-- Eliminar usuarios anónimos si existen
DELETE FROM mysql.user WHERE User='';
-- Asegurar que root solo puede acceder desde localhost
UPDATE mysql.user SET Host='localhost' WHERE User='root' AND Host='%';
FLUSH PRIVILEGES;
EOF

echo "=== MySQL configurado correctamente ==="
echo "Base de datos: wordpress_db"
echo "Usuario: wp_user (acceso desde 192.168.56.%)"
echo "MySQL escuchando en 0.0.0.0:3306"

