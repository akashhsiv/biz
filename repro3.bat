@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "PG_SUPER_PASS=abc123"
set "BACKEND_DIR=C:\Program Files\ErpHost\backend"
set "PG_DIR=C:\Program Files\ErpHost\pgsql"
set "PGPORT=5433"
set "DB_NAME=erp"
set "DB_USER=erp_app"
set "LOGFILE=C:\temp\testlog.txt"
set "INSTALL_DIR=C:\Program Files\ErpHost\"
echo BEFORE_SECTION3

if not defined PG_SUPER_PASS (
    echo This is an existing data directory - re-enter the postgres superuser password to
    echo confirm/create the erp_app role and erp database - leave blank to skip this step.
    set /p PG_SUPER_PASS="postgres superuser password: "
)

if defined PG_SUPER_PASS (
    echo for /f stub >APP_DB_PASS%%p
    set "APP_DB_PASS=xyz"
    set "PGPASSWORD=!PG_SUPER_PASS!"
    echo psql stub 1
    echo psql stub 2
    set "PGPASSWORD="

    echo powershell stub
    echo Role/database created and appsettings.Production.json written >> "%LOGFILE%"
) else (
    echo Skipped role/database creation and appsettings.Production.json generation.
    echo You must create them manually before the ErpHost service will start correctly.
    echo WARNING: skipped role/database creation - no superuser password available >> "%LOGFILE%"
)

echo AFTER_SECTION4

sc query stub >nul 2>&1
if 1==0 (
    echo ErpHost service already registered, stopping for upgrade...
) else (
    echo sc create ErpHost binPath= "\"%BACKEND_DIR%\Erp.Api.exe\"" start= auto DisplayName= "ERP Host" >nul
    echo sc failure ErpHost reset= 86400 actions= restart/60000/restart/60000/restart/60000 >nul
)
echo reg add stub >nul

echo AFTER_SC_BLOCK

net start stub
if 1==0 (
    echo ErpHost service failed to start
    exit /b 1
)
echo AFTER_NETSTART_BLOCK

echo === Install complete ===
echo DONE
endlocal
