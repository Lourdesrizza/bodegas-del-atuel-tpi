-- ============================================================================
-- PROYECTO: Bodegas del Atuel
-- ETAPA 2: Triggers y Reglas de Negocio Dinámicas (005_triggers.sql)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. VALIDACIÓN DE STOCK Y CÁLCULO DE IMPORTES EN RENGLÓN DE VENTA
-- Reglas: RN-01, RN-06, RN-08, RN-09
-- Tipo: BEFORE INSERT en renglon_comprobante
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_validar_renglon_venta()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_sala INTEGER;
    v_cliente INTEGER;
    v_stock_disponible INTEGER;
    v_precio_actual NUMERIC(10, 2);
    v_descuento_pct NUMERIC(5, 2);
BEGIN
    -- Obtener la sala y el cliente del comprobante
    SELECT id_sala, id_cliente INTO v_sala, v_cliente
    FROM comprobante
    WHERE nro_comprobante = NEW.nro_comprobante;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante cabecera % no existe', NEW.nro_comprobante;
    END IF;

    -- RN-09: Validar existencia de stock suficiente en la sala
    v_stock_disponible := fn_stock_sala(v_sala, NEW.cod_vino);
    IF v_stock_disponible < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente del vino % en la sala % (disponible: %, solicitado: %) (RN-09)',
            NEW.cod_vino, v_sala, v_stock_disponible, NEW.cantidad;
    END IF;

    -- Obtener precio vigente del catálogo del vino (RN-01)
    SELECT precio INTO v_precio_actual
    FROM vino
    WHERE cod_vino = NEW.cod_vino;

    -- Fijar el precio histórico al momento de la venta
    NEW.precio_unitario := COALESCE(NEW.precio_unitario, v_precio_actual);

    -- RN-06: Asignar descuento según tipo de cliente
    v_descuento_pct := fn_descuento_cliente(v_cliente);
    NEW.descuento_aplicado := v_descuento_pct;

    -- RN-08: Calcular el subtotal del renglón con descuento aplicado
    NEW.subtotal_renglon := ROUND(
        NEW.cantidad * NEW.precio_unitario * (1.0 - (v_descuento_pct / 100.0)),
        2
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_valida_stock_renglon ON renglon_comprobante;
CREATE TRIGGER trg_valida_stock_renglon
BEFORE INSERT ON renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION trg_fn_validar_renglon_venta();


-- ----------------------------------------------------------------------------
-- 2. DESCUENTO DE STOCK Y ACTUALIZACIÓN DE TOTALES DEL COMPROBANTE
-- Reglas: RN-08, RN-09
-- Tipo: AFTER INSERT en renglon_comprobante
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_actualizar_stock_totales_venta()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_sala INTEGER;
    v_totales RECORD;
BEGIN
    -- Obtener sala del comprobante
    SELECT id_sala INTO v_sala
    FROM comprobante
    WHERE nro_comprobante = NEW.nro_comprobante;

    -- RN-09: Descontar botellas vendidas del stock de la sala
    UPDATE stock_sala
    SET cantidad = cantidad - NEW.cantidad
    WHERE id_sala = v_sala AND cod_vino = NEW.cod_vino;

    -- RN-08: Recalcular y actualizar totales en la cabecera
    SELECT * INTO v_totales FROM fn_total_comprobante(NEW.nro_comprobante);

    UPDATE comprobante
    SET subtotal = v_totales.subtotal,
        descuento = v_totales.descuento,
        total = v_totales.total
    WHERE nro_comprobante = NEW.nro_comprobante;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_descuenta_stock_actualiza_totales ON renglon_comprobante;
CREATE TRIGGER trg_descuenta_stock_actualiza_totales
AFTER INSERT ON renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION trg_fn_actualizar_stock_totales_venta();


-- ----------------------------------------------------------------------------
-- 3. CONTROL DE TRANSICIONES DE ESTADO EN INGRESOS
-- Regla: RN-10 (en_confeccion -> terminado -> procesado, sin retrocesos ni saltos)
-- Tipo: BEFORE UPDATE OF estado en ingreso
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_control_estados_ingreso()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    IF OLD.estado = 'en_confeccion' AND NEW.estado <> 'terminado' THEN
        RAISE EXCEPTION 'Transición inválida en ingreso %: solo se puede pasar de "en_confeccion" a "terminado" (RN-10)',
            OLD.cod_ingreso;
    ELSIF OLD.estado = 'terminado' AND NEW.estado <> 'procesado' THEN
        RAISE EXCEPTION 'Transición inválida en ingreso %: solo se puede pasar de "terminado" a "procesado" (RN-10)',
            OLD.cod_ingreso;
    ELSIF OLD.estado = 'procesado' THEN
        RAISE EXCEPTION 'El ingreso % ya está procesado y su estado no puede modificarse (RN-10)',
            OLD.cod_ingreso;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_estado_ingreso ON ingreso;
CREATE TRIGGER trg_estado_ingreso
BEFORE UPDATE OF estado ON ingreso
FOR EACH ROW
EXECUTE FUNCTION trg_fn_control_estados_ingreso();


-- ----------------------------------------------------------------------------
-- 4. CONTROL DE TRANSICIONES DE ESTADO EN TRANSFERENCIAS
-- Regla: RN-11 (en_confeccion -> terminado -> procesado, sin retrocesos ni saltos)
-- Tipo: BEFORE UPDATE OF estado en transferencia
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_control_estados_transferencia()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    IF OLD.estado = 'en_confeccion' AND NEW.estado <> 'terminado' THEN
        RAISE EXCEPTION 'Transición inválida en transferencia %: solo se permite pasar de "en_confeccion" a "terminado" (RN-11)',
            OLD.nro_solicitud;
    ELSIF OLD.estado = 'terminado' AND NEW.estado <> 'procesado' THEN
        RAISE EXCEPTION 'Transición inválida en transferencia %: solo se permite pasar de "terminado" a "procesado" (RN-11)',
            OLD.nro_solicitud;
    ELSIF OLD.estado = 'procesado' THEN
        RAISE EXCEPTION 'La transferencia % ya está procesada y su estado no admite modificaciones (RN-11)',
            OLD.nro_solicitud;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_estado_transferencia ON transferencia;
CREATE TRIGGER trg_estado_transferencia
BEFORE UPDATE OF estado ON transferencia
FOR EACH ROW
EXECUTE FUNCTION trg_fn_control_estados_transferencia();


-- ----------------------------------------------------------------------------
-- 5. FECHA DE CONFECCIÓN INMUTABLE EN TRANSFERENCIAS
-- Regla: RN-11 (La fecha de confección es la actual y no puede modificarse)
-- Tipo: BEFORE INSERT OR UPDATE en transferencia
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_fecha_confeccion_transferencia()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha_confeccion := CURRENT_DATE;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.fecha_confeccion IS DISTINCT FROM OLD.fecha_confeccion THEN
            RAISE EXCEPTION 'La fecha de confección de la transferencia no puede ser modificada (RN-11)';
        END IF;
        RETURN NEW;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fecha_transferencia ON transferencia;
CREATE TRIGGER trg_fecha_transferencia
BEFORE INSERT OR UPDATE ON transferencia
FOR EACH ROW
EXECUTE FUNCTION trg_fn_fecha_confeccion_transferencia();


-- ----------------------------------------------------------------------------
-- 6. BLOQUEO DE RENGLONES EN DOCUMENTOS NO EN CONFECCIÓN
-- Regla: RN-12 (No admite agregar, modificar ni quitar renglones si no está en confección)
-- Tipo: BEFORE INSERT OR UPDATE OR DELETE en renglon_ingreso y renglon_transferencia
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_bloqueo_renglones_ingreso()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_cod_ingreso INTEGER;
    v_estado estado_documento;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_cod_ingreso := OLD.cod_ingreso;
    ELSE
        v_cod_ingreso := NEW.cod_ingreso;
    END IF;

    SELECT estado INTO v_estado
    FROM ingreso
    WHERE cod_ingreso = v_cod_ingreso;

    IF v_estado IS DISTINCT FROM 'en_confeccion' THEN
        RAISE EXCEPTION 'No se pueden modificar los renglones del ingreso % porque su estado es "%" (RN-12)',
            v_cod_ingreso, v_estado;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bloqueo_renglon_ingreso ON renglon_ingreso;
CREATE TRIGGER trg_bloqueo_renglon_ingreso
BEFORE INSERT OR UPDATE OR DELETE ON renglon_ingreso
FOR EACH ROW
EXECUTE FUNCTION trg_fn_bloqueo_renglones_ingreso();


CREATE OR REPLACE FUNCTION trg_fn_bloqueo_renglones_transferencia()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_nro_solicitud INTEGER;
    v_estado estado_documento;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_nro_solicitud := OLD.nro_solicitud;
    ELSE
        v_nro_solicitud := NEW.nro_solicitud;
    END IF;

    SELECT estado INTO v_estado
    FROM transferencia
    WHERE nro_solicitud = v_nro_solicitud;

    IF v_estado IS DISTINCT FROM 'en_confeccion' THEN
        RAISE EXCEPTION 'No se pueden modificar los renglones de la transferencia % porque su estado es "%" (RN-12)',
            v_nro_solicitud, v_estado;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bloqueo_renglon_transferencia ON renglon_transferencia;
CREATE TRIGGER trg_bloqueo_renglon_transferencia
BEFORE INSERT OR UPDATE OR DELETE ON renglon_transferencia
FOR EACH ROW
EXECUTE FUNCTION trg_fn_bloqueo_renglones_transferencia();


-- ----------------------------------------------------------------------------
-- 7. AUDITORÍA DE PRECIOS DE VINO
-- Regla: RN-13 (Registra fecha, usuario, precio anterior y nuevo ante cambios de precio)
-- Tipo: AFTER UPDATE OF precio en vino
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_auditoria_precio_vino()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.precio IS DISTINCT FROM NEW.precio THEN
        INSERT INTO auditoria_precio (
            cod_vino,
            precio_anterior,
            precio_nuevo,
            fecha_hora,
            usuario
        ) VALUES (
            NEW.cod_vino,
            OLD.precio,
            NEW.precio,
            CURRENT_TIMESTAMP,
            SESSION_USER
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audita_precio_vino ON vino;
CREATE TRIGGER trg_audita_precio_vino
AFTER UPDATE OF precio ON vino
FOR EACH ROW
EXECUTE FUNCTION trg_fn_auditoria_precio_vino();


-- ----------------------------------------------------------------------------
-- 8. SUMA DE PORCENTAJES DE CORTE (100%)
-- Regla: RN-05 (Los porcentajes de corte suman exactamente 100)
-- Tipo: CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED en composicion
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_validar_porcentaje_corte()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_cod_vino INTEGER;
    v_suma NUMERIC(6, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_cod_vino := OLD.cod_vino;
    ELSE
        v_cod_vino := NEW.cod_vino;
    END IF;

    -- Validar si el vino todavía existe (evita errores en cascadas)
    IF EXISTS (SELECT 1 FROM vino WHERE cod_vino = v_cod_vino) THEN
        SELECT COALESCE(SUM(porcentaje), 0.00) INTO v_suma
        FROM composicion
        WHERE cod_vino = v_cod_vino;

        IF v_suma <> 100.00 THEN
            RAISE EXCEPTION 'La composición del vino % suma % %, pero debe sumar exactamente 100 %% (RN-05)',
                v_cod_vino, v_suma;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_composicion_suma_cien ON composicion;
CREATE CONSTRAINT TRIGGER trg_composicion_suma_cien
AFTER INSERT OR UPDATE OR DELETE ON composicion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION trg_fn_validar_porcentaje_corte();