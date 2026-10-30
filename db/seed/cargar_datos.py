"""Carga ficticia reproducible de la etapa 3 en una base nueva *_test o *_dev."""
import argparse
import csv
import hashlib
import os
import pathlib
import random
import re
import time
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal

import psycopg
from faker import Faker

ROOT = pathlib.Path(__file__).resolve().parents[2]
CAT = pathlib.Path(__file__).resolve().parent / "catalogos"
SEED = 20261029
REFERENCIA = date(2026, 10, 28)
VENTA_INICIO = date(2025, 4, 1)


def catalogo(nombre):
    with (CAT / nombre).open(encoding="utf-8-sig", newline="") as archivo:
        return list(csv.DictReader(archivo))


def copiar(conn, tabla, columnas, filas):
    # Los nombres son constantes del programa; psycopg adapta los valores de COPY.
    with conn.cursor() as cur:
        with cur.copy(f"COPY {tabla} ({', '.join(columnas)}) FROM STDIN") as copia:
            for fila in filas:
                copia.write_row(fila)


def medir_metodos(conn):
    muestra = [(n, f"fila-{n:04d}") for n in range(1000)]
    conn.execute("CREATE TEMP TABLE muestra_carga (n integer, texto text) ON COMMIT DROP")
    inicio = time.perf_counter()
    with conn.cursor() as cur:
        for fila in muestra:
            cur.execute("INSERT INTO muestra_carga VALUES (%s,%s)", fila)
    individual = time.perf_counter() - inicio
    conn.execute("TRUNCATE muestra_carga")
    inicio = time.perf_counter()
    copiar(conn, "muestra_carga", ("n", "texto"), muestra)
    lote = time.perf_counter() - inicio
    if conn.execute("SELECT count(*) FROM muestra_carga").fetchone()[0] != len(muestra):
        raise RuntimeError("Falló la comparación de métodos")
    return individual, lote


def comprobar_base_vacia(conn):
    tablas = [r[0] for r in conn.execute(
        "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")]
    if len(tablas) != 30:
        raise RuntimeError(f"Se esperaban 30 tablas del esquema actual; hay {len(tablas)}")
    for tabla in tablas:
        if tabla != "tipo_cliente" and conn.execute(f'SELECT EXISTS(SELECT 1 FROM "{tabla}")').fetchone()[0]:
            raise RuntimeError(f"La base no está vacía: {tabla}. Se rechaza la repetición")
    if conn.execute("SELECT count(*) FROM tipo_cliente").fetchone()[0] != 3:
        raise RuntimeError("El catálogo tipo_cliente de la migración no coincide")


def huella(conn):
    """Hash de filas reales; excluye fecha_hora/usuario de la auditoría de ejecución."""
    h = hashlib.sha256()
    tablas = [r[0] for r in conn.execute(
        "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")]
    for tabla in tablas:
        h.update((tabla + "\n").encode())
        cols = [r[0] for r in conn.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema='public' AND table_name=%s ORDER BY ordinal_position", (tabla,))]
        if tabla == "auditoria_precio":
            cols = [c for c in cols if c not in ("fecha_hora", "usuario")]
        claves = [r[0] for r in conn.execute("""
            SELECT a.attname FROM pg_constraint k
            JOIN LATERAL unnest(k.conkey) WITH ORDINALITY u(num, orden) ON true
            JOIN pg_attribute a ON a.attrelid=k.conrelid AND a.attnum=u.num
            WHERE k.contype='p' AND k.conrelid=%s::regclass ORDER BY u.orden
        """, (tabla,))]
        consulta = f"COPY (SELECT {', '.join(cols)} FROM {tabla} ORDER BY {', '.join(claves)}) TO STDOUT"
        with conn.cursor() as cur:
            with cur.copy(consulta) as copia:
                for bloque in copia:
                    h.update(bloque)
    return h.hexdigest()


def cargar(conn, modo):
    rnd = random.Random(SEED)
    fake = Faker("es_AR")
    fake.seed_instance(SEED)
    locs = catalogo("localidades.csv")
    cepas = catalogo("cepas.csv")
    maridajes = catalogo("maridajes.csv")
    departamentos = catalogo("departamentos.csv")
    tipos_vino = [r["tipo"] for r in catalogo("tipos_vino.csv")]
    if len(locs) != 20 or len(cepas) != 12 or len(maridajes) != 8 or len(departamentos) != 18 or len(tipos_vino) != 4:
        raise RuntimeError("Los catálogos no tienen el tamaño esperado")

    if modo == "completa":
        salas, fincas, parcelas, bodegas, vinos = 25, 20, 600, 20, 600
        transportes, clientes, ventas, populares, repeticiones = 30, 20000, 150000, 100, 5
        campanias = range(2020, 2025)
    else:
        salas, fincas, parcelas, bodegas, vinos = 5, 3, 12, 3, 12
        transportes, clientes, ventas, populares, repeticiones = 3, 50, 30, 8, 2
        campanias = range(2023, 2025)

    tiempos = {}
    inicio = time.perf_counter()
    individual, lote = medir_metodos(conn)
    tiempos["comparacion_fila_1000_s"] = round(individual, 3)
    tiempos["comparacion_copy_1000_s"] = round(lote, 3)

    def fase(nombre, funcion):
        ahora = time.perf_counter()
        funcion()
        tiempos[nombre + "_s"] = round(time.perf_counter() - ahora, 3)

    # Raíces y catálogos: nombres reales sólo desde CSV; responsables ficticios.
    fase("catalogos", lambda: (
        copiar(conn, "localidad", ("id_localidad", "codigo_postal", "nombre", "provincia", "encargado_regional"),
               ((i, r["codigo_postal"], r["nombre"], r["provincia"], fake.name()) for i, r in enumerate(locs, 1))),
        copiar(conn, "cepa", ("id_cepa", "nombre", "tipo"),
               ((i, r["nombre"], r["tipo"]) for i, r in enumerate(cepas, 1))),
        copiar(conn, "maridaje", ("id_maridaje", "nombre", "temperatura_servicio"),
               ((i, r["nombre"], r["temperatura_servicio"]) for i, r in enumerate(maridajes, 1)))))

    def cuit_bodega(i):
        return f"30{100000000+i:09d}"

    def cuit_transporte(i):
        return f"31{100000000+i:09d}"

    def cuit_empleado(i):
        return f"20{100000000+i:09d}"
    fase("maestros", lambda: (
        copiar(conn, "sala_venta", ("id_sala", "id_localidad", "calle", "numero", "dia_cierre"),
               ((i, (i-1) % len(locs)+1, "Calle Ficticia", str(100+i), ["Lunes", "Miércoles", "Domingo"][i % 3]) for i in range(1, salas+1))),
        copiar(conn, "empleado", ("cuit", "id_sala", "nombre", "fecha_ingreso", "salario"),
               ((cuit_empleado(i), (i-1) % salas+1, fake.name(), date(2020, 1, 1)+timedelta(days=i), 500000+i*100) for i in range(1, salas*2+1))),
        copiar(conn, "finca", ("id_finca", "nombre", "superficie_ha", "departamento", "provincia"),
               ((i, f"Finca Ficticia {i}", 300, departamentos[(i-1)%len(departamentos)]["nombre"], "Mendoza") for i in range(1, fincas+1))),
        copiar(conn, "bodega", ("cuit", "razon_social", "domicilio"),
               ((cuit_bodega(i), f"Bodega Ficticia {i} SA", f"Ruta ficticia {i}") for i in range(1, bodegas+1))),
        copiar(conn, "transportista", ("cod_transportista", "cuit", "razon_social", "domicilio", "email", "telefono"),
               ((i, cuit_transporte(i), f"Transporte Ficticio {i} SRL", f"Calle ficticia {i}", f"t{i}@example.invalid", f"260400{i:04d}") for i in range(1, transportes+1))),
        copiar(conn, "transportista_localidad", ("cod_transportista", "id_localidad"),
               ((i, (i*2+j-2)%len(locs)+1) for i in range(1, transportes+1) for j in (0,1)))))

    # Cada parcela tiene hasta cinco campañas, sin duplicar (finca, parcela, año).
    parcela_finca = {i: (i-1) % fincas+1 for i in range(1, parcelas+1)}
    parcela_numero = {i: (i-1) // fincas+1 for i in range(1, parcelas+1)}
    fase("produccion", lambda: (
        copiar(conn, "parcela", ("id_finca", "nro_parcela", "id_cepa", "superficie", "anio_plantacion"),
               ((parcela_finca[i], parcela_numero[i], (i-1)%len(cepas)+1, 5, 2010+i%10) for i in range(1, parcelas+1))),
        copiar(conn, "lote_uva", ("nro_lote", "id_finca", "nro_parcela", "cuit_bodega", "campania", "fecha_cosecha", "kilos"),
               ((n, parcela_finca[i], parcela_numero[i], cuit_bodega((i-1)%bodegas+1), anio,
                 date(anio, 2, 1)+timedelta(days=(i+n)%80), 1000+(i%100)*10)
                for n, (i, anio) in enumerate(((i, anio) for anio in campanias for i in range(1, parcelas+1)), 1))),
        copiar(conn, "analisis_calidad", ("id_analisis", "nro_lote", "fecha", "brix", "ph", "acidez_total"),
               ((n, n, date(anio, 2, 1)+timedelta(days=(i+n)%80+5), 21, 3.5, 5)
                for n, (i, anio) in enumerate(((i, anio) for anio in campanias for i in range(1, parcelas+1)), 1)))))

    vinos_por_bodega = vinos // bodegas
    def bodega_de_vino(i):
        return (i-1)//vinos_por_bodega+1

    def precio(i):
        return 1000+i*7+(1 if i==1 else 0)
    fase("vinos", lambda: (
        copiar(conn, "vino", ("cod_vino", "cuit_bodega", "nombre", "tipo", "anada", "volumen_ml", "graduacion", "precio"),
               ((i, cuit_bodega(bodega_de_vino(i)), f"Vino Ficticio {i:04d}", tipos_vino[(i-1)%4], 2023+i%2, 750, 12+i%5, 1000+i*7)
                for i in range(1, vinos+1))),
        copiar(conn, "composicion", ("cod_vino", "id_cepa", "porcentaje"),
               ((i, (i-1)%len(cepas)+1, 100) for i in range(1, vinos+1))),
        copiar(conn, "vino_maridaje", ("cod_vino", "id_maridaje"),
               ((i, (i-1)%len(maridajes)+1) for i in range(1, vinos+1)))))
    # El cambio real de precio crea auditoría; sus datos de ejecución se excluyen de la huella.
    conn.execute("UPDATE vino SET precio=precio+1 WHERE cod_vino=1")

    def tipo_cliente(i):
        if i % 20 < 12:
            return "socio"
        if i % 20 < 17:
            return "distribuidor"
        return "exportador"

    def numero_doc(i):
        return f"{10000000+i:08d}" if tipo_cliente(i)=="socio" else f"30{200000000+i:09d}"
    descuento = {"socio":10, "distribuidor":20, "exportador":30}
    fase("clientes", lambda: (
        copiar(conn, "cliente", ("id_cliente", "id_localidad", "nombre_o_razon_social", "tipo_doc", "numero_doc", "domicilio", "fecha_alta", "tipo_cliente"),
               ((i, (i-1)%len(locs)+1, fake.name() if tipo_cliente(i)=="socio" else fake.company(),
                 "DNI" if tipo_cliente(i)=="socio" else "CUIT", numero_doc(i), f"Calle ficticia {i}",
                 date(2022,1,1)+timedelta(days=i%1000), tipo_cliente(i)) for i in range(1, clientes+1))),
        copiar(conn, "socio", ("id_cliente",), ((i,) for i in range(1, clientes+1) if tipo_cliente(i)=="socio")),
        copiar(conn, "distribuidor", ("id_cliente", "zona_cobertura", "nro_habilitacion"),
               ((i, "Mendoza", f"HAB-{i:06d}") for i in range(1, clientes+1) if tipo_cliente(i)=="distribuidor")),
        copiar(conn, "exportador", ("id_cliente", "pais_destino"),
               ((i, "Chile") for i in range(1, clientes+1) if tipo_cliente(i)=="exportador")),
        copiar(conn, "permiso_exportacion", ("cod_permiso", "id_cliente", "fecha_emision", "fecha_vencimiento"),
               ((f"PERM-{i:06d}", i, date(2024,1,1), date(2028,1,1))
                for i in range(1, clientes+1) if tipo_cliente(i)=="exportador"))))

    # Plan de ventas primero: permite abastecer exactamente cada sala y evitar stock negativo.
    cabeceras, renglones = [], []
    demanda = defaultdict(int)
    for nro in range(1, ventas+1):
        sala = (nro-1)%salas+1
        cliente = rnd.randint(1, clientes)
        fecha = VENTA_INICIO + timedelta(days=rnd.randrange((REFERENCIA-VENTA_INICIO).days+1))
        vinos_venta = rnd.sample(range(1, populares+1), 3+(modo=="completa" and nro<=50000))
        bruto = neto_centavos = 0
        for vino in vinos_venta:
            cantidad = rnd.randint(1,3)
            precio_vino = precio(vino)
            bruto_renglon = cantidad*precio_vino
            centavos_renglon = bruto_renglon*(100-descuento[tipo_cliente(cliente)])
            bruto += bruto_renglon
            neto_centavos += centavos_renglon
            demanda[(sala,vino)] += cantidad
            renglones.append((nro,vino,cantidad,precio_vino,descuento[tipo_cliente(cliente)],Decimal(centavos_renglon)/100))
        cabeceras.append((nro,cliente,sala,fecha,bruto,Decimal(bruto*100-neto_centavos)/100,Decimal(neto_centavos)/100))
    del rnd, fake

    # Un traslado por cada par sala-vino popular, y 500 renglones extra de vinos de baja rotación.
    transferencias = []
    for sala in range(1,salas+1):
        for vino in range(1,populares+1):
            transferencias.append((sala,vino,demanda[(sala,vino)]+10))
    for vino in range(populares+1,vinos+1):
        transferencias.append((1,vino,10))
    transferencias.sort()
    total_transferido = defaultdict(int)
    for _,vino,cantidad in transferencias:
        total_transferido[vino] += cantidad

    # Cinco ingresos por vino en carga completa; todos posteriores a las cosechas 2024.
    ingresos, lineas_ingreso = [], []
    nro_ingreso = 0
    for bodega in range(1,bodegas+1):
        vinos_bodega = list(range((bodega-1)*vinos_por_bodega+1,bodega*vinos_por_bodega+1))
        for repeticion in range(repeticiones):
            for pos in range(0,len(vinos_bodega),5):
                nro_ingreso += 1
                ingresos.append((nro_ingreso,cuit_bodega(bodega),(nro_ingreso-1)%transportes+1,date(2025,1,15)))
                for vino in vinos_bodega[pos:pos+5]:
                    total = total_transferido[vino]+50
                    cantidad = total//repeticiones+(repeticion<total%repeticiones)
                    lineas_ingreso.append((nro_ingreso,vino,cantidad))

    fase("ingresos", lambda: (
        copiar(conn, "ingreso", ("cod_ingreso", "cuit_bodega", "cod_transportista", "fecha"), ingresos),
        copiar(conn, "renglon_ingreso", ("cod_ingreso", "cod_vino", "cantidad"), lineas_ingreso)))
    inicio_proc = time.perf_counter()
    for ingreso in ingresos:
        conn.execute("CALL sp_terminar_ingreso(%s)", (ingreso[0],))
        conn.execute("CALL sp_procesar_ingreso(%s)", (ingreso[0],))
    tiempos["procesar_ingresos_s"] = round(time.perf_counter()-inicio_proc,3)

    docs_transferencia, lineas_transferencia = [], []
    nro_transferencia = 0
    for sala in range(1,salas+1):
        items = [(vino,cant) for s,vino,cant in transferencias if s==sala]
        for pos in range(0,len(items),5):
            nro_transferencia += 1
            docs_transferencia.append((nro_transferencia,sala,date(2025,3,1)))
            lineas_transferencia.extend((nro_transferencia,vino,cant) for vino,cant in items[pos:pos+5])
    # Sólo este trigger sustituye la fecha histórica por CURRENT_DATE; DDL transaccional.
    conn.execute("ALTER TABLE transferencia DISABLE TRIGGER trg_fecha_transferencia")
    fase("transferencias", lambda: (
        copiar(conn, "transferencia", ("nro_solicitud", "id_sala", "fecha_confeccion"), docs_transferencia),
        copiar(conn, "renglon_transferencia", ("nro_solicitud", "cod_vino", "cantidad"), lineas_transferencia)))
    conn.execute("ALTER TABLE transferencia ENABLE TRIGGER trg_fecha_transferencia")
    inicio_proc = time.perf_counter()
    for transferencia in docs_transferencia:
        conn.execute("CALL sp_terminar_transferencia(%s)", (transferencia[0],))
        conn.execute("CALL sp_procesar_transferencia(%s)", (transferencia[0],))
    tiempos["procesar_transferencias_s"] = round(time.perf_counter()-inicio_proc,3)

    # La historia fue calculada con el mismo precio/descuento del motor. Se evitan
    # 500.000 recálculos fila a fila; sólo se suspenden los dos triggers de INSERT.
    conn.execute("ALTER TABLE renglon_comprobante DISABLE TRIGGER trg_valida_stock_renglon")
    conn.execute("ALTER TABLE renglon_comprobante DISABLE TRIGGER trg_descuenta_stock_actualiza_totales")
    fase("ventas", lambda: (
        copiar(conn, "comprobante", ("nro_comprobante", "id_cliente", "id_sala", "fecha", "subtotal", "descuento", "total"), cabeceras),
        copiar(conn, "renglon_comprobante", ("nro_comprobante", "cod_vino", "cantidad", "precio_unitario", "descuento_aplicado", "subtotal_renglon"), renglones)))
    conn.execute("ALTER TABLE renglon_comprobante ENABLE TRIGGER trg_valida_stock_renglon")
    conn.execute("ALTER TABLE renglon_comprobante ENABLE TRIGGER trg_descuenta_stock_actualiza_totales")
    conn.execute("CREATE TEMP TABLE demanda_venta (id_sala integer,cod_vino integer,cantidad integer) ON COMMIT DROP")
    copiar(conn,"demanda_venta",("id_sala","cod_vino","cantidad"),
           ((s,v,c) for (s,v),c in sorted(demanda.items())))
    conn.execute("UPDATE stock_sala s SET cantidad=s.cantidad-d.cantidad FROM demanda_venta d "
                 "WHERE s.id_sala=d.id_sala AND s.cod_vino=d.cod_vino")
    del cabeceras, renglones

    # Secuencias listas para nuevas operaciones tras cargar claves explícitas.
    for tabla,columna in (("localidad","id_localidad"),("sala_venta","id_sala"),("finca","id_finca"),
                          ("cepa","id_cepa"),("lote_uva","nro_lote"),("analisis_calidad","id_analisis"),
                          ("vino","cod_vino"),("maridaje","id_maridaje"),("cliente","id_cliente"),
                          ("transportista","cod_transportista"),("ingreso","cod_ingreso"),
                          ("transferencia","nro_solicitud"),("comprobante","nro_comprobante")):
        conn.execute(f"SELECT setval(pg_get_serial_sequence('{tabla}','{columna}'), "
                     f"(SELECT max({columna}) FROM {tabla}), true)")
    conn.execute("SET CONSTRAINTS ALL IMMEDIATE")
    conn.execute("SELECT set_config('atuel.carga_modo', %s, true)", (modo,))
    controles = conn.execute((ROOT/"db/seed/validar_carga.sql").read_text(encoding="utf-8")).fetchall()
    fallos = [(n,c) for n,c in controles if c]
    if fallos:
        raise RuntimeError(f"Controles fallidos: {fallos}")
    conn.execute("REFRESH MATERIALIZED VIEW mv_ventas_mensuales_sala")
    tiempos["total_s"] = round(time.perf_counter()-inicio,3)
    return tiempos, controles, huella(conn)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modo", choices=("pequena","completa"), required=True)
    parser.add_argument("--reporte", help="Ruta de un log de resultados sin credenciales")
    args = parser.parse_args()
    db = os.environ.get("PGDATABASE", "")
    if not re.fullmatch(r"[a-z0-9_]+_(test|dev)", db):
        raise SystemExit("PGDATABASE debe identificar una base exclusiva terminada en _test o _dev")
    inicio = datetime.now()
    with psycopg.connect(dbname=db) as conn:
        comprobar_base_vacia(conn)
        conn.execute("SET ROLE app_owner")
        try:
            reloj = time.perf_counter()
            tiempos, controles, digest = cargar(conn,args.modo)
            antes_commit = time.perf_counter()
            conn.commit()
            tiempos["confirmacion_s"] = round(time.perf_counter()-antes_commit,3)
            tiempos["ejecucion_total_s"] = round(time.perf_counter()-reloj,3)
        except Exception:
            conn.rollback()  # También revierte DISABLE TRIGGER.
            raise
    lineas = [f"modo={args.modo} base={db} inicio={inicio.isoformat(timespec='seconds')}"]
    for nombre, segundos in tiempos.items():
        lineas.append(f"{nombre}={segundos}")
    for nombre, fallos in controles:
        lineas.append(f"control {nombre}={fallos}")
    lineas.extend((f"huella_sin_auditoria_runtime={digest}","carga confirmada"))
    salida = "\n".join(lineas)+"\n"
    if args.reporte:
        destino = pathlib.Path(args.reporte)
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_text(salida,encoding="utf-8")
    print(salida,end="")


if __name__ == "__main__":
    main()
