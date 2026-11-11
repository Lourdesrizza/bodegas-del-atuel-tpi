# Bodegas del Atuel · Sistema de Gestión Vitivinícola

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20%7C%2018-336791?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v2+-2496ED?style=flat&logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)

**Trabajo Práctico Integrador de Bases de Datos**  
**Universidad Tecnológica Nacional · Facultad Regional San Rafael (UTN FRSR)**  
**Carrera:** Ingeniería en Sistemas de Información · **Ciclo Lectivo:** 2026  
**Integrantes:**
- Lourdes Rizza · `47194471@alumnos.frsr.utn.edu.ar`
- Maite Puente · `46329220@alumnos.frsr.utn.edu.ar`
- Angelina Magallanes · `46664934@alumnos.frsr.utn.edu.ar`
- Jeremías Roda · `45875185@alumnos.frsr.utn.edu.ar`

---

## 1. Resumen Arquitectónico

Bodegas del Atuel es un sistema integral para el control de la cadena de valor vitivinícola en San Rafael, Mendoza: desde el viñedo y el control de calidad enológico hasta la elaboración, fraccionamiento, transferencias logísticas y ventas minoristas/mayoristas.

El sistema implementa una **arquitectura desacoplada en tres capas centrada en la base de datos** (*Database-Centric Architecture*):

```
┌─────────────────────────────────────────────────────────────┐
│                       CAPA CLIENTE                          │
│   Frontend Web Vanilla (HTML5 semántico, CSS3, ES6 Modules) │
│       Puerto 5173 · Proxy de desarrollo anti-CORS           │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP REST / JSON
┌──────────────────────────────▼──────────────────────────────┐
│                    CAPA DE APLICACIÓN                       │
│    API REST FastAPI · Driver Nativo psycopg 3 (Sin ORM)     │
│        Pool de conexiones transaccional · Rol: app_rw       │
└──────────────────────────────┬──────────────────────────────┘
                               │ Protocolo PostgreSQL (TCP 5432)
┌──────────────────────────────▼──────────────────────────────┐
│                    NÚCLEO DE DATOS                          │
│              PostgreSQL 16 (Alpine) / 18 Local              │
│  - 30 tablas normalizadas en 3FN                            │
│  - Integridad declarativa (CHECK, UNIQUE, DOMAIN, FKs)      │
│  - Reglas de negocio procedimentales (Triggers RN-01..RN-15)│
│  - Procedimientos almacenados transaccionales (SPs)         │
│  - Índices optimizados (Compuestos, Parciales, INCLUDE)     │
│  - Control de accesos RBAC (app_owner, app_rw, app_ro)      │
└─────────────────────────────────────────────────────────────┘
```

- **Motor de Base de Datos como Núcleo:** La lógica de negocio crítica (validaciones de corte de vino al 100%, cálculo de subtotales y descuentos, control estricto de existencias e inmutabilidad de comprobantes) reside exclusivamente en PostgreSQL. Cualquier cliente (API web, procesos batch o reportes analíticos) queda regido por las mismas invariantes.
- **Acceso a Datos Directo y Seguro:** Se prohíbe el uso de ORMs. La API interactúa mediante sentencias SQL directas 100% parametrizadas vía `psycopg`, previniendo inyecciones SQL y garantizando un control milimétrico sobre las transacciones y los planes de ejecución.
- **Seguridad y Privilegios Mínimos:** La API opera bajo el rol de base de datos `app_rw`, el cual carece de permisos de definición de datos (DDL) y de actualización directa sobre existencias físicas, canalizando mutaciones de stock a través de procedimientos almacenados autorizados o triggers.

---

## 2. Puesta en Marcha con un Solo Comando

### Requisitos Previos
- Docker Desktop (con motor Linux activo) y Docker Compose v2+.
- Shell: PowerShell 7+ (Windows) o Bash (Linux / macOS).
- Puertos libres locales: `8000` (API) y `5173` (Frontend).

### Pasos de Inicialización

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/Lourdesrizza/bodegas-del-atuel-tpi.git
   cd bodegas-del-atuel-tpi
   ```

2. **Configurar el entorno seguro (`.env`):**
   Copiar la plantilla de variables de entorno y definir contraseñas seguras para el laboratorio:
   
   *En Windows (PowerShell):*
   ```powershell
   if (-not (Test-Path -LiteralPath .env)) { Copy-Item .env.example .env }
   # Editar .env asegurando valores para ATUEL_LAB_ADMIN_PASSWORD y API_DB_PASSWORD
   ```

   *En Linux / macOS (Bash):*
   ```bash
   cp -n .env.example .env
   # Editar .env completando las contraseñas requeridas
   ```

   *Ejemplo de configuración en `.env`:*
   ```env
   ATUEL_LAB_ADMIN_PASSWORD=AdminSeguroLab2026!
   API_DB_PASSWORD=AppRwPasswordLab2026!
   ATUEL_API_PORT=8000
   ATUEL_FRONT_PORT=5173
   ```

3. **Construir y levantar todo el ecosistema contenedorizado:**
   ```bash
   docker compose up -d --build
   ```

El inicializador automático ejecutará secuencialmente las migraciones `001` a `008`, aprovisionará los esquemas, roles y privilegios, e iniciará los servicios `db`, `api` y `front` en una red interna privada.

---

## 3. Puntos de Acceso del Sistema

Una vez finalizado el levantamiento, los puntos de acceso disponibles en el host son:

| Servicio | URL Local | Descripción |
|---|---|---|
| **Frontend Web** | [`http://localhost:5173`](http://localhost:5173) | Interfaz gráfica de 5 pantallas (Catálogo, Alta/Edición, Ventas, Transferencias, Tablero). |
| **API Swagger UI** | [`http://localhost:8000/docs`](http://localhost:8000/docs) | Documentación interactiva OpenAPI con catálogo completo de endpoints y esquemas. |
| **API ReDoc** | [`http://localhost:8000/redoc`](http://localhost:8000/redoc) | Especificación técnica formal de la API REST. |
| **Chequeo de Salud** | [`http://localhost:8000/salud`](http://localhost:8000/salud) | Verificación de conectividad de base de datos y rol activo (`app_rw`). |
| **Especificación OpenAPI** | [`http://localhost:8000/openapi.json`](http://localhost:8000/openapi.json) | Contrato crudo JSON consumido por clientes externos. |

---

## 4. Instrucciones de Verificación y Testing

El repositorio cuenta con suites de regresión automatizadas que cubren las reglas de negocio, integridad de datos, concurrencia y pruebas de integración HTTP.

### A. Pruebas de Integración de la API (10 casos de prueba completos)
Ejecutan contra el contenedor activo validando transacciones, auditoría de precios, prevención de inyecciones SQL y rechazo de violaciones de reglas de negocio:
```powershell
docker compose exec -T api python -m unittest discover -s api/tests -v
```
*Salida esperada:* `Ran 10 tests ... OK`.

### B. Suite de Regresión de la Base de Datos (`tests/db_tests.sql`)
Verifica las 15 reglas de negocio (RN-01 a RN-15), permisos de roles y constraints en PostgreSQL:
```powershell
docker compose exec -T db psql -U atuel_admin -d atuel_api_test -v ON_ERROR_STOP=1 -f /atuel/migrations/../tests/db_tests.sql
```
*Salida esperada:* Ejecución limpia con código de retorno `0`.

### C. Prueba de Concurrencia Extrema: «La Última Botella»
Simula dos compradores concurrentes compitiendo al mismo milisegundo por la última botella en stock bajo nivel de aislamiento `Read Committed`:
```powershell
docker compose exec -T api python tests/concurrencia_ultima_botella.py
```
*Salida esperada:* `OK: una sola venta confirmó la última botella (resultados=[0, 3]; stock=0; ventas=1)`.

### D. Verificación de los 20 Controles de Integridad en Carga Masiva
Comprueba que los 500.000 renglones de venta y 150.000 comprobantes cumplan todas las invariantes contables y de stock:
```powershell
docker compose exec -T db psql -U atuel_admin -d atuel_api_test -f /atuel/migrations/../db/seed/validar_carga.sql
```
*Salida esperada:* Las 20 métricas de control en `0`.

### E. Benchmarks de Rendimiento e Índices (Etapa 4)
Para reproducir las comparaciones con `EXPLAIN (ANALYZE, BUFFERS)` y medición de costos de escritura (WAL):
```powershell
docker compose exec -T api python db/benchmarks/etapa_4/medir.py comparar --salida docs/evidencias_etapa_4
```

---

## 5. Nota de Alcance sobre la Infraestructura

> [!NOTE]
> **Acuerdo con la Cátedra (Sustitución de Etapa 8):**  
> De común acuerdo con el cuerpo docente de la cátedra de Bases de Datos, el despliegue en infraestructuras comerciales en la nube (plataformas PaaS/Serverless gratuitas) fue **reemplazado por una solución de contenedorización 100% aislada, inmutable y reproducible mediante Docker Compose local**.
> 
> **Fundamentación Técnica:**
> 1. **Volumen de Datos Realista:** Las capas gratuitas de servicios en la nube imponen límites restrictivos de memoria (512 MB) y almacenamiento (500 MB a 1 GB) que impiden alojar de forma determinística 500.000 renglones de venta, 150.000 comprobantes y ejecutar pruebas de estrés con generación masiva de WAL.
> 2. **Reproducibilidad Académica:** Docker Compose garantiza paridad absoluta entre el entorno de desarrollo y la evaluación docente en cualquier sistema operativo (Windows, Linux, macOS), eliminando fallas por latencia de red, límites de cuota de I/O o suspensión de instancias por inactividad.
> 3. **Seguridad y Aislamiento:** La base de datos no expone su puerto `5432` a la red pública; reside en una red puente (*bridge network*) interna a la que únicamente tiene acceso la API mediante credenciales inyectadas por variables de entorno protegidas.

---

## 6. Estructura del Repositorio y Documentación

- [`docs/informe_final.md`](docs/informe_final.md): **Informe Final Consolidado (Sección 10.2)** con el desarrollo exhaustivo de todas las etapas, justificación teórica en 3FN, tabla de trazabilidad RN-01..RN-15, mediciones EXPLAIN ANALYZE y análisis de consultas complejas.
- [`docs/guion_demo.md`](docs/guion_demo.md): **Guion de la Demostración en Vivo (10-15 min)** paso a paso para la defensa frente al tribunal evaluador.
- [`docs/defensa_oral_preguntas.md`](docs/defensa_oral_preguntas.md): **Simulador de Defensa Oral** con las 10 preguntas técnicas de mayor profundidad y sus respuestas de nivel senior.
- [`db/migrations/`](db/migrations/): Scripts DDL ordenados (`001_esquema.sql` a `008_indices.sql`).
- [`consultas/`](consultas/): Resolución de las 30 consultas SQL de la Etapa 5 (SELECT, INSERT, UPDATE, DELETE).
- [`api/`](api/): Código fuente de la API REST transaccional en FastAPI con driver nativo.
- [`front/`](front/): Frontend Vanilla JavaScript, servidor de archivos y proxy reverso.
- [`tests/`](tests/): Scripts y suites de prueba de regresión y concurrencia.
