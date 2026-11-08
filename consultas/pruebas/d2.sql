BEGIN;
INSERT INTO cepa(nombre,tipo) VALUES ('ETAPA5 D2 sin referencias','tinta');
CREATE TEMP TABLE d2_control AS SELECT DISTINCT id_cepa FROM parcela;
WITH borradas AS (
  DELETE FROM cepa c WHERE NOT EXISTS (SELECT FROM composicion v WHERE v.id_cepa=c.id_cepa)
    AND NOT EXISTS (SELECT FROM parcela p WHERE p.id_cepa=c.id_cepa)
  RETURNING nombre
) SELECT * INTO TEMP d2_borradas FROM borradas;
TABLE d2_borradas;
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM d2_borradas WHERE nombre='ETAPA5 D2 sin referencias')
     OR EXISTS (SELECT FROM d2_control d WHERE NOT EXISTS (SELECT FROM cepa c WHERE c.id_cepa=d.id_cepa))
  THEN RAISE EXCEPTION 'Falló D2'; END IF;
END $$;
ROLLBACK;
