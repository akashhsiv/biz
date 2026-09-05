@echo off
REM ERP Host uninstaller (batch) — removes the two Windows services and the firewall rule this
REM package created. Deliberately never touches %ProgramData%\ErpHost\pgdata or the backup
REM directory: financial/stock data is never destroyed by this project's own rule, and that
REM extends to "uninstall" — see project memory feedback_erp_development_process.
REM
REM Usage: run as Administrator.

setlocal EnableExtensions EnableDelayedExpansion

net session >nul 2>&1
if not %errorlevel%==0 (
    echo This uninstaller must be run as Administrator.
    exit /b 1
)

set "INSTALL_DIR=%~dp0"
set "PG_DIR=%INSTALL_DIR%pgsql"

echo Stopping ErpHost...
net stop ErpHost 2>nul
sc delete ErpHost >nul 2>&1

echo Stopping ErpPostgres...
net stop ErpPostgres 2>nul
if exist "%PG_DIR%\bin\pg_ctl.exe" (
    "%PG_DIR%\bin\pg_ctl.exe" unregister -N ErpPostgres
) else (
    sc delete ErpPostgres >nul 2>&1
)

netsh advfirewall firewall delete rule name="ERP Host API" >nul 2>&1
netsh advfirewall firewall delete rule name="ERP Host Discovery" >nul 2>&1

if exist "%INSTALL_DIR%whatsapp\win-service.cjs" (
    echo Stopping ERP WhatsApp Bridge...
    set "WA_NODE=%INSTALL_DIR%whatsapp\node.exe"
    if not exist "!WA_NODE!" set "WA_NODE=node"
    pushd "%INSTALL_DIR%whatsapp"
    "!WA_NODE!" win-service.cjs uninstall
    popd
)

del "%PUBLIC%\Desktop\ERP.lnk" 2>nul
del "%ProgramData%\Microsoft\Windows\Start Menu\Programs\ERP.lnk" 2>nul

echo.
echo === Uninstall complete ===
echo Database files (%ProgramData%\ErpHost\pgdata), the saved superuser password, and any backups were left untouched.
echo Delete them yourself only if you are certain you no longer need that data.
endlocal
