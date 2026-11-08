#!/bin/sh
set -eu

# La imagen ejecuta este archivo solo al inicializar un volumen vacío.
for migration in /atuel/migrations/00[1-8]_*.sql; do
    psql -X -w -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$migration"
done

# El valor proviene del entorno y psql lo cita como literal SQL.
psql -X -w -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<'SQL'
\getenv clave API_DB_PASSWORD
ALTER ROLE app_rw PASSWORD :'clave';
SQL
