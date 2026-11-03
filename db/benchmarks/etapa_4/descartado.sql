-- Candidato descartado. Se prueba aislado contra el B-tree elegido para S8.
BEGIN;
SELECT attname, correlation FROM pg_stats
WHERE schemaname='public' AND tablename='comprobante' AND attname='fecha';
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.id_sala,coalesce(sum(c.total),0) total
FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala
  AND c.fecha BETWEEN DATE '2026-07-28' AND DATE '2026-10-28'
GROUP BY s.id_sala ORDER BY total DESC,s.id_sala;
CREATE INDEX candidato_comprobante_fecha_brin ON comprobante USING brin(fecha);
ANALYZE comprobante;
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.id_sala,coalesce(sum(c.total),0) total
FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala
  AND c.fecha BETWEEN DATE '2026-07-28' AND DATE '2026-10-28'
GROUP BY s.id_sala ORDER BY total DESC,s.id_sala;
ROLLBACK;
