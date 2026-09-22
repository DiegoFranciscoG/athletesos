# Arranca el backend cargando secretos desde .env (no desde variables de
# entorno de Windows, que se acumulan/corrompen entre sesiones distintas).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path ".env")) {
    Write-Error "Falta .env - copia .env.example y completa los valores."
    exit 1
}

Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $parts = $_ -split '=', 2
    if ($parts.Length -eq 2) {
        [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
    }
}

& ".\mvnw.cmd" spring-boot:run
