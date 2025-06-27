<?php
require_once 'config/database.php';
require_once 'config/session.php';

verificarSesion();
verificarPermiso(2); // Nivel mínimo para gestionar empleados

$titulo = 'Gestión de Empleados';
$database = new Database();
$db = $database->getConnection();

$action = $_GET['action'] ?? 'listar';
$mensaje = '';
$error = '';

// Procesar acciones
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    if ($action == 'crear' || $action == 'editar') {
        $datos = [
            'codigo_empleado' => trim($_POST['codigo_empleado']),
            'nombres' => trim($_POST['nombres']),
            'apellidos' => trim($_POST['apellidos']),
            'dpi' => trim($_POST['dpi']),
            'nit' => trim($_POST['nit']),
            'telefono' => trim($_POST['telefono']),
            'email' => trim($_POST['email']),
            'direccion' => trim($_POST['direccion']),
            'fecha_nacimiento' => $_POST['fecha_nacimiento'],
            'sexo' => $_POST['sexo'],
            'estado_civil' => $_POST['estado_civil'],
            'numero_igss' => trim($_POST['numero_igss']),
            'numero_irtra' => trim($_POST['numero_irtra']),
            'numero_cuenta_bancaria' => trim($_POST['numero_cuenta_bancaria']),
            'banco' => trim($_POST['banco']),
            'id_puesto' => $_POST['id_puesto'],
            'fecha_ingreso' => $_POST['fecha_ingreso'],
            'salario_base' => $_POST['salario_base'],
            'bonificacion_decreto' => $_POST['bonificacion_decreto'] ?: 250.00
        ];
        
        try {
            if ($action == 'crear') {
                $query = "INSERT INTO empleados (codigo_empleado, nombres, apellidos, dpi, nit, telefono, email, direccion, 
                         fecha_nacimiento, sexo, estado_civil, numero_igss, numero_irtra, numero_cuenta_bancaria, banco, 
                         id_puesto, fecha_ingreso, salario_base, bonificacion_decreto) 
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                
                $stmt = $db->prepare($query);
                $stmt->execute(array_values($datos));
                $mensaje = 'Empleado creado exitosamente.';
            } else {
                $id = $_POST['id_empleado'];
                $query = "UPDATE empleados SET codigo_empleado=?, nombres=?, apellidos=?, dpi=?, nit=?, telefono=?, 
                         email=?, direccion=?, fecha_nacimiento=?, sexo=?, estado_civil=?, numero_igss=?, numero_irtra=?, 
                         numero_cuenta_bancaria=?, banco=?, id_puesto=?, fecha_ingreso=?, salario_base=?, bonificacion_decreto=? 
                         WHERE id_empleado=?";
                
                $stmt = $db->prepare($query);
                $valores = array_values($datos);
                $valores[] = $id;
                $stmt->execute($valores);
                $mensaje = 'Empleado actualizado exitosamente.';
            }
            
            $action = 'listar';
        } catch (PDOException $e) {
            $error = 'Error al guardar empleado: ' . $e->getMessage();
        }
    }
}

// Eliminar empleado
if ($action == 'eliminar' && isset($_GET['id'])) {
    try {
        $stmt = $db->prepare("UPDATE empleados SET estado = 'inactivo' WHERE id_empleado = ?");
        $stmt->execute([$_GET['id']]);
        $mensaje = 'Empleado desactivado exitosamente.';
        $action = 'listar';
    } catch (PDOException $e) {
        $error = 'Error al eliminar empleado: ' . $e->getMessage();
    }
}

// Obtener datos para formularios
if ($action == 'nuevo' || $action == 'editar') {
    // Obtener puestos
    $stmt = $db->query("SELECT p.*, d.nombre as departamento FROM puestos p JOIN departamentos d ON p.id_departamento = d.id_departamento WHERE p.estado = 'activo' ORDER BY d.nombre, p.nombre");
    $puestos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Si es edición, obtener datos del empleado
    if ($action == 'editar' && isset($_GET['id'])) {
        $stmt = $db->prepare("SELECT * FROM empleados WHERE id_empleado = ?");
        $stmt->execute([$_GET['id']]);
        $empleado = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$empleado) {
            $error = 'Empleado no encontrado.';
            $action = 'listar';
        }
    }
}

// Listar empleados
if ($action == 'listar') {
    $stmt = $db->query("
        SELECT e.*, p.nombre as puesto, d.nombre as departamento 
        FROM empleados e 
        LEFT JOIN puestos p ON e.id_puesto = p.id_puesto 
        LEFT JOIN departamentos d ON p.id_departamento = d.id_departamento 
        WHERE e.estado != 'finiquitado'
        ORDER BY e.nombres, e.apellidos
    ");
    $empleados = $stmt->fetchAll(PDO::FETCH_ASSOC);
}

include 'includes/header.php';
?>

<div class="container-fluid">
    <div class="row">
        <?php include 'includes/sidebar.php'; ?>
        
        <div class="col-lg-10">
            <div class="main-content">
                <?php if ($action == 'listar'): ?>
                <!-- Lista de empleados -->
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <div>
                        <h1 class="h3 mb-0">Gestión de Empleados</h1>
                        <p class="text-muted">Administre la información de los empleados</p>
                    </div>
                    <a href="?action=nuevo" class="btn btn-primary">
                        <i class="bi bi-person-plus"></i> Nuevo Empleado
                    </a>
                </div>

                <?php if ($mensaje): ?>
                    <div class="alert alert-success alert-dismissible fade show" role="alert">
                        <i class="bi bi-check-circle"></i> <?php echo $mensaje; ?>
                        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                    </div>
                <?php endif; ?>

                <?php if ($error): ?>
                    <div class="alert alert-danger alert-dismissible fade show" role="alert">
                        <i class="bi bi-exclamation-triangle"></i> <?php echo $error; ?>
                        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                    </div>
                <?php endif; ?>

                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0"><i class="bi bi-people"></i> Lista de Empleados</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table id="empleadosTable" class="table table-striped table-hover">
                                <thead>
                                    <tr>
                                        <th>Código</th>
                                        <th>Nombre Completo</th>
                                        <th>DPI</th>
                                        <th>Puesto</th>
                                        <th>Departamento</th>
                                        <th>Salario</th>
                                        <th>Estado</th>
                                        <th>Acciones</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($empleados as $emp): ?>
                                    <tr>
                                        <td><strong><?php echo $emp['codigo_empleado']; ?></strong></td>
                                        <td>
                                            <?php echo $emp['nombres'] . ' ' . $emp['apellidos']; ?><br>
                                            <small class="text-muted"><?php echo $emp['email']; ?></small>
                                        </td>
                                        <td><?php echo $emp['dpi']; ?></td>
                                        <td><?php echo $emp['puesto'] ?: 'Sin asignar'; ?></td>
                                        <td><?php echo $emp['departamento'] ?: 'Sin asignar'; ?></td>
                                        <td>Q <?php echo number_format($emp['salario_base'], 2); ?></td>
                                        <td>
                                            <?php
                                            $badge_class = '';
                                            switch($emp['estado']) {
                                                case 'activo': $badge_class = 'bg-success'; break;
                                                case 'inactivo': $badge_class = 'bg-secondary'; break;
                                                case 'suspendido': $badge_class = 'bg-warning'; break;
                                                default: $badge_class = 'bg-danger';
                                            }
                                            ?>
                                            <span class="badge <?php echo $badge_class; ?>">
                                                <?php echo ucfirst($emp['estado']); ?>
                                            </span>
                                        </td>
                                        <td>
                                            <div class="btn-group" role="group">
                                                <a href="?action=editar&id=<?php echo $emp['id_empleado']; ?>" 
                                                   class="btn btn-sm btn-outline-primary" data-bs-toggle="tooltip" title="Editar">
                                                    <i class="bi bi-pencil"></i>
                                                </a>
                                                <button onclick="confirmDelete('?action=eliminar&id=<?php echo $emp['id_empleado']; ?>', '¿Desea desactivar este empleado?')" 
                                                        class="btn btn-sm btn-outline-danger" data-bs-toggle="tooltip" title="Desactivar">
                                                    <i class="bi bi-trash"></i>
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

                <?php elseif ($action == 'nuevo' || $action == 'editar'): ?>
                <!-- Formulario de empleado -->
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <div>
                        <h1 class="h3 mb-0"><?php echo $action == 'nuevo' ? 'Nuevo' : 'Editar'; ?> Empleado</h1>
                        <p class="text-muted">Complete la información del empleado</p>
                    </div>
                    <a href="?action=listar" class="btn btn-secondary">
                        <i class="bi bi-arrow-left"></i> Volver
                    </a>
                </div>

                <?php if ($error): ?>
                    <div class="alert alert-danger alert-dismissible fade show" role="alert">
                        <i class="bi bi-exclamation-triangle"></i> <?php echo $error; ?>
                        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                    </div>
                <?php endif; ?>

                <form method="POST" action="?action=<?php echo $action; ?>">
                    <?php if ($action == 'editar'): ?>
                        <input type="hidden" name="id_empleado" value="<?php echo $empleado['id_empleado']; ?>">
                    <?php endif; ?>
                    
                    <div class="row">
                        <div class="col-lg-8">
                            <div class="card">
                                <div class="card-header">
                                    <h5 class="mb-0"><i class="bi bi-person"></i> Información Personal</h5>
                                </div>
                                <div class="card-body">
                                    <div class="row">
                                        <div class="col-md-6 mb-3">
                                            <label for="codigo_empleado" class="form-label">Código de Empleado *</label>
                                            <input type="text" class="form-control" id="codigo_empleado" name="codigo_empleado" 
                                                   value="<?php echo $empleado['codigo_empleado'] ?? ''; ?>" required>
                                        </div>
                                        <div class="col-md-6 mb-3">
                                            <label for="dpi" class="form-label">DPI *</label>
                                            <input type="text" class="form-control" id="dpi" name="dpi" 
                                                   value="<?php echo $empleado['dpi'] ?? ''; ?>" required>
                                        </div>
                                    </div>
                                    
                                    <div class="row">
                                        <div class="col-md-6 mb-3">
                                            <label for="nombres" class="form-label">Nombres *</label>
                                            <input type="text" class="form-control" id="nombres" name="nombres" 
                                                   value="<?php echo $empleado['nombres'] ?? ''; ?>" required>
                                        </div>
                                        <div class="col-md-6 mb-3">
                                            <label for="apellidos" class="form-label">Apellidos *</label>
                                            <input type="text" class="form-control" id="apellidos" name="apellidos" 
                                                   value="<?php echo $empleado['apellidos'] ?? ''; ?>" required>
                                        </div>
                                    </div>
                                    
                                    <div class="row">
                                        <div class="col-md-6 mb-3">
                                            <label for="fecha_nacimiento" class="form-label">Fecha de Nacimiento</label>
                                            <input type="date" class="form-control" id="fecha_nacimiento" name="fecha_nacimiento" 
                                                   value="<?php echo $empleado['fecha_nacimiento'] ?? ''; ?>">
                                        </div>
                                        <div class="col-md-3 mb-3">
                                            <label for="sexo" class="form-label">Sexo</label>
                                            <select class="form-select" id="sexo" name="sexo">
                                                <option value="">Seleccionar</option>
                                                <option value="M" <?php echo (isset($empleado['sexo']) && $empleado['sexo'] == 'M') ? 'selected' : ''; ?>>Masculino</option>
                                                <option value="F" <?php echo (isset($empleado['sexo']) && $empleado['sexo'] == 'F') ? 'selected' : ''; ?>>Femenino</option>
                                            </select>
                                        </div>
                                        <div class="col-md-3 mb-3">
                                            <label for="estado_civil" class="form-label">Estado Civil</label>
                                            <select class="form-select" id="estado_civil" name="estado_civil">
                                                <option value="">Seleccionar</option>
                                                <option value="soltero" <?php echo (isset($empleado['estado_civil']) && $empleado['estado_civil'] == 'soltero') ? 'selected' : ''; ?>>Soltero</option>
                                                <option value="casado" <?php echo (isset($empleado['estado_civil']) && $empleado['estado_civil'] == 'casado') ? 'selected' : ''; ?>>Casado</option>
                                                <option value="divorciado" <?php echo (isset($empleado['estado_civil']) && $empleado['estado_civil'] == 'divorciado') ? 'selected' : ''; ?>>Divorciado</option>
                                                <option value="viudo" <?php echo (isset($empleado['estado_civil']) && $empleado['estado_civil'] == 'viudo') ? 'selected' : ''; ?>>Viudo</option>
                                                <option value="union_hecho" <?php echo (isset($empleado['estado_civil']) && $empleado['estado_civil'] == 'union_hecho') ? 'selected' : ''; ?>>Unión de Hecho</option>
                                            </select>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="card mt-4">
                                <div class="card-header">
                                    <h5 class="mb-0"><i class="bi bi-telephone"></i> Información de Contacto</h5>
                                </div>
                                <div class="card-body">
                                    <div class="row">
                                        <div class="col-md-6 mb-3">
                                            <label for="telefono" class="form-label">Teléfono</label>
                                            <input type="text" class="form-control" id="telefono" name="telefono" 
                                                   value="<?php echo $empleado['telefono'] ?? ''; ?>">
                                        </div>
                                        <div class="col-md-6 mb-3">
                                            <label for="email" class="form-label">Email</label>
                                            <input type="email" class="form-control" id="email" name="email" 
                                                   value="<?php echo $empleado['email'] ?? ''; ?>">
                                        </div>
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="direccion" class="form-label">Dirección</label>
                                        <textarea class="form-control" id="direccion" name="direccion" rows="3"><?php echo $empleado['direccion'] ?? ''; ?></textarea>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="col-lg-4">
                            <div class="card">
                                <div class="card-header">
                                    <h5 class="mb-0"><i class="bi bi-briefcase"></i> Información Laboral</h5>
                                </div>
                                <div class="card-body">
                                    <div class="mb-3">
                                        <label for="id_puesto" class="form-label">Puesto *</label>
                                        <select class="form-select" id="id_puesto" name="id_puesto" required>
                                            <option value="">Seleccionar puesto</option>
                                            <?php foreach ($puestos as $puesto): ?>
                                                <option value="<?php echo $puesto['id_puesto']; ?>" 
                                                        <?php echo (isset($empleado['id_puesto']) && $empleado['id_puesto'] == $puesto['id_puesto']) ? 'selected' : ''; ?>>
                                                    <?php echo $puesto['departamento'] . ' - ' . $puesto['nombre']; ?>
                                                </option>
                                            <?php endforeach; ?>
                                        </select>
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="fecha_ingreso" class="form-label">Fecha de Ingreso *</label>
                                        <input type="date" class="form-control" id="fecha_ingreso" name="fecha_ingreso" 
                                               value="<?php echo $empleado['fecha_ingreso'] ?? ''; ?>" required>
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="salario_base" class="form-label">Salario Base *</label>
                                        <div class="input-group">
                                            <span class="input-group-text">Q</span>
                                            <input type="number" class="form-control" id="salario_base" name="salario_base" 
                                                   step="0.01" value="<?php echo $empleado['salario_base'] ?? ''; ?>" required>
                                        </div>
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="bonificacion_decreto" class="form-label">Bonificación Decreto</label>
                                        <div class="input-group">
                                            <span class="input-group-text">Q</span>
                                            <input type="number" class="form-control" id="bonificacion_decreto" name="bonificacion_decreto" 
                                                   step="0.01" value="<?php echo $empleado['bonificacion_decreto'] ?? '250.00'; ?>">
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="card mt-4">
                                <div class="card-header">
                                    <h5 class="mb-0"><i class="bi bi-shield"></i> Información Legal</h5>
                                </div>
                                <div class="card-body">
                                    <div class="mb-3">
                                        <label for="nit" class="form-label">NIT</label>
                                        <input type="text" class="form-control" id="nit" name="nit" 
                                               value="<?php echo $empleado['nit'] ?? ''; ?>">
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="numero_igss" class="form-label">Número IGSS</label>
                                        <input type="text" class="form-control" id="numero_igss" name="numero_igss" 
                                               value="<?php echo $empleado['numero_igss'] ?? ''; ?>">
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="numero_irtra" class="form-label">Número IRTRA</label>
                                        <input type="text" class="form-control" id="numero_irtra" name="numero_irtra" 
                                               value="<?php echo $empleado['numero_irtra'] ?? ''; ?>">
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="numero_cuenta_bancaria" class="form-label">Cuenta Bancaria</label>
                                        <input type="text" class="form-control" id="numero_cuenta_bancaria" name="numero_cuenta_bancaria" 
                                               value="<?php echo $empleado['numero_cuenta_bancaria'] ?? ''; ?>">
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="banco" class="form-label">Banco</label>
                                        <select class="form-select" id="banco" name="banco">
                                            <option value="">Seleccionar banco</option>
                                            <option value="Banrural" <?php echo (isset($empleado['banco']) && $empleado['banco'] == 'Banrural') ? 'selected' : ''; ?>>Banrural</option>
                                            <option value="Banco Industrial" <?php echo (isset($empleado['banco']) && $empleado['banco'] == 'Banco Industrial') ? 'selected' : ''; ?>>Banco Industrial</option>
                                            <option value="G&T Continental" <?php echo (isset($empleado['banco']) && $empleado['banco'] == 'G&T Continental') ? 'selected' : ''; ?>>G&T Continental</option>
                                            <option value="BAC" <?php echo (isset($empleado['banco']) && $empleado['banco'] == 'BAC') ? 'selected' : ''; ?>>BAC</option>
                                            <option value="Bantrab" <?php echo (isset($empleado['banco']) && $empleado['banco'] == 'Bantrab') ? 'selected' : ''; ?>>Bantrab</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="d-grid gap-2 mt-4">
                                <button type="submit" class="btn btn-primary btn-lg">
                                    <i class="bi bi-check-circle"></i> 
                                    <?php echo $action == 'nuevo' ? 'Crear Empleado' : 'Actualizar Empleado'; ?>
                                </button>
                                <a href="?action=listar" class="btn btn-secondary">
                                    <i class="bi bi-x-circle"></i> Cancelar
                                </a>
                            </div>
                        </div>
                    </div>
                </form>
                <?php endif; ?>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    $('#empleadosTable').DataTable({
        order: [[1, 'asc']],
        columnDefs: [
            { orderable: false, targets: [7] }
        ]
    });
});
</script>

<?php include 'includes/footer.php'; ?>