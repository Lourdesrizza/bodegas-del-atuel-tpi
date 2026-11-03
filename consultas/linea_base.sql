-- Variantes históricas para repetir la comparación con los mismos parámetros.
-- Ejecutar en laboratorio y comprobar el catálogo de índices.
SELECT CURRENT_DATE fecha_de_ejecucion;
SELECT * FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname;
ANALYZE comprobante, renglon_comprobante, vino, sala_venta, transferencia,
        renglon_transferencia, lote_uva, parcela;
-- S1 histórica · Ranking trimestral, distinto del ranking general oficial.
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.cod_vino,v.nombre,sum(r.cantidad) botellas FROM vino v JOIN renglon_comprobante r USING(cod_vino) JOIN comprobante c USING(nro_comprobante) WHERE c.fecha BETWEEN DATE '2026-07-28' AND DATE '2026-10-28' GROUP BY v.cod_vino ORDER BY botellas DESC,v.cod_vino LIMIT 10;

-- S4 · Quince días con transferencias
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.id_sala,sum(r.cantidad) botellas FROM transferencia t JOIN renglon_transferencia r USING(nro_solicitud) WHERE r.cod_vino=1 AND t.fecha_confeccion BETWEEN DATE '2025-02-16' AND DATE '2025-03-02' GROUP BY t.id_sala ORDER BY botellas DESC,t.id_sala LIMIT 5;

-- S8 · Ventas del trimestre histórico
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.id_sala,coalesce(sum(c.total),0) total FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala AND c.fecha BETWEEN DATE '2026-07-28' AND DATE '2026-10-28' GROUP BY s.id_sala ORDER BY total DESC,s.id_sala;

-- S10 · Cosechas de la campaña 2024
EXPLAIN (ANALYZE, BUFFERS)
WITH rendimiento AS (SELECT l.id_finca,l.nro_parcela,l.campania,l.kilos/p.superficie kg_ha FROM lote_uva l JOIN parcela p USING(id_finca,nro_parcela) WHERE l.fecha_cosecha >= DATE '2024-01-01' AND l.fecha_cosecha < DATE '2025-01-01') SELECT r.*,r.kg_ha<(SELECT avg(f.kg_ha) FROM rendimiento f WHERE f.id_finca=r.id_finca AND f.campania=r.campania) bajo_promedio FROM rendimiento r ORDER BY id_finca,nro_parcela,campania;
