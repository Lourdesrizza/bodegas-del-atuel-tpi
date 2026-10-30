"""Regenera esquema, diccionario y diagramas drawio desde la base migrada."""
import os
import pathlib
import subprocess
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(__file__).resolve().parent
BIN = pathlib.Path(os.environ.get("PG_BIN", r"C:\Program Files\PostgreSQL\18\bin"))
DB = os.environ.get("PGDATABASE", "atuel_regresion5_test")
args = [str(BIN / "psql.exe"), "-X", "-v", "ON_ERROR_STOP=1", "-h",
        os.environ.get("PGHOST", "127.0.0.1"), "-p", os.environ.get("PGPORT", "55440"),
        "-U", os.environ.get("PGUSER", "atuel_admin"), "-d", DB, "-At", "-F", "|"]

def query(sql):
    out = subprocess.run([*args, "-c", sql], text=True, capture_output=True, check=True).stdout
    return [line.split("|") for line in out.splitlines() if line]

cols = query("""SELECT table_name,column_name,data_type,COALESCE(character_maximum_length::text,''),
numeric_precision::text,COALESCE(numeric_scale::text,''),is_nullable,COALESCE(column_default,''),COALESCE(domain_name,'')
FROM information_schema.columns WHERE table_schema='public'
AND table_name IN (SELECT tablename FROM pg_tables WHERE schemaname='public')
ORDER BY table_name,ordinal_position""")
rels = query("""SELECT c.conrelid::regclass::text,a.attname,c.confrelid::regclass::text,b.attname,c.contype
FROM pg_constraint c JOIN LATERAL unnest(c.conkey,c.confkey) WITH ORDINALITY AS k(src,dst,ord) ON true
JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=k.src
JOIN pg_attribute b ON b.attrelid=c.confrelid AND b.attnum=k.dst
WHERE c.contype='f' AND c.connamespace='public'::regnamespace ORDER BY 1,2""")
pks = query("""SELECT c.conrelid::regclass::text,a.attname FROM pg_constraint c
JOIN LATERAL unnest(c.conkey) AS k(num) ON true
JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=k.num
WHERE c.contype='p' AND c.connamespace='public'::regnamespace ORDER BY 1,2""")
pkset = {(t,c) for t,c in pks}
fkmap = {(t,c):(ref,rc) for t,c,ref,rc,_ in rels}
tables = {}
for row in cols:
    tables.setdefault(row[0],[]).append(row)

def dtype(r):
    _,_,dt,ln,prec,scale,_,_,domain = r
    if domain: return domain
    if dt in ("character varying","character"):
        return ("VARCHAR" if dt=="character varying" else "CHAR")+f"({ln})"
    if dt=="numeric": return f"NUMERIC({prec},{scale})"
    if dt=="USER-DEFINED": return "estado_documento"
    if dt=="cuit_dom": return "cuit_dom"
    return dt.upper()

def desc(t,c):
    if (t,c) in fkmap:
        ref,rc=fkmap[(t,c)]; return f"Referencia a {ref}.{rc}."
    if (t,c) in pkset: return f"Identificador de {t}."
    names={"cantidad":"Botellas o unidades registradas.","precio":"Precio vigente del catálogo.",
           "precio_unitario":"Precio histórico capturado al vender.",
           "descuento_aplicado":"Porcentaje histórico aplicado al renglón.",
           "subtotal_renglon":"Importe neto redondeado del renglón.",
           "subtotal":"Suma bruta de los renglones.","descuento":"Descuento calculado o porcentaje del tipo.",
           "total":"Suma de importes netos redondeados.","estado":"Estado controlado del documento.",
           "porcentaje":"Participación de la cepa en el corte.",
           "fecha_confeccion":"Fecha actual fijada al crear la transferencia."}
    return names.get(c,f"{c.replace('_',' ').capitalize()} de {t}.")

schema=["# Esquema relacional revisado", "", "Fuente: migraciones 001–007 aplicadas en PostgreSQL. PK y FK se indican por columna.", ""]
dictionary=["# Diccionario de datos revisado", "", "Generado desde `pg_catalog` e `information_schema` con `docs/generar_modelado.py`. Nulabilidad y tipos corresponden a la base migrada.", ""]
for t,rows in tables.items():
    fields=[]
    dictionary += [f"## {t}","", "| Columna | Tipo | Nulo | Restricción | Descripción |", "|---|---|---|---|---|"]
    for r in rows:
        _,c,_,_,_,_,nullable,default,_=r
        tags=[]
        if (t,c) in pkset: tags.append("PK")
        if (t,c) in fkmap: tags.append("FK → "+".".join(fkmap[(t,c)]))
        if default: tags.append("DEFAULT "+default.replace("|","/"))
        fields.append(c+" "+dtype(r)+(" ["+", ".join(tags)+"]" if tags else ""))
        dictionary.append(f"| {c} | {dtype(r)} | {'sí' if nullable=='YES' else 'no'} | {'; '.join(tags)} | {desc(t,c)} |")
    schema += [f"**{t}**("+"; ".join(fields)+")",""]
    dictionary.append("")
schema += ["## Relaciones", ""]
schema += [f"- {t}.{c} → {ref}.{rc}" for t,c,ref,rc,_ in rels]
(OUT/"esquema_relacional_revisado.md").write_text("\n".join(schema),encoding="utf-8")
(OUT/"diccionario_datos_revisado.md").write_text("\n".join(dictionary),encoding="utf-8")

def drawio(path, detailed):
    root=ET.Element("mxfile",host="app.diagrams.net")
    diagram=ET.SubElement(root,"diagram",name="Modelo revisado")
    model=ET.SubElement(diagram,"mxGraphModel",dx="1600",dy="1200",grid="1",gridSize="10",page="1",pageWidth="2800",pageHeight="2200")
    parent=ET.SubElement(model,"root")
    ET.SubElement(parent,"mxCell",id="0")
    ET.SubElement(parent,"mxCell",id="1",parent="0")
    ids={}
    for i,(t,rows) in enumerate(tables.items()):
        ids[t]=str(i+2)
        detail="<br/>".join(("PK " if (t,r[1]) in pkset else "FK " if (t,r[1]) in fkmap else "")+r[1]+(" : "+dtype(r) if detailed else "") for r in rows)
        val="<b>"+t+"</b><br/>"+detail
        cell=ET.SubElement(parent,"mxCell",id=ids[t],value=val,style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;align=left;spacing=8;",vertex="1",parent="1")
        ET.SubElement(cell,"mxGeometry",x=str(30+(i%5)*540),y=str(30+(i//5)*370),width="470",height=str(max(90,35+len(rows)*21)),**{"as":"geometry"})
    for i,(t,c,ref,rc,_) in enumerate(rels):
        cell=ET.SubElement(parent,"mxCell",id="e"+str(i),value=c+" → "+rc,style="endArrow=block;html=1;edgeStyle=orthogonalEdgeStyle;rounded=1;strokeColor=#6c8ebf;",edge="1",parent="1",source=ids[t],target=ids[ref])
        ET.SubElement(cell,"mxGeometry",relative="1",**{"as":"geometry"})
    ET.ElementTree(root).write(path,encoding="utf-8",xml_declaration=True)

drawio(OUT/"DER_revisado.drawio",False)
drawio(OUT/"diagramarelacional_revisado.drawio",True)
print(f"{len(tables)} tablas, {len(cols)} columnas, {len(rels)} relaciones")
