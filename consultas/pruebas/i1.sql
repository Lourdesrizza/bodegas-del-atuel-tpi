BEGIN;
-- El código menor desempata entre transportistas sin envíos recientes.
INSERT INTO transportista(cod_transportista,cuit,razon_social,domicilio,email,telefono)
VALUES ((SELECT min(cod_transportista)-1 FROM transportista),'30999999051','ETAPA5 I1','Ensayo','etapa5-i1@example.invalid','000');
WITH elegido AS (
  SELECT t.cod_transportista FROM transportista t LEFT JOIN ingreso i
  ON i.cod_transportista=t.cod_transportista
    AND i.fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE
  GROUP BY t.cod_transportista ORDER BY count(i.cod_ingreso),t.cod_transportista LIMIT 1
), altas AS (
  INSERT INTO transportista_localidad
  SELECT t.cod_transportista,l.id_localidad FROM elegido t CROSS JOIN localidad l
  WHERE l.nombre='General Alvear' AND l.provincia='Mendoza'
  ON CONFLICT DO NOTHING RETURNING *
)
SELECT * INTO TEMP i1_altas FROM altas;
SELECT t.razon_social,l.nombre FROM i1_altas a JOIN transportista t USING(cod_transportista)
JOIN localidad l USING(id_localidad);
DO $$ BEGIN
  IF (SELECT count(*) FROM i1_altas)<>1 OR NOT EXISTS (
    SELECT FROM i1_altas a JOIN transportista t USING(cod_transportista)
    WHERE t.razon_social='ETAPA5 I1'
  ) THEN RAISE EXCEPTION 'Falló I1'; END IF;
END $$;
ROLLBACK;
