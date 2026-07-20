@echo off
setlocal
title Windows Maintenance Toolkit

set "SCRIPT=%~dp0src\WMT.ps1"

if not exist "%SCRIPT%" (
    echo ERROR: No se encuentra "%SCRIPT%".
    echo Comprueba que has descomprimido todo el repositorio.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

if errorlevel 1 (
    echo.
    echo WMT finalizo con un codigo de error.
    pause
)

endlocal
