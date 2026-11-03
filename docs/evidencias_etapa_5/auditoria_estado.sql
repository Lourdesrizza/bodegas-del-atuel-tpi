SELECT current_database(), current_user, version();
DO $$ BEGIN
  IF current_database()<>'atuel_base_test' OR current_user<>'atuel_admin'
     OR current_setting('server_version_num')::integer NOT BETWEEN 160000 AND 169999 THEN
    RAISE EXCEPTION 'Base, usuario o versión de laboratorio inesperados';
  END IF;
END $$;
SELECT (SELECT count(*) FROM comprobante) comprobantes,
       (SELECT count(*) FROM renglon_comprobante) renglones;
SELECT tgrelid::regclass tabla,tgname,tgenabled FROM pg_trigger
WHERE NOT tgisinternal ORDER BY 1,2;
SELECT pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid='tipo_cliente'::regclass AND conname='tipo_cliente_check';
SELECT pg_get_functiondef('public.fn_descuento_cliente(integer)'::regprocedure);
SELECT count(*) columnas_demo FROM information_schema.columns
WHERE table_schema='public' AND table_name='exportador' AND column_name='descuento';
SELECT count(*) permisos_demo FROM permiso_exportacion WHERE cod_permiso LIKE 'ETAPA5-U6-%';
SELECT * FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname;
