# Reporte auditable · Etapa 5

## Resumen

Rama `etapa-5-consultas`, con las 30 consignas de la sección 8. Este archivo reúne el informe y el reporte auditable. La fase A se omitió porque falta `008_indices.sql`. Las pruebas se ejecutaron el 3 de noviembre de 2026 en `atuel_base_test`, PostgreSQL 16.15, con 500.000 renglones de venta. El acceso se hizo por el socket del contenedor de laboratorio tras verificar que publica en 55441. El proceso que ejecutó psql desde el host no recibió la variable de contraseña.

## Tabla de criterios de aceptación

| Criterio | Estado | Evidencia |
|---|---|---|
| Las 30 consignas tienen código, enunciado y estrategia | OK | Cuatro archivos SQL |
| DML con controles previos y posteriores, transacción y ROLLBACK | OK | UPDATE, INSERT y DELETE |
| Filas afectadas, datos concretos y comportamiento real de triggers | OK | Logs PostgreSQL por archivo |
| Avanzadas con vista, CTE, ventanas, correlación y división según corresponda | OK | S9–S12 |
| EXPLAIN ANALYZE de las consultas candidatas y avanzadas | OK | Nueve planes en select_final.log |

## Tabla por consigna

| Código | Archivo y línea | Filas afectadas o devueltas |
|---|---|---|
| U1 | [update.sql:1](../consultas/update.sql#L1) | 0 de 150.000 evaluados |
| U2 | [update.sql:20](../consultas/update.sql#L20) | 50 |
| U3 | [update.sql:28](../consultas/update.sql#L28) | 30 |
| U4 | [update.sql:36](../consultas/update.sql#L36) | 17 |
| U5 | [update.sql:44](../consultas/update.sql#L44) | 10 |
| U6 | [update.sql:55](../consultas/update.sql#L55) | 0 de la carga, 1 en la demostración |
| I1 | [insert.sql:1](../consultas/insert.sql#L1) | 0, cobertura existente |
| I2 | [insert.sql:18](../consultas/insert.sql#L18) | 1 maridaje y 90 asociaciones |
| I3 | [insert.sql:33](../consultas/insert.sql#L33) | 1 cabecera y 3 renglones |
| I4 | [insert.sql:58](../consultas/insert.sql#L58) | 1 |
| I5 | [insert.sql:66](../consultas/insert.sql#L66) | 1 |
| I6 | [insert.sql:74](../consultas/insert.sql#L74) | 1 cabecera y 1 renglón de 120 botellas |
| D1 | [delete.sql:1](../consultas/delete.sql#L1) | 0 con cinco años, 33.822 cabeceras y 112.822 renglones con un año |
| D2 | [delete.sql:29](../consultas/delete.sql#L29) | 0 |
| D3 | [delete.sql:37](../consultas/delete.sql#L37) | 0 |
| D4 | [delete.sql:45](../consultas/delete.sql#L45) | 0 |
| D5 | [delete.sql:53](../consultas/delete.sql#L53) | 600 cabeceras |
| D6 | [delete.sql:63](../consultas/delete.sql#L63) | 1 cliente |
| S1 | [select.sql:3](../consultas/select.sql#L3) | 10 |
| S2 | [select.sql:11](../consultas/select.sql#L11) | 100 |
| S3 | [select.sql:15](../consultas/select.sql#L15) | 3 |
| S4 | [select.sql:19](../consultas/select.sql#L19) | 0 |
| S5 | [select.sql:27](../consultas/select.sql#L27) | 25 |
| S6 | [select.sql:31](../consultas/select.sql#L31) | 0 |
| S7 | [select.sql:35](../consultas/select.sql#L35) | 0 |
| S8 | [select.sql:39](../consultas/select.sql#L39) | 25 |
| S9 | [select.sql:47](../consultas/select.sql#L47) | 1 |
| S10 | [select.sql:61](../consultas/select.sql#L61) | 3.000 |
| S11 | [select.sql:69](../consultas/select.sql#L69) | 2.500 para ranking y 475 para acumulado |
| S12 | [select.sql:83](../consultas/select.sql#L83) | 0 para división y 226 sin compras de tintos |

## Decisiones y ambigüedades

- U1 recalcula el total histórico con el descuento ya aplicado al renglón. Cuenta diferencias y actualiza solo las filas que cambiarían.
- U6 pide 35 % y RN-06 fija 30 %. El catálogo es compartido por todos los exportadores. El ensayo relaja el CHECK del catálogo y guarda la excepción en una columna temporal por exportador. La propuesta 009 incorpora esa columna con su CHECK y modifica `fn_descuento_cliente` para leerla. El catálogo puede conservar su CHECK de 30 % como tasa base cuando la excepción vive en el subtipo. La propuesta requiere acuerdo docente y queda fuera de las migraciones.
- D1 cuenta el umbral literal de cinco años y, si da cero, usa un año como umbral de demostración ajustable. El purgado de archivo conserva el stock. U1 y D1 suspenden ambos triggers de inmutabilidad dentro de la transacción y requieren dueño de las tablas o superusuario. `app_rw` carece de ese permiso.
- D5 suspende y rehabilita dentro del ensayo el trigger de renglones de ingreso que rechaza el CASCADE de un documento cerrado. Conserva el stock resultante de la recepción histórica.
- I1 cuenta transportistas con cero envíos y desempata por código. Una cobertura ya existente puede dar cero inserciones. S7 mide actividad por número de ingresos.
- S3 y S4 incluyen el día actual. S7 y S8 usan meses calendario móviles. S10 compara parcelas de la misma finca y campaña, ponderando cada parcela por igual.

## Evidencia y línea base

- [UPDATE final](evidencias_etapa_5/update_final.log), [INSERT](evidencias_etapa_5/insert.log), [DELETE](evidencias_etapa_5/delete.log) y [SELECT final](evidencias_etapa_5/select_final.log) registran comandos, hora y salida.
- En I3 el total guardado coincidió con la función (2.738,70) y el stock bajó de 10 a 9 para cada uno de los tres vinos. En D1 el control de stock dio verdadero.
- El primer UPDATE se detuvo en U6 porque el nombre del CHECK inferido era incorrecto. Se consultó el catálogo, se corrigió a `tipo_cliente_check` y se repitió el archivo. El primer SELECT se canceló en S12. La versión final agrupa primero las compras por cliente y conserva la división con doble NOT EXISTS.
- S1, S4, S8 y S10 constituyen la línea base sin índices de etapa 4. El [catálogo previo](evidencias_etapa_5/preflight.log) registró 36 índices de claves y unicidad preexistentes. Sus tiempos de ejecución fueron 116,215 ms, 0,128 ms, 53,184 ms y 686,706 ms, respectivamente. Son mediciones de una corrida.

- El [control posterior](evidencias_etapa_5/control_final.log) devolvió 20 controles en cero, los tres triggers habilitados, ningún permiso de demostración, ninguna columna temporal de descuento y el CHECK original de 30 %.

## Cosas no verificadas

- La propuesta 009 quedó sin aplicar. Falta la decisión docente sobre la vigencia de la excepción al perder permisos.
- S4 y S7 devolvieron cero filas con las ventanas temporales vigentes. S4 se midió con ese resultado y su tiempo describe esa distribución de datos.
- Falta la comparación de rendimiento con índices de etapa 4.

## Riesgos

- El historial tiene fechas fijas en el generador. U6 encontró cero candidatos reales. El ensayo adicional insertó permisos ficticios para un solo exportador y revirtió todo al final.
- ALTER TABLE toma bloqueos sobre tablas. Ejecutar los ensayos en una base de laboratorio aislada. ROLLBACK revierte las filas y el DDL, mientras que los valores consumidos de secuencias pueden dejar huecos.
- El historial Git contiene commits que tocaron `.env`. La etapa 5 conserva el historial y no imprime su contenido. La presencia histórica de valores reales queda sin verificar.

## Preguntas de defensa

1. ¿Por qué U1 usa el descuento histórico del renglón y qué sucede al cambiar el descuento de un cliente?
2. ¿Por qué hace falta suspender dos triggers en D1 y qué cambia al ejecutar el CASCADE?
3. ¿Por qué U6 requiere guardar un descuento por exportador?
4. ¿Cómo evita S9 multiplicar filas cuando hay varias cepas y varios maridajes?
5. ¿Qué expresa el doble NOT EXISTS de S2 y S12?
6. ¿Qué condiciones deben cumplirse para comparar los planes antes y después de agregar índices?
