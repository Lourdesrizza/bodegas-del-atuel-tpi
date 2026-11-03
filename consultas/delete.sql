-- D1 · Purgar comprobantes históricos de socios
-- El purgado es de archivo y conserva stock. Requiere dueño de tablas.
BEGIN;
SELECT count(*) FROM comprobante c JOIN socio s USING(id_cliente) WHERE c.fecha<CURRENT_DATE-interval '5 years';
-- Cambiar el umbral de demostración si la base no tiene ventas de cinco años.
CREATE TEMP TABLE purga AS
SELECT c.nro_comprobante FROM comprobante c JOIN socio s USING(id_cliente)
WHERE c.fecha < CURRENT_DATE - CASE WHEN EXISTS (
  SELECT FROM comprobante h JOIN socio j USING(id_cliente)
  WHERE h.fecha<CURRENT_DATE-interval '5 years'
) THEN interval '5 years' ELSE interval '1 year' END;
CREATE TEMP TABLE stock_antes AS SELECT * FROM stock_sala;
SELECT count(*) cabeceras FROM purga;
SELECT count(*) renglones FROM renglon_comprobante JOIN purga USING(nro_comprobante);
ALTER TABLE comprobante DISABLE TRIGGER trg_comprobante_inmutable;
ALTER TABLE renglon_comprobante DISABLE TRIGGER trg_renglon_venta_inmutable;
DELETE FROM comprobante USING purga WHERE comprobante.nro_comprobante=purga.nro_comprobante;
SELECT count(*) cabeceras_restantes FROM comprobante JOIN purga USING(nro_comprobante);
SELECT count(*) renglones_restantes FROM renglon_comprobante JOIN purga USING(nro_comprobante);
SELECT NOT EXISTS (
  (SELECT * FROM stock_antes EXCEPT SELECT * FROM stock_sala)
  UNION ALL
  (SELECT * FROM stock_sala EXCEPT SELECT * FROM stock_antes)
) AS stock_sala_intacto;
ALTER TABLE comprobante ENABLE TRIGGER trg_comprobante_inmutable;
ALTER TABLE renglon_comprobante ENABLE TRIGGER trg_renglon_venta_inmutable;
ROLLBACK;

-- D2 · Eliminar cepas sin composición ni plantación
-- Dos NOT EXISTS excluyen las cepas referenciadas.
BEGIN;
SELECT count(*) FROM cepa c WHERE NOT EXISTS (SELECT FROM composicion v WHERE v.id_cepa=c.id_cepa) AND NOT EXISTS (SELECT FROM parcela p WHERE p.id_cepa=c.id_cepa);
DELETE FROM cepa c WHERE NOT EXISTS (SELECT FROM composicion v WHERE v.id_cepa=c.id_cepa) AND NOT EXISTS (SELECT FROM parcela p WHERE p.id_cepa=c.id_cepa);
SELECT count(*) FROM cepa c WHERE NOT EXISTS (SELECT FROM composicion v WHERE v.id_cepa=c.id_cepa) AND NOT EXISTS (SELECT FROM parcela p WHERE p.id_cepa=c.id_cepa);
ROLLBACK;

-- D3 · Eliminar empleados con menos de dos años de una sala dada de baja
-- Cambiar sala 1. El esquema no guarda fecha ni estado de baja.
BEGIN;
SELECT count(*) FROM empleado WHERE id_sala=1 AND fecha_ingreso>CURRENT_DATE-interval '2 years';
DELETE FROM empleado WHERE id_sala=1 AND fecha_ingreso>CURRENT_DATE-interval '2 years';
SELECT count(*) FROM empleado WHERE id_sala=1 AND fecha_ingreso>CURRENT_DATE-interval '2 years';
ROLLBACK;

-- D4 · Eliminar socios sin compras y con más de cinco años de alta
-- NOT EXISTS excluye clientes con comprobantes. CASCADE elimina el subtipo.
BEGIN;
SELECT count(*) FROM cliente s WHERE s.tipo_cliente='socio' AND s.fecha_alta<CURRENT_DATE-interval '5 years' AND NOT EXISTS (SELECT FROM comprobante c WHERE c.id_cliente=s.id_cliente);
DELETE FROM cliente s WHERE s.tipo_cliente='socio' AND s.fecha_alta<CURRENT_DATE-interval '5 years' AND NOT EXISTS (SELECT FROM comprobante c WHERE c.id_cliente=s.id_cliente);
SELECT count(*) FROM cliente s WHERE s.tipo_cliente='socio' AND s.fecha_alta<CURRENT_DATE-interval '5 years' AND NOT EXISTS (SELECT FROM comprobante c WHERE c.id_cliente=s.id_cliente);
ROLLBACK;

-- D5 · Eliminar ingresos procesados de hace más de 365 días
-- El CASCADE elimina renglones. Se conserva stock del depósito.
BEGIN;
SELECT count(*) FROM ingreso WHERE estado='procesado' AND fecha<CURRENT_DATE-365;
ALTER TABLE renglon_ingreso DISABLE TRIGGER trg_bloqueo_renglon_ingreso;
DELETE FROM ingreso WHERE estado='procesado' AND fecha<CURRENT_DATE-365;
ALTER TABLE renglon_ingreso ENABLE TRIGGER trg_bloqueo_renglon_ingreso;
SELECT count(*) FROM ingreso WHERE estado='procesado' AND fecha<CURRENT_DATE-365;
ROLLBACK;

-- D6 · Eliminar socios sin compras de una localidad
-- Cambiar General Alvear. CASCADE elimina el subtipo.
BEGIN;
SELECT count(*) FROM cliente s WHERE s.tipo_cliente='socio' AND s.id_localidad IN (SELECT id_localidad FROM localidad WHERE nombre='General Alvear' AND provincia='Mendoza') AND NOT EXISTS (SELECT FROM comprobante c WHERE c.id_cliente=s.id_cliente);
DELETE FROM cliente s WHERE s.tipo_cliente='socio' AND s.id_localidad IN (SELECT id_localidad FROM localidad WHERE nombre='General Alvear' AND provincia='Mendoza') AND NOT EXISTS (SELECT FROM comprobante c WHERE c.id_cliente=s.id_cliente);
SELECT count(*) FROM cliente s WHERE s.tipo_cliente='socio' AND s.id_localidad IN (SELECT id_localidad FROM localidad WHERE nombre='General Alvear' AND provincia='Mendoza') AND NOT EXISTS (SELECT FROM comprobante c WHERE c.id_cliente=s.id_cliente);
ROLLBACK;
