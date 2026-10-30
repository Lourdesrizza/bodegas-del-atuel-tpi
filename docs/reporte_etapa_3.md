# Reporte de carga masiva — etapa 3

Fecha: 2026-10-29. Rama local: `etapa-3-carga-masiva`. Esquema: 30 tablas de las migraciones actuales. Primero se probó en PostgreSQL 18.1 local; la verificación definitiva de este reporte se hizo después en PostgreSQL **16.15** del Compose aislado, puerto 55441, siempre con bases nuevas. No se ejecutó carga sobre bases existentes.

## Fuentes y estrategia

Los cuatro CSV iniciales proceden del anexo B de la consigna. `localidades.csv` contiene 20 localidades confirmadas en [Georef](https://www.argentina.gob.ar/georef) y pares de CP de cuatro cifras contrastados con la [tabla RENAPER](https://www.argentina.gob.ar/sites/default/files/renaper_plazosentrega_0.pdf), páginas 174–178. Se trata del CP de localidad, no del [CPA actual de una dirección concreta](https://www.correoargentino.com.ar/categorias/consulta-cpa). Las personas, empresas, calles y movimientos son ficticios y reproducibles con semilla `20261029` y fecha de referencia `2026-10-28`.

El log `docs/evidencias_carga/catalogos.log` conserva los 20 identificadores devueltos por Georef y el método de consulta.

El orden físico y la razón de cada desactivación temporal de trigger están en `db/seed/README.md`. Ingresos y transferencias se procesan por procedimientos; las ventas históricas se importan por COPY con dos triggers de inserción suspendidos en la misma transacción. Antes del COMMIT se rehabilitan, se fuerzan restricciones diferidas y se ejecutan 20 controles de integridad. No se suspende ninguna FK ni CHECK.

## Conteos de la base completa

| Tabla | Filas | Tabla | Filas |
|---|---:|---|---:|
| localidad | 20 | sala_venta | 25 |
| empleado | 50 | finca | 20 |
| cepa | 12 | parcela | 600 |
| bodega | 20 | lote_uva | 3.000 |
| analisis_calidad | 3.000 | vino | 600 |
| composicion | 600 | maridaje | 8 |
| vino_maridaje | 600 | tipo_cliente | 3 |
| cliente | 20.000 | socio | 12.000 |
| distribuidor | 5.000 | exportador | 3.000 |
| permiso_exportacion | 3.000 | transportista | 30 |
| transportista_localidad | 60 | stock_deposito | 600 |
| stock_sala | 3.000 | ingreso | 600 |
| renglon_ingreso | 3.000 | transferencia | 600 |
| renglon_transferencia | 3.000 | comprobante | 150.000 |
| renglon_comprobante | 500.000 | auditoria_precio | 1 |

Las 30 tablas tienen filas; tres superan 10.000 y dos superan 100.000. Los mínimos de la etapa 3 se alcanzaron en PostgreSQL 18.1. La vista materializada se refrescó: suma facturada en vista y en `comprobante` = **1.146.038.536,10** en ambos casos.

## Tiempos medidos

Ambas cargas completas partieron de bases nuevas y ejecutaron idéntico código. Segundos de reloj de pared medidos con `time.perf_counter()`:

| Medición | Base A | Base B |
|---|---:|---:|
| Muestra 1.000 INSERT individuales | 0,090 | 0,098 |
| Misma muestra con COPY | 0,004 | 0,004 |
| COPY de 150.000 cabeceras y 500.000 renglones | 13,682 | 13,959 |
| Generación, carga, controles y refresh | 23,937 | 24,896 |
| Ejecución completa, incluida huella y COMMIT | 25,484 | 26,521 |

La comparación de métodos usa la misma tabla temporal sin índices ni triggers, la misma muestra de 1.000 filas y un TRUNCATE de esa tabla temporal entre métodos. Es una medición acotada de inserción; no se presenta como estimación de todas las reglas y tablas. Los logs definitivos están en `docs/evidencias_carga/full_final_a.log` y `full_final_b.log`.

## Integridad, determinismo y repetición

Las cargas pequeñas y completas terminaron con los 20 controles en cero. Se revisaron conteos, FK, huérfanos en relaciones críticas, cortes, subtipos, descuentos, fechas, importes, estados y las dos ecuaciones de stock. La misma consulta pasó después con `app_ro`; evidencia: `docs/evidencias_carga/validacion_lectura.log`.

Como prueba negativa, dentro de una transacción se alteró en una unidad el stock de una sala: `validar_carga.sql` devolvió `stock_sala=1`; se hizo ROLLBACK. Se comprobó además que los tres triggers suspendidos durante la importación terminaron habilitados (`tgenabled='O'`). Evidencia: `docs/evidencias_carga/control_negativo.log`.

La huella SHA-256 de las 30 tablas completas fue idéntica en dos bases nuevas: `d1d72d692be506f59c9d31826439774ae427959dd44c22eaee1f9dda05be8a1c`. Sólo se omitieron `auditoria_precio.fecha_hora` y `auditoria_precio.usuario`, dependientes de cuándo y con qué cuenta se hizo la carga; se incluyeron el ID, vino y precios de esa auditoría. La carga pequeña final tiene huella `c607da46016262c897d95434e076822e357449938964aec700bc350ce2b94cf5`. Intentar repetir la carga sobre una base poblada produjo error antes de escribir, en vez de duplicar silenciosamente.

La última corrección usa DNI ficticio de ocho dígitos para socios y CUIT ficticio de once para empresas. Ambas cargas completas definitivas (`atuel_seed_finala_test`, `atuel_seed_finalb_test`) se ejecutaron después de esa corrección.

Se generó localmente `dump_completo.sql.gz` con `pg_dump --no-owner --no-privileges`: 6.086.603 bytes comprimidos, ignorado por Git. Se restauró en la nueva base `atuel_restore_final_test`, se reaplicó 007 para dueño y permisos, se repitió la validación y se obtuvo la misma huella y 500.000 renglones de venta. Los comandos están en el README.

La comprobación de restauración quedó guardada en `docs/evidencias_carga/restauracion_final.log`: 20 controles, ningún fallo.

## Verificación posterior en PostgreSQL 16.15 del Compose

Docker Desktop respondió el 29/10 y se creó el contenedor aislado `atuel_pg16_carga_test` con el volumen nuevo `seed_atuel_pg16_carga_test_data`; no existían antes y no se borró ningún volumen. `tests/run_exclusive.py` creó `atuel_pg16_rules_20261029_test`, aplicó 001–007 con `ON_ERROR_STOP=1` y pasó `tests/db_tests.sql`. La prueba de concurrencia en `atuel_pg16_concurrency_20261029_test` produjo códigos `[0,3]`: una venta confirmada, una rechazada y stock final cero. Evidencias: `docs/evidencias_cierre/atuel_pg16_rules_20261029_test.log` y `atuel_pg16_concurrency_20261029_test.log`.

La carga pequeña pasó en `atuel_pg16_small_20261029_test`. Las cargas completas pasaron en otras dos bases nuevas, `atuel_pg16_fulla_20261029_test` y `atuel_pg16_fullb_20261029_test`. Las siete migraciones se aplicaron de cero en cada una. Las dos completas dieron **20.000 clientes, 150.000 comprobantes, 500.000 renglones, 30 tablas con filas y 20 controles en cero**. La vista materializada y las cabeceras sumaron ambas **1.146.038.536,10**; los tres triggers suspendidos temporalmente estaban habilitados tras confirmar. El validador volvió a dar 20 ceros con `SET ROLE app_ro`.

| Medición PG16.15, segundos | Completa A | Completa B |
|---|---:|---:|
| 1.000 INSERT individuales | 1,274 | 1,078 |
| Las mismas 1.000 filas con COPY | 0,006 | 0,006 |
| Fase de ventas | 49,699 | 48,991 |
| Generación, carga, controles y refresh | 74,730 | 72,863 |
| Ejecución completa con huella y COMMIT | 76,311 | 74,501 |

La huella de las dos bases completas PG16 fue idéntica: `cc7eda8516018adee1c5d10726b8b6673bf662acd71d44c0246f284d20be8a34`. La carga pequeña PG16 tuvo huella `cc06c8777708007db337b96baac6f257508151c6768403dc99e352b038f5c793`. Son distintas de las huellas de las corridas previas en PostgreSQL 18; la reproducibilidad exigida se comprobó con dos bases nuevas de **la misma versión y entorno PG16**. Los campos de auditoría dependientes de la ejecución se excluyeron con el mismo criterio documentado arriba.

`pg_dump` de la imagen PG16 generó `dump_completo_pg16.sql.gz` (5.907.614 bytes), ignorado por Git. Se restauró en la base nueva `atuel_pg16_restore_20261029_test`, se reaplicó 007 para dueño y permisos, y se obtuvieron 20 controles en cero, 500.000 renglones y la misma huella. Evidencias: `docs/evidencias_carga/pequena_pg16_20261029.log`, `full_a_pg16_20261029.log`, `full_b_pg16_20261029.log`, `validacion_lectura_pg16_20261029.log`, `resumen_pg16_20261029.log` y `restauracion_pg16_20261029.log`.

La comprobación pendiente en Docker 16 quedó **cumplida**. Las mediciones de PG18 se conservan arriba como antecedentes; no se generó ni subió ningún dump remoto ni se hizo carga definitiva fuera de bases de prueba.
