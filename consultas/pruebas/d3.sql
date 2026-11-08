BEGIN;
-- La fecha de baja se informa externamente. No existe en sala_venta.
CREATE TEMP TABLE d3_parametros AS SELECT 1 id_sala,DATE '2026-11-03' fecha_baja;
INSERT INTO empleado(cuit,id_sala,nombre,fecha_ingreso,salario)
SELECT cuit,id_sala,nombre,(fecha_baja-interval '2 years')::date+dias,100
FROM d3_parametros CROSS JOIN (VALUES
  ('20999999031','ETAPA5 D3 menor',1),
  ('20999999032','ETAPA5 D3 limite',0),
  ('20999999033','ETAPA5 D3 mayor',-1)
) AS casos(cuit,nombre,dias);
WITH borrados AS (
  DELETE FROM empleado e USING d3_parametros p
  WHERE e.id_sala=p.id_sala AND e.fecha_ingreso>p.fecha_baja-interval '2 years'
    AND e.fecha_ingreso<=p.fecha_baja
  RETURNING e.nombre
) SELECT * INTO TEMP d3_borrados FROM borrados;
TABLE d3_borrados;
SELECT nombre,fecha_ingreso FROM empleado WHERE nombre LIKE 'ETAPA5 D3 %' ORDER BY fecha_ingreso;
DO $$ BEGIN
  IF (SELECT count(*) FROM d3_borrados WHERE nombre LIKE 'ETAPA5 D3 %')<>1
     OR NOT EXISTS (SELECT FROM d3_borrados WHERE nombre='ETAPA5 D3 menor')
     OR (SELECT count(*) FROM empleado WHERE nombre IN ('ETAPA5 D3 limite','ETAPA5 D3 mayor'))<>2
  THEN RAISE EXCEPTION 'Falló D3'; END IF;
END $$;
ROLLBACK;
