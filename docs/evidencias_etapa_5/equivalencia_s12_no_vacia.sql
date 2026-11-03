CREATE TEMP TABLE indices_antes AS
SELECT * FROM pg_indexes WHERE schemaname='public';
SELECT * FROM indices_antes ORDER BY tablename,indexname;

BEGIN;
-- Venta de laboratorio para el cliente 1 y todos los vinos de la bodega objetivo.
CREATE TEMP TABLE vinos_caso AS
SELECT cod_vino FROM vino
WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1);
INSERT INTO stock_sala(id_sala,cod_vino,cantidad)
SELECT 1,cod_vino,1 FROM vinos_caso
ON CONFLICT (id_sala,cod_vino) DO UPDATE SET cantidad=greatest(stock_sala.cantidad,1);
CREATE TEMP TABLE venta_caso AS
WITH alta AS (
  INSERT INTO comprobante(id_cliente,id_sala,fecha)
  VALUES (1,1,CURRENT_DATE) RETURNING nro_comprobante
)
SELECT * FROM alta;
INSERT INTO renglon_comprobante(nro_comprobante,cod_vino,cantidad)
SELECT nro_comprobante,cod_vino,1 FROM venta_caso CROSS JOIN vinos_caso;

-- Caso acotado con los mismos nombres que usan ambas consultas.
-- El cliente 1 tiene la compra completa y el 2 sirve de control negativo.
CREATE TEMP TABLE cliente AS SELECT * FROM public.cliente WHERE id_cliente IN (1,2);
CREATE TEMP TABLE comprobante AS
SELECT c.* FROM public.comprobante c JOIN venta_caso USING(nro_comprobante);
CREATE TEMP TABLE renglon_comprobante AS
SELECT r.* FROM public.renglon_comprobante r JOIN venta_caso USING(nro_comprobante);
CREATE TEMP TABLE s12_original AS
WITH objetivo AS (SELECT cod_vino FROM vino WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1)) SELECT cl.id_cliente FROM cliente cl WHERE EXISTS (SELECT FROM objetivo) AND NOT EXISTS (SELECT FROM objetivo v WHERE NOT EXISTS (SELECT FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante) WHERE c.id_cliente=cl.id_cliente AND r.cod_vino=v.cod_vino)) ORDER BY cl.id_cliente;
CREATE TEMP TABLE s12_reformulada AS
WITH objetivo AS (
  SELECT cod_vino FROM vino
  WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1)
), compras AS (
  SELECT c.id_cliente,array_agg(DISTINCT r.cod_vino) vinos
  FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante)
  JOIN objetivo v USING(cod_vino)
  GROUP BY c.id_cliente
)
SELECT c.id_cliente FROM compras c
WHERE NOT EXISTS (
  SELECT FROM objetivo v WHERE NOT EXISTS (
    SELECT FROM unnest(c.vinos) compra(cod_vino) WHERE compra.cod_vino=v.cod_vino
  )
)
ORDER BY c.id_cliente;
SELECT (SELECT count(*) FROM s12_original) original,
       (SELECT count(*) FROM s12_reformulada) reformulada,
       (SELECT count(*) FROM (TABLE s12_original EXCEPT TABLE s12_reformulada) a) solo_original,
       (SELECT count(*) FROM (TABLE s12_reformulada EXCEPT TABLE s12_original) b) solo_reformulada;
TABLE s12_original;
TABLE s12_reformulada;
DO $$ BEGIN
  IF (SELECT count(*) FROM s12_original) <> 1
     OR NOT EXISTS (SELECT FROM s12_original WHERE id_cliente=1)
     OR EXISTS (TABLE s12_original EXCEPT TABLE s12_reformulada)
     OR EXISTS (TABLE s12_reformulada EXCEPT TABLE s12_original) THEN
    RAISE EXCEPTION 'La comparación S12 no produjo el caso esperado';
  END IF;
END $$;
ROLLBACK;

SELECT * FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname;
SELECT
  (SELECT count(*) FROM indices_antes) antes,
  (SELECT count(*) FROM pg_indexes WHERE schemaname='public') despues,
  (SELECT count(*) FROM (
    SELECT * FROM pg_indexes WHERE schemaname='public' EXCEPT TABLE indices_antes
  ) i) nuevos,
  (SELECT count(*) FROM (
    TABLE indices_antes EXCEPT SELECT * FROM pg_indexes WHERE schemaname='public'
  ) i) faltantes;
