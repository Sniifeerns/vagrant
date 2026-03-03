#!/bin/bash
# ============================================================
# jenkins.sh - Instalación y configuración de Jenkins
# VM: jenkins (192.168.56.20)
#
# Funciones:
#   - Instala Java OpenJDK 17 (requisito de Jenkins)
#   - Instala Jenkins desde el repositorio oficial
#   - Desactiva el asistente de configuración inicial
#   - Crea usuario administrador automáticamente (Groovy)
#   - Instala plugins necesarios (git, pipeline, gitea, etc.)
#   - Crea pipeline "deploy-mi-web" que conecta con Gitea
#   - Configura claves SSH para desplegar en el servidor Deploy
#   - Accesible en http://localhost:8080
# ============================================================

set -e

echo "=========================================="
echo "  Jenkins - Instalación y Configuración"
echo "=========================================="

# --- Variables de configuración (vienen del Vagrantfile / config.yml) ---
ADMIN_USER="${JENKINS_ADMIN_USER:-admin}"
ADMIN_PASS="${JENKINS_ADMIN_PASSWORD:-admin}"
GIT_IP="${GITEA_IP:-192.168.56.10}"
GIT_PORT="${GITEA_PORT:-3000}"
GIT_REPO="${GITEA_REPO_NAME:-mi-web}"
GIT_USER="${GITEA_ADMIN_USER:-gitea_admin}"
GIT_PASS="${GITEA_ADMIN_PASSWORD:-gitea_admin}"
DEPLOY_SERVER="${DEPLOY_IP:-192.168.56.30}"

export DEBIAN_FRONTEND=noninteractive

# ===========================================================
# FASE 1: Instalación de Java y Jenkins
# ===========================================================

# --- 1. Instalar Java OpenJDK 17 ---
echo ">> Instalando Java OpenJDK 17..."
apt-get install -y -qq fontconfig openjdk-17-jre > /dev/null 2>&1
echo "   Java instalado: $(java -version 2>&1 | head -1)"

# --- 2. Añadir repositorio oficial de Jenkins ---
echo ">> Añadiendo repositorio de Jenkins..."
# Importar clave GPG desde keyserver (la clave del fichero .key está desactualizada)
gpg --keyserver keyserver.ubuntu.com --recv-keys 7198F4B714ABFC68 2>/dev/null
gpg --export 7198F4B714ABFC68 2>/dev/null | tee /usr/share/keyrings/jenkins-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | \
    tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# --- 3. Instalar Jenkins ---
echo ">> Instalando Jenkins (esto puede tardar unos minutos)..."
apt-get update -qq 2>/dev/null
apt-get install -y -qq jenkins > /dev/null 2>&1

# ===========================================================
# FASE 2: Configuración previa al inicio
# ===========================================================

# --- 4. Desactivar el asistente de configuración inicial ---
echo ">> Configurando Jenkins para omitir el asistente de instalación..."
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
EOF

# --- 5. Crear script Groovy para configurar admin automáticamente ---
# Este script se ejecuta cuando Jenkins arranca por primera vez
echo ">> Creando script de configuración del usuario admin..."
mkdir -p /var/lib/jenkins/init.groovy.d

cat > /var/lib/jenkins/init.groovy.d/01-create-admin.groovy << GROOVY
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

// Siempre recrear el security realm para asegurar user/pass correctos
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("${ADMIN_USER}", "${ADMIN_PASS}")
instance.setSecurityRealm(hudsonRealm)

// Dar permisos completos al admin
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
println(">> Usuario admin '${ADMIN_USER}' configurado correctamente.")
GROOVY

# Eliminar el password inicial de Jenkins (ya no es necesario)
rm -f /var/lib/jenkins/secrets/initialAdminPassword

chown -R jenkins:jenkins /var/lib/jenkins

# ===========================================================
# FASE 3: Configurar claves SSH para despliegue
# ===========================================================

# --- 6. Instalar clave SSH privada para conectar con Deploy ---
echo ">> Configurando claves SSH para acceso al servidor de despliegue..."
JENKINS_SSH_DIR="/var/lib/jenkins/.ssh"
mkdir -p "$JENKINS_SSH_DIR"

if [ -f /vagrant/config-files/ssh/jenkins_key ]; then
    cp /vagrant/config-files/ssh/jenkins_key "$JENKINS_SSH_DIR/id_ed25519"
    cp /vagrant/config-files/ssh/jenkins_key.pub "$JENKINS_SSH_DIR/id_ed25519.pub"
    chmod 700 "$JENKINS_SSH_DIR"
    chmod 600 "$JENKINS_SSH_DIR/id_ed25519"
    chmod 644 "$JENKINS_SSH_DIR/id_ed25519.pub"

    # Añadir Deploy server a known_hosts (evita pregunta de fingerprint)
    ssh-keyscan -H "$DEPLOY_SERVER" >> "$JENKINS_SSH_DIR/known_hosts" 2>/dev/null
    chown -R jenkins:jenkins "$JENKINS_SSH_DIR"
    echo "   Clave SSH instalada correctamente."
else
    echo "   AVISO: Clave SSH no encontrada en /vagrant/config-files/ssh/"
fi

# ===========================================================
# FASE 4: Iniciar Jenkins
# ===========================================================

# --- 7. Iniciar Jenkins ---
echo ">> Iniciando Jenkins..."
systemctl daemon-reload
systemctl enable jenkins
systemctl restart jenkins

# --- 8. Esperar a que Jenkins esté completamente listo ---
echo ">> Esperando a que Jenkins esté disponible (puede tardar 1-2 min)..."
for i in $(seq 1 60); do
    if curl -sf http://localhost:8080/login > /dev/null 2>&1; then
        echo "   Jenkins está listo (intento $i)."
        break
    fi
    if [ $((i % 5)) -eq 0 ]; then
        echo "   Intento $i/60 - esperando..."
    fi
    sleep 5
done

# Verificar que Jenkins respondió
if ! curl -sf http://localhost:8080/login > /dev/null 2>&1; then
    echo ">> AVISO: Jenkins aún arrancando, continuando con la configuración..."
fi

# ===========================================================
# FASE 5: Instalar plugins y crear pipeline
# ===========================================================

# --- 9. Esperar un poco más para que Jenkins cargue completamente ---
echo ">> Esperando a que Jenkins termine de inicializarse..."
sleep 30

# --- 10. Descargar Jenkins CLI ---
echo ">> Descargando Jenkins CLI..."
for i in $(seq 1 10); do
    if wget -q http://localhost:8080/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar 2>/dev/null; then
        echo "   Jenkins CLI descargado."
        break
    fi
    sleep 10
done

# --- 11. Instalar plugins necesarios ---
if [ -f /tmp/jenkins-cli.jar ]; then
    echo ">> Instalando plugins de Jenkins..."

    # Lista de plugins necesarios para el pipeline CI/CD
    PLUGINS=(
        "git"                    # Integración con repositorios Git
        "workflow-aggregator"    # Pipeline (necesario para Jenkinsfile)
        "pipeline-stage-view"    # Vista de etapas del pipeline
        "ssh-agent"              # Agente SSH para despliegues
        "credentials"            # Gestión de credenciales
        "credentials-binding"    # Binding de credenciales en pipelines
        "gitea"                  # Integración con Gitea (webhooks)
        "ws-cleanup"             # Limpieza de workspace
    )

    for plugin in "${PLUGINS[@]}"; do
        echo "   Instalando plugin: $plugin"
        java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ \
            -auth "${ADMIN_USER}:${ADMIN_PASS}" \
            install-plugin "$plugin" 2>/dev/null || echo "   (no se pudo instalar $plugin, continuando...)"
    done

    # --- 12. Reiniciar Jenkins para cargar plugins ---
    echo ">> Reiniciando Jenkins para cargar plugins..."
    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ \
        -auth "${ADMIN_USER}:${ADMIN_PASS}" \
        safe-restart 2>/dev/null || systemctl restart jenkins

    # Esperar al reinicio
    echo ">> Esperando reinicio de Jenkins..."
    sleep 20
    for i in $(seq 1 40); do
        if curl -sf http://localhost:8080/login > /dev/null 2>&1; then
            echo "   Jenkins reiniciado correctamente (intento $i)."
            break
        fi
        sleep 5
    done

    # Esperar un poco más para que los plugins se carguen
    sleep 15

    # --- 13. Crear el pipeline job "deploy-mi-web" ---
    echo ">> Creando pipeline 'deploy-mi-web'..."
    # Usamos el fichero XML del directorio compartido (config-files/)
    # Se sustituyen los placeholders con las IPs reales
    cp /vagrant/config-files/job-config.xml /tmp/job-config.xml
    sed -i "s|192.168.56.10:3000/gitea_admin/mi-web|${GIT_IP}:${GIT_PORT}/${GIT_USER}/${GIT_REPO}|g" /tmp/job-config.xml

    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ \
        -auth "${ADMIN_USER}:${ADMIN_PASS}" \
        create-job "deploy-mi-web" < /tmp/job-config.xml 2>/dev/null || \
        echo "   (el job ya existe o hubo un error al crearlo)"

    # --- 14. Ejecutar el pipeline una primera vez ---
    echo ">> Ejecutando pipeline por primera vez..."
    sleep 5
    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ \
        -auth "${ADMIN_USER}:${ADMIN_PASS}" \
        build "deploy-mi-web" 2>/dev/null || \
        echo "   (no se pudo ejecutar el pipeline automáticamente)"

else
    echo ">> AVISO: No se pudo descargar Jenkins CLI."
    echo "   Los plugins y el job deberán configurarse manualmente."
fi

echo ""
echo "=========================================="
echo "  Jenkins instalado correctamente"
echo "  URL:        http://192.168.56.20:8080"
echo "  Host:       http://localhost:8080"
echo "  Usuario:    ${ADMIN_USER}"
echo "  Contraseña: ${ADMIN_PASS}"
echo ""
echo "  Pipeline:   deploy-mi-web"
echo "  Repositorio: http://${GIT_IP}:${GIT_PORT}/${GIT_USER}/${GIT_REPO}"
echo "  Despliega en: ${DEPLOY_SERVER}"
echo "=========================================="
