# Informe de normalización revisado — etapas 1 y 2

Los PDF originales de la carpeta superior se conservan sin cambios. Este texto reemplaza las afirmaciones de implementación que el informe inicial daba por aprobadas sin una prueba completa.

## Dependencias y 3FN

En `cliente`, `id_cliente → tipo_cliente` y `tipo_cliente → descuento`. Guardar ambos atributos en esa relación produce una dependencia transitiva. El esquema revisado almacena la correspondencia en `tipo_cliente(tipo_cliente PK, descuento)` y `cliente` conserva sólo la clave foránea. `fn_descuento_cliente` consulta el catálogo. Los porcentajes aplicados a ventas se copian en `renglon_comprobante` como hechos históricos de cada operación; dependen de la clave compuesta del renglón, no del tipo actual del cliente. El catálogo fija socio 10 %, distribuidor 20 % y exportador 30 % mediante CHECK.

La especialización usa un supertipo y tres subtipos. Un constraint trigger diferido comprueba al final de la transacción que exista exactamente una fila de subtipo y que corresponda a `cliente.tipo_cliente`. Esto permite insertar supertipo y subtipo dentro de una transacción y rechaza una fila incompleta al confirmar. La tabla única con columnas nulas era una alternativa de modelado: tener NULL no viola 3FN por sí mismo; la forma normal depende de las dependencias funcionales.

El resto de relaciones tiene atributos no clave dependientes de una clave candidata completa. En `parcela`, la clave es `(id_finca,nro_parcela)`; en `composicion`, `(cod_vino,id_cepa)`; en los renglones, la cabecera y el vino. `localidad` concentra `encargado_regional`, evitando repetirlo por sala. Los importes calculados en comprobante son una materialización controlada del detalle y se mantienen por trigger; se documentan como redundancia operacional deliberada, no como prueba de 3FN estricta de esa tabla. El descuento y precio del renglón registran el valor histórico al vender.

El informe inicial atribuía `UNIQUE(codigo_postal,nombre)` a `localidad`, pero esa restricción no existe. Tampoco se impone ahora: provincia forma parte del contexto geográfico y no se ha demostrado que el par sea una clave natural válida. Las afirmaciones de rendimiento a 500.000 filas son hipótesis hasta medir la etapa 4.

## Política de documentos

El comprobante queda inmutable para edición o borrado después de crearlo. Los renglones se agregan en la misma transacción que la cabecera; el motor fija precio vigente, descuento y neto redondeado de cada renglón, descuenta stock con una actualización condicional atómica y recalcula cabecera como suma de los renglones. Una venta fallida revierte todo. `fn_total_comprobante` usa los valores históricos, no el descuento actual del cliente. La suma de importes netos redondeados por renglón determina `total` y el descuento de cabecera es bruto menos neto.

Ingresos y transferencias comienzan en confección; las llamadas `sp_terminar_*` y `sp_procesar_*` hacen las transiciones. El rol de API sólo inserta cabeceras y llama procedimientos; no puede actualizar el estado ni escribir stock directamente. El propietario y un administrador conservan facultades de mantenimiento, por lo que las operaciones administrativas requieren disciplina operacional.

## Límites y etapa siguiente

La consigna posterior U6 propone subir a 35 % a ciertos exportadores, en conflicto con RN-06 que exige 30 %. Se mantiene RN-06 para cerrar estas etapas; antes de resolver U6 debe acordarse si existe una promoción histórica adicional y modelarla por separado.

El esquema y diccionario adjuntos se generaron desde PostgreSQL 18. Falta repetir la migración y la suite en el Docker Compose PostgreSQL 16, revisar visualmente los diagramas y decidir si la cátedra requiere una exportación PDF de estos documentos. No hay medición de rendimiento de la carga masiva.
