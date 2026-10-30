-- ============================================================================
-- PROYECTO: Bodegas del Atuel
-- ETAPA 2: Integridad y Restricciones Declarativas (002_constraints.sql)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TIPOS PROPIOS Y DOMINIOS
-- ----------------------------------------------------------------------------
-- Se crean antes de las tablas en 001. No se repiten conversiones.

-- ----------------------------------------------------------------------------
-- 2. VALORES POR DEFECTO (DEFAULT)
-- ----------------------------------------------------------------------------

ALTER TABLE cliente 
    ALTER COLUMN fecha_alta SET DEFAULT CURRENT_DATE;

ALTER TABLE comprobante 
    ALTER COLUMN fecha SET DEFAULT CURRENT_DATE;

ALTER TABLE ingreso 
    ALTER COLUMN fecha SET DEFAULT CURRENT_DATE,
    ALTER COLUMN estado SET DEFAULT 'en_confeccion'::estado_documento;

ALTER TABLE transferencia 
    ALTER COLUMN fecha_confeccion SET DEFAULT CURRENT_DATE,
    ALTER COLUMN estado SET DEFAULT 'en_confeccion'::estado_documento;

ALTER TABLE auditoria_precio 
    ALTER COLUMN fecha_hora SET DEFAULT CURRENT_TIMESTAMP;

-- ----------------------------------------------------------------------------
-- 3. RESTRICCIONES DE UNICIDAD (UNIQUE)
-- ----------------------------------------------------------------------------

-- Unicidad del vino: no pueden coexistir vinos con mismo nombre, añada y volumen
ALTER TABLE vino 
    ADD CONSTRAINT uq_vino_nombre_anada_volumen UNIQUE (nombre, anada, volumen_ml);

-- RN-04: Una parcela se cosecha como máximo una vez por campaña
ALTER TABLE lote_uva 
    ADD CONSTRAINT uq_lote_parcela_campania UNIQUE (id_finca, nro_parcela, campania);

-- CUIT único por transportista
ALTER TABLE transportista 
    ADD CONSTRAINT uq_transportista_cuit UNIQUE (cuit);

-- Documento único por cliente
ALTER TABLE cliente 
    ADD CONSTRAINT uq_cliente_documento UNIQUE (tipo_doc, numero_doc);

-- Razón social única de bodegas
ALTER TABLE bodega 
    ADD CONSTRAINT uq_bodega_razon_social UNIQUE (razon_social);

-- ----------------------------------------------------------------------------
-- 4. RESTRICCIONES DE CHEQUEO (CHECK)
-- ----------------------------------------------------------------------------

-- RN-01 y RN-15: El precio del vino es mayor que cero
ALTER TABLE vino 
    ADD CONSTRAINT ck_vino_precio_positivo CHECK (precio > 0);

-- RN-15: Graduación alcohólica válida entre 5° y 20°
ALTER TABLE vino 
    ADD CONSTRAINT ck_vino_graduacion_rango CHECK (graduacion BETWEEN 5.00 AND 20.00);

-- Tipo de vino controlado
ALTER TABLE vino 
    ADD CONSTRAINT ck_vino_tipo_valido CHECK (tipo IN ('tinto', 'blanco', 'rosado', 'espumante'));

-- Presentaciones de volumen permitidas (en ml)
ALTER TABLE vino 
    ADD CONSTRAINT ck_vino_volumen_valido CHECK (volumen_ml IN (187, 375, 750, 1500, 3000));

-- Añadas razonables
ALTER TABLE vino 
    ADD CONSTRAINT ck_vino_anada_valida CHECK (anada BETWEEN 1990 AND 2100);

-- RN-07: Verificación entre columnas en permisos (vencimiento posterior a emisión)
ALTER TABLE permiso_exportacion 
    ADD CONSTRAINT ck_permiso_fechas CHECK (fecha_vencimiento > fecha_emision);

-- RN-09 y RN-15: El stock nunca es negativo
ALTER TABLE stock_sala 
    ADD CONSTRAINT ck_stock_sala_no_negativo CHECK (cantidad >= 0);

ALTER TABLE stock_deposito 
    ADD CONSTRAINT ck_stock_deposito_no_negativo CHECK (cantidad >= 0);

-- Porcentaje individual de cepa en la composición (la suma de 100 se valida en trigger)
ALTER TABLE composicion 
    ADD CONSTRAINT ck_composicion_porcentaje CHECK (porcentaje > 0 AND porcentaje <= 100);

-- Cantidades en renglones estrictamente positivas
ALTER TABLE renglon_comprobante 
    ADD CONSTRAINT ck_renglon_comprobante_cantidad CHECK (cantidad > 0);

ALTER TABLE renglon_ingreso 
    ADD CONSTRAINT ck_renglon_ingreso_cantidad CHECK (cantidad > 0);

ALTER TABLE renglon_transferencia 
    ADD CONSTRAINT ck_renglon_transferencia_cantidad CHECK (cantidad > 0);

-- Salarios, superficies y kilos positivos (RN-15)
ALTER TABLE empleado 
    ADD CONSTRAINT ck_empleado_salario_positivo CHECK (salario > 0);

ALTER TABLE finca 
    ADD CONSTRAINT ck_finca_superficie_positiva CHECK (superficie_ha > 0);

ALTER TABLE parcela 
    ADD CONSTRAINT ck_parcela_superficie_positiva CHECK (superficie > 0);

ALTER TABLE lote_uva 
    ADD CONSTRAINT ck_lote_kilos_positivos CHECK (kilos > 0);

-- Parámetros enológicos de análisis de calidad
ALTER TABLE analisis_calidad 
    ADD CONSTRAINT ck_analisis_brix CHECK (brix >= 0),
    ADD CONSTRAINT ck_analisis_ph CHECK (ph BETWEEN 0.00 AND 14.00),
    ADD CONSTRAINT ck_analisis_acidez CHECK (acidez_total >= 0);

-- RN-06: cliente referencia el catálogo tipo_cliente; descuento no se duplica.

-- ----------------------------------------------------------------------------
-- 5. ACCIONES REFERENCIALES (ON DELETE / ON UPDATE)
-- ----------------------------------------------------------------------------

-- RN-14: No se puede borrar una bodega, transportista o vino con movimientos (RESTRICT)
ALTER TABLE vino 
    DROP CONSTRAINT IF EXISTS vino_cuit_bodega_fkey,
    ADD CONSTRAINT fk_vino_bodega 
        FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) 
        ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE lote_uva 
    DROP CONSTRAINT IF EXISTS lote_uva_cuit_bodega_fkey,
    ADD CONSTRAINT fk_lote_bodega 
        FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) 
        ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE ingreso 
    DROP CONSTRAINT IF EXISTS ingreso_cuit_bodega_fkey,
    DROP CONSTRAINT IF EXISTS ingreso_cod_transportista_fkey,
    ADD CONSTRAINT fk_ingreso_bodega 
        FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_ingreso_transportista 
        FOREIGN KEY (cod_transportista) REFERENCES transportista(cod_transportista) 
        ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE renglon_comprobante 
    DROP CONSTRAINT IF EXISTS renglon_comprobante_cod_vino_fkey,
    ADD CONSTRAINT fk_renglon_vino 
        FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) 
        ON DELETE RESTRICT ON UPDATE CASCADE;

-- Tablas dependientes y renglones: si se elimina la cabecera, se eliminan los renglones (CASCADE)
ALTER TABLE renglon_comprobante 
    DROP CONSTRAINT IF EXISTS renglon_comprobante_nro_comprobante_fkey,
    ADD CONSTRAINT fk_renglon_comprobante_cabecera 
        FOREIGN KEY (nro_comprobante) REFERENCES comprobante(nro_comprobante) 
        ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE renglon_ingreso 
    DROP CONSTRAINT IF EXISTS renglon_ingreso_cod_ingreso_fkey,
    ADD CONSTRAINT fk_renglon_ingreso_cabecera 
        FOREIGN KEY (cod_ingreso) REFERENCES ingreso(cod_ingreso) 
        ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE renglon_transferencia 
    DROP CONSTRAINT IF EXISTS renglon_transferencia_nro_solicitud_fkey,
    ADD CONSTRAINT fk_renglon_transferencia_cabecera 
        FOREIGN KEY (nro_solicitud) REFERENCES transferencia(nro_solicitud) 
        ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE composicion 
    DROP CONSTRAINT IF EXISTS composicion_cod_vino_fkey,
    ADD CONSTRAINT fk_composicion_vino 
        FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) 
        ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE vino_maridaje 
    DROP CONSTRAINT IF EXISTS vino_maridaje_cod_vino_fkey,
    ADD CONSTRAINT fk_vino_maridaje_vino 
        FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) 
        ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE permiso_exportacion 
    DROP CONSTRAINT IF EXISTS permiso_exportacion_id_cliente_fkey,
    ADD CONSTRAINT fk_permiso_exportador 
        FOREIGN KEY (id_cliente) REFERENCES exportador(id_cliente) 
        ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE socio 
    DROP CONSTRAINT IF EXISTS socio_id_cliente_fkey,
    ADD CONSTRAINT fk_socio_cliente 
        FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) 
        ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE distribuidor 
    DROP CONSTRAINT IF EXISTS distribuidor_id_cliente_fkey,
    ADD CONSTRAINT fk_distribuidor_cliente 
        FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) 
        ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE exportador 
    DROP CONSTRAINT IF EXISTS exportador_id_cliente_fkey,
    ADD CONSTRAINT fk_exportador_cliente 
        FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) 
        ON DELETE CASCADE ON UPDATE CASCADE;
