# Bocetos de las cinco pantallas · etapa 7

Estos bocetos documentan el recorrido de las cinco pantallas implementadas. El diseño final usa la paleta Old Rose, Rosewood, Sand, Ebony y Dark Coffee.

## 1. Catálogo de vinos

```text
┌──────────────────────────────────────────────────────────────┐
│ Bodegas del Atuel · Catálogo                                  │
│ Nombre [____] Tipo [____] Cepa ID [__] Bodega CUIT [_______] │
│ Añada [____]                         [Buscar] [Limpiar]       │
│ Mensaje de la API, si existe                                  │
│ ┌ Vino 1 ┐  ┌ Vino 2 ┐  ┌ Vino 3 ┐ ...                       │
│ │ tipo   │  │ tipo   │  │ tipo   │                             │
│ │ precio │  │ precio │  │ precio │                             │
│ │ Detalle│  │ Detalle│  │ Detalle│                             │
│ [Anterior]                  Página N               [Siguiente] │
└──────────────────────────────────────────────────────────────┘
Detalle: datos del vino · composición con porcentajes · maridajes.
```

La API lista por `limite` y `offset`; no devuelve total de resultados. Cepa y bodega se filtran por ID y CUIT porque hoy no hay endpoints para poblar selectores con nombres.

## 2. Alta y edición de vino

```text
┌ Vino nuevo / Editar vino ─────────────────────────────────────┐
│ Bodega [____] Nombre [________] Tipo [____] Añada [____]      │
│ Volumen [__] Graduación [__] Precio [____]                    │
│ Composición: [Cepa ID][Porcentaje] [+ Agregar cepa]          │
│ Maridajes: [ID] [+ Agregar]                                   │
│ [Guardar]  Mensaje exacto de la API / regla de corte          │
└──────────────────────────────────────────────────────────────┘
```

La base valida el 100 % del corte. Falta decidir con el grupo cómo ofrecer catálogos de cepas, bodegas y maridajes por nombre.

## 3. Nueva venta

```text
┌ Nueva venta ──────────────────────────────────────────────────┐
│ Cliente [ID]  Sala [ID]                                       │
│ Vino [ID] Cantidad [__] [+ Renglón]                           │
│ Renglones elegidos                                            │
│ [Confirmar venta]                                             │
│ Respuesta de la API: comprobante con importes o error exacto  │
└──────────────────────────────────────────────────────────────┘
```

El navegador no calcula importes ni stock. La venta se confirma con `POST /comprobantes` y se muestra el resultado de la base.

## 4. Transferencias

```text
┌ Transferencias ───────────────────────────────────────────────┐
│ Sala [ID] [Nueva transferencia]                               │
│ Nro [__] Estado [en confección / terminado / procesado]      │
│ Vino [ID] Cantidad [__] [+ Renglón]                           │
│ [Terminar] [Procesar] (según estado)                           │
│ Mensaje exacto de la API                                      │
└──────────────────────────────────────────────────────────────┘
```

El estado mostrado por la API determina qué acciones se habilitan; los procedimientos de la base realizan las transiciones.

## 5. Tablero

```text
┌ Tablero ──────────────────────────────────────────────────────┐
│ Top 10 vinos vendidos      │ Ventas por sala, trimestre       │
│ 1. ...                     │ [Gráfico simple]                 │
│ Sala [ID]                  │ Vinos sin stock en esa sala      │
│ Mensaje exacto de la API                                      │
└──────────────────────────────────────────────────────────────┘
```

Los datos vienen de `/reportes/top-vinos`, `/reportes/ventas-por-sala` y `/reportes/vinos-sin-stock?sala=ID`. El navegador sólo presenta importes y stock recibidos.
