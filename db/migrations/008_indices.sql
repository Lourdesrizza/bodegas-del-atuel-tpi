-- Etapa 4. Índices adicionales sobre el esquema de 001–007.
BEGIN;

-- S3: primero igualdad por sala, después rango de fechas.
-- El cliente se proyecta para el JOIN y COUNT DISTINCT sin agregar una clave de orden.
CREATE INDEX idx_comprobante_sala_fecha
    ON public.comprobante (id_sala, fecha) INCLUDE (id_cliente);

-- S8: intervalo de fechas para todas las salas. El índice también contiene
-- los datos necesarios para agrupar y sumar, si la visibilidad permite un Index Only Scan.
CREATE INDEX idx_comprobante_fecha_ventas
    ON public.comprobante (fecha) INCLUDE (id_sala, total);

-- S4: cod_vino es FK y filtro de igualdad. La PK existente comienza por
-- nro_solicitud. El orden inverso permite buscar por vino antes de unir cabeceras.
CREATE INDEX idx_renglon_transferencia_vino_solicitud
    ON public.renglon_transferencia (cod_vino, nro_solicitud) INCLUDE (cantidad);

-- S5: solo documentos pendientes. El predicado coincide con la consigna
-- y excluye el historial procesado. No depende de la fecha actual.
CREATE INDEX idx_transferencia_pendiente_sala
    ON public.transferencia (id_sala) INCLUDE (nro_solicitud)
    WHERE estado <> 'procesado';

-- I1: por transportista (FK) y rango de fecha. También sirve para localizar
-- ingresos asociados al controlar el borrado o cambio de clave de un transportista.
CREATE INDEX idx_ingreso_transportista_fecha
    ON public.ingreso (cod_transportista, fecha);

COMMIT;
