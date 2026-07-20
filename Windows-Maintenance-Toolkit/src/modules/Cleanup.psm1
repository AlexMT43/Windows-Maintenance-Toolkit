function Invoke-WMTSafeCleanup {
    param(
        [Parameter(Mandatory=$true)]$Config,
        [AllowNull()][string]$LogPath
    )

    Clear-Host
    Write-Host "=== LIBERAR ESPACIO: LIMPIEZA SEGURA ===" -ForegroundColor Cyan
    Write-Host ""

    $before = Get-WMTFreeSpaceGB
    if ($null -ne $before) {
        Write-Host "Espacio libre antes: $before GB" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Esta operación puede limpiar:" -ForegroundColor White
    if ($Config.Cleanup.UserTemp) { Write-Host " - Temporales del usuario" }
    if ($Config.Cleanup.WindowsTemp) { Write-Host " - Temporales de Windows" }
    if ($Config.Cleanup.WindowsUpdateCache) { Write-Host " - Descargas temporales de Windows Update" }
    if ($Config.Cleanup.RecycleBin) { Write-Host " - Papelera de reciclaje" }
    if ($Config.Cleanup.DismComponentCleanup) { Write-Host " - Componentes antiguos de Windows mediante DISM" }

    Write-Host ""
    Write-Host "No se borrarán Descargas, Documentos ni archivos personales." -ForegroundColor DarkYellow

    if ((Read-Host "Escribe LIMPIAR para continuar") -cne "LIMPIAR") {
        Write-Host "Operación cancelada." -ForegroundColor Yellow
        Write-WMTLog -LogPath $LogPath -Level WARN -Message "Limpieza segura cancelada."
        Pause-WMT
        return
    }

    if ($Config.Cleanup.UserTemp) {
        Invoke-WMTSafeChildCleanup -Path $env:TEMP -LogPath $LogPath
    }

    if ($Config.Cleanup.WindowsTemp) {
        Invoke-WMTSafeChildCleanup -Path (Join-Path $env:WINDIR "Temp") -LogPath $LogPath
    }

    if ($Config.Cleanup.WindowsUpdateCache) {
        Write-Host "Limpiando caché de Windows Update..." -ForegroundColor Cyan
        Write-WMTLog -LogPath $LogPath -Message "Iniciando limpieza de caché de Windows Update."

        try {
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            Stop-Service bits -Force -ErrorAction SilentlyContinue
            Invoke-WMTSafeChildCleanup -Path (Join-Path $env:WINDIR "SoftwareDistribution\Download") -LogPath $LogPath
        }
        finally {
            Start-Service bits -ErrorAction SilentlyContinue
            Start-Service wuauserv -ErrorAction SilentlyContinue
        }
    }

    if ($Config.Cleanup.RecycleBin) {
        Write-Host "Vaciando la papelera..." -ForegroundColor Cyan
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-WMTLog -LogPath $LogPath -Message "Papelera vaciada."
        }
        catch {
            Write-WMTLog -LogPath $LogPath -Level WARN -Message "No se pudo vaciar completamente la papelera: $($_.Exception.Message)"
        }
    }

    if ($Config.Cleanup.DismComponentCleanup) {
        Write-Host "Limpiando componentes antiguos de Windows..." -ForegroundColor Cyan
        Write-WMTLog -LogPath $LogPath -Message "Ejecutando DISM StartComponentCleanup."
        & dism.exe /Online /Cleanup-Image /StartComponentCleanup
        Write-WMTLog -LogPath $LogPath -Message "DISM terminó con código $LASTEXITCODE."
    }

    $after = Get-WMTFreeSpaceGB
    Write-Host ""
    if ($null -ne $after) {
        Write-Host "Espacio libre después: $after GB" -ForegroundColor Green
        if ($null -ne $before) {
            $freed = [math]::Round($after - $before, 2)
            Write-Host "Espacio recuperado aproximadamente: $freed GB" -ForegroundColor Green
            Write-WMTLog -LogPath $LogPath -Message "Espacio recuperado aproximado: $freed GB."
        }
    }

    Pause-WMT
}

Export-ModuleMember -Function Invoke-WMTSafeCleanup
