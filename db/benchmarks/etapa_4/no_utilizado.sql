-- La ventana abarca todas las cabeceras y subtotal exige consultar la tabla.
EXPLAIN (ANALYZE, BUFFERS)
SELECT sum(total),sum(subtotal) FROM comprobante
WHERE fecha BETWEEN DATE '2025-04-01' AND DATE '2026-10-28';
