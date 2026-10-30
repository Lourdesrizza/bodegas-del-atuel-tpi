# Bodegas del Atuel

## Informe de estudio de las etapas 1 2 y 3

Material para el grupo de Bases de Datos de UTN San Rafael. Actualizado al 29 de octubre de 2026.

Este informe explica qué construimos, por qué tomamos cada decisión y cómo comprobamos el resultado. Está pensado para estudiar en grupo y preparar la defensa. Reúne el modelado, las correcciones de integridad y la carga masiva. Los resultados se tomaron del código, la bitácora y los registros de prueba del repositorio; para preparar este documento no se volvieron a ejecutar las cargas.

El resultado es una base con 30 tablas y reglas implementadas en PostgreSQL. Las migraciones, las pruebas de reglas y concurrencia, dos cargas completas y una restauración tienen evidencia en PostgreSQL 16.15 dentro de Docker. La inspección visual final de los diagramas sigue siendo un punto a confirmar: tener los archivos editables no acredita por sí solo su legibilidad ni todas las cardinalidades dibujadas.

## 1 Cómo estudiar este informe

Primero lean el recorrido de la empresa y la explicación del modelo. Después estudien las reglas con sus ejemplos. Finalmente revisen cómo generamos los datos y qué significan las mediciones. No hace falta memorizar cada línea de código: sí poder explicar qué problema resuelve y encontrar el archivo correspondiente.

Cada integrante debería poder responder: ¿qué tablas participan?, ¿qué regla las protege?, ¿qué pasa si falla una operación? y ¿qué prueba demuestra el comportamiento? La última sección incluye preguntas con respuestas breves para practicar.

## 2 Qué sistema estamos construyendo

Bodegas del Atuel integra producción, distribución y venta de vinos. Una finca se divide en parcelas; cada parcela tiene una cepa. La cosecha de una parcela en una campaña genera un lote de uva que recibe análisis de calidad y se entrega a una bodega. La bodega elabora vinos cuyo corte indica las cepas y sus porcentajes.

Las botellas ingresan al depósito central mediante ingresos. Desde allí se transfieren a salas de venta. Las salas venden a clientes y emiten comprobantes con sus renglones. Cada venta debe descontar stock, conservar el precio histórico y aplicar el descuento correspondiente al tipo de cliente.

Recorrido resumido de las botellas: bodega → ingreso → depósito central → transferencia → sala de venta → comprobante. El lote de uva aporta el contexto agrícola; el esquema actual no representa una transformación industrial detallada de cada lote en cada botella.

## 3 Qué aporta cada etapa

| Etapa | Pregunta que responde | Resultado principal |
|---|---|---|
| 1 Modelado | Qué datos existen y cómo se relacionan | Diagramas, relaciones, diccionario y esquema SQL |
| 2 Integridad | Qué operaciones son válidas y quién puede realizarlas | Restricciones, funciones, procedimientos, triggers, vistas y roles |
| 3 Carga masiva | Cómo obtener muchos datos coherentes y repetibles | Catálogos, generador, controles, mediciones y respaldo probado |

La etapa 4 estudiará índices y planes de ejecución. La comparación INSERT frente a COPY de la etapa 3 mide una forma de cargar datos; no reemplaza el análisis de consultas que se hará en la etapa 4.

## 4 Etapa 1 El modelo de datos

### 4.1 Entidades y relaciones

Una entidad representa algo que queremos registrar, como una bodega o un cliente. La relación indica cómo se vincula con otras entidades. Por ejemplo, una sala está en una localidad y una localidad puede tener varias salas: es una relación de uno a muchos.

La clave primaria o PK identifica una fila sin repetirla. La clave foránea o FK exige que exista la fila relacionada. Así, sala_venta.id_localidad apunta a localidad.id_localidad. No se puede crear una sala que haga referencia a una localidad inexistente.

En una relación muchos a muchos se agrega una tabla intermedia. Un vino admite varias cepas y una cepa puede integrar muchos vinos: composicion resuelve esa relación y agrega porcentaje. vino_maridaje y transportista_localidad siguen el mismo principio, sin porcentaje.

### 4.2 Las 30 tablas por área

| Área | Tablas | Qué representan |
|---|---|---|
| Localización y personal | localidad, sala_venta, empleado | Lugares, puntos de venta y personas que trabajan allí |
| Producción agrícola | finca, cepa, parcela, lote_uva, analisis_calidad | Terreno, variedades, cosechas y mediciones |
| Vinos | bodega, vino, composicion, maridaje, vino_maridaje | Elaboradores, catálogo, cortes y recomendaciones |
| Clientes | tipo_cliente, cliente, socio, distribuidor, exportador, permiso_exportacion | Clasificación comercial y atributos de cada categoría |
| Logística | transportista, transportista_localidad, stock_deposito, stock_sala | Transporte, cobertura y existencias |
| Documentos y auditoría | ingreso, renglon_ingreso, transferencia, renglon_transferencia, comprobante, renglon_comprobante, auditoria_precio | Movimientos, ventas y cambios de precios |

El modelo inicial tenía 29 tablas. La tabla adicional tipo_cliente apareció al corregir la dependencia entre categoría y descuento.

### 4.3 Parcela como entidad débil

El número de parcela sólo identifica una parcela dentro de su finca. Puede existir parcela 1 en dos fincas distintas. Por eso la PK es (id_finca, nro_parcela). Un lote referencia ese par mediante una FK compuesta; no basta con guardar el número de parcela.

La misma idea aparece en los renglones. La PK de renglon_comprobante es (nro_comprobante, cod_vino): el mismo vino puede venderse en muchos comprobantes, pero no se repite como dos renglones independientes dentro del mismo comprobante. Su cantidad se expresa en el único renglón correspondiente.

### 4.4 La jerarquía de clientes

cliente guarda datos comunes: identidad, documento, domicilio, localidad, fecha de alta y tipo. socio, distribuidor y exportador comparten su id_cliente con la tabla base. distribuidor agrega zona y habilitación; exportador agrega país y se relaciona con sus permisos.

La estrategia elegida es supertipo más subtipos. Evita repetir los datos comunes y permite que comprobante tenga una sola FK a cliente. Los controles diferidos exigen exactamente un subtipo, coherente con el tipo declarado, al cerrar la transacción. Esto permite insertar primero cliente y después su subtipo dentro de la misma transacción.

### 4.5 Dependencias funcionales y normalización

Una dependencia X → Y significa que, para un mismo valor de X, hay un único valor permitido de Y. Ejemplos del proyecto: id_localidad → encargado_regional; cod_vino → nombre, precio y bodega; (cod_vino, id_cepa) → porcentaje; (id_finca, nro_parcela) → cepa y superficie.

Primera forma normal: una columna guarda un valor del dominio y no una lista de valores repetidos. Las cepas de un vino se guardan como filas en composicion, no como una lista dentro de vino.

Segunda forma normal: los atributos no clave dependen de toda la clave candidata compuesta, no de una parte. En composicion, el porcentaje corresponde a una cepa dentro de un vino: no depende sólo del vino ni sólo de la cepa.

Tercera forma normal: formalmente, en cada dependencia no trivial X → A, X es superclave o A es atributo primo. En términos prácticos, buscamos evitar que un dato no clave determine otro dato no clave y produzca redundancia innecesaria.

El caso corregido fue cliente: id_cliente → tipo_cliente y tipo_cliente → descuento. Guardar el descuento de catálogo en cada cliente repetía la correspondencia 10, 20 o 30 %. Se creó tipo_cliente(tipo_cliente, descuento) y cliente conserva una FK. La función de descuento consulta ese catálogo.

Otro caso importante es encargado_regional: pertenece a localidad. Si se copiara en cada sala, cambiar el encargado exigiría modificar varias filas. Tener una sola fila de localidad evita encargados distintos para salas del mismo lugar.

Los datos históricos y los totales requieren una explicación adicional. El precio y el descuento de un renglón son hechos de esa venta, aunque el catálogo cambie después. Los totales de cabecera se almacenan como una materialización controlada del detalle. Por eso el informe revisado no presenta toda esa redundancia operacional como una demostración de normalización estricta.

### 4.6 Tipos y claves elegidos

Se usan identificadores SERIAL para muchas entidades: separan la identidad interna de nombres o direcciones que pueden cambiar. Las claves naturales CUIT se conservan en bodega y empleado. Las PK compuestas expresan dependencias propias del negocio, como parcela y los renglones.

El dinero se guarda con NUMERIC, que permite decimales exactos según la precisión declarada. FLOAT y REAL pueden introducir aproximaciones binarias. Las fechas comerciales usan DATE y la auditoría usa TIMESTAMP. estado_documento es un ENUM con en_confeccion, terminado y procesado. cuit_dom comprueba un formato de once dígitos; no valida por sí solo existencia legal ni dígito verificador de un CUIT.

Los tipos se crean en 001 antes de las tablas que los utilizan. El diccionario revisado detalla por columna tipo, nulabilidad y restricciones; el esquema relacional revisado permite seguir las PK y FK completas.

## 5 Qué encontramos y corregimos al revisar

La revisión inicial no se limitó a contar tablas y funciones. Se intentó crear la base y se probaron operaciones incorrectas para observar si PostgreSQL las rechazaba.

| Problema inicial | Corrección implementada |
|---|---|
| Conversión de estados usaba un nombre de tipo como columna | Se crearon los tipos antes de usarlos y se ajustó 002 |
| Mensaje RAISE tenía más placeholders que argumentos | Se corrigió el porcentaje literal y la función pudo compilar |
| Un socio podía tener descuento 30 % | Se separó el catálogo de tipos y descuentos |
| Un cliente podía figurar en subtipos incompatibles | Se agregó validación diferida de pertenencia única |
| La venta aceptaba un precio arbitrario | El trigger captura el precio vigente del catálogo |
| Cambiar una venta no ajustaba stock ni totales | Se bloqueó la edición y el borrado de ventas emitidas |
| Cabecera y renglones podían diferir por redondeo | Se suman los netos ya redondeados de cada renglón |
| Se podía omitir el proceso de stock cambiando estados | Se acotaron permisos y se centralizaron transiciones en procedimientos |
| Mover un renglón evitaba revisar el documento anterior | Se comprueban OLD y NEW y se bloquean ambas cabeceras |
| Se aceptaban vinos sin composición | Se agregó control diferido desde vino y composición |
| Pruebas capturaban su propio mensaje de fallo | Se separó la captura del rechazo de la afirmación de la prueba |
| Roles tenían permisos amplios y claves en SQL | Se separaron propietario, escritura y lectura, sin contraseñas en migraciones |

También se retiraron los borrados preventivos de tablas de las migraciones de creación. Se corrigió el nombre de .gitignore y se quitaron .env y .venv del índice de Git conservando los archivos locales. Esto evita seguir versionándolos, pero no elimina datos del historial anterior.

## 6 Etapa 2 Las reglas dentro de PostgreSQL

### 6.1 Qué herramienta usamos para cada caso

| Herramienta | Para qué sirve | Ejemplo del proyecto |
|---|---|---|
| PRIMARY KEY | Identificar una fila | Clave de parcela |
| FOREIGN KEY | Exigir una referencia existente | Sala en una localidad |
| NOT NULL | Exigir un dato obligatorio | Empleado con sala |
| UNIQUE | Evitar duplicados adicionales a la PK | Una cosecha por parcela y campaña |
| CHECK | Validar valores de una fila | Precio positivo y vencimiento posterior a emisión |
| DEFAULT | Dar un valor si no se informa | Estado inicial del documento |
| Función | Obtener o calcular un resultado reutilizable | Total de comprobante |
| Procedimiento | Ejecutar una operación de varios pasos | Transferir stock |
| Trigger | Reaccionar automáticamente a una modificación | Capturar precio o auditarlo |
| Constraint trigger diferido | Validar un conjunto al cierre de transacción | Corte al 100 % y subtipo completo |

Una FK no valida una suma de porcentajes; un CHECK de una fila no resuelve una operación concurrente sobre varias filas. Elegimos el mecanismo según el alcance de la regla. Las validaciones de interfaz no sustituyen a estas restricciones del motor.

### 6.2 Las quince reglas del trabajo

| Regla | Qué significa | Protección y comprobación |
|---|---|---|
| RN 01 | Un precio de catálogo por vino en toda la red y mayor que cero | Precio en vino, CHECK y captura al vender |
| RN 02 | Sala en una localidad con un encargado regional | FK obligatoria y encargado guardado en localidad |
| RN 03 | Empleado en una sola sala | FK NOT NULL |
| RN 04 | Una cepa por parcela y una cosecha por campaña | FK de cepa y UNIQUE de finca, parcela y campaña |
| RN 05 | Corte completo al 100 % | Triggers diferidos en vino y composición |
| RN 06 | Socio 10 %, distribuidor 20 %, exportador 30 % | Catálogo, función y control de subtipos |
| RN 07 | Permisos del exportador con fechas válidas | FK y CHECK vencimiento mayor que emisión |
| RN 08 | Total calculado desde los renglones | Función de sumas históricas, trigger e inmutabilidad |
| RN 09 | Venta limitada por stock y stock no negativo | UPDATE condicional atómico y CHECK |
| RN 10 | Ingreso procesado impacta depósito una sola vez | ENUM, procedimientos, estados y permisos |
| RN 11 | Transferencia atómica y fecha protegida | Procedimientos, bloqueos, estados y trigger de fecha |
| RN 12 | Documento cerrado no admite cambios de renglones | Control de OLD y NEW con bloqueo de cabeceras |
| RN 13 | Cambio de precio auditado | AFTER UPDATE y tabla de auditoría protegida para API |
| RN 14 | No borrar maestros con movimientos | FK restrictivas |
| RN 15 | Valores positivos y graduación de 5 a 20 | CHECK por dominio de datos |

### 6.3 Las funciones que hay que conocer

fn_descuento_cliente obtiene el porcentaje desde tipo_cliente a través de cliente. fn_stock_sala devuelve existencias de un vino en una sala, o cero si no hay registro. fn_antiguedad_anios calcula años completos a partir de una fecha. fn_total_comprobante devuelve bruto, descuento monetario y neto a partir de los valores históricos de los renglones.

Las funciones de consulta están declaradas STABLE. Eso expresa que no modifican datos y mantienen el comportamiento permitido por PostgreSQL para ese nivel de volatilidad; no significa que devuelvan el mismo resultado para siempre. Una consulta de stock puede cambiar entre operaciones y la antigüedad depende de la fecha.

### 6.4 Ingresos y transferencias

El ciclo comercial es en_confeccion → terminado → procesado. Mientras se confecciona un documento se editan sus renglones. Al terminarlo se cierra esa edición. Al procesarlo se mueve el stock. No debe procesarse dos veces porque se duplicaría el movimiento.

sp_terminar_ingreso y sp_terminar_transferencia realizan el cierre. sp_procesar_ingreso bloquea su cabecera, exige terminado y renglones, suma depósito y pasa a procesado. sp_procesar_transferencia bloquea cabecera y existencias, verifica disponibilidad de todos los vinos, resta depósito, suma sala y pasa a procesado.

Los bloqueos de vinos siguen un orden para reducir interbloqueos. La operación se ejecuta dentro de una transacción: si un vino no alcanza, no queda una transferencia a medias. El ingreso también comprueba que sus vinos correspondan a la bodega de origen.

### 6.5 Cómo se registra una venta normal

Al insertar un renglón, el BEFORE INSERT bloquea la cabecera, obtiene precio vigente y descuento y calcula el neto. Después intenta descontar stock con una actualización que sólo se aplica si hay cantidad suficiente. Si no consigue actualizar una fila, rechaza la venta.

El AFTER INSERT recalcula la cabecera con fn_total_comprobante. El bruto es la suma de cantidad por precio; el total es la suma de netos redondeados; el descuento monetario es bruto menos total. La cabecera no puede editarse libremente, aunque el trigger autorizado sí puede actualizar sus importes.

Ejemplo didáctico: un socio compra cuatro botellas de $12.500. Bruto = $50.000; descuento = $5.000; total = $45.000. Si había diez botellas en la sala, quedan seis. Si la inserción falla, la transacción revierte el descuento de stock.

El redondeo se fija por renglón. Dos líneas de $0,05 con 10 % de descuento producen $0,05 netos cada una al redondear a dos decimales: el comprobante debe sumar $0,10. Recalcular un 10 % global sobre $0,10 daría $0,09 y contradice los renglones ya redondeados. De ahí la política elegida.

Se rechazan UPDATE y DELETE de renglones emitidos. La aplicación debe crear cabecera y todos sus renglones en la misma transacción. El mecanismo actual no tiene un estado explícito de emisión que cierre futuros INSERT de renglones: la política de creación conjunta y los permisos deben respetarse. No se debe confundir inmutabilidad de UPDATE/DELETE con un cierre formal de toda posibilidad de agregar líneas.

### 6.6 Concurrencia y transacciones

COMMIT confirma una transacción y ROLLBACK la revierte. FOR UPDATE bloquea filas para coordinar operaciones simultáneas. En stock de venta, el UPDATE condicional verifica y descuenta en la misma operación; evita separar la lectura de disponibilidad de una escritura posterior sin protección.

La prueba de la última botella usa dos sesiones. Una venta se confirma; la otra termina rechazada por stock insuficiente. El stock final es cero y sólo existe una venta exitosa. Los códigos [0,3] del registro representan una ejecución correcta y un error esperado de la otra sesión; no significan dos ventas confirmadas.

Las pruebas se hicieron con READ COMMITTED. Este resultado demuestra el caso ensayado, no una prueba exhaustiva de todas las combinaciones posibles de concurrencia. Los bloqueos y permisos forman parte de la solución y deben mantenerse.

### 6.7 Vistas y roles

v_stock_total_vino reúne existencias de depósito y salas. v_documentos_pendientes muestra ingresos y transferencias todavía no procesados. mv_ventas_mensuales_sala guarda un resumen mensual por sala: es materializada, por lo que necesita REFRESH cuando deben actualizarse sus resultados. Su índice único permite identificar cada sala y período.

app_owner es el propietario sin acceso de inicio de sesión directo. app_rw es el rol de aplicación: lee, mantiene los maestros permitidos, inserta documentos y ejecuta procedimientos; no escribe directamente stock ni auditoría. app_ro consulta reportes y las funciones autorizadas; no recibe USAGE de secuencias para avanzar identificadores.

Algunos procedimientos y funciones de trigger usan SECURITY DEFINER con search_path fijado: ejecutan las acciones internas con privilegios del dueño. Esto permite ofrecer una operación controlada sin conceder a la API escritura general sobre las tablas sensibles. El propietario y los administradores conservan facultades de mantenimiento: los permisos no protegen frente a un superusuario que deliberadamente eluda los controles.

### 6.8 Cómo se corrigieron y verificaron las pruebas

Antes, algunos casos intentaban una operación inválida, lanzaban un error propio si se aceptaba y capturaban ese mismo error como un supuesto éxito. Se corrigieron usando un indicador de rechazo y una afirmación fuera del bloque que captura la excepción. Los triggers diferidos se fuerzan con SET CONSTRAINTS ALL IMMEDIATE cuando corresponde.

La suite revisada incluye reglas positivas y negativas, redondeo, precio histórico, subtipos, movimientos de OLD y NEW, permisos y transferencia fallida sin cambios parciales. Los scripts trabajan con bases exclusivas; no necesitan vaciar una base de uso con TRUNCATE global. Las migraciones se ejecutan con ON_ERROR_STOP para detenerse ante el primer error.

## 7 Etapa 3 La carga masiva

### 7.1 Qué había que demostrar

La consigna exige filas en todas las tablas, más de 10.000 en al menos tres y más de 100.000 en una. También requiere catálogos reales, semilla fija, datos coherentes, medición de carga, controles y respaldo. Se eligieron 20.000 clientes, 150.000 comprobantes y 500.000 renglones de venta.

No se generaron datos sólo para alcanzar números: la demanda de las ventas define cuánto debe ingresar y transferirse. Así podemos demostrar que los saldos finales coinciden con los movimientos, además de que no son negativos.

### 7.2 Herramientas y datos de referencia

El generador usa Python, psycopg 3.2.10, Faker 37.11.0 y random.Random. Las versiones directas y transitivas están fijadas en requirements.txt. Faker genera personas y empresas ficticias; random controla elecciones reproducibles; psycopg conecta con PostgreSQL y ejecuta SQL directo.

La semilla es 20261029 y la fecha de referencia 2026-10-28. Fijar ambas evita que una ejecución cambie sólo por correr en otro día. También deben conservarse las versiones de las dependencias y el entorno relevante.

cepas.csv, maridajes.csv, departamentos.csv y tipos_vino.csv proceden del anexo B. localidades.csv agrega 20 localidades de Mendoza confirmadas con Georef y códigos postales contrastados con una tabla oficial de RENAPER. El CP de localidad de cuatro cifras no se presenta como el CPA actual de ocho caracteres de una dirección exacta. Los responsables y domicilios generados son ficticios.

### 7.3 Orden real de la carga

1. Leer catálogos y crear localidades, salas, empleados, fincas, bodegas y transportistas.
2. Crear parcelas, cosechas, análisis, vinos, composición y maridajes.
3. Crear clientes con su tipo, subtipo y permisos.
4. Planificar comprobantes y renglones en memoria y sumar la demanda por sala y vino.
5. Crear y procesar ingresos suficientes para abastecer depósito.
6. Crear y procesar transferencias suficientes para abastecer salas.
7. Importar las ventas históricas y descontar su demanda agregada.
8. Sincronizar secuencias, rehabilitar triggers, validar restricciones y controles, refrescar la vista y confirmar.

Las FK obligan a cargar primero las filas referenciadas. El orden comercial también importa: vender antes de abastecer las salas produciría falta de stock. Las secuencias se sincronizan porque se cargan IDs explícitos y luego deben poder generarse identificadores nuevos sin colisiones.

### 7.4 Fechas y composición generadas

Las campañas son 2020 a 2024, con cosechas entre febrero y abril; los análisis son posteriores a su cosecha. Los ingresos tienen fecha de enero de 2025, las transferencias de marzo de 2025 y las ventas van de abril de 2025 al 28 de octubre de 2026. Esta separación hace simple verificar el orden temporal del conjunto de prueba.

La carga completa tiene 600 vinos y 600 componentes: en esta versión se genera una cepa al 100 % para cada vino. La estructura permite cortes de varias cepas, y las pruebas de reglas incluyen composición y cambios; la carga masiva no pretende representar todos los estilos enológicos posibles.

### 7.5 Por qué usamos COPY

Una inserción individual envía una operación por fila. COPY transmite filas como un flujo de carga y reduce el costo de muchas operaciones separadas. El generador conserva SQL directo y no usa ORM.

Para medirlo se cargaron las mismas 1.000 filas en una tabla temporal sin índices ni triggers, vaciándola entre métodos. Se midió tiempo de reloj con time.perf_counter. Esto permite comparar los dos métodos en esa muestra; no garantiza la misma proporción de mejora en cada tabla o máquina.

### 7.6 Cómo se manejaron los triggers históricos

En operación normal el motor calcula importes y stock. La carga histórica es una importación administrativa y se realiza en una base exclusiva con un rol capaz de mantener tablas. El rol API no puede suspender triggers.

Se suspende trg_fecha_transferencia durante la inserción de cabeceras para conservar marzo de 2025, porque normalmente fuerza la fecha actual. Durante COPY de renglones de venta se suspenden trg_valida_stock_renglon y trg_descuenta_stock_actualiza_totales para evitar cientos de miles de verificaciones y recálculos individuales.

En ese tramo Python calcula precio, descuento y netos en centavos con Decimal para los campos monetarios. Las cabeceras se insertan con sus importes y después se resta la demanda agregada del stock. Los tres triggers vuelven a habilitarse antes de forzar restricciones diferidas y ejecutar los controles. Las FK y CHECK siguen activas; no se usa session_replication_role.

Todo ocurre en una transacción. Si un control falla, se hace ROLLBACK y se revierten también los ALTER TABLE de esa transacción. El uso de secuencias tiene particularidades propias de PostgreSQL y no debe confundirse con una garantía general de rollback de cada número consumido. El generador exige una base nueva y evita reutilizar automáticamente una corrida fallida o poblada.

La auditoría se genera por el cambio normal de precio del vino 1 antes de cargar ventas. Se comprobó que los tres triggers estaban habilitados después de confirmar. La importación no sustituye el flujo normal de venta de la futura API.

### 7.7 Los 20 controles y qué comprueban

Cada control devuelve cantidad de incumplimientos: cero significa que no encontró problemas dentro de su alcance. Los mínimos de volumen se exigen en modo completa; una prueba pequeña no tiene que producir medio millón de filas.

| Grupo | Controles del validador |
|---|---|
| Tablas y volumen | tabla_vacia, tablas_no_en_catalogo, volumen_clientes, volumen_comprobantes, volumen_renglones_venta, volumen_tres_tablas_10k |
| Referencias | fk_no_validadas, huerfanos_venta, huerfanos_produccion, huerfanos_movimientos |
| Composición y clientes | cortes, subtipos, descuentos_catalogo, descuentos_venta |
| Fechas | fechas_analisis, fechas_movimientos |
| Importes y stock | totales_venta, stock_deposito, stock_sala |
| Estados | documentos_no_procesados |

Las ecuaciones de la carga parten de stock inicial cero: depósito = ingresos procesados menos transferencias procesadas; sala = transferencias procesadas recibidas menos ventas. Ejemplo: entran 100 botellas, se transfieren 30 y se venden 4. Quedan 70 en depósito y 26 en la sala.

El validador está diseñado para este conjunto generado. Por ejemplo, exige todos los movimientos procesados y compara el descuento de venta con el tipo actual del cliente, ya que en la carga no hay cambios posteriores de categoría. No debe aplicarse sin adaptación a una base real con documentos pendientes, saldos iniciales o cambios históricos de categoría.

También se hizo una prueba negativa: se alteró el stock de una sala en una unidad dentro de una transacción. El control detectó un incumplimiento y luego se revirtió. Eso aporta evidencia de que el validador puede detectar al menos ese error, además de aprobar datos correctos.

## 8 Resultados de la carga completa

### 8.1 Conteos por tabla

| Tabla | Filas | Tabla | Filas |
|---|---|---|---|
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

Las 30 tablas tienen filas. Al menos tres superan las 10.000 y dos superan las 100.000. Además de las tres elegidas como objetivo, socio tiene 12.000 filas: por eso en los conteos hay cuatro tablas por encima de 10.000, aunque alcanza con tres. Los volúmenes sugeridos para tablas auxiliares son recomendaciones, distintos de los mínimos obligatorios.

### 8.2 Mediciones definitivas en PostgreSQL 16

| Medición en segundos | Corrida A | Corrida B |
|---|---|---|
| Muestra de 1.000 INSERT individuales | 1,274 | 1,078 |
| Las mismas 1.000 filas con COPY | 0,006 | 0,006 |
| Fase de ventas | 49,699 | 48,991 |
| Generación carga controles y refresco | 74,730 | 72,863 |
| Ejecución completa con huella y COMMIT | 76,311 | 74,501 |

Son tiempos de ese equipo y entorno, no una promesa para otras computadoras. La suma facturada en comprobantes y en la vista materializada coincidió: $1.146.038.536,10.

### 8.3 Reproducibilidad y huella

Se cargaron dos bases nuevas con el mismo código, semilla y entorno. La huella SHA-256 lee las 30 tablas ordenadas por sus PK. Se excluyen únicamente auditoria_precio.fecha_hora y auditoria_precio.usuario porque dependen del momento y cuenta de ejecución; el ID, vino y precios de la auditoría sí participan.

Las dos cargas completas PG16 obtuvieron la misma huella: cc7eda8516018adee1c5d10726b8b6673bf662acd71d44c0246f284d20be8a34. La coincidencia demuestra igualdad bajo ese procedimiento de comparación; no significa que los campos excluidos sean idénticos.

Las huellas PG18 anteriores son diferentes. Por eso la evidencia de reproducibilidad se refiere a dos bases nuevas del mismo entorno PG16, sin afirmar igualdad entre versiones. No se investigó aquí la causa de esa diferencia entre entornos.

### 8.4 Respaldo y restauración

pg_dump del contenedor PostgreSQL 16 generó un volcado SQL comprimido de 5.907.614 bytes. Se usaron --no-owner y --no-privileges: el respaldo transporta estructura y datos sin fijar propietarios y permisos del ambiente original. Después de restaurar en otra base nueva se reaplica 007 para asignar el dueño y los permisos del proyecto.

La base restaurada obtuvo los 20 controles en cero, 500.000 renglones de venta y la misma huella que el origen. El respaldo probado se llama dump_completo_pg16.sql.gz y está ignorado por Git. No basta con crear un archivo de respaldo: restaurarlo y comprobar su contenido es lo que valida su utilidad.

### 8.5 Cómo se llegó al entorno de entrega

Al principio Docker no respondía y las correcciones se probaron en PostgreSQL 18.1 local, en bases de laboratorio. Esas ejecuciones quedaron como antecedentes. Cuando Docker estuvo disponible se creó un Compose aislado con imagen postgres:16-alpine, contenedor atuel_pg16_carga_test y volumen nuevo, conservando los existentes.

Las consultas al servidor confirmaron PostgreSQL 16.15. Que el cliente psql de Windows sea versión 18 no convierte al servidor en PG18. El pg_dump definitivo se ejecutó dentro del contenedor PG16. En ese entorno se repitieron migraciones, suite de reglas, concurrencia, carga pequeña, dos completas y restauración.

## 9 Archivos para encontrar cada tema

| Archivo o carpeta del repositorio | Qué estudiar allí |
|---|---|
| db/migrations/001_esquema.sql | Tipos, tablas, PK y FK |
| db/migrations/002_constraints.sql | UNIQUE, CHECK, valores por defecto y acciones referenciales |
| db/migrations/003_funciones.sql | Las cuatro funciones de consulta y cálculo |
| db/migrations/004_procedimientos.sql | Terminar y procesar ingresos y transferencias |
| db/migrations/005_triggers.sql | Captura histórica, stock, estados, cortes, subtipos e inmutabilidad |
| db/migrations/006_vistas.sql | Existencias, pendientes y ventas mensuales |
| db/migrations/007_roles.sql | Propietario y permisos de API y lectura |
| tests/db_tests.sql y etapas_1_2_regresion.sql | Casos positivos y negativos de reglas |
| tests/concurrencia_ultima_botella.py | Dos sesiones compitiendo por la última botella |
| db/seed/cargar_datos.py y validar_carga.sql | Generación, importación y 20 controles |
| db/seed/README.md | Comandos para preparar, cargar, validar, respaldar y restaurar |
| docs/diccionario_datos_revisado.md | Detalle completo de columnas |
| docs/esquema_relacional_revisado.md | Relaciones completas y claves |
| docs/DER_revisado.drawio y diagramarelacional_revisado.drawio | Fuentes editables del modelo |
| docs/reporte_etapa_3.md y bitacora_etapa_3.md | Mediciones, decisiones, errores y correcciones |
| docs/evidencias_cierre y docs/evidencias_carga | Logs que respaldan los resultados |

Los SQL contienen algunas funciones definidas más de una vez mediante CREATE OR REPLACE. Para estudiar el comportamiento final hay que seguir la última definición y los permisos de 007; no alcanza con leer sólo el primer bloque del archivo. Esto es una característica actual del código, no una recomendación de estilo para agregar más duplicaciones.

## 10 Qué queda confirmado y qué debe revisarse

Está documentada la ejecución desde cero de 001 a 007 y de las pruebas en PG16.15. También se registran la prueba concurrente, volúmenes completos, veinte controles sin incumplimientos, reproducibilidad en PG16 y restauración del respaldo. La carga se hizo en bases exclusivas de laboratorio; no es un despliegue productivo.

La inspección visual final de los diagramas y sus cardinalidades debe confirmarse con el grupo. Algunas notas antiguas de normalización y trazabilidad todavía dicen pendiente PG16 o Probado PG18; la bitácora y el reporte posteriores acreditan que esa prueba de entorno se completó. Este informe usa ese estado posterior sin modificar las fuentes históricas.

Se mantiene RN 06 con 30 % a exportadores. La consigna de consultas posterior incluye una actualización al 35 % para ciertos exportadores; esa diferencia debe acordarse y modelarse al llegar a esa consulta, sin cambiar silenciosamente las reglas actuales.

No se hicieron push ni merge durante el trabajo registrado. Un commit local y la revisión grupal de los archivos son pasos de organización posteriores. La etapa 4 debe agregar índices y evidencia de EXPLAIN ANALYZE y BUFFERS; esos resultados todavía no se presentan como realizados.

## 11 Preguntas para practicar la defensa

### Por qué el encargado regional está en localidad

Porque depende de la localidad y todas sus salas deben compartirlo. Guardarlo en cada sala repetiría el dato y permitiría contradicciones al actualizar.

### Por qué parcela tiene una clave compuesta

Porque nro_parcela se repite entre fincas. La identidad completa es finca más número; las referencias al lote deben respetar ambas columnas.

### Por qué agregamos tipo_cliente

Para guardar una sola vez la dependencia tipo → descuento y quitar esa redundancia de cada cliente. El porcentaje histórico de una venta se conserva aparte en su renglón.

### Por qué no calculamos ventas pasadas con el precio actual

Porque un cambio del catálogo alteraría importes de operaciones ya realizadas. Se guarda el precio al vender y se calcula desde los datos históricos.

### Cuándo usamos un trigger diferido

Cuando una regla debe cumplirse al final de una transacción que construye varias filas. El vino puede insertarse antes de sus componentes y el cliente antes de su subtipo, siempre que al cerrar el conjunto sea válido.

### Por qué no basta con consultar stock antes de vender

Porque otra sesión podría vender entre la consulta y la actualización. La actualización condicional verifica disponibilidad y descuenta de forma atómica.

### Qué pasa si falta stock en el segundo vino de una transferencia

La operación falla y la transacción no debe conservar movimientos parciales del primer vino. La prueba comprueba saldos y estado antes y después del rechazo.

### Qué diferencia hay entre función y procedimiento

La función devuelve un resultado reutilizable, como el total de un comprobante. El procedimiento organiza una operación, como procesar una transferencia, y se invoca con CALL. La transacción protege el conjunto de pasos.

### Por qué la API no recibe escritura directa sobre stock

Porque podría fabricar saldos sin ingresos, transferencias ni ventas. Debe ejecutar las operaciones autorizadas y dejar el impacto a los mecanismos de la base.

### Por qué suspendimos triggers durante la carga histórica

Para conservar fechas pasadas y evitar recálculos por cada una de 500.000 líneas. Fue una operación administrativa controlada, con tres triggers identificados, una transacción, rehabilitación y validación antes de confirmar.

### Cómo sabemos que los datos son coherentes

Las restricciones siguen activas y veinte consultas contrastan volúmenes, referencias, cortes, tipos, fechas, importes, estados y saldos. Además, se introdujo un error de stock controlado para comprobar que el validador lo detectara.

### Cómo sabemos que la carga es reproducible

Dos bases nuevas PG16 con las mismas condiciones dieron la misma huella de datos, excluyendo sólo hora y usuario de auditoría. La restauración también reprodujo esa huella.

### COPY hizo siempre doscientas veces más rápida la base

No podemos afirmar eso. La mejora medida corresponde a 1.000 filas en una tabla temporal concreta. Los tiempos completos incluyen generación, reglas, controles y huella y deben explicarse por separado.

### Un log con veinte ceros demuestra que no hay ningún error posible

No. Demuestra que los controles definidos no encontraron incumplimientos en esa ejecución. Hay que conocer sus supuestos y sumar pruebas si aparecen reglas o casos nuevos.

## 12 Guion breve para explicar el proyecto

Modelamos la empresa con tablas relacionadas por claves. Evitamos repetir datos como el encargado regional y el descuento de catálogo. Después colocamos las reglas dentro de PostgreSQL para que la futura API no tenga que calcular stock ni importes por su cuenta. Las ventas conservan sus valores históricos y las transferencias se ejecutan completas o se revierten.

Para probar la base con volumen realista hicimos un generador repetible con catálogos reales y operaciones ficticias. Planificamos la demanda, abastecimos depósito y salas, importamos el historial y verificamos sus saldos. En PostgreSQL 16.15 cargamos 20.000 clientes, 150.000 comprobantes y 500.000 renglones, repetimos el proceso y restauramos un respaldo con los mismos resultados de validación.

## 13 Fuentes y evidencias del informe

La fuente de requisitos es TPI_Bodegas_del_Atuel.pdf de la carpeta superior: escenario y reglas en páginas 4 a 8, modelado e integridad en páginas 10 a 13, carga en páginas 13 y 14 y catálogos en página 29. El informe de normalización original se conserva como antecedente; las correcciones están en docs/normalizacion_revisada.md y el código actual.

Se contrastaron las migraciones 001 a 007, el diccionario y esquema revisados, la trazabilidad, cargar_datos.py, validar_carga.sql, el README de carga, reporte_etapa_3.md y bitacora_etapa_3.md. La fecha de este informe identifica el estado documental revisado, no una nueva ejecución de las bases.

Evidencias PG16 principales: docs/evidencias_cierre/atuel_pg16_rules_20261029_test.log; docs/evidencias_cierre/atuel_pg16_concurrency_20261029_test.log; docs/evidencias_carga/full_a_pg16_20261029.log; docs/evidencias_carga/full_b_pg16_20261029.log; docs/evidencias_carga/resumen_pg16_20261029.log; docs/evidencias_carga/restauracion_pg16_20261029.log.

Las fuentes de catálogo y su método de verificación están conservados en db/seed/README.md y docs/evidencias_carga/catalogos.log. Para repetir operaciones usen ese README con credenciales propias y bases nuevas de prueba; este material de estudio no reemplaza las instrucciones operativas.
