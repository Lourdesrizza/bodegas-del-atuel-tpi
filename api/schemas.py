"""Contratos de entrada. PostgreSQL valida las reglas de negocio."""
from datetime import date
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class Entrada(BaseModel):
    model_config = ConfigDict(extra="forbid")


TipoVino = Literal["tinto", "blanco", "rosado", "espumante"]
Id = Annotated[int, Field(gt=0, le=2147483647)]


class Corte(Entrada):
    id_cepa: Id
    porcentaje: Decimal


class Vino(Entrada):
    cuit_bodega: str = Field(pattern=r"^[0-9]{11}$")
    nombre: str = Field(min_length=1, max_length=120)
    tipo: TipoVino
    anada: int
    volumen_ml: int
    graduacion: Decimal
    precio: Decimal
    cepas: list[Corte] = Field(min_length=1)
    maridajes: list[Id] = Field(default_factory=list)


class ClienteBase(Entrada):
    id_localidad: Id
    nombre_o_razon_social: str = Field(min_length=1, max_length=150)
    tipo_doc: str = Field(min_length=1, max_length=20)
    numero_doc: str = Field(min_length=1, max_length=30)
    domicilio: str = Field(min_length=1, max_length=200)


class Socio(ClienteBase):
    tipo_cliente: Literal["socio"]


class Distribuidor(ClienteBase):
    tipo_cliente: Literal["distribuidor"]
    zona_cobertura: str = Field(min_length=1, max_length=150)
    nro_habilitacion: str = Field(min_length=1, max_length=50)


class Permiso(Entrada):
    cod_permiso: str = Field(min_length=1, max_length=50)
    fecha_emision: date
    fecha_vencimiento: date


class Exportador(ClienteBase):
    tipo_cliente: Literal["exportador"]
    pais_destino: str = Field(min_length=1, max_length=100)
    permisos: list[Permiso] = Field(default_factory=list)


Cliente = Annotated[Socio | Distribuidor | Exportador, Field(discriminator="tipo_cliente")]


class Renglon(Entrada):
    cod_vino: Id
    cantidad: Id


class Venta(Entrada):
    id_cliente: Id
    id_sala: Id
    renglones: list[Renglon] = Field(min_length=1, max_length=500)


class Transferencia(Entrada):
    id_sala: Id


class Ingreso(Entrada):
    cuit_bodega: str = Field(pattern=r"^[0-9]{11}$")
    cod_transportista: Id
