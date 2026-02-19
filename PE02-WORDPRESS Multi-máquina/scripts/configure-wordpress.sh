#!/bin/bash
set -e

echo "=== Configurando WordPress ==="

cd /var/www/html

# Crear wp-config.php desde la plantilla
cp wp-config-sample.php wp-config.php

# Configurar credenciales de base de datos
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASS/" wp-config.php
sed -i "s/localhost/$DB_HOST/" wp-config.php

# Generar salt keys desde la API de WordPress
echo "=== Generando salt keys ==="
SALT_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

# Reemplazar las claves de ejemplo con las generadas
php <<ENDPHP
<?php
\$config = file_get_contents('/var/www/html/wp-config.php');

// Obtener las claves desde la API
\$salt_keys = file_get_contents('https://api.wordpress.org/secret-key/1.1/salt/');

// Buscar y reemplazar el bloque de claves
\$pattern = '/\/\*.*?put your unique phrase here.*?\*\//s';
\$replacement = \$salt_keys;

\$config = preg_replace(\$pattern, \$replacement, \$config);

file_put_contents('/var/www/html/wp-config.php', \$config);
?>
ENDPHP

# Añadir configuraciones adicionales
cat >> wp-config.php <<'EOF'

/* Configuración adicional */
define('WP_DEBUG', false);
define('WP_AUTO_UPDATE_CORE', false);
define('DISALLOW_FILE_EDIT', true);

/* Dirección del sitio */
define('WP_SITEURL', 'http://192.168.56.10');
define('WP_HOME', 'http://192.168.56.10');
EOF

echo "=== Verificando conexión a base de datos ==="
php -r "
try {
    \$pdo = new PDO('mysql:host=$DB_HOST;dbname=$DB_NAME', '$DB_USER', '$DB_PASS');
    echo '✓ Conexión a BD exitosa!\n';
} catch (PDOException \$e) {
    echo '✗ Error: ' . \$e->getMessage() . '\n';
    exit(1);
}
"

# Asegurar permisos correctos
chown www-data:www-data wp-config.php
chmod 644 wp-config.php

echo "=== WordPress configurado correctamente ==="
echo ""
echo "=========================================="
echo "  WordPress está listo para usar"
echo "=========================================="
echo "Accede desde el navegador:"
echo "  - http://localhost:8080"
echo "  - http://192.168.56.10"
echo ""
echo "Credenciales de base de datos:"
echo "  Host: $DB_HOST"
echo "  Base de datos: $DB_NAME"
echo "  Usuario: $DB_USER"
echo "=========================================="

