"""Archivos del front y proxy acotado hacia las rutas existentes de la API."""
import json
import os
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

CARPETA = Path(__file__).resolve().parent
API = os.environ.get("ATUEL_API_URL", "http://127.0.0.1:8000").rstrip("/")
PUERTO = int(os.environ.get("ATUEL_FRONT_PORT", "5173"))
HOST = os.environ.get("ATUEL_FRONT_HOST", "127.0.0.1")
RUTAS = {
    "GET": (
        r"/vinos(?:/[0-9]+)?",
        r"/clientes(?:/[0-9]+)?",
        r"/comprobantes/[0-9]+",
        r"/transferencias/[0-9]+",
        r"/reportes/(?:top-vinos|ventas-por-sala|vinos-sin-stock)",
    ),
    "POST": (
        r"/vinos", r"/comprobantes", r"/transferencias",
        r"/transferencias/[0-9]+/(?:renglones|terminar|procesar)",
    ),
    "PUT": (r"/vinos/[0-9]+",),
}


class Servidor(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(CARPETA), **kwargs)

    def do_GET(self):
        if urlsplit(self.path).path.startswith("/api/"):
            self.reenviar()
        else:
            super().do_GET()

    def do_POST(self):
        self.reenviar()

    def do_PUT(self):
        self.reenviar()

    def responder_json(self, estado, cuerpo):
        self.send_response(estado)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(cuerpo)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(cuerpo)

    def reenviar(self):
        ruta = urlsplit(self.path)
        camino = ruta.path[4:] if ruta.path.startswith("/api/") else ""
        if not any(re.fullmatch(patron, camino) for patron in RUTAS.get(self.command, ())):
            self.responder_json(404, b'{"detail":"Ruta no disponible"}')
            return
        if self.command != "GET" and self.headers.get_content_type() != "application/json":
            self.responder_json(415, b'{"detail":"La solicitud debe usar application/json"}')
            return
        try:
            longitud = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.responder_json(400, b'{"detail":"Longitud invalida"}')
            return
        if not 0 <= longitud <= 1_000_000:
            self.responder_json(413, b'{"detail":"Solicitud demasiado grande"}')
            return
        datos = self.rfile.read(longitud) if longitud else None
        destino = API + camino + ("?" + ruta.query if ruta.query else "")
        headers = {"Accept": "application/json", "Content-Type": "application/json"}
        try:
            solicitud = Request(destino, data=datos, headers=headers, method=self.command)
            with urlopen(solicitud, timeout=20) as respuesta:
                estado, cuerpo = respuesta.status, respuesta.read()
        except HTTPError as fallo:
            estado, cuerpo = fallo.code, fallo.read()
        except (URLError, TimeoutError, ConnectionError):
            estado = 502
            cuerpo = json.dumps({"detail": "No se pudo conectar con la API."}).encode()
        self.responder_json(estado, cuerpo)


if __name__ == "__main__":
    print(f"Front en http://{HOST}:{PUERTO} · API: {API}")
    ThreadingHTTPServer((HOST, PUERTO), Servidor).serve_forever()
