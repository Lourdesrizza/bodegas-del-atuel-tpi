SELECT CURRENT_DATE AS fecha_de_ejecucion;
SELECT 'comprobante' tabla,min(fecha),max(fecha) FROM comprobante
UNION ALL SELECT 'transferencia',min(fecha_confeccion),max(fecha_confeccion) FROM transferencia
UNION ALL SELECT 'ingreso',min(fecha),max(fecha) FROM ingreso;
SELECT 'S3' consigna,count(*) filas FROM (SELECT t.tipo_cliente,count(DISTINCT c.id_cliente) clientes FROM tipo_cliente t LEFT JOIN cliente cl USING(tipo_cliente) LEFT JOIN comprobante c ON c.id_cliente=cl.id_cliente AND c.id_sala=1 AND c.fecha BETWEEN CURRENT_DATE-6 AND CURRENT_DATE GROUP BY t.tipo_cliente) resultado;
SELECT 'S4' consigna,count(*) filas FROM (SELECT t.id_sala,sum(r.cantidad) botellas FROM transferencia t JOIN renglon_transferencia r USING(nro_solicitud) WHERE r.cod_vino=1 AND t.fecha_confeccion BETWEEN CURRENT_DATE-14 AND CURRENT_DATE GROUP BY t.id_sala ORDER BY botellas DESC,t.id_sala LIMIT 5) resultado;
SELECT 'S7' consigna,count(*) filas FROM (SELECT t.cod_transportista,t.razon_social,count(*) ingresos FROM transportista t JOIN ingreso i USING(cod_transportista) WHERE i.fecha BETWEEN CURRENT_DATE-interval '1 month' AND CURRENT_DATE GROUP BY t.cod_transportista ORDER BY ingresos DESC FETCH FIRST 1 ROW WITH TIES) resultado;
SELECT 'S8' consigna,count(*) filas FROM (SELECT s.id_sala,coalesce(sum(c.total),0) total FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala AND c.fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE GROUP BY s.id_sala ORDER BY total DESC,s.id_sala) resultado;
SELECT count(*) ventas_sala_1 FROM comprobante WHERE id_sala=1 AND fecha BETWEEN CURRENT_DATE-6 AND CURRENT_DATE;
SELECT count(*) ventas_trimestre FROM comprobante WHERE fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE;
SELECT count(*) ingresos_trimestre_I1 FROM ingreso WHERE fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE;
SELECT 'I1' consigna,count(*) filas_insertadas FROM (
  SELECT t.cod_transportista FROM transportista t LEFT JOIN ingreso i
    ON i.cod_transportista=t.cod_transportista AND i.fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE
  GROUP BY t.cod_transportista ORDER BY count(i.cod_ingreso),t.cod_transportista LIMIT 1
) t CROSS JOIN localidad l WHERE l.nombre='General Alvear' AND l.provincia='Mendoza'
AND NOT EXISTS (SELECT FROM transportista_localidad x WHERE x.cod_transportista=t.cod_transportista AND x.id_localidad=l.id_localidad);
SELECT conname,pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='tipo_cliente'::regclass AND contype='c';
SELECT (SELECT count(*) FROM comprobante) comprobantes,(SELECT count(*) FROM renglon_comprobante) renglones;
SELECT tgname,tgenabled FROM pg_trigger WHERE NOT tgisinternal ORDER BY tgname;
