SELECT current_database(),current_user;
SELECT count(*) cabeceras_restauradas FROM ingreso
WHERE estado='procesado' AND fecha<CURRENT_DATE-365;
SELECT count(*) renglones_restaurados FROM renglon_ingreso JOIN ingreso USING(cod_ingreso)
WHERE estado='procesado' AND fecha<CURRENT_DATE-365;
SELECT count(*) filas_stock FROM stock_deposito;
SELECT tgname,tgenabled FROM pg_trigger WHERE tgname='trg_bloqueo_renglon_ingreso';
