# Esquema relacional revisado

Fuente: migraciones 001–007 aplicadas en PostgreSQL. PK y FK se indican por columna.

**analisis_calidad**(id_analisis INTEGER [PK, DEFAULT nextval('analisis_calidad_id_analisis_seq'::regclass)]; nro_lote INTEGER [FK → lote_uva.nro_lote]; fecha DATE; brix NUMERIC(4,2); ph NUMERIC(3,2); acidez_total NUMERIC(5,2))

**auditoria_precio**(id_auditoria INTEGER [PK, DEFAULT nextval('auditoria_precio_id_auditoria_seq'::regclass)]; cod_vino INTEGER [FK → vino.cod_vino]; precio_anterior NUMERIC(10,2); precio_nuevo NUMERIC(10,2); fecha_hora TIMESTAMP WITHOUT TIME ZONE [DEFAULT CURRENT_TIMESTAMP]; usuario VARCHAR(100))

**bodega**(cuit cuit_dom [PK]; razon_social VARCHAR(150); domicilio VARCHAR(200))

**cepa**(id_cepa INTEGER [PK, DEFAULT nextval('cepa_id_cepa_seq'::regclass)]; nombre VARCHAR(80); tipo VARCHAR(20))

**cliente**(id_cliente INTEGER [PK, DEFAULT nextval('cliente_id_cliente_seq'::regclass)]; id_localidad INTEGER [FK → localidad.id_localidad]; nombre_o_razon_social VARCHAR(150); tipo_doc VARCHAR(20); numero_doc VARCHAR(30); domicilio VARCHAR(200); fecha_alta DATE [DEFAULT CURRENT_DATE]; tipo_cliente VARCHAR(30) [FK → tipo_cliente.tipo_cliente])

**composicion**(cod_vino INTEGER [PK, FK → vino.cod_vino]; id_cepa INTEGER [PK, FK → cepa.id_cepa]; porcentaje NUMERIC(5,2))

**comprobante**(nro_comprobante INTEGER [PK, DEFAULT nextval('comprobante_nro_comprobante_seq'::regclass)]; id_cliente INTEGER [FK → cliente.id_cliente]; id_sala INTEGER [FK → sala_venta.id_sala]; fecha DATE [DEFAULT CURRENT_DATE]; subtotal NUMERIC(12,2) [DEFAULT 0]; descuento NUMERIC(12,2) [DEFAULT 0]; total NUMERIC(12,2) [DEFAULT 0])

**distribuidor**(id_cliente INTEGER [PK, FK → cliente.id_cliente]; zona_cobertura VARCHAR(150); nro_habilitacion VARCHAR(50))

**empleado**(cuit cuit_dom [PK]; id_sala INTEGER [FK → sala_venta.id_sala]; nombre VARCHAR(150); fecha_ingreso DATE; salario NUMERIC(12,2))

**exportador**(id_cliente INTEGER [PK, FK → cliente.id_cliente]; pais_destino VARCHAR(100))

**finca**(id_finca INTEGER [PK, DEFAULT nextval('finca_id_finca_seq'::regclass)]; nombre VARCHAR(100); superficie_ha NUMERIC(8,2); departamento VARCHAR(100); provincia VARCHAR(100))

**ingreso**(cod_ingreso INTEGER [PK, DEFAULT nextval('ingreso_cod_ingreso_seq'::regclass)]; cuit_bodega cuit_dom [FK → bodega.cuit]; cod_transportista INTEGER [FK → transportista.cod_transportista]; fecha DATE [DEFAULT CURRENT_DATE]; estado estado_documento [DEFAULT 'en_confeccion'::estado_documento])

**localidad**(id_localidad INTEGER [PK, DEFAULT nextval('localidad_id_localidad_seq'::regclass)]; codigo_postal VARCHAR(10); nombre VARCHAR(100); provincia VARCHAR(100); encargado_regional VARCHAR(150))

**lote_uva**(nro_lote INTEGER [PK, DEFAULT nextval('lote_uva_nro_lote_seq'::regclass)]; id_finca INTEGER [FK → parcela.id_finca]; nro_parcela INTEGER [FK → parcela.nro_parcela]; cuit_bodega cuit_dom [FK → bodega.cuit]; campania SMALLINT; fecha_cosecha DATE; kilos NUMERIC(10,2))

**maridaje**(id_maridaje INTEGER [PK, DEFAULT nextval('maridaje_id_maridaje_seq'::regclass)]; nombre VARCHAR(100); temperatura_servicio NUMERIC(4,1))

**parcela**(id_finca INTEGER [PK, FK → finca.id_finca]; nro_parcela INTEGER [PK]; id_cepa INTEGER [FK → cepa.id_cepa]; superficie NUMERIC(8,2); anio_plantacion SMALLINT)

**permiso_exportacion**(cod_permiso VARCHAR(50) [PK]; id_cliente INTEGER [FK → exportador.id_cliente]; fecha_emision DATE; fecha_vencimiento DATE)

**renglon_comprobante**(nro_comprobante INTEGER [PK, FK → comprobante.nro_comprobante]; cod_vino INTEGER [PK, FK → vino.cod_vino]; cantidad INTEGER; precio_unitario NUMERIC(10,2); descuento_aplicado NUMERIC(5,2); subtotal_renglon NUMERIC(12,2))

**renglon_ingreso**(cod_ingreso INTEGER [PK, FK → ingreso.cod_ingreso]; cod_vino INTEGER [PK, FK → vino.cod_vino]; cantidad INTEGER)

**renglon_transferencia**(nro_solicitud INTEGER [PK, FK → transferencia.nro_solicitud]; cod_vino INTEGER [PK, FK → vino.cod_vino]; cantidad INTEGER)

**sala_venta**(id_sala INTEGER [PK, DEFAULT nextval('sala_venta_id_sala_seq'::regclass)]; id_localidad INTEGER [FK → localidad.id_localidad]; calle VARCHAR(100); numero VARCHAR(20); dia_cierre VARCHAR(20))

**socio**(id_cliente INTEGER [PK, FK → cliente.id_cliente])

**stock_deposito**(cod_vino INTEGER [PK, FK → vino.cod_vino]; cantidad INTEGER [DEFAULT 0])

**stock_sala**(id_sala INTEGER [PK, FK → sala_venta.id_sala]; cod_vino INTEGER [PK, FK → vino.cod_vino]; cantidad INTEGER [DEFAULT 0])

**tipo_cliente**(tipo_cliente VARCHAR(30) [PK]; descuento NUMERIC(5,2))

**transferencia**(nro_solicitud INTEGER [PK, DEFAULT nextval('transferencia_nro_solicitud_seq'::regclass)]; id_sala INTEGER [FK → sala_venta.id_sala]; fecha_confeccion DATE [DEFAULT CURRENT_DATE]; estado estado_documento [DEFAULT 'en_confeccion'::estado_documento])

**transportista**(cod_transportista INTEGER [PK, DEFAULT nextval('transportista_cod_transportista_seq'::regclass)]; cuit cuit_dom; razon_social VARCHAR(150); domicilio VARCHAR(200); email VARCHAR(120); telefono VARCHAR(50))

**transportista_localidad**(cod_transportista INTEGER [PK, FK → transportista.cod_transportista]; id_localidad INTEGER [PK, FK → localidad.id_localidad])

**vino**(cod_vino INTEGER [PK, DEFAULT nextval('vino_cod_vino_seq'::regclass)]; cuit_bodega cuit_dom [FK → bodega.cuit]; nombre VARCHAR(120); tipo VARCHAR(30); anada SMALLINT; volumen_ml INTEGER; graduacion NUMERIC(4,2); precio NUMERIC(10,2))

**vino_maridaje**(cod_vino INTEGER [PK, FK → vino.cod_vino]; id_maridaje INTEGER [PK, FK → maridaje.id_maridaje])

## Relaciones

- analisis_calidad.nro_lote → lote_uva.nro_lote
- auditoria_precio.cod_vino → vino.cod_vino
- cliente.id_localidad → localidad.id_localidad
- cliente.tipo_cliente → tipo_cliente.tipo_cliente
- composicion.cod_vino → vino.cod_vino
- composicion.id_cepa → cepa.id_cepa
- comprobante.id_cliente → cliente.id_cliente
- comprobante.id_sala → sala_venta.id_sala
- distribuidor.id_cliente → cliente.id_cliente
- empleado.id_sala → sala_venta.id_sala
- exportador.id_cliente → cliente.id_cliente
- ingreso.cod_transportista → transportista.cod_transportista
- ingreso.cuit_bodega → bodega.cuit
- lote_uva.cuit_bodega → bodega.cuit
- lote_uva.id_finca → parcela.id_finca
- lote_uva.nro_parcela → parcela.nro_parcela
- parcela.id_cepa → cepa.id_cepa
- parcela.id_finca → finca.id_finca
- permiso_exportacion.id_cliente → exportador.id_cliente
- renglon_comprobante.cod_vino → vino.cod_vino
- renglon_comprobante.nro_comprobante → comprobante.nro_comprobante
- renglon_ingreso.cod_ingreso → ingreso.cod_ingreso
- renglon_ingreso.cod_vino → vino.cod_vino
- renglon_transferencia.cod_vino → vino.cod_vino
- renglon_transferencia.nro_solicitud → transferencia.nro_solicitud
- sala_venta.id_localidad → localidad.id_localidad
- socio.id_cliente → cliente.id_cliente
- stock_deposito.cod_vino → vino.cod_vino
- stock_sala.cod_vino → vino.cod_vino
- stock_sala.id_sala → sala_venta.id_sala
- transferencia.id_sala → sala_venta.id_sala
- transportista_localidad.cod_transportista → transportista.cod_transportista
- transportista_localidad.id_localidad → localidad.id_localidad
- vino.cuit_bodega → bodega.cuit
- vino_maridaje.cod_vino → vino.cod_vino
- vino_maridaje.id_maridaje → maridaje.id_maridaje