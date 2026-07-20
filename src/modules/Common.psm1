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
        try {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-WMTLog -LogPath $LogPath -Level WARN -Message "No se pudo eliminar $($item.FullName): $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function *
