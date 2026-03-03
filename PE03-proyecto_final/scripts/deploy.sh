#!/bin/bash
# ============================================================
# deploy.sh - Configuración del Servidor de Despliegue
# VM: deploy (192.168.56.30)
#
# Funciones:
#   - Instala Nginx como servidor web
#   - Configura Nginx para servir la aplicación
#   - Copia la página web inicial
#   - Instala la clave pública SSH de Jenkins (para despliegues)
#   - Accesible desde el host en http://localhost:8888
# ============================================================

set -e

echo "=========================================="
echo "  Servidor de Despliegue - Configuración"
echo "=========================================="

export DEBIAN_FRONTEND=noninteractive

# --- 1. Instalar Nginx ---
echo ">> Instalando Nginx..."
apt-get install -y -qq nginx > /dev/null 2>&1

# --- 2. Crear directorio de la aplicación web ---
echo ">> Preparando directorio web..."
mkdir -p /var/www/html

# --- 3. Copiar la página web inicial ---
# Esta página será reemplazada por Jenkins en cada despliegue
echo ">> Copiando página web inicial..."
cp /vagrant/app/index.html /var/www/html/index.html

# --- 4. Copiar configuración de Nginx ---
echo ">> Configurando Nginx..."
cp /vagrant/config-files/nginx-deploy.conf /etc/nginx/sites-available/default

# --- 5. Configurar acceso SSH para Jenkins ---
# Jenkins se conectará por SSH para copiar los archivos desplegados
DEPLOY_USER="vagrant"
SSH_DIR="/home/${DEPLOY_USER}/.ssh"
mkdir -p "$SSH_DIR"

if [ -f /vagrant/config-files/ssh/jenkins_key.pub ]; then
    echo ">> Instalando clave pública SSH de Jenkins..."
    cat /vagrant/config-files/ssh/jenkins_key.pub >> "$SSH_DIR/authorized_keys"
    # Eliminar duplicados (idempotente)
    sort -u -o "$SSH_DIR/authorized_keys" "$SSH_DIR/authorized_keys"
    chmod 600 "$SSH_DIR/authorized_keys"
    chown -R ${DEPLOY_USER}:${DEPLOY_USER} "$SSH_DIR"
    echo "   Clave SSH instalada correctamente."
else
    echo "   AVISO: Clave SSH no encontrada. Jenkins no podrá desplegar."
fi

# --- 6. Dar permisos al usuario vagrant sobre el directorio web ---
# Esto permite que Jenkins (via SSH como vagrant) pueda escribir archivos
chown -R vagrant:vagrant /var/www/html
chmod -R 755 /var/www/html

# --- 7. Habilitar y reiniciar Nginx ---
echo ">> Iniciando Nginx..."
systemctl enable nginx
systemctl restart nginx

# --- 8. Verificar que Nginx está funcionando ---
if systemctl is-active --quiet nginx; then
    echo ">> Nginx está corriendo correctamente."
else
    echo ">> ERROR: Nginx no se pudo iniciar."
    exit 1
fi

echo ""
echo "=========================================="
echo "  Servidor de Despliegue configurado"
echo "  URL: http://192.168.56.30"
echo "  Puerto host: http://localhost:8888"
echo "=========================================="
