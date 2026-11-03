-- Borrador para revisión docente. Aplicar únicamente tras acordar la excepción a RN-06.
-- Ejecutar como propietario. El 30 % sigue siendo el valor base del catálogo.
BEGIN;
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
COMMIT;
