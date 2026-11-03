-- U1 · Recalcular el total de todos los comprobantes
-- Usa el descuento histórico aplicado a los renglones. Actualiza solo diferencias. Requiere dueño de tablas.
BEGIN;
SELECT count(*) comprobantes,count(*) FILTER (WHERE c.total IS DISTINCT FROM f.total) diferencias
FROM comprobante c CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f;
ALTER TABLE comprobante DISABLE TRIGGER trg_comprobante_inmutable;
ALTER TABLE renglon_comprobante DISABLE TRIGGER trg_renglon_venta_inmutable;
WITH calculados AS (
  SELECT c.nro_comprobante,f.total FROM comprobante c
  CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f
)
UPDATE comprobante c SET total=x.total FROM calculados x
WHERE c.nro_comprobante=x.nro_comprobante AND c.total IS DISTINCT FROM x.total;
SELECT count(*) comprobantes,count(*) FILTER (WHERE c.total IS DISTINCT FROM f.total) diferencias
FROM comprobante c CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f;
ALTER TABLE comprobante ENABLE TRIGGER trg_comprobante_inmutable;
ALTER TABLE renglon_comprobante ENABLE TRIGGER trg_renglon_venta_inmutable;
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
-- RN-06 fija 30 %. El catálogo es compartido. Una columna temporal por exportador
-- permite demostrar la excepción sin subir el descuento del resto.
BEGIN;
ALTER TABLE tipo_cliente DROP CONSTRAINT tipo_cliente_check,
  ADD CONSTRAINT tipo_cliente_check CHECK (
    (tipo_cliente='socio' AND descuento=10) OR
    (tipo_cliente='distribuidor' AND descuento=20) OR
    (tipo_cliente='exportador' AND descuento IN (30,35)));
ALTER TABLE exportador ADD COLUMN descuento NUMERIC(5,2) NOT NULL DEFAULT 30
  CONSTRAINT ck_exportador_descuento CHECK (descuento IN (30,35));
SELECT e.descuento,count(*) exportadores
FROM exportador e WHERE e.id_cliente IN (SELECT id_cliente FROM permiso_exportacion GROUP BY id_cliente HAVING count(*)>3)
GROUP BY e.descuento;
UPDATE exportador SET descuento=35
WHERE id_cliente IN (SELECT id_cliente FROM permiso_exportacion GROUP BY id_cliente HAVING count(*)>3);
SELECT e.descuento,count(*) exportadores
FROM exportador e WHERE e.id_cliente IN (SELECT id_cliente FROM permiso_exportacion GROUP BY id_cliente HAVING count(*)>3)
GROUP BY e.descuento;
-- Demostración adicional cuando la carga no tiene exportadores elegibles.
-- Se agregan permisos ficticios a un solo exportador y se vuelven a contar.
INSERT INTO permiso_exportacion(cod_permiso,id_cliente,fecha_emision,fecha_vencimiento)
SELECT 'ETAPA5-U6-' || n, e.id_cliente, CURRENT_DATE, CURRENT_DATE+365
FROM (SELECT id_cliente FROM exportador ORDER BY id_cliente LIMIT 1) e
CROSS JOIN generate_series(1,4) n
WHERE NOT EXISTS (
  SELECT FROM permiso_exportacion GROUP BY id_cliente HAVING count(*)>3
);
SELECT descuento,count(*) FROM exportador GROUP BY descuento ORDER BY descuento;
UPDATE exportador SET descuento=35
WHERE descuento<>35 AND id_cliente IN (
  SELECT id_cliente FROM permiso_exportacion GROUP BY id_cliente HAVING count(*)>3
);
SELECT descuento,count(*) FROM exportador GROUP BY descuento ORDER BY descuento;
ROLLBACK;
