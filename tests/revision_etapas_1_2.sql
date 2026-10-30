-- Diagnóstico de vulneraciones. SOLO ejecutar en una base de prueba con los
-- fixtures de db_tests.sql y las migraciones 002 y 005 corregidas temporalmente.
-- Cada caso usa ROLLBACK: no modifica los archivos de migración ni conserva datos.
\set ON_ERROR_STOP on
\pset pager off

BEGIN;
UPDATE cliente SET descuento = 30 WHERE id_cliente = 1;
SELECT 'RN06: socio acepta 30%' AS hallazgo, tipo_cliente, descuento
FROM cliente WHERE id_cliente = 1;
ROLLBACK;

BEGIN;
INSERT INTO exportador VALUES (1, 'Chile');
SELECT 'Jerarquia: mismo cliente socio y exportador' AS hallazgo,
       EXISTS (SELECT FROM socio WHERE id_cliente=1) AS es_socio,
       EXISTS (SELECT FROM exportador WHERE id_cliente=1) AS es_exportador;
ROLLBACK;

BEGIN;
UPDATE comprobante SET total = 1 WHERE nro_comprobante = 1;
SELECT 'RN08: total manual' AS hallazgo, total FROM comprobante WHERE nro_comprobante=1;
ROLLBACK;

BEGIN;
UPDATE renglon_comprobante SET cantidad=10000 WHERE nro_comprobante=1;
SELECT 'RN08/09: UPDATE no descuenta stock ni recalcula' AS hallazgo,
       r.cantidad, s.cantidad AS stock, c.total
FROM renglon_comprobante r JOIN comprobante c USING(nro_comprobante)
JOIN stock_sala s ON s.id_sala=c.id_sala AND s.cod_vino=r.cod_vino
WHERE r.nro_comprobante=1;
ROLLBACK;

BEGIN;
INSERT INTO comprobante(nro_comprobante,id_cliente,id_sala) VALUES(90001,1,1);
INSERT INTO renglon_comprobante(nro_comprobante,cod_vino,cantidad,precio_unitario)
VALUES(90001,1,1,0.01);
SELECT 'RN01: precio arbitrario aceptado' AS hallazgo, r.precio_unitario, v.precio AS catalogo
FROM renglon_comprobante r JOIN vino v USING(cod_vino) WHERE nro_comprobante=90001;
ROLLBACK;

BEGIN;
INSERT INTO ingreso(cod_ingreso,cuit_bodega,cod_transportista,estado)
VALUES(90001,'30708090101',1,'terminado');
UPDATE ingreso SET estado='procesado' WHERE cod_ingreso=90001;
SELECT 'RN10: procesado sin procedimiento ni movimiento' AS hallazgo,estado
FROM ingreso WHERE cod_ingreso=90001;
ROLLBACK;

BEGIN;
INSERT INTO ingreso(cod_ingreso,cuit_bodega,cod_transportista,estado)
VALUES(90001,'30708090101',1,'en_confeccion');
UPDATE renglon_ingreso SET cod_ingreso=90001 WHERE cod_ingreso=1;
SELECT 'RN12: se retiro renglon de ingreso procesado' AS hallazgo,
       (SELECT count(*) FROM renglon_ingreso WHERE cod_ingreso=1) AS renglones_originales;
ROLLBACK;

BEGIN;
INSERT INTO vino(cod_vino,cuit_bodega,nombre,tipo,anada,volumen_ml,graduacion,precio)
VALUES(90001,'30708090101','Sin composicion','tinto',2025,750,13,100);
SET CONSTRAINTS ALL IMMEDIATE;
SELECT 'RN05: vino sin composicion pasa validacion' AS hallazgo, count(*) AS componentes
FROM composicion WHERE cod_vino=90001;
ROLLBACK;

BEGIN;
UPDATE vino SET precio=0.05 WHERE cod_vino IN(1,2);
INSERT INTO stock_sala(id_sala,cod_vino,cantidad) VALUES(1,2,10)
ON CONFLICT(id_sala,cod_vino) DO UPDATE SET cantidad=10;
INSERT INTO comprobante(nro_comprobante,id_cliente,id_sala) VALUES(90001,1,1);
INSERT INTO renglon_comprobante(nro_comprobante,cod_vino,cantidad)
VALUES(90001,1,1),(90001,2,1);
SELECT 'RN08: redondeo cabecera difiere de renglones' AS hallazgo,
       c.total, SUM(r.subtotal_renglon) AS suma_renglones
FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante)
WHERE nro_comprobante=90001 GROUP BY c.total;
ROLLBACK;

BEGIN;
SET LOCAL ROLE app_ro;
SELECT 'Rol lectura puede ejecutar nextval' AS hallazgo,
       has_sequence_privilege(current_user,'vino_cod_vino_seq','USAGE') AS puede_avanzar_secuencia;
ROLLBACK;

BEGIN;
CREATE FUNCTION public.audit_future_function() RETURNS integer
LANGUAGE sql AS 'SELECT 1';
SELECT 'Futuras funciones ejecutables por PUBLIC' AS hallazgo,
       has_function_privilege('app_ro','public.audit_future_function()','EXECUTE') AS lectura_puede_ejecutar;
ROLLBACK;
