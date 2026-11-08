# Etapa 4 · Índices y rendimiento

## Alcance y datos

Medición del 3 de noviembre de 2026 en PostgreSQL 16.15, en el contenedor de laboratorio publicado en 55441. La rama parte de `bda026e`. El enunciado y las consultas de etapa 5 se consultaron desde la referencia publicada `b70b0b19f923b217a6721d6c9cdf5e126dc168bd`, sin integrarla a la rama.

Se aplicaron 001–007 en `atuel_e4m_sin_test`, creada desde `template0`. Se copió el volcado de datos de `atuel_base_test` por el socket del contenedor, sin escribir en la base fuente. La restauración se hizo en una sola transacción de la base nueva, con triggers suspendidos por el volcado durante la copia. Se refrescó la vista materializada, se obtuvieron cero incumplimientos en los 20 controles de etapa 3 y se ejecutó `VACUUM (ANALYZE)`. La base `atuel_e4m_con_test` se creó como clon de ese estado. La primera preparación se revirtió cuando el volcado dejó vacío el `search_path`. Calificar la vista con `public` corrigió el problema en las bases de la medición.

La carga tiene **150.000 comprobantes, 500.000 renglones de venta, 3.000 renglones de transferencia y 3.000 lotes**. El escenario inicial tiene 36 índices preexistentes. Solo el clon indexado recibió 008 y quedó con 41. Las huellas ordenadas de las tablas de la medición coinciden entre la fuente y ambos escenarios. Los resultados de las cinco consultas también coinciden entre escenarios.

[Preparación](evidencias_etapa_4/preparacion.log) · [Catálogo sin 008](evidencias_etapa_4/catalogo_sin.log) · [Catálogo con 008](evidencias_etapa_4/catalogo_con.log) · [Huellas](evidencias_etapa_4/integridad.log)

## Diseño de 008

| Índice | Justificación |
|---|---|
| `idx_comprobante_sala_fecha` | S3 filtra por igualdad de sala antes del rango de fechas. Por eso `id_sala` precede a `fecha`. Incluye `id_cliente` para el cruce y el conteo distinto. |
| `idx_comprobante_fecha_ventas` | S8 filtra por fecha para todas las salas. La fecha lidera el B-tree y `INCLUDE (id_sala, total)` permite agrupar y sumar desde el índice cuando la visibilidad lo permite. Tiene un prefijo distinto al índice de S3. |
| `idx_renglon_transferencia_vino_solicitud` | S4 busca primero por `cod_vino`, una FK. La PK existente empieza por `nro_solicitud`. El nuevo orden encuentra los renglones del vino y aporta el identificador para el join y la cantidad para la suma. |
| `idx_transferencia_pendiente_sala` | Parcial para S5. El predicado `estado <> 'procesado'` coincide con la consulta, excluye el historial procesado y es independiente del reloj. La carga actual tiene cero pendientes, así que su utilidad en presencia de pendientes queda justificada por el diseño. |
| `idx_ingreso_transportista_fecha` | La FK `cod_transportista` lidera el índice para ubicar dependencias del transportista y filtrar por fecha dentro de ese conjunto, como en I1. El dataset concentra todos los ingresos en una fecha y no permite atribuirle una mejora temporal representativa. |

## Comparación de lectura

Se ejecutó `ANALYZE` en ambos escenarios. Cada serie tiene una corrida de calentamiento separada y siete corridas medidas, alternando qué base se ejecuta primero. Se usó el mismo SQL en los dos escenarios y se compararon todas las filas devueltas. Los tiempos son la mediana de `Execution Time` del servidor en milisegundos. Un cambio negativo indica menos tiempo.

S1 mide el ranking general oficial. La S1 trimestral que figura en la evidencia de etapa 5 es otra consulta y no participa en esta comparación. S3 usa sala 1 y la semana inclusiva del 22 al 28 de octubre de 2026. S4 usa el vino 1 y la ventana histórica inclusiva del 16 de febrero al 2 de marzo de 2025. S8 usa el trimestre histórico inclusivo del 28 de julio al 28 de octubre de 2026. S10 usa la consulta oficial para todas las campañas. Las consignas originales de etapa 5 conservan sus ventanas relativas.

| Consulta | Tiempo sin 008 | Tiempo con 008 | Cambio | Recorrido | Filas y buffers |
|---|---:|---:|---:|---|---|
| S1 oficial | 85,111 ms | 91,790 ms | +7,85 % | Parallel Seq Scan de renglones en ambos | ≈500.000 → ≈500.000 renglones examinados. 10 filas de salida. 3.756 → 3.756 buffers. |
| S3 benchmark | 35,876 ms | 20,574 ms | −42,65 % | Seq Scan → Index Only Scan en comprobante | 150.000 → 67 cabeceras. 3 filas de salida. 1.583 → 299 buffers. |
| S4 histórica | 0,668 ms | 0,469 ms | −29,79 % | Seq Scan → Index Only Scan en renglón. Seq Scan de cabecera en ambos | 3.000 → 25 renglones y 600 cabeceras en ambos. 5 filas de salida. 27 → 13 buffers. |
| S8 histórica | 23,049 ms | 14,152 ms | −38,60 % | Seq Scan → Index Only Scan en comprobante | 150.000 → 24.454 cabeceras. 25 filas de salida. 1.295 → 108 buffers. |
| S10 oficial | 630,381 ms | 732,210 ms | +16,15 % | Seq Scan de lote y parcela en ambos, con subconsulta correlacionada sobre el CTE | 3.000 lotes y 600 parcelas en ambos. 3.000 filas de salida. 35 → 35 buffers. |

Las filas examinadas corresponden al recorrido indicado e incluyen las descartadas por filtros, ajustadas por ciclos. PostgreSQL redondea promedios de nodos paralelos, por eso S1 figura como aproximación. Los buffers son los bloques compartidos del nodo superior en la corrida de la mediana. En esas corridas todos fueron hits y no hubo lecturas de bloques compartidos. Los tres `Index Only Scan` tuvieron cero accesos al heap.

**S3, S4 y S8 mejoraron** en tiempo, filas examinadas y buffers. En S4 la diferencia absoluta es **0,199 ms** y la fecha concentra las transferencias en un día. El ahorro observado viene de filtrar los renglones por vino. S1 y S10 tuvieron medianas más altas con el mismo recorrido y los mismos buffers. La dispersión entre corridas y la ausencia de cambios de plan impiden atribuir esas diferencias a los índices.

## Candidato descartado e índice no utilizado

Se evaluó un BRIN sobre `comprobante.fecha` en una transacción del escenario sin 008. La correlación física observada fue **−0,0038**, cercana a cero. S8 conservó el Seq Scan y examinó la tabla completa. Las dos observaciones fueron 21,783 y 19,921 ms, con el mismo recorrido. El BRIN quedó fuera porque el planificador no lo eligió y el B-tree elegido sí redujo el trabajo. [Plan y ROLLBACK del candidato](evidencias_etapa_4/descartado.log)

En el escenario indexado, una suma de `total` y `subtotal` sobre todo el historial eligió **Parallel Seq Scan** a pesar del índice de fecha. El filtro cubre los 150.000 comprobantes y `subtotal` requiere consultar el heap. [Plan de baja selectividad](evidencias_etapa_4/no_utilizado.log)

## Costo de escritura

Cada corrida creó un clon fresco del escenario correspondiente, con sus 150.000 cabeceras iniciales. El mismo `INSERT … SELECT` agregó otras 150.000 cabeceras a la tabla real, con FK activas y numeración nueva. Se midió el tiempo del servidor con `EXPLAIN (ANALYZE, BUFFERS, WAL)`, seguido de ROLLBACK. El tiempo de clonar y descartar la base queda fuera de la medición. Se alternó el orden y se excluyó la primera corrida por escenario. Este ensayo mide los dos índices adicionales de comprobante. Los demás índices de 008 están en tablas que esta carga no escribe.

| Indicador | Sin 008 | Con 008 |
|---|---:|---:|
| Mediana de 7 corridas | 7.046,384 ms | 8.607,975 ms |
| Mediana de registros WAL del nodo superior | 300.411 | 602.101 |
| Mediana de bytes WAL del nodo superior | 23.483.046 | 49.371.718 |

La carga fue **22,16 % más lenta** con los dos índices de comprobante y generó aproximadamente **2,10 veces** los bytes WAL. El costo corresponde a este patrón de escritura masiva con FK activas.

## Validación y reproducción

008 se aplicó en el clon indexado y también sobre 001–007 en una base vacía de regresión. La suite tests/db_tests.sql terminó con código 0. El ensayo concurrente reutilizó el fixture de la prueba existente por el socket del contenedor. Una venta confirmó y la otra recibió el rechazo de stock insuficiente. El stock final fue cero y quedó un renglón vendido. Los scripts y planes permiten volver a medir con la misma carga y parámetros. Para comparar después de ajustar índices, se debe mantener el SQL de cada consulta, su ventana y el dataset.

Desde la raíz, con Python 3 y Docker disponibles, ejecutar con un prefijo nuevo y una carpeta de salida distinta a la evidencia versionada:

```powershell
foreach ($fase in 'preparar','base','aplicar','comparar','extras','escritura','regresion','integridad','concurrencia') {
    python db/benchmarks/etapa_4/medir.py $fase --prefijo atuel_e4rep --salida evidencia_e4rep
    if ($LASTEXITCODE) { break }
}
```

## Anexo de planes completos

- [SQL de lectura y parámetros](../db/benchmarks/etapa_4/consultas.sql)
- [Planes de exploración sin 008](evidencias_etapa_4/planes_exploracion.json)
- [Planes comparados, calentamientos y resultados](evidencias_etapa_4/planes_comparados.json)
- [Planes y WAL de escritura](evidencias_etapa_4/escritura.json)
- [Aplicación de 008 en el escenario indexado](evidencias_etapa_4/aplicacion_008.log)
- [Registro de sesiones](evidencias_etapa_4/sesiones.log)
- [Regresión desde cero](evidencias_etapa_4/regresion.log)
- [Venta concurrente](evidencias_etapa_4/concurrencia.log)
