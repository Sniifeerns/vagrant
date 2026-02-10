#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== Instalando MySQL ==="

# Actualizar lista de paquetes
apt-get update

# Instalar MySQL Server
apt-get install -y mysql-server

# Iniciar y habilitar MySQL
systemctl enable mysql
systemctl start mysql

echo "=== Configurando MySQL ==="

# Crear base de datos y usuario
mysql <<EOF
CREATE DATABASE IF NOT EXISTS lamp_db;
CREATE USER IF NOT EXISTS 'lamp_user'@'localhost' IDENTIFIED BY 'lamp_pass';
GRANT ALL PRIVILEGES ON lamp_db.* TO 'lamp_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# Verificar que MySQL está funcionando
systemctl status mysql --no-pager

echo "MySQL configurado correctamente"
