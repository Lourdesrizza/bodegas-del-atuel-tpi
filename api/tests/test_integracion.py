"""Pruebas HTTP sobre el Compose de laboratorio, con inspección como app_rw."""
import json
import os
import unittest
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from uuid import uuid4

import psycopg


def http(method, path, payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    request = Request("http://127.0.0.1:8000" + path, data=body, method=method,
                      headers={"Content-Type": "application/json"})
    try:
        response = urlopen(request, timeout=10)
    except HTTPError as error:
        response = error
    with response:
        raw = response.read()
        return response.status, json.loads(raw) if raw else None


class Integracion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.environ["API_DB_NAME"] != "atuel_api_test":
            raise RuntimeError("Usar exclusivamente el Compose descartable de etapa 6")
        cls.db = psycopg.connect(
            host=os.environ["API_DB_HOST"], port=os.environ["API_DB_PORT"],
            dbname=os.environ["API_DB_NAME"], user="app_rw",
            password=os.environ["API_DB_PASSWORD"], autocommit=True,
        )
        cls.addClassCleanup(cls.db.close)
        cls.marca = uuid4().hex[:10]
        cls.cuit = str(int(uuid4().hex[:10],16) % 10**11).zfill(11)
        cls.loc = cls.escalar("""INSERT INTO localidad(codigo_postal,nombre,provincia,encargado_regional)
            VALUES ('5600',%s,'Mendoza','Prueba') RETURNING id_localidad""", (cls.marca,))
        cls.sala = cls.escalar("""INSERT INTO sala_venta(id_localidad,calle,numero,dia_cierre)
            VALUES (%s,'Prueba','1','Lunes') RETURNING id_sala""", (cls.loc,))
        cls.db.execute("INSERT INTO bodega VALUES (%s,%s,'Prueba')", (cls.cuit,cls.marca))
        cls.cepa = cls.escalar("INSERT INTO cepa(nombre,tipo) VALUES (%s,'tinta') RETURNING id_cepa",
                              (cls.marca,))
        cls.transporte = cls.escalar("""INSERT INTO transportista(cuit,razon_social,domicilio,email,telefono)
            VALUES (%s,%s,'Prueba','prueba@example.invalid','123') RETURNING cod_transportista""",
                                    (cls.cuit,cls.marca))
        cls.vinos = []
        for suffix in ("primero","segundo"):
            status, vino = http("POST", "/vinos", cls.vino(suffix))
            if status != 201:
                raise AssertionError((status,vino))
            cls.vinos.append(vino["cod_vino"])
        with cls.db.transaction():
            ingreso = cls.escalar("""INSERT INTO ingreso(cuit_bodega,cod_transportista)
                VALUES (%s,%s) RETURNING cod_ingreso""", (cls.cuit,cls.transporte))
            cls.db.execute("INSERT INTO renglon_ingreso VALUES (%s,%s,20)", (ingreso,cls.vinos[0]))
            cls.db.execute("CALL sp_terminar_ingreso(%s)", (ingreso,))
            cls.db.execute("CALL sp_procesar_ingreso(%s)", (ingreso,))
            transferencia = cls.escalar("INSERT INTO transferencia(id_sala) VALUES (%s) RETURNING nro_solicitud",
                                       (cls.sala,))
            cls.db.execute("INSERT INTO renglon_transferencia VALUES (%s,%s,10)", (transferencia,cls.vinos[0]))
            cls.db.execute("CALL sp_terminar_transferencia(%s)", (transferencia,))
            cls.db.execute("CALL sp_procesar_transferencia(%s)", (transferencia,))

    @classmethod
    def escalar(cls, sql, args=()):
        return cls.db.execute(sql,args).fetchone()[0]

    @classmethod
    def vino(cls, sufijo, **cambios):
        return {"cuit_bodega":cls.cuit, "nombre":f"{cls.marca}-{sufijo}", "tipo":"tinto",
                "anada":2024, "volumen_ml":750, "graduacion":"13", "precio":"100.00",
                "cepas":[{"id_cepa":cls.cepa,"porcentaje":"100"}], **cambios}

    def alta_cliente(self, **cambios):
        cuerpo = {"id_localidad":self.loc,"nombre_o_razon_social":"Cliente API",
                  "tipo_doc":"DNI","numero_doc":uuid4().hex[:10],"domicilio":"Prueba",
                  "tipo_cliente":"socio",**cambios}
        status, cliente = http("POST","/clientes",cuerpo)
        self.assertEqual(status,201,cliente)
        return cliente["id_cliente"], cuerpo

    def test_salud_y_openapi(self):
        self.assertEqual(http("GET","/salud"),(200,{"ok":True,"rol":"app_rw"}))
        status, schema = http("GET","/openapi.json")
        self.assertEqual(status,200)
        self.assertIn("post",schema["paths"]["/ingresos/{cod}/terminar"])
        self.assertIn("get",schema["paths"]["/reportes/trazabilidad/{cod}"])

    def test_filtros_y_paginacion(self):
        filtros = urlencode(dict(tipo="tinto",cepa=self.cepa,bodega=self.cuit,anada=2024,limite=1))
        a = http("GET",f"/vinos?{filtros}")[1]
        b = http("GET",f"/vinos?{filtros}&offset=1")[1]
        self.assertEqual([a[0]["cod_vino"],b[0]["cod_vino"]],self.vinos)
        self.assertEqual(http("GET","/vinos?limite=101")[0],422)

    def test_inyeccion(self):
        cuenta = self.escalar("SELECT count(*) FROM vino")
        path = "/vinos?" + urlencode({"nombre":"' OR 1=1; DROP TABLE vino; --"})
        result = http("GET",path)
        self.assertEqual(result,(200,[]))
        despues = self.escalar("SELECT count(*) FROM vino")
        self.assertEqual(cuenta,despues)
        print(f"Inyección: GET {path} -> {result}; filas vino antes={cuenta}, después={despues}",flush=True)

    def test_precio_negativo_422(self):
        status, respuesta = http("POST","/vinos",self.vino("negativo",precio="-1"))
        self.assertEqual((status,respuesta["detail"]),(422,"Un valor incumple una restricción de la base"))

    def test_constraint_diferido_y_auditoria(self):
        mal = self.vino("corte",cepas=[{"id_cepa":self.cepa,"porcentaje":"60"}])
        self.assertEqual(http("POST","/vinos",mal)[0],409)
        self.assertEqual(self.escalar("SELECT count(*) FROM vino WHERE nombre=%s",(mal["nombre"],)),0)
        status, alta = http("POST","/vinos",self.vino("editar"))
        self.assertEqual(status,201,alta)
        cod = alta["cod_vino"]
        self.assertEqual(http("PUT",f"/vinos/{cod}",self.vino("editar",precio="120"))[0],200)
        self.assertEqual(self.escalar("SELECT precio_nuevo FROM auditoria_precio WHERE cod_vino=%s",(cod,)),120)

    def test_cliente_subtipo_atomico(self):
        permiso = {"cod_permiso":self.marca,"fecha_emision":"2026-01-01","fecha_vencimiento":"2027-01-01"}
        cod, _ = self.alta_cliente(tipo_cliente="exportador",pais_destino="Chile",permisos=[permiso])
        self.assertEqual(http("GET",f"/clientes/{cod}")[1]["permisos"],[permiso])
        _, socio = self.alta_cliente()
        socio.update(tipo_cliente="distribuidor",zona_cobertura="Sur",nro_habilitacion=self.marca)
        # El identificador del documento es único, por eso se usa uno nuevo al convertir.
        socio["numero_doc"] = uuid4().hex[:10]
        status, actual = http("PUT",f"/clientes/{cod}",socio)
        self.assertEqual(status,200,actual)
        self.assertEqual(actual["zona_cobertura"],"Sur")
        self.assertEqual(self.escalar("SELECT count(*) FROM permiso_exportacion WHERE id_cliente=%s",(cod,)),0)
        self.assertEqual(http("DELETE",f"/clientes/{cod}")[0],204)

    def test_venta_exitosa(self):
        cliente, _ = self.alta_cliente()
        status, venta = http("POST","/comprobantes",{"id_cliente":cliente,"id_sala":self.sala,
            "renglones":[{"cod_vino":self.vinos[0],"cantidad":1}]})
        self.assertEqual(status,201,venta)
        self.assertEqual(venta["total"],"90.00")
        self.assertEqual(venta["renglones"][0]["descuento_aplicado"],"10.00")
        self.assertEqual(http("GET",f"/comprobantes/{venta['nro_comprobante']}"),(200,venta))

    def test_venta_reversion_despues_de_primer_renglon(self):
        cliente, _ = self.alta_cliente()
        stock = lambda: self.escalar("SELECT fn_stock_sala(%s,%s)",(self.sala,self.vinos[0]))
        antes = stock()
        self.assertGreater(antes,0)
        renglones = self.escalar("SELECT count(*) FROM renglon_comprobante")
        status, error = http("POST","/comprobantes",{"id_cliente":cliente,"id_sala":self.sala,
            "renglones":[{"cod_vino":self.vinos[0],"cantidad":1},{"cod_vino":self.vinos[1],"cantidad":9999}]})
        self.assertEqual(status,409,error)
        self.assertIn(f"vino {self.vinos[1]}",error["detail"])
        self.assertEqual(stock(),antes)
        self.assertEqual(self.escalar("SELECT count(*) FROM comprobante WHERE id_cliente=%s",(cliente,)),0)
        self.assertEqual(self.escalar("SELECT count(*) FROM renglon_comprobante"),renglones)

    def test_transicion_invalida_y_flujos(self):
        for ruta, clave, alta in (
            ("ingresos","cod_ingreso",{"cuit_bodega":self.cuit,"cod_transportista":self.transporte}),
            ("transferencias","nro_solicitud",{"id_sala":self.sala}),
        ):
            status, doc = http("POST",f"/{ruta}",alta)
            self.assertEqual(status,201,doc)
            url = f"/{ruta}/{doc[clave]}"
            self.assertEqual(http("POST",url+"/procesar")[0],409)
            self.assertEqual(http("POST",url+"/renglones",{"cod_vino":self.vinos[0],"cantidad":2})[0],201)
            self.assertEqual(http("POST",url+"/terminar")[1]["estado"],"terminado")
            self.assertEqual(http("POST",url+"/procesar")[1]["estado"],"procesado")

    def test_reportes_y_rol_minimo(self):
        for path in ("top-vinos","ventas-por-sala",f"vinos-sin-stock?sala={self.sala}",
                     "transportista-activo",f"trazabilidad/{self.vinos[0]}"):
            self.assertEqual(http("GET",f"/reportes/{path}")[0],200)
        self.assertEqual(self.escalar("SELECT current_user"),"app_rw")
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            self.db.execute("CREATE TABLE public.etapa6_privilegios (id integer)")
