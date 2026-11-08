"""Pruebas del proxy sin acceder a bases de datos ni a la API del grupo."""
import importlib.util
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

RUTA = Path(__file__).resolve().parents[1] / "server.py"
spec = importlib.util.spec_from_file_location("servidor_front", RUTA)
front = importlib.util.module_from_spec(spec)
spec.loader.exec_module(front)


class ApiDePrueba(BaseHTTPRequestHandler):
    def atender(self):
        cuerpo = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.path == "/comprobantes":
            estado, datos = 409, {"detail": "Stock insuficiente en sala para vino 1 (RN-09)"}
        else:
            estado = 200
            datos = {"metodo": self.command, "ruta": self.path,
                     "cuerpo": json.loads(cuerpo) if cuerpo else None}
        salida = json.dumps(datos).encode()
        self.send_response(estado)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(salida)

    do_GET = atender
    do_POST = atender
    do_PUT = atender

    def log_message(self, *_args):
        pass


class Proxy(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api = ThreadingHTTPServer(("127.0.0.1", 0), ApiDePrueba)
        front.API = f"http://127.0.0.1:{cls.api.server_port}"
        cls.proxy = ThreadingHTTPServer(("127.0.0.1", 0), front.Servidor)
        for servidor in (cls.api, cls.proxy):
            threading.Thread(target=servidor.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        for servidor in (cls.proxy, cls.api):
            servidor.shutdown()
            servidor.server_close()

    def pedir(self, ruta, metodo="GET", cuerpo=None, tipo="application/json"):
        solicitud = Request(
            f"http://127.0.0.1:{self.proxy.server_port}{ruta}", method=metodo,
            data=json.dumps(cuerpo).encode() if cuerpo is not None else None,
            headers={"Content-Type": tipo})
        try:
            respuesta = urlopen(solicitud, timeout=5)
        except HTTPError as error:
            respuesta = error
        with respuesta:
            return respuesta.status, respuesta.read()

    def test_filtros_y_paginacion(self):
        codigo, cuerpo = self.pedir("/api/vinos?tipo=rosado&limite=13&offset=12")
        self.assertEqual(codigo, 200)
        self.assertEqual(json.loads(cuerpo)["ruta"], "/vinos?tipo=rosado&limite=13&offset=12")

    def test_edicion_conserva_cuerpo(self):
        datos = {"nombre": "Rosado del Atuel", "cepas": [{"id_cepa": 1, "porcentaje": "100"}]}
        codigo, cuerpo = self.pedir("/api/vinos/2", "PUT", datos)
        self.assertEqual(codigo, 200)
        self.assertEqual(json.loads(cuerpo)["cuerpo"], datos)
        self.assertEqual(json.loads(cuerpo)["metodo"], "PUT")

    def test_error_de_venta_conserva_texto_y_codigo(self):
        codigo, cuerpo = self.pedir("/api/comprobantes", "POST", {"renglones": []})
        self.assertEqual(codigo, 409)
        self.assertEqual(json.loads(cuerpo)["detail"], "Stock insuficiente en sala para vino 1 (RN-09)")

    def test_transiciones_sin_cuerpo(self):
        for accion in ("terminar", "procesar"):
            codigo, cuerpo = self.pedir(f"/api/transferencias/7/{accion}", "POST")
            self.assertEqual(codigo, 200)
            self.assertEqual(json.loads(cuerpo)["metodo"], "POST")

    def test_rutas_restringidas(self):
        for ruta in ("/api/admin", "/api/vinos/../clientes", "/api/reportes/otro"):
            self.assertEqual(self.pedir(ruta)[0], 404)

    def test_mutaciones_requieren_json(self):
        codigo, _ = self.pedir("/api/transferencias/7/procesar", "POST", tipo="text/plain")
        self.assertEqual(codigo, 415)

    def test_interfaz_estatica(self):
        codigo, cuerpo = self.pedir("/")
        self.assertEqual(codigo, 200)
        for vista in ("catalogo", "vino", "venta", "transferencias", "tablero"):
            self.assertIn(f'id="vista-{vista}"'.encode(), cuerpo)

    def test_reporte_stock(self):
        codigo, cuerpo = self.pedir("/api/reportes/vinos-sin-stock?sala=1&limite=13&offset=0")
        self.assertEqual(codigo, 200)
        self.assertIn("sala=1", json.loads(cuerpo)["ruta"])


if __name__ == "__main__":
    unittest.main()
