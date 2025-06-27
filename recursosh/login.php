<?php
require_once 'config/database.php';
require_once 'config/session.php';

// Si ya está logueado, redirigir al dashboard
if (isset($_SESSION['usuario_id'])) {
    header('Location: dashboard.php');
    exit();
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $username = trim($_POST['username']);
    $password = $_POST['password'];
    
    if (empty($username) || empty($password)) {
        $error = 'Por favor, complete todos los campos.';
    } else {
        $database = new Database();
        $db = $database->getConnection();
        
        try {
            $query = "SELECT u.*, e.nombres, e.apellidos, r.nombre as rol, r.nivel_acceso 
                     FROM usuarios u 
                     LEFT JOIN empleados e ON u.id_empleado = e.id_empleado 
                     JOIN roles r ON u.id_rol = r.id_rol 
                     WHERE u.username = ? AND u.estado = 'activo'";
            
            $stmt = $db->prepare($query);
            $stmt->execute([$username]);
            $usuario = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($usuario && password_verify($password, $usuario['password_hash'])) {
                // Login exitoso
                $_SESSION['usuario_id'] = $usuario['id_usuario'];
                $_SESSION['username'] = $usuario['username'];
                $_SESSION['nombre_usuario'] = $usuario['nombres'] . ' ' . $usuario['apellidos'];
                $_SESSION['rol'] = $usuario['rol'];
                $_SESSION['nivel_acceso'] = $usuario['nivel_acceso'];
                $_SESSION['id_empleado'] = $usuario['id_empleado'];
                
                // Actualizar último login
                $update_query = "UPDATE usuarios SET fecha_ultimo_login = NOW() WHERE id_usuario = ?";
                $update_stmt = $db->prepare($update_query);
                $update_stmt->execute([$usuario['id_usuario']]);
                
                header('Location: dashboard.php');
                exit();
            } else {
                $error = 'Usuario o contraseña incorrectos.';
            }
        } catch (PDOException $e) {
            $error = 'Error en el sistema. Intente nuevamente.';
        }
    }
}

$titulo = 'Iniciar Sesión';
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo $titulo; ?> - Sistema RRHH Guatemala</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        
        .login-container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1);
            overflow: hidden;
            max-width: 900px;
            width: 100%;
        }
        
        .login-form {
            padding: 60px 40px;
        }
        
        .login-image {
            background: linear-gradient(135deg, #2c5aa0 0%, #1e3d72 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            padding: 60px 40px;
        }
        
        .form-control {
            border-radius: 10px;
            border: 2px solid #e9ecef;
            padding: 15px 20px;
            font-size: 16px;
            transition: all 0.3s ease;
        }
        
        .form-control:focus {
            border-color: #2c5aa0;
            box-shadow: 0 0 0 0.2rem rgba(44, 90, 160, 0.25);
        }
        
        .btn-login {
            background: linear-gradient(135deg, #2c5aa0 0%, #1e3d72 100%);
            border: none;
            border-radius: 10px;
            padding: 15px 30px;
            font-size: 16px;
            font-weight: 600;
            color: white;
            width: 100%;
            transition: all 0.3s ease;
        }
        
        .btn-login:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 30px rgba(44, 90, 160, 0.3);
            color: white;
        }
        
        .logo {
            font-size: 3rem;
            margin-bottom: 20px;
        }
        
        @media (max-width: 768px) {
            .login-image {
                display: none;
            }
            .login-form {
                padding: 40px 30px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-lg-10">
                <div class="login-container">
                    <div class="row g-0">
                        <div class="col-lg-6">
                            <div class="login-image">
                                <div class="text-center">
                                    <div class="logo">
                                        <i class="bi bi-building"></i>
                                    </div>
                                    <h2 class="mb-4">Sistema RRHH</h2>
                                    <h4 class="mb-4">Guatemala</h4>
                                    <p class="lead">Gestión integral de recursos humanos para empresas guatemaltecas</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-6">
                            <div class="login-form">
                                <div class="text-center mb-5">
                                    <h3 class="fw-bold text-dark">Iniciar Sesión</h3>
                                    <p class="text-muted">Ingrese sus credenciales para acceder</p>
                                </div>
                                
                                <?php if ($error): ?>
                                    <div class="alert alert-danger" role="alert">
                                        <i class="bi bi-exclamation-triangle"></i> <?php echo $error; ?>
                                    </div>
                                <?php endif; ?>
                                
                                <form method="POST" action="">
                                    <div class="mb-4">
                                        <label for="username" class="form-label fw-semibold">Usuario</label>
                                        <div class="input-group">
                                            <span class="input-group-text bg-light border-end-0" style="border-radius: 10px 0 0 10px;">
                                                <i class="bi bi-person"></i>
                                            </span>
                                            <input type="text" class="form-control border-start-0" id="username" name="username" 
                                                   placeholder="Ingrese su usuario" required style="border-radius: 0 10px 10px 0;">
                                        </div>
                                    </div>
                                    
                                    <div class="mb-4">
                                        <label for="password" class="form-label fw-semibold">Contraseña</label>
                                        <div class="input-group">
                                            <span class="input-group-text bg-light border-end-0" style="border-radius: 10px 0 0 10px;">
                                                <i class="bi bi-lock"></i>
                                            </span>
                                            <input type="password" class="form-control border-start-0" id="password" name="password" 
                                                   placeholder="Ingrese su contraseña" required style="border-radius: 0 10px 10px 0;">
                                        </div>
                                    </div>
                                    
                                    <div class="mb-4">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" id="remember">
                                            <label class="form-check-label text-muted" for="remember">
                                                Recordar sesión
                                            </label>
                                        </div>
                                    </div>
                                    
                                    <button type="submit" class="btn btn-login">
                                        <i class="bi bi-box-arrow-in-right me-2"></i>
                                        Iniciar Sesión
                                    </button>
                                </form>
                                
                                <div class="text-center mt-4">
                                    <small class="text-muted">
                                        <i class="bi bi-shield-check"></i>
                                        Sistema seguro y confiable
                                    </small>
                                </div>
                                
                                <div class="text-center mt-4">
                                    <small class="text-muted">
                                        Usuario demo: <strong>carlos.perez</strong><br>
                                        Contraseña: <strong>123456</strong>
                                    </small>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>