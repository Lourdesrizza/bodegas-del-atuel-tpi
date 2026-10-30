-- Cada fila devuelve cantidad de incumplimientos. Cero significa que pasó.
-- La variable de sesión atuel.carga_modo se fija antes de ejecutar este SQL.
WITH conteos(tabla, n) AS (
  VALUES
  ('localidad',(SELECT count(*) FROM localidad)),
  ('sala_venta',(SELECT count(*) FROM sala_venta)),
  ('empleado',(SELECT count(*) FROM empleado)),
  ('finca',(SELECT count(*) FROM finca)),
  ('cepa',(SELECT count(*) FROM cepa)),
  ('parcela',(SELECT count(*) FROM parcela)),
  ('bodega',(SELECT count(*) FROM bodega)),
  ('lote_uva',(SELECT count(*) FROM lote_uva)),
  ('analisis_calidad',(SELECT count(*) FROM analisis_calidad)),
  ('vino',(SELECT count(*) FROM vino)),
  ('composicion',(SELECT count(*) FROM composicion)),
  ('maridaje',(SELECT count(*) FROM maridaje)),
  ('vino_maridaje',(SELECT count(*) FROM vino_maridaje)),
  ('tipo_cliente',(SELECT count(*) FROM tipo_cliente)),
  ('cliente',(SELECT count(*) FROM cliente)),
  ('socio',(SELECT count(*) FROM socio)),
  ('distribuidor',(SELECT count(*) FROM distribuidor)),
  ('exportador',(SELECT count(*) FROM exportador)),
  ('permiso_exportacion',(SELECT count(*) FROM permiso_exportacion)),
  ('transportista',(SELECT count(*) FROM transportista)),
  ('transportista_localidad',(SELECT count(*) FROM transportista_localidad)),
  ('stock_deposito',(SELECT count(*) FROM stock_deposito)),
  ('stock_sala',(SELECT count(*) FROM stock_sala)),
  ('ingreso',(SELECT count(*) FROM ingreso)),
  ('renglon_ingreso',(SELECT count(*) FROM renglon_ingreso)),
  ('transferencia',(SELECT count(*) FROM transferencia)),
  ('renglon_transferencia',(SELECT count(*) FROM renglon_transferencia)),
  ('comprobante',(SELECT count(*) FROM comprobante)),
  ('renglon_comprobante',(SELECT count(*) FROM renglon_comprobante)),
  ('auditoria_precio',(SELECT count(*) FROM auditoria_precio))
),
ingresado AS (
  SELECT cod_vino, sum(cantidad) cantidad FROM renglon_ingreso r
  JOIN ingreso i USING(cod_ingreso) WHERE i.estado='procesado' GROUP BY cod_vino
),
transferido AS (
  SELECT cod_vino, sum(cantidad) cantidad FROM renglon_transferencia r
  JOIN transferencia t USING(nro_solicitud) WHERE t.estado='procesado' GROUP BY cod_vino
),
transferido_sala AS (
  SELECT id_sala,cod_vino,sum(cantidad) cantidad FROM renglon_transferencia r
  JOIN transferencia t USING(nro_solicitud) WHERE t.estado='procesado' GROUP BY id_sala,cod_vino
),
vendido_sala AS (
  SELECT id_sala,cod_vino,sum(cantidad) cantidad FROM renglon_comprobante r
  JOIN comprobante c USING(nro_comprobante) GROUP BY id_sala,cod_vino
),
totales AS (
  SELECT nro_comprobante,sum(cantidad*precio_unitario) bruto,
         sum(subtotal_renglon) neto FROM renglon_comprobante GROUP BY nro_comprobante
),
controles(control, incumplimientos) AS (
  SELECT 'tabla_vacia', count(*) FROM conteos WHERE n=0
  UNION ALL SELECT 'tablas_no_en_catalogo', abs((SELECT count(*) FROM conteos)-30)
  UNION ALL SELECT 'volumen_clientes',
    CASE WHEN current_setting('atuel.carga_modo',true)='completa'
    THEN abs((SELECT n FROM conteos WHERE tabla='cliente')-20000) ELSE 0 END
  UNION ALL SELECT 'volumen_comprobantes',
    CASE WHEN current_setting('atuel.carga_modo',true)='completa'
    THEN abs((SELECT n FROM conteos WHERE tabla='comprobante')-150000) ELSE 0 END
  UNION ALL SELECT 'volumen_renglones_venta',
    CASE WHEN current_setting('atuel.carga_modo',true)='completa'
    THEN abs((SELECT n FROM conteos WHERE tabla='renglon_comprobante')-500000) ELSE 0 END
  UNION ALL SELECT 'volumen_tres_tablas_10k',
    CASE WHEN current_setting('atuel.carga_modo',true)='completa'
    THEN greatest(3-(SELECT count(*) FROM conteos WHERE n>10000),0) ELSE 0 END
  UNION ALL SELECT 'fk_no_validadas', count(*) FROM pg_constraint
    WHERE contype='f' AND connamespace='public'::regnamespace AND NOT convalidated
  UNION ALL SELECT 'huerfanos_venta', count(*) FROM renglon_comprobante r
    LEFT JOIN comprobante c USING(nro_comprobante) LEFT JOIN vino v USING(cod_vino)
    WHERE c.nro_comprobante IS NULL OR v.cod_vino IS NULL
  UNION ALL SELECT 'huerfanos_produccion', count(*) FROM lote_uva l
    LEFT JOIN parcela p USING(id_finca,nro_parcela) LEFT JOIN bodega b ON b.cuit=l.cuit_bodega
    WHERE p.id_finca IS NULL OR b.cuit IS NULL
  UNION ALL SELECT 'huerfanos_movimientos', count(*) FROM renglon_transferencia r
    LEFT JOIN transferencia t USING(nro_solicitud) LEFT JOIN vino v USING(cod_vino)
    WHERE t.nro_solicitud IS NULL OR v.cod_vino IS NULL
  UNION ALL SELECT 'cortes', count(*) FROM vino v LEFT JOIN
    (SELECT cod_vino,sum(porcentaje) suma FROM composicion GROUP BY cod_vino) c USING(cod_vino)
    WHERE c.suma IS DISTINCT FROM 100
  UNION ALL SELECT 'subtipos', count(*) FROM cliente c
    LEFT JOIN socio s USING(id_cliente) LEFT JOIN distribuidor d USING(id_cliente)
    LEFT JOIN exportador e USING(id_cliente)
    WHERE (s.id_cliente IS NOT NULL)::int+(d.id_cliente IS NOT NULL)::int+
      (e.id_cliente IS NOT NULL)::int <> 1 OR
      (c.tipo_cliente='socio') IS DISTINCT FROM (s.id_cliente IS NOT NULL) OR
      (c.tipo_cliente='distribuidor') IS DISTINCT FROM (d.id_cliente IS NOT NULL) OR
      (c.tipo_cliente='exportador') IS DISTINCT FROM (e.id_cliente IS NOT NULL)
  UNION ALL SELECT 'descuentos_catalogo', count(*) FROM tipo_cliente
    WHERE (tipo_cliente,descuento) NOT IN (('socio',10),('distribuidor',20),('exportador',30))
  UNION ALL SELECT 'descuentos_venta', count(*) FROM renglon_comprobante r
    JOIN comprobante c USING(nro_comprobante) JOIN cliente cl USING(id_cliente)
    JOIN tipo_cliente t USING(tipo_cliente)
    WHERE r.descuento_aplicado<>t.descuento OR
      r.subtotal_renglon<>round(r.cantidad*r.precio_unitario*(1-r.descuento_aplicado/100),2)
  UNION ALL SELECT 'fechas_analisis', count(*) FROM analisis_calidad a
    JOIN lote_uva l USING(nro_lote) WHERE a.fecha<l.fecha_cosecha
  UNION ALL SELECT 'fechas_movimientos',
    (CASE WHEN (SELECT max(fecha_cosecha) FROM lote_uva) >= (SELECT min(fecha) FROM ingreso) THEN 1 ELSE 0 END +
     CASE WHEN (SELECT max(fecha) FROM ingreso) >= (SELECT min(fecha_confeccion) FROM transferencia) THEN 1 ELSE 0 END +
     CASE WHEN (SELECT max(fecha_confeccion) FROM transferencia) >= (SELECT min(fecha) FROM comprobante) THEN 1 ELSE 0 END)
  UNION ALL SELECT 'totales_venta', count(*) FROM comprobante c
    LEFT JOIN totales t USING(nro_comprobante)
    WHERE t.nro_comprobante IS NULL OR c.subtotal<>t.bruto OR c.total<>t.neto OR c.descuento<>t.bruto-t.neto
  UNION ALL SELECT 'stock_deposito', count(*) FROM vino v
    LEFT JOIN ingresado i USING(cod_vino) LEFT JOIN transferido t USING(cod_vino)
    LEFT JOIN stock_deposito s USING(cod_vino)
    WHERE s.cod_vino IS NULL OR s.cantidad<>coalesce(i.cantidad,0)-coalesce(t.cantidad,0) OR s.cantidad<0
  UNION ALL SELECT 'stock_sala', count(*) FROM transferido_sala t
    FULL JOIN vendido_sala v USING(id_sala,cod_vino)
    FULL JOIN stock_sala s USING(id_sala,cod_vino)
    WHERE s.id_sala IS NULL OR s.cantidad<>coalesce(t.cantidad,0)-coalesce(v.cantidad,0) OR s.cantidad<0
  UNION ALL SELECT 'documentos_no_procesados',
    (SELECT count(*) FROM ingreso WHERE estado<>'procesado')+
    (SELECT count(*) FROM transferencia WHERE estado<>'procesado')
)
SELECT control,incumplimientos FROM controles ORDER BY control;
