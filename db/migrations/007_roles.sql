-- Migración exclusiva de base nueva. Claves fuera del repositorio.
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='app_owner') THEN CREATE ROLE app_owner NOLOGIN; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='app_rw') THEN CREATE ROLE app_rw LOGIN; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='app_ro') THEN CREATE ROLE app_ro LOGIN; END IF;
END $$;
DO $$ DECLARE x record; BEGIN
  FOR x IN SELECT c.relname,c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE n.nspname='public' AND c.relkind IN ('r','v','m') LOOP
    EXECUTE format('ALTER %s public.%I OWNER TO app_owner',
      CASE x.relkind WHEN 'v' THEN 'VIEW'
      WHEN 'm' THEN 'MATERIALIZED VIEW' ELSE 'TABLE' END,x.relname);
  END LOOP;
  FOR x IN SELECT p.oid,p.prokind FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='public' LOOP
    EXECUTE format('ALTER %s %s OWNER TO app_owner',
      CASE WHEN x.prokind='p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,x.oid::regprocedure);
  END LOOP;
  ALTER TYPE estado_documento OWNER TO app_owner;
  ALTER DOMAIN cuit_dom OWNER TO app_owner;
END $$;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO app_owner,app_rw,app_ro;
GRANT CREATE ON SCHEMA public TO app_owner;
GRANT USAGE ON TYPE estado_documento,cuit_dom TO app_rw,app_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_rw,app_ro;
GRANT SELECT,INSERT,UPDATE,DELETE ON localidad,sala_venta,empleado,finca,cepa,parcela,
  bodega,lote_uva,analisis_calidad,vino,composicion,maridaje,vino_maridaje,
  cliente,socio,distribuidor,exportador,permiso_exportacion,transportista,
  transportista_localidad TO app_rw;
GRANT INSERT ON ingreso,transferencia,comprobante,renglon_ingreso,
  renglon_transferencia,renglon_comprobante TO app_rw;
GRANT UPDATE,DELETE ON renglon_ingreso,renglon_transferencia TO app_rw;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_rw;
GRANT EXECUTE ON FUNCTION fn_descuento_cliente(integer),fn_stock_sala(integer,integer),
  fn_antiguedad_anios(date),fn_total_comprobante(integer) TO app_rw,app_ro;
GRANT EXECUTE ON PROCEDURE sp_procesar_ingreso(integer),sp_procesar_transferencia(integer),
  sp_terminar_ingreso(integer),sp_terminar_transferencia(integer) TO app_rw;
DO $$ DECLARE x record; BEGIN
  FOR x IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='public' AND (p.proname LIKE 'trg_fn_%' OR p.proname LIKE 'sp_%') LOOP
    EXECUTE format('ALTER ROUTINE %s SECURITY DEFINER',x.oid::regprocedure);
    EXECUTE format('ALTER ROUTINE %s SET search_path = public, pg_temp',x.oid::regprocedure);
  END LOOP;
END $$;
-- EXECUTE de funciones es global por defecto: revocar sin IN SCHEMA.
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public GRANT SELECT ON TABLES TO app_ro;
