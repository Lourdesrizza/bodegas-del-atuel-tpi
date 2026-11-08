param(
    [Parameter(Mandatory)][string]$Puerto,
    [Parameter(Mandatory)][string]$Usuario,
    [Parameter(Mandatory)][string]$Base,
    [Parameter(Mandatory)][string]$VariableClave,
    [string]$Psql = 'psql'
)

$ErrorActionPreference = 'Stop'
if ($Base -cnotmatch '^[a-zA-Z0-9_]+_(test|dev)$') {
    throw 'La base debe terminar en _test o _dev.'
}
$clave = [Environment]::GetEnvironmentVariable($VariableClave)
if ([string]::IsNullOrEmpty($clave)) { throw 'La variable de contraseña está vacía o no está disponible.' }

Push-Location (Split-Path $PSScriptRoot -Parent)
$claveAnterior = $env:PGPASSWORD
try {
    $env:PGPASSWORD = $clave
    $marca = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $destino = 'docs/evidencias_etapa_5'
    New-Item -ItemType Directory -Force $destino | Out-Null
    $fallos = @()
    foreach ($tipo in 'update','insert','delete','select') {
        $archivo = "consultas/$tipo.sql"
        $log = Join-Path $destino "${marca}_$tipo.log"
        $argumentos = @('-X','-w','-h','localhost','-p',$Puerto,'-U',$Usuario,'-d',$Base,
            '-v','ON_ERROR_STOP=1','-v','medir=1','-a','-c','SELECT current_database(), current_user, version();','-f',$archivo)
        @(
            "Inicio: $(Get-Date -Format o)"
            "Base: $Base"
            ('Comando: "' + $Psql + '" "' + ($argumentos -join '" "') + '"')
        ) | Set-Content -Encoding utf8 $log
        & $Psql @argumentos 2>&1 | ForEach-Object { "$_" } | Add-Content -Encoding utf8 $log
        $codigo = $LASTEXITCODE
        "Fin: $(Get-Date -Format o) | Código: $codigo" | Add-Content -Encoding utf8 $log
        if ($codigo -ne 0) { $fallos += $tipo }
    }
    if ($fallos.Count) { throw "Ver ejecución incompleta en los logs de: $($fallos -join ', ')." }
}
finally {
    $env:PGPASSWORD = $claveAnterior
    Pop-Location
}
