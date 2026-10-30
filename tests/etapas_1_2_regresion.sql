-- Ejecutar SOLO en una base de prueba recién migrada. No limpia bases existentes.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO localidad(codigo_postal,nombre,provincia,encargado_regional) VALUES('5600','San Rafael','Mendoza','Responsable');
INSERT INTO sala_venta(id_localidad,calle,numero,dia_cierre) VALUES(1,'Mitre','1','Lunes');
INSERT INTO empleado VALUES('20304050601',1,'Empleado',CURRENT_DATE,100);
INSERT INTO finca(nombre,superficie_ha,departamento,provincia) VALUES('Finca',10,'San Rafael','Mendoza');
INSERT INTO cepa(nombre,tipo) VALUES('Malbec','tinta');
INSERT INTO parcela VALUES(1,1,1,2,2010);
INSERT INTO bodega VALUES('30708090101','Bodega','Domicilio');
INSERT INTO transportista(cuit,razon_social,domicilio,email,telefono)
 VALUES('30554433221','Transporte','Domicilio','test@example.invalid','1');
INSERT INTO cliente(id_localidad,nombre_o_razon_social,tipo_doc,numero_doc,domicilio,fecha_alta,tipo_cliente)
 VALUES(1,'Cliente','DNI','1','Domicilio',CURRENT_DATE,'socio');
INSERT INTO socio VALUES(1);
INSERT INTO vino(cuit_bodega,nombre,tipo,anada,volumen_ml,graduacion,precio)
 VALUES('30708090101','Vino','tinto',2024,750,13,0.05);
INSERT INTO composicion VALUES(1,1,100);
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO stock_sala VALUES(1,1,2);
INSERT INTO comprobante(id_cliente,id_sala) VALUES(1,1);
INSERT INTO renglon_comprobante(nro_comprobante,cod_vino,cantidad,precio_unitario,descuento_aplicado,subtotal_renglon)
 VALUES(1,1,2,999,99,999);
DO $$ BEGIN
 IF (SELECT precio_unitario FROM renglon_comprobante WHERE nro_comprobante=1)<>0.05 OR
    (SELECT descuento_aplicado FROM renglon_comprobante WHERE nro_comprobante=1)<>10 OR
    (SELECT total FROM comprobante WHERE nro_comprobante=1)<>0.09 OR
    (SELECT cantidad FROM stock_sala WHERE id_sala=1 AND cod_vino=1)<>0 THEN
   RAISE EXCEPTION 'RN-01/06/08/09: precio, descuento, total o stock incorrecto';
 END IF;
END $$;
-- Dos netos de 0,05 se suman a 0,10; aplicar 10 % al bruto global daría 0,09.
INSERT INTO cepa(nombre,tipo) VALUES('Cabernet','tinta');
INSERT INTO vino(cuit_bodega,nombre,tipo,anada,volumen_ml,graduacion,precio)
 VALUES('30708090101','Vino 2','tinto',2024,750,13,0.05);
INSERT INTO composicion VALUES(2,2,100);
INSERT INTO stock_sala VALUES(1,2,1);
INSERT INTO stock_sala VALUES(1,1,1) ON CONFLICT(id_sala,cod_vino) DO UPDATE SET cantidad=1;
INSERT INTO comprobante(id_cliente,id_sala) VALUES(1,1);
INSERT INTO renglon_comprobante VALUES(2,1,1,0,0,0),(2,2,1,0,0,0);
DO $$ BEGIN
 IF (SELECT total FROM comprobante WHERE nro_comprobante=2)<>0.10 THEN
   RAISE EXCEPTION 'RN-08: redondeo multirrenglón'; END IF;
END $$;
DO $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN UPDATE composicion SET cod_vino=2 WHERE cod_vino=1;
 EXECUTE 'SET CONSTRAINTS ALL IMMEDIATE';
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-05: cambio de vino dejó corte inválido'; END IF;
END $$;
-- Casos negativos con indicador fuera del bloque EXCEPTION.
DO $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN INSERT INTO sala_venta(id_localidad,calle,numero,dia_cierre) VALUES(999,'X','1','Lunes');
 EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-02: localidad inexistente aceptada'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO empleado(cuit,id_sala,nombre,fecha_ingreso,salario)
 VALUES('20999999991',NULL,'X',CURRENT_DATE,100);
 EXCEPTION WHEN not_null_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-03: empleado sin sala aceptado'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO lote_uva(id_finca,nro_parcela,cuit_bodega,campania,fecha_cosecha,kilos)
 VALUES(1,1,'30708090101',2024,CURRENT_DATE,1);
 INSERT INTO lote_uva(id_finca,nro_parcela,cuit_bodega,campania,fecha_cosecha,kilos)
 VALUES(1,1,'30708090101',2024,CURRENT_DATE,1);
 EXCEPTION WHEN unique_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-04: cosecha duplicada aceptada'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO vino(cuit_bodega,nombre,tipo,anada,volumen_ml,graduacion,precio)
 VALUES('30708090101','Sin corte','tinto',2024,750,13,10);
 EXECUTE 'SET CONSTRAINTS ALL IMMEDIATE';
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-05: vino sin corte aceptado'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO vino(cuit_bodega,nombre,tipo,anada,volumen_ml,graduacion,precio)
 VALUES('30708090101','Precio inválido','tinto',2024,750,13,0);
 EXCEPTION WHEN check_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-01: precio no positivo aceptado'; END IF;
 rechazado:=false;
 BEGIN UPDATE tipo_cliente SET descuento=30 WHERE tipo_cliente='socio';
 EXCEPTION WHEN check_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-06: descuento incompatible aceptado'; END IF;
END $$;

-- El marcador se comprueba FUERA del bloque que captura el error esperado.
DO $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN UPDATE comprobante SET total=1 WHERE nro_comprobante=1;
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-08: total manual aceptado'; END IF;
 rechazado:=false;
 BEGIN UPDATE renglon_comprobante SET cantidad=3 WHERE nro_comprobante=1;
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-09: edición de venta aceptada'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO renglon_comprobante VALUES(1,1,1,1,1,1);
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-09: venta sin stock aceptada'; END IF;
END $$;

INSERT INTO ingreso(cuit_bodega,cod_transportista) VALUES('30708090101',1);
INSERT INTO renglon_ingreso VALUES(1,1,3);
CALL sp_terminar_ingreso(1);
CALL sp_procesar_ingreso(1);
DO $$ BEGIN
 IF (SELECT cantidad FROM stock_deposito WHERE cod_vino=1)<>3 THEN RAISE EXCEPTION 'RN-10 stock'; END IF;
END $$;
INSERT INTO transferencia(id_sala) VALUES(1);
INSERT INTO renglon_transferencia VALUES(1,1,2);
CALL sp_terminar_transferencia(1);
CALL sp_procesar_transferencia(1);
DO $$ BEGIN
 IF (SELECT cantidad FROM stock_deposito WHERE cod_vino=1)<>1 OR
    (SELECT cantidad FROM stock_sala WHERE id_sala=1 AND cod_vino=1)<>2 THEN
   RAISE EXCEPTION 'RN-11 stock'; END IF;
END $$;
INSERT INTO ingreso(cuit_bodega,cod_transportista) VALUES('30708090101',1);
INSERT INTO transferencia(id_sala) VALUES(1);
DO $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN UPDATE renglon_ingreso SET cod_ingreso=2 WHERE cod_ingreso=1;
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-12: movió renglón desde ingreso cerrado'; END IF;
 rechazado:=false;
 BEGIN UPDATE renglon_transferencia SET nro_solicitud=2 WHERE nro_solicitud=1;
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-12: movió renglón desde transferencia cerrada'; END IF;
END $$;
INSERT INTO transferencia(id_sala) VALUES(1);
INSERT INTO renglon_transferencia VALUES(3,1,100);
CALL sp_terminar_transferencia(3);
DO $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN CALL sp_procesar_transferencia(3);
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-11: falta de stock aceptada'; END IF;
 IF (SELECT estado FROM transferencia WHERE nro_solicitud=3)<>'terminado' OR
    (SELECT cantidad FROM stock_deposito WHERE cod_vino=1)<>1 THEN
   RAISE EXCEPTION 'RN-11: falta de atomicidad'; END IF;
END $$;
DO $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN UPDATE ingreso SET estado='procesado' WHERE cod_ingreso=1;
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-10: transición directa aceptada'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO exportador VALUES(1,'Chile'); EXECUTE 'SET CONSTRAINTS ALL IMMEDIATE';
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-06: subtipo incompatible aceptado'; END IF;
END $$;
INSERT INTO cliente(id_localidad,nombre_o_razon_social,tipo_doc,numero_doc,domicilio,tipo_cliente)
 VALUES(1,'Exportador','CUIT','2','Domicilio','exportador');
INSERT INTO exportador VALUES(2,'Chile');
INSERT INTO permiso_exportacion VALUES('P1',2,CURRENT_DATE-10,CURRENT_DATE+10);
INSERT INTO permiso_exportacion VALUES('P2',2,CURRENT_DATE-10,CURRENT_DATE+10);
DO $$ DECLARE rechazado boolean:=false; BEGIN
 IF (SELECT count(*) FROM permiso_exportacion WHERE id_cliente=2)<>2 THEN
   RAISE EXCEPTION 'RN-07: múltiples permisos'; END IF;
 BEGIN INSERT INTO permiso_exportacion VALUES('P3',2,CURRENT_DATE,CURRENT_DATE-1);
 EXCEPTION WHEN check_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-07: fechas inválidas aceptadas'; END IF;
 rechazado:=false;
 BEGIN UPDATE renglon_ingreso SET cantidad=4 WHERE cod_ingreso=1;
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-12: cambio en ingreso procesado'; END IF;
 rechazado:=false;
 BEGIN UPDATE renglon_transferencia SET cantidad=4 WHERE nro_solicitud=1;
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-12: cambio en transferencia procesada'; END IF;
 rechazado:=false;
 BEGIN DELETE FROM vino WHERE cod_vino=1;
 EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-14: vino con movimientos borrado'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO finca(nombre,superficie_ha,departamento,provincia) VALUES('Mala',0,'X','X');
 EXCEPTION WHEN check_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-15: superficie cero aceptada'; END IF;
END $$;
UPDATE vino SET precio=0.06 WHERE cod_vino=1;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM auditoria_precio WHERE cod_vino=1
   AND precio_anterior=0.05 AND precio_nuevo=0.06) THEN RAISE EXCEPTION 'RN-13: auditoría ausente'; END IF;
END $$;
DO $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN UPDATE transferencia SET fecha_confeccion=CURRENT_DATE-1 WHERE nro_solicitud=1;
 EXCEPTION WHEN raise_exception THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-11: fecha de transferencia editable'; END IF;
 rechazado:=false;
 BEGIN DELETE FROM bodega WHERE cuit='30708090101';
 EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-14: bodega con movimientos borrada'; END IF;
 rechazado:=false;
 BEGIN DELETE FROM transportista WHERE cod_transportista=1;
 EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-14: transportista con movimientos borrado'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO lote_uva(id_finca,nro_parcela,cuit_bodega,campania,fecha_cosecha,kilos)
 VALUES(1,1,'30708090101',2025,CURRENT_DATE,0);
 EXCEPTION WHEN check_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-15: kilos cero aceptados'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO vino(cuit_bodega,nombre,tipo,anada,volumen_ml,graduacion,precio)
 VALUES('30708090101','Alcohol inválido','tinto',2024,750,25,10);
 EXCEPTION WHEN check_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-15: graduación inválida aceptada'; END IF;
 rechazado:=false;
 BEGIN INSERT INTO renglon_ingreso VALUES(2,2,0);
 EXCEPTION WHEN check_violation THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'RN-15: cantidad cero aceptada'; END IF;
END $$;
UPDATE cliente SET tipo_cliente='exportador' WHERE id_cliente=1;
DELETE FROM socio WHERE id_cliente=1;
INSERT INTO exportador VALUES(1,'Uruguay');
SET CONSTRAINTS ALL IMMEDIATE;
DO $$ BEGIN
 IF (SELECT total FROM fn_total_comprobante(1))<>0.09 OR
    (SELECT descuento_aplicado FROM renglon_comprobante WHERE nro_comprobante=1)<>10 THEN
   RAISE EXCEPTION 'RN-06/08: cambió una venta histórica'; END IF;
END $$;
SET ROLE app_owner;
CREATE FUNCTION prueba_privilegio_futuro() RETURNS integer LANGUAGE sql AS 'SELECT 1';
RESET ROLE;
DO $$ BEGIN
 IF has_function_privilege('app_ro','prueba_privilegio_futuro()','EXECUTE') OR
    has_sequence_privilege('app_ro','localidad_id_localidad_seq','USAGE') THEN
   RAISE EXCEPTION 'Permisos: lectura ejecuta función futura o avanza secuencia'; END IF;
END $$;
SET ROLE app_rw;
DO $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN UPDATE stock_sala SET cantidad=100 WHERE id_sala=1;
 EXCEPTION WHEN insufficient_privilege THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'Permisos: API editó stock'; END IF;
 rechazado:=false;
 BEGIN DELETE FROM auditoria_precio;
 EXCEPTION WHEN insufficient_privilege THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'Permisos: API borró auditoría'; END IF;
 rechazado:=false;
 BEGIN UPDATE comprobante SET total=1 WHERE nro_comprobante=1;
 EXCEPTION WHEN insufficient_privilege THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'Permisos: API editó total'; END IF;
END $$;
RESET ROLE;
SET ROLE app_ro;
DO $$ DECLARE rechazado boolean:=false; BEGIN
 IF (SELECT count(*) FROM vino)<2 THEN RAISE EXCEPTION 'Permisos: lectura falló'; END IF;
 BEGIN INSERT INTO stock_sala VALUES(1,1,1);
 EXCEPTION WHEN insufficient_privilege THEN rechazado:=true; END;
 IF NOT rechazado THEN RAISE EXCEPTION 'Permisos: app_ro escribió stock'; END IF;
END $$;
RESET ROLE;
ROLLBACK;
