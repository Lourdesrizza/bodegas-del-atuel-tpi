-- ============================================================================
-- PROYECTO: Bodegas del Atuel
-- ETAPA 2: Procedimientos Almacenados Transaccionales (004_procedimientos.sql)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. sp_procesar_ingreso
-- Regla: RN-10 (Solo un ingreso terminado impacta en depósito y pasa a procesado)
-- Propósito: Bloquea la cabecera del ingreso, verifica que esté 'terminado',
--            suma las botellas de cada renglón a stock_deposito (creando el
--            registro si aún no existía) y actualiza el estado a 'procesado'.
-- Parámetros: p_cod_ingreso (INTEGER) -> Código del ingreso a procesar.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(p_cod_ingreso INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_documento;
    v_cant_renglones INTEGER;
    r RECORD;
BEGIN
    -- 1. Bloqueo pesimista de la fila del ingreso para evitar procesamiento concurrente
    SELECT estado INTO v_estado
    FROM ingreso
    WHERE cod_ingreso = p_cod_ingreso
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El ingreso % no existe (RN-10)', p_cod_ingreso;
    END IF;

    -- 2. Validación de estado requerido
    IF v_estado IS DISTINCT FROM 'terminado' THEN
        RAISE EXCEPTION 'El ingreso % se encuentra en estado "%", pero debe estar "terminado" para procesarse (RN-10)',
            p_cod_ingreso, v_estado;
    END IF;

    -- 3. Verificar que el documento contenga renglones
    SELECT COUNT(*) INTO v_cant_renglones
    FROM renglon_ingreso
    WHERE cod_ingreso = p_cod_ingreso;

    IF v_cant_renglones = 0 THEN
        RAISE EXCEPTION 'El ingreso % no contiene renglones asociados para procesar', p_cod_ingreso;
    END IF;

    -- 4. Incrementar el stock del depósito central (crea la fila si no existía)
    FOR r IN SELECT cod_vino,cantidad FROM renglon_ingreso
             WHERE cod_ingreso=p_cod_ingreso ORDER BY cod_vino LOOP
      INSERT INTO stock_deposito(cod_vino,cantidad) VALUES(r.cod_vino,r.cantidad)
      ON CONFLICT(cod_vino) DO UPDATE SET cantidad=stock_deposito.cantidad+EXCLUDED.cantidad;
    END LOOP;

    -- 5. Transición definitiva de estado
    UPDATE ingreso
    SET estado = 'procesado'::estado_documento
    WHERE cod_ingreso = p_cod_ingreso;

    RAISE NOTICE 'Ingreso % procesado exitosamente.', p_cod_ingreso;
END;
$$;


-- ----------------------------------------------------------------------------
-- 2. sp_procesar_transferencia
-- Reglas: RN-09, RN-11 (Impacto atómico de transferencias entre depósito y sala)
-- Propósito: Bloquea la transferencia, verifica estado 'terminado', controla que
--            el depósito central cuente con existencias suficientes de cada vino,
--            descuenta de depósito, suma al stock de la sala solicitante y pasa a 'procesado'.
-- Parámetros: p_nro_solicitud (INTEGER) -> Número de transferencia.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(p_nro_solicitud INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_sala INTEGER;
    v_estado estado_documento;
    v_cant_renglones INTEGER;
    r RECORD;
    v_stock_deposito_actual INTEGER;
BEGIN
    -- 1. Bloqueo de la cabecera de la solicitud
    SELECT id_sala, estado INTO v_id_sala, v_estado
    FROM transferencia
    WHERE nro_solicitud = p_nro_solicitud
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La transferencia % no existe (RN-11)', p_nro_solicitud;
    END IF;

    -- 2. Validación de estado requerido
    IF v_estado IS DISTINCT FROM 'terminado' THEN
        RAISE EXCEPTION 'La transferencia % se encuentra en estado "%", pero debe estar "terminado" para procesarse (RN-11)',
            p_nro_solicitud, v_estado;
    END IF;

    -- 3. Verificar existencia de renglones
    SELECT COUNT(*) INTO v_cant_renglones
    FROM renglon_transferencia
    WHERE nro_solicitud = p_nro_solicitud;

    IF v_cant_renglones = 0 THEN
        RAISE EXCEPTION 'La transferencia % no posee renglones asociados', p_nro_solicitud;
    END IF;

    -- 4. Verificación y bloqueo de stock en depósito central por cada vino
    FOR r IN (
        SELECT cod_vino, cantidad
        FROM renglon_transferencia
        WHERE nro_solicitud = p_nro_solicitud
        ORDER BY cod_vino
    ) LOOP
        SELECT cantidad INTO v_stock_deposito_actual
        FROM stock_deposito
        WHERE cod_vino = r.cod_vino
        FOR UPDATE;

        IF NOT FOUND OR v_stock_deposito_actual < r.cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente en depósito central para el vino % (disponible: %, requerido: %) (RN-11)',
                r.cod_vino, COALESCE(v_stock_deposito_actual, 0), r.cantidad;
        END IF;
    END LOOP;

    -- 5. Descontar botellas de stock_deposito (usando alias rt)
    FOR r IN SELECT cod_vino,cantidad FROM renglon_transferencia
             WHERE nro_solicitud=p_nro_solicitud ORDER BY cod_vino LOOP
      UPDATE stock_deposito SET cantidad=cantidad-r.cantidad WHERE cod_vino=r.cod_vino;
      INSERT INTO stock_sala(id_sala,cod_vino,cantidad) VALUES(v_id_sala,r.cod_vino,r.cantidad)
      ON CONFLICT(id_sala,cod_vino) DO UPDATE SET cantidad=stock_sala.cantidad+EXCLUDED.cantidad;
    END LOOP;

    -- 7. Transición definitiva de estado
    UPDATE transferencia
    SET estado = 'procesado'::estado_documento
    WHERE nro_solicitud = p_nro_solicitud;

    RAISE NOTICE 'Transferencia % procesada exitosamente para la sala %.', p_nro_solicitud, v_id_sala;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_terminar_ingreso(p_id integer) LANGUAGE plpgsql AS $$
BEGIN
  UPDATE ingreso SET estado='terminado' WHERE cod_ingreso=p_id AND estado='en_confeccion';
  IF NOT FOUND THEN RAISE EXCEPTION 'Ingreso inexistente o no está en confección'; END IF;
END $$;
CREATE OR REPLACE PROCEDURE sp_terminar_transferencia(p_id integer) LANGUAGE plpgsql AS $$
BEGIN
  UPDATE transferencia SET estado='terminado' WHERE nro_solicitud=p_id AND estado='en_confeccion';
  IF NOT FOUND THEN RAISE EXCEPTION 'Transferencia inexistente o no está en confección'; END IF;
END $$;
