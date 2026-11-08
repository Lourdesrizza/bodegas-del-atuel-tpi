# Evidencias de la etapa 5

`consultas/verificar.ps1` registra un log por archivo con hora ISO, comando, base, SQL, salida y código de salida. Ejecutar desde PowerShell con el puerto, usuario, base de laboratorio y **nombre** de la variable de contraseña.

```powershell
.\consultas\verificar.ps1 -Puerto PUERTO -Usuario USUARIO -Base BASE_test -VariableClave VARIABLE
```

Resultados en PostgreSQL 16.15 sobre atuel_base_test. preflight.log comprueba la carga y los índices. update_final.log, insert.log, delete.log y select_final.log son las corridas aceptadas. update.log y select.log conservan los primeros intentos, y control_final.log registra el control posterior. Los comandos de los logs usan el socket del contenedor aislado que publica en 55441.
