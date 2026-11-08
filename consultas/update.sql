-- U1 · Recalcular el total de todos los comprobantes
-- Concilia únicamente el total según RN-08 con el precio y descuento históricos.
-- fn_total_comprobante suma importes históricos. El criterio requiere validación docente.
-- Una diferencia en subtotal o descuento de cabecera exige otra conciliación.
BEGIN;
SELECT count(*) comprobantes,count(*) FILTER (WHERE c.total IS DISTINCT FROM f.total) diferencias
FROM comprobante c CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f;
ALTER TABLE comprobante DISABLE TRIGGER trg_comprobante_inmutable;
WITH calculados AS (
  SELECT c.nro_comprobante,f.total FROM comprobante c
  CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f
)
UPDATE comprobante c SET total=x.total FROM calculados x
WHERE c.nro_comprobante=x.nro_comprobante AND c.total IS DISTINCT FROM x.total;
SELECT count(*) comprobantes,count(*) FILTER (WHERE c.total IS DISTINCT FROM f.total) diferencias
FROM comprobante c CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f;
ALTER TABLE comprobante ENABLE TRIGGER trg_comprobante_inmutable;
ROLLBACK;

-- U2 · Aumentar 20 % el salario con más de cinco años de antigüedad
-- Compara la fecha exacta con el umbral relativo.
BEGIN;
SELECT count(*),sum(salario) FROM empleado WHERE fecha_ingreso<CURRENT_DATE-interval '5 years';
UPDATE empleado SET salario=round(salario*1.20,2) WHERE fecha_ingreso<CURRENT_DATE-interval '5 years';
SELECT count(*),sum(salario) FROM empleado WHERE fecha_ingreso<CURRENT_DATE-interval '5 years';
ROLLBACK;

-- U3 · Aumentar 13 % el precio de los vinos de una bodega
-- Cambiar el selector de bodega. El trigger registra los cambios de precio.
BEGIN;
SELECT count(*),sum(precio) FROM vino WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1);
UPDATE vino SET precio=round(precio*1.13,2) WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1);
SELECT count(*),sum(precio) FROM vino WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1);
ROLLBACK;

-- U4 · Intercambiar lunes y miércoles como día de cierre
-- CASE evalúa el valor original en una sola sentencia.
BEGIN;
SELECT dia_cierre,count(*) FROM sala_venta WHERE lower(dia_cierre) IN ('lunes','miércoles','miercoles') GROUP BY dia_cierre;
UPDATE sala_venta SET dia_cierre=CASE WHEN lower(dia_cierre)='lunes' THEN 'Miércoles' ELSE 'Lunes' END WHERE lower(dia_cierre) IN ('lunes','miércoles','miercoles');
SELECT dia_cierre,count(*) FROM sala_venta WHERE lower(dia_cierre) IN ('lunes','miércoles','miercoles') GROUP BY dia_cierre;
ROLLBACK;

-- U5 · Reducir 15 % el precio de los diez vinos menos vendidos
-- Incluye vinos sin ventas y desempata por código.
BEGIN;
SELECT cod_vino,precio FROM vino WHERE cod_vino IN (SELECT v.cod_vino FROM vino v LEFT JOIN renglon_comprobante r USING(cod_vino)
GROUP BY v.cod_vino ORDER BY coalesce(sum(r.cantidad),0),v.cod_vino LIMIT 10) ORDER BY cod_vino;
UPDATE vino SET precio=round(precio*0.85,2) WHERE cod_vino IN (SELECT v.cod_vino FROM vino v LEFT JOIN renglon_comprobante r USING(cod_vino)
GROUP BY v.cod_vino ORDER BY coalesce(sum(r.cantidad),0),v.cod_vino LIMIT 10);
SELECT cod_vino,precio FROM vino WHERE cod_vino IN (SELECT v.cod_vino FROM vino v LEFT JOIN renglon_comprobante r USING(cod_vino)
GROUP BY v.cod_vino ORDER BY coalesce(sum(r.cantidad),0),v.cod_vino LIMIT 10) ORDER BY cod_vino;
ROLLBACK;

-- U6 · Subir a 35 % el descuento de exportadores con más de tres permisos
-- La prueba de ventas aplica el cuerpo de la propuesta 009 y revierte todo.
\ir pruebas/u6.sql