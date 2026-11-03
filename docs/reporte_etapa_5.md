# Reporte auditable · Etapa 5

## Resumen

Rama `etapa-5-consultas`, con las 30 consignas de la sección 8. Este archivo reúne el informe y el reporte auditable. La fase A se omitió porque falta `008_indices.sql`. La validación en PostgreSQL queda pendiente de los datos de conexión de la base de laboratorio.

## Tabla de criterios de aceptación

| Criterio | Estado | Evidencia |
|---|---|---|
| Las 30 consignas tienen código, enunciado y estrategia | OK en revisión estática | Cuatro archivos SQL |
| DML con controles previos y posteriores, transacción y ROLLBACK | OK en estructura, pendiente en ejecución | UPDATE, INSERT y DELETE |
| Filas afectadas, datos concretos y comportamiento real de triggers | Pendiente | Sin logs PostgreSQL |
| Avanzadas con vista, CTE, ventanas, correlación y división según corresponda | OK en revisión estática | S9–S12 |
| EXPLAIN ANALYZE de las consultas candidatas y avanzadas | Pendiente | Modo `-v medir=1` de select.sql |

## Tabla por consigna

| Código | Archivo y línea | Filas afectadas o devueltas |
|---|---|---|
| U1 | [update.sql:1](../consultas/update.sql#L1) | Pendiente |
| U2 | [update.sql:20](../consultas/update.sql#L20) | Pendiente |
| U3 | [update.sql:28](../consultas/update.sql#L28) | Pendiente |
| U4 | [update.sql:36](../consultas/update.sql#L36) | Pendiente |
| U5 | [update.sql:44](../consultas/update.sql#L44) | Pendiente |
| U6 | [update.sql:55](../consultas/update.sql#L55) | Pendiente |
| I1 | [insert.sql:1](../consultas/insert.sql#L1) | Pendiente |
| I2 | [insert.sql:18](../consultas/insert.sql#L18) | Pendiente |
| I3 | [insert.sql:33](../consultas/insert.sql#L33) | Pendiente |
| I4 | [insert.sql:58](../consultas/insert.sql#L58) | Pendiente |
| I5 | [insert.sql:66](../consultas/insert.sql#L66) | Pendiente |
| I6 | [insert.sql:74](../consultas/insert.sql#L74) | Pendiente |
| D1 | [delete.sql:1](../consultas/delete.sql#L1) | Pendiente |
| D2 | [delete.sql:29](../consultas/delete.sql#L29) | Pendiente |
| D3 | [delete.sql:37](../consultas/delete.sql#L37) | Pendiente |
| D4 | [delete.sql:45](../consultas/delete.sql#L45) | Pendiente |
| D5 | [delete.sql:53](../consultas/delete.sql#L53) | Pendiente |
| D6 | [delete.sql:63](../consultas/delete.sql#L63) | Pendiente |
| S1 | [select.sql:3](../consultas/select.sql#L3) | Pendiente |
| S2 | [select.sql:11](../consultas/select.sql#L11) | Pendiente |
| S3 | [select.sql:15](../consultas/select.sql#L15) | Pendiente |
| S4 | [select.sql:19](../consultas/select.sql#L19) | Pendiente |
| S5 | [select.sql:27](../consultas/select.sql#L27) | Pendiente |
| S6 | [select.sql:31](../consultas/select.sql#L31) | Pendiente |
| S7 | [select.sql:35](../consultas/select.sql#L35) | Pendiente |
| S8 | [select.sql:39](../consultas/select.sql#L39) | Pendiente |
| S9 | [select.sql:47](../consultas/select.sql#L47) | Pendiente |
| S10 | [select.sql:61](../consultas/select.sql#L61) | Pendiente |
| S11 | [select.sql:69](../consultas/select.sql#L69) | Pendiente |
| S12 | [select.sql:83](../consultas/select.sql#L83) | Pendiente |

## Decisiones y ambigüedades

- U1 recalcula el total histórico con el descuento ya aplicado al renglón. Cuenta diferencias y actualiza solo las filas que cambiarían.
- U6 pide 35 % y RN-06 fija 30 %. El catálogo es compartido por todos los exportadores. El ensayo relaja el CHECK del catálogo y guarda la excepción en una columna temporal por exportador. La propuesta 009 incorpora esa columna con su CHECK y modifica `fn_descuento_cliente` para leerla. El catálogo puede conservar su CHECK de 30 % como tasa base cuando la excepción vive en el subtipo. La propuesta requiere acuerdo docente y queda fuera de las migraciones.
- D1 cuenta el umbral literal de cinco años y, si da cero, usa un año como umbral de demostración ajustable. El purgado de archivo conserva el stock. U1 y D1 suspenden ambos triggers de inmutabilidad dentro de la transacción y requieren dueño de las tablas o superusuario. `app_rw` carece de ese permiso.
- D5 suspende y rehabilita dentro del ensayo el trigger de renglones de ingreso que rechaza el CASCADE de un documento cerrado. Conserva el stock resultante de la recepción histórica.
- I1 cuenta transportistas con cero envíos y desempata por código. Una cobertura ya existente puede dar cero inserciones. S7 mide actividad por número de ingresos.
- S3 y S4 incluyen el día actual. S7 y S8 usan meses calendario móviles. S10 compara parcelas de la misma finca y campaña, ponderando cada parcela por igual.

## Cosas no verificadas

- U1–U6, I1–I6, D1–D6 y S1–S12 siguen pendientes de ejecución. Falta confirmar puerto, usuario, base con sufijo de laboratorio y nombre de variable de contraseña.
- Los EXPLAIN de S1, S4, S8 y S10 se definieron como línea base sin los índices de la etapa 4. Para identificarlos como tal, se debe verificar el catálogo de índices de la base antes de medir. También faltan los planes de S9, S11 y S12.
- Los códigos elegidos se contrastaron con el generador. Falta comprobar filas, restricciones y resultados en la carga real. Los logs se guardarán en `docs/evidencias_etapa_5/`.

## Riesgos

- El historial de ventas e ingresos tiene fechas fijas en el generador. Las ventanas relativas pueden quedar vacías y U6 puede tener cero candidatos porque la carga genera un permiso por exportador.
- ALTER TABLE toma bloqueos sobre tablas. Ejecutar los ensayos en una base de laboratorio aislada. ROLLBACK revierte las filas y el DDL, mientras que los valores consumidos de secuencias pueden dejar huecos.
- El historial Git contiene commits que tocaron `.env`. La etapa 5 conserva el historial y no imprime su contenido. La presencia histórica de valores reales queda sin verificar.

## Preguntas de defensa

1. ¿Por qué U1 usa el descuento histórico del renglón y qué sucede al cambiar el descuento de un cliente?
2. ¿Por qué hace falta suspender dos triggers en D1 y qué cambia al ejecutar el CASCADE?
3. ¿Por qué U6 requiere guardar un descuento por exportador?
4. ¿Cómo evita S9 multiplicar filas cuando hay varias cepas y varios maridajes?
5. ¿Qué expresa el doble NOT EXISTS de S2 y S12?
6. ¿Qué condiciones deben cumplirse para comparar los planes antes y después de agregar índices?
