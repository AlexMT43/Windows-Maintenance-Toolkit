#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "Windows Maintenance Toolkit"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $scriptRoot
$moduleRoot = Join-Path $scriptRoot "modules"

Import-Module (Join-Path $moduleRoot "Common.psm1") -Force
Start-WMTElevated -ScriptPath $PSCommandPath

if ($env:OS -ne "Windows_NT") {
    Write-Host "WMT solo es compatible con Windows." -ForegroundColor Red
    exit 1
}

try {
    $config = Get-WMTConfig -RepositoryRoot $repositoryRoot
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

$logPath = Initialize-WMTLog -RepositoryRoot $repositoryRoot -Config $config
Write-WMTLog -LogPath $logPath -Message "Inicio de Windows Maintenance Toolkit."

Import-Module (Join-Path $moduleRoot "UpdateApps.psm1") -Force
Import-Module (Join-Path $moduleRoot "Cleanup.psm1") -Force
Import-Module (Join-Path $moduleRoot "EmptyFolders.psm1") -Force
Import-Module (Join-Path $moduleRoot "Repair.psm1") -Force
Import-Module (Join-Path $moduleRoot "Reports.psm1") -Force

do {
    Clear-Host
    Write-Host "================================================" -ForegroundColor DarkCyan
    Write-Host "        WINDOWS MAINTENANCE TOOLKIT v1.0.1" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host " 1. Actualizar aplicaciones con WinGet"
    Write-Host " 2. Liberar espacio: limpieza segura"
    Write-Host " 3. Eliminar carpetas vacías"
    Write-Host " 4. Comprobar y reparar Windows"
    Write-Host " 5. Limpiar caché DNS"
    Write-Host " 6. Crear informe del sistema"
    Write-Host " 7. Exportar aplicaciones instaladas"
    Write-Host " 0. Salir"
    Write-Host ""

    $option = Read-Host "Selecciona una opción"

    switch ($option) {
        "1" { Invoke-WMTApplicationUpdate -Config $config -LogPath $logPath }
        "2" { Invoke-WMTSafeCleanup -Config $config -LogPath $logPath }
        "3" { Invoke-WMTEmptyFolderRemoval -Config $config -LogPath $logPath }
        "4" { Invoke-WMTWindowsRepair -LogPath $logPath }
        "5" { Invoke-WMTFlushDns -LogPath $logPath }
        "6" { Export-WMTSystemReport -RepositoryRoot $repositoryRoot -LogPath $logPath }
        "7" { Export-WMTWingetApps -RepositoryRoot $repositoryRoot -LogPath $logPath }
        "0" { }
        default {
            Write-Host "Opción no válida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($option -ne "0")

Write-WMTLog -LogPath $logPath -Message "Cierre de Windows Maintenance Toolkit."
