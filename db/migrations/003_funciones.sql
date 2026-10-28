-- ============================================================================
-- PROYECTO: Bodegas del Atuel
-- ETAPA 2: Funciones de Lógica y Cálculo (003_funciones.sql)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. fn_descuento_cliente
-- Propósito: Obtiene el porcentaje de descuento aplicable según el tipo de cliente (RN-06).
-- Parámetros: p_id_cliente (INTEGER) -> Identificador del cliente.
-- Retorno: NUMERIC(5, 2) -> Porcentaje de descuento (10.00, 20.00 o 30.00).
-- Volatilidad: STABLE (consulta la tabla cliente; no modifica datos).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_descuento_cliente(p_id_cliente INTEGER)
RETURNS NUMERIC(5, 2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_descuento NUMERIC(5, 2);
BEGIN
    SELECT descuento INTO v_descuento
    FROM cliente
    WHERE id_cliente = p_id_cliente;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cliente con ID % no existe (RN-06)', p_id_cliente;
    END IF;

    RETURN v_descuento;
END;
$$;


-- ----------------------------------------------------------------------------
-- 2. fn_stock_sala
-- Propósito: Consulta el stock disponible de un vino en una sala de venta específica (RN-09).
--            Si no existe registro previo para ese vino en la sala, retorna 0.
-- Parámetros: p_sala (INTEGER) -> ID de la sala de venta.
--             p_vino (INTEGER) -> Código del vino.
-- Retorno: INTEGER -> Cantidad de botellas disponibles.
-- Volatilidad: STABLE (consulta la tabla stock_sala; no modifica datos).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_stock_sala(p_sala INTEGER, p_vino INTEGER)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        (SELECT cantidad 
         FROM stock_sala
         WHERE id_sala = p_sala AND cod_vino = p_vino),
        0
    );
$$;


-- ----------------------------------------------------------------------------
-- 3. fn_antiguedad_anios
-- Propósito: Calcula la antigüedad en años completos transcurridos entre una fecha y hoy.
-- Parámetros: p_fecha (DATE) -> Fecha base (ej. ingreso laboral o alta).
-- Retorno: INTEGER -> Años completos transcurridos.
-- Volatilidad: STABLE (utiliza CURRENT_DATE, invariable dentro de la misma transacción).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_antiguedad_anios(p_fecha DATE)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT DATE_PART('year', AGE(CURRENT_DATE, p_fecha))::INTEGER;
$$;


-- ----------------------------------------------------------------------------
-- 4. fn_total_comprobante
-- Propósito: Calcula el subtotal bruto, el monto de descuento y el total neto
--            de un comprobante sumando sus renglones (RN-08).
-- Parámetros: p_nro_comprobante (INTEGER) -> Número del comprobante.
-- Retorno: TABLE (subtotal NUMERIC, descuento NUMERIC, total NUMERIC)
-- Volatilidad: STABLE (lee tablas comprobante y renglon_comprobante sin alterar datos).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_comprobante(p_nro_comprobante INTEGER)
RETURNS TABLE (
    subtotal NUMERIC(12, 2),
    descuento NUMERIC(12, 2),
    total NUMERIC(12, 2)
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_id_cliente INTEGER;
    v_descuento_pct NUMERIC(5, 2);
    v_subtotal_bruto NUMERIC(12, 2);
    v_monto_descuento NUMERIC(12, 2);
    v_total_neto NUMERIC(12, 2);
BEGIN
    -- Obtener cliente asociado al comprobante
    SELECT id_cliente INTO v_id_cliente
    FROM comprobante
    WHERE nro_comprobante = p_nro_comprobante;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante % no existe', p_nro_comprobante;
    END IF;

    -- Obtener porcentaje de descuento del cliente (RN-06)
    v_descuento_pct := fn_descuento_cliente(v_id_cliente);

    -- Sumar los importes brutos (cantidad * precio_unitario) de los renglones
    SELECT COALESCE(SUM(r.cantidad * r.precio_unitario), 0.00)
    INTO v_subtotal_bruto
    FROM renglon_comprobante r
    WHERE r.nro_comprobante = p_nro_comprobante;

    -- Calcular descuentos e importes finales redondeados a 2 decimales
    v_monto_descuento := ROUND(v_subtotal_bruto * (v_descuento_pct / 100.0), 2);
    v_total_neto := v_subtotal_bruto - v_monto_descuento;

    RETURN QUERY SELECT v_subtotal_bruto, v_monto_descuento, v_total_neto;
END;
$$;