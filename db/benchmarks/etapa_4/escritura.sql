-- Se ejecuta sobre un clon fresco que ya contiene 150.000 cabeceras.
-- EXPLAIN incluye la escritura real, los índices y las verificaciones FK.
EXPLAIN (ANALYZE, BUFFERS, WAL, FORMAT JSON)
INSERT INTO comprobante(nro_comprobante,id_cliente,id_sala,fecha,subtotal,descuento,total)
SELECT nro_comprobante+150000,id_cliente,id_sala,fecha,subtotal,descuento,total
FROM comprobante ORDER BY nro_comprobante;
