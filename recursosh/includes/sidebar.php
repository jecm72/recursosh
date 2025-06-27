<!-- Sidebar -->
<div class="col-lg-2 p-0">
    <nav class="sidebar" id="sidebar">
        <div class="nav flex-column p-3">
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'dashboard.php' ? 'active' : ''; ?>" href="dashboard.php">
                <i class="bi bi-speedometer2"></i> Dashboard
            </a>
            
            <?php if(isset($_SESSION['nivel_acceso']) && $_SESSION['nivel_acceso'] >= 2): ?>
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'empleados.php' ? 'active' : ''; ?>" href="empleados.php">
                <i class="bi bi-people"></i> Empleados
            </a>
            <?php endif; ?>
            
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'asistencia.php' ? 'active' : ''; ?>" href="asistencia.php">
                <i class="bi bi-clock"></i> Asistencia
            </a>
            
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'permisos.php' ? 'active' : ''; ?>" href="permisos.php">
                <i class="bi bi-calendar-check"></i> Permisos
            </a>
            
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'vacaciones.php' ? 'active' : ''; ?>" href="vacaciones.php">
                <i class="bi bi-calendar-heart"></i> Vacaciones
            </a>
            
            <?php if(isset($_SESSION['nivel_acceso']) && $_SESSION['nivel_acceso'] >= 3): ?>
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'nomina.php' ? 'active' : ''; ?>" href="nomina.php">
                <i class="bi bi-currency-dollar"></i> Nómina
            </a>
            
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'bono14.php' ? 'active' : ''; ?>" href="bono14.php">
                <i class="bi bi-gift"></i> Bono 14
            </a>
            
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'aguinaldo.php' ? 'active' : ''; ?>" href="aguinaldo.php">
                <i class="bi bi-star"></i> Aguinaldo
            </a>
            
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'indemnizaciones.php' ? 'active' : ''; ?>" href="indemnizaciones.php">
                <i class="bi bi-shield-check"></i> Indemnizaciones
            </a>
            <?php endif; ?>
            
            <?php if(isset($_SESSION['nivel_acceso']) && $_SESSION['nivel_acceso'] >= 4): ?>
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'reportes.php' ? 'active' : ''; ?>" href="reportes.php">
                <i class="bi bi-graph-up"></i> Reportes
            </a>
            
            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'usuarios.php' ? 'active' : ''; ?>" href="usuarios.php">
                <i class="bi bi-person-gear"></i> Usuarios
            </a>
            <?php endif; ?>
        </div>
    </nav>
</div>