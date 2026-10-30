"""Prueba de dos ventas simultáneas. Crea una base NUEVA terminada en _test."""
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DB = sys.argv[1] if len(sys.argv) > 1 else "atuel_concurrencia_test"
if not DB.endswith("_test") or not DB.replace("_", "").isalnum():
    raise SystemExit("El nombre debe ser alfanumérico y terminar en _test")
BIN = pathlib.Path(os.environ.get("PG_BIN", r"C:\Program Files\PostgreSQL\18\bin"))
HOST = os.environ.get("PGHOST", "127.0.0.1")
PORT = os.environ.get("PGPORT", "55440")
USER = os.environ.get("PGUSER", "atuel_admin")
common = ["-h", HOST, "-p", PORT, "-U", USER]
subprocess.run([str(BIN / "createdb.exe"), *common, DB], check=True)
psql = [str(BIN / "psql.exe"), "-X", "-v", "ON_ERROR_STOP=1", *common, "-d", DB]
for file in sorted((ROOT / "db/migrations").glob("0*.sql")):
    subprocess.run([*psql, "-f", str(file)], check=True, capture_output=True)
fixture = """
BEGIN;
INSERT INTO localidad VALUES(1,'5600','San Rafael','Mendoza','X');
INSERT INTO sala_venta VALUES(1,1,'Mitre','1','Lunes');
INSERT INTO bodega VALUES('30708090101','Bodega','X');
INSERT INTO cepa VALUES(1,'Malbec','tinta');
INSERT INTO vino VALUES(1,'30708090101','Vino','tinto',2024,750,13,100);
INSERT INTO composicion VALUES(1,1,100);
INSERT INTO cliente VALUES(1,1,'Cliente','DNI','1','X',CURRENT_DATE,'socio');
INSERT INTO socio VALUES(1);
INSERT INTO stock_sala VALUES(1,1,1);
INSERT INTO comprobante(nro_comprobante,id_cliente,id_sala) VALUES(1,1,1),(2,1,1);
COMMIT;
"""
subprocess.run(psql, input=fixture, text=True, check=True, capture_output=True)
procs = [subprocess.Popen(psql, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True) for _ in (1, 2)]
results = [p.communicate(f"BEGIN; SELECT pg_sleep(1); INSERT INTO renglon_comprobante VALUES({i},1,1,0,0,0); COMMIT;")
           for i, p in enumerate(procs, 1)]
codes = [p.returncode for p in procs]
state = subprocess.run([*psql, "-Atc", "SELECT cantidad FROM stock_sala WHERE id_sala=1 AND cod_vino=1; SELECT count(*) FROM renglon_comprobante;"],
                       text=True, capture_output=True, check=True).stdout.strip().splitlines()
evidence = ROOT / "docs/evidencias_cierre" / (DB + ".log")
evidence.parent.mkdir(exist_ok=True)
evidence.write_text(f"Base exclusiva: {DB}\nresultados={codes}; stock={state[0]}; ventas={state[1]}\n"
                    + "\n".join(err.strip() for _,err in results if err.strip()) + "\n",encoding="utf-8")
print(f"resultados={codes}; stock={state[0]}; ventas={state[1]}")
if sorted(codes) != [0, 3] or state != ["0", "1"]:
    for out, err in results:
        print(out, err, file=sys.stderr)
    raise SystemExit("FALLO: se esperaba una venta y un rechazo por falta de stock")
print("OK: una sola venta confirmó la última botella")
print("Evidencia:",evidence)
