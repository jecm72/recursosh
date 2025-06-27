-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 27-06-2025 a las 01:26:09
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `rrhh_guatemala`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `autenticar_usuario` (IN `p_username` VARCHAR(50), IN `p_password_hash` VARCHAR(255), IN `p_ip_address` VARCHAR(45), OUT `p_resultado` VARCHAR(100), OUT `p_id_usuario` INT, OUT `p_token_sesion` VARCHAR(255))   BEGIN
    DECLARE v_id_usuario INT DEFAULT 0;
    DECLARE v_password_hash VARCHAR(255);
    DECLARE v_bloqueado BOOLEAN DEFAULT FALSE;
    DECLARE v_intentos_fallidos INT DEFAULT 0;
    DECLARE v_estado VARCHAR(20);
    
    -- Obtener información del usuario
    SELECT id_usuario, password_hash, bloqueado, intentos_fallidos, estado
    INTO v_id_usuario, v_password_hash, v_bloqueado, v_intentos_fallidos, v_estado
    FROM usuarios 
    WHERE username = p_username;
    
    IF v_id_usuario = 0 THEN
        SET p_resultado = 'Usuario no encontrado';
        SET p_id_usuario = 0;
        SET p_token_sesion = NULL;
    ELSEIF v_estado != 'activo' THEN
        SET p_resultado = 'Usuario inactivo';
        SET p_id_usuario = 0;
        SET p_token_sesion = NULL;
    ELSEIF v_bloqueado = TRUE THEN
        SET p_resultado = 'Usuario bloqueado';
        SET p_id_usuario = 0;
        SET p_token_sesion = NULL;
    ELSEIF v_password_hash != p_password_hash THEN
        -- Incrementar intentos fallidos
        UPDATE usuarios 
        SET intentos_fallidos = intentos_fallidos + 1,
            bloqueado = (intentos_fallidos + 1 >= 5)
        WHERE id_usuario = v_id_usuario;
        
        SET p_resultado = 'Contraseña incorrecta';
        SET p_id_usuario = 0;
        SET p_token_sesion = NULL;
        
        -- Log de intento fallido
        INSERT INTO log_actividades (id_usuario, accion, modulo, detalle, ip_address)
        VALUES (v_id_usuario, 'LOGIN_FALLIDO', 'autenticacion', 'Intento de login fallido', p_ip_address);
    ELSE
        -- Login exitoso
        SET p_token_sesion = UUID();
        SET p_id_usuario = v_id_usuario;
        SET p_resultado = 'Login exitoso';
        
        -- Resetear intentos fallidos y actualizar último login
        UPDATE usuarios 
        SET intentos_fallidos = 0,
            fecha_ultimo_login = CURRENT_TIMESTAMP,
            primer_login = FALSE
        WHERE id_usuario = v_id_usuario;
        
        -- Crear sesión
        INSERT INTO sesiones (id_usuario, token_sesion, ip_address)
        VALUES (v_id_usuario, p_token_sesion, p_ip_address);
        
        -- Log de login exitoso
        INSERT INTO log_actividades (id_usuario, accion, modulo, detalle, ip_address)
        VALUES (v_id_usuario, 'LOGIN_EXITOSO', 'autenticacion', 'Login exitoso', p_ip_address);
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `calcular_bono14` (IN `p_id_empleado` INT, IN `p_año` INT)   BEGIN
    DECLARE v_salario_promedio DECIMAL(10,2);
    DECLARE v_meses_trabajados INT;
    DECLARE v_monto_bono DECIMAL(10,2);
    DECLARE v_fecha_ingreso DATE;
    
    -- Obtener fecha de ingreso
    SELECT fecha_ingreso INTO v_fecha_ingreso 
    FROM empleados 
    WHERE id_empleado = p_id_empleado;
    
    -- Calcular meses trabajados en el año
    SET v_meses_trabajados = 12;
    IF YEAR(v_fecha_ingreso) = p_año THEN
        SET v_meses_trabajados = 13 - MONTH(v_fecha_ingreso);
    END IF;
    
    -- Calcular salario promedio de los últimos 12 meses
    SELECT AVG(salario_ordinario + bonificacion_decreto) INTO v_salario_promedio
    FROM nomina 
    WHERE id_empleado = p_id_empleado 
      AND (año = p_año OR (año = p_año - 1 AND mes >= 7))
      AND año <= p_año;
    
    -- Calcular monto proporcional
    SET v_monto_bono = v_salario_promedio * (v_meses_trabajados / 12);
    
    -- Insertar o actualizar registro de bono 14
    INSERT INTO bono_14 (id_empleado, año, salario_promedio, meses_trabajados, monto_bono, fecha_calculo)
    VALUES (p_id_empleado, p_año, v_salario_promedio, v_meses_trabajados, v_monto_bono, CURRENT_DATE)
    ON DUPLICATE KEY UPDATE 
        salario_promedio = v_salario_promedio,
        meses_trabajados = v_meses_trabajados,
        monto_bono = v_monto_bono,
        fecha_calculo = CURRENT_DATE;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `calcular_igss_empleado` (IN `p_salario_base` DECIMAL(10,2), IN `p_bonificacion` DECIMAL(10,2), OUT `p_igss_empleado` DECIMAL(10,2))   BEGIN
    DECLARE salario_total DECIMAL(10,2);
    SET salario_total = p_salario_base + p_bonificacion;
    SET p_igss_empleado = salario_total * 0.0483;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `crear_usuario` (IN `p_username` VARCHAR(50), IN `p_email` VARCHAR(100), IN `p_password_hash` VARCHAR(255), IN `p_id_empleado` INT, IN `p_id_rol` INT, OUT `p_resultado` VARCHAR(100))   BEGIN
    DECLARE v_existe_username INT DEFAULT 0;
    DECLARE v_existe_email INT DEFAULT 0;
    DECLARE v_existe_empleado INT DEFAULT 0;
    
    -- Verificar si ya existe el username
    SELECT COUNT(*) INTO v_existe_username FROM usuarios WHERE username = p_username;
    
    -- Verificar si ya existe el email
    SELECT COUNT(*) INTO v_existe_email FROM usuarios WHERE email = p_email;
    
    -- Verificar si el empleado ya tiene usuario
    IF p_id_empleado IS NOT NULL THEN
        SELECT COUNT(*) INTO v_existe_empleado FROM usuarios WHERE id_empleado = p_id_empleado;
    END IF;
    
    IF v_existe_username > 0 THEN
        SET p_resultado = 'ERROR: Ya existe un usuario con ese username';
    ELSEIF v_existe_email > 0 THEN
        SET p_resultado = 'ERROR: Ya existe un usuario con ese email';
    ELSEIF v_existe_empleado > 0 THEN
        SET p_resultado = 'ERROR: El empleado ya tiene un usuario asignado';
    ELSE
        INSERT INTO usuarios (username, email, password_hash, id_empleado, id_rol)
        VALUES (p_username, p_email, p_password_hash, p_id_empleado, p_id_rol);
        
        SET p_resultado = 'Usuario creado exitosamente';
        
        -- Registrar actividad
        INSERT INTO log_actividades (id_usuario, accion, modulo, detalle)
        VALUES (LAST_INSERT_ID(), 'CREAR_USUARIO', 'usuarios', CONCAT('Usuario creado: ', p_username));
    END IF;
END$$

--
-- Funciones
--
CREATE DEFINER=`root`@`localhost` FUNCTION `calcular_años_servicio` (`fecha_ingreso` DATE, `fecha_calculo` DATE) RETURNS DECIMAL(4,2) DETERMINISTIC READS SQL DATA BEGIN
    RETURN DATEDIFF(fecha_calculo, fecha_ingreso) / 365.25;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `verificar_permiso` (`p_username` VARCHAR(50), `p_modulo` VARCHAR(50), `p_accion` VARCHAR(30)) RETURNS TINYINT(1) DETERMINISTIC READS SQL DATA BEGIN
    DECLARE v_count INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_count
    FROM v_permisos_usuario
    WHERE username = p_username 
      AND modulo = p_modulo 
      AND accion = p_accion;
    
    RETURN v_count > 0;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `aguinaldo`
--

CREATE TABLE `aguinaldo` (
  `id_aguinaldo` int(11) NOT NULL,
  `id_empleado` int(11) NOT NULL,
  `año` int(11) NOT NULL,
  `salario_promedio` decimal(10,2) NOT NULL,
  `meses_trabajados` int(11) NOT NULL,
  `monto_aguinaldo` decimal(10,2) NOT NULL,
  `fecha_calculo` date NOT NULL,
  `fecha_pago` date DEFAULT NULL,
  `estado` enum('calculado','pagado') DEFAULT 'calculado',
  `observaciones` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `asistencia`
--

CREATE TABLE `asistencia` (
  `id_asistencia` int(11) NOT NULL,
  `id_empleado` int(11) NOT NULL,
  `fecha` date NOT NULL,
  `hora_entrada` time DEFAULT NULL,
  `hora_salida` time DEFAULT NULL,
  `horas_trabajadas` decimal(4,2) DEFAULT NULL,
  `horas_extra` decimal(4,2) DEFAULT 0.00,
  `observaciones` text DEFAULT NULL,
  `estado` enum('presente','ausente','tardanza','permiso','vacaciones','enfermedad') DEFAULT 'presente',
  `fecha_registro` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `asistencia`
--

INSERT INTO `asistencia` (`id_asistencia`, `id_empleado`, `fecha`, `hora_entrada`, `hora_salida`, `horas_trabajadas`, `horas_extra`, `observaciones`, `estado`, `fecha_registro`) VALUES
(1, 1, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(2, 2, '2025-06-10', '08:05:00', '17:00:00', 8.00, 0.00, NULL, 'tardanza', '2025-06-17 23:00:24'),
(3, 3, '2025-06-10', NULL, NULL, NULL, 0.00, NULL, 'ausente', '2025-06-17 23:00:24'),
(4, 4, '2025-06-10', '08:00:00', '18:00:00', 9.00, 1.00, NULL, 'presente', '2025-06-17 23:00:24'),
(5, 5, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(6, 6, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(7, 7, '2025-06-10', '08:10:00', '17:00:00', 7.83, 0.00, NULL, 'tardanza', '2025-06-17 23:00:24'),
(8, 8, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(9, 9, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(10, 10, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(11, 11, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(12, 12, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(13, 13, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(14, 14, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24'),
(15, 15, '2025-06-10', '08:00:00', '17:00:00', 8.00, 0.00, NULL, 'presente', '2025-06-17 23:00:24');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `bono_14`
--

CREATE TABLE `bono_14` (
  `id_bono14` int(11) NOT NULL,
  `id_empleado` int(11) NOT NULL,
  `año` int(11) NOT NULL,
  `salario_promedio` decimal(10,2) NOT NULL,
  `meses_trabajados` int(11) NOT NULL,
  `monto_bono` decimal(10,2) NOT NULL,
  `fecha_calculo` date NOT NULL,
  `fecha_pago` date DEFAULT NULL,
  `estado` enum('calculado','pagado') DEFAULT 'calculado',
  `observaciones` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `departamentos`
--

CREATE TABLE `departamentos` (
  `id_departamento` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `jefe_departamento` int(11) DEFAULT NULL,
  `estado` enum('activo','inactivo') DEFAULT 'activo',
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `departamentos`
--

INSERT INTO `departamentos` (`id_departamento`, `nombre`, `descripcion`, `jefe_departamento`, `estado`, `fecha_creacion`) VALUES
(1, 'Recursos Humanos', 'Gestión del talento humano', NULL, 'activo', '2025-06-16 20:52:42'),
(2, 'Contabilidad', 'Gestión financiera y contable', NULL, 'activo', '2025-06-16 20:52:42'),
(3, 'Ventas', 'Departamento comercial', NULL, 'activo', '2025-06-16 20:52:42'),
(4, 'Sistemas', 'Tecnología de la información', NULL, 'activo', '2025-06-16 20:52:42'),
(5, 'Producción', 'Área operativa de producción', NULL, 'activo', '2025-06-16 20:52:42'),
(6, 'Marketing', 'Promoción y publicidad de productos', NULL, 'activo', '2025-06-17 22:59:49'),
(7, 'Logística', 'Gestión de inventarios y distribución', NULL, 'activo', '2025-06-17 22:59:49'),
(8, 'Servicio al Cliente', 'Atención postventa y soporte técnico', NULL, 'activo', '2025-06-17 22:59:49'),
(9, 'Calidad', 'Control y aseguramiento de calidad', NULL, 'activo', '2025-06-17 22:59:49'),
(10, 'Innovación', 'Desarrollo de nuevos productos y servicios', NULL, 'activo', '2025-06-17 22:59:49');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `empleados`
--

CREATE TABLE `empleados` (
  `id_empleado` int(11) NOT NULL,
  `codigo_empleado` varchar(20) NOT NULL,
  `nombres` varchar(100) NOT NULL,
  `apellidos` varchar(100) NOT NULL,
  `dpi` varchar(20) NOT NULL,
  `nit` varchar(15) DEFAULT NULL,
  `telefono` varchar(15) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `direccion` text DEFAULT NULL,
  `fecha_nacimiento` date DEFAULT NULL,
  `sexo` enum('M','F') DEFAULT NULL,
  `estado_civil` enum('soltero','casado','divorciado','viudo','union_hecho') DEFAULT NULL,
  `numero_igss` varchar(20) DEFAULT NULL,
  `numero_irtra` varchar(20) DEFAULT NULL,
  `numero_cuenta_bancaria` varchar(30) DEFAULT NULL,
  `banco` varchar(50) DEFAULT NULL,
  `id_puesto` int(11) DEFAULT NULL,
  `fecha_ingreso` date NOT NULL,
  `fecha_salida` date DEFAULT NULL,
  `salario_base` decimal(10,2) NOT NULL,
  `bonificacion_decreto` decimal(10,2) DEFAULT 250.00,
  `estado` enum('activo','inactivo','suspendido','finiquitado') DEFAULT 'activo',
  `foto` blob DEFAULT NULL,
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp(),
  `fecha_modificacion` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `empleados`
--

INSERT INTO `empleados` (`id_empleado`, `codigo_empleado`, `nombres`, `apellidos`, `dpi`, `nit`, `telefono`, `email`, `direccion`, `fecha_nacimiento`, `sexo`, `estado_civil`, `numero_igss`, `numero_irtra`, `numero_cuenta_bancaria`, `banco`, `id_puesto`, `fecha_ingreso`, `fecha_salida`, `salario_base`, `bonificacion_decreto`, `estado`, `foto`, `fecha_creacion`, `fecha_modificacion`) VALUES
(1, 'EMP001', 'Carlos', 'Pérez Pérez', '12345678901', '1234-5', '5555-1234', 'carlos.perez@example.com', 'Guatemala', '1985-05-10', 'M', 'casado', 'IGSS123456', 'IRTRA123', '1234567890', 'Banrural', 1, '2020-01-15', NULL, 12000.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(2, 'EMP002', 'María', 'López González', '23456789012', '2345-6', '5555-2345', 'maria.lopez@example.com', 'Guatemala', '1990-08-20', 'F', 'soltero', 'IGSS234567', 'IRTRA234', '2345678901', 'Banco Industrial', 2, '2018-03-22', NULL, 8500.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(3, 'EMP003', 'José', 'Martínez Rivera', '34567890123', '3456-7', '5555-3456', 'jose.martinez@example.com', 'Mixco', '1982-11-05', 'M', 'casado', 'IGSS345678', 'IRTRA345', '3456789012', 'G&T Continental', 3, '2019-07-10', NULL, 5000.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(4, 'EMP004', 'Ana', 'Santos Morales', '45678901234', '4567-8', '5555-4567', 'ana.santos@example.com', 'Villa Nueva', '1995-04-18', 'F', 'soltero', 'IGSS456789', 'IRTRA456', '4567890123', 'Banrural', 4, '2021-02-01', NULL, 6500.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(5, 'EMP005', 'Luis', 'Hernández López', '56789012345', '5678-9', '5555-5678', 'luis.hernandez@example.com', 'San Miguel Petapa', '1988-06-25', 'M', 'casado', 'IGSS567890', 'IRTRA567', '5678901234', 'Banco Industrial', 5, '2017-09-14', NULL, 4000.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(6, 'EMP006', 'Diana', 'Ramírez Soto', '67890123456', '6789-0', '5555-6789', 'diana.ramirez@example.com', 'Palín, Escuintla', '1992-10-12', 'F', 'divorciado', 'IGSS678901', 'IRTRA678', '6789012345', 'G&T Continental', 1, '2022-05-30', NULL, 13000.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(7, 'EMP007', 'Javier', 'Cruz Mendoza', '78901234567', '7890-1', '5555-7890', 'javier.cruz@example.com', 'Chimaltenango', '1980-01-30', 'M', 'casado', 'IGSS789012', 'IRTRA789', '7890123456', 'Banrural', 2, '2016-11-08', NULL, 9000.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(8, 'EMP008', 'Laura', 'Ortega Flores', '89012345678', '8901-2', '5555-8901', 'laura.ortega@example.com', 'Antigua Guatemala', '1993-03-03', 'F', 'soltero', 'IGSS890123', 'IRTRA890', '8901234567', 'Banco Industrial', 3, '2020-04-19', NULL, 4800.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(9, 'EMP009', 'Andrés', 'Ruiz Castillo', '90123456789', '9012-3', '5555-9012', 'andres.ruiz@example.com', 'Cobán, Alta Verapaz', '1987-09-17', 'M', 'casado', 'IGSS901234', 'IRTRA901', '9012345678', 'G&T Continental', 4, '2019-01-11', NULL, 6200.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(10, 'EMP010', 'Karen', 'Flores Domínguez', '01234567890', '0123-4', '5555-0123', 'karen.flores@example.com', 'Quetzaltenango', '1994-12-24', 'F', 'soltero', 'IGSS012345', 'IRTRA012', '0123456789', 'Banrural', 5, '2021-08-05', NULL, 3700.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(11, 'EMP011', 'Mario', 'Castro León', '12345678912', '1234-6', '5555-1235', 'mario.castro@example.com', 'Retalhuleu', '1983-07-09', 'M', 'casado', 'IGSS123457', 'IRTRA124', '1234567891', 'Banco Industrial', 1, '2018-10-17', NULL, 14000.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(12, 'EMP012', 'Claudia', 'Rojas Vargas', '23456789013', '2345-7', '5555-2346', 'claudia.rojas@example.com', 'Puerto Barrios', '1991-02-14', 'F', 'soltero', 'IGSS234568', 'IRTRA235', '2345678902', 'G&T Continental', 2, '2020-06-01', NULL, 8200.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(13, 'EMP013', 'Diego', 'Sánchez Ortiz', '34567890124', '3456-8', '5555-3457', 'diego.sanchez@example.com', 'Zacatecoluca', '1986-04-30', 'M', 'casado', 'IGSS345679', 'IRTRA346', '3456789013', 'Banrural', 3, '2017-12-12', NULL, 4900.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(14, 'EMP014', 'Gabriela', 'Navarro Mendoza', '45678901235', '4567-9', '5555-4568', 'gabriela.navarro@example.com', 'Tecún Umán', '1996-09-05', 'F', 'soltero', 'IGSS456780', 'IRTRA457', '4567890124', 'Banco Industrial', 4, '2022-01-20', NULL, 6300.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30'),
(15, 'EMP015', 'Oscar', 'Méndez Ramírez', '56789012346', '5678-0', '5555-5679', 'oscar.mendez@example.com', 'Flores', '1989-11-13', 'M', 'casado', 'IGSS567891', 'IRTRA568', '5678901235', 'G&T Continental', 5, '2019-05-25', NULL, 3600.00, 250.00, 'activo', NULL, '2025-06-17 22:59:30', '2025-06-17 22:59:30');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `indemnizaciones`
--

CREATE TABLE `indemnizaciones` (
  `id_indemnizacion` int(11) NOT NULL,
  `id_empleado` int(11) NOT NULL,
  `tipo_indemnizacion` enum('despido_injustificado','renuncia_indirecta','muerte','incapacidad') NOT NULL,
  `años_servicio` decimal(4,2) NOT NULL,
  `salario_base` decimal(10,2) NOT NULL,
  `monto_indemnizacion` decimal(10,2) NOT NULL,
  `fecha_calculo` date NOT NULL,
  `fecha_pago` date DEFAULT NULL,
  `motivo` text DEFAULT NULL,
  `estado` enum('calculada','pagada') DEFAULT 'calculada'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `log_actividades`
--

CREATE TABLE `log_actividades` (
  `id_log` int(11) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `accion` varchar(100) NOT NULL,
  `modulo` varchar(50) NOT NULL,
  `detalle` text DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `fecha_accion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `nomina`
--

CREATE TABLE `nomina` (
  `id_nomina` int(11) NOT NULL,
  `id_empleado` int(11) NOT NULL,
  `mes` int(11) NOT NULL,
  `año` int(11) NOT NULL,
  `dias_trabajados` int(11) NOT NULL,
  `horas_trabajadas` decimal(6,2) DEFAULT NULL,
  `horas_extra` decimal(6,2) DEFAULT 0.00,
  `salario_ordinario` decimal(10,2) NOT NULL,
  `bonificacion_decreto` decimal(10,2) DEFAULT 250.00,
  `horas_extra_pago` decimal(10,2) DEFAULT 0.00,
  `comisiones` decimal(10,2) DEFAULT 0.00,
  `bonos_adicionales` decimal(10,2) DEFAULT 0.00,
  `total_ingresos` decimal(10,2) NOT NULL,
  `igss_empleado` decimal(10,2) DEFAULT 0.00,
  `isr` decimal(10,2) DEFAULT 0.00,
  `otras_deducciones` decimal(10,2) DEFAULT 0.00,
  `total_deducciones` decimal(10,2) DEFAULT 0.00,
  `igss_patronal` decimal(10,2) DEFAULT 0.00,
  `irtra` decimal(10,2) DEFAULT 0.00,
  `intecap` decimal(10,2) DEFAULT 0.00,
  `salario_liquido` decimal(10,2) NOT NULL,
  `estado` enum('borrador','calculado','pagado') DEFAULT 'borrador',
  `fecha_calculo` timestamp NOT NULL DEFAULT current_timestamp(),
  `fecha_pago` timestamp NULL DEFAULT NULL,
  `observaciones` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `permisos`
--

CREATE TABLE `permisos` (
  `id_permiso` int(11) NOT NULL,
  `id_empleado` int(11) NOT NULL,
  `id_tipo_permiso` int(11) NOT NULL,
  `fecha_solicitud` date NOT NULL,
  `fecha_inicio` date NOT NULL,
  `fecha_fin` date NOT NULL,
  `dias_solicitados` int(11) NOT NULL,
  `motivo` text NOT NULL,
  `documento_respaldo` varchar(255) DEFAULT NULL,
  `estado` enum('pendiente','aprobado','rechazado') DEFAULT 'pendiente',
  `aprobado_por` int(11) DEFAULT NULL,
  `fecha_aprobacion` timestamp NULL DEFAULT NULL,
  `observaciones` text DEFAULT NULL,
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `puestos`
--

CREATE TABLE `puestos` (
  `id_puesto` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `salario_base` decimal(10,2) NOT NULL,
  `id_departamento` int(11) DEFAULT NULL,
  `estado` enum('activo','inactivo') DEFAULT 'activo',
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `puestos`
--

INSERT INTO `puestos` (`id_puesto`, `nombre`, `descripcion`, `salario_base`, `id_departamento`, `estado`, `fecha_creacion`) VALUES
(1, 'Gerente General', 'Dirección general de la empresa', 15000.00, 1, 'activo', '2025-06-16 20:52:42'),
(2, 'Contador General', 'Responsable del área contable', 8000.00, 2, 'activo', '2025-06-16 20:52:42'),
(3, 'Vendedor', 'Ejecutivo de ventas', 4000.00, 3, 'activo', '2025-06-16 20:52:42'),
(4, 'Desarrollador', 'Programador de sistemas', 6000.00, 4, 'activo', '2025-06-16 20:52:42'),
(5, 'Operario', 'Trabajador de producción', 3500.00, 5, 'activo', '2025-06-16 20:52:42');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `roles`
--

CREATE TABLE `roles` (
  `id_rol` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `nivel_acceso` int(11) NOT NULL,
  `estado` enum('activo','inactivo') DEFAULT 'activo',
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `roles`
--

INSERT INTO `roles` (`id_rol`, `nombre`, `descripcion`, `nivel_acceso`, `estado`, `fecha_creacion`) VALUES
(1, 'Superadmin', 'Acceso total al sistema, configuración y administración', 5, 'activo', '2025-06-16 20:52:42'),
(2, 'Administrador RRHH', 'Gestión completa de recursos humanos', 4, 'activo', '2025-06-16 20:52:42'),
(3, 'Jefe de Departamento', 'Gestión de empleados de su departamento', 3, 'activo', '2025-06-16 20:52:42'),
(4, 'Supervisor', 'Supervisión y aprobación de solicitudes', 2, 'activo', '2025-06-16 20:52:42'),
(5, 'Empleado', 'Acceso básico para consultas personales', 1, 'activo', '2025-06-16 20:52:42'),
(6, 'Contador', 'Acceso a nóminas y reportes financieros', 3, 'activo', '2025-06-16 20:52:42'),
(7, 'Recepcionista', 'Registro de asistencia y consultas básicas', 2, 'activo', '2025-06-16 20:52:42');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `rol_permisos`
--

CREATE TABLE `rol_permisos` (
  `id_rol_permiso` int(11) NOT NULL,
  `id_rol` int(11) NOT NULL,
  `id_permiso` int(11) NOT NULL,
  `fecha_asignacion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `sesiones`
--

CREATE TABLE `sesiones` (
  `id_sesion` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `token_sesion` varchar(255) NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text DEFAULT NULL,
  `fecha_inicio` timestamp NOT NULL DEFAULT current_timestamp(),
  `fecha_ultimo_acceso` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `activa` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `suspensiones`
--

CREATE TABLE `suspensiones` (
  `id_suspension` int(11) NOT NULL,
  `id_empleado` int(11) NOT NULL,
  `tipo_suspension` enum('igss_enfermedad','igss_maternidad','disciplinaria','administrativa') NOT NULL,
  `fecha_inicio` date NOT NULL,
  `fecha_fin` date DEFAULT NULL,
  `motivo` text NOT NULL,
  `numero_documento_igss` varchar(50) DEFAULT NULL,
  `porcentaje_pago` decimal(5,2) DEFAULT 0.00,
  `estado` enum('activo','finalizado','cancelado') DEFAULT 'activo',
  `observaciones` text DEFAULT NULL,
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipos_bonificaciones`
--

CREATE TABLE `tipos_bonificaciones` (
  `id_tipo_bonificacion` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `formula_calculo` text DEFAULT NULL,
  `periodo` enum('mensual','anual','unico') DEFAULT 'mensual',
  `obligatoria` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `tipos_bonificaciones`
--

INSERT INTO `tipos_bonificaciones` (`id_tipo_bonificacion`, `nombre`, `descripcion`, `formula_calculo`, `periodo`, `obligatoria`) VALUES
(1, 'Bonificación Decreto 37-2001', 'Bonificación mensual según decreto', NULL, 'mensual', 1),
(2, 'Bono 14', 'Bono anual equivalente a salario promedio', NULL, 'anual', 1),
(3, 'Aguinaldo', 'Bono navideño equivalente a salario promedio', NULL, 'anual', 1),
(4, 'Comisiones', 'Comisiones por ventas', NULL, 'mensual', 0),
(5, 'Bono por Desempeño', 'Bono por cumplimiento de objetivos', NULL, 'mensual', 0);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipos_deducciones`
--

CREATE TABLE `tipos_deducciones` (
  `id_tipo_deduccion` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `porcentaje` decimal(5,2) DEFAULT NULL,
  `monto_fijo` decimal(10,2) DEFAULT NULL,
  `base_calculo` enum('salario_ordinario','salario_total','monto_fijo') DEFAULT 'salario_ordinario',
  `obligatoria` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `tipos_deducciones`
--

INSERT INTO `tipos_deducciones` (`id_tipo_deduccion`, `nombre`, `descripcion`, `porcentaje`, `monto_fijo`, `base_calculo`, `obligatoria`) VALUES
(1, 'IGSS Empleado', 'Aporte empleado al IGSS', 4.83, NULL, 'salario_ordinario', 1),
(2, 'ISR', 'Impuesto Sobre la Renta', NULL, NULL, 'salario_ordinario', 1),
(3, 'Préstamo Personal', 'Descuento por préstamo personal', NULL, NULL, 'salario_ordinario', 0),
(4, 'Seguro Médico Privado', 'Seguro médico privado', NULL, NULL, 'salario_ordinario', 0);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipos_permisos`
--

CREATE TABLE `tipos_permisos` (
  `id_tipo_permiso` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `requiere_justificacion` tinyint(1) DEFAULT 0,
  `dias_maximos` int(11) DEFAULT NULL,
  `remunerado` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `tipos_permisos`
--

INSERT INTO `tipos_permisos` (`id_tipo_permiso`, `nombre`, `descripcion`, `requiere_justificacion`, `dias_maximos`, `remunerado`) VALUES
(1, 'IGSS - Cita médica', 'Permiso para asistir a cita médica en IGSS', 1, 1, 1),
(2, 'IGSS - Enfermedad', 'Permiso por enfermedad con certificado IGSS', 1, NULL, 0),
(3, 'IGSS - Maternidad', 'Permiso por maternidad', 1, 84, 1),
(4, 'Personal', 'Permiso personal con o sin goce de salario', 1, 3, 0),
(5, 'Luto', 'Permiso por fallecimiento familiar', 1, 3, 1),
(6, 'Matrimonio', 'Permiso por matrimonio propio', 1, 5, 1),
(7, 'Paternidad', 'Permiso por paternidad', 1, 2, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id_usuario` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `id_empleado` int(11) DEFAULT NULL,
  `id_rol` int(11) NOT NULL,
  `primer_login` tinyint(1) DEFAULT 1,
  `debe_cambiar_password` tinyint(1) DEFAULT 1,
  `intentos_fallidos` int(11) DEFAULT 0,
  `bloqueado` tinyint(1) DEFAULT 0,
  `fecha_ultimo_login` timestamp NULL DEFAULT NULL,
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp(),
  `fecha_modificacion` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `estado` enum('activo','inactivo','bloqueado','pendiente') DEFAULT 'pendiente',
  `token_recuperacion` varchar(255) DEFAULT NULL,
  `fecha_expiracion_token` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `username`, `email`, `password_hash`, `id_empleado`, `id_rol`, `primer_login`, `debe_cambiar_password`, `intentos_fallidos`, `bloqueado`, `fecha_ultimo_login`, `fecha_creacion`, `fecha_modificacion`, `estado`, `token_recuperacion`, `fecha_expiracion_token`) VALUES
(2, 'carlos.perez', 'carlos.perez@example.com', '$2y$10$9q7SGlwGjmULY6Di9E0BZOrO9ye0PUA.w/St8VD1g7J5UzX.uefWu', 1, 1, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:03:29', 'activo', NULL, NULL),
(3, 'maria.lopez', 'maria.lopez@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 2, 2, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(4, 'jose.martinez', 'jose.martinez@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 3, 3, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(5, 'ana.santos', 'ana.santos@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 4, 4, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(6, 'luis.hernandez', 'luis.hernandez@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 5, 5, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(7, 'diana.ramirez', 'diana.ramirez@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 6, 6, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(8, 'javier.cruz', 'javier.cruz@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 7, 7, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(9, 'laura.ortega', 'laura.ortega@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 8, 1, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(10, 'andres.ruiz', 'andres.ruiz@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 9, 2, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(11, 'karen.flores', 'karen.flores@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 10, 3, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(12, 'mario.castro', 'mario.castro@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 11, 4, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(13, 'claudia.rojas', 'claudia.rojas@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 12, 5, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(14, 'diego.sanchez', 'diego.sanchez@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 13, 6, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(15, 'gabriela.navarro', 'gabriela.navarro@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 14, 7, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL),
(16, 'oscar.mendez', 'oscar.mendez@example.com', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 15, 1, 1, 1, 0, 0, NULL, '2025-06-17 23:00:04', '2025-06-17 23:00:04', 'activo', NULL, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `vacaciones`
--

CREATE TABLE `vacaciones` (
  `id_vacacion` int(11) NOT NULL,
  `id_empleado` int(11) NOT NULL,
  `periodo_inicio` date NOT NULL,
  `periodo_fin` date NOT NULL,
  `dias_ganados` int(11) NOT NULL DEFAULT 15,
  `dias_tomados` int(11) DEFAULT 0,
  `dias_pendientes` int(11) NOT NULL DEFAULT 15,
  `fecha_inicio_vacacion` date DEFAULT NULL,
  `fecha_fin_vacacion` date DEFAULT NULL,
  `estado` enum('pendiente','en_curso','completado','cancelado') DEFAULT 'pendiente',
  `observaciones` text DEFAULT NULL,
  `fecha_creacion` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_asistencia_mensual`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_asistencia_mensual` (
`id_empleado` int(11)
,`empleado` varchar(201)
,`año` int(4)
,`mes` int(2)
,`dias_registrados` bigint(21)
,`dias_presente` decimal(22,0)
,`dias_ausente` decimal(22,0)
,`dias_permiso` decimal(22,0)
,`total_horas_trabajadas` decimal(26,2)
,`total_horas_extra` decimal(26,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_empleados_activos`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_empleados_activos` (
`id_empleado` int(11)
,`codigo_empleado` varchar(20)
,`nombre_completo` varchar(201)
,`dpi` varchar(20)
,`numero_igss` varchar(20)
,`puesto` varchar(100)
,`departamento` varchar(100)
,`salario_base` decimal(10,2)
,`bonificacion_decreto` decimal(10,2)
,`fecha_ingreso` date
,`años_servicio` decimal(12,4)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_usuarios_completo`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_usuarios_completo` (
`id_usuario` int(11)
,`username` varchar(50)
,`email` varchar(100)
,`estado_usuario` enum('activo','inactivo','bloqueado','pendiente')
,`fecha_ultimo_login` timestamp
,`intentos_fallidos` int(11)
,`bloqueado` tinyint(1)
,`rol` varchar(50)
,`nivel_acceso` int(11)
,`nombre_empleado` varchar(201)
,`codigo_empleado` varchar(20)
,`departamento` varchar(100)
);

-- --------------------------------------------------------

--
-- Estructura para la vista `v_asistencia_mensual`
--
DROP TABLE IF EXISTS `v_asistencia_mensual`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_asistencia_mensual`  AS SELECT `a`.`id_empleado` AS `id_empleado`, concat(`e`.`nombres`,' ',`e`.`apellidos`) AS `empleado`, year(`a`.`fecha`) AS `año`, month(`a`.`fecha`) AS `mes`, count(0) AS `dias_registrados`, sum(case when `a`.`estado` = 'presente' then 1 else 0 end) AS `dias_presente`, sum(case when `a`.`estado` = 'ausente' then 1 else 0 end) AS `dias_ausente`, sum(case when `a`.`estado` = 'permiso' then 1 else 0 end) AS `dias_permiso`, sum(`a`.`horas_trabajadas`) AS `total_horas_trabajadas`, sum(`a`.`horas_extra`) AS `total_horas_extra` FROM (`asistencia` `a` join `empleados` `e` on(`a`.`id_empleado` = `e`.`id_empleado`)) GROUP BY `a`.`id_empleado`, year(`a`.`fecha`), month(`a`.`fecha`) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_empleados_activos`
--
DROP TABLE IF EXISTS `v_empleados_activos`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_empleados_activos`  AS SELECT `e`.`id_empleado` AS `id_empleado`, `e`.`codigo_empleado` AS `codigo_empleado`, concat(`e`.`nombres`,' ',`e`.`apellidos`) AS `nombre_completo`, `e`.`dpi` AS `dpi`, `e`.`numero_igss` AS `numero_igss`, `p`.`nombre` AS `puesto`, `d`.`nombre` AS `departamento`, `e`.`salario_base` AS `salario_base`, `e`.`bonificacion_decreto` AS `bonificacion_decreto`, `e`.`fecha_ingreso` AS `fecha_ingreso`, (to_days(curdate()) - to_days(`e`.`fecha_ingreso`)) / 365.25 AS `años_servicio` FROM ((`empleados` `e` left join `puestos` `p` on(`e`.`id_puesto` = `p`.`id_puesto`)) left join `departamentos` `d` on(`p`.`id_departamento` = `d`.`id_departamento`)) WHERE `e`.`estado` = 'activo' ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_usuarios_completo`
--
DROP TABLE IF EXISTS `v_usuarios_completo`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_usuarios_completo`  AS SELECT `u`.`id_usuario` AS `id_usuario`, `u`.`username` AS `username`, `u`.`email` AS `email`, `u`.`estado` AS `estado_usuario`, `u`.`fecha_ultimo_login` AS `fecha_ultimo_login`, `u`.`intentos_fallidos` AS `intentos_fallidos`, `u`.`bloqueado` AS `bloqueado`, `r`.`nombre` AS `rol`, `r`.`nivel_acceso` AS `nivel_acceso`, concat(`e`.`nombres`,' ',`e`.`apellidos`) AS `nombre_empleado`, `e`.`codigo_empleado` AS `codigo_empleado`, `d`.`nombre` AS `departamento` FROM ((((`usuarios` `u` join `roles` `r` on(`u`.`id_rol` = `r`.`id_rol`)) left join `empleados` `e` on(`u`.`id_empleado` = `e`.`id_empleado`)) left join `puestos` `p` on(`e`.`id_puesto` = `p`.`id_puesto`)) left join `departamentos` `d` on(`p`.`id_departamento` = `d`.`id_departamento`)) ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `aguinaldo`
--
ALTER TABLE `aguinaldo`
  ADD PRIMARY KEY (`id_aguinaldo`),
  ADD UNIQUE KEY `unique_empleado_año_aguinaldo` (`id_empleado`,`año`);

--
-- Indices de la tabla `asistencia`
--
ALTER TABLE `asistencia`
  ADD PRIMARY KEY (`id_asistencia`),
  ADD UNIQUE KEY `unique_empleado_fecha` (`id_empleado`,`fecha`),
  ADD KEY `idx_asistencia_fecha` (`fecha`);

--
-- Indices de la tabla `bono_14`
--
ALTER TABLE `bono_14`
  ADD PRIMARY KEY (`id_bono14`),
  ADD UNIQUE KEY `unique_empleado_año_bono14` (`id_empleado`,`año`);

--
-- Indices de la tabla `departamentos`
--
ALTER TABLE `departamentos`
  ADD PRIMARY KEY (`id_departamento`);

--
-- Indices de la tabla `empleados`
--
ALTER TABLE `empleados`
  ADD PRIMARY KEY (`id_empleado`),
  ADD UNIQUE KEY `codigo_empleado` (`codigo_empleado`),
  ADD UNIQUE KEY `dpi` (`dpi`),
  ADD KEY `id_puesto` (`id_puesto`),
  ADD KEY `idx_empleados_estado` (`estado`),
  ADD KEY `idx_empleados_fecha_ingreso` (`fecha_ingreso`);

--
-- Indices de la tabla `indemnizaciones`
--
ALTER TABLE `indemnizaciones`
  ADD PRIMARY KEY (`id_indemnizacion`),
  ADD KEY `id_empleado` (`id_empleado`);

--
-- Indices de la tabla `log_actividades`
--
ALTER TABLE `log_actividades`
  ADD PRIMARY KEY (`id_log`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `nomina`
--
ALTER TABLE `nomina`
  ADD PRIMARY KEY (`id_nomina`),
  ADD UNIQUE KEY `unique_empleado_periodo` (`id_empleado`,`mes`,`año`);

--
-- Indices de la tabla `permisos`
--
ALTER TABLE `permisos`
  ADD PRIMARY KEY (`id_permiso`),
  ADD KEY `id_empleado` (`id_empleado`),
  ADD KEY `id_tipo_permiso` (`id_tipo_permiso`),
  ADD KEY `aprobado_por` (`aprobado_por`);

--
-- Indices de la tabla `puestos`
--
ALTER TABLE `puestos`
  ADD PRIMARY KEY (`id_puesto`),
  ADD KEY `id_departamento` (`id_departamento`);

--
-- Indices de la tabla `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id_rol`),
  ADD UNIQUE KEY `nombre` (`nombre`);

--
-- Indices de la tabla `rol_permisos`
--
ALTER TABLE `rol_permisos`
  ADD PRIMARY KEY (`id_rol_permiso`),
  ADD UNIQUE KEY `unique_rol_permiso` (`id_rol`,`id_permiso`),
  ADD KEY `id_permiso` (`id_permiso`);

--
-- Indices de la tabla `sesiones`
--
ALTER TABLE `sesiones`
  ADD PRIMARY KEY (`id_sesion`),
  ADD UNIQUE KEY `token_sesion` (`token_sesion`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `suspensiones`
--
ALTER TABLE `suspensiones`
  ADD PRIMARY KEY (`id_suspension`),
  ADD KEY `id_empleado` (`id_empleado`);

--
-- Indices de la tabla `tipos_bonificaciones`
--
ALTER TABLE `tipos_bonificaciones`
  ADD PRIMARY KEY (`id_tipo_bonificacion`);

--
-- Indices de la tabla `tipos_deducciones`
--
ALTER TABLE `tipos_deducciones`
  ADD PRIMARY KEY (`id_tipo_deduccion`);

--
-- Indices de la tabla `tipos_permisos`
--
ALTER TABLE `tipos_permisos`
  ADD PRIMARY KEY (`id_tipo_permiso`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `id_empleado` (`id_empleado`),
  ADD KEY `id_rol` (`id_rol`);

--
-- Indices de la tabla `vacaciones`
--
ALTER TABLE `vacaciones`
  ADD PRIMARY KEY (`id_vacacion`),
  ADD KEY `id_empleado` (`id_empleado`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `aguinaldo`
--
ALTER TABLE `aguinaldo`
  MODIFY `id_aguinaldo` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `asistencia`
--
ALTER TABLE `asistencia`
  MODIFY `id_asistencia` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT de la tabla `bono_14`
--
ALTER TABLE `bono_14`
  MODIFY `id_bono14` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `departamentos`
--
ALTER TABLE `departamentos`
  MODIFY `id_departamento` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `empleados`
--
ALTER TABLE `empleados`
  MODIFY `id_empleado` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT de la tabla `indemnizaciones`
--
ALTER TABLE `indemnizaciones`
  MODIFY `id_indemnizacion` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `log_actividades`
--
ALTER TABLE `log_actividades`
  MODIFY `id_log` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `nomina`
--
ALTER TABLE `nomina`
  MODIFY `id_nomina` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `permisos`
--
ALTER TABLE `permisos`
  MODIFY `id_permiso` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `puestos`
--
ALTER TABLE `puestos`
  MODIFY `id_puesto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `roles`
--
ALTER TABLE `roles`
  MODIFY `id_rol` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `rol_permisos`
--
ALTER TABLE `rol_permisos`
  MODIFY `id_rol_permiso` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `sesiones`
--
ALTER TABLE `sesiones`
  MODIFY `id_sesion` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `suspensiones`
--
ALTER TABLE `suspensiones`
  MODIFY `id_suspension` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `tipos_bonificaciones`
--
ALTER TABLE `tipos_bonificaciones`
  MODIFY `id_tipo_bonificacion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `tipos_deducciones`
--
ALTER TABLE `tipos_deducciones`
  MODIFY `id_tipo_deduccion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `tipos_permisos`
--
ALTER TABLE `tipos_permisos`
  MODIFY `id_tipo_permiso` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT de la tabla `vacaciones`
--
ALTER TABLE `vacaciones`
  MODIFY `id_vacacion` int(11) NOT NULL AUTO_INCREMENT;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `aguinaldo`
--
ALTER TABLE `aguinaldo`
  ADD CONSTRAINT `aguinaldo_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`);

--
-- Filtros para la tabla `asistencia`
--
ALTER TABLE `asistencia`
  ADD CONSTRAINT `asistencia_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`);

--
-- Filtros para la tabla `bono_14`
--
ALTER TABLE `bono_14`
  ADD CONSTRAINT `bono_14_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`);

--
-- Filtros para la tabla `empleados`
--
ALTER TABLE `empleados`
  ADD CONSTRAINT `empleados_ibfk_1` FOREIGN KEY (`id_puesto`) REFERENCES `puestos` (`id_puesto`);

--
-- Filtros para la tabla `indemnizaciones`
--
ALTER TABLE `indemnizaciones`
  ADD CONSTRAINT `indemnizaciones_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`);

--
-- Filtros para la tabla `log_actividades`
--
ALTER TABLE `log_actividades`
  ADD CONSTRAINT `log_actividades_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE SET NULL;

--
-- Filtros para la tabla `nomina`
--
ALTER TABLE `nomina`
  ADD CONSTRAINT `nomina_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`);

--
-- Filtros para la tabla `permisos`
--
ALTER TABLE `permisos`
  ADD CONSTRAINT `permisos_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`),
  ADD CONSTRAINT `permisos_ibfk_2` FOREIGN KEY (`id_tipo_permiso`) REFERENCES `tipos_permisos` (`id_tipo_permiso`),
  ADD CONSTRAINT `permisos_ibfk_3` FOREIGN KEY (`aprobado_por`) REFERENCES `empleados` (`id_empleado`);

--
-- Filtros para la tabla `puestos`
--
ALTER TABLE `puestos`
  ADD CONSTRAINT `puestos_ibfk_1` FOREIGN KEY (`id_departamento`) REFERENCES `departamentos` (`id_departamento`);

--
-- Filtros para la tabla `rol_permisos`
--
ALTER TABLE `rol_permisos`
  ADD CONSTRAINT `rol_permisos_ibfk_1` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`) ON DELETE CASCADE,
  ADD CONSTRAINT `rol_permisos_ibfk_2` FOREIGN KEY (`id_permiso`) REFERENCES `permisos` (`id_permiso`) ON DELETE CASCADE;

--
-- Filtros para la tabla `sesiones`
--
ALTER TABLE `sesiones`
  ADD CONSTRAINT `sesiones_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `suspensiones`
--
ALTER TABLE `suspensiones`
  ADD CONSTRAINT `suspensiones_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`);

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`) ON DELETE SET NULL,
  ADD CONSTRAINT `usuarios_ibfk_2` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`);

--
-- Filtros para la tabla `vacaciones`
--
ALTER TABLE `vacaciones`
  ADD CONSTRAINT `vacaciones_ibfk_1` FOREIGN KEY (`id_empleado`) REFERENCES `empleados` (`id_empleado`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
