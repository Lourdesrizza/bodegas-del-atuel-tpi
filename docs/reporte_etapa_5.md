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
| U6 | [update.sql:55](../consultas/update.sql#L55) | 0 elegibles en la carga; 1 reasignado y 2 ventas en el ensayo |
| I1 | [insert.sql:1](../consultas/insert.sql#L1) | 0, cobertura existente |
| I2 | [insert.sql:18](../consultas/insert.sql#L18) | 1 maridaje y 90 asociaciones |
| I3 | [insert.sql:33](../consultas/insert.sql#L33) | 1 cabecera y 3 renglones |
| I4 | [insert.sql:58](../consultas/insert.sql#L58) | 1 |
| I5 | [insert.sql:66](../consultas/insert.sql#L66) | 1 |
| I6 | [insert.sql:74](../consultas/insert.sql#L74) | 1 cabecera y 1 renglón de 120 botellas |
| D1 | [delete.sql:1](../consultas/delete.sql#L1) | 0 literal; ensayo separado: 1 cabecera y 1 renglón |
| D2 | [delete.sql:25](../consultas/delete.sql#L25) | 0 |
| D3 | [delete.sql:33](../consultas/delete.sql#L33) | 0 |
| D4 | [delete.sql:41](../consultas/delete.sql#L41) | 0 |
| D5 | [delete.sql:49](../consultas/delete.sql#L49) | 600 cabeceras y 3.000 renglones |
| D6 | [delete.sql:69](../consultas/delete.sql#L69) | 1 cliente |
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

- U1 concilia solo el total de cabecera según RN-08. La función suma los importes históricos de los renglones y preserva su precio y descuento. Esta interpretación de U1 requiere validación docente. Si subtotal o descuento de cabecera difieren, hace falta otra conciliación.
- U6 pide 35 % y RN-06 fija 30 %. El ensayo usa el cuerpo de la propuesta 009 dentro de una transacción y prueba ventas con la función redefinida. El catálogo conserva el 30 % y el CHECK del subtipo admite 30 o 35. Queda pendiente definir con la cátedra la excepción y qué pasa al perder permisos.
- D1 conserva el umbral literal de más de cinco años con CURRENT_DATE y devuelve cero en la carga. El ensayo positivo separado verifica el CASCADE y el stock. D1 suspende ambos triggers de inmutabilidad por el borrado en cascada. U1 suspende únicamente el de cabecera. Se requiere dueño de las tablas o superusuario.
- D5 suspende y rehabilita dentro del ensayo el trigger de renglones de ingreso que rechaza el CASCADE de un documento cerrado. Conserva el stock resultante de la recepción histórica.
- I1 cuenta transportistas con cero envíos y desempata por código. Una cobertura ya existente puede dar cero inserciones. S7 mide actividad por número de ingresos.
- S3 y S4 incluyen el día actual. S7 y S8 usan meses calendario móviles. S10 compara parcelas de la misma finca y campaña, ponderando cada parcela por igual.

## Evidencia y línea base

- [UPDATE final](evidencias_etapa_5/update_final.log), [INSERT](evidencias_etapa_5/insert.log), [DELETE](evidencias_etapa_5/delete.log) y [SELECT final](evidencias_etapa_5/select_final.log) registran comandos, hora y salida.
- En I3 el total guardado coincidió con la función (2.738,70) y el stock bajó de 10 a 9 para cada uno de los tres vinos. En D1 el control de stock dio verdadero.
- El primer UPDATE se detuvo en U6 porque el nombre del CHECK inferido era incorrecto. Se consultó el catálogo, se corrigió a `tipo_cliente_check` y se repitió el archivo. El primer SELECT se canceló en S12. La versión final agrupa primero las compras por cliente y conserva la división con doble NOT EXISTS.
- S1, S4, S8 y S10 constituyen la línea base sin índices de etapa 4. El [catálogo previo](evidencias_etapa_5/preflight.log) registró 36 índices de claves y unicidad preexistentes. Sus tiempos de ejecución fueron 116,215 ms, 0,128 ms, 53,184 ms y 686,706 ms, respectivamente. Son mediciones de una corrida.

- El [control posterior](evidencias_etapa_5/control_final.log) devolvió 20 controles en cero, los tres triggers habilitados, ningún permiso de demostración, ninguna columna temporal de descuento y el CHECK original de 30 %.

### Fechas y ventanas al cierre

Fecha de referencia de PostgreSQL: 2026-11-03.

| Tabla y columna | MIN | MAX |
|---|---|---|
| comprobante.fecha | 2025-04-01 | 2026-10-28 |
| transferencia.fecha_confeccion | 2025-03-01 | 2025-03-01 |
| ingreso.fecha | 2025-01-15 | 2025-01-15 |

| Consigna con CURRENT_DATE | Filas devueltas o insertadas | Filas de origen relevantes |
|---|---:|---|
| S3 | 3 | 8 comprobantes en la sala 1 |
| S4 | 0 | Sin transferencias en la ventana |
| S7 | 0 | Sin ingresos en la ventana |
| S8 | 25 | 22.851 comprobantes trimestrales |
| I1 | 0 insertadas | 0 ingresos trimestrales y la cobertura ganadora ya existe |

Las consignas mantienen CURRENT_DATE. Para comparar antes y después de etapa 4, repetir las mismas [variantes históricas](../consultas/linea_base.sql) y el ANALYZE en ambos escenarios. La [medición histórica sin índices de etapa 4](evidencias_etapa_5/linea_base_historica.log) registró:

| Variante | Ventana | Filas del nodo superior | Tiempo |
|---|---|---:|---:|
| S1 | 2026-07-28 a 2026-10-28, inclusive | 10 | 164,827 ms |
| S4 | 2025-02-16 a 2025-03-02, inclusive | 5 | 0,513 ms |
| S8 | 2026-07-28 a 2026-10-28, inclusive | 25 | 53,640 ms |
| S10 | Cosechas de 2024 | 600 | 103,191 ms |

### Estado después de ROLLBACK y regresión

[Controles de cierre](evidencias_etapa_5/controles_cierre.log) registra `tipo_cliente_check` con 30 % para exportadores, 150.000 comprobantes, 500.000 renglones y los 18 triggers de usuario con `tgenabled = O`. La [suite completa](evidencias_etapa_5/db_tests_cierre.log) aplicó 001–007 y ejecutó `tests/db_tests.sql` sin cambios, con código 0 y parada ante errores, sobre la base nueva `atuel_etapa5_regresion_test` del mismo servidor de laboratorio.

### S12 original y reformulada

La primera variante cruza los clientes con los vinos objetivo y vuelve a buscar la compra para cada par. La segunda agrupa las compras objetivo una vez por cliente antes de hacer la división. La parte de clientes sin compras de tintos es idéntica en ambas.

**Original**

```sql
WITH objetivo AS (
  SELECT cod_vino FROM vino
  WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1)
)
SELECT cl.id_cliente FROM cliente cl
WHERE EXISTS (SELECT FROM objetivo)
  AND NOT EXISTS (
    SELECT FROM objetivo v WHERE NOT EXISTS (
      SELECT FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante)
      WHERE c.id_cliente=cl.id_cliente AND r.cod_vino=v.cod_vino
    )
  )
ORDER BY cl.id_cliente;
```

**Reformulada**

```sql
WITH objetivo AS (
  SELECT cod_vino FROM vino
  WHERE cuit_bodega=(SELECT cuit FROM bodega ORDER BY cuit LIMIT 1)
), compras AS (
  SELECT c.id_cliente,array_agg(DISTINCT r.cod_vino) vinos
  FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante)
  JOIN objetivo v USING(cod_vino)
  GROUP BY c.id_cliente
)
SELECT c.id_cliente FROM compras c
WHERE NOT EXISTS (
  SELECT FROM objetivo v WHERE NOT EXISTS (
    SELECT FROM unnest(c.vinos) compra(cod_vino) WHERE compra.cod_vino=v.cod_vino
  )
)
ORDER BY c.id_cliente;
```

Para la misma bodega, ambas devolvieron 0 filas y EXCEPT devolvió 0 en cada sentido. La [prueba de equivalencia](evidencias_etapa_5/equivalencia_s12.log) usó un índice auxiliar únicamente para ejecutar la versión original. El índice se creó después de medir las variantes históricas y se revirtió con ROLLBACK. La parte común de tintos devolvió 226 clientes.

La [prueba con resultado no vacío](evidencias_etapa_5/equivalencia_s12_caso.log) creó dentro de la transacción una venta del cliente 1 con los 30 vinos de la bodega objetivo. Ambas consultas se ejecutaron sin cambios sobre copias temporales con esa compra y dos clientes, uno de ellos como control sin compras. El resultado fue:

| Original | Reformulada | Solo original (EXCEPT) | Solo reformulada (EXCEPT) |
|---:|---:|---:|---:|
| 1 | 1 | 0 | 0 |

Ambas devolvieron el cliente 1. El log incluye los listados completos de pg_indexes antes de BEGIN y después de ROLLBACK. En public quedaron los mismos 36 índices, con cero nuevos y cero faltantes. El catálogo conserva únicamente los índices preexistentes, sin índices de etapa 4. Los primeros intentos sobre todo el historial con la venta de prueba se cancelaron por demora de la consulta original.

## Correcciones tras la auditoría externa

La auditoría comparó `2bed30a` con `bda026e`. Los logs previos quedan como trazabilidad histórica. Las corridas nuevas del 3 de noviembre de 2026 usaron sesiones separadas, con parada ante errores, en PostgreSQL 16.15 sobre `atuel_base_test` por el contenedor publicado en 55441.

| Consigna | Resultado nuevo | Evidencia |
|---|---|---|
| D1 | 0 filas en la carga con el filtro literal. El caso positivo borró 1 cabecera y 1 renglón, conservó 2 cabeceras y 2 renglones de control y verificó el stock de sala intacto. | [DELETE completo](evidencias_etapa_5/delete_auditado.log), [caso D1](../consultas/pruebas/d1.sql), [salida D1](evidencias_etapa_5/d1_positivo.log) |
| U6 | 0 candidatos originales. El cliente con 5 permisos recibió 35 % y pagó 655,20. El cliente con 1 permiso recibió 30 % y pagó 705,60. Ambos renglones partieron de 1.008,00. | [Caso U6](../consultas/pruebas/u6.sql), [ventas](evidencias_etapa_5/u6_ventas.log) |
| U1 | 0 diferencias en 150.000 comprobantes. En el ensayo, 1 fila pasó de 908,20 a 907,20, igual a la función. Las comparaciones bidireccionales confirmaron renglones y stock intactos. | [UPDATE completo](evidencias_etapa_5/update_auditado.log), [caso U1](../consultas/pruebas/u1.sql), [salida U1](evidencias_etapa_5/u1_positivo.log) |
| D5 | 600 cabeceras y 3.000 renglones antes, 0 y 0 durante el ensayo. Stock del depósito idéntico y trigger habilitado. Una nueva conexión volvió a contar 600 y 3.000 tras el ROLLBACK. | [DELETE completo](evidencias_etapa_5/delete_auditado.log), [control posterior](evidencias_etapa_5/d5_restaurado.log) |
| D2 | 0 en la carga. El caso positivo eliminó la cepa sin referencias y conservó las plantadas. | [Caso D2](../consultas/pruebas/d2.sql), [salida D2](evidencias_etapa_5/d2_positivo.log) |
| D3 | 0 en la carga. Con fecha de baja externa 2026-11-03 se eliminó solo al empleado con menos de dos años. Se conservaron el límite exacto y el de mayor antigüedad. | [Caso D3](../consultas/pruebas/d3.sql), [salida D3](evidencias_etapa_5/d3_positivo.log) |
| D4 | 0 en la carga. Se eliminó al socio antiguo sin compras junto con su subtipo. Se conservaron el comprador y el socio en el límite de cinco años. | [Caso D4](../consultas/pruebas/d4.sql), [salida D4](evidencias_etapa_5/d4_positivo.log) |
| I1 | 0 en la carga. El desempate por código permitió insertar una nueva cobertura para General Alvear en el ensayo. | [Caso I1](../consultas/pruebas/i1.sql), [salida I1](evidencias_etapa_5/i1_positivo.log) |
| S4 | 0 en la ventana actual de la carga. El ensayo devolvió las salas 1 a 5 con 10, 9, 8, 7 y 6 botellas. El código menor resolvió el empate por el quinto puesto. | [Caso S4](../consultas/pruebas/s4.sql), [salida S4](evidencias_etapa_5/s4_positivo.log) |
| S7 | 0 en la ventana actual de la carga. El ensayo devolvió ambos líderes, transportistas 1 y 2 con 2 ingresos cada uno. | [Caso S7](../consultas/pruebas/s7.sql), [salida S7](evidencias_etapa_5/s7_positivo.log) |

### Planes oficiales y variantes históricas

Las dos familias ejecutaron ANALYZE y EXPLAIN (ANALYZE, BUFFERS). Los logs contienen el SQL, la fecha de referencia, los parámetros, los 36 índices preexistentes y los planes. La S1 oficial es el ranking general. La S1 histórica agrega un join con comprobante y un filtro trimestral, por lo que se compara exclusivamente contra el mismo SQL histórico.

| Consulta | Oficial, filas y ms | Histórica, filas y ms |
|---|---:|---:|
| S1 | 10 · 77,699 | 10 · 92,543 |
| S4 | 0 · 0,149 | 5 · 0,615 |
| S8 | 25 · 25,815 | 25 · 19,938 |
| S10 | 3.000 · 702,982 | 600 · 29,544 |

[SQL oficial](../consultas/linea_base_oficial.sql) · [Planes oficiales](evidencias_etapa_5/linea_base_oficial_auditada.log) · [SQL histórico](../consultas/linea_base.sql) · [Planes históricos](evidencias_etapa_5/linea_base_historica_auditada.log)

Para etapa 4 se debe repetir cada consulta con el mismo SQL, parámetros, fecha efectiva para ventanas relativas y carga. Sigue ausente `008_indices.sql`. Las mediciones corresponden a una base sin esos índices y quedan como línea base.

### Estado al finalizar

Desde una conexión nueva se verificaron 150.000 comprobantes, 500.000 renglones, 18 triggers de usuario en estado O, el CHECK original del 30 %, ausencia de la columna y permisos del ensayo U6, y la definición original de `fn_descuento_cliente`. Las salidas SQL de los controles inicial y final coincidieron de forma ordinal. Las secuencias pueden avanzar durante los INSERT revertidos.

[Estado inicial](evidencias_etapa_5/auditoria_antes.log) · [Estado final](evidencias_etapa_5/auditoria_despues.log) · [Comparación](evidencias_etapa_5/auditoria_comparacion.log) · [Enunciado versionado](TPI_Bodegas_del_Atuel.pdf)

## Cosas no verificadas

- La propuesta 009 se ensayó dentro de ROLLBACK. Falta aprobación docente de la excepción a RN-06 y del criterio al perder permisos.
- S4 y S7 devolvieron cero filas con las ventanas temporales vigentes. La variante histórica de S4 mide una ventana con transferencias.
- Falta la comparación de rendimiento con índices de etapa 4.

## Conexión TCP

La usuaria verificó desde su terminal que `app_rw` conecta por TCP al puerto 55441 y que PostgreSQL rechaza las operaciones DDL con `InsufficientPrivilege`. El resultado se registra como verificación reportada por la usuaria.

## Riesgos

- Todas las transferencias tienen fecha 2025-03-01 y todos los ingresos tienen fecha 2025-01-15. Con esta distribución, S4, S7 e I1 se pueden ejecutar, pero sus ventanas relativas no permiten evaluar actividad reciente representativa. La variante histórica de S4 incluye filas, concentradas en un solo día.

- U6 encontró cero candidatos reales. El ensayo agregó cuatro permisos a un exportador y revirtió la modificación de la función, las ventas y los permisos al final.
- ALTER TABLE toma bloqueos sobre tablas. Ejecutar los ensayos en una base de laboratorio aislada. ROLLBACK revierte las filas y el DDL, mientras que los valores consumidos de secuencias pueden dejar huecos.
- El commit inicial `0167fae` incluyó por error un `.env` de desarrollo local. Según la verificación del grupo, contenía únicamente configuración y una contraseña local de desarrollo, sin credenciales reales. Se retiró del índice en `98b6877` durante la etapa 3. Se conservó el historial porque los datos eran de desarrollo local y el grupo decidió preservar los commits existentes. Para evitar repetirlo, `.gitignore` excluye `.env`, las claves se mantienen en el entorno y el repositorio conserva solo la plantilla `.env.example`. El [control Git](evidencias_etapa_5/gitignore_cierre.log) registra la regla, la plantilla permitida y el índice actual.

## Preguntas de defensa

1. ¿Por qué U1 usa el descuento histórico del renglón y qué sucede al cambiar el descuento de un cliente?
2. ¿Por qué hace falta suspender dos triggers en D1 y qué cambia al ejecutar el CASCADE?
3. ¿Por qué U6 requiere guardar un descuento por exportador?
4. ¿Cómo evita S9 multiplicar filas cuando hay varias cepas y varios maridajes?
5. ¿Qué expresa el doble NOT EXISTS de S2 y S12?
6. ¿Qué condiciones deben cumplirse para comparar los planes antes y después de agregar índices?
