BEGIN;
CREATE TEMP TABLE s4_altas AS
WITH altas AS (
  INSERT INTO transferencia(id_sala) SELECT generate_series(1,6)
  RETURNING nro_solicitud,id_sala
) SELECT * FROM altas;
INSERT INTO renglon_transferencia(nro_solicitud,cod_vino,cantidad)
SELECT nro_solicitud,1,greatest(6,11-id_sala) FROM s4_altas;
CREATE TEMP TABLE s4_resultado AS
SELECT t.id_sala,sum(r.cantidad) botellas FROM transferencia t
JOIN renglon_transferencia r USING(nro_solicitud)
WHERE r.cod_vino=1 AND t.fecha_confeccion BETWEEN CURRENT_DATE-14 AND CURRENT_DATE
GROUP BY t.id_sala ORDER BY botellas DESC,t.id_sala LIMIT 5;
SELECT * FROM s4_resultado ORDER BY botellas DESC,id_sala;
DO $$ BEGIN
  IF (SELECT array_agg(id_sala ORDER BY botellas DESC,id_sala) FROM s4_resultado)
      IS DISTINCT FROM ARRAY[1,2,3,4,5]
    OR (SELECT array_agg(botellas ORDER BY botellas DESC,id_sala) FROM s4_resultado)
      IS DISTINCT FROM ARRAY[10,9,8,7,6]::bigint[]
  THEN RAISE EXCEPTION 'Falló S4'; END IF;
END $$;
ROLLBACK;
