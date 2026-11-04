"""Pool y límite transaccional de cada operación."""
import os
from decimal import Decimal

from fastapi import Request
from fastapi.encoders import jsonable_encoder
from psycopg.conninfo import make_conninfo
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool


def pool():
    return ConnectionPool(
        make_conninfo(host=os.environ["API_DB_HOST"], port=os.environ["API_DB_PORT"],
                      dbname=os.environ["API_DB_NAME"], user="app_rw",
                      password=os.environ["API_DB_PASSWORD"], connect_timeout=3),
        kwargs={"row_factory": dict_row, "autocommit": True},
        min_size=0, max_size=8, timeout=5, open=False,
    )


def ejecutar(request: Request, operacion, *args):
    with request.app.state.pool.connection() as conexion:
        # La salida del contexto confirma y puede disparar constraints diferidos.
        with conexion.transaction():
            resultado = operacion(conexion, *args)
    return jsonable_encoder(resultado, custom_encoder={Decimal: str})
