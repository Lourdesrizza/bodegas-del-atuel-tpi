# Bitácora · etapa 7

## 2026-11-07 · Cinco pantallas y paleta final

Se completaron catálogo, alta y edición de vino, nueva venta, transferencias y tablero en `etapa-7-frontend`. La interfaz utiliza HTML, CSS y JavaScript. Se aplicaron los colores de la referencia y se ajustó la navegación para pantallas angostas. Python sirve el front y reenvía las solicitudes al mismo origen, con métodos y rutas permitidos explícitamente. Se añadió `front` al Compose para servir la interfaz junto a la API y PostgreSQL.

Se mantuvo el contrato de etapa 6. Los selectores que dependen de rutas inexistentes usan códigos. Los renglones de transferencias que se ven son los agregados en la sesión actual. El comprobante presenta el total que devuelve la API después de registrar la venta. U1, U6, D1 y D5 siguen sujetos a la decisión docente.

Pasaron ocho pruebas del proxy y los chequeos de sintaxis. Se aplicaron 001–008 a una base PostgreSQL 18.1 nueva en un clúster local independiente. Con datos ficticios se probaron en el navegador paginación y detalle, alta y edición, rechazo de corte al 80 %, venta con comprobante y stock insuficiente, creación y procesamiento de transferencia, ranking, gráfico y consulta de faltantes. Una venta de dos renglones falló en el segundo y los conteos y el stock del primero quedaron iguales. Evidencia en `docs/evidencias_etapa_7/validacion_local.log`.

La interfaz se revisó con datos de prueba en navegador y se comprobó que no desborda a 385 ni a 308 px. La configuración de Compose pasó `docker compose config --quiet`. Su ejecución sigue pendiente porque el motor de Docker Desktop no respondió. Se trabajó en archivos locales y una base exclusiva de prueba, sin commit ni push.

## 2026-11-04 · Bocetos e inicio del catálogo

Se leyó la página 18 de la consigna. La rama local `etapa-7-frontend` se creó desde el commit publicado `8c7b8cad0aecae321590ec5e93e9e6b4cc42b9ec` de `etapa-6-api`, con árbol de trabajo limpio. No se alteraron los archivos de etapas 4, 5 o 6.

Se revisaron `api/main.py`, `api/data.py` y el esquema OpenAPI generado sin iniciar la base. El contrato ofrece filtros `tipo`, `cepa` (ID), `bodega` (CUIT), `anada` y `nombre`; paginación `limite`/`offset`; y detalle con composición y maridajes. Swagger en vivo (`127.0.0.1:8000`) no respondió porque Docker Desktop no entregó su motor Linux en esta sesión. La generación local de `app.openapi()` sí confirmó parámetros y límites. Los campos del cuerpo de respuesta se comprobaron en el SQL y el serializador de la API: Swagger no define un `response_model` para esos GET.

Se hicieron bocetos de las cinco pantallas en `front/bocetos.md`. Sólo se implementó el catálogo en HTML, CSS y JavaScript sin framework: lista paginada, filtros, detalle y mensajes `detail` de la API. `front/api.js` concentra las llamadas. `front/config.js` fija la ruta base del navegador y `front/server.py` sirve los archivos y reenvía únicamente las dos consultas GET del catálogo. El destino de la API se configura con `ATUEL_API_URL`. Se eligió el proxy porque la API actual no configura CORS; no hubo que modificarla.

Decisiones pendientes: no existen endpoints de catálogo para llenar desplegables de cepa, bodega y maridaje por nombre; la lista de vinos no incluye conteo total; el detalle no trae razón social de bodega. Se usan ID/CUIT y paginación con una fila adicional. Un esquema de respuesta OpenAPI más preciso, la integración en Docker Compose y las pantallas de alta, venta, transferencias y tablero quedan pendientes. También se mantienen sin decidir U1, U6, D1 y D5 hasta recibir la respuesta de la profesora.

### Comprobaciones y límites

- La generación local de OpenAPI con las dependencias fijadas de `api/requirements.txt` devolvió 22 rutas y confirmó los siete parámetros de `GET /vinos` y el identificador positivo de `GET /vinos/{cod}`.
- `node --check` pasó para `app.js`, `api.js` y `config.js`. La prueba de `api.js` comprobó filtros, `limite=13`, `offset=12`, ruta de detalle y preservación literal de un `detail` recibido con HTTP 409. Un primer intento de esa prueba usó una opción de Node no disponible; se repitió con `--input-type=module` y pasó.
- Una API simulada local confirmó que `front/server.py` sirve la página, reenvía lista y detalle, conserva el cuerpo y código HTTP 409, y rechaza una ruta fuera del catálogo con 404. La sintaxis Python pasó y `git diff --check` no detectó problemas.
- No se probó aún con PostgreSQL real ni se inspeccionó visualmente en un navegador con datos cargados: Docker Desktop no entregó el motor Linux y `127.0.0.1:8000` rechazó la conexión. No se ejecutó carga ni se cambió ninguna base existente.

## 2026-11-04 · Ajuste visual del catálogo

Se cambió sólo `front/styles.css` para usar una paleta rosa y ciruela, con encabezado degradado, filtros y tarjetas de bordes suaves, botones con estados claros y foco visible. Se mantuvo buen contraste para textos y errores. Se agregó una columna para filtros en pantallas de hasta 430 px.

Se revisaron capturas locales en Chrome sin API conectada a 1440 px y 500 px: encabezado, filtros y paginación se ven ordenados. La captura solicitada a 390 px quedó recortada por el ancho mínimo de la ventana de Chrome en modo headless; el punto de corte de 430 px se revisó en el CSS, pero queda pendiente una comprobación visual en un dispositivo de ese ancho y con vinos reales. No se modificó la lógica ni se hizo push.
