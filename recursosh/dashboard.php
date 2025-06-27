<?php
require_once 'config/database.php';
require_once 'config/session.php';

verificarSesion();

$titulo = 'Dashboard';
$database = new Database();
$db = $database->getConnection();

// Obtener estadísticas
try {
    // Total empleados activos
    $stmt = $db->query("SELECT COUNT(*) as total FROM empleados WHERE estado = 'activo'");
    $total_empleados = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Empleados presentes hoy
    $stmt = $db->query("SELECT COUNT(*) as total FROM asistencia WHERE fecha = CURDATE() AND estado = 'presente'");
    $presentes_hoy = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Permisos pendientes
    $stmt = $db->query("SELECT COUNT(*) as total FROM permisos WHERE estado = 'pendiente'");
    $permisos_pendientes = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Vacaciones en curso
    $stmt = $db->query("SELECT COUNT(*) as total FROM vacaciones WHERE estado = 'en_curso'");
    $vacaciones_curso = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Últimas asistencias
    $stmt = $db->query("
        SELECT a.*, CONCAT(e.nombres, ' ', e.apellidos) as empleado, e.codigo_empleado
        FROM asistencia a 
        JOIN empleados e ON a.id_empleado = e.id_empleado 
        ORDER BY a.fecha_registro DESC 
        LIMIT 10
    ");
    $ultimas_asistencias = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Empleados por departamento
    $stmt = $db->query("
        SELECT d.nombre as departamento, COUNT(e.id_empleado) as total
        FROM departamentos d
        LEFT JOIN puestos p ON d.id_departamento = p.id_departamento
        LEFT JOIN empleados e ON p.id_puesto = e.id_puesto AND e.estado = 'activo'
        GROUP BY d.id_departamento, d.nombre
        ORDER BY total DESC
    ");
    $empleados_departamento = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
} catch (PDOException $e) {
    $error = "Error al obtener estadísticas: " . $e->getMessage();
}

include 'includes/header.php';
?>

<div class="container-fluid">
    <div class="row">
        <?php include 'includes/sidebar.php'; ?>
        
        <div class="col-lg-10">
            <div class="main-content">
                <!-- Header -->
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <div>
                        <h1 class="h3 mb-0 text-gray-800">Dashboard</h1>
                        <p class="text-muted">Bienvenido al sistema de recursos humanos</p>
                    </div>
                    <div class="text-end">
                        <small class="text-muted">
                            <i class="bi bi-calendar"></i> <?php echo date('d/m/Y'); ?>
                        </small>
                    </div>
                </div>

                <!-- Tarjetas de estadísticas -->
                <div class="row mb-4">
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="stats-card">
                            <div class="d-flex align-items-center">
                                <div class="flex-grow-1">
                                    <div class="h4 mb-0"><?php echo $total_empleados; ?></div>
                                    <div class="small">Empleados Activos</div>
                                </div>
                                <div class="ms-3">
                                    <i class="bi bi-people fs-1"></i>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="stats-card success">
                            <div class="d-flex align-items-center">
                                <div class="flex-grow-1">
                                    <div class="h4 mb-0"><?php echo $presentes_hoy; ?></div>
                                    <div class="small">Presentes Hoy</div>
                                </div>
                                <div class="ms-3">
                                    <i class="bi bi-check-circle fs-1"></i>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="stats-card warning">
                            <div class="d-flex align-items-center">
                                <div class="flex-grow-1">
                                    <div class="h4 mb-0"><?php echo $permisos_pendientes; ?></div>
                                    <div class="small">Permisos Pendientes</div>
                                </div>
                                <div class="ms-3">
                                    <i class="bi bi-clock-history fs-1"></i>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="stats-card info">
                            <div class="d-flex align-items-center">
                                <div class="flex-grow-1">
                                    <div class="h4 mb-0"><?php echo $vacaciones_curso; ?></div>
                                    <div class="small">En Vacaciones</div>
                                </div>
                                <div class="ms-3">
                                    <i class="bi bi-calendar-heart fs-1"></i>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="row">
                    <!-- Últimas asistencias -->
                    <div class="col-lg-8 mb-4">
                        <div class="card">
                            <div class="card-header">
                                <h5 class="mb-0"><i class="bi bi-clock-history"></i> Últimas Asistencias</h5>
                            </div>
                            <div class="card-body">
                                <div class="table-responsive">
                                    <table class="table table-hover">
                                        <thead>
                                            <tr>
                                                <th>Empleado</th>
                                                <th>Fecha</th>
                                                <th>Entrada</th>
                                                <th>Salida</th>
                                                <th>Estado</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php foreach ($ultimas_asistencias as $asistencia): ?>
                                            <tr>
                                                <td>
                                                    <strong><?php echo $asistencia['empleado']; ?></strong><br>
                                                    <small class="text-muted"><?php echo $asistencia['codigo_empleado']; ?></small>
                                                </td>
                                                <td><?php echo date('d/m/Y', strtotime($asistencia['fecha'])); ?></td>
                                                <td><?php echo $asistencia['hora_entrada'] ? date('H:i', strtotime($asistencia['hora_entrada'])) : '-'; ?></td>
                                                <td><?php echo $asistencia['hora_salida'] ? date('H:i', strtotime($asistencia['hora_salida'])) : '-'; ?></td>
                                                <td>
                                                    <?php
                                                    $badge_class = '';
                                                    switch($asistencia['estado']) {
                                                        case 'presente': $badge_class = 'bg-success'; break;
                                                        case 'ausente': $badge_class = 'bg-danger'; break;
                                                        case 'tardanza': $badge_class = 'bg-warning'; break;
                                                        case 'permiso': $badge_class = 'bg-info'; break;
                                                        default: $badge_class = 'bg-secondary';
                                                    }
                                                    ?>
                                                    <span class="badge <?php echo $badge_class; ?>">
                                                        <?php echo ucfirst($asistencia['estado']); ?>
                                                    </span>
                                                </td>
                                            </tr>
                                            <?php endforeach; ?>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Gráfico empleados por departamento -->
                    <div class="col-lg-4 mb-4">
                        <div class="card">
                            <div class="card-header">
                                <h5 class="mb-0"><i class="bi bi-pie-chart"></i> Empleados por Departamento</h5>
                            </div>
                            <div class="card-body">
                                <canvas id="departamentosChart" width="400" height="400"></canvas>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Accesos rápidos -->
                <div class="row">
                    <div class="col-12">
                        <div class="card">
                            <div class="card-header">
                                <h5 class="mb-0"><i class="bi bi-lightning"></i> Accesos Rápidos</h5>
                            </div>
                            <div class="card-body">
                                <div class="row">
                                    <?php if($_SESSION['nivel_acceso'] >= 2): ?>
                                    <div class="col-lg-3 col-md-6 mb-3">
                                        <a href="empleados.php?action=nuevo" class="btn btn-outline-primary w-100 p-3">
                                            <i class="bi bi-person-plus fs-4 d-block mb-2"></i>
                                            Nuevo Empleado
                                        </a>
                                    </div>
                                    <?php endif; ?>
                                    
                                    <div class="col-lg-3 col-md-6 mb-3">
                                        <a href="asistencia.php?action=registrar" class="btn btn-outline-success w-100 p-3">
                                            <i class="bi bi-clock fs-4 d-block mb-2"></i>
                                            Registrar Asistencia
                                        </a>
                                    </div>
                                    
                                    <div class="col-lg-3 col-md-6 mb-3">
                                        <a href="permisos.php?action=solicitar" class="btn btn-outline-warning w-100 p-3">
                                            <i class="bi bi-calendar-check fs-4 d-block mb-2"></i>
                                            Solicitar Permiso
                                        </a>
                                    </div>
                                    
                                    <?php if($_SESSION['nivel_acceso'] >= 3): ?>
                                    <div class="col-lg-3 col-md-6 mb-3">
                                        <a href="reportes.php" class="btn btn-outline-info w-100 p-3">
                                            <i class="bi bi-graph-up fs-4 d-block mb-2"></i>
                                            Ver Reportes
                                        </a>
                                    </div>
                                    <?php endif; ?>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
// Gráfico de empleados por departamento
const ctx = document.getElementById('departamentosChart').getContext('2d');
const departamentosData = <?php echo json_encode($empleados_departamento); ?>;

const labels = departamentosData.map(item => item.departamento);
const data = departamentosData.map(item => item.total);

new Chart(ctx, {
    type: 'doughnut',
    data: {
        labels: labels,
        datasets: [{
            data: data,
            backgroundColor: [
                '#2c5aa0',
                '#28a745',
                '#ffc107',
                '#dc3545',
                '#17a2b8',
                '#6f42c1',
                '#fd7e14',
                '#20c997',
                '#e83e8c',
                '#6c757d'
            ],
            borderWidth: 2,
            borderColor: '#fff'
        }]
    },
    options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: {
                position: 'bottom',
                labels: {
                    padding: 20,
                    usePointStyle: true
                }
            }
        }
    }
});
</script>

<?php include 'includes/footer.php'; ?>