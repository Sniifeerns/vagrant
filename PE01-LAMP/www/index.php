<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Servidor LAMP</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }
        h2 {
            color: #555;
            margin-top: 30px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        td, th {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #4CAF50;
            color: white;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .success {
            color: #4CAF50;
            font-weight: bold;
            padding: 10px;
            background-color: #e8f5e9;
            border-radius: 4px;
            margin: 10px 0;
        }
        .error {
            color: #f44336;
            font-weight: bold;
            padding: 10px;
            background-color: #ffebee;
            border-radius: 4px;
            margin: 10px 0;
        }
        .extensions {
            display: flex;
            flex-wrap: wrap;
            gap: 5px;
            margin: 10px 0;
        }
        .extension {
            background-color: #2196F3;
            color: white;
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 0.9em;
        }
        a {
            color: #4CAF50;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Servidor LAMP Funcionando</h1>

        <h2>📊 Información del Servidor</h2>
        <table>
            <tr>
                <th>Propiedad</th>
                <th>Valor</th>
            </tr>
            <tr>
                <td><strong>Hostname</strong></td>
                <td><?php echo gethostname(); ?></td>
            </tr>
            <tr>
                <td><strong>IP</strong></td>
                <td><?php echo $_SERVER['SERVER_ADDR'] ?? 'N/A'; ?></td>
            </tr>
            <tr>
                <td><strong>Sistema Operativo</strong></td>
                <td><?php echo php_uname(); ?></td>
            </tr>
        </table>

        <h2>🔧 Versiones de Software</h2>
        <table>
            <tr>
                <th>Software</th>
                <th>Versión</th>
            </tr>
            <tr>
                <td><strong>Apache</strong></td>
                <td><?php echo apache_get_version(); ?></td>
            </tr>
            <tr>
                <td><strong>MySQL</strong></td>
                <td>
                    <?php
                    try {
                        $conn = new PDO("mysql:host=localhost", "lamp_user", "lamp_pass");
                        $version = $conn->query('SELECT VERSION()')->fetchColumn();
                        echo $version;
                    } catch (PDOException $e) {
                        echo "No disponible";
                    }
                    ?>
                </td>
            </tr>
            <tr>
                <td><strong>PHP</strong></td>
                <td><?php echo phpversion(); ?></td>
            </tr>
        </table>

        <h2>💾 Conexión a Base de Datos</h2>
        <?php
        try {
            $conn = new PDO(
                "mysql:host=localhost;dbname=lamp_db",
                "lamp_user",
                "lamp_pass"
            );
            $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            echo '<p class="success">✅ Conexión exitosa a la base de datos lamp_db</p>';
            echo '<p>Base de datos: <strong>lamp_db</strong></p>';
            echo '<p>Usuario: <strong>lamp_user</strong></p>';
        } catch (PDOException $e) {
            echo '<p class="error">❌ Error de conexión: ' . $e->getMessage() . '</p>';
        }
        ?>

        <h2>📦 Extensiones PHP Cargadas</h2>
        <div class="extensions">
            <?php
            $extensions = get_loaded_extensions();
            sort($extensions);
            foreach ($extensions as $ext) {
                echo '<span class="extension">' . htmlspecialchars($ext) . '</span>';
            }
            ?>
        </div>
        <p><strong>Total:</strong> <?php echo count($extensions); ?> extensiones cargadas</p>

        <h2>🔗 Enlaces</h2>
        <p><a href="info.php">📄 Ver phpinfo() completo</a></p>
    </div>
</body>
</html>
