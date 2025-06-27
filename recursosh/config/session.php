<?php
session_start();

function verificarSesion() {
    if (!isset($_SESSION['usuario_id'])) {
        header('Location: login.php');
        exit();
    }
}

function verificarPermiso($nivel_requerido) {
    if (!isset($_SESSION['nivel_acceso']) || $_SESSION['nivel_acceso'] < $nivel_requerido) {
        header('Location: dashboard.php?error=sin_permisos');
        exit();
    }
}

function cerrarSesion() {
    session_destroy();
    header('Location: login.php');
    exit();
}
?>