# PE02-WORDPRESS Multi-máquina - Infraestructura WordPress Multi-máquina


Infraestructura WordPress profesional con separación de servicios utilizando Vagrant. Este proyecto crea dos máquinas virtuales: un servidor web con Apache y PHP, y un servidor de base de datos MySQL separado, comunicándose a través de una red privada.

## Descripción del proyecto

Este proyecto implementa una arquitectura WordPress multi-máquina mediante Vagrant, permitiendo crear un entorno de desarrollo web reproducible y automatizado con separación de servicios. Las máquinas virtuales se configuran automáticamente con:

- **Linux**: Ubuntu 20.04 (Focal Fossa)
- **web-server**: Apache 2.4, PHP 7.4+ y WordPress
- **db-server**: MySQL 8.0 con base de datos preconfigurada

La configuración incluye WordPress completamente instalado y conectado a una base de datos MySQL remota, con resolución de nombres, permisos correctos y configuración automática de wp-config.php.

## Instrucciones de uso

### 1. Clonar o descargar el proyecto

```bash
cd "PE02-WORDPRESS Multi-máquina"
```

### 2. Iniciar las máquinas virtuales

```bash
vagrant up
```

Este comando descargará la imagen de Ubuntu (si es la primera vez), creará ambas VMs y ejecutará automáticamente los scripts de provisioning para instalar y configurar Apache, MySQL, PHP y WordPress.

### 3. Verificar el estado

Una vez completada la instalación, puedes verificar que los servicios están funcionando:

```bash
# Verificar estado de ambas VMs
vagrant status

# Verificar estado de Apache en web-server
vagrant ssh web -c "systemctl status apache2"

# Verificar estado de MySQL en db-server
vagrant ssh db -c "systemctl status mysql"

# Probar conexión a la base de datos desde web-server
vagrant ssh web -c "mysql -h 192.168.56.20 -u wp_user -pwp_secure_pass -e 'SHOW DATABASES;'"
```

**Verificación de conectividad entre VMs:**

```bash
# Ping desde web-server hacia db-server
vagrant ssh web -c "ping -c 3 192.168.56.20"
vagrant ssh web -c "ping -c 3 db-server"
```

### 4. Acceder a WordPress

Abre tu navegador y visita:
- **http://localhost:8080** - Instalador de WordPress
- **http://192.168.56.10** - Acceso directo por IP privada

Sigue el asistente de instalación de WordPress para completar la configuración inicial.

### 5. Comandos útiles

```bash
# Conectarse por SSH al servidor web
vagrant ssh web

# Conectarse por SSH al servidor de BD
vagrant ssh db

# Detener todas las VMs (sin destruirlas)
vagrant halt

# Reiniciar las VMs
vagrant reload

# Destruir todas las VMs (eliminar completamente)
vagrant destroy

# Re-provisionar (ejecutar scripts de nuevo)
vagrant provision
```

## Accesos

### URLs

- **Web (puerto redirigido)**: http://localhost:8080
- **Web (IP privada)**: http://192.168.56.10
- **SSH web-server**: `vagrant ssh web` (desde el directorio del proyecto)
- **SSH db-server**: `vagrant ssh db` (desde el directorio del proyecto)

### Credenciales

#### MySQL

- **Host**: `192.168.56.20`
- **Usuario**: `wp_user`
- **Contraseña**: `wp_secure_pass`
- **Base de datos**: `wordpress_db`

#### SSH

- **Usuario**: `vagrant`
- **Contraseña**: `vagrant` (o usar clave SSH automática)
- **Acceso**: `vagrant ssh web` o `vagrant ssh db` desde el directorio del proyecto

### Configuración de las VMs

#### web-server
- **Hostname**: `web-server`
- **IP privada**: `192.168.56.10`
- **RAM**: 1024 MB
- **Box**: `ubuntu/focal64`

#### db-server
- **Hostname**: `db-server`
- **IP privada**: `192.168.56.20`
- **RAM**: 2048 MB
- **Box**: `ubuntu/focal64`

## Estructura del proyecto

```
PE02-WORDPRESS Multi-máquina/
├── .gitignore               # Archivos a ignorar en Git
├── Vagrantfile              # Configuración de las VMs
├── README.md                # Este archivo
├── PE02_wordpress.md        # Documentación del proyecto
├── scripts/                 # Scripts de provisioning
│   ├── common.sh           # Configuración común para ambas VMs
│   ├── install-db.sh       # Instalación y configuración de MySQL
│   ├── install-web.sh      # Instalación de Apache, PHP y WordPress
│   └── configure-wordpress.sh  # Configuración automática de WordPress
└── config/                  # Configuraciones
    └── wordpress.conf       # Configuración de VirtualHost de Apache
```

## Solución de problemas

### El puerto 8080 está en uso

Si el puerto 8080 ya está ocupado, puedes cambiarlo en el `Vagrantfile`:

```ruby
web.vm.network "forwarded_port", guest: 80, host: 8081
```

Luego ejecuta `vagrant reload`.

### MySQL rechaza conexiones remotas

```bash
# Verificar usuarios MySQL
vagrant ssh db
sudo mysql -e "SELECT User, Host FROM mysql.user WHERE User='wp_user';"

# Verificar que MySQL escucha en todas las interfaces
sudo netstat -tlnp | grep 3306

# Verificar configuración de bind-address
sudo cat /etc/mysql/mysql.conf.d/mysqld.cnf | grep bind-address
```

### WordPress no conecta a BD

```bash
# Verificar configuración de wp-config.php
vagrant ssh web
cat /var/www/html/wp-config.php | grep DB_

# Probar conexión manualmente
php -r "new PDO('mysql:host=192.168.56.20;dbname=wordpress_db', 'wp_user', 'wp_secure_pass');"

# Verificar logs de Apache
sudo tail -f /var/log/apache2/wordpress_error.log
```

### Error al instalar paquetes

Si hay problemas con la instalación, intenta:

```bash
vagrant destroy
vagrant up
```

### La IP privada no funciona

Asegúrate de que VirtualBox tenga configurada la red privada. Puedes verificar con:

```bash
vagrant ssh web -c "ip addr show"
vagrant ssh db -c "ip addr show"
```

### Problemas con permisos

```bash
vagrant ssh web
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html/ -type d -exec chmod 755 {} \;
sudo find /var/www/html/ -type f -exec chmod 644 {} \;
```

## Información técnica

### Software instalado

- **Apache 2.4** con módulos rewrite y headers habilitados
- **MySQL 8.0** configurado para acceso remoto desde red privada
- **PHP 7.4+** con extensiones:
  - php-mysql
  - php-curl
  - php-gd
  - php-mbstring
  - php-xml
  - php-xmlrpc
  - php-zip
  - php-intl
  - php-opcache
- **WordPress** (última versión) con configuración automática

### Características

- ✅ Provisioning completamente automatizado
- ✅ Dos VMs con red privada configurada (192.168.56.0/24)
- ✅ Puerto HTTP redirigido (8080 → 80)
- ✅ Base de datos y usuario creados automáticamente
- ✅ WordPress instalado y conectado a BD remota
- ✅ Resolución de nombres configurada (/etc/hosts)
- ✅ wp-config.php autoconfigurable con salt keys
- ✅ Permisos correctos (www-data propietario)
- ✅ Scripts de instalación separados y organizados
- ✅ PHP OPcache habilitado para mejor rendimiento
- ✅ Seguridad MySQL (solo usuario necesario, sin root remoto)
- ✅ Virtual host personalizado configurado

## Autor

Proyecto realizado para la práctica PE02 - Infraestructura WordPress Multi-máquina

Javier Naranjo Simarro

## Licencia

Este proyecto es de uso educativo.
======

