-- ============================================================================
-- PROYECTO: Bodegas del Atuel
-- ETAPA 2: Vistas Analíticas y de Operación (006_vistas.sql)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. v_stock_total_vino
-- Propósito: Consolida el stock en el depósito central y en las salas de venta
--            por cada vino existente en el catálogo.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_stock_total_vino AS
SELECT 
    v.cod_vino,
    v.nombre AS vino,
    v.tipo,
    v.anada,
    v.volumen_ml,
    v.precio,
    COALESCE(sd.cantidad, 0) AS stock_deposito,
    COALESCE(ss.stock_salas, 0)::INTEGER AS stock_salas,
    (COALESCE(sd.cantidad, 0) + COALESCE(ss.stock_salas, 0))::INTEGER AS stock_total
FROM vino v
LEFT JOIN stock_deposito sd ON v.cod_vino = sd.cod_vino
LEFT JOIN (
    SELECT cod_vino, SUM(cantidad) AS stock_salas
    FROM stock_sala
    GROUP BY cod_vino
) ss ON v.cod_vino = ss.cod_vino;


-- ----------------------------------------------------------------------------
-- 2. v_documentos_pendientes
-- Propósito: Monitorea todas las operaciones de ingresos y transferencias que
--            todavía no fueron procesadas (estados 'en_confeccion' o 'terminado').
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_documentos_pendientes AS
SELECT 
    'ingreso' AS tipo_documento,
    i.cod_ingreso AS nro_documento,
    i.fecha AS fecha_emision,
    i.estado,
    b.razon_social AS origen,
    'Depósito Central' AS destino,
    t.razon_social AS transportista,
    COUNT(ri.cod_vino)::INTEGER AS cantidad_items,
    COALESCE(SUM(ri.cantidad), 0)::INTEGER AS total_botellas
FROM ingreso i
JOIN bodega b ON i.cuit_bodega = b.cuit
JOIN transportista t ON i.cod_transportista = t.cod_transportista
LEFT JOIN renglon_ingreso ri ON i.cod_ingreso = ri.cod_ingreso
WHERE i.estado <> 'procesado'
GROUP BY i.cod_ingreso, i.fecha, i.estado, b.razon_social, t.razon_social

UNION ALL

SELECT 
    'transferencia' AS tipo_documento,
    tr.nro_solicitud AS nro_documento,
    tr.fecha_confeccion AS fecha_emision,
    tr.estado,
    'Depósito Central' AS origen,
    CONCAT('Sala ', s.id_sala, ' - ', l.nombre) AS destino,
    '-' AS transportista,
    COUNT(rt.cod_vino)::INTEGER AS cantidad_items,
    COALESCE(SUM(rt.cantidad), 0)::INTEGER AS total_botellas
FROM transferencia tr
JOIN sala_venta s ON tr.id_sala = s.id_sala
JOIN localidad l ON s.id_localidad = l.id_localidad
LEFT JOIN renglon_transferencia rt ON tr.nro_solicitud = rt.nro_solicitud
WHERE tr.estado <> 'procesado'
GROUP BY tr.nro_solicitud, tr.fecha_confeccion, tr.estado, s.id_sala, l.nombre;


-- ----------------------------------------------------------------------------
-- 3. mv_ventas_mensuales_sala (Vista Materializada)
-- Propósito: Agrupa el volumen de comprobantes emitidos y montos facturados
--            por sala y período mensual. Acelera consultas de reportes.
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_ventas_mensuales_sala CASCADE;

CREATE MATERIALIZED VIEW mv_ventas_mensuales_sala AS
SELECT 
    c.id_sala,
    s.calle || ' ' || s.numero AS direccion_sala,
    l.nombre AS localidad,
    DATE_PART('year', c.fecha)::INTEGER AS anio,
    DATE_PART('month', c.fecha)::INTEGER AS mes,
    COUNT(c.nro_comprobante)::INTEGER AS cantidad_ventas,
    COALESCE(SUM(c.subtotal), 0.00)::NUMERIC(14, 2) AS subtotal_bruto,
    COALESCE(SUM(c.descuento), 0.00)::NUMERIC(14, 2) AS total_descuentos,
    COALESCE(SUM(c.total), 0.00)::NUMERIC(14, 2) AS total_facturado
FROM comprobante c
JOIN sala_venta s ON c.id_sala = s.id_sala
JOIN localidad l ON s.id_localidad = l.id_localidad
GROUP BY c.id_sala, s.calle, s.numero, l.nombre, DATE_PART('year', c.fecha), DATE_PART('month', c.fecha);

-- Índice único sobre la vista materializada para permitir REFRESH CONCURRENTLY
CREATE UNIQUE INDEX uq_mv_ventas_mensuales_sala 
ON mv_ventas_mensuales_sala (id_sala, anio, mes);