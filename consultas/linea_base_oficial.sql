-- Consultas oficiales de select.sql. Usar la misma carga y parámetros en ambas mediciones.
-- Para S4 y S8, registrar CURRENT_DATE y mantener la misma fecha efectiva al comparar.
SELECT CURRENT_DATE fecha_referencia;
SELECT * FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname;
ANALYZE comprobante, renglon_comprobante, vino, sala_venta, transferencia,
        renglon_transferencia, lote_uva, parcela;

-- S1 oficial
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.cod_vino,v.nombre,sum(r.cantidad) botellas FROM vino v JOIN renglon_comprobante r USING(cod_vino) GROUP BY v.cod_vino ORDER BY botellas DESC,v.cod_vino LIMIT 10;

-- S4 oficial
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.id_sala,sum(r.cantidad) botellas FROM transferencia t JOIN renglon_transferencia r USING(nro_solicitud) WHERE r.cod_vino=1 AND t.fecha_confeccion BETWEEN CURRENT_DATE-14 AND CURRENT_DATE GROUP BY t.id_sala ORDER BY botellas DESC,t.id_sala LIMIT 5;

-- S8 oficial
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.id_sala,coalesce(sum(c.total),0) total FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala AND c.fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE GROUP BY s.id_sala ORDER BY total DESC,s.id_sala;

-- S10 oficial
EXPLAIN (ANALYZE, BUFFERS)
WITH rendimiento AS (SELECT l.id_finca,l.nro_parcela,l.campania,l.kilos/p.superficie kg_ha FROM lote_uva l JOIN parcela p USING(id_finca,nro_parcela)) SELECT r.*,r.kg_ha<(SELECT avg(f.kg_ha) FROM rendimiento f WHERE f.id_finca=r.id_finca AND f.campania=r.campania) bajo_promedio FROM rendimiento r ORDER BY id_finca,nro_parcela,campania;
