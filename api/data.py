"""SQL directo. Los valores ingresados se enlazan mediante psycopg."""
from fastapi import HTTPException
from psycopg import sql


def fila(db, consulta, args=()):
    return db.execute(consulta, args).fetchone()


def filas(db, consulta, args=()):
    return db.execute(consulta, args).fetchall()


def requerido(registro):
    if registro is None:
        raise HTTPException(404, "Recurso inexistente")
    return registro


def salud(db):
    return fila(db, "SELECT true AS ok, current_user AS rol")


def listar_vinos(db, tipo, cepa, bodega, anada, nombre, limite, offset):
    return filas(db, """
        SELECT v.* FROM vino v
        WHERE (%s::text IS NULL OR v.tipo=%s)
          AND (%s::integer IS NULL OR EXISTS (
            SELECT FROM composicion c WHERE c.cod_vino=v.cod_vino AND c.id_cepa=%s))
          AND (%s::text IS NULL OR v.cuit_bodega=%s)
          AND (%s::integer IS NULL OR v.anada=%s)
          AND (%s::text IS NULL OR strpos(lower(v.nombre), lower(%s))>0)
        ORDER BY v.cod_vino LIMIT %s OFFSET %s
    """, (tipo,tipo,cepa,cepa,bodega,bodega,anada,anada,nombre,nombre,limite,offset))


def vino(db, cod):
    registro = requerido(fila(db, "SELECT * FROM vino WHERE cod_vino=%s", (cod,)))
    registro["cepas"] = filas(db, """
        SELECT c.id_cepa,e.nombre,c.porcentaje
        FROM composicion c JOIN cepa e USING(id_cepa)
        WHERE c.cod_vino=%s ORDER BY c.id_cepa
    """, (cod,))
    registro["maridajes"] = filas(db, """
        SELECT m.* FROM vino_maridaje v JOIN maridaje m USING(id_maridaje)
        WHERE v.cod_vino=%s ORDER BY m.id_maridaje
    """, (cod,))
    return registro


def guardar_vino(db, datos, cod=None):
    valores = (datos.cuit_bodega, datos.nombre, datos.tipo, datos.anada,
               datos.volumen_ml, datos.graduacion, datos.precio)
    if cod is None:
        cod = fila(db, """INSERT INTO vino(cuit_bodega,nombre,tipo,anada,volumen_ml,graduacion,precio)
                         VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING cod_vino""", valores)["cod_vino"]
    else:
        requerido(fila(db, """UPDATE vino SET cuit_bodega=%s,nombre=%s,tipo=%s,anada=%s,
                              volumen_ml=%s,graduacion=%s,precio=%s
                              WHERE cod_vino=%s RETURNING cod_vino""", (*valores,cod)))
        db.execute("DELETE FROM composicion WHERE cod_vino=%s", (cod,))
        db.execute("DELETE FROM vino_maridaje WHERE cod_vino=%s", (cod,))
    for corte in datos.cepas:
        db.execute("INSERT INTO composicion VALUES (%s,%s,%s)", (cod,corte.id_cepa,corte.porcentaje))
    for maridaje in datos.maridajes:
        db.execute("INSERT INTO vino_maridaje VALUES (%s,%s)", (cod,maridaje))
    return vino(db, cod)


def borrar_vino(db, cod):
    # Las FK RESTRICT deciden si existen movimientos asociados.
    requerido(fila(db, "DELETE FROM vino WHERE cod_vino=%s RETURNING cod_vino", (cod,)))


def listar_clientes(db, limite, offset):
    return filas(db, "SELECT * FROM cliente ORDER BY id_cliente LIMIT %s OFFSET %s", (limite,offset))


def cliente(db, id_cliente):
    registro = requerido(fila(db, """
        SELECT c.*,d.zona_cobertura,d.nro_habilitacion,e.pais_destino
        FROM cliente c LEFT JOIN distribuidor d USING(id_cliente)
        LEFT JOIN exportador e USING(id_cliente) WHERE c.id_cliente=%s
    """, (id_cliente,)))
    if registro["tipo_cliente"] == "exportador":
        registro["permisos"] = filas(db, """SELECT cod_permiso,fecha_emision,fecha_vencimiento
            FROM permiso_exportacion WHERE id_cliente=%s ORDER BY cod_permiso""", (id_cliente,))
    return registro


def guardar_cliente(db, datos, id_cliente=None):
    valores = (datos.id_localidad, datos.nombre_o_razon_social, datos.tipo_doc,
               datos.numero_doc, datos.domicilio, datos.tipo_cliente)
    if id_cliente is None:
        id_cliente = fila(db, """INSERT INTO cliente(id_localidad,nombre_o_razon_social,
            tipo_doc,numero_doc,domicilio,tipo_cliente) VALUES (%s,%s,%s,%s,%s,%s)
            RETURNING id_cliente""", valores)["id_cliente"]
    else:
        anterior = requerido(fila(db, "SELECT tipo_cliente FROM cliente WHERE id_cliente=%s FOR UPDATE",
                                   (id_cliente,)))["tipo_cliente"]
        if anterior != datos.tipo_cliente:
            tabla = {"socio":"socio", "distribuidor":"distribuidor", "exportador":"exportador"}[anterior]
            db.execute(sql.SQL("DELETE FROM {} WHERE id_cliente=%s").format(sql.Identifier(tabla)), (id_cliente,))
        db.execute("""UPDATE cliente SET id_localidad=%s,nombre_o_razon_social=%s,tipo_doc=%s,
            numero_doc=%s,domicilio=%s,tipo_cliente=%s WHERE id_cliente=%s""", (*valores,id_cliente))
    if datos.tipo_cliente == "socio":
        db.execute("INSERT INTO socio VALUES (%s) ON CONFLICT DO NOTHING", (id_cliente,))
    elif datos.tipo_cliente == "distribuidor":
        db.execute("""INSERT INTO distribuidor VALUES (%s,%s,%s) ON CONFLICT (id_cliente)
            DO UPDATE SET zona_cobertura=excluded.zona_cobertura,nro_habilitacion=excluded.nro_habilitacion""",
                   (id_cliente,datos.zona_cobertura,datos.nro_habilitacion))
    else:
        db.execute("""INSERT INTO exportador(id_cliente,pais_destino) VALUES (%s,%s)
            ON CONFLICT (id_cliente) DO UPDATE SET pais_destino=excluded.pais_destino""",
                   (id_cliente,datos.pais_destino))
        db.execute("DELETE FROM permiso_exportacion WHERE id_cliente=%s", (id_cliente,))
        for permiso in datos.permisos:
            db.execute("""INSERT INTO permiso_exportacion(cod_permiso,id_cliente,fecha_emision,fecha_vencimiento)
                VALUES (%s,%s,%s,%s)""",
                       (permiso.cod_permiso,id_cliente,permiso.fecha_emision,permiso.fecha_vencimiento))
    return cliente(db, id_cliente)


def borrar_cliente(db, id_cliente):
    requerido(fila(db, "DELETE FROM cliente WHERE id_cliente=%s RETURNING id_cliente", (id_cliente,)))


def comprobante(db, nro):
    registro = requerido(fila(db, "SELECT * FROM comprobante WHERE nro_comprobante=%s", (nro,)))
    registro["renglones"] = filas(db, """SELECT * FROM renglon_comprobante
        WHERE nro_comprobante=%s ORDER BY cod_vino""", (nro,))
    return registro


def vender(db, datos):
    nro = fila(db, """INSERT INTO comprobante(id_cliente,id_sala) VALUES (%s,%s)
        RETURNING nro_comprobante""", (datos.id_cliente,datos.id_sala))["nro_comprobante"]
    # El orden reduce cruces de locks al vender los mismos vinos concurrentemente.
    for renglon in sorted(datos.renglones, key=lambda r: r.cod_vino):
        db.execute("""INSERT INTO renglon_comprobante(nro_comprobante,cod_vino,cantidad)
            VALUES (%s,%s,%s)""", (nro,renglon.cod_vino,renglon.cantidad))
    return comprobante(db, nro)


DOCUMENTOS = {
    "ingreso": ("cod_ingreso", "sp_terminar_ingreso", "sp_procesar_ingreso"),
    "transferencia": ("nro_solicitud", "sp_terminar_transferencia", "sp_procesar_transferencia"),
}


def documento(db, clase, nro):
    clave, _, _ = DOCUMENTOS[clase]
    return requerido(fila(db, sql.SQL("SELECT * FROM {} WHERE {}=%s").format(
        sql.Identifier(clase), sql.Identifier(clave)), (nro,)))


def crear_transferencia(db, datos):
    return fila(db, "INSERT INTO transferencia(id_sala) VALUES (%s) RETURNING *", (datos.id_sala,))


def crear_ingreso(db, datos):
    return fila(db, """INSERT INTO ingreso(cuit_bodega,cod_transportista) VALUES (%s,%s)
        RETURNING *""", (datos.cuit_bodega,datos.cod_transportista))


def cargar_renglon(db, clase, nro, datos):
    clave, _, _ = DOCUMENTOS[clase]
    return fila(db, sql.SQL("INSERT INTO {} ({},cod_vino,cantidad) VALUES (%s,%s,%s) RETURNING *").format(
        sql.Identifier("renglon_" + clase), sql.Identifier(clave)), (nro,datos.cod_vino,datos.cantidad))


def cambiar_estado(db, clase, nro, procesar):
    _, terminar, procesar_sp = DOCUMENTOS[clase]
    documento(db, clase, nro)
    db.execute(sql.SQL("CALL {}(%s)").format(sql.Identifier(procesar_sp if procesar else terminar)), (nro,))
    return documento(db, clase, nro)


def top_vinos(db):
    return filas(db, """SELECT v.cod_vino,v.nombre,sum(r.cantidad) botellas
        FROM vino v JOIN renglon_comprobante r USING(cod_vino)
        GROUP BY v.cod_vino ORDER BY botellas DESC,v.cod_vino LIMIT 10""")


def ventas_por_sala(db):
    return filas(db, """SELECT s.id_sala,coalesce(sum(c.total),0) total
        FROM sala_venta s LEFT JOIN comprobante c ON c.id_sala=s.id_sala
          AND c.fecha BETWEEN CURRENT_DATE-interval '3 months' AND CURRENT_DATE
        GROUP BY s.id_sala ORDER BY total DESC,s.id_sala""")


def vinos_sin_stock(db, sala, limite, offset):
    requerido(fila(db, "SELECT id_sala FROM sala_venta WHERE id_sala=%s", (sala,)))
    return filas(db, """SELECT v.cod_vino,v.nombre,d.cantidad FROM stock_deposito d
        JOIN vino v USING(cod_vino) LEFT JOIN stock_sala s ON s.cod_vino=d.cod_vino AND s.id_sala=%s
        WHERE d.cantidad>0 AND coalesce(s.cantidad,0)=0 ORDER BY v.cod_vino LIMIT %s OFFSET %s""",
                 (sala,limite,offset))


def transportista_activo(db):
    return filas(db, """SELECT t.cod_transportista,t.razon_social,count(*) ingresos
        FROM transportista t JOIN ingreso i USING(cod_transportista)
        WHERE i.fecha BETWEEN CURRENT_DATE-interval '1 month' AND CURRENT_DATE
        GROUP BY t.cod_transportista ORDER BY ingresos DESC FETCH FIRST 1 ROW WITH TIES""")


def trazabilidad(db, cod, limite, offset):
    registro = vino(db, cod)
    registro["stock"] = fila(db, "SELECT * FROM v_stock_total_vino WHERE cod_vino=%s", (cod,))
    registro["ingresos"] = filas(db, """SELECT i.*,r.cantidad FROM ingreso i
        JOIN renglon_ingreso r USING(cod_ingreso) WHERE r.cod_vino=%s
        ORDER BY i.cod_ingreso LIMIT %s OFFSET %s""", (cod,limite,offset))
    registro["transferencias"] = filas(db, """SELECT t.*,r.cantidad FROM transferencia t
        JOIN renglon_transferencia r USING(nro_solicitud) WHERE r.cod_vino=%s
        ORDER BY t.nro_solicitud LIMIT %s OFFSET %s""", (cod,limite,offset))
    registro["ventas"] = filas(db, """SELECT c.nro_comprobante,c.fecha,c.id_sala,r.cantidad
        FROM comprobante c JOIN renglon_comprobante r USING(nro_comprobante) WHERE r.cod_vino=%s
        ORDER BY c.nro_comprobante LIMIT %s OFFSET %s""", (cod,limite,offset))
    return registro
