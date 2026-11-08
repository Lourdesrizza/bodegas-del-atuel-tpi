BEGIN;
CREATE TEMP TABLE d1_ventas AS
WITH altas AS (
  INSERT INTO comprobante(id_cliente,id_sala,fecha)
  VALUES ((SELECT min(id_cliente) FROM socio),1,CURRENT_DATE-interval '6 years'),
         ((SELECT min(id_cliente) FROM socio),1,CURRENT_DATE-interval '5 years'),
         ((SELECT min(id_cliente) FROM exportador),1,CURRENT_DATE-interval '6 years')
  RETURNING *
)
SELECT a.*, (s.id_cliente IS NOT NULL AND fecha<CURRENT_DATE-interval '5 years') objetivo
FROM altas a LEFT JOIN socio s USING(id_cliente);
INSERT INTO renglon_comprobante(nro_comprobante,cod_vino,cantidad)
SELECT nro_comprobante,1,1 FROM d1_ventas;
CREATE TEMP TABLE d1_stock AS TABLE stock_sala;
SELECT objetivo,count(*) FROM d1_ventas GROUP BY objetivo;
ALTER TABLE comprobante DISABLE TRIGGER trg_comprobante_inmutable;
ALTER TABLE renglon_comprobante DISABLE TRIGGER trg_renglon_venta_inmutable;
DELETE FROM comprobante c USING d1_ventas v,socio s
WHERE c.nro_comprobante=v.nro_comprobante AND c.id_cliente=s.id_cliente
AND c.fecha<CURRENT_DATE-interval '5 years';
ALTER TABLE comprobante ENABLE TRIGGER trg_comprobante_inmutable;
ALTER TABLE renglon_comprobante ENABLE TRIGGER trg_renglon_venta_inmutable;
CREATE TEMP TABLE d1_resultado AS
SELECT v.objetivo,count(c.nro_comprobante) cabeceras,count(r.nro_comprobante) renglones
FROM d1_ventas v LEFT JOIN comprobante c USING(nro_comprobante)
LEFT JOIN renglon_comprobante r USING(nro_comprobante) GROUP BY v.objetivo;
TABLE d1_resultado;
SELECT NOT EXISTS ((TABLE d1_stock EXCEPT TABLE stock_sala)
UNION ALL (TABLE stock_sala EXCEPT TABLE d1_stock)) stock_intacto;
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM d1_resultado WHERE objetivo AND cabeceras=0 AND renglones=0)
     OR NOT EXISTS (SELECT FROM d1_resultado WHERE NOT objetivo AND cabeceras=2 AND renglones=2)
     OR EXISTS ((TABLE d1_stock EXCEPT TABLE stock_sala) UNION ALL (TABLE stock_sala EXCEPT TABLE d1_stock)) THEN
    RAISE EXCEPTION 'Falló el caso D1';
  END IF;
END $$;
SELECT tgname,tgenabled FROM pg_trigger
WHERE tgname IN ('trg_comprobante_inmutable','trg_renglon_venta_inmutable');
ROLLBACK;
