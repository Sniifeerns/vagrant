#!/bin/bash
# ============================================================
# common.sh - Configuración común para TODAS las VMs
# Se ejecuta en: gitea, jenkins, deploy
#
# Funciones:
#   - Actualiza paquetes del sistema
#   - Instala herramientas básicas (curl, wget, git, etc.)
#   - Configura /etc/hosts para que las VMs se resuelvan por nombre
#   - Genera par de claves SSH compartidas (para Jenkins → Deploy)
# ============================================================

set -e

echo "=========================================="
echo "  Configuración común - Inicio"
echo "=========================================="

# Evitar prompts interactivos durante la instalación
export DEBIAN_FRONTEND=noninteractive

# --- 1. Limpiar repositorios externos rotos (por si se re-provisiona) ---
rm -f /etc/apt/sources.list.d/jenkins.list 2>/dev/null
rm -f /usr/share/keyrings/jenkins-keyring.asc 2>/dev/null
rm -f /usr/share/keyrings/jenkins-keyring.gpg 2>/dev/null

# --- 2. Actualizar repositorios e instalar paquetes básicos ---
echo ">> Actualizando paquetes del sistema..."
apt-get update -qq
apt-get install -y -qq curl wget git net-tools sshpass > /dev/null 2>&1

# --- 3. Configurar /etc/hosts ---
# Permite que las VMs se comuniquen usando nombres en vez de IPs
echo ">> Configurando /etc/hosts..."
if ! grep -q "gitea" /etc/hosts; then
    cat >> /etc/hosts << EOF

# --- VMs del proyecto CI/CD ---
192.168.56.10 gitea
192.168.56.20 jenkins
192.168.56.30 deploy
EOF
fi

# --- 4. Generar par de claves SSH compartidas ---
# Se usan para que Jenkins pueda conectarse al servidor de despliegue
# sin pedir contraseña. Solo se generan una vez (idempotente).
SSH_DIR="/vagrant/config-files/ssh"
if [ ! -f "$SSH_DIR/jenkins_key" ]; then
    echo ">> Generando par de claves SSH para Jenkins → Deploy..."
    mkdir -p "$SSH_DIR"
    ssh-keygen -t ed25519 -f "$SSH_DIR/jenkins_key" -N "" -C "jenkins@cicd" -q
    chmod 644 "$SSH_DIR/jenkins_key.pub"
    chmod 600 "$SSH_DIR/jenkins_key"
    echo "   Claves generadas en $SSH_DIR"
else
    echo ">> Claves SSH ya existen, no se regeneran."
fi

echo ">> Configuración común completada."
echo ""
