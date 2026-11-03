-- S1 oficial · Ranking general, sin filtro de fecha.
SELECT v.cod_vino,v.nombre,sum(r.cantidad) botellas
FROM vino v JOIN renglon_comprobante r USING(cod_vino)
GROUP BY v.cod_vino ORDER BY botellas DESC,v.cod_vino LIMIT 10;

-- S3 benchmark · Sala 1, semana que termina el 28/10/2026.
SELECT t.tipo_cliente,count(DISTINCT c.id_cliente) clientes
FROM tipo_cliente t LEFT JOIN cliente cl USING(tipo_cliente)
LEFT JOIN comprobante c ON c.id_cliente=cl.id_cliente AND c.id_sala=1
  AND c.fecha BETWEEN DATE '2026-10-22' AND DATE '2026-10-28'
GROUP BY t.tipo_cliente;

-- S4 histórica · Vino 1, quince días que incluyen las transferencias cargadas.
SELECT t.id_sala,sum(r.cantidad) botellas
FROM transferencia t JOIN renglon_transferencia r USING(nro_solicitud)
WHERE r.cod_vino=1 AND t.fecha_confeccion BETWEEN DATE '2025-02-16' AND DATE '2025-03-02'
GROUP BY t.id_sala ORDER BY botellas DESC,t.id_sala LIMIT 5;

-- S8 histórica · Ventas por sala en el trimestre de referencia.
SELECT s.id_sala,coalesce(sum(c.total),0) total
FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala
  AND c.fecha BETWEEN DATE '2026-07-28' AND DATE '2026-10-28'
GROUP BY s.id_sala ORDER BY total DESC,s.id_sala;

-- S10 oficial · Rendimiento por parcela frente al promedio de su finca y campaña.
WITH rendimiento AS (
  SELECT l.id_finca,l.nro_parcela,l.campania,l.kilos/p.superficie kg_ha
  FROM lote_uva l JOIN parcela p USING(id_finca,nro_parcela)
)
SELECT r.*,r.kg_ha<(SELECT avg(f.kg_ha) FROM rendimiento f
                    WHERE f.id_finca=r.id_finca AND f.campania=r.campania) bajo_promedio
FROM rendimiento r ORDER BY id_finca,nro_parcela,campania;
