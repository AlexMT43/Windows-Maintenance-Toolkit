function Export-WMTSystemReport {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [AllowNull()][string]$LogPath
    )

    Clear-Host
    Write-Host "=== INFORME DEL SISTEMA ===" -ForegroundColor Cyan

    $reportDir = Join-Path $RepositoryRoot "logs"
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    $path = Join-Path $reportDir ("SystemReport_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("WINDOWS MAINTENANCE TOOLKIT - INFORME DEL SISTEMA")
    $lines.Add("Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add("Equipo: $env:COMPUTERNAME")
    $lines.Add("")

    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

        $lines.Add("Sistema operativo: $($os.Caption)")
        $lines.Add("Versión: $($os.Version)")
        $lines.Add("Arquitectura: $($os.OSArchitecture)")
        $lines.Add("Fabricante: $($cs.Manufacturer)")
        $lines.Add("Modelo: $($cs.Model)")
        $lines.Add("CPU: $($cpu.Name)")
        $lines.Add("RAM total: $([math]::Round($cs.TotalPhysicalMemory / 1GB, 2)) GB")
        $lines.Add("")
        $lines.Add("UNIDADES:")

        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            $lines.Add(("{0} Total: {1} GB | Libre: {2} GB" -f
                $_.DeviceID,
                [math]::Round($_.Size / 1GB, 2),
                [math]::Round($_.FreeSpace / 1GB, 2)))
        }
    }
    catch {
        $lines.Add("ERROR al recopilar datos: $($_.Exception.Message)")
    }

    $lines | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Host ""
    Write-Host "Informe creado en:" -ForegroundColor Green
    Write-Host $path
    Write-WMTLog -LogPath $LogPath -Message "Informe del sistema creado: $path"
    Pause-WMT
}

function Export-WMTWingetApps {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [AllowNull()][string]$LogPath
    )

    Clear-Host
    Write-Host "=== EXPORTAR APLICACIONES DE WINGET ===" -ForegroundColor Cyan

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Host "WinGet no está disponible." -ForegroundColor Red
        Write-WMTLog -LogPath $LogPath -Level ERROR -Message "No se pudo exportar: WinGet no disponible."
        Pause-WMT
        return
    }

    $exportDir = Join-Path $RepositoryRoot "logs"
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
    $path = Join-Path $exportDir ("winget-packages_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

    & winget.exe export --output $path --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Listado exportado en:" -ForegroundColor Green
        Write-Host $path
        Write-WMTLog -LogPath $LogPath -Message "Aplicaciones WinGet exportadas: $path"
    }
    else {
        Write-Host "La exportación terminó con código $LASTEXITCODE." -ForegroundColor Yellow
        Write-WMTLog -LogPath $LogPath -Level WARN -Message "Exportación WinGet terminó con código $LASTEXITCODE."
    }

    Pause-WMT
}

Export-ModuleMember -Function Export-WMTSystemReport, Export-WMTWingetApps
