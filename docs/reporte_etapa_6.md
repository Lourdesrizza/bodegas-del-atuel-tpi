# Etapa 6 · API REST

## Arranque en un laboratorio nuevo

Requiere Docker y Docker Compose. Desde la raíz, definí dos contraseñas diferentes en tu entorno o en un archivo local ignorado por Git. La plantilla `.env.example` enumera las variables. Si ya tenés un `.env` de otra etapa, podés usar variables de la sesión sin sobrescribirlo.

```powershell
$env:ATUEL_LAB_ADMIN_PASSWORD = Read-Host 'Contraseña del administrador del laboratorio' -MaskInput
$env:API_DB_PASSWORD = Read-Host 'Contraseña de app_rw' -MaskInput
$env:ATUEL_API_PORT = '8000'
docker compose up --build
```

Compose usa el proyecto `atuel-etapa6-lab`, el volumen `etapa6_data` de ese proyecto y la base `atuel_api_test`. PostgreSQL 16 escucha en la red interna y solo la API publica un puerto, ligado a loopback. El inicializador aplica 001–008 en orden y configura la contraseña de `app_rw` desde el entorno. La API recibe únicamente su propia contraseña. Un volumen usado conserva su configuración previa. Para probar una inicialización nueva, elegí un nombre de proyecto nuevo con `docker compose -p NOMBRE up --build`.

- Salud en `http://127.0.0.1:8000/salud`.
- Swagger en `http://127.0.0.1:8000/docs`.
- Contrato en `http://127.0.0.1:8000/openapi.json`.
- Pruebas HTTP y datos ficticios para el laboratorio descartable:

```powershell
docker compose exec -T api python -m unittest discover -s api/tests -v
```

## Contratos HTTP

| Recurso | Métodos y rutas | Comportamiento |
|---|---|---|
| Salud | GET `/salud` | Consulta real y rol de conexión. |
| Vinos | GET/POST `/vinos`, GET/PUT/DELETE `/vinos/{cod}` | Filtros combinables `tipo`, `cepa` (ID), `bodega` (CUIT), `anada` y `nombre` (subcadena literal). El detalle incluye composición y maridajes. PUT reemplaza los datos y las asociaciones y dispara auditoría si cambia el precio. |
| Clientes | GET/POST `/clientes`, GET/PUT/DELETE `/clientes/{cod}` | Cuerpo discriminado por `tipo_cliente`. Distribuidor tiene zona y habilitación. Exportador tiene país y permisos. PUT reemplaza los datos del subtipo y permite cambiarlo. |
| Ventas | POST `/comprobantes`, GET `/comprobantes/{nro}` | La venta recibe cliente, sala y renglones. Cabecera, renglones, stock e importes quedan bajo una transacción de PostgreSQL. |
| Ingresos | POST `/ingresos`, GET `/ingresos/{cod}`, POST `/ingresos/{cod}/renglones`, `/terminar` y `/procesar` | El alta recibe CUIT de bodega y transportista. Los estados se cambian por procedimientos autorizados. |
| Transferencias | POST `/transferencias`, GET `/transferencias/{cod}`, POST `/transferencias/{cod}/renglones`, `/terminar` y `/procesar` | El alta recibe la sala. PostgreSQL asigna fecha, controla stock y cambia el estado. |
| Reportes | GET `/reportes/top-vinos`, `/ventas-por-sala`, `/vinos-sin-stock?sala=ID`, `/transportista-activo`, `/trazabilidad/{cod}` | S1, S8, S6 y S7 para los primeros cuatro. La trazabilidad vincula la ficha, stock e ingresos, transferencias y ventas comprobables por código de vino. |

Los listados paginados aceptan `limite` de 1 a 100 y `offset` desde 0. Usan orden estable por identificador. En trazabilidad, cada colección de movimientos aplica la misma ventana por separado. La consigna pide un endpoint por código, y el esquema enlaza lote de uva con bodega y vino con cepas y bodega. Carece de una relación física que permita atribuir un lote específico a un vino, así que la respuesta se limita a vínculos verificables. El dinero se serializa como texto decimal para preservar precisión.

## Transacciones y errores

El pool de psycopg usa un único rol fijo, `app_rw`. Cada operación trabaja con una conexión y la confirma al salir del contexto transaccional. Las restricciones diferidas también pueden rechazar la confirmación. Los datos se pasan como parámetros. Las tablas y procedimientos dinámicos salen exclusivamente de un catálogo cerrado en el código.

| SQLSTATE | HTTP | Respuesta |
|---|---:|---|
| 23505 | 409 | Duplicado |
| 23503, 23001 | 409 | Referencia inválida o registro con dependencias |
| P0001 | 409 | Mensaje de la regla de negocio |
| 23514, 23502 | 422 | Restricción o valor obligatorio |
| 22P02 | 400 | Formato inválido |
| 40001, 40P01 | 503 | Reintentar, con `Retry-After` |

La API y el código de prueba trabajan como `app_rw`. El ensayo confirmó que el rol puede invocar los cuatro procedimientos de estado, pero carece de CREATE en `public` y de UPDATE directo sobre `stock_sala`. La prueba de DDL obtuvo `InsufficientPrivilege`. El código HTTP de error evita devolver trazas, sentencias internas y credenciales.

## Ejecuciones verificadas

- Arranque nuevo con `docker compose -p atuel-etapa6-validada up -d --build` y puerto HTTP de laboratorio 18066. El primer intento se detuvo al interpretar el delimitador del shell con CRLF. Se corrigió a LF y se repitió en otro volumen nuevo. [Arranque final](evidencias_etapa_6/compose_final.log)
- `GET /salud`, `/docs` y `/openapi.json` respondieron 200 desde el host. Una consulta desde el contenedor API confirmó TCP, `app_rw`, PostgreSQL 16.15 y los cinco índices de 008. [Comprobación del servicio](evidencias_etapa_6/servicio.log)
- `docker exec atuel-etapa6-validada-api-1 python -m unittest discover -s api/tests -v` ejecutó **10 pruebas**, todas exitosas. Incluye precio negativo, confirmación diferida de corte inválido, transición inválida y stock insuficiente en el segundo renglón. La última comprobó que cabecera, renglones y stock se revirtieron. También se verificaron auditoría, subtipos, filtros, paginación y flujos exitosos. [Salida de integración](evidencias_etapa_6/integracion.log)
- Se aplicaron 001–008 y pasó `tests/db_tests.sql` en una base nueva del laboratorio de 55441 mediante `python db/benchmarks/etapa_4/medir.py regresion --prefijo atuel_e4e6 --salida docs/evidencias_etapa_6`. [Regresión](evidencias_etapa_6/regresion.log)

### Inyección SQL

```powershell
curl.exe 'http://127.0.0.1:18066/vinos?nombre=%27+OR+1%3D1%3B+DROP+TABLE+vino%3B+--'
```

La prueba HTTP envió ese mismo filtro. La respuesta fue **200 con `[]`** y `SELECT count(*) FROM vino` devolvió **3 antes y 3 después**. [Evidencia](evidencias_etapa_6/integracion.log)

### Alcance pendiente

U1 conserva el criterio histórico pendiente de validación docente. U6 sigue como demostración reversible de etapa 5. La propuesta 009 queda pendiente de aprobación, incluida la vigencia de la excepción al perder permisos.
