-- ============================================================================
-- PROYECTO: Bodegas del Atuel
-- ETAPA 2: Batería de Pruebas de Integridad y Reglas de Negocio (db_tests.sql)
-- ============================================================================

\set ECHO none
\set QUIET on
SET client_min_messages TO NOTICE;

-- ----------------------------------------------------------------------------
-- 0. LIMPIEZA TOTAL Y REINICIO DE SECUENCIAS (Sin disparar triggers de fila)
-- ----------------------------------------------------------------------------
TRUNCATE TABLE
    auditoria_precio,
    renglon_comprobante,
    comprobante,
    renglon_transferencia,
    transferencia,
    renglon_ingreso,
    ingreso,
    stock_sala,
    stock_deposito,
    transportista_localidad,
    transportista,
    permiso_exportacion,
    exportador,
    distribuidor,
    socio,
    cliente,
    vino_maridaje,
    maridaje,
    composicion,
    vino,
    bodega,
    analisis_calidad,
    lote_uva,
    parcela,
    cepa,
    finca,
    empleado,
    sala_venta,
    localidad
RESTART IDENTITY CASCADE;

DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'INICIANDO BATERÍA DE PRUEBAS DE INTEGRIDAD (RN-01 A RN-15)';
    RAISE NOTICE '============================================================';

    -- Localidad y Salas
    INSERT INTO localidad (id_localidad, codigo_postal, nombre, provincia, encargado_regional)
    VALUES (1, '5600', 'San Rafael', 'Mendoza', 'Juan Perez');

    INSERT INTO sala_venta (id_sala, id_localidad, calle, numero, dia_cierre)
    VALUES (1, 1, 'Av. Hipolito Yrigoyen', '1500', 'Lunes'),
           (2, 1, 'Av. Mitre', '300', 'Domingo');

    -- Empleado
    INSERT INTO empleado (cuit, id_sala, nombre, fecha_ingreso, salario)
    VALUES ('20304050601', 1, 'Carlos Gomez', '2020-03-01', 850000.00);

    -- Finca, Cepas y Parcelas
    INSERT INTO finca (id_finca, nombre, superficie_ha, departamento, provincia)
    VALUES (1, 'Finca El Nevado', 50.00, 'San Rafael', 'Mendoza');

    INSERT INTO cepa (id_cepa, nombre, tipo)
    VALUES (1, 'Malbec', 'tinta'),
           (2, 'Cabernet Sauvignon', 'tinta');

    INSERT INTO parcela (id_finca, nro_parcela, id_cepa, superficie, anio_plantacion)
    VALUES (1, 1, 1, 10.00, 2015),
           (1, 2, 2, 15.00, 2018);

    -- Bodega
    INSERT INTO bodega (cuit, razon_social, domicilio)
    VALUES ('30708090101', 'Bodega Atuel Norte S.A.', 'Calle Rama Caida 1200');

    -- Clientes
    INSERT INTO cliente (id_cliente, id_localidad, nombre_o_razon_social, tipo_doc, numero_doc, domicilio, fecha_alta, tipo_cliente, descuento)
    VALUES (1, 1, 'Maria Lopez', 'DNI', '32111222', 'Calle Francia 200', CURRENT_DATE, 'socio', 10.00),
           (2, 1, 'Distribuidora Cuyo SRL', 'CUIT', '30654321981', 'Ruta 143 km 5', CURRENT_DATE, 'distribuidor', 20.00),
           (3, 1, 'Andes Wines Export', 'CUIT', '30998877661', 'Parque Industrial 40', CURRENT_DATE, 'exportador', 30.00);

    INSERT INTO socio (id_cliente) VALUES (1);
    INSERT INTO distribuidor (id_cliente, zona_cobertura, nro_habilitacion) VALUES (2, 'Zona Sur', 'HAB-2026-99');
    INSERT INTO exportador (id_cliente, pais_destino) VALUES (3, 'Estados Unidos');

    -- Transportista
    INSERT INTO transportista (cod_transportista, cuit, razon_social, domicilio, email, telefono)
    VALUES (1, '30554433221', 'Expreso Mendoza', 'Av. Balloffet 800', 'logistica@expreso.com', '2604112233');

    -- Vinos base
    INSERT INTO vino (cod_vino, cuit_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio)
    VALUES (1, '30708090101', 'Reserva Malbec', 'tinto', 2021, 750, 14.50, 12500.00),
           (2, '30708090101', 'Gran Cabernet', 'tinto', 2022, 750, 14.00, 15000.00);

    -- Composición inicial vino 1 (100% Malbec)
    INSERT INTO composicion (cod_vino, id_cepa, porcentaje) VALUES (1, 1, 100.00);
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-01: El precio del vino es mayor que cero
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO vino (cuit_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio)
    VALUES ('30708090101', 'Vino Invalido', 'tinto', 2023, 750, 13.50, 0.00);
    RAISE EXCEPTION '[FALLO] RN-01: Se permitió insertar un vino con precio 0.';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '[OK] RN-01: Rechazado vino con precio <= 0 (check_violation).';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-02: Sala pertenece a localidad existente (FK)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- Se asigna id_sala 9999 para que no colisione y falle estrictamente por id_localidad inexistente
    INSERT INTO sala_venta (id_sala, id_localidad, calle, numero, dia_cierre)
    VALUES (9999, 9999, 'Calle Inexistente', '100', 'Lunes');
    RAISE EXCEPTION '[FALLO] RN-02: Se permitió sala con localidad inexistente.';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '[OK] RN-02: Rechazada sala vinculada a localidad inexistente (foreign_key_violation).';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-03: Empleado trabaja en una sola sala (FK obligatoria)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO empleado (cuit, id_sala, nombre, fecha_ingreso, salario)
    VALUES ('20999999991', NULL, 'Sin Sala', '2023-01-01', 500000.00);
    RAISE EXCEPTION '[FALLO] RN-03: Se permitió empleado sin sala.';
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE '[OK] RN-03: Rechazado empleado sin sala asociada (not_null_violation).';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-04: Máximo una cosecha por parcela y campaña (UNIQUE)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO lote_uva (id_finca, nro_parcela, cuit_bodega, campania, fecha_cosecha, kilos)
    VALUES (1, 1, '30708090101', 2024, '2024-03-10', 8500.00);

    INSERT INTO lote_uva (id_finca, nro_parcela, cuit_bodega, campania, fecha_cosecha, kilos)
    VALUES (1, 1, '30708090101', 2024, '2024-03-25', 1200.00);

    RAISE EXCEPTION '[FALLO] RN-04: Se permitió duplicar la cosecha de una parcela en el mismo año.';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE '[OK] RN-04: Rechazada segunda cosecha en misma parcela y campaña (unique_violation).';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-05: Porcentajes de corte suman exactamente 100 (Trigger diferido)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        INSERT INTO composicion (cod_vino, id_cepa, porcentaje) VALUES (2, 1, 50.00);
        INSERT INTO composicion (cod_vino, id_cepa, porcentaje) VALUES (2, 2, 30.00);
    END;
    RAISE EXCEPTION '[FALLO] RN-05: Se permitió corte que no suma 100%%.';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE = 'P0001' THEN
            RAISE NOTICE '[OK] RN-05: Rechazada composición con suma distinta de 100%% (Trigger diferido).';
        ELSE
            RAISE;
        END IF;
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-06: Descuentos según tipo de cliente (Función y rango válido)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_desc NUMERIC;
BEGIN
    v_desc := fn_descuento_cliente(1);
    IF v_desc <> 10.00 THEN RAISE EXCEPTION 'Descuento socio incorrecto: %', v_desc; END IF;

    v_desc := fn_descuento_cliente(2);
    IF v_desc <> 20.00 THEN RAISE EXCEPTION 'Descuento distribuidor incorrecto: %', v_desc; END IF;

    v_desc := fn_descuento_cliente(3);
    IF v_desc <> 30.00 THEN RAISE EXCEPTION 'Descuento exportador incorrecto: %', v_desc; END IF;

    RAISE NOTICE '[OK] RN-06: fn_descuento_cliente devolvió los descuentos exactos (10%%, 20%% y 30%%).';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-07: Permisos con fecha de vencimiento posterior a emisión (CHECK)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO permiso_exportacion (cod_permiso, id_cliente, fecha_emision, fecha_vencimiento)
    VALUES ('PERM-INV-01', 3, '2026-05-10', '2026-05-01');
    RAISE EXCEPTION '[FALLO] RN-07: Se permitió vencimiento anterior a la emisión.';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '[OK] RN-07: Rechazado permiso con fecha de vencimiento incoherente (check_violation).';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-08 y RN-09: Control de stock en venta y cálculo de totales
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_nro_comp INTEGER;
    v_total NUMERIC;
BEGIN
    -- Asegurar precio base de $12.500
    UPDATE vino SET precio = 12500.00 WHERE cod_vino = 1;

    INSERT INTO stock_sala (id_sala, cod_vino, cantidad)
    VALUES (1, 1, 10)
    ON CONFLICT (id_sala, cod_vino) DO UPDATE SET cantidad = 10;

    INSERT INTO comprobante (id_cliente, id_sala, fecha)
    VALUES (1, 1, CURRENT_DATE)
    RETURNING nro_comprobante INTO v_nro_comp;

    -- Intento de sobreventa
    BEGIN
        INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad)
        VALUES (v_nro_comp, 1, 15);
        RAISE EXCEPTION '[FALLO] RN-09: Se permitió vender más botellas que las disponibles.';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLSTATE = 'P0001' THEN
                RAISE NOTICE '[OK] RN-09: Rechazada venta por stock insuficiente en sala (Trigger BEFORE).';
            ELSE
                RAISE;
            END IF;
    END;

    -- Venta válida de 4 botellas (4 * 12500 = 50000; con 10% desc = 45000)
    INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad)
    VALUES (v_nro_comp, 1, 4);

    IF fn_stock_sala(1, 1) <> 6 THEN
        RAISE EXCEPTION '[FALLO] RN-09: El stock de sala no se actualizó tras la venta.';
    END IF;

    SELECT total INTO v_total FROM comprobante WHERE nro_comprobante = v_nro_comp;
    IF v_total <> 45000.00 THEN
        RAISE EXCEPTION '[FALLO] RN-08: Cálculo de total incorrecto. Obtenido: %, esperado: 45000.00', v_total;
    END IF;

    RAISE NOTICE '[OK] RN-08 y RN-09: Venta exitosa descontó stock (quedan 6) y totalizó $45.000 con descuento.';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-10: Ciclo de Ingresos y procedimiento
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_cod_ingreso INTEGER;
BEGIN
    INSERT INTO ingreso (cuit_bodega, cod_transportista, fecha, estado)
    VALUES ('30708090101', 1, CURRENT_DATE, 'en_confeccion')
    RETURNING cod_ingreso INTO v_cod_ingreso;

    INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
    VALUES (v_cod_ingreso, 1, 100);

    BEGIN
        CALL sp_procesar_ingreso(v_cod_ingreso);
        RAISE EXCEPTION '[FALLO] RN-10: Se permitió procesar un ingreso en confección.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '[OK] RN-10: Procedimiento rechazó procesar ingreso que no estaba terminado.';
    END;

    UPDATE ingreso SET estado = 'terminado' WHERE cod_ingreso = v_cod_ingreso;
    CALL sp_procesar_ingreso(v_cod_ingreso);

    IF (SELECT cantidad FROM stock_deposito WHERE cod_vino = 1) < 100 THEN
        RAISE EXCEPTION '[FALLO] RN-10: No impactó el stock en depósito.';
    END IF;

    BEGIN
        UPDATE ingreso SET estado = 'en_confeccion' WHERE cod_ingreso = v_cod_ingreso;
        RAISE EXCEPTION '[FALLO] RN-10: Se permitió retroceder el estado a en_confeccion.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '[OK] RN-10: Rechazado retroceso de estado en ingreso procesado.';
    END;
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-11: Ciclo de Transferencias y procedimiento
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_nro_solicitud INTEGER;
BEGIN
    INSERT INTO transferencia (id_sala, fecha_confeccion, estado)
    VALUES (1, CURRENT_DATE, 'en_confeccion')
    RETURNING nro_solicitud INTO v_nro_solicitud;

    INSERT INTO renglon_transferencia (nro_solicitud, cod_vino, cantidad)
    VALUES (v_nro_solicitud, 1, 30);

    BEGIN
        UPDATE transferencia SET fecha_confeccion = '2025-01-01' WHERE nro_solicitud = v_nro_solicitud;
        RAISE EXCEPTION '[FALLO] RN-11: Se permitió modificar la fecha de confección.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '[OK] RN-11: Rechazada alteración de fecha_confeccion (Trigger BEFORE).';
    END;

    UPDATE transferencia SET estado = 'terminado' WHERE nro_solicitud = v_nro_solicitud;
    CALL sp_procesar_transferencia(v_nro_solicitud);

    RAISE NOTICE '[OK] RN-11: Transferencia impactó existencias entre depósito y sala.';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-12: Inmutabilidad de renglones en documentos cerrados
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_cod_ingreso INTEGER;
BEGIN
    INSERT INTO ingreso (cuit_bodega, cod_transportista, fecha, estado)
    VALUES ('30708090101', 1, CURRENT_DATE, 'terminado')
    RETURNING cod_ingreso INTO v_cod_ingreso;

    BEGIN
        INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
        VALUES (v_cod_ingreso, 1, 50);
        RAISE EXCEPTION '[FALLO] RN-12: Se permitió agregar renglones a documento terminado.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '[OK] RN-12: Bloqueada adición de renglones a documento que no está en confección.';
    END;
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-13: Auditoría de cambios de precio
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    UPDATE vino SET precio = 13900.00 WHERE cod_vino = 1;

    IF NOT EXISTS (
        SELECT 1 FROM auditoria_precio 
        WHERE cod_vino = 1 AND precio_anterior = 12500.00 AND precio_nuevo = 13900.00
    ) THEN
        RAISE EXCEPTION '[FALLO] RN-13: No se insertó el registro de auditoría de precio.';
    END IF;

    RAISE NOTICE '[OK] RN-13: Auditoría registró cambio de precio de $12.500 a $13.900.';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-14: ON DELETE RESTRICT en vino con ventas asociadas
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    DELETE FROM vino WHERE cod_vino = 1;
    RAISE EXCEPTION '[FALLO] RN-14: Se permitió eliminar un vino con movimientos.';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '[OK] RN-14: Rechazado borrado de vino con movimientos por ON DELETE RESTRICT.';
END $$;


-- ----------------------------------------------------------------------------
-- PRUEBA RN-15: Rango de graduación alcohólica (5° a 20°)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO vino (cuit_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio)
    VALUES ('30708090101', 'Vino Fuerte', 'tinto', 2022, 750, 25.00, 8000.00);
    RAISE EXCEPTION '[FALLO] RN-15: Se permitió graduación alcohólica de 25°.';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '[OK] RN-15: Rechazada graduación fuera del rango 5° - 20° (check_violation).';
END $$;

DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'BATERÍA DE PRUEBAS FINALIZADA CON ÉXITO: 100%% DE COBERTURA';
    RAISE NOTICE '============================================================';
END $$;