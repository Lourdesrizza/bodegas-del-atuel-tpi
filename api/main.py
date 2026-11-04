"""Rutas HTTP y traducción de errores de PostgreSQL."""
from contextlib import asynccontextmanager
from typing import Annotated

import psycopg
from psycopg_pool import PoolTimeout
from fastapi import FastAPI, Query, Request, Response
from fastapi.responses import JSONResponse

from . import data, schemas
from .db import ejecutar, pool


@asynccontextmanager
async def lifespan(app):
    app.state.pool = pool()
    app.state.pool.open()
    try:
        yield
    finally:
        app.state.pool.close()


app = FastAPI(title="Bodegas del Atuel", version="1.0.0", lifespan=lifespan)
Limite = Annotated[int, Query(ge=1, le=100)]
Offset = Annotated[int, Query(ge=0, le=2147483647)]
Id = Annotated[int, Query(gt=0, le=2147483647)]
ERRORES = {
    "23505": (409, "Ya existe un registro con esos datos"),
    "23503": (409, "La referencia no existe o tiene registros dependientes"),
    "23001": (409, "El registro tiene movimientos dependientes"),
    "23514": (422, "Un valor incumple una restricción de la base"),
    "23502": (422, "Falta un valor obligatorio"),
    "22003": (422, "Un valor numérico está fuera de rango"),
    "22001": (422, "Un valor excede la longitud permitida"),
    "22P02": (400, "Formato de dato inválido"),
    "40001": (503, "Conflicto temporal. Reintentá la operación"),
    "40P01": (503, "Conflicto temporal. Reintentá la operación"),
}


@app.exception_handler(psycopg.Error)
async def error_postgres(_request, error):
    if error.sqlstate == "P0001":
        return JSONResponse(status_code=409, content={"detail": error.diag.message_primary})
    status, detail = ERRORES.get(error.sqlstate, (500, "Error de acceso a datos"))
    if isinstance(error, psycopg.OperationalError) and not error.sqlstate:
        status, detail = 503, "Base de datos no disponible. Reintentá"
    return JSONResponse(status_code=status, content={"detail": detail},
                        headers={"Retry-After": "1"} if status == 503 else None)


@app.exception_handler(PoolTimeout)
async def pool_ocupado(_request, _error):
    return JSONResponse(status_code=503, content={"detail": "Base de datos no disponible. Reintentá"},
                        headers={"Retry-After": "1"})


@app.get("/salud", tags=["Salud"])
def salud(request: Request):
    return ejecutar(request, data.salud)


@app.get("/vinos", tags=["Vinos"])
def vinos(request: Request, tipo: schemas.TipoVino | None = None, cepa: Id | None = None,
          bodega: Annotated[str | None, Query(pattern=r"^[0-9]{11}$")] = None,
          anada: int | None = None, nombre: Annotated[str | None, Query(max_length=120)] = None,
          limite: Limite = 25, offset: Offset = 0):
    return ejecutar(request, data.listar_vinos, tipo, cepa, bodega, anada, nombre, limite, offset)


@app.get("/vinos/{cod}", tags=["Vinos"])
def obtener_vino(request: Request, cod: schemas.Id):
    return ejecutar(request, data.vino, cod)


@app.post("/vinos", status_code=201, tags=["Vinos"])
def alta_vino(request: Request, cuerpo: schemas.Vino):
    return ejecutar(request, data.guardar_vino, cuerpo)


@app.put("/vinos/{cod}", tags=["Vinos"])
def editar_vino(request: Request, cod: schemas.Id, cuerpo: schemas.Vino):
    return ejecutar(request, data.guardar_vino, cuerpo, cod)


@app.delete("/vinos/{cod}", status_code=204, tags=["Vinos"])
def baja_vino(request: Request, cod: schemas.Id):
    ejecutar(request, data.borrar_vino, cod)
    return Response(status_code=204)


@app.get("/clientes", tags=["Clientes"])
def clientes(request: Request, limite: Limite = 25, offset: Offset = 0):
    return ejecutar(request, data.listar_clientes, limite, offset)


@app.get("/clientes/{cod}", tags=["Clientes"])
def obtener_cliente(request: Request, cod: schemas.Id):
    return ejecutar(request, data.cliente, cod)


@app.post("/clientes", status_code=201, tags=["Clientes"])
def alta_cliente(request: Request, cuerpo: schemas.Cliente):
    return ejecutar(request, data.guardar_cliente, cuerpo)


@app.put("/clientes/{cod}", tags=["Clientes"])
def editar_cliente(request: Request, cod: schemas.Id, cuerpo: schemas.Cliente):
    return ejecutar(request, data.guardar_cliente, cuerpo, cod)


@app.delete("/clientes/{cod}", status_code=204, tags=["Clientes"])
def baja_cliente(request: Request, cod: schemas.Id):
    ejecutar(request, data.borrar_cliente, cod)
    return Response(status_code=204)


@app.post("/comprobantes", status_code=201, tags=["Comprobantes"])
def alta_venta(request: Request, cuerpo: schemas.Venta):
    return ejecutar(request, data.vender, cuerpo)


@app.get("/comprobantes/{nro}", tags=["Comprobantes"])
def obtener_venta(request: Request, nro: schemas.Id):
    return ejecutar(request, data.comprobante, nro)


@app.post("/ingresos", status_code=201, tags=["Ingresos"])
def alta_ingreso(request: Request, cuerpo: schemas.Ingreso):
    return ejecutar(request, data.crear_ingreso, cuerpo)


@app.post("/transferencias", status_code=201, tags=["Transferencias"])
def alta_transferencia(request: Request, cuerpo: schemas.Transferencia):
    return ejecutar(request, data.crear_transferencia, cuerpo)


def registrar_documento(ruta, clase, tag):
    @app.get(f"/{ruta}/{{cod}}", tags=[tag], name=f"Obtener {clase}")
    def obtener(request: Request, cod: schemas.Id):
        return ejecutar(request, data.documento, clase, cod)

    @app.post(f"/{ruta}/{{cod}}/renglones", status_code=201, tags=[tag], name=f"Cargar renglón de {clase}")
    def renglon(request: Request, cod: schemas.Id, cuerpo: schemas.Renglon):
        return ejecutar(request, data.cargar_renglon, clase, cod, cuerpo)

    @app.post(f"/{ruta}/{{cod}}/terminar", tags=[tag], name=f"Terminar {clase}")
    def terminar(request: Request, cod: schemas.Id):
        return ejecutar(request, data.cambiar_estado, clase, cod, False)

    @app.post(f"/{ruta}/{{cod}}/procesar", tags=[tag], name=f"Procesar {clase}")
    def procesar(request: Request, cod: schemas.Id):
        return ejecutar(request, data.cambiar_estado, clase, cod, True)


registrar_documento("ingresos", "ingreso", "Ingresos")
registrar_documento("transferencias", "transferencia", "Transferencias")


@app.get("/reportes/top-vinos", tags=["Reportes"])
def top_vinos(request: Request):
    return ejecutar(request, data.top_vinos)


@app.get("/reportes/ventas-por-sala", tags=["Reportes"])
def ventas_por_sala(request: Request):
    return ejecutar(request, data.ventas_por_sala)


@app.get("/reportes/vinos-sin-stock", tags=["Reportes"])
def vinos_sin_stock(request: Request, sala: Id, limite: Limite = 25, offset: Offset = 0):
    return ejecutar(request, data.vinos_sin_stock, sala, limite, offset)


@app.get("/reportes/transportista-activo", tags=["Reportes"])
def transportista_activo(request: Request):
    return ejecutar(request, data.transportista_activo)


@app.get("/reportes/trazabilidad/{cod}", tags=["Reportes"])
def trazabilidad(request: Request, cod: schemas.Id, limite: Limite = 25, offset: Offset = 0):
    return ejecutar(request, data.trazabilidad, cod, limite, offset)
