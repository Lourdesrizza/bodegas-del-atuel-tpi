# Trazabilidad RN-01 a RN-15

| Regla | Mecanismo principal | Prueba reproducible | Estado |
|---|---|---|---|
| RN-01 | `vino.precio` CHECK; captura en trigger de venta | `tests/db_tests.sql`: precio cero y captura del catálogo | Probado PG18 |
| RN-02 | `sala_venta.id_localidad` FK; encargado en localidad | sala válida y FK inválida | Probado PG18 |
| RN-03 | `empleado.id_sala` FK NOT NULL | empleado válido y sin sala | Probado PG18 |
| RN-04 | PK de parcela; UNIQUE por parcela y campaña | parcela válida y cosecha duplicada | Probado PG18 |
| RN-05 | constraint triggers diferidos en vino y composición | corte 100 %, vino sin corte y traslado de componente | Probado PG18 |
| RN-06 | catálogo tipo/descuento; función; trigger diferido de subtipos | descuento histórico, subtipo correcto e incompatible | Probado PG18 |
| RN-07 | FK a exportador y CHECK de fechas | dos permisos y vencimiento inválido | Probado PG18 |
| RN-08 | función de suma histórica; trigger de cabecera; inmutabilidad | total, edición rechazada, redondeo multirrenglón e historia | Probado PG18 |
| RN-09 | UPDATE condicional de stock; CHECK no negativo | venta válida, sin stock y dos ventas simultáneas | Probado PG18 |
| RN-10 | ENUM, triggers de estados, procedimientos | ingreso procesado y transición directa rechazada | Probado PG18 |
| RN-11 | ENUM, fecha, procedimientos y stock bloqueado | transferencia procesada, falta de stock atómica y fecha inmutable | Probado PG18 |
| RN-12 | triggers que bloquean ambas cabeceras en orden | cambios y traslado desde documentos procesados rechazados | Probado PG18 |
| RN-13 | trigger AFTER UPDATE y auditoría protegida por roles | auditoría creada y DELETE API rechazado | Probado PG18 |
| RN-14 | FK restrictivas | vino, bodega y transportista con movimientos no se borran | Probado PG18 |
| RN-15 | CHECK de cantidades, superficies, kilos, graduación | cantidad, superficie, kilos y graduación inválidos rechazados | Probado PG18 |

La suite nueva sustituye los bloques de prueba que antes capturaban su propio `RAISE`. Cada expectativa negativa conserva un indicador y falla fuera del bloque `EXCEPTION`. Sólo se ejecuta en una base nueva de laboratorio; no hace TRUNCATE global.

Además se comprobaron permisos efectivos de `app_rw` y `app_ro`, ausencia de USAGE de secuencias en lectura y ausencia de EXECUTE público para una función futura creada por `app_owner`.
