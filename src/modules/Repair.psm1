function Invoke-WMTWindowsRepair {
    param([AllowNull()][string]$LogPath)

    Clear-Host
    Write-Host "=== COMPROBAR Y REPARAR WINDOWS ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Se ejecutarán:" -ForegroundColor White
    Write-Host " - DISM /Online /Cleanup-Image /RestoreHealth"
    Write-Host " - SFC /scannow"
    Write-Host ""
    Write-Host "El proceso puede tardar y requiere conexión para algunas reparaciones." -ForegroundColor Yellow

    if ((Read-Host "Escribe REPARAR para continuar") -cne "REPARAR") {
        Write-Host "Operación cancelada." -ForegroundColor Yellow
        Write-WMTLog -LogPath $LogPath -Level WARN -Message "Reparación de Windows cancelada."
        Pause-WMT
        return
    }

    Write-WMTLog -LogPath $LogPath -Message "Ejecutando DISM RestoreHealth."
    & dism.exe /Online /Cleanup-Image /RestoreHealth
    Write-WMTLog -LogPath $LogPath -Message "DISM RestoreHealth terminó con código $LASTEXITCODE."

    Write-WMTLog -LogPath $LogPath -Message "Ejecutando SFC /scannow."
    & sfc.exe /scannow
    Write-WMTLog -LogPath $LogPath -Message "SFC terminó con código $LASTEXITCODE."

    Pause-WMT
}

function Invoke-WMTFlushDns {
    param([AllowNull()][string]$LogPath)

    Clear-Host
    Write-Host "=== LIMPIAR CACHÉ DNS ===" -ForegroundColor Cyan
    Write-WMTLog -LogPath $LogPath -Message "Ejecutando ipconfig /flushdns."
    & ipconfig.exe /flushdns
    Write-WMTLog -LogPath $LogPath -Message "ipconfig /flushdns terminó con código $LASTEXITCODE."
    Pause-WMT
}

Export-ModuleMember -Function Invoke-WMTWindowsRepair, Invoke-WMTFlushDns
