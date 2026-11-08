# Bodegas del Atuel

Trabajo Práctico Integrador de Bases de Datos · UTN FR San Rafael. Este traspaso deja la API de etapa 6 lista para que el equipo empiece la etapa 7.

## Levantar la API en Windows

Con Docker Desktop iniciado, ejecutá en PowerShell:

```powershell
git clone https://github.com/Lourdesrizza/bodegas-del-atuel-tpi.git
Set-Location bodegas-del-atuel-tpi
git switch etapa-6-api
if (-not (Test-Path -LiteralPath .env)) { Copy-Item .env.example .env }
notepad .env
```

Completá `ATUEL_LAB_ADMIN_PASSWORD` y `API_DB_PASSWORD` con dos contraseñas locales distintas. Dejá `ATUEL_API_PORT=8000` si ese puerto está libre. Git ignora `.env`. Si ya existía, revisá que tenga las tres variables sin sobrescribir otras configuraciones.

```powershell
docker compose up -d --build
Invoke-RestMethod 'http://127.0.0.1:8000/salud' | ConvertTo-Json -Compress
Start-Process 'http://127.0.0.1:8000/docs'
```

La respuesta esperada de salud es `{"ok":true,"rol":"app_rw"}`. La **URL base para el frontend es `http://127.0.0.1:8000`**. Si cambiaste `ATUEL_API_PORT`, usá ese puerto también para salud, Swagger y el frontend. El contrato JSON está en `/openapi.json`.

Compose levanta PostgreSQL 16 en su red interna e inicializa la base de laboratorio con 001–008 al crear el volumen. Si ya usaste ese volumen, conserva sus datos y las contraseñas iniciales. Para un laboratorio nuevo podés elegir otro nombre con `docker compose -p NOMBRE up -d --build`. En una base recién inicializada los catálogos de la API pueden estar vacíos. Para cargar los datos ficticios mínimos de las pruebas en el laboratorio descartable, ejecutá:

```powershell
docker compose exec -T api python -m unittest discover -s api/tests -v
```

## Empezar etapa 7

Creá la rama desde la referencia publicada de la API, una vez por equipo:

```powershell
git fetch origin
git switch --no-track -c etapa-7-frontend origin/etapa-6-api
```

Usá Swagger para revisar los cuerpos y respuestas. Los listados paginados aceptan `limite` y `offset`, los importes viajan como texto decimal y la base calcula los totales, descuentos y stock. La API actual carece de configuración CORS. Si el frontend corre en otro origen durante el desarrollo, usá un proxy de desarrollo hacia la URL base.

## Referencias y pendientes

- [Reporte de etapa 6 y matriz de endpoints](docs/reporte_etapa_6.md)
- [Evidencia de las 10 pruebas HTTP](docs/evidencias_etapa_6/integracion.log) y [verificación del servicio](docs/evidencias_etapa_6/servicio.log)
- [Enunciado del TPI](docs/TPI_Bodegas_del_Atuel.pdf)

U1 requiere validación docente del criterio histórico para conciliar el total de cabecera. U6 fue un ensayo reversible. El 35 % y su vigencia al perder permisos requieren aprobación docente. La propuesta 009 está fuera de las migraciones vigentes. La trazabilidad llega a movimientos verificables por código de vino. El esquema carece de una relación física entre un lote específico de uva y el vino elaborado.
