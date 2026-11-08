-- Ejecutar normalmente para ver resultados o con -v medir=1 para obtener también los planes.

-- S1 · Ranking de los 10 vinos más vendidos
-- Agrupa los renglones por vino y desempata por código.
SELECT v.cod_vino,v.nombre,sum(r.cantidad) botellas FROM vino v JOIN renglon_comprobante r USING(cod_vino) GROUP BY v.cod_vino ORDER BY botellas DESC,v.cod_vino LIMIT 10;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.cod_vino,v.nombre,sum(r.cantidad) botellas FROM vino v JOIN renglon_comprobante r USING(cod_vino) GROUP BY v.cod_vino ORDER BY botellas DESC,v.cod_vino LIMIT 10;
\endif

-- S2 · Vinos vendidos en todas las salas
-- Doble NOT EXISTS para la división relacional.
SELECT v.cod_vino,v.nombre FROM vino v WHERE NOT EXISTS (SELECT FROM sala_venta s WHERE NOT EXISTS (SELECT FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante) WHERE c.id_sala=s.id_sala AND r.cod_vino=v.cod_vino));

-- S3 · Clientes por tipo en la última semana
-- Cuenta clientes distintos y conserva tipos sin ventas. Cambiar sala 1.
SELECT t.tipo_cliente,count(DISTINCT c.id_cliente) clientes FROM tipo_cliente t LEFT JOIN cliente cl USING(tipo_cliente) LEFT JOIN comprobante c ON c.id_cliente=cl.id_cliente AND c.id_sala=1 AND c.fecha BETWEEN CURRENT_DATE-6 AND CURRENT_DATE GROUP BY t.tipo_cliente;

-- S4 · Top 5 de salas por botellas solicitadas en 15 días
-- Agrupa solicitudes por sala. Cambiar vino 1.
SELECT t.id_sala,sum(r.cantidad) botellas FROM transferencia t JOIN renglon_transferencia r USING(nro_solicitud) WHERE r.cod_vino=1 AND t.fecha_confeccion BETWEEN CURRENT_DATE-14 AND CURRENT_DATE GROUP BY t.id_sala ORDER BY botellas DESC,t.id_sala LIMIT 5;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.id_sala,sum(r.cantidad) botellas FROM transferencia t JOIN renglon_transferencia r USING(nro_solicitud) WHERE r.cod_vino=1 AND t.fecha_confeccion BETWEEN CURRENT_DATE-14 AND CURRENT_DATE GROUP BY t.id_sala ORDER BY botellas DESC,t.id_sala LIMIT 5;
\endif

-- S5 · Salas con el mínimo de transferencias pendientes
-- Incluye salas con cero pendientes y conserva empates.
WITH pendientes AS (SELECT s.id_sala,count(t.nro_solicitud) cantidad FROM sala_venta s LEFT JOIN transferencia t ON t.id_sala=s.id_sala AND t.estado<>'procesado' GROUP BY s.id_sala) SELECT * FROM pendientes WHERE cantidad=(SELECT min(cantidad) FROM pendientes) ORDER BY id_sala;

-- S6 · Vinos sin stock en la sala y disponibles en depósito
-- LEFT JOIN trata la fila de stock ausente como cero. Cambiar sala 1.
SELECT v.cod_vino,v.nombre,d.cantidad FROM stock_deposito d JOIN vino v USING(cod_vino) LEFT JOIN stock_sala s ON s.cod_vino=d.cod_vino AND s.id_sala=1 WHERE d.cantidad>0 AND coalesce(s.cantidad,0)=0 ORDER BY v.cod_vino;

-- S7 · Transportista con más ingresos en el último mes
-- Agrupa ingresos por transportista y conserva empates.
SELECT t.cod_transportista,t.razon_social,count(*) ingresos FROM transportista t JOIN ingreso i USING(cod_transportista) WHERE i.fecha BETWEEN CURRENT_DATE-interval '1 month' AND CURRENT_DATE GROUP BY t.cod_transportista ORDER BY ingresos DESC FETCH FIRST 1 ROW WITH TIES;

-- S8 · Ventas por sala en el último trimestre
-- LEFT JOIN conserva salas sin ventas.
SELECT s.id_sala,coalesce(sum(c.total),0) total FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala AND c.fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE GROUP BY s.id_sala ORDER BY total DESC,s.id_sala;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.id_sala,coalesce(sum(c.total),0) total FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala AND c.fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE GROUP BY s.id_sala ORDER BY total DESC,s.id_sala;
\endif

-- S9 · Ficha de vino
-- La vista aporta stock. Subconsultas separadas evitan multiplicar cepas y maridajes. Cambiar vino 1.
SELECT v.cod_vino,v.nombre,b.razon_social,s.stock_total,
 (SELECT jsonb_agg(jsonb_build_object('cepa',ce.nombre,'porcentaje',c.porcentaje) ORDER BY ce.nombre) FROM composicion c JOIN cepa ce USING(id_cepa) WHERE c.cod_vino=v.cod_vino) cepas,
 (SELECT jsonb_agg(m.nombre ORDER BY m.nombre) FROM vino_maridaje vm JOIN maridaje m USING(id_maridaje) WHERE vm.cod_vino=v.cod_vino) maridajes
FROM vino v JOIN bodega b ON b.cuit=v.cuit_bodega JOIN v_stock_total_vino s USING(cod_vino) WHERE v.cod_vino=1;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.cod_vino,v.nombre,b.razon_social,s.stock_total,
 (SELECT jsonb_agg(jsonb_build_object('cepa',ce.nombre,'porcentaje',c.porcentaje) ORDER BY ce.nombre) FROM composicion c JOIN cepa ce USING(id_cepa) WHERE c.cod_vino=v.cod_vino) cepas,
 (SELECT jsonb_agg(m.nombre ORDER BY m.nombre) FROM vino_maridaje vm JOIN maridaje m USING(id_maridaje) WHERE vm.cod_vino=v.cod_vino) maridajes
FROM vino v JOIN bodega b ON b.cuit=v.cuit_bodega JOIN v_stock_total_vino s USING(cod_vino) WHERE v.cod_vino=1;
\endif

-- S10 · Rendimiento por parcela y campaña frente al promedio de su finca
-- La CTE calcula kg/ha y la subconsulta correlacionada compara dentro de la misma campaña.
WITH rendimiento AS (SELECT l.id_finca,l.nro_parcela,l.campania,l.kilos/p.superficie kg_ha FROM lote_uva l JOIN parcela p USING(id_finca,nro_parcela)) SELECT r.*,r.kg_ha<(SELECT avg(f.kg_ha) FROM rendimiento f WHERE f.id_finca=r.id_finca AND f.campania=r.campania) bajo_promedio FROM rendimiento r ORDER BY id_finca,nro_parcela,campania;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
WITH rendimiento AS (SELECT l.id_finca,l.nro_parcela,l.campania,l.kilos/p.superficie kg_ha FROM lote_uva l JOIN parcela p USING(id_finca,nro_parcela)) SELECT r.*,r.kg_ha<(SELECT avg(f.kg_ha) FROM rendimiento f WHERE f.id_finca=r.id_finca AND f.campania=r.campania) bajo_promedio FROM rendimiento r ORDER BY id_finca,nro_parcela,campania;
\endif

-- S11 · Ranking por sala y ventas mensuales acumuladas
-- RANK conserva empates. La suma de montos mensuales usa una ventana por sala.
WITH ventas AS (SELECT c.id_sala,r.cod_vino,sum(r.cantidad) botellas FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante) GROUP BY c.id_sala,r.cod_vino) SELECT *,rank() OVER(PARTITION BY id_sala ORDER BY botellas DESC) puesto FROM ventas ORDER BY id_sala,puesto,cod_vino;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas AS (SELECT c.id_sala,r.cod_vino,sum(r.cantidad) botellas FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante) GROUP BY c.id_sala,r.cod_vino) SELECT *,rank() OVER(PARTITION BY id_sala ORDER BY botellas DESC) puesto FROM ventas ORDER BY id_sala,puesto,cod_vino;
\endif

WITH meses AS (SELECT id_sala,date_trunc('month',fecha)::date mes,sum(total) total FROM comprobante GROUP BY id_sala,date_trunc('month',fecha)::date) SELECT *,sum(total) OVER(PARTITION BY id_sala ORDER BY mes ROWS UNBOUNDED PRECEDING) acumulado FROM meses ORDER BY id_sala,mes;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
WITH meses AS (SELECT id_sala,date_trunc('month',fecha)::date mes,sum(total) total FROM comprobante GROUP BY id_sala,date_trunc('month',fecha)::date) SELECT *,sum(total) OVER(PARTITION BY id_sala ORDER BY mes ROWS UNBOUNDED PRECEDING) acumulado FROM meses ORDER BY id_sala,mes;
\endif

-- S12 · Clientes que compraron todos los vinos de una bodega y clientes sin compras de tintos
-- Doble NOT EXISTS para la bodega y anti-join para tintos. Cambiar el selector de bodega.
WITH objetivo AS (
  SELECT cod_vino FROM vino
  WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1)
), compras AS (
  SELECT c.id_cliente,array_agg(DISTINCT r.cod_vino) vinos
  FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante)
  JOIN objetivo v USING(cod_vino)
  GROUP BY c.id_cliente
)
SELECT c.id_cliente FROM compras c
WHERE NOT EXISTS (
  SELECT FROM objetivo v WHERE NOT EXISTS (
    SELECT FROM unnest(c.vinos) compra(cod_vino) WHERE compra.cod_vino=v.cod_vino
  )
)
ORDER BY c.id_cliente;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
WITH objetivo AS (
  SELECT cod_vino FROM vino
  WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1)
), compras AS (
  SELECT c.id_cliente,array_agg(DISTINCT r.cod_vino) vinos
  FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante)
  JOIN objetivo v USING(cod_vino)
  GROUP BY c.id_cliente
)
SELECT c.id_cliente FROM compras c
WHERE NOT EXISTS (
  SELECT FROM objetivo v WHERE NOT EXISTS (
    SELECT FROM unnest(c.vinos) compra(cod_vino) WHERE compra.cod_vino=v.cod_vino
  )
)
ORDER BY c.id_cliente;
\endif

WITH compradores_tinto AS (SELECT DISTINCT c.id_cliente FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante) JOIN vino v USING(cod_vino) WHERE v.tipo='tinto') SELECT cl.id_cliente FROM cliente cl LEFT JOIN compradores_tinto t USING(id_cliente) WHERE t.id_cliente IS NULL ORDER BY cl.id_cliente;
\if :{?medir}
EXPLAIN (ANALYZE, BUFFERS)
WITH compradores_tinto AS (SELECT DISTINCT c.id_cliente FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante) JOIN vino v USING(cod_vino) WHERE v.tipo='tinto') SELECT cl.id_cliente FROM cliente cl LEFT JOIN compradores_tinto t USING(id_cliente) WHERE t.id_cliente IS NULL ORDER BY cl.id_cliente;
\endif
