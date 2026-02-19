#!/bin/bash
set -e

echo "=== Configuración común ==="

# Actualizar sistema
apt-get update

# Instalar utilidades
apt-get install -y vim curl wget net-tools

# Configurar /etc/hosts para resolución de nombres
cat >> /etc/hosts <<EOF
192.168.56.10 web-server
192.168.56.20 db-server
EOF

# Configurar timezone
timedatectl set-timezone Europe/Madrid

echo "=== Configuración común completada ==="

