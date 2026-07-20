function Get-WMTEmptyFolderRoots {
    param([Parameter(Mandatory=$true)]$Config)

    if ($Config.EmptyFolderScan.Mode -eq "Custom") {
        return @($Config.EmptyFolderScan.CustomRoots | Where-Object { Test-Path -LiteralPath $_ })
    }

    # Solo unidades físicas reales. Nunca unidades virtuales de nube (Google Drive, etc.).
    return @(Get-WMTLocalFixedDriveRoots)
}

function Test-WMTExcludedPath {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][object[]]$ExcludedPaths
    )

    foreach ($excluded in $ExcludedPaths) {
        if ([string]::IsNullOrWhiteSpace([string]$excluded)) { continue }

        $normalized = ([string]$excluded).TrimEnd("\")
        if ($Path.Equals($normalized, [StringComparison]::OrdinalIgnoreCase) -or
            $Path.StartsWith($normalized + "\", [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Invoke-WMTEmptyFolderRemoval {
    param(
        [Parameter(Mandatory=$true)]$Config,
        [AllowNull()][string]$LogPath
    )

    Clear-Host
    Write-Host "=== ELIMINAR CARPETAS VACÍAS ===" -ForegroundColor Cyan
    Write-Host ""

    $roots = @(Get-WMTEmptyFolderRoots -Config $Config)
    if ($roots.Count -eq 0) {
        Write-Host "No se encontraron unidades o rutas válidas." -ForegroundColor Red
        Write-WMTLog -LogPath $LogPath -Level ERROR -Message "No hay raíces válidas para el análisis."
        Pause-WMT
        return
    }

    Write-Host "Rutas que se analizarán:" -ForegroundColor Yellow
    $roots | ForEach-Object { Write-Host " - $_" }
    Write-Host ""
    Write-Host "Se omitirán rutas críticas, enlaces simbólicos y puntos de unión." -ForegroundColor DarkYellow
    Write-Host "No se tocan unidades de nube ni archivos solo en la nube (Drive, OneDrive)." -ForegroundColor DarkYellow
    Write-Host "El análisis completo de varias unidades puede tardar bastante." -ForegroundColor DarkYellow

    if ((Read-Host "Escribe ELIMINAR para continuar") -cne "ELIMINAR") {
        Write-Host "Operación cancelada." -ForegroundColor Yellow
        Write-WMTLog -LogPath $LogPath -Level WARN -Message "Eliminación de carpetas vacías cancelada."
        Pause-WMT
        return
    }

    $skipCloud = $true
    if ($null -ne $Config.EmptyFolderScan.PSObject.Properties['SkipCloudFiles']) {
        $skipCloud = [bool]$Config.EmptyFolderScan.SkipCloudFiles
    }

    $excluded = @($Config.EmptyFolderScan.ExcludePaths) + @(Get-WMTCloudSyncExclusions)
    $removed = 0
    $failed = 0
    $skipped = 0

    foreach ($root in $roots) {
        Write-Host ""
        Write-Host "Analizando $root ..." -ForegroundColor Cyan
        Write-WMTLog -LogPath $LogPath -Message "Analizando carpetas vacías en $root"

        Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object {
                -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
                -not (Test-WMTExcludedPath -Path $_.FullName -ExcludedPaths $excluded)
            } |
            Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object {
                $dir = $_

                # Salvaguarda crítica: nunca borrar marcadores de nube (Drive/OneDrive/Dropbox).
                # Borrarlos sincroniza el borrado a la nube y destruye los datos reales.
                if ($skipCloud -and (Test-WMTCloudPlaceholder -Item $dir)) {
                    $skipped++
                    Write-WMTLog -LogPath $LogPath -Level WARN -Message "Omitida (nube/placeholder): $($dir.FullName)"
                    return
                }

                try {
                    if (@($dir.EnumerateFileSystemInfos()).Count -eq 0) {
                        Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop
                        Write-Host "Eliminando: $($dir.FullName)"
                        Write-WMTLog -LogPath $LogPath -Message "Carpeta vacía eliminada: $($dir.FullName)"
                        $removed++
                    }
                }
                catch {
                    $failed++
                    Write-Host "ERROR: $($dir.FullName)" -ForegroundColor Red
                    Write-WMTLog -LogPath $LogPath -Level WARN -Message "No se pudo eliminar $($dir.FullName): $($_.Exception.Message)"
                }
            }
    }

    Write-Host ""
    Write-Host "$removed carpetas vacías eliminadas." -ForegroundColor Green
    if ($skipped -gt 0) {
        Write-Host "$skipped carpetas omitidas por protección de nube." -ForegroundColor Cyan
    }
    if ($failed -gt 0) {
        Write-Host "$failed carpetas no pudieron procesarse." -ForegroundColor Yellow
    }

    Pause-WMT
}

Export-ModuleMember -Function Invoke-WMTEmptyFolderRemoval
