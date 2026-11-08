BEGIN;
CREATE TEMP TABLE u1_venta AS
WITH alta AS (
  INSERT INTO comprobante(id_cliente,id_sala) VALUES (1,1) RETURNING nro_comprobante
) SELECT * FROM alta;
INSERT INTO renglon_comprobante(nro_comprobante,cod_vino,cantidad)
SELECT nro_comprobante,1,1 FROM u1_venta;
CREATE TEMP TABLE u1_stock AS TABLE stock_sala;
CREATE TEMP TABLE u1_renglones AS
SELECT r.* FROM renglon_comprobante r JOIN u1_venta USING(nro_comprobante);
ALTER TABLE comprobante DISABLE TRIGGER trg_comprobante_inmutable;
UPDATE comprobante c SET total=c.total+1 FROM u1_venta v
WHERE c.nro_comprobante=v.nro_comprobante;
SELECT c.total total_desajustado,f.total total_historico
FROM comprobante c JOIN u1_venta USING(nro_comprobante)
CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f;
WITH calculados AS (
  SELECT c.nro_comprobante,f.total FROM comprobante c JOIN u1_venta USING(nro_comprobante)
  CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f
), corregidos AS (
  UPDATE comprobante c SET total=x.total FROM calculados x
  WHERE c.nro_comprobante=x.nro_comprobante AND c.total IS DISTINCT FROM x.total
  RETURNING c.nro_comprobante,c.total
)
SELECT * INTO TEMP u1_corregidos FROM corregidos;
ALTER TABLE comprobante ENABLE TRIGGER trg_comprobante_inmutable;
SELECT c.total total_conciliado,f.total total_historico
FROM comprobante c JOIN u1_venta USING(nro_comprobante)
CROSS JOIN LATERAL fn_total_comprobante(c.nro_comprobante) f;
DO $$ BEGIN
  IF (SELECT count(*) FROM u1_corregidos)<>1
     OR EXISTS (SELECT FROM u1_corregidos c CROSS JOIN LATERAL
       fn_total_comprobante(c.nro_comprobante) f WHERE c.total IS DISTINCT FROM f.total)
     OR EXISTS ((TABLE u1_stock EXCEPT TABLE stock_sala) UNION ALL (TABLE stock_sala EXCEPT TABLE u1_stock))
     OR EXISTS ((TABLE u1_renglones EXCEPT SELECT r.* FROM renglon_comprobante r JOIN u1_venta USING(nro_comprobante))
       UNION ALL (SELECT r.* FROM renglon_comprobante r JOIN u1_venta USING(nro_comprobante) EXCEPT TABLE u1_renglones)) THEN
    RAISE EXCEPTION 'Falló el caso U1';
  END IF;
END $$;
SELECT count(*) filas_corregidas FROM u1_corregidos;
SELECT tgname,tgenabled FROM pg_trigger WHERE tgname='trg_comprobante_inmutable';
ROLLBACK;
