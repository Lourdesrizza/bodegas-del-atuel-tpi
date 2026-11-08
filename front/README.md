# Etapa 7 · Front de Bodegas del Atuel

Las cinco pantallas usan HTML, CSS y JavaScript. `server.py` sirve los archivos y reenvía las llamadas a la API. El navegador muestra los importes, el stock y los mensajes que devuelve PostgreSQL a través de FastAPI.

## Abrir la interfaz

Si la API ya está disponible, ejecutá desde la raíz del proyecto en PowerShell:

```powershell
$env:ATUEL_API_URL = 'http://127.0.0.1:8000'
python front/server.py
```

Abrí <http://127.0.0.1:5173>. El puerto del front se configura con `ATUEL_FRONT_PORT`. `config.js` indica que el navegador llama a `/api`, y el servidor de Python dirige esas llamadas a `ATUEL_API_URL`. El proxy permite los GET, POST y PUT usados por estas pantallas y conserva el estado HTTP y el texto de error.

## Docker Compose

Configurá las contraseñas del entorno de laboratorio siguiendo el [README principal](../README.md) y ejecutá `docker compose up -d --build`. Compose incluye `db`, `api` y `front`. Dentro de Compose, el front llama a `http://api:8000`; desde Windows se abre en `127.0.0.1:5173`. Para usar formularios y reportes necesitás datos de laboratorio en esa base. Consultá la [guía de carga](../db/seed/README.md) para preparar una base de prueba.

## Pantallas

| Pantalla | Funciones disponibles |
|---|---|
| Catálogo | Filtrar por nombre, tipo, cepa, bodega y añada. Paginar y abrir el detalle con composición y maridajes. |
| Alta y edición | Crear una ficha o editarla por código o desde el detalle. Agregar cepas y guardar maridajes. El corte inválido muestra el mensaje de la API. |
| Nueva venta | Elegir un cliente, ingresar la sala y agregar renglones. Al confirmar, el comprobante muestra el subtotal, descuento y total devueltos por la API. |
| Transferencias | Crear o consultar una solicitud, agregar renglones, terminarla y procesarla. Los botones se habilitan según el estado recibido. |
| Tablero | Consultar los diez vinos más vendidos, el gráfico de ventas de los últimos tres meses y los vinos sin stock en una sala con existencia en depósito. |

Las rutas de etapa 6 reciben ID de cepa y maridaje, CUIT de bodega y código de sala. Los renglones nuevos de transferencias se muestran en la sesión en que se agregan, porque la consulta de una transferencia devuelve su cabecera. El catálogo pagina pidiendo una fila adicional para detectar si hay página siguiente.

La paleta usa Old Rose `#D58198`, rosa profundo `#AE5368`, Sand `#A89C70`, Ebony `#515335` y Dark Coffee `#503429`, los valores indicados para el diseño.

## Verificación

```powershell
node --check front/app.js
node --check front/api.js
python -m unittest discover -s front/tests -v
```

Se ejercitaron las cinco pantallas en el navegador con FastAPI y una base PostgreSQL 18.1 exclusiva. Se verificaron el rechazo de una composición inválida y la reversión de una venta de varios renglones sin stock. Ver [resultados](../docs/evidencias_etapa_7/validacion_local.log) y [bitácora](../docs/bitacora_etapa_7.md). `docker compose config --quiet` validó la configuración. Queda pendiente ejecutar el conjunto en Docker con PostgreSQL 16.
