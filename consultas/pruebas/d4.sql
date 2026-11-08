BEGIN;
CREATE TEMP TABLE d4_clientes AS
WITH altas AS (
  INSERT INTO cliente(id_localidad,nombre_o_razon_social,tipo_doc,numero_doc,domicilio,fecha_alta,tipo_cliente)
  VALUES (1,'ETAPA5 D4 antiguo','DNI','99000041','Ensayo',CURRENT_DATE-interval '6 years','socio'),
         (1,'ETAPA5 D4 límite','DNI','99000042','Ensayo',CURRENT_DATE-interval '5 years','socio'),
         (1,'ETAPA5 D4 comprador','DNI','99000043','Ensayo',CURRENT_DATE-interval '6 years','socio')
  RETURNING id_cliente,nombre_o_razon_social
) SELECT * FROM altas;
INSERT INTO socio(id_cliente) SELECT id_cliente FROM d4_clientes;
INSERT INTO comprobante(id_cliente,id_sala)
SELECT id_cliente,1 FROM d4_clientes WHERE nombre_o_razon_social='ETAPA5 D4 comprador';
WITH borrados AS (
  DELETE FROM cliente s WHERE s.tipo_cliente='socio' AND s.fecha_alta<CURRENT_DATE-interval '5 years'
    AND NOT EXISTS (SELECT FROM comprobante c WHERE c.id_cliente=s.id_cliente)
  RETURNING s.nombre_o_razon_social
) SELECT * INTO TEMP d4_borrados FROM borrados;
TABLE d4_borrados;
SELECT d.nombre_o_razon_social,s.id_cliente IS NOT NULL subtipo_presente
FROM d4_clientes d LEFT JOIN socio s USING(id_cliente) ORDER BY 1;
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM d4_borrados WHERE nombre_o_razon_social='ETAPA5 D4 antiguo')
     OR (SELECT count(*) FROM d4_clientes JOIN socio USING(id_cliente))<>2
     OR EXISTS (SELECT FROM d4_borrados WHERE nombre_o_razon_social IN ('ETAPA5 D4 límite','ETAPA5 D4 comprador'))
  THEN RAISE EXCEPTION 'Falló D4'; END IF;
END $$;
ROLLBACK;
