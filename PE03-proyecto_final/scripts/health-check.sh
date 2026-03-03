#!/bin/bash
# ============================================================
# health-check.sh - Script de monitorización (Punto extra)
# Verifica que todos los servicios del entorno CI/CD están
# funcionando correctamente.
#
# Uso: vagrant ssh deploy -c "bash /vagrant/scripts/health-check.sh"
#      (o desde cualquier VM con acceso a la red)
# ============================================================

echo "=========================================="
echo "  Health Check - Entorno CI/CD"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

ERRORS=0

# --- Función para verificar un servicio ---
check_service() {
    local NAME="$1"
    local URL="$2"
    local EXPECTED_CODE="${3:-200}"

    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout 5 "$URL" 2>/dev/null)

    if [ "$HTTP_CODE" = "$EXPECTED_CODE" ]; then
        echo "  [OK]    $NAME ($URL) - HTTP $HTTP_CODE"
    else
        echo "  [FALLO] $NAME ($URL) - HTTP ${HTTP_CODE:-timeout}"
        ERRORS=$((ERRORS + 1))
    fi
}

# --- Función para verificar ping ---
check_ping() {
    local NAME="$1"
    local IP="$2"

    if ping -c 1 -W 2 "$IP" > /dev/null 2>&1; then
        echo "  [OK]    $NAME ($IP) - Ping OK"
    else
        echo "  [FALLO] $NAME ($IP) - No responde al ping"
        ERRORS=$((ERRORS + 1))
    fi
}

# --- 1. Verificar conectividad de red ---
echo "1. Conectividad de red:"
check_ping "Gitea" "192.168.56.10"
check_ping "Jenkins" "192.168.56.20"
check_ping "Deploy" "192.168.56.30"
echo ""

# --- 2. Verificar servicios web ---
echo "2. Servicios web:"
check_service "Gitea (Web)" "http://192.168.56.10:3000"
check_service "Gitea (API)" "http://192.168.56.10:3000/api/v1/version"
check_service "Jenkins" "http://192.168.56.20:8080/login"
check_service "Deploy (Nginx)" "http://192.168.56.30"
echo ""

# --- 3. Verificar repositorio en Gitea ---
echo "3. Repositorio Gitea:"
REPO_CHECK=$(curl -sf "http://192.168.56.10:3000/api/v1/repos/gitea_admin/mi-web" 2>/dev/null)
if [ -n "$REPO_CHECK" ]; then
    echo "  [OK]    Repositorio 'mi-web' existe"
else
    echo "  [FALLO] Repositorio 'mi-web' no encontrado"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# --- 4. Verificar contenido desplegado ---
echo "4. Contenido desplegado:"
WEB_CONTENT=$(curl -sf http://192.168.56.30 2>/dev/null)
if echo "$WEB_CONTENT" | grep -q "CI/CD Pipeline"; then
    echo "  [OK]    La página web contiene el contenido esperado"
else
    echo "  [FALLO] La página web no tiene el contenido esperado"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# --- Resumen ---
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo "  RESULTADO: Todos los checks OK"
    echo "  Estado: SALUDABLE"
else
    echo "  RESULTADO: $ERRORS check(s) fallido(s)"
    echo "  Estado: PROBLEMAS DETECTADOS"
fi
echo "=========================================="

exit $ERRORS
