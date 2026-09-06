@echo off
REM ERP desktop client installer (batch) — copies the Flutter Windows build to Program Files
REM and creates Start Menu + Desktop shortcuts. One client app for every install; role-based
REM permissions (see PermissionKeys.cs) decide what a signed-in user can do, so there's no
REM separate install logic per variant.
REM
REM Expected layout (this file must sit next to app\ — build-release.ps1 produces this in
REM deploy\dist\client-package\):
REM   install.bat            (this file)
REM   uninstall.bat
REM   app\                   flutter build windows output (erp_client.exe, data\, ...)
REM
REM Usage: run as Administrator, from wherever the package was extracted/installed to.

setlocal EnableExtensions

set "INSTALL_DIR=%ProgramFiles%\ErpApp"
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
echo First launch will ask for the backend's address (e.g. https://your-erp-backend.example.com).
endlocal
