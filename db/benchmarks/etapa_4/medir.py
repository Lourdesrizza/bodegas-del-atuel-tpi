"""Medición reproducible en PostgreSQL 16 del contenedor aislado de 55441."""
import argparse
import ast
from concurrent.futures import ThreadPoolExecutor
import datetime
import json
from pathlib import Path
import re
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SOURCE = "atuel_base_test"
CONTAINER = "atuel_pg16_carga_test"
OWNER = "atuel_admin"


def docker(*args, data=None):
    result = subprocess.run(["docker", *args], input=data, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.decode(errors="replace"))
    return result.stdout.decode("utf-8")


def psql(db, sql, *options):
    return docker("exec", "-i", CONTAINER, "psql", "-X", "-w", "-U", OWNER,
                  "-d", db, "-v", "ON_ERROR_STOP=1", "-P", "pager=off", *options,
                  "-f", "-", data=sql.encode())


def check_environment():
    ports = docker("port", CONTAINER, "5432/tcp").splitlines()
    if not ports or any(not port.endswith(":55441") for port in ports):
        raise RuntimeError(f"Puerto inesperado: {ports}")
    identity = psql(SOURCE, "SELECT current_database(), current_user, version();", "-At").strip()
    if not identity.startswith(f"{SOURCE}|{OWNER}|PostgreSQL 16."):
        raise RuntimeError(f"Identidad inesperada: {identity}")
    return {"contenedor": CONTAINER, "puertos": ports, "origen": identity}


def create(db, template):
    docker("exec", CONTAINER, "createdb", "-w", "-U", OWNER,
           "--maintenance-db=postgres", "-T", template, db)


def apply(db, migration):
    sql = migration.read_text(encoding="utf-8-sig")
    return psql(db, sql, "-a")


def prepare(before, after, output):
    create(before, "template0")
    with (output / "preparacion.log").open("w", encoding="utf-8") as log:
        for migration in sorted((ROOT / "db/migrations").glob("00[1-7]_*.sql")):
            log.write(f"\n{before} · {migration.name}\n")
            log.write(apply(before, migration))
        # 001 precarga el catálogo. Se vacía solo en la base nueva.
        # El volcado omite la vista materializada y la reconstruimos tras la copia.
        dump = docker("exec", CONTAINER, "pg_dump", "-w", "-U", OWNER, "-a",
                      "--disable-triggers", "--no-owner", "--no-privileges", SOURCE)
        log.write(psql(before, "TRUNCATE tipo_cliente, cliente, socio, distribuidor, exportador, "
                       "permiso_exportacion, comprobante, renglon_comprobante;\n" + dump
                       + "\nREFRESH MATERIALIZED VIEW public.mv_ventas_mensuales_sala;\n",
                       "--single-transaction"))
        log.write(psql(before, "SET atuel.carga_modo='completa';\n" +
                       (ROOT / "db/seed/validar_carga.sql").read_text(encoding="utf-8")))
        log.write(psql(before, "VACUUM (ANALYZE);"))
        create(after, before)
        log.write(f"\nClonado {after} desde {before} con CREATE DATABASE TEMPLATE.\n")


def queries():
    text = (HERE / "consultas.sql").read_text(encoding="utf-8")
    for item in re.split(r"(?m)^-- (S\d+) ", text)[1:][::2]:
        block = re.search(rf"(?ms)^-- {item} .*?\n(.*?);", text)
        yield item, block.group(1)


def explain(db, sql):
    raw = psql(db, f"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)\n{sql};", "-At", "-q")
    return json.loads(raw)[0]


def catalog(db, output, label):
    sql = """SELECT current_database(), current_user, version(), CURRENT_DATE;
SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY 1,2;
SELECT (SELECT count(*) FROM comprobante) comprobantes,
       (SELECT count(*) FROM renglon_comprobante) renglones,
       (SELECT count(*) FROM renglon_transferencia) renglones_transferencia,
       (SELECT count(*) FROM lote_uva) lotes;
SHOW shared_buffers;
SHOW max_parallel_workers_per_gather;
SHOW random_page_cost;
SHOW jit;"""
    (output / f"catalogo_{label}.log").write_text(psql(db, sql, "-a"), encoding="utf-8")


def measure(databases, output, runs, filename):
    for label, db in databases.items():
        psql(db, "ANALYZE;")
        catalog(db, output, label)
    data = {}
    for code, sql in queries():
        # El orden alterna en cada vuelta y se conserva una corrida de calentamiento.
        samples = {label: [] for label in databases}
        for step in range(runs + 1):
            labels = list(databases)
            if step % 2:
                labels.reverse()
            for label in labels:
                samples[label].append(explain(databases[label], sql))
        results = {label: sorted(psql(db, sql + ";", "--csv", "-q").splitlines()[1:])
                   for label, db in databases.items()}
        if len(databases) > 1 and len(set(map(tuple, results.values()))) != 1:
            raise RuntimeError(f"{code}: resultados distintos")
        data[code] = {"sql": sql, "resultados": results, "planes": samples,
                      "medianas_ms": {label: statistics.median(
                          plan["Execution Time"] for plan in plans[1:])
                          for label, plans in samples.items()}}
        (output / filename).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
        print(code, data[code]["medianas_ms"], flush=True)


def extras(before, after, output):
    for db, name in ((before, "descartado"), (after, "no_utilizado")):
        sql = (HERE / f"{name}.sql").read_text(encoding="utf-8")
        (output / f"{name}.log").write_text(psql(db, sql, "-a"), encoding="utf-8")


def write_measure(databases, prefix, output, runs):
    sql = (HERE / "escritura.sql").read_text(encoding="utf-8")
    samples = {label: [] for label in databases}
    for step in range(runs + 1):
        labels = list(databases)
        if step % 2:
            labels.reverse()
        for label in labels:
            clone = f"{prefix}_w{step}_{label}_test"
            create(clone, databases[label])
            try:
                raw = psql(clone, "BEGIN;\n" + sql + "\nROLLBACK;", "-At", "-q")
                plan = json.loads(raw)[0]
                samples[label].append(plan)
                print("escritura", step, label, plan["Execution Time"], flush=True)
            finally:
                docker("exec", CONTAINER, "dropdb", "-w", "-U", OWNER,
                       "--maintenance-db=postgres", clone)
    summary = {label: statistics.median(plan["Execution Time"] for plan in plans[1:])
               for label, plans in samples.items()}
    (output / "escritura.json").write_text(json.dumps(
        {"sql": sql, "filas_cargadas": 150000, "medianas_ms": summary, "planes": samples},
        indent=2, ensure_ascii=False), encoding="utf-8")


def regression(prefix, output):
    db = f"{prefix}_regresion_test"
    create(db, "template0")
    with (output / "regresion.log").open("w", encoding="utf-8") as log:
        log.write(psql(db, "SELECT current_database(), current_user, version();", "-a"))
        for migration in sorted((ROOT / "db/migrations").glob("00[1-8]_*.sql")):
            log.write(f"\n{migration.name}\n")
            log.write(apply(db, migration))
        # Se copia el punto de entrada y su inclusión relativa sin modificarlos.
        folder = f"/tmp/{db}"
        docker("exec", CONTAINER, "mkdir", folder)
        for name in ("db_tests.sql", "etapas_1_2_regresion.sql"):
            docker("cp", str(ROOT / "tests" / name), f"{CONTAINER}:{folder}/{name}")
        args = ("exec", CONTAINER, "psql", "-X", "-w", "-U", OWNER, "-d", db,
                "-v", "ON_ERROR_STOP=1", "-P", "pager=off", "-f", f"{folder}/db_tests.sql")
        log.write("\ndocker " + " ".join(args) + "\n")
        log.write(docker(*args))
        log.write("\nSuite db_tests.sql: código 0.\n")


def verify_data(before, after, output):
    sql = (HERE / "integridad.sql").read_text(encoding="utf-8")
    results = {db: psql(db, sql, "--csv", "-q") for db in (SOURCE, before, after)}
    with (output / "integridad.log").open("w", encoding="utf-8") as log:
        log.write(sql)
        for db, result in results.items():
            log.write(f"\n{db}\n{result}")
        same = len(set(results.values())) == 1
        log.write(f"\nHuellas y conteos idénticos: {same}\n")
    if not same:
        raise RuntimeError("El dataset de los clones difiere")


def concurrency(prefix, output):
    db = f"{prefix}_regresion_test"
    # Reutiliza el fixture de la prueba existente y cambia el transporte al socket.
    tree = ast.parse((ROOT / "tests/concurrencia_ultima_botella.py").read_text(encoding="utf-8"))
    fixture = next(ast.literal_eval(node.value) for node in tree.body
                   if isinstance(node, ast.Assign)
                   and any(isinstance(target, ast.Name) and target.id == "fixture"
                           for target in node.targets))
    args = ["docker", "exec", "-i", CONTAINER, "psql", "-X", "-w", "-U", OWNER,
            "-d", db, "-v", "ON_ERROR_STOP=1", "-P", "pager=off", "-a", "-f", "-"]
    state_sql = ("SELECT cantidad,(SELECT count(*) FROM renglon_comprobante) "
                 "FROM stock_sala WHERE id_sala=1 AND cod_vino=1;")

    def sell(number):
        sql = (f"BEGIN; INSERT INTO renglon_comprobante VALUES({number},1,1,0,0,0); "
               "SELECT pg_sleep(0.5); COMMIT;")
        result = subprocess.run(args, input=sql.encode(), capture_output=True)
        return result, sql

    with (output / "concurrencia.log").open("w", encoding="utf-8") as log:
        log.write(" ".join(args) + "\n")
        log.write(psql(db, fixture, "-a"))
        with ThreadPoolExecutor(max_workers=2) as pool:
            sales = list(pool.map(sell, (1, 2)))
        for result, sql in sales:
            log.write(f"\n{sql}\nCódigo: {result.returncode}\n")
            log.write((result.stdout + result.stderr).decode("utf-8"))
        state = psql(db, state_sql, "-At").strip()
        log.write(f"\n{state_sql}\nStock|ventas: {state}\n")
        codes = sorted(result.returncode for result, _ in sales)
        if codes != [0, 3] or state != "0|1":
            raise RuntimeError("La prueba concurrente no produjo una venta y un rechazo")
        log.write("OK: una sola venta confirmó la última botella.\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("fase", choices=("preparar", "base", "aplicar", "comparar", "extras", "escritura", "regresion", "integridad", "concurrencia"))
    parser.add_argument("--prefijo", default="atuel_e4")
    parser.add_argument("--salida", type=Path, default=ROOT / "docs/evidencias_etapa_4")
    parser.add_argument("--corridas", type=int, default=7)
    args = parser.parse_args()
    if not re.fullmatch(r"atuel_e4[a-z0-9_]{0,24}", args.prefijo) or args.corridas < 3:
        parser.error("Se requiere un prefijo de laboratorio y al menos tres corridas")
    before, after = (f"{args.prefijo}_{name}_test" for name in ("sin", "con"))
    args.salida.mkdir(parents=True, exist_ok=True)
    env = check_environment()
    print(env, flush=True)
    with (args.salida / "sesiones.log").open("a", encoding="utf-8") as log:
        log.write(f"{datetime.datetime.now().astimezone().isoformat()} {args.fase} "
                  f"{before} {after} {env}\n")
    if args.fase == "preparar":
        prepare(before, after, args.salida)
    elif args.fase == "base":
        measure({"sin": before}, args.salida, args.corridas, "planes_exploracion.json")
    elif args.fase == "aplicar":
        log = apply(after, ROOT / "db/migrations/008_indices.sql")
        (args.salida / "aplicacion_008.log").write_text(log, encoding="utf-8")
    elif args.fase == "comparar":
        measure({"sin": before, "con": after}, args.salida, args.corridas, "planes_comparados.json")
    elif args.fase == "extras":
        extras(before, after, args.salida)
    elif args.fase == "escritura":
        write_measure({"sin": before, "con": after}, args.prefijo, args.salida, args.corridas)
    elif args.fase == "regresion":
        regression(args.prefijo, args.salida)
    elif args.fase == "integridad":
        verify_data(before, after, args.salida)
    else:
        concurrency(args.prefijo, args.salida)


if __name__ == "__main__":
    main()
