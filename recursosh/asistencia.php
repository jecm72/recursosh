<?php
require_once 'config/database.php';
require_once 'config/session.php';

verificarSesion();

$titulo = 'Control de Asistencia';
$database = new Database();
$db = $database->getConnection();

$action = $_GET['action'] ?? 'listar';
$mensaje = '';
$error = '';

// Procesar registro de asistencia
if ($_SERVER['REQUEST_METHOD'] == 'POST' && $action == 'registrar') {
    $id_empleado = $_POST['id_empleado'];
    $fecha = $_POST['fecha'];
    $hora_entrada = $_POST['hora_entrada'] ?: null;
    $hora_salida = $_POST['hora_salida'] ?: null;
    $estado = $_POST['estado'];
    $observaciones = trim($_POST['observaciones']);
    
    // Calcular horas trabajadas
    $horas_trabajadas = null;
    $horas_extra = 0;
    
    if ($hora_entrada && $hora_salida) {
        $entrada = new DateTime($hora_entrada);
        $salida = new DateTime($hora_salida);
        $diff = $entrada->diff($salida);
        $horas_trabajadas = $diff->h + ($diff->i / 60);
        
        // Calcular horas extra (más de 8 horas)
        if ($horas_trabajadas > 8) {
            $horas_extra = $horas_trabajadas - 8;
        }
    }
    
    try {
        // Verificar si ya existe registro para esa fecha
        $check_stmt = $db->prepare("SELECT id_asistencia FROM asistencia WHERE id_empleado = ? AND fecha = ?");
        $check_stmt->execute([$id_empleado, $fecha]);
        
        if ($check_stmt->fetch()) {
            // Actualizar registro existente
            $query = "UPDATE asistencia SET hora_entrada=?, hora_salida=?, horas_trabajadas=?, horas_extra=?, 
                     estado=?, observaciones=? WHERE id_empleado=? AND fecha=?";
            $stmt = $db->prepare($query);
            $stmt->execute([$hora_entrada, $hora_salida, $horas_trabajadas, $horas_extra, $estado, $observaciones, $id_empleado, $fecha]);
            $mensaje = 'Asistencia actualizada exitosamente.';
        } else {
            // Crear nuevo registro
            $query = "INSERT INTO asistencia (id_empleado, fecha, hora_entrada, hora_salida, horas_trabajadas, 
                     horas_extra, estado, observaciones) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
            $stmt = $db->prepare($query);
            $stmt->execute([$id_empleado, $fecha, $hora_entrada, $hora_salida, $horas_trabajadas, $horas_extra, $estado, $observaciones]);
            $mensaje = 'Asistencia registrada exitosamente.';
        }
        
        $action = 'listar';
    } catch (PDOException $e) {
        $error = 'Error al registrar asistencia: ' . $e->getMessage();
    }
}

// Obtener empleados activos para el formulario
if ($action == 'registrar') {
    $stmt = $db->query("SELECT id_empleado, codigo_empleado, CONCAT(nombres, ' ', apellidos) as nombre_completo 
                       FROM empleados WHERE estado = 'activo' ORDER BY nombres, apellidos");
    $empleados = $stmt->fetchAll(PDO::FETCH_ASSOC);
}

// Listar asistencias
if ($action == 'listar') {
    $fecha_filtro = $_GET['fecha'] ?? date('Y-m-d');
    
    $query = "SELECT a.*, CONCAT(e.nombres, ' ', e.apellidos) as empleado, e.codigo_empleado, p.nombre as puesto
              FROM asistencia a 
              JOIN empleados e ON a.id_empleado = e.id_empleado 
              LEFT JOIN puestos p ON e.id_puesto = p.id_puesto 
              WHERE a.fecha = ? 
              ORDER BY e.nombres, e.apellidos";
    
    $stmt = $db->prepare($query);
    $stmt->execute([$fecha_filtro]);
    $asistencias = $stmt->fetchAll(PDO::FETCH_ASSOC);
}

include 'includes/header.php';
?>

<div class="container-fluid">
    <div class="row">
        <?php include 'includes/sidebar.php'; ?>
        
        <div class="col-lg-10">
            <div class="main-content">
                <?php if ($action == 'listar'): ?>
                <!-- Lista de asistencias -->
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <div>
                        <h1 class="h3 mb-0">Control de Asistencia</h1>
                        <p class="text-muted">Gestione la asistencia diaria de los empleados</p>
                    </div>
                    <div class="d-flex gap-2">
                        <a href="?action=registrar" class="btn btn-primary">
                            <i class="bi bi-plus-circle"></i> Registrar Asistencia
                        </a>
                        <a href="reportes.php?tipo=asistencia" class="btn btn-outline-info">
                            <i class="bi bi-graph-up"></i> Reportes
                        </a>
                    </div>
                </div>

                <?php if ($mensaje): ?>
                    <div class="alert alert-success alert-dismissible fade show" role="alert">
                        <i class="bi bi-check-circle"></i> <?php echo $mensaje; ?>
                        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                    </div>
                <?php endif; ?>

                <!-- Filtro por fecha -->
                <div class="card mb-4">
                    <div class="card-body">
                        <form method="GET" class="row g-3 align-items-end">
                            <input type="hidden" name="action" value="listar">
                            <div class="col-md-4">
                                <label for="fecha" class="form-label">Fecha</label>
                                <input type="date" class="form-control" id="fecha" name="fecha" 
                                       value="<?php echo $fecha_filtro; ?>">
                            </div>
                            <div class="col-md-2">
                                <button type="submit" class="btn btn-primary w-100">
                                    <i class="bi bi-search"></i> Filtrar
                                </button>
                            </div>
                            <div class="col-md-6 text-end">
                                <div class="btn-group" role="group">
                                    <a href="?action=listar&fecha=<?php echo date('Y-m-d'); ?>" class="btn btn-outline-secondary">Hoy</a>
                                    <a href="?action=listar&fecha=<?php echo date('Y-m-d', strtotime('yesterday')); ?>" class="btn btn-outline-secondary">Ayer</a>
                                    <a href="?action=listar&fecha=<?php echo date('Y-m-d', strtotime('monday this week')); ?>" class="btn btn-outline-secondary">Esta Semana</a>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">
                            <i class="bi bi-calendar-check"></i> 
                            Asistencia del <?php echo date('d/m/Y', strtotime($fecha_filtro)); ?>
                        </h5>
                        <span class="badge bg-primary"><?php echo count($asistencias); ?> registros</span>
                    </div>
                    <div class="card-body">
                        <?php if (empty($asistencias)): ?>
                            <div class="text-center py-5">
                                <i class="bi bi-calendar-x fs-1 text-muted"></i>
                                <h5 class="mt-3 text-muted">No hay registros de asistencia</h5>
                                <p class="text-muted">No se encontraron registros para la fecha seleccionada.</p>
                                <a href="?action=registrar" class="btn btn-primary">
                                    <i class="bi bi-plus-circle"></i> Registrar Asistencia
                                </a>
                            </div>
                        <?php else: ?>
                            <div class="table-responsive">
                                <table id="asistenciaTable" class="table table-striped table-hover">
                                    <thead>
                                        <tr>
                                            <th>Empleado</th>
                                            <th>Puesto</th>
                                            <th>Entrada</th>
                                            <th>Salida</th>
                                            <th>Horas</th>
                                            <th>H. Extra</th>
                                            <th>Estado</th>
                                            <th>Observaciones</th>
                                            <th>Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php foreach ($asistencias as $asist): ?>
                                        <tr>
                                            <td>
                                                <strong><?php echo $asist['empleado']; ?></strong><br>
                                                <small class="text-muted"><?php echo $asist['codigo_empleado']; ?></small>
                                            </td>
                                            <td><?php echo $asist['puesto'] ?: 'Sin asignar'; ?></td>
                                            <td>
                                                <?php if ($asist['hora_entrada']): ?>
                                                    <span class="badge bg-success">
                                                        <?php echo date('H:i', strtotime($asist['hora_entrada'])); ?>
                                                    </span>
                                                <?php else: ?>
                                                    <span class="text-muted">-</span>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <?php if ($asist['hora_salida']): ?>
                                                    <span class="badge bg-info">
                                                        <?php echo date('H:i', strtotime($asist['hora_salida'])); ?>
                                                    </span>
                                                <?php else: ?>
                                                    <span class="text-muted">-</span>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <?php if ($asist['horas_trabajadas']): ?>
                                                    <?php echo number_format($asist['horas_trabajadas'], 2); ?>h
                                                <?php else: ?>
                                                    <span class="text-muted">-</span>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <?php if ($asist['horas_extra'] > 0): ?>
                                                    <span class="badge bg-warning">
                                                        <?php echo number_format($asist['horas_extra'], 2); ?>h
                                                    </span>
                                                <?php else: ?>
                                                    <span class="text-muted">-</span>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <?php
                                                $badge_class = '';
                                                switch($asist['estado']) {
                                                    case 'presente': $badge_class = 'bg-success'; break;
                                                    case 'ausente': $badge_class = 'bg-danger'; break;
                                                    case 'tardanza': $badge_class = 'bg-warning'; break;
                                                    case 'permiso': $badge_class = 'bg-info'; break;
                                                    case 'vacaciones': $badge_class = 'bg-primary'; break;
                                                    case 'enfermedad': $badge_class = 'bg-secondary'; break;
                                                    default: $badge_class = 'bg-secondary';
                                                }
                                                ?>
                                                <span class="badge <?php echo $badge_class; ?>">
                                                    <?php echo ucfirst($asist['estado']); ?>
                                                </span>
                                            </td>
                                            <td>
                                                <?php if ($asist['observaciones']): ?>
                                                    <span data-bs-toggle="tooltip" title="<?php echo htmlspecialchars($asist['observaciones']); ?>">
                                                        <i class="bi bi-chat-text text-info"></i>
                                                    </span>
                                                <?php else: ?>
                                                    <span class="text-muted">-</span>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <a href="?action=editar&id=<?php echo $asist['id_asistencia']; ?>" 
                                                   class="btn btn-sm btn-outline-primary" data-bs-toggle="tooltip" title="Editar">
                                                    <i class="bi bi-pencil"></i>
                                                </a>
                                            </td>
                                        </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>

                <?php elseif ($action == 'registrar'): ?>
                <!-- Formulario de registro -->
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <div>
                        <h1 class="h3 mb-0">Registrar Asistencia</h1>
                        <p class="text-muted">Complete la información de asistencia del empleado</p>
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

                <div class="row">
                    <div class="col-lg-8">
                        <div class="card">
                            <div class="card-header">
                                <h5 class="mb-0"><i class="bi bi-clock"></i> Información de Asistencia</h5>
                            </div>
                            <div class="card-body">
                                <form method="POST" action="?action=registrar">
                                    <div class="row">
                                        <div class="col-md-6 mb-3">
                                            <label for="id_empleado" class="form-label">Empleado *</label>
                                            <select class="form-select" id="id_empleado" name="id_empleado" required>
                                                <option value="">Seleccionar empleado</option>
                                                <?php foreach ($empleados as $emp): ?>
                                                    <option value="<?php echo $emp['id_empleado']; ?>">
                                                        <?php echo $emp['codigo_empleado'] . ' - ' . $emp['nombre_completo']; ?>
                                                    </option>
                                                <?php endforeach; ?>
                                            </select>
                                        </div>
                                        <div class="col-md-6 mb-3">
                                            <label for="fecha" class="form-label">Fecha *</label>
                                            <input type="date" class="form-control" id="fecha" name="fecha" 
                                                   value="<?php echo date('Y-m-d'); ?>" required>
                                        </div>
                                    </div>
                                    
                                    <div class="row">
                                        <div class="col-md-4 mb-3">
                                            <label for="hora_entrada" class="form-label">Hora de Entrada</label>
                                            <input type="time" class="form-control" id="hora_entrada" name="hora_entrada">
                                        </div>
                                        <div class="col-md-4 mb-3">
                                            <label for="hora_salida" class="form-label">Hora de Salida</label>
                                            <input type="time" class="form-control" id="hora_salida" name="hora_salida">
                                        </div>
                                        <div class="col-md-4 mb-3">
                                            <label for="estado" class="form-label">Estado *</label>
                                            <select class="form-select" id="estado" name="estado" required>
                                                <option value="presente">Presente</option>
                                                <option value="ausente">Ausente</option>
                                                <option value="tardanza">Tardanza</option>
                                                <option value="permiso">Permiso</option>
                                                <option value="vacaciones">Vacaciones</option>
                                                <option value="enfermedad">Enfermedad</option>
                                            </select>
                                        </div>
                                    </div>
                                    
                                    <div class="mb-3">
                                        <label for="observaciones" class="form-label">Observaciones</label>
                                        <textarea class="form-control" id="observaciones" name="observaciones" rows="3" 
                                                  placeholder="Comentarios adicionales sobre la asistencia..."></textarea>
                                    </div>
                                    
                                    <div class="d-flex gap-2">
                                        <button type="submit" class="btn btn-primary">
                                            <i class="bi bi-check-circle"></i> Registrar Asistencia
                                        </button>
                                        <a href="?action=listar" class="btn btn-secondary">
                                            <i class="bi bi-x-circle"></i> Cancelar
                                        </a>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-lg-4">
                        <div class="card">
                            <div class="card-header">
                                <h5 class="mb-0"><i class="bi bi-info-circle"></i> Información</h5>
                            </div>
                            <div class="card-body">
                                <div class="alert alert-info">
                                    <h6><i class="bi bi-lightbulb"></i> Consejos:</h6>
                                    <ul class="mb-0 small">
                                        <li>Las horas extra se calculan automáticamente (más de 8 horas)</li>
                                        <li>Si no hay hora de entrada/salida, marque como "Ausente"</li>
                                        <li>Use "Tardanza" para llegadas después de la hora establecida</li>
                                        <li>Las observaciones son útiles para justificar ausencias</li>
                                    </ul>
                                </div>
                                
                                <div class="mt-3">
                                    <h6>Estados de Asistencia:</h6>
                                    <div class="d-flex flex-wrap gap-1">
                                        <span class="badge bg-success">Presente</span>
                                        <span class="badge bg-danger">Ausente</span>
                                        <span class="badge bg-warning">Tardanza</span>
                                        <span class="badge bg-info">Permiso</span>
                                        <span class="badge bg-primary">Vacaciones</span>
                                        <span class="badge bg-secondary">Enfermedad</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <?php endif; ?>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    $('#asistenciaTable').DataTable({
        order: [[0, 'asc']],
        columnDefs: [
            { orderable: false, targets: [8] }
        ]
    });
    
    // Auto-completar hora actual al hacer clic en entrada
    $('#hora_entrada').on('focus', function() {
        if (!this.value) {
            const now = new Date();
            const hours = String(now.getHours()).padStart(2, '0');
            const minutes = String(now.getMinutes()).padStart(2, '0');
            this.value = `${hours}:${minutes}`;
        }
    });
    
    // Auto-completar hora actual al hacer clic en salida
    $('#hora_salida').on('focus', function() {
        if (!this.value) {
            const now = new Date();
            const hours = String(now.getHours()).padStart(2, '0');
            const minutes = String(now.getMinutes()).padStart(2, '0');
            this.value = `${hours}:${minutes}`;
        }
    });
});
</script>

<?php include 'includes/footer.php'; ?>