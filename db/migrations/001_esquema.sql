-- ============================================================================
-- PROYECTO: Bodegas del Atuel
-- ETAPA 1: Esquema Físico Base (001_esquema.sql)
-- ============================================================================

-- Migración de creación: ejecutar sólo en una base nueva y exclusiva.
-- No borra tablas preexistentes.

CREATE TYPE estado_documento AS ENUM ('en_confeccion', 'terminado', 'procesado');
CREATE DOMAIN cuit_dom AS CHAR(11) CHECK (VALUE ~ '^[0-9]{11}$');

-- ----------------------------------------------------------------------------
-- 1. LOCALIZACIÓN, SALAS Y PERSONAL
-- ----------------------------------------------------------------------------

CREATE TABLE localidad (
    id_localidad SERIAL PRIMARY KEY,
    codigo_postal VARCHAR(10) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    provincia VARCHAR(100) NOT NULL,
    encargado_regional VARCHAR(150) NOT NULL
);

CREATE TABLE sala_venta (
    id_sala SERIAL PRIMARY KEY,
    id_localidad INTEGER NOT NULL REFERENCES localidad(id_localidad),
    calle VARCHAR(100) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    dia_cierre VARCHAR(20) NOT NULL
);

CREATE TABLE empleado (
    cuit cuit_dom PRIMARY KEY,
    id_sala INTEGER NOT NULL REFERENCES sala_venta(id_sala),
    nombre VARCHAR(150) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    salario NUMERIC(12, 2) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2. PRODUCCIÓN AGRÍCOLA Y COSECHA
-- ----------------------------------------------------------------------------

CREATE TABLE finca (
    id_finca SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    superficie_ha NUMERIC(8, 2) NOT NULL,
    departamento VARCHAR(100) NOT NULL,
    provincia VARCHAR(100) NOT NULL
);

CREATE TABLE cepa (
    id_cepa SERIAL PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    tipo VARCHAR(20) NOT NULL
);

CREATE TABLE parcela (
    id_finca INTEGER NOT NULL REFERENCES finca(id_finca),
    nro_parcela INTEGER NOT NULL,
    id_cepa INTEGER NOT NULL REFERENCES cepa(id_cepa),
    superficie NUMERIC(8, 2) NOT NULL,
    anio_plantacion SMALLINT NOT NULL,
    PRIMARY KEY (id_finca, nro_parcela)
);

CREATE TABLE bodega (
    cuit cuit_dom PRIMARY KEY,
    razon_social VARCHAR(150) NOT NULL,
    domicilio VARCHAR(200) NOT NULL
);

CREATE TABLE lote_uva (
    nro_lote SERIAL PRIMARY KEY,
    id_finca INTEGER NOT NULL,
    nro_parcela INTEGER NOT NULL,
    cuit_bodega cuit_dom NOT NULL REFERENCES bodega(cuit),
    campania SMALLINT NOT NULL,
    fecha_cosecha DATE NOT NULL,
    kilos NUMERIC(10, 2) NOT NULL,
    FOREIGN KEY (id_finca, nro_parcela) REFERENCES parcela(id_finca, nro_parcela)
);

CREATE TABLE analisis_calidad (
    id_analisis SERIAL PRIMARY KEY,
    nro_lote INTEGER NOT NULL REFERENCES lote_uva(nro_lote),
    fecha DATE NOT NULL,
    brix NUMERIC(4, 2) NOT NULL,
    ph NUMERIC(3, 2) NOT NULL,
    acidez_total NUMERIC(5, 2) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 3. VINOS, COMPOSICIÓN Y MARIDAJE
-- ----------------------------------------------------------------------------

CREATE TABLE vino (
    cod_vino SERIAL PRIMARY KEY,
    cuit_bodega cuit_dom NOT NULL REFERENCES bodega(cuit),
    nombre VARCHAR(120) NOT NULL,
    tipo VARCHAR(30) NOT NULL,
    anada SMALLINT NOT NULL,
    volumen_ml INTEGER NOT NULL,
    graduacion NUMERIC(4, 2) NOT NULL,
    precio NUMERIC(10, 2) NOT NULL
);

CREATE TABLE composicion (
    cod_vino INTEGER NOT NULL REFERENCES vino(cod_vino),
    id_cepa INTEGER NOT NULL REFERENCES cepa(id_cepa),
    porcentaje NUMERIC(5, 2) NOT NULL,
    PRIMARY KEY (cod_vino, id_cepa)
);

CREATE TABLE maridaje (
    id_maridaje SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    temperatura_servicio NUMERIC(4, 1) NOT NULL
);

CREATE TABLE vino_maridaje (
    cod_vino INTEGER NOT NULL REFERENCES vino(cod_vino),
    id_maridaje INTEGER NOT NULL REFERENCES maridaje(id_maridaje),
    PRIMARY KEY (cod_vino, id_maridaje)
);

-- ----------------------------------------------------------------------------
-- 4. CLIENTES Y ESTRUCTURA DE SUBTIPOS
-- ----------------------------------------------------------------------------

CREATE TABLE tipo_cliente (
    tipo_cliente VARCHAR(30) PRIMARY KEY,
    descuento NUMERIC(5, 2) NOT NULL CHECK (
      (tipo_cliente='socio' AND descuento=10) OR
      (tipo_cliente='distribuidor' AND descuento=20) OR
      (tipo_cliente='exportador' AND descuento=30))
);
INSERT INTO tipo_cliente VALUES ('socio', 10), ('distribuidor', 20), ('exportador', 30);

CREATE TABLE cliente (
    id_cliente SERIAL PRIMARY KEY,
    id_localidad INTEGER NOT NULL REFERENCES localidad(id_localidad),
    nombre_o_razon_social VARCHAR(150) NOT NULL,
    tipo_doc VARCHAR(20) NOT NULL,
    numero_doc VARCHAR(30) NOT NULL,
    domicilio VARCHAR(200) NOT NULL,
    fecha_alta DATE NOT NULL,
    tipo_cliente VARCHAR(30) NOT NULL REFERENCES tipo_cliente(tipo_cliente)
);

CREATE TABLE socio (
    id_cliente INTEGER PRIMARY KEY REFERENCES cliente(id_cliente)
);

CREATE TABLE distribuidor (
    id_cliente INTEGER PRIMARY KEY REFERENCES cliente(id_cliente),
    zona_cobertura VARCHAR(150) NOT NULL,
    nro_habilitacion VARCHAR(50) NOT NULL
);

CREATE TABLE exportador (
    id_cliente INTEGER PRIMARY KEY REFERENCES cliente(id_cliente),
    pais_destino VARCHAR(100) NOT NULL
);

CREATE TABLE permiso_exportacion (
    cod_permiso VARCHAR(50) PRIMARY KEY,
    id_cliente INTEGER NOT NULL REFERENCES exportador(id_cliente),
    fecha_emision DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL
);

-- ----------------------------------------------------------------------------
-- 5. LOGÍSTICA, TRANSPORTE Y STOCKS
-- ----------------------------------------------------------------------------

CREATE TABLE transportista (
    cod_transportista SERIAL PRIMARY KEY,
    cuit cuit_dom NOT NULL,
    razon_social VARCHAR(150) NOT NULL,
    domicilio VARCHAR(200) NOT NULL,
    email VARCHAR(120) NOT NULL,
    telefono VARCHAR(50) NOT NULL
);

CREATE TABLE transportista_localidad (
    cod_transportista INTEGER NOT NULL REFERENCES transportista(cod_transportista),
    id_localidad INTEGER NOT NULL REFERENCES localidad(id_localidad),
    PRIMARY KEY (cod_transportista, id_localidad)
);

CREATE TABLE stock_deposito (
    cod_vino INTEGER PRIMARY KEY REFERENCES vino(cod_vino),
    cantidad INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE stock_sala (
    id_sala INTEGER NOT NULL REFERENCES sala_venta(id_sala),
    cod_vino INTEGER NOT NULL REFERENCES vino(cod_vino),
    cantidad INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (id_sala, cod_vino)
);

-- ----------------------------------------------------------------------------
-- 6. INGRESOS, TRANSFERENCIAS Y COMPROBANTES DE VENTA
-- ----------------------------------------------------------------------------

CREATE TABLE ingreso (
    cod_ingreso SERIAL PRIMARY KEY,
    cuit_bodega cuit_dom NOT NULL REFERENCES bodega(cuit),
    cod_transportista INTEGER NOT NULL REFERENCES transportista(cod_transportista),
    fecha DATE NOT NULL,
    estado estado_documento NOT NULL DEFAULT 'en_confeccion'
);

CREATE TABLE renglon_ingreso (
    cod_ingreso INTEGER NOT NULL REFERENCES ingreso(cod_ingreso),
    cod_vino INTEGER NOT NULL REFERENCES vino(cod_vino),
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (cod_ingreso, cod_vino)
);

CREATE TABLE transferencia (
    nro_solicitud SERIAL PRIMARY KEY,
    id_sala INTEGER NOT NULL REFERENCES sala_venta(id_sala),
    fecha_confeccion DATE NOT NULL,
    estado estado_documento NOT NULL DEFAULT 'en_confeccion'
);

CREATE TABLE renglon_transferencia (
    nro_solicitud INTEGER NOT NULL REFERENCES transferencia(nro_solicitud),
    cod_vino INTEGER NOT NULL REFERENCES vino(cod_vino),
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (nro_solicitud, cod_vino)
);

CREATE TABLE comprobante (
    nro_comprobante SERIAL PRIMARY KEY,
    id_cliente INTEGER NOT NULL REFERENCES cliente(id_cliente),
    id_sala INTEGER NOT NULL REFERENCES sala_venta(id_sala),
    fecha DATE NOT NULL,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
    descuento NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total NUMERIC(12, 2) NOT NULL DEFAULT 0
);

CREATE TABLE renglon_comprobante (
    nro_comprobante INTEGER NOT NULL REFERENCES comprobante(nro_comprobante),
    cod_vino INTEGER NOT NULL REFERENCES vino(cod_vino),
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10, 2) NOT NULL,
    descuento_aplicado NUMERIC(5, 2) NOT NULL,
    subtotal_renglon NUMERIC(12, 2) NOT NULL,
    PRIMARY KEY (nro_comprobante, cod_vino)
);

CREATE TABLE auditoria_precio (
    id_auditoria SERIAL PRIMARY KEY,
    cod_vino INTEGER NOT NULL REFERENCES vino(cod_vino),
    precio_anterior NUMERIC(10, 2) NOT NULL,
    precio_nuevo NUMERIC(10, 2) NOT NULL,
    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100) NOT NULL
);
