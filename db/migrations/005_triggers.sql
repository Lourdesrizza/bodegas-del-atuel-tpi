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
    NEW.precio_unitario := v_precio_actual;

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
            RAISE EXCEPTION 'La composición del vino % suma %, pero debe sumar exactamente 100 %% (RN-05)',
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

-- Cierre de brechas detectadas en la revisión.
CREATE OR REPLACE FUNCTION trg_fn_cliente_subtipo() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_id integer; v_tipo text; v_n integer;
BEGIN
  v_id := CASE WHEN TG_TABLE_NAME = 'cliente' THEN COALESCE(NEW.id_cliente, OLD.id_cliente)
               ELSE COALESCE(NEW.id_cliente, OLD.id_cliente) END;
  SELECT tipo_cliente INTO v_tipo FROM cliente WHERE id_cliente = v_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT (EXISTS(SELECT 1 FROM socio WHERE id_cliente=v_id))::int +
         (EXISTS(SELECT 1 FROM distribuidor WHERE id_cliente=v_id))::int +
         (EXISTS(SELECT 1 FROM exportador WHERE id_cliente=v_id))::int INTO v_n;
  IF v_n <> 1 OR NOT (
      (v_tipo='socio' AND EXISTS(SELECT 1 FROM socio WHERE id_cliente=v_id)) OR
      (v_tipo='distribuidor' AND EXISTS(SELECT 1 FROM distribuidor WHERE id_cliente=v_id)) OR
      (v_tipo='exportador' AND EXISTS(SELECT 1 FROM exportador WHERE id_cliente=v_id))) THEN
    RAISE EXCEPTION 'Cliente %: subtipo ausente o incompatible (RN-06)', v_id;
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER trg_cliente_subtipo AFTER INSERT OR UPDATE OR DELETE ON cliente
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trg_fn_cliente_subtipo();
CREATE CONSTRAINT TRIGGER trg_socio_subtipo AFTER INSERT OR UPDATE OR DELETE ON socio
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trg_fn_cliente_subtipo();
CREATE CONSTRAINT TRIGGER trg_distribuidor_subtipo AFTER INSERT OR UPDATE OR DELETE ON distribuidor
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trg_fn_cliente_subtipo();
CREATE CONSTRAINT TRIGGER trg_exportador_subtipo AFTER INSERT OR UPDATE OR DELETE ON exportador
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trg_fn_cliente_subtipo();

CREATE OR REPLACE FUNCTION trg_fn_comprobante_inmutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP='UPDATE' AND pg_trigger_depth() > 1 AND
     ROW(NEW.nro_comprobante,NEW.id_cliente,NEW.id_sala,NEW.fecha) IS NOT DISTINCT FROM
     ROW(OLD.nro_comprobante,OLD.id_cliente,OLD.id_sala,OLD.fecha) THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'Comprobante emitido inmutable (RN-08)';
END $$;
CREATE TRIGGER trg_comprobante_inmutable BEFORE UPDATE OR DELETE ON comprobante
FOR EACH ROW EXECUTE FUNCTION trg_fn_comprobante_inmutable();
CREATE OR REPLACE FUNCTION trg_fn_renglon_venta_inmutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Renglón de venta emitido inmutable (RN-08/09)'; END $$;
CREATE TRIGGER trg_renglon_venta_inmutable BEFORE UPDATE OR DELETE ON renglon_comprobante
FOR EACH ROW EXECUTE FUNCTION trg_fn_renglon_venta_inmutable();

-- Bloqueo de cabecera durante el alta de renglones; serializa las ventas del mismo comprobante.
CREATE OR REPLACE FUNCTION trg_fn_validar_renglon_venta() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_sala integer; v_cliente integer; v_precio numeric(10,2); v_desc numeric(5,2);
BEGIN
  SELECT id_sala,id_cliente INTO v_sala,v_cliente FROM comprobante
  WHERE nro_comprobante=NEW.nro_comprobante FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comprobante % inexistente',NEW.nro_comprobante; END IF;
  SELECT precio INTO v_precio FROM vino WHERE cod_vino=NEW.cod_vino;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vino % inexistente',NEW.cod_vino; END IF;
  v_desc := fn_descuento_cliente(v_cliente);
  NEW.precio_unitario := v_precio;
  NEW.descuento_aplicado := v_desc;
  NEW.subtotal_renglon := ROUND(NEW.cantidad*v_precio*(1-v_desc/100),2);
  -- UPDATE atómico: la segunda sesión espera y luego observa el stock vigente.
  UPDATE stock_sala SET cantidad=cantidad-NEW.cantidad
  WHERE id_sala=v_sala AND cod_vino=NEW.cod_vino AND cantidad>=NEW.cantidad;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stock insuficiente en sala para vino % (RN-09)',NEW.cod_vino; END IF;
  RETURN NEW;
END $$;
-- El descuento se realiza en BEFORE INSERT; AFTER INSERT solo recalcula.
CREATE OR REPLACE FUNCTION trg_fn_actualizar_stock_totales_venta() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_totales record;
BEGIN
  SELECT * INTO v_totales FROM fn_total_comprobante(NEW.nro_comprobante);
  UPDATE comprobante SET subtotal=v_totales.subtotal, descuento=v_totales.descuento,
    total=v_totales.total WHERE nro_comprobante=NEW.nro_comprobante;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION trg_fn_bloqueo_renglones_ingreso() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_id integer; v_estado estado_documento;
BEGIN
  FOR v_id IN SELECT DISTINCT id FROM (VALUES
    (CASE WHEN TG_OP<>'INSERT' THEN OLD.cod_ingreso END),
    (CASE WHEN TG_OP<>'DELETE' THEN NEW.cod_ingreso END)) AS ids(id)
    WHERE id IS NOT NULL ORDER BY id LOOP
    SELECT estado INTO v_estado FROM ingreso WHERE cod_ingreso=v_id FOR UPDATE;
    IF v_estado IS DISTINCT FROM 'en_confeccion' THEN
      RAISE EXCEPTION 'Ingreso % cerrado: renglón inmutable (RN-12)',v_id;
    END IF;
  END LOOP;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION trg_fn_bloqueo_renglones_transferencia() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_id integer; v_estado estado_documento;
BEGIN
  FOR v_id IN SELECT DISTINCT id FROM (VALUES
    (CASE WHEN TG_OP<>'INSERT' THEN OLD.nro_solicitud END),
    (CASE WHEN TG_OP<>'DELETE' THEN NEW.nro_solicitud END)) AS ids(id)
    WHERE id IS NOT NULL ORDER BY id LOOP
    SELECT estado INTO v_estado FROM transferencia WHERE nro_solicitud=v_id FOR UPDATE;
    IF v_estado IS DISTINCT FROM 'en_confeccion' THEN
      RAISE EXCEPTION 'Transferencia % cerrada: renglón inmutable (RN-12)',v_id;
    END IF;
  END LOOP;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;

-- El ingreso sólo puede contener vinos elaborados por su bodega de origen.
CREATE OR REPLACE FUNCTION trg_fn_bloqueo_renglones_ingreso() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_id integer; v_estado estado_documento;
BEGIN
  FOR v_id IN SELECT DISTINCT id FROM (VALUES
    (CASE WHEN TG_OP<>'INSERT' THEN OLD.cod_ingreso END),
    (CASE WHEN TG_OP<>'DELETE' THEN NEW.cod_ingreso END)) AS ids(id)
    WHERE id IS NOT NULL ORDER BY id LOOP
    SELECT estado INTO v_estado FROM ingreso WHERE cod_ingreso=v_id FOR UPDATE;
    IF v_estado IS DISTINCT FROM 'en_confeccion' THEN
      RAISE EXCEPTION 'Ingreso % cerrado: renglón inmutable (RN-12)',v_id;
    END IF;
  END LOOP;
  IF TG_OP<>'DELETE' AND NOT EXISTS (
    SELECT 1 FROM ingreso i JOIN vino v ON v.cuit_bodega=i.cuit_bodega
    WHERE i.cod_ingreso=NEW.cod_ingreso AND v.cod_vino=NEW.cod_vino) THEN
    RAISE EXCEPTION 'El vino no pertenece a la bodega del ingreso';
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;

-- Procesado se reserva a procedimientos; el rol API no recibe UPDATE de cabeceras.
CREATE OR REPLACE FUNCTION trg_fn_control_estados_ingreso() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.estado='en_confeccion' AND NEW.estado='terminado' THEN RETURN NEW; END IF;
  IF OLD.estado='terminado' AND NEW.estado='procesado' AND pg_trigger_depth()>0
     AND current_user='app_owner' THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'Transición inválida de ingreso (RN-10)';
END $$;
CREATE OR REPLACE FUNCTION trg_fn_control_estados_transferencia() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.estado='en_confeccion' AND NEW.estado='terminado' THEN RETURN NEW; END IF;
  IF OLD.estado='terminado' AND NEW.estado='procesado' AND current_user='app_owner' THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'Transición inválida de transferencia (RN-11)';
END $$;
CREATE OR REPLACE FUNCTION trg_fn_estado_inicial() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.estado <> 'en_confeccion' THEN RAISE EXCEPTION 'Estado inicial debe ser en_confeccion'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_ingreso_inicial BEFORE INSERT ON ingreso FOR EACH ROW EXECUTE FUNCTION trg_fn_estado_inicial();
CREATE TRIGGER trg_transferencia_inicial BEFORE INSERT ON transferencia FOR EACH ROW EXECUTE FUNCTION trg_fn_estado_inicial();

CREATE OR REPLACE FUNCTION trg_fn_validar_porcentaje_corte() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_id integer; v_suma numeric;
BEGIN
  FOR v_id IN SELECT DISTINCT id FROM (VALUES
    (CASE WHEN TG_OP<>'INSERT' THEN OLD.cod_vino END),
    (CASE WHEN TG_OP<>'DELETE' THEN NEW.cod_vino END)) AS ids(id)
    WHERE id IS NOT NULL ORDER BY id LOOP
    IF EXISTS(SELECT 1 FROM vino WHERE cod_vino=v_id) THEN
      SELECT COALESCE(SUM(porcentaje),0) INTO v_suma FROM composicion WHERE cod_vino=v_id;
      IF v_suma<>100 THEN RAISE EXCEPTION 'Corte del vino % suma %; debe sumar 100 %% (RN-05)',v_id,v_suma; END IF;
    END IF;
  END LOOP;
  RETURN NULL;
END $$;
CREATE OR REPLACE FUNCTION trg_fn_validar_vino_composicion() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_suma numeric;
BEGIN
  IF EXISTS(SELECT 1 FROM vino WHERE cod_vino=NEW.cod_vino) THEN
    SELECT COALESCE(SUM(porcentaje),0) INTO v_suma FROM composicion WHERE cod_vino=NEW.cod_vino;
    IF v_suma<>100 THEN RAISE EXCEPTION 'Corte del vino % suma %; debe sumar 100 %% (RN-05)',NEW.cod_vino,v_suma; END IF;
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER trg_vino_tiene_composicion AFTER INSERT OR UPDATE ON vino
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trg_fn_validar_vino_composicion();
