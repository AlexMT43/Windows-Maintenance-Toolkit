Set-StrictMode -Version 2.0

function Test-WMTAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-WMTElevated {
    param([Parameter(Mandatory=$true)][string]$ScriptPath)

    if (-not (Test-WMTAdministrator)) {
        Write-Host "Solicitando permisos de administrador..." -ForegroundColor Yellow
        $arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
        try {
            Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $arguments -ErrorAction Stop
        }
        catch {
            Write-Host "No se concedieron permisos de administrador. WMT no puede continuar." -ForegroundColor Red
            exit 1
        }
        exit
    }
}

function Get-WMTConfig {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot)

    $localPath = Join-Path $RepositoryRoot "config\config.local.json"
    $defaultPath = Join-Path $RepositoryRoot "config\config.json"
    $path = if (Test-Path -LiteralPath $localPath) { $localPath } else { $defaultPath }

    if (-not (Test-Path -LiteralPath $path)) {
        throw "No se encuentra el archivo de configuración: $path"
    }

    try {
        return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "El archivo de configuración no es válido: $($_.Exception.Message)"
    }
}

function Initialize-WMTLog {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [Parameter(Mandatory=$true)]$Config
    )

    if (-not $Config.EnableLogging) {
        return $null
    }

    $logDirectory = Join-Path $RepositoryRoot "logs"
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

    $retention = [int]$Config.LogRetentionDays
    if ($retention -gt 0) {
        Get-ChildItem -LiteralPath $logDirectory -Filter "*.log" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$retention) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    return Join-Path $logDirectory ("WMT_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
}

function Write-WMTLog {
    param(
        [AllowNull()][string]$LogPath,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO","WARN","ERROR")][string]$Level = "INFO"
    )

    if (-not $LogPath) { return }

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Pause-WMT {
    Write-Host ""
    [void](Read-Host "Pulsa ENTER para volver al menú")
}

function Get-WMTFreeSpaceGB {
    param([string]$DriveLetter = "C:")

    try {
        $escaped = $DriveLetter.Replace("'", "''")
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$escaped'"
        if ($null -eq $disk) { return $null }
        return [math]::Round($disk.FreeSpace / 1GB, 2)
    }
    catch {
        return $null
    }
}

# --- Protección frente a almacenamiento en la nube (Google Drive, OneDrive, Dropbox) ---
#
# Los archivos "solo en la nube" aparecen en disco como marcadores (placeholders)
# que ocupan 0 bytes. Borrarlos, o borrar sus carpetas, SINCRONIZA el borrado a
# la nube y elimina los datos reales. WMT nunca debe tocarlos.

function Test-WMTCloudPlaceholder {
    param([Parameter(Mandatory=$true)][System.IO.FileSystemInfo]$Item)

    try {
        $attr = [int64]$Item.Attributes
    }
    catch {
        # Si no podemos leer los atributos, asumimos lo peor y no lo tocamos.
        return $true
    }

    $FILE_ATTRIBUTE_REPARSE_POINT         = 0x400      # unión / enlace / marcador de nube
    $FILE_ATTRIBUTE_OFFLINE               = 0x1000     # contenido no residente localmente
    $FILE_ATTRIBUTE_RECALL_ON_OPEN        = 0x40000    # placeholder OneDrive/Drive
    $FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x400000   # archivo bajo demanda

    if ($attr -band $FILE_ATTRIBUTE_REPARSE_POINT)         { return $true }
    if ($attr -band $FILE_ATTRIBUTE_OFFLINE)               { return $true }
    if ($attr -band $FILE_ATTRIBUTE_RECALL_ON_OPEN)        { return $true }
    if ($attr -band $FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS) { return $true }

    return $false
}

function Get-WMTLocalFixedDriveRoots {
    # Devuelve solo unidades fijas respaldadas por un disco físico real.
    # Las unidades virtuales de nube (p. ej. G:\ de Google Drive) no tienen
    # partición asociada y quedan excluidas, aunque el sistema las declare "fijas".

    $letters = New-Object System.Collections.Generic.List[string]

    try {
        $partitions = Get-CimInstance Win32_DiskPartition -ErrorAction Stop
        foreach ($partition in $partitions) {
            Get-CimAssociatedInstance -InputObject $partition -ResultClassName Win32_LogicalDisk -ErrorAction SilentlyContinue |
                Where-Object { $_.DriveType -eq 3 } |
                ForEach-Object { if (-not $letters.Contains($_.DeviceID)) { $letters.Add($_.DeviceID) } }
        }
    }
    catch {
        # Silencioso: pasamos al respaldo.
    }

    if ($letters.Count -eq 0) {
        # Respaldo: unidades fijas con sistema de archivos local estándar.
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
            Where-Object { $_.FileSystem -in @("NTFS", "ReFS", "exFAT", "FAT32", "FAT") } |
            ForEach-Object { if (-not $letters.Contains($_.DeviceID)) { $letters.Add($_.DeviceID) } }
    }

    return @($letters | Sort-Object | ForEach-Object { "$_\" })
}

function Get-WMTCloudSyncExclusions {
    # Carpetas de sincronización conocidas que reflejan contenido de nube.
    $paths = New-Object System.Collections.Generic.List[string]

    $candidates = @(
        $env:OneDrive,
        $env:OneDriveConsumer,
        $env:OneDriveCommercial,
        (Join-Path $env:USERPROFILE "OneDrive"),
        (Join-Path $env:USERPROFILE "Google Drive"),
        (Join-Path $env:USERPROFILE "Dropbox"),
        (Join-Path $env:LOCALAPPDATA "Google\DriveFS"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive")
    )

    foreach ($c in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($c) -and -not $paths.Contains($c)) {
            $paths.Add($c)
        }
    }

    return @($paths)
}

function Invoke-WMTSafeChildCleanup {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [AllowNull()][string]$LogPath
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-WMTLog -LogPath $LogPath -Level WARN -Message "Ruta no encontrada: $Path"
        return
    }

    Write-Host "Limpiando: $Path" -ForegroundColor Cyan
    Write-WMTLog -LogPath $LogPath -Message "Limpiando contenido de $Path"

    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $item = $_
        if (Test-WMTCloudPlaceholder -Item $item) {
            Write-WMTLog -LogPath $LogPath -Level WARN -Message "Omitido (nube/placeholder): $($item.FullName)"
            return
        }
        try {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-WMTLog -LogPath $LogPath -Level WARN -Message "No se pudo eliminar $($item.FullName): $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function *
