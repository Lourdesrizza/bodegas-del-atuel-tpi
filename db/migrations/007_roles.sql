-- ============================================================================
-- PROYECTO: Bodegas del Atuel
-- ETAPA 2: Seguridad, Roles y Privilegios Mínimos (007_roles.sql)
-- ============================================================================

-- 1. Creación de roles si no existen
DO $$
BEGIN
    -- Rol lectura y escritura para el Backend / API
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN
        CREATE ROLE app_rw WITH LOGIN PASSWORD 'app_rw_secret_pass';
    END IF;

    -- Rol solo lectura para auditoría y reportes
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_ro') THEN
        CREATE ROLE app_ro WITH LOGIN PASSWORD 'app_ro_secret_pass';
    END IF;
END $$;

-- 2. Revocar privilegios públicos por defecto en el esquema public
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;

-- 3. Otorgar permisos al rol de la API (app_rw)
GRANT USAGE ON SCHEMA public TO app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO app_rw;

-- 4. Otorgar permisos al rol de reportes (app_ro)
GRANT USAGE ON SCHEMA public TO app_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_ro;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_ro;

-- 5. Asegurar privilegios automáticos en futuras tablas o funciones del esquema
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT USAGE, SELECT ON SEQUENCES TO app_rw;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT EXECUTE ON ROUTINES TO app_rw;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT ON TABLES TO app_ro;