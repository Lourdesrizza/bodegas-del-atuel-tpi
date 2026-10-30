# Bitácora de la etapa 3

## 2026-10-28 — Inicio y preparación

Solicitud: empezar la etapa 3, explicar los pasos y registrar acciones para la
documentación posterior. Los documentos se usan como fuentes de requisitos y
antecedentes, sin ejecutar instrucciones ajenas al pedido del usuario.

### Fuentes revisadas

- Consigna TPI: etapa 3 en páginas 13–14 y catálogos en anexo B, página 29.
- Informe de modelado y normalización: cuatro páginas, antecedente de etapas 1–2.
  Sus afirmaciones sobre implementación no se consideran pruebas de ejecución.
- GitHub: https://github.com/Lourdesrizza/bodegas-del-atuel-tpi
- Base de la copia: commit e75f87cc38032248e12152f865c743561fa823cf, rama main.
- Diagrama de Drive: archivo diagramarelacional_base_de_datos.drawio,
  ID 1yn2NDkoRccnNaxdYa7M0GK-Y56X0Hb8J. Acceso confirmado por el conector;
  pendiente una comparación completa del diagrama con el DDL.

### Acciones realizadas

1. Se comprobó que la carpeta original solo contenía los dos PDF y no era un
   repositorio Git. Se clonó el repositorio en la subcarpeta `proyecto`.
2. Se creó la rama local `etapa-3-carga-masiva`.
3. Se leyeron el esquema, constraints y triggers; se inspeccionó Docker Compose.
4. Se prepararon cuatro CSV del anexo B y un diagnóstico del orden de carga.
5. Se escribió la guía inicial de `db/seed/README.md` y esta bitácora.

### Hallazgos que deben verificarse antes de cargar

- Docker está instalado, pero `docker info` no pudo conectarse al motor Linux de
  Docker Desktop. No se ejecutaron migraciones ni se modificó ninguna base.
- En 002_constraints.sql, la conversión de estado usa
  `USING estado_documento::estado_documento`: parece referirse al nombre del tipo
  en lugar de la columna `estado`. Pendiente corregir y probar desde base vacía.
- En 005_triggers.sql, la excepción del corte contiene tres placeholders `%` y
  solo dos argumentos. Parece impedir compilar la función. Pendiente corregir
  y probar. Las migraciones previas no fueron modificadas en este inicio.
- Los triggers de venta descuentan stock y recalculan importes; no se puede
  cargar un stock final y volver a descontar las mismas ventas históricas.
- El trigger de transferencia impone CURRENT_DATE: hay que decidir explícitamente
  cómo preservar las fechas históricas sin dejar validaciones desactivadas.
- Existe `.gitgnore` (nombre incorrecto), además de `.env` y `.venv` versionados.
  No se imprimieron credenciales ni se cambió el historial remoto.
- El informe menciona una unicidad de localidad que no se observó en las
  migraciones 001–002. No asumir que informe, diagrama y SQL coinciden totalmente.

### Decisiones iniciales

- Conservar los PDF originales y trabajar dentro de la copia local.
- Usar CSV del anexo, sin generar catálogos al azar.
- Preparar metas de 20.000 clientes, 150.000 comprobantes y 500.000 renglones.
- Separar objetivos de resultados medidos: todavía no hay tiempos de carga,
  conteos reales ni evidencia de reproducibilidad en PostgreSQL.
- No se realizaron commits, push ni cambios remotos.

### Comprobación realizada

`python db/seed/plan_carga.py` finalizó correctamente: verificó los cuatro
catálogos y organizó las 29 tablas del esquema en cuatro niveles, sin ciclos ni
referencias a tablas ausentes. Esta es una comprobación estática del DDL;
no demuestra que las migraciones se ejecuten correctamente en PostgreSQL.

### Cómo continuar el registro

Por cada avance anotar: fecha, objetivo, archivos modificados, decisión y motivo,
comprobación ejecutada, resultado y pendientes. Conservar también errores y sus
soluciones para poder explicarlos en la defensa.

## 2026-10-28 — Revisión solicitada de etapas 1 y 2

Se revisaron requisitos, fuentes drawio, informe y SQL; se creó una instancia
aislada PostgreSQL 18 para probar sin depender de Docker ni tocar otras bases.
Se confirmaron los errores de migraciones 002 y 005. Solo se ajustaron copias
temporales externas para poder revisar las demás reglas; las migraciones del
repositorio permanecen intactas.

Se agregaron `docs/revision_etapas_1_2.md`, logs en `docs/evidencias_revision/`
y `tests/revision_etapas_1_2.sql`. Se reprodujeron brechas de descuentos,
jerarquía, precio, edición de ventas, redondeo, estados, renglones y permisos.
Se confirmó atomicidad ante transferencia sin stock y rechazo concurrente de
la segunda venta de la última botella mediante CHECK de stock no negativo.
La suite existente termina con éxito tras dos ajustes temporales, pero contiene
falsos positivos. No se considera evidencia de aceptación integral.

Decisión: las etapas 1–2 necesitan correcciones antes de la carga definitiva.
Pendientes y prioridades detallados en el informe. Sin commit ni push.

## 2026-10-28 — Corrección de etapas 1 y 2

Objetivo: cerrar las brechas del informe de revisión antes de la carga masiva. Se trabajó en la rama local `etapa-3-carga-masiva`; no hubo push, merge ni cambios remotos. Los PDF superiores no se modificaron.

### Cambios y decisiones

1. `001_esquema.sql` crea ENUM y DOMAIN antes de las tablas. Se quitó de 002 la creación tardía y las conversiones duplicadas. Se agregó catálogo `tipo_cliente` con descuentos fijos 10/20/30; `cliente` ya no duplica el descuento.
2. `003_funciones.sql` consulta el catálogo y calcula totales con los importes históricos redondeados por renglón. Se documentó la política de comprobantes inmutables. `005_triggers.sql` fija precio del catálogo, descuenta stock con UPDATE condicional, impide editar ventas y valida pertenencia única y correspondiente a subtipos.
3. Los procedimientos de ingreso y transferencia toman vinos en orden de código; se añadieron procedimientos para terminar documentos. Los triggers de renglón bloquean y validan tanto cabecera OLD como NEW. El corte se comprueba también al insertar vino o mover un componente. El ingreso verifica que cada vino pertenece a su bodega.
4. `007_roles.sql` crea dueño separado `app_owner` sin LOGIN y roles API/lectura sin claves en SQL. El rol API no escribe auditoría, stocks, totales ni estados procesados. Las rutinas de escritura corren como dueño con `search_path` fijado. Se ajustaron privilegios futuros y se retiró USAGE de secuencias al rol de lectura.
5. `.gitignore` sustituye el nombre mal escrito como archivo efectivo. `.env` y `.venv` se retiraron **sólo del índice** mediante `git rm --cached`; siguen físicamente en el equipo. No se reescribió el historial, por lo que secretos antiguos en commits previos requieren tratamiento separado si fueron reales.
6. `tests/db_tests.sql` ahora ejecuta una suite sin TRUNCATE global ni excepciones capturadas por la propia prueba. Se añadieron scripts para migrar en base nueva y ensayar dos ventas simultáneas. Se generaron esquema escrito, diccionario por columna, dos drawio editables, normalización corregida y trazabilidad.

### Errores encontrados al comprobar

- Docker Desktop seguía sin motor Linux disponible. Se usó provisionalmente PostgreSQL 18.1, clúster nuevo `C:/Users/puent/.codex/tmp/atuel-fix-pg18`, puerto local 55440. Nunca se ejecutó la limpieza de 001 en una base existente.
- La primera versión de 007 intentó transferir secuencias vinculadas a tablas por separado; PostgreSQL lo rechazó. Se corrigió transfiriendo la tabla, que arrastra su secuencia.
- La primera prueba de FK reveló que el dueño de las tablas necesitaba USAGE en el esquema tras revocar PUBLIC. Se concedió.
- Un fixture que esperaba total 0,10 para dos unidades en **un mismo renglón** era incorrecto: el neto es 0,09. Se corrigió y se agregó un caso real de dos renglones cuyos netos de 0,05 suman 0,10.
- El ensayo de privilegios futuros mostró que `ALTER DEFAULT PRIVILEGES ... IN SCHEMA` no quita el EXECUTE global de PUBLIC. Se corrigió con REVOKE global para `app_owner`.

### Resultado comprobado

`python tests/run_exclusive.py atuel_cierre_final3_test` creó una base exclusiva y aplicó 001–007 con `psql -X -v ON_ERROR_STOP=1`; las siete migraciones y la suite terminaron con código 0. Evidencia: `docs/evidencias_cierre/atuel_cierre_final3_test.log`.

`python tests/concurrencia_ultima_botella.py atuel_concurrencia_cierre_test` creó otra base exclusiva: dos sesiones vendieron simultáneamente la última botella; códigos de salida 0 y 3, stock final 0, una venta confirmada. Evidencia: `docs/evidencias_cierre/atuel_concurrencia_cierre_test.log`.

### Pendientes honestos

- Repetir migraciones, regresión y concurrencia en Docker Compose PostgreSQL 16 cuando el motor esté disponible. La prueba 18.1 es provisional.
- Ampliar aún los negativos de cantidades de RN-15 y pruebas de permisos efectivas del rol de sólo lectura; la trazabilidad indica lo probado.
- Abrir los dos drawio revisados en un editor y revisar visualmente cardinalidades, jerarquía, legibilidad y líneas superpuestas. También comparar con la versión actual de Drive si se desea sincronizar ese archivo, sin cambios remotos en esta tarea.
- El informe revisado es Markdown separado de los PDF originales. Si la entrega exige PDF, exportarlo y revisar páginas visualmente.
- La carga masiva definitiva y las mediciones de rendimiento siguen pendientes. La consigna U6 (35 % a algunos exportadores) contradice RN-06 (30 %); resolver en la etapa 5 sin alterar el cierre actual.

### Validación final ampliada

Se agregaron casos de redondeo con dos renglones, cambio de vino en composición, traslado OLD/NEW de renglones, transferencia sin stock con estado y stock intactos, fecha inmutable, borrado restrictivo de los tres maestros y privilegio de funciones futuras. La prueba inicial de borrado de bodega falló porque `ON DELETE RESTRICT` devuelve `restrict_violation` (23001), no siempre `foreign_key_violation` (23503). Se ajustó la expectativa de la prueba, sin cambiar la regla.

`python tests/run_exclusive.py atuel_cierre_validacion2_test`: migraciones 001–007 y suite, todos código 0, PostgreSQL 18.1. Log: `docs/evidencias_cierre/atuel_cierre_validacion2_test.log`. Se regeneraron los diagramas y diccionario desde esa base.

Se intentó iniciar Docker Desktop en segundo plano y luego el servicio local; el motor Linux siguió inaccesible y el servicio no pudo iniciarse. PostgreSQL 16 continúa pendiente. Los intentos fallidos previos se conservaron en `docs/evidencias_cierre/` como registro del proceso, sin presentarlos como aceptación.

### Última pasada

Se eliminaron los `DROP TABLE` heredados de 001 y el `DROP MATERIALIZED VIEW` de 006: las migraciones sólo crean objetos en una base nueva. La corrida final `python tests/run_exclusive.py atuel_cierre_definitivo_test` aplicó 001–007 y la suite sin errores, código 0; `python tests/concurrencia_ultima_botella.py atuel_concurrencia_definitiva_test` volvió a dejar una venta, un rechazo y stock 0. Logs definitivos en `docs/evidencias_cierre/atuel_cierre_definitivo_test.log` y `docs/evidencias_cierre/atuel_concurrencia_definitiva_test.log`. El diccionario y los drawio se regeneraron desde `atuel_cierre_definitivo_test`.

Se agregaron las últimas negativas para descuento incompatible, cantidad cero y escritura con rol de sólo lectura. La corrida `python tests/run_exclusive.py atuel_cierre_final_ok_test` volvió a pasar 001–007 y `tests/db_tests.sql` con código 0. Evidencia más reciente: `docs/evidencias_cierre/atuel_cierre_final_ok_test.log`.

## 2026-10-29 — Implementación y carga de la etapa 3

### Fuentes y decisiones

Se releyeron las páginas 13–14 y el anexo B de la consigna, los siete SQL actuales, procedimientos, triggers, roles y la documentación corregida. Los cuatro CSV iniciales coinciden con los catálogos sugeridos. Se agregó `db/seed/catalogos/localidades.csv` con 20 pares de localidades y CP de Mendoza: los CP de cuatro cifras se contrastaron con la tabla oficial RENAPER (páginas 174–178) y todos los nombres fueron confirmados en la API oficial Georef como **localidades** de Mendoza. Tres candidatos iniciales (Lavalle, Las Paredes y San Pedro del Atuel) no aparecieron con coincidencia exacta en esa API y fueron sustituidos por Palmira, La Consulta y Real del Padre. La fuente RENAPER usa CP de localidad de cuatro cifras; no se presenta como CPA vigente de domicilio de ocho caracteres.

Se eligieron Python, `psycopg` 3.2.10, Faker 37.11.0 y `random.Random` con semilla 20261029 y fecha de referencia 2026-10-28. Las dependencias transitivas también quedaron fijadas. El programa rechaza nombres de base que no terminen en `_test` o `_dev`, revisa que las 30 tablas estén vacías salvo `tipo_cliente`, y no crea ni vacía bases automáticamente. Se usan IDs explícitos y al final se sincronizan secuencias.

Se planifican primero ventas ficticias para calcular demanda por sala y vino. Ingresos suficientes suman depósito; transferencias suficientes llevan stock a salas; sólo después se cargan los comprobantes y se descuentan sus ventas. Ingresos y transferencias se terminan/procesan con los procedimientos existentes. Las fechas son lógicas: campañas 2020–2024, ingresos enero 2025, transferencias marzo 2025 y ventas abril 2025 a octubre 2026. El vino 1 cambia de precio mediante su trigger normal y crea auditoría antes de vender.

Para conservar fecha histórica de transferencia se desactiva **sólo** `trg_fecha_transferencia` durante el COPY de cabeceras. Para el historial de 500.000 renglones se desactivan **sólo** `trg_valida_stock_renglon` y `trg_descuenta_stock_actualiza_totales` durante ese COPY; Python calcula importes en centavos y una actualización agregada descuenta demanda del stock. Se rehabilitan esos triggers antes de `SET CONSTRAINTS ALL IMMEDIATE`, 20 controles de integridad y `REFRESH MATERIALIZED VIEW`. Todo ocurre dentro de una transacción, por lo que un error revierte datos y `ALTER TABLE`. No se usa `session_replication_role`, y FK/CHECK permanecen activas.

### Pruebas, errores y resultados

Docker Desktop se intentó iniciar, pero el motor Linux continuó inaccesible el 29/10. Se usó provisionalmente PostgreSQL 18.1 local en 127.0.0.1:55440. Todas las bases fueron nuevas y exclusivas. La primera revisión del generador detectó antes de ejecutar que dividir importes enteros descartaría centavos; se corrigió usando centavos y `Decimal` para los campos monetarios.

La carga pequeña pasó en `atuel_seed_small1_test` y `atuel_seed_small2_test` con la misma huella. La carga completa pasó en dos bases nuevas (`atuel_seed_full3_test` y `atuel_seed_full4_test`) con 20.000 clientes, 150.000 comprobantes, 500.000 renglones, 30 tablas con filas, 20 controles en cero y la misma huella SHA-256 de datos. Los campos `auditoria_precio.fecha_hora` y `usuario` quedan fuera de la huella porque dependen de la ejecución; el resto de la auditoría sí se compara. Logs sin credenciales: `docs/evidencias_carga/full_a.log`, `full_b.log`, `pequena.log` y `validacion_lectura.log`.

La muestra de 1.000 filas en la misma tabla temporal sin índices/triggers tardó 0,095/0,097 s con INSERT individual y 0,004/0,004 s con COPY. La ejecución completa, con controles, huella y COMMIT, tardó 24,690 y 25,178 s. Intentar cargar de nuevo una base poblada produjo error antes de escribir. La vista materializada y la tabla de comprobantes suman ambas 1.146.038.536,10.

Se creó localmente `dump_completo.sql.gz` (6.087.363 bytes, ignorado por Git) mediante `pg_dump` y se restauró en `atuel_restore_test`. Después de reaplicar 007, la base restaurada pasó validación y reprodujo la huella y los 500.000 renglones de venta. No se hizo push, merge, cambio remoto ni se borraron bases existentes. La carga definitiva fuera de laboratorio sigue sin ejecutarse.

### Entrega y pendiente

`db/seed/cargar_datos.py`, `requirements.txt`, `catalogos/localidades.csv`, `validar_carga.sql`, `compose.test.yml`, `README.md` y `docs/reporte_etapa_3.md` contienen implementación, instrucciones y evidencia. Queda repetir carga pequeña, completa, validación y restauración con PostgreSQL 16 del Docker Compose de prueba cuando Docker funcione. Hasta entonces el criterio de entorno Docker no está confirmado.

Comprobación adicional: se alteró deliberadamente el stock de una sala dentro de una transacción y el validador detectó exactamente un incumplimiento; se revirtió con ROLLBACK. Los tres triggers suspendidos temporalmente estaban habilitados después de confirmar la carga. `docs/evidencias_carga/control_negativo.log` conserva el resultado. También se simplificaron las funciones cortas de CUIT, precio y tipo de cliente; una carga pequeña posterior reprodujo la misma huella. `plan_carga.py` ahora verifica el quinto CSV de localidades.

Última corrida del código ya simplificado: carga completa en `atuel_seed_final_test`, 25,096 s, 20 controles en cero y la misma huella SHA-256. Log: `docs/evidencias_carga/full_final.log`. La consulta a Georef de los 20 nombres quedó registrada con identificadores en `docs/evidencias_carga/catalogos.log`.

### Corrección final y evidencias definitivas

Después de esas corridas se corrigió `numero_doc`: los socios usan DNI ficticio de ocho dígitos y los clientes empresa, CUIT ficticio de once. Se volvió a cargar desde cero en `atuel_seed_small_final_test` y en dos bases completas nuevas, `atuel_seed_finala_test` y `atuel_seed_finalb_test`. Los resultados anteriores quedan como historial de desarrollo; las cifras definitivas son las de `docs/reporte_etapa_3.md`.

Las dos cargas completas posteriores a la corrección dieron la misma huella SHA-256 `d1d72d692be506f59c9d31826439774ae427959dd44c22eaee1f9dda05be8a1c`, 20 controles en cero y tiempos totales de 25,484 s y 26,521 s. La muestra de INSERT individual tardó 0,090 s y 0,098 s; la misma muestra con COPY, 0,004 s en ambos casos. Logs: `docs/evidencias_carga/pequena_final.log`, `full_final_a.log` y `full_final_b.log`.

Se generó de nuevo `dump_completo.sql.gz` desde la base final A (6.086.603 bytes comprimidos) y se restauró en la base nueva `atuel_restore_final_test`: 20 controles en cero, 500.000 renglones de venta y la misma huella. Evidencia: `docs/evidencias_carga/restauracion_final.log`. El dump local permanece ignorado por Git. PostgreSQL 16 en Docker sigue pendiente porque el motor de Docker Desktop no respondió.

## 2026-10-29 — Verificación pendiente completada en Docker PostgreSQL 16

El usuario avisó que Docker Desktop estaba abierto. `docker info` respondió con motor 29.7.2. El Compose aislado pidió `ATUEL_TEST_PASSWORD`, que no estaba definida; se generó una clave efímera sólo en memoria, sin escribirla en archivos ni logs. Se comprobó antes que no existían el contenedor ni el volumen de esta prueba. Se descargó `postgres:16-alpine` y se creó `atuel_pg16_carga_test` con volumen nuevo `seed_atuel_pg16_carga_test_data`; el servidor informó versión **16.15**. No se borró ni vació ningún volumen.

En la base nueva `atuel_pg16_rules_20261029_test`, `tests/run_exclusive.py` aplicó 001–007 con `ON_ERROR_STOP=1` y pasó `tests/db_tests.sql` (reglas positivas y negativas). En `atuel_pg16_concurrency_20261029_test`, las dos ventas simultáneas de la última botella terminaron con salidas `[0,3]`, una venta confirmada, una rechazada y stock cero. Logs: `docs/evidencias_cierre/atuel_pg16_rules_20261029_test.log` y `atuel_pg16_concurrency_20261029_test.log`.

Se crearon tres bases nuevas más con 001–007: `atuel_pg16_small_20261029_test`, `atuel_pg16_fulla_20261029_test` y `atuel_pg16_fullb_20261029_test`. La pequeña pasó 20 controles. Las dos completas dieron 20.000 clientes, 150.000 comprobantes, 500.000 renglones, todas las 30 tablas con filas y 20 controles en cero. Tiempos totales 76,311 s y 74,501 s. En muestra igual de 1.000 filas, INSERT individual tardó 1,274/1,078 s y COPY 0,006/0,006 s. Las dos completas tuvieron la misma huella `cc7eda8516018adee1c5d10726b8b6673bf662acd71d44c0246f284d20be8a34`; la comparación se hizo entre bases nuevas del mismo PG16. `app_ro` pudo ejecutar los 20 controles con cero fallos. Los tres triggers suspendidos sólo durante COPY quedaron habilitados. Logs de migraciones, cargas, lectura y resumen en `docs/evidencias_carga/` con sufijo `pg16_20261029`.

Durante el resumen adicional se consultó erróneamente `total_ventas` en la vista materializada; esa columna no existe. Se corrigió la consulta a `total_facturado` y se repitió con éxito: cabeceras y vista suman ambas 1.146.038.536,10. Este error fue sólo de la consulta de resumen y no afectó datos ni validaciones.

`pg_dump` del contenedor PG16 generó `dump_completo_pg16.sql.gz` (5.907.614 bytes, ignorado por Git). Se creó `atuel_pg16_restore_20261029_test`, se restauró allí, se reaplicó 007 y se ejecutó el validador: 20 controles en cero, 500.000 renglones y la misma huella de las dos bases completas. Evidencia: `docs/evidencias_carga/restauracion_pg16_20261029.log`. El dump previo de PG18 se conservó. La verificación que antes estaba pendiente por Docker queda completada; no se hizo carga definitiva, push, merge ni cambio remoto.

## 2026-10-29 — Informe de estudio para el grupo

Se prepararon `docs/informe_estudio_etapas_1_2_3.md` y su versión editable Word
`docs/Informe_de_estudio_Bodegas_del_Atuel_etapas_1_2_3.docx`. Explican modelo,
normalización, correcciones, RN-01 a RN-15, funciones, procedimientos, triggers,
roles, concurrencia, generación, controles, conteos, tiempos y restauración.
Incluyen ejemplos y preguntas con respuestas para practicar la defensa.

Se contrastó el contenido con los SQL actuales, README, reporte, bitácora y logs
PG16. Se aclararon las notas antiguas que todavía marcaban Docker como pendiente,
los campos excluidos de la huella y el alcance de las validaciones del dataset.
Se corrigió en este informe la descripción del mínimo de volumen: hay cuatro
tablas con más de 10.000 filas, al incluir socio con 12.000.
No se volvieron a ejecutar cargas ni se modificaron migraciones o datos.
La conversión habitual falló por falta de LibreOffice; se usó Word instalado
para exportar una copia temporal y revisar visualmente la presentación.
