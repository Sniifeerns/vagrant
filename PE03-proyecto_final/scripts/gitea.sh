#!/bin/bash
# ============================================================
# gitea.sh - Instalación y configuración de Gitea
# VM: gitea (192.168.56.10)
#
# Funciones:
#   - Descarga e instala Gitea (servidor Git ligero)
#   - Configura Gitea como servicio systemd
#   - Crea usuario administrador automáticamente
#   - Crea repositorio "mi-web" con la aplicación
#   - Sube código inicial (index.html + Jenkinsfile)
#   - Configura webhook hacia Jenkins
#   - Accesible en http://localhost:3000
# ============================================================

set -e

echo "=========================================="
echo "  Gitea - Instalación y Configuración"
echo "=========================================="

# --- Variables de configuración (vienen del Vagrantfile / config.yml) ---
GITEA_VERSION="1.21.11"
GITEA_USER="git"
GITEA_ADMIN="${GITEA_ADMIN_USER:-gitea_admin}"
GITEA_PASS="${GITEA_ADMIN_PASSWORD:-gitea_admin}"
GITEA_EMAIL="${GITEA_ADMIN_EMAIL:-admin@local.dev}"
REPO_NAME="${GITEA_REPO_NAME:-mi-web}"
SERVER_IP="${GITEA_IP:-192.168.56.10}"
JENKINS_SERVER_IP="${JENKINS_IP:-192.168.56.20}"
JENKINS_SERVER_PORT="${JENKINS_PORT:-8080}"
DEPLOY_SERVER_IP="${DEPLOY_IP:-192.168.56.30}"

export DEBIAN_FRONTEND=noninteractive

# --- 1. Crear usuario del sistema para Gitea ---
echo ">> Creando usuario '${GITEA_USER}' del sistema..."
if ! id "$GITEA_USER" &>/dev/null; then
    adduser --system --shell /bin/bash --gecos 'Git Version Control' \
        --group --disabled-password --home /home/$GITEA_USER $GITEA_USER
fi

# --- 2. Crear directorios necesarios ---
echo ">> Creando directorios de Gitea..."
mkdir -p /var/lib/gitea/{custom,data,log}
mkdir -p /etc/gitea
chown -R $GITEA_USER:$GITEA_USER /var/lib/gitea
chown -R root:$GITEA_USER /etc/gitea
chmod 770 /etc/gitea

# --- 3. Descargar e instalar el binario de Gitea ---
if [ ! -f /usr/local/bin/gitea ]; then
    echo ">> Descargando Gitea v${GITEA_VERSION}..."
    wget -q "https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64" \
        -O /usr/local/bin/gitea
    chmod +x /usr/local/bin/gitea
    echo "   Gitea descargado correctamente."
else
    echo ">> Gitea ya está instalado."
fi

# --- 4. Copiar archivo de configuración (app.ini) ---
echo ">> Configurando Gitea (app.ini)..."
cp /vagrant/config-files/gitea-app.ini /etc/gitea/app.ini
# Reemplazar placeholders con la IP real del servidor
sed -i "s|__SERVER_IP__|${SERVER_IP}|g" /etc/gitea/app.ini
chown root:$GITEA_USER /etc/gitea/app.ini
chmod 660 /etc/gitea/app.ini

# --- 5. Crear servicio systemd ---
echo ">> Creando servicio systemd para Gitea..."
cat > /etc/systemd/system/gitea.service << 'UNIT'
[Unit]
Description=Gitea (Git con una taza de té)
After=syslog.target
After=network.target

[Service]
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
UNIT

# --- 6. Iniciar el servicio de Gitea ---
echo ">> Iniciando Gitea..."
systemctl daemon-reload
systemctl enable gitea
systemctl start gitea

# --- 7. Esperar a que Gitea esté completamente listo ---
echo ">> Esperando a que Gitea responda..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:3000/api/v1/version > /dev/null 2>&1; then
        echo "   Gitea está listo (intento $i)."
        break
    fi
    echo "   Intento $i/30 - esperando..."
    sleep 5
done

# Verificar que Gitea está funcionando
if ! curl -sf http://localhost:3000/api/v1/version > /dev/null 2>&1; then
    echo ">> ERROR: Gitea no respondió después de 150 segundos."
    exit 1
fi

# --- 8. Crear usuario administrador ---
echo ">> Creando usuario administrador '${GITEA_ADMIN}'..."
su - $GITEA_USER -c "/usr/local/bin/gitea admin user create \
    --config /etc/gitea/app.ini \
    --username '${GITEA_ADMIN}' \
    --password '${GITEA_PASS}' \
    --email '${GITEA_EMAIL}' \
    --admin \
    --must-change-password=false" 2>/dev/null || echo "   (el usuario ya existe, continuando...)"

# --- 9. Crear repositorio para la aplicación web ---
echo ">> Creando repositorio '${REPO_NAME}'..."
curl -sf -X POST "http://localhost:3000/api/v1/user/repos" \
    -H "Content-Type: application/json" \
    -u "${GITEA_ADMIN}:${GITEA_PASS}" \
    -d "{
        \"name\": \"${REPO_NAME}\",
        \"description\": \"Aplicación web desplegada automáticamente via CI/CD\",
        \"auto_init\": false,
        \"private\": false,
        \"default_branch\": \"master\"
    }" > /dev/null 2>&1 || echo "   (el repositorio ya existe, continuando...)"

# --- 10. Subir código inicial al repositorio ---
echo ">> Subiendo código inicial al repositorio..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Configurar git
git config --global init.defaultBranch master
git config --global user.email "${GITEA_EMAIL}"
git config --global user.name "${GITEA_ADMIN}"

# Inicializar repositorio local
git init -q

# Copiar archivos de la aplicación
cp /vagrant/app/index.html .

# Generar Jenkinsfile con la IP correcta del servidor de despliegue
cat > Jenkinsfile << JFILE
pipeline {
    agent any

    stages {
        stage('Clonar repositorio') {
            steps {
                echo 'Descargando código del repositorio Gitea...'
                checkout scm
            }
        }

        stage('Verificar archivos') {
            steps {
                echo 'Verificando que los archivos están correctos...'
                sh 'ls -la'
                sh 'test -f index.html && echo "index.html encontrado OK"'
            }
        }

        stage('Desplegar') {
            steps {
                echo 'Desplegando en el servidor de producción (${DEPLOY_SERVER_IP})...'
                sh '''
                    scp -o StrictHostKeyChecking=no \\
                        -i /var/lib/jenkins/.ssh/id_ed25519 \\
                        index.html vagrant@${DEPLOY_SERVER_IP}:/var/www/html/index.html
                '''
                echo 'Archivos copiados al servidor de despliegue'
            }
        }

        stage('Verificar despliegue') {
            steps {
                echo 'Verificando que la web está accesible...'
                sh 'curl -sf http://${DEPLOY_SERVER_IP} | head -5'
            }
        }
    }

    post {
        success {
            echo 'Pipeline completado con éxito - Aplicación desplegada en http://${DEPLOY_SERVER_IP}'
        }
        failure {
            echo 'Error en el pipeline - Revisar los logs para más detalles'
        }
    }
}
JFILE

# Commit y push al repositorio
git add -A
git commit -q -m "Commit inicial: aplicación web y pipeline CI/CD"
git remote add origin "http://${GITEA_ADMIN}:${GITEA_PASS}@localhost:3000/${GITEA_ADMIN}/${REPO_NAME}.git"
git push -u origin master -q 2>/dev/null
echo "   Código subido correctamente al repositorio."

# Volver al directorio anterior y limpiar
cd /
rm -rf "$TEMP_DIR"

# --- 11. Configurar webhook hacia Jenkins ---
# Cuando se hace push al repo, Gitea notifica a Jenkins automáticamente
echo ">> Configurando webhook a Jenkins (http://${JENKINS_SERVER_IP}:${JENKINS_SERVER_PORT})..."
curl -sf -X POST "http://localhost:3000/api/v1/repos/${GITEA_ADMIN}/${REPO_NAME}/hooks" \
    -H "Content-Type: application/json" \
    -u "${GITEA_ADMIN}:${GITEA_PASS}" \
    -d "{
        \"type\": \"gitea\",
        \"active\": true,
        \"config\": {
            \"url\": \"http://${JENKINS_SERVER_IP}:${JENKINS_SERVER_PORT}/gitea-webhook/post\",
            \"content_type\": \"json\"
        },
        \"events\": [\"push\"]
    }" > /dev/null 2>&1 || echo "   (webhook ya configurado o Jenkins aún no disponible)"

echo ""
echo "=========================================="
echo "  Gitea instalado correctamente"
echo "  URL:        http://${SERVER_IP}:3000"
echo "  Host:       http://localhost:3000"
echo "  Usuario:    ${GITEA_ADMIN}"
echo "  Contraseña: ${GITEA_PASS}"
echo "  Repositorio: ${GITEA_ADMIN}/${REPO_NAME}"
echo "=========================================="
