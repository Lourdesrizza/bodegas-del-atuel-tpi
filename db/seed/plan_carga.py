"""Inspecciona el DDL y muestra dependencias. No se conecta ni modifica la BD."""
import csv
import re
from pathlib import Path

BASE = Path(__file__).resolve().parent


def plan():
    ddl = (BASE.parent / 'migrations' / '001_esquema.sql').read_text(encoding='utf-8')
    ddl = re.sub(r'--[^\n]*', '', ddl)
    tablas = re.findall(r'CREATE TABLE\s+(\w+)\s*\((.*?)\);', ddl, re.S | re.I)
    pendientes = {nombre: set(re.findall(r'REFERENCES\s+(\w+)', cuerpo, re.I))
                  for nombre, cuerpo in tablas}
    cargadas = set()
    niveles = []
    while pendientes:
        listas = sorted(n for n, deps in pendientes.items() if deps <= cargadas)
        if not listas:
            raise ValueError(f'Dependencias circulares o tablas ausentes: {pendientes}')
        niveles.append(listas)
        cargadas.update(listas)
        for nombre in listas:
            del pendientes[nombre]
    return niveles


def main():
    esperados = {'cepas.csv': 12, 'maridajes.csv': 8,
                 'departamentos.csv': 18, 'tipos_vino.csv': 4,
                 'localidades.csv': 20}
    for nombre, cantidad in esperados.items():
        with (BASE / 'catalogos' / nombre).open(encoding='utf-8', newline='') as archivo:
            filas = list(csv.DictReader(archivo))
        if len(filas) != cantidad or any(not v or '\ufffd' in v or '?' in v
                                        for fila in filas for v in fila.values()):
            raise ValueError(f'Catalogo incompleto o texto dañado: {nombre}')
        print(f'{nombre}: {len(filas)} filas verificadas')
    niveles = plan()
    print(f'\nOrden por dependencias ({sum(map(len, niveles))} tablas):')
    for i, tablas in enumerate(niveles, 1):
        print(f'{i}. {", ".join(tablas)}')
    print('\nSolo diagnostico: no se insertaron datos en PostgreSQL.')


if __name__ == '__main__':
    main()
