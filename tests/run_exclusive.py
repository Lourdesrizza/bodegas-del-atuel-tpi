"""Crea base nueva *_test, ejecuta 001-007 y suite con parada inmediata."""
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DB = sys.argv[1] if len(sys.argv)>1 else "atuel_cierre_test"
if not DB.endswith("_test") or not DB.replace("_", "").isalnum():
    raise SystemExit("Usar nombre alfanumérico terminado en _test")
BIN = pathlib.Path(os.environ.get("PG_BIN", r"C:\Program Files\PostgreSQL\18\bin"))
common = ["-h",os.environ.get("PGHOST","127.0.0.1"),"-p",os.environ.get("PGPORT","55440"),
          "-U",os.environ.get("PGUSER","atuel_admin")]
createdb = subprocess.run([str(BIN/"createdb.exe"),*common,DB],text=True,capture_output=True)
if createdb.returncode:
    raise SystemExit("No se creó una base nueva; no se ejecutó ninguna migración. "+createdb.stderr.strip())
psql=[str(BIN/"psql.exe"),"-X","-v","ON_ERROR_STOP=1",*common,"-d",DB]
version=subprocess.run([*psql,"-Atc","SHOW server_version"],text=True,capture_output=True,check=True).stdout.strip()
lines=[f"Base exclusiva: {DB}",f"PostgreSQL: {version}","ON_ERROR_STOP=1"]
for file in [*sorted((ROOT/"db/migrations").glob("0*.sql")),ROOT/"tests/db_tests.sql"]:
    run=subprocess.run([*psql,"-f",str(file)],text=True,capture_output=True)
    lines.append(f"{file.relative_to(ROOT)}: {'OK' if run.returncode==0 else 'FALLO'} (exit={run.returncode})")
    if run.returncode:
        lines.append(run.stderr.strip())
        break
    if file.name=="db_tests.sql":
        lines.append(run.stdout.strip())
        lines.append(run.stderr.strip())
out=ROOT/"docs/evidencias_cierre"
out.mkdir(exist_ok=True)
log=out/(DB+".log")
log.write_text("\n".join(lines)+"\n",encoding="utf-8")
print("\n".join(line for line in lines if not line.startswith(("BEGIN","INSERT","DO","SET","CALL"))))
print("Evidencia:",log)
if any("FALLO" in line for line in lines):
    raise SystemExit(1)
