-- Cuerpo de la propuesta 009 en una transacción reversible. El CHECK del catálogo sigue en 30 %.
BEGIN;
SELECT count(*) elegibles_originales FROM (
  SELECT id_cliente FROM permiso_exportacion GROUP BY id_cliente HAVING count(*)>3
) p;
CREATE TEMP TABLE u6_clientes AS
SELECT e.id_cliente, row_number() OVER (ORDER BY e.id_cliente) posicion
FROM exportador e WHERE (SELECT count(*) FROM permiso_exportacion p WHERE p.id_cliente=e.id_cliente)<=3
ORDER BY e.id_cliente LIMIT 2;
INSERT INTO permiso_exportacion(cod_permiso,id_cliente,fecha_emision,fecha_vencimiento)
SELECT 'ETAPA5-U6-AUD-' || n,id_cliente,CURRENT_DATE,CURRENT_DATE+365
FROM u6_clientes CROSS JOIN generate_series(1,4) n WHERE posicion=1;
ALTER TABLE exportador ADD COLUMN descuento NUMERIC(5,2) NOT NULL DEFAULT 30
  CONSTRAINT ck_exportador_descuento CHECK (descuento IN (30,35));

UPDATE exportador SET descuento=35
WHERE id_cliente IN (
  SELECT id_cliente FROM permiso_exportacion GROUP BY id_cliente HAVING count(*)>3
);

CREATE OR REPLACE FUNCTION fn_descuento_cliente(p_id_cliente INTEGER)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_descuento NUMERIC(5,2);
BEGIN
  SELECT coalesce(e.descuento,t.descuento) INTO v_descuento
  FROM cliente c JOIN tipo_cliente t USING(tipo_cliente)
  LEFT JOIN exportador e USING(id_cliente)
  WHERE c.id_cliente=p_id_cliente;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El cliente con ID % no existe (RN-06)', p_id_cliente;
  END IF;
  RETURN v_descuento;
END;
$$;

-- El alta del beneficio es explícita. Definir con la cátedra si debe
-- retirarse automáticamente al perder permisos antes de aplicar la propuesta.
CREATE TEMP TABLE u6_ventas AS
WITH altas AS (
  INSERT INTO comprobante(id_cliente,id_sala) SELECT id_cliente,1 FROM u6_clientes
  RETURNING nro_comprobante,id_cliente
) SELECT * FROM altas;
INSERT INTO renglon_comprobante(nro_comprobante,cod_vino,cantidad)
SELECT nro_comprobante,1,1 FROM u6_ventas;
CREATE TEMP TABLE u6_resultado AS
SELECT x.posicion,c.id_cliente,p.permisos,e.descuento,r.descuento_aplicado,
       r.precio_unitario,r.subtotal_renglon,c.subtotal,c.descuento monto_descuento,c.total,
       CASE x.posicion WHEN 1 THEN 35 ELSE 30 END esperado
FROM u6_ventas v JOIN comprobante c USING(nro_comprobante)
JOIN u6_clientes x ON x.id_cliente=c.id_cliente JOIN exportador e ON e.id_cliente=c.id_cliente
JOIN renglon_comprobante r USING(nro_comprobante)
CROSS JOIN LATERAL (SELECT count(*) permisos FROM permiso_exportacion p WHERE p.id_cliente=c.id_cliente) p;
SELECT * FROM u6_resultado ORDER BY posicion;
DO $$ BEGIN
  IF (SELECT count(*) FROM u6_resultado)<>2 OR EXISTS (
    SELECT FROM u6_resultado WHERE descuento_aplicado<>esperado OR descuento<>esperado
      OR (permisos>3)<>(posicion=1) OR total<>round(precio_unitario*(1-esperado/100.0),2)
      OR subtotal_renglon<>total OR subtotal-monto_descuento<>total
  ) THEN RAISE EXCEPTION 'Falló la comprobación de ventas de U6'; END IF;
END $$;
ROLLBACK;
