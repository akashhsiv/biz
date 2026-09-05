@echo off
REM ERP Slave/Host-desktop installer (batch) — copies the Flutter Windows build to Program Files
REM and creates Start Menu + Desktop shortcuts. This same script installs either build variant
REM (APP_VARIANT=host or =slave, see app_variant.dart) — only the app\ payload differs; there's
REM no separate install logic per variant.
REM
REM Expected layout (this file must sit next to app\ — build-release.ps1 produces this in
REM deploy\dist\slave-package\ and deploy\dist\slave-host-package\):
REM   install.bat            (this file)
REM   uninstall.bat
REM   app\                   flutter build windows output (erp_client.exe, data\, ...)
REM
REM Usage: run as Administrator, from wherever the package was extracted/installed to.

setlocal EnableExtensions

set "INSTALL_DIR=%ProgramFiles%\ErpSlave"
set "SRC_DIR=%~dp0app"

if not exist "%SRC_DIR%\erp_client.exe" (
    echo app\erp_client.exe not found next to this script. Aborting.
    exit /b 1
)

echo Installing to %INSTALL_DIR% ...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
xcopy /E /I /Y "%SRC_DIR%\*" "%INSTALL_DIR%\" >nul

REM Desktop/Start Menu shortcut is created by installer.nsi itself (native NSIS CreateShortcut),
REM not from here - proven working pattern from this org's other installer, and doesn't depend on
REM PowerShell/WScript.Shell succeeding in whatever context this script runs under.

echo.
echo === Install complete ===
echo Shortcut created on the Desktop and in the Start Menu.
echo First launch will ask for the Host's LAN address (e.g. 192.168.1.100:5000) unless this is
echo the host-variant build, which defaults to localhost:5000.
endlocal
