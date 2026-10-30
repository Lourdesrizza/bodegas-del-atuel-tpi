# Revisión de las etapas 1 y 2

Fecha: 2026-10-28. Base: e75f87cc38032248e12152f865c743561fa823cf.

## Dictamen

Las etapas tienen una estructura aprovechable, pero todavía no están cerradas.
No corresponde comenzar la carga masiva definitiva hasta corregir los bloqueos
de migración, las brechas de integridad y las pruebas que dan falsos positivos.
No se modificaron las migraciones originales durante esta revisión.

## Alcance y método

Se contrastaron el escenario, RN-01 a RN-15 y los entregables de las páginas 4–13
de la consigna, el informe de normalización, los dos fuentes drawio del repositorio,
las siete migraciones y tests/db_tests.sql. Los diagramas se inspeccionaron por su
estructura y etiquetas XML; queda pendiente la revisión visual de notación y
cardinalidades, y comparar la versión actual de Drive con la copia del repositorio.

Se inició un clúster desechable PostgreSQL 18 en
`C:/Users/puent/.codex/tmp/atuel-audit-pg`, puerto 55439, escuchando únicamente
en 127.0.0.1. No se usaron las credenciales ni otras bases del usuario.
La versión cumple el mínimo 14+, pero queda pendiente repetir en el contenedor
PostgreSQL 16 configurado por el proyecto: Docker Desktop no estaba funcionando.

Se ejecutaron las migraciones con `psql -X -v ON_ERROR_STOP=1`. Para continuar
después de los errores de 002 y 005 se usaron copias temporales fuera del repo:
en 002 se sustituyó `USING estado_documento::estado_documento` por
`USING estado::estado_documento` en sus dos apariciones; en 005 se escapó el
porcentaje literal de la excepción como `%%`. Se recreó el esquema tras el
fallo de 002. Las pruebas funcionales siguientes corresponden a esas dos
correcciones temporales, no a una ejecución limpia del original completo.

## Bloqueos confirmados

1. **002_constraints.sql, líneas 45 y 48:** usa un nombre de tipo como si fuera
   una columna. PostgreSQL devuelve `column "estado_documento" does not exist`.
   La ejecución se detiene en la línea 45.
2. **005_triggers.sql, línea 353:** la excepción tiene tres placeholders y dos
   argumentos. PostgreSQL devuelve `too few parameters specified for RAISE`.
   No se llega a crear el constraint trigger del corte.

001 se ejecutó correctamente. 003, 004, 006 y 007 se ejecutaron después de
aplicar únicamente los dos ajustes temporales anteriores.

## Integridad: casos reproducidos

El script `tests/revision_etapas_1_2.sql` reproduce los casos con ROLLBACK.
Los resultados completos están en `evidencias_revision/casos_reproducidos.log`.

| Prioridad | Hallazgo | Resultado observado | Corrección necesaria |
|---|---|---|---|
| Alta | RN-06: descuento sin correspondencia con tipo | socio con descuento 30 aceptado | Derivar descuento del tipo o imponer correspondencia exacta; probar combinaciones inválidas |
| Alta | Jerarquía sin exclusividad ni correspondencia | cliente socio también insertado en exportador | Validar coherencia de tipo y subtipo, pertenencia única y completitud al cierre de transacción |
| Alta | RN-08: cabecera editable a mano | total del comprobante cambiado a 1 | Proteger importes calculados y definir política de edición de comprobantes |
| Alta | RN-08/09: venta protegida solo al insertar | cantidad cambiada a 10.000, stock quedó 36 y total 45.000 | Prohibir cambios de documentos emitidos o implementar correctamente UPDATE/DELETE, incluyendo reversión de stock |
| Alta | RN-01: precio de venta arbitrario | precio_unitario 0,01 frente a catálogo 13.900 | Capturar precio desde vino al crear la venta y proteger el valor histórico |
| Alta | RN-08: diferencia de redondeo | dos renglones netos de 0,05 suman 0,10; cabecera 0,09 | Establecer una única política; total de cabecera debe coincidir con suma de renglones |
| Alta | RN-10: estado procesado sin impacto | UPDATE terminado → procesado aceptado sin procedimiento | Vincular transición e impacto de stock; restringir accesos directos que omiten el proceso |
| Alta | RN-12: mover renglón fuera de documento cerrado | renglón de ingreso procesado movido a uno en confección | Validar cabecera OLD y NEW en UPDATE, tanto para ingreso como transferencia |
| Alta | RN-05: vino sin componentes | SET CONSTRAINTS ALL IMMEDIATE no rechaza vino sin composición | Validar también existencia del corte desde vino; controlar ambos vinos al mover un componente |
| Media | Solo lectura con USAGE sobre secuencias | app_ro tiene permiso para avanzar secuencia | Retirar USAGE a reportes; conceder SELECT solo si hace falta |
| Media | Privilegios futuros de funciones | función nueva ejecutable por app_ro mediante PUBLIC | Revocar EXECUTE de PUBLIC en privilegios por defecto del dueño real |

Otros riesgos observados por lectura del SQL, pendientes de prueba específica:

- RN-11 tiene la misma transición directa a procesado que RN-10 y permite
  insertar inicialmente documentos procesados. No basta con controlar UPDATE.
- RN-12 consulta estados sin bloquear cabeceras: revisar carrera entre edición
  de renglones y cierre/procesamiento del documento.
- La función de totales consulta el descuento actual del cliente, aunque los
  renglones guardan un descuento histórico: recalcular después de cambiar
  categoría puede alterar el resultado histórico.
- Los procedimientos bloquean stock sin orden explícito de vino. Transferencias
  con varios vinos pueden sufrir interbloqueos si toman filas en distinto orden.
- El esquema permite ingresar a una bodega vinos de otra; revisar coherencia
  entre bodega de ingreso y bodega de vino antes de generar datos masivos.
- Faltan controles de catálogo para cepa.tipo y día de cierre; son mejoras de
  dominio recomendadas, distintas de los bloqueos anteriores.

## Qué sí pasó las comprobaciones

- Todas las entidades mínimas están representadas en las 29 tablas del SQL.
- Parcela tiene PK compuesta y FK a finca; localidad concentra encargado_regional.
- Los importes usan NUMERIC. Hay PK, FK y NOT NULL en atributos obligatorios.
- El inventario estático alcanza los mínimos: 5 UNIQUE adicionales, más de 8
  CHECK, más de 3 DEFAULT, 4 funciones, 2 procedimientos, 9 triggers declarados,
  2 vistas normales y 1 materializada. ENUM y DOMAIN están en 002; el trigger de
  corte necesita antes corregir su compilación.
- Transferencia sin stock: se rechazó y conservó stock y estado sin cambios
  parciales. Evidencia: `evidencias_revision/atomicidad_transferencia.log`.
- Venta concurrente de la última botella, aislamiento predeterminado READ
  COMMITTED: una sesión confirmó, la otra falló por CHECK al intentar stock -1;
  quedó stock 0 y una sola venta. Esto evita sobreventa en ese caso, aunque la
  consulta previa no usa FOR UPDATE y el error final es técnico.
  Evidencia: `evidencias_revision/concurrencia_venta.log`.
- La suite original terminó con código 0 después de los dos ajustes temporales.
  Esto no acredita corrección integral, por los defectos descritos debajo.

## Revisión de las pruebas entregadas

**El mensaje “100% de cobertura” no está justificado.**

En RN-05, RN-09, RN-10, RN-11 y RN-12 hay bloques que lanzan su propia excepción
`[FALLO]` si se acepta una operación inválida y después la capturan como si fuera
el rechazo esperado. Por ejemplo, RN-05 captura P0001, que es también el código
de su propia excepción. Además, no fuerza el chequeo diferido antes de afirmar
que se rechazó el corte. Puede informar OK sin haber probado la restricción.

Se debe capturar la excepción únicamente alrededor de la operación probada,
guardar un indicador de rechazo, comprobar código y/o constraint cuando aplique,
y lanzar el fallo de la prueba FUERA de ese bloque. Los triggers diferidos deben
probarse con SET CONSTRAINTS ... IMMEDIATE o en transacciones separadas.

Faltan casos de descuentos incompatibles, jerarquía, actualización/borrado de
ventas, precio histórico, redondeo, transición directa a procesado, traslado de
renglones desde cabecera cerrada, permisos efectivos y concurrencia automatizada.
Los fixtures insertan IDs explícitos sin sincronizar secuencias: las inserciones
posteriores pueden colisionar; usar RETURNING o ajustar secuencias al terminar.
La suite hace TRUNCATE global: debe ejecutarse exclusivamente en una base de prueba.

## Etapa 1: modelo y documentación

### Normalización

El informe no basta para afirmar 3FN completa. Según RN-06 existe la dependencia
`tipo_cliente → descuento`, además de `id_cliente → tipo_cliente`. Como tipo_cliente
no es superclave y descuento no es primo, almacenarlos así en cliente introduce
una dependencia transitiva. Un CHECK de correspondencia arregla integridad, pero
no elimina esa dependencia. Para justificar 3FN conviene derivar el descuento o
separar un catálogo de tipos/descuentos y explicar los valores históricos de venta.

El informe afirma que una tabla única con muchos NULL viola 3FN: esa afirmación
no es correcta por sí sola; la 3FN se analiza por dependencias funcionales.
También atribuye un UNIQUE(codigo_postal,nombre) a localidad que el SQL no tiene.
Debe decidirse la clave natural con cuidado (incluida provincia) y alinear informe
y migraciones. Las afirmaciones de rendimiento sobre 500.000 filas todavía no
cuentan con mediciones del proyecto; deben presentarse como motivación o hipótesis.

### Diferencias entre diagramas y SQL

- En el DER aparece Departamento como entidad; el SQL lo guarda como texto en finca.
- El DER no muestra dia_cierre ni numero_doc en las etiquetas inspeccionadas.
- En el esquema relacional dibujado empleado repite fecha_ingreso y omite salario.
- Cliente omite numero_doc; comprobante omite descuento y total.
- Composición omite porcentaje; los tres renglones omiten cantidades y el de
  comprobante también los importes; stock_sala omite cantidad y transferencia
  omite fecha y estado.
- La tabla vino_maridaje sigue titulada “Table” con “Row 3” y “Row 4”.
- Hay nombres diferentes (codigo_vino/cod_vino, numero_parcela/nro_parcela, etc.).
  No son necesariamente errores conceptuales, pero deben unificarse para la entrega.

No se encontró en los archivos revisados un diccionario completo por columna
(tipo, nulabilidad, restricciones y descripción), un esquema relacional textual
completo, ni exportaciones PDF/imagen de los dos diagramas. El informe de
normalización es externo a la copia Git y lista solo parte de las dependencias.
La imagen de concurrencia existente no sustituye un informe que explique pasos,
aislamiento y resultados con y sin bloqueo; no se evaluó visualmente esa captura.

En 001 los estados todavía son VARCHAR y no se definen ENUM ni DOMAIN; aparecen
recién en 002. Aunque se arregle la conversión, el entregable aislado de etapa 1
no cumple el criterio de estados controlados. Conviene crear los tipos antes de
las tablas y ajustar 002 para no repetir conversiones innecesarias.

## Etapa 2: trazabilidad de reglas

| Regla | Mecanismo actual | Resultado de revisión |
|---|---|---|
| RN-01 | Precio en vino + CHECK + captura en venta | Precio positivo correcto; captura acepta sobreescritura |
| RN-02 | Localidad y FK obligatoria de sala | Diseño base correcto; alinear unicidad documentada |
| RN-03 | FK NOT NULL de empleado | Mecanismo correcto |
| RN-04 | Cepa en parcela + UNIQUE de campaña | Mecanismo correcto |
| RN-05 | Trigger diferido en composición | No compila; tras ajuste no cubre vino sin corte ni OLD al mover |
| RN-06 | Función + dos CHECK independientes | No vincula descuento con tipo |
| RN-07 | Permisos con FK + CHECK de fechas | Estructura correcta; depende de arreglar jerarquía |
| RN-08 | Función y trigger INSERT de venta | Edición manual, redondeo e historia inconsistentes |
| RN-09 | BEFORE INSERT + AFTER INSERT + CHECK | Inserción simple protegida; UPDATE/DELETE no cubiertos |
| RN-10 | ENUM, estados y procedimiento | Procedimiento útil; transición directa omite stock |
| RN-11 | Igual + trigger de fecha | Fecha protegida; misma brecha de transición y concurrencia pendiente |
| RN-12 | Trigger de renglones | Valida NEW pero no OLD al mover renglones |
| RN-13 | Trigger de auditoría de precio | Registra cambios; rol API puede editar/borrar auditoría |
| RN-14 | FK restrictivas a maestros con movimientos | Mecanismo correcto para relaciones existentes |
| RN-15 | CHECK de cantidades, superficies, kilos y graduación | Cobertura base presente; agregar pruebas por dominio |

## Roles y entorno

007 crea solo app_rw y app_ro; no provisiona un propietario separado y Compose
usa postgres como usuario de conexión. Debe documentarse/provisionarse el dueño
de objetos y diferenciarlo del usuario de API.

app_rw recibe escritura sobre TODAS las tablas, incluida auditoría, stocks e
importes calculados. Esto permite omitir los procesos que deberían protegerlos.
La solución debe coordinar permisos con funciones/procedimientos y triggers,
sin retirar permisos que estos necesitan sin proporcionar un acceso seguro.
Las contraseñas de roles están en el SQL; `.env` y `.venv` están versionados y
`.gitgnore` está mal escrito. Se recomienda corregir ignorados y retirar secretos
de los archivos versionados; si fueron usados fuera de pruebas, reemplazarlos.
No se copian sus valores en este informe ni se modificó el historial remoto.

## Orden recomendado para cerrar ambas etapas

1. Corregir creación de tipos y errores de compilación; migraciones con parada
   inmediata ante errores y prueba desde cero en PostgreSQL 16 del contenedor.
2. Resolver descuento y jerarquía; unificar la política de totales e historia.
3. Proteger ventas y estados/procesamiento; corregir OLD/NEW y bloqueos.
4. Completar RN-05 y privilegios mínimos; arreglar la batería y agregar regresiones.
5. Sincronizar diagramas, esquema escrito, diccionario e informe de normalización.
6. Repetir pruebas, documentar concurrencia y cerrar trazabilidad con evidencias.
7. Recién entonces ejecutar la carga masiva definitiva de etapa 3.

Los CSV y el plan de carga ya preparados pueden conservarse; la carga definitiva
queda pendiente. Los logs son evidencia de esta revisión, no de un sistema corregido.
