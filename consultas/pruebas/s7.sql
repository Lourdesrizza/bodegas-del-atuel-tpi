BEGIN;
INSERT INTO ingreso(cuit_bodega,cod_transportista,fecha)
SELECT (SELECT min(cuit) FROM bodega),t,CURRENT_DATE FROM (VALUES (1),(1),(2),(2),(3)) v(t);
CREATE TEMP TABLE s7_resultado AS
SELECT t.cod_transportista,t.razon_social,count(*) ingresos FROM transportista t
JOIN ingreso i USING(cod_transportista)
WHERE i.fecha BETWEEN CURRENT_DATE-interval '1 month' AND CURRENT_DATE
GROUP BY t.cod_transportista ORDER BY ingresos DESC FETCH FIRST 1 ROW WITH TIES;
SELECT * FROM s7_resultado ORDER BY cod_transportista;
DO $$ BEGIN
  IF (SELECT array_agg(cod_transportista ORDER BY cod_transportista) FROM s7_resultado)
      IS DISTINCT FROM ARRAY[1,2] OR EXISTS (SELECT FROM s7_resultado WHERE ingresos<>2)
  THEN RAISE EXCEPTION 'Falló S7'; END IF;
END $$;
ROLLBACK;
