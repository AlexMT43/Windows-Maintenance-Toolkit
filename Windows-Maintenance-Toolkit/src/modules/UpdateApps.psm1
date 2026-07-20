function Invoke-WMTApplicationUpdate {
    param(
        [Parameter(Mandatory=$true)]$Config,
        [AllowNull()][string]$LogPath
    )

    Clear-Host
    Write-Host "=== ACTUALIZAR APLICACIONES ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Host "WinGet no está instalado o no está disponible." -ForegroundColor Red
        Write-Host "Instala o actualiza App Installer desde Microsoft Store." -ForegroundColor Yellow
        Write-WMTLog -LogPath $LogPath -Level ERROR -Message "WinGet no disponible."
        Pause-WMT
        return
    }

    Write-Host "WinGet actualizará las aplicaciones compatibles." -ForegroundColor Yellow
    Write-Host "Esto no garantiza la actualización de todos los controladores." -ForegroundColor DarkYellow
    Write-Host ""

    if ((Read-Host "Escribe ACTUALIZAR para continuar") -cne "ACTUALIZAR") {
        Write-Host "Operación cancelada." -ForegroundColor Yellow
        Write-WMTLog -LogPath $LogPath -Level WARN -Message "Actualización cancelada por el usuario."
        Pause-WMT
        return
    }

    $arguments = @("upgrade", "--all")
    if ($Config.Winget.AcceptAgreements) {
        $arguments += "--accept-source-agreements"
        $arguments += "--accept-package-agreements"
    }
    if ($Config.Winget.IncludeUnknown) {
        $arguments += "--include-unknown"
    }

    Write-WMTLog -LogPath $LogPath -Message "Ejecutando winget $($arguments -join ' ')"
    & winget.exe @arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "Actualización finalizada." -ForegroundColor Green
        Write-WMTLog -LogPath $LogPath -Message "WinGet finalizó correctamente."
    }
    else {
        Write-Host "WinGet terminó con código $exitCode." -ForegroundColor Yellow
        Write-WMTLog -LogPath $LogPath -Level WARN -Message "WinGet finalizó con código $exitCode."
    }

    Pause-WMT
}

Export-ModuleMember -Function Invoke-WMTApplicationUpdate
