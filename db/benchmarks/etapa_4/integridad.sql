-- Huella por tabla y orden de clave primaria. Se ejecuta en ambos clones.
SELECT 'cliente' tabla,count(*),md5(string_agg(md5(t::text),'' ORDER BY id_cliente)) huella FROM cliente t
UNION ALL SELECT 'tipo_cliente',count(*),md5(string_agg(md5(t::text),'' ORDER BY tipo_cliente)) FROM tipo_cliente t
UNION ALL SELECT 'comprobante',count(*),md5(string_agg(md5(t::text),'' ORDER BY nro_comprobante)) FROM comprobante t
UNION ALL SELECT 'renglon_comprobante',count(*),md5(string_agg(md5(t::text),'' ORDER BY nro_comprobante,cod_vino)) FROM renglon_comprobante t
UNION ALL SELECT 'vino',count(*),md5(string_agg(md5(t::text),'' ORDER BY cod_vino)) FROM vino t
UNION ALL SELECT 'transferencia',count(*),md5(string_agg(md5(t::text),'' ORDER BY nro_solicitud)) FROM transferencia t
UNION ALL SELECT 'renglon_transferencia',count(*),md5(string_agg(md5(t::text),'' ORDER BY nro_solicitud,cod_vino)) FROM renglon_transferencia t
UNION ALL SELECT 'sala_venta',count(*),md5(string_agg(md5(t::text),'' ORDER BY id_sala)) FROM sala_venta t
UNION ALL SELECT 'lote_uva',count(*),md5(string_agg(md5(t::text),'' ORDER BY nro_lote)) FROM lote_uva t
UNION ALL SELECT 'parcela',count(*),md5(string_agg(md5(t::text),'' ORDER BY id_finca,nro_parcela)) FROM parcela t
UNION ALL SELECT 'ingreso',count(*),md5(string_agg(md5(t::text),'' ORDER BY cod_ingreso)) FROM ingreso t
ORDER BY 1;
