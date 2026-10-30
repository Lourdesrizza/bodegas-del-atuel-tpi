# Diccionario de datos revisado

Generado desde `pg_catalog` e `information_schema` con `docs/generar_modelado.py`. Nulabilidad y tipos corresponden a la base migrada.

## analisis_calidad

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_analisis | INTEGER | no | PK; DEFAULT nextval('analisis_calidad_id_analisis_seq'::regclass) | Identificador de analisis_calidad. |
| nro_lote | INTEGER | no | FK → lote_uva.nro_lote | Referencia a lote_uva.nro_lote. |
| fecha | DATE | no |  | Fecha de analisis_calidad. |
| brix | NUMERIC(4,2) | no |  | Brix de analisis_calidad. |
| ph | NUMERIC(3,2) | no |  | Ph de analisis_calidad. |
| acidez_total | NUMERIC(5,2) | no |  | Acidez total de analisis_calidad. |

## auditoria_precio

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_auditoria | INTEGER | no | PK; DEFAULT nextval('auditoria_precio_id_auditoria_seq'::regclass) | Identificador de auditoria_precio. |
| cod_vino | INTEGER | no | FK → vino.cod_vino | Referencia a vino.cod_vino. |
| precio_anterior | NUMERIC(10,2) | no |  | Precio anterior de auditoria_precio. |
| precio_nuevo | NUMERIC(10,2) | no |  | Precio nuevo de auditoria_precio. |
| fecha_hora | TIMESTAMP WITHOUT TIME ZONE | no | DEFAULT CURRENT_TIMESTAMP | Fecha hora de auditoria_precio. |
| usuario | VARCHAR(100) | no |  | Usuario de auditoria_precio. |

## bodega

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cuit | cuit_dom | no | PK | Identificador de bodega. |
| razon_social | VARCHAR(150) | no |  | Razon social de bodega. |
| domicilio | VARCHAR(200) | no |  | Domicilio de bodega. |

## cepa

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_cepa | INTEGER | no | PK; DEFAULT nextval('cepa_id_cepa_seq'::regclass) | Identificador de cepa. |
| nombre | VARCHAR(80) | no |  | Nombre de cepa. |
| tipo | VARCHAR(20) | no |  | Tipo de cepa. |

## cliente

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_cliente | INTEGER | no | PK; DEFAULT nextval('cliente_id_cliente_seq'::regclass) | Identificador de cliente. |
| id_localidad | INTEGER | no | FK → localidad.id_localidad | Referencia a localidad.id_localidad. |
| nombre_o_razon_social | VARCHAR(150) | no |  | Nombre o razon social de cliente. |
| tipo_doc | VARCHAR(20) | no |  | Tipo doc de cliente. |
| numero_doc | VARCHAR(30) | no |  | Numero doc de cliente. |
| domicilio | VARCHAR(200) | no |  | Domicilio de cliente. |
| fecha_alta | DATE | no | DEFAULT CURRENT_DATE | Fecha alta de cliente. |
| tipo_cliente | VARCHAR(30) | no | FK → tipo_cliente.tipo_cliente | Referencia a tipo_cliente.tipo_cliente. |

## composicion

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_vino | INTEGER | no | PK; FK → vino.cod_vino | Referencia a vino.cod_vino. |
| id_cepa | INTEGER | no | PK; FK → cepa.id_cepa | Referencia a cepa.id_cepa. |
| porcentaje | NUMERIC(5,2) | no |  | Participación de la cepa en el corte. |

## comprobante

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| nro_comprobante | INTEGER | no | PK; DEFAULT nextval('comprobante_nro_comprobante_seq'::regclass) | Identificador de comprobante. |
| id_cliente | INTEGER | no | FK → cliente.id_cliente | Referencia a cliente.id_cliente. |
| id_sala | INTEGER | no | FK → sala_venta.id_sala | Referencia a sala_venta.id_sala. |
| fecha | DATE | no | DEFAULT CURRENT_DATE | Fecha de comprobante. |
| subtotal | NUMERIC(12,2) | no | DEFAULT 0 | Suma bruta de los renglones. |
| descuento | NUMERIC(12,2) | no | DEFAULT 0 | Descuento calculado o porcentaje del tipo. |
| total | NUMERIC(12,2) | no | DEFAULT 0 | Suma de importes netos redondeados. |

## distribuidor

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_cliente | INTEGER | no | PK; FK → cliente.id_cliente | Referencia a cliente.id_cliente. |
| zona_cobertura | VARCHAR(150) | no |  | Zona cobertura de distribuidor. |
| nro_habilitacion | VARCHAR(50) | no |  | Nro habilitacion de distribuidor. |

## empleado

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cuit | cuit_dom | no | PK | Identificador de empleado. |
| id_sala | INTEGER | no | FK → sala_venta.id_sala | Referencia a sala_venta.id_sala. |
| nombre | VARCHAR(150) | no |  | Nombre de empleado. |
| fecha_ingreso | DATE | no |  | Fecha ingreso de empleado. |
| salario | NUMERIC(12,2) | no |  | Salario de empleado. |

## exportador

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_cliente | INTEGER | no | PK; FK → cliente.id_cliente | Referencia a cliente.id_cliente. |
| pais_destino | VARCHAR(100) | no |  | Pais destino de exportador. |

## finca

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_finca | INTEGER | no | PK; DEFAULT nextval('finca_id_finca_seq'::regclass) | Identificador de finca. |
| nombre | VARCHAR(100) | no |  | Nombre de finca. |
| superficie_ha | NUMERIC(8,2) | no |  | Superficie ha de finca. |
| departamento | VARCHAR(100) | no |  | Departamento de finca. |
| provincia | VARCHAR(100) | no |  | Provincia de finca. |

## ingreso

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_ingreso | INTEGER | no | PK; DEFAULT nextval('ingreso_cod_ingreso_seq'::regclass) | Identificador de ingreso. |
| cuit_bodega | cuit_dom | no | FK → bodega.cuit | Referencia a bodega.cuit. |
| cod_transportista | INTEGER | no | FK → transportista.cod_transportista | Referencia a transportista.cod_transportista. |
| fecha | DATE | no | DEFAULT CURRENT_DATE | Fecha de ingreso. |
| estado | estado_documento | no | DEFAULT 'en_confeccion'::estado_documento | Estado controlado del documento. |

## localidad

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_localidad | INTEGER | no | PK; DEFAULT nextval('localidad_id_localidad_seq'::regclass) | Identificador de localidad. |
| codigo_postal | VARCHAR(10) | no |  | Codigo postal de localidad. |
| nombre | VARCHAR(100) | no |  | Nombre de localidad. |
| provincia | VARCHAR(100) | no |  | Provincia de localidad. |
| encargado_regional | VARCHAR(150) | no |  | Encargado regional de localidad. |

## lote_uva

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| nro_lote | INTEGER | no | PK; DEFAULT nextval('lote_uva_nro_lote_seq'::regclass) | Identificador de lote_uva. |
| id_finca | INTEGER | no | FK → parcela.id_finca | Referencia a parcela.id_finca. |
| nro_parcela | INTEGER | no | FK → parcela.nro_parcela | Referencia a parcela.nro_parcela. |
| cuit_bodega | cuit_dom | no | FK → bodega.cuit | Referencia a bodega.cuit. |
| campania | SMALLINT | no |  | Campania de lote_uva. |
| fecha_cosecha | DATE | no |  | Fecha cosecha de lote_uva. |
| kilos | NUMERIC(10,2) | no |  | Kilos de lote_uva. |

## maridaje

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_maridaje | INTEGER | no | PK; DEFAULT nextval('maridaje_id_maridaje_seq'::regclass) | Identificador de maridaje. |
| nombre | VARCHAR(100) | no |  | Nombre de maridaje. |
| temperatura_servicio | NUMERIC(4,1) | no |  | Temperatura servicio de maridaje. |

## parcela

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_finca | INTEGER | no | PK; FK → finca.id_finca | Referencia a finca.id_finca. |
| nro_parcela | INTEGER | no | PK | Identificador de parcela. |
| id_cepa | INTEGER | no | FK → cepa.id_cepa | Referencia a cepa.id_cepa. |
| superficie | NUMERIC(8,2) | no |  | Superficie de parcela. |
| anio_plantacion | SMALLINT | no |  | Anio plantacion de parcela. |

## permiso_exportacion

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_permiso | VARCHAR(50) | no | PK | Identificador de permiso_exportacion. |
| id_cliente | INTEGER | no | FK → exportador.id_cliente | Referencia a exportador.id_cliente. |
| fecha_emision | DATE | no |  | Fecha emision de permiso_exportacion. |
| fecha_vencimiento | DATE | no |  | Fecha vencimiento de permiso_exportacion. |

## renglon_comprobante

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| nro_comprobante | INTEGER | no | PK; FK → comprobante.nro_comprobante | Referencia a comprobante.nro_comprobante. |
| cod_vino | INTEGER | no | PK; FK → vino.cod_vino | Referencia a vino.cod_vino. |
| cantidad | INTEGER | no |  | Botellas o unidades registradas. |
| precio_unitario | NUMERIC(10,2) | no |  | Precio histórico capturado al vender. |
| descuento_aplicado | NUMERIC(5,2) | no |  | Porcentaje histórico aplicado al renglón. |
| subtotal_renglon | NUMERIC(12,2) | no |  | Importe neto redondeado del renglón. |

## renglon_ingreso

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_ingreso | INTEGER | no | PK; FK → ingreso.cod_ingreso | Referencia a ingreso.cod_ingreso. |
| cod_vino | INTEGER | no | PK; FK → vino.cod_vino | Referencia a vino.cod_vino. |
| cantidad | INTEGER | no |  | Botellas o unidades registradas. |

## renglon_transferencia

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| nro_solicitud | INTEGER | no | PK; FK → transferencia.nro_solicitud | Referencia a transferencia.nro_solicitud. |
| cod_vino | INTEGER | no | PK; FK → vino.cod_vino | Referencia a vino.cod_vino. |
| cantidad | INTEGER | no |  | Botellas o unidades registradas. |

## sala_venta

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_sala | INTEGER | no | PK; DEFAULT nextval('sala_venta_id_sala_seq'::regclass) | Identificador de sala_venta. |
| id_localidad | INTEGER | no | FK → localidad.id_localidad | Referencia a localidad.id_localidad. |
| calle | VARCHAR(100) | no |  | Calle de sala_venta. |
| numero | VARCHAR(20) | no |  | Numero de sala_venta. |
| dia_cierre | VARCHAR(20) | no |  | Dia cierre de sala_venta. |

## socio

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_cliente | INTEGER | no | PK; FK → cliente.id_cliente | Referencia a cliente.id_cliente. |

## stock_deposito

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_vino | INTEGER | no | PK; FK → vino.cod_vino | Referencia a vino.cod_vino. |
| cantidad | INTEGER | no | DEFAULT 0 | Botellas o unidades registradas. |

## stock_sala

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| id_sala | INTEGER | no | PK; FK → sala_venta.id_sala | Referencia a sala_venta.id_sala. |
| cod_vino | INTEGER | no | PK; FK → vino.cod_vino | Referencia a vino.cod_vino. |
| cantidad | INTEGER | no | DEFAULT 0 | Botellas o unidades registradas. |

## tipo_cliente

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| tipo_cliente | VARCHAR(30) | no | PK | Identificador de tipo_cliente. |
| descuento | NUMERIC(5,2) | no |  | Descuento calculado o porcentaje del tipo. |

## transferencia

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| nro_solicitud | INTEGER | no | PK; DEFAULT nextval('transferencia_nro_solicitud_seq'::regclass) | Identificador de transferencia. |
| id_sala | INTEGER | no | FK → sala_venta.id_sala | Referencia a sala_venta.id_sala. |
| fecha_confeccion | DATE | no | DEFAULT CURRENT_DATE | Fecha actual fijada al crear la transferencia. |
| estado | estado_documento | no | DEFAULT 'en_confeccion'::estado_documento | Estado controlado del documento. |

## transportista

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_transportista | INTEGER | no | PK; DEFAULT nextval('transportista_cod_transportista_seq'::regclass) | Identificador de transportista. |
| cuit | cuit_dom | no |  | Cuit de transportista. |
| razon_social | VARCHAR(150) | no |  | Razon social de transportista. |
| domicilio | VARCHAR(200) | no |  | Domicilio de transportista. |
| email | VARCHAR(120) | no |  | Email de transportista. |
| telefono | VARCHAR(50) | no |  | Telefono de transportista. |

## transportista_localidad

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_transportista | INTEGER | no | PK; FK → transportista.cod_transportista | Referencia a transportista.cod_transportista. |
| id_localidad | INTEGER | no | PK; FK → localidad.id_localidad | Referencia a localidad.id_localidad. |

## vino

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_vino | INTEGER | no | PK; DEFAULT nextval('vino_cod_vino_seq'::regclass) | Identificador de vino. |
| cuit_bodega | cuit_dom | no | FK → bodega.cuit | Referencia a bodega.cuit. |
| nombre | VARCHAR(120) | no |  | Nombre de vino. |
| tipo | VARCHAR(30) | no |  | Tipo de vino. |
| anada | SMALLINT | no |  | Anada de vino. |
| volumen_ml | INTEGER | no |  | Volumen ml de vino. |
| graduacion | NUMERIC(4,2) | no |  | Graduacion de vino. |
| precio | NUMERIC(10,2) | no |  | Precio vigente del catálogo. |

## vino_maridaje

| Columna | Tipo | Nulo | Restricción | Descripción |
|---|---|---|---|---|
| cod_vino | INTEGER | no | PK; FK → vino.cod_vino | Referencia a vino.cod_vino. |
| id_maridaje | INTEGER | no | PK; FK → maridaje.id_maridaje | Referencia a maridaje.id_maridaje. |
