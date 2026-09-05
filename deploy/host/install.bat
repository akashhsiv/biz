@echo off
REM ERP Host installer (batch) - provisions a local PostgreSQL instance, applies the backend's own
REM EF Core migrations, and registers both PostgreSQL and the ERP Host API as Windows services.
REM
REM This script is the single source of truth for the install steps. installer.nsi and
REM installer.iss are thin GUI wrappers that copy this same package layout to Program Files and
REM then run this file - so there is only one place that actually knows how to install the Host.
REM
REM Every significant command's REAL output (not just a checkpoint message) is captured into
REM %ProgramData%\ErpHost\install.log via the "run > step.txt 2>&1 / type step.txt / type step.txt
REM >> log" pattern below - the GUI installer's own progress window only shows a live scroll that's
REM gone once it closes, so nothing that matters should depend on that being the only record.
REM
REM Expected layout (this file must sit next to these folders - this is exactly what
REM build-release.ps1 produces in deploy\dist\host-package\, and what both GUI installers extract):
REM   install.bat            (this file)
REM   uninstall.bat
REM   find-free-port.ps1
REM   backend\               dotnet publish output (Erp.Api.exe, appsettings.json, ...)
REM   pgsql\                 PostgreSQL portable Windows binaries (bin\, lib\, share\) - see the
REM                          README.txt this script writes into pgsql\ if that folder is empty.
REM   client\                (optional) the Flutter client app, host-flavored - installer.nsi
REM                          creates a Desktop/Start Menu shortcut to it if present (native NSIS
REM                          CreateShortcut, not from this script).
REM
REM Usage: run as Administrator, from wherever the package was extracted/installed to.
REM   install.bat [port]      (port auto-picked, starting at 5432, if omitted - a dev/shop PC
REM                            may already have PostgreSQL installed for other software, and
REM                            hardcoding 5432 would silently collide with it)

setlocal EnableExtensions EnableDelayedExpansion

set "LOGDIR=%ProgramData%\ErpHost"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOGFILE=%LOGDIR%\install.log"
set "STEP=%TEMP%\erphost_step.txt"
echo. >> "%LOGFILE%"
echo ==== install.bat run started %date% %time% ==== >> "%LOGFILE%"

net session >nul 2>&1
if not %errorlevel%==0 (
    echo This installer must be run as Administrator.
    echo FAILED: not running as Administrator >> "%LOGFILE%"
    exit /b 1
)
echo Admin check passed >> "%LOGFILE%"

set "INSTALL_DIR=%~dp0"
set "PG_DIR=%INSTALL_DIR%pgsql"
set "BACKEND_DIR=%INSTALL_DIR%backend"
set "PGDATA=%ProgramData%\ErpHost\pgdata"
set "PGPORT=%~1"
set "DB_NAME=erp"
set "DB_USER=erp_app"
echo INSTALL_DIR=%INSTALL_DIR% >> "%LOGFILE%"

if not exist "%PG_DIR%\bin\pg_ctl.exe" (
    echo.
    echo pgsql\ does not contain PostgreSQL binaries yet.
    echo Download the "PostgreSQL Windows x86-64 binaries" zip - no installer, portable - from
    echo EnterpriseDB's PostgreSQL download page, and extract it so that
    echo   "%PG_DIR%\bin\pg_ctl.exe" exists, then re-run this script.
    echo FAILED: pgsql\bin\pg_ctl.exe missing >> "%LOGFILE%"
    exit /b 1
)
echo pgsql binaries found >> "%LOGFILE%"

if not exist "%BACKEND_DIR%\Erp.Api.exe" (
    echo backend\Erp.Api.exe not found next to this script. Aborting.
    echo FAILED: backend\Erp.Api.exe missing >> "%LOGFILE%"
    exit /b 1
)
echo backend exe found >> "%LOGFILE%"

echo ---- port detection ---- >> "%LOGFILE%"
if "%PGPORT%"=="" (
    echo Picking a free port for PostgreSQL, starting at 5432...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%find-free-port.ps1" > "%STEP%" 2>&1
    type "%STEP%"
    type "%STEP%" >> "%LOGFILE%"
    for /f "usebackq delims=" %%p in ("%STEP%") do set "PGPORT=%%p"
)
if "%PGPORT%"=="" (
    echo Port auto-detection produced no output - falling back to 5432.
    echo WARNING: find-free-port.ps1 produced no output, falling back to 5432 >> "%LOGFILE%"
    set "PGPORT=5432"
)
echo Using port: %PGPORT% >> "%LOGFILE%"

echo === ERP Host installer ===
echo Install dir : %INSTALL_DIR%
echo PostgreSQL  : %PG_DIR%
echo Data dir    : %PGDATA%
echo Port        : %PGPORT%
echo Log file    : %LOGFILE%
echo.

REM ---------------------------------------------------------------------------
REM 1. Initialize the PostgreSQL data directory (first install only)
REM ---------------------------------------------------------------------------
if exist "%PGDATA%" (
    echo Data directory already exists, skipping initdb.
    echo Data directory already exists, skipping initdb >> "%LOGFILE%"
    if exist "%LOGDIR%\.superpass" (
        set /p PG_SUPER_PASS=<"%LOGDIR%\.superpass"
        echo Loaded saved superuser password from .superpass >> "%LOGFILE%"
    )
    goto :register_postgres
)

echo ---- generating superuser password ---- >> "%LOGFILE%"
powershell -NoProfile -Command "[guid]::NewGuid().ToString('N')" > "%STEP%" 2>&1
type "%STEP%" >> "%LOGFILE%"
for /f "usebackq delims=" %%p in ("%STEP%") do set "PG_SUPER_PASS=%%p"
if not defined PG_SUPER_PASS (
    echo Could not generate a superuser password - see install.log.
    echo FAILED: superuser password generation produced no output >> "%LOGFILE%"
    exit /b 1
)

mkdir "%ProgramData%\ErpHost" 2>nul
REM Persisted so a later re-run of this script (e.g. repairing a partial install) can create/
REM confirm the erp_app role without an interactive prompt - there's no console attached when
REM this runs through the GUI installer, so `set /p` for a password on that path silently gets no
REM input, breaking the whole role/credential setup that follows.
REM Written via PowerShell (not `echo ... > file`) so the file contains exactly the password with
REM no trailing CRLF.
powershell -NoProfile -Command "[System.IO.File]::WriteAllText('%LOGDIR%\.superpass', '%PG_SUPER_PASS%')"
powershell -NoProfile -Command "[System.IO.File]::WriteAllText('%TEMP%\erp_pg_super.txt', '%PG_SUPER_PASS%')"

echo ---- initdb ---- >> "%LOGFILE%"
"%PG_DIR%\bin\initdb.exe" -D "%PGDATA%" -U postgres -A scram-sha-256 --pwfile="%TEMP%\erp_pg_super.txt" -E UTF8 > "%STEP%" 2>&1
set "INITDB_RC=%errorlevel%"
type "%STEP%"
type "%STEP%" >> "%LOGFILE%"
del "%TEMP%\erp_pg_super.txt" >nul 2>&1
if not "%INITDB_RC%"=="0" (
    echo initdb failed with exit code %INITDB_RC%.
    echo FAILED: initdb exit code %INITDB_RC% >> "%LOGFILE%"
    exit /b %INITDB_RC%
)
echo initdb succeeded >> "%LOGFILE%"

REM Bind to localhost only - the Host's PostgreSQL is never exposed on the LAN, only the API is
REM (see ARCHITECTURE.md sec.9: "PostgreSQL's port is not opened on the firewall at all").
powershell -NoProfile -Command "(Get-Content '%PGDATA%\postgresql.conf') -replace '^#?listen_addresses\s*=.*', \"listen_addresses = 'localhost'\" | Set-Content '%PGDATA%\postgresql.conf'"
powershell -NoProfile -Command "(Get-Content '%PGDATA%\postgresql.conf') -replace '^#?port\s*=.*', 'port = %PGPORT%' | Set-Content '%PGDATA%\postgresql.conf'"

:register_postgres
REM ---------------------------------------------------------------------------
REM 2. Register + start PostgreSQL as a Windows service (safe to re-run)
REM ---------------------------------------------------------------------------
echo ---- registering ErpPostgres service ---- >> "%LOGFILE%"
sc query ErpPostgres >nul 2>&1
if %errorlevel%==0 (
    echo ErpPostgres service already registered.
    echo ErpPostgres service already registered >> "%LOGFILE%"
) else (
    "%PG_DIR%\bin\pg_ctl.exe" register -N "ErpPostgres" -D "%PGDATA%" -w > "%STEP%" 2>&1
    type "%STEP%"
    type "%STEP%" >> "%LOGFILE%"
    sc config ErpPostgres start= auto >nul
)
net start ErpPostgres > "%STEP%" 2>&1
type "%STEP%"
type "%STEP%" >> "%LOGFILE%"

echo Waiting for PostgreSQL to accept connections...
set "READY="
for /l %%i in (1,1,30) do (
    "%PG_DIR%\bin\pg_isready.exe" -h localhost -p %PGPORT% -U postgres >nul 2>&1
    if !errorlevel!==0 (
        set "READY=1"
        goto :pg_ready
    )
    timeout /t 1 /nobreak >nul
)
:pg_ready
if not defined READY (
    echo PostgreSQL did not become ready in time. Check %PGDATA%\log for details.
    echo FAILED: PostgreSQL never became ready on port %PGPORT% >> "%LOGFILE%"
    exit /b 1
)
echo PostgreSQL is ready on port %PGPORT% >> "%LOGFILE%"

REM ---------------------------------------------------------------------------
REM 3. Create the application role + database (idempotent)
REM ---------------------------------------------------------------------------
if not defined PG_SUPER_PASS (
    echo This is an existing data directory - re-enter the postgres superuser password to
    echo confirm/create the erp_app role and erp database - leave blank to skip this step.
    set /p PG_SUPER_PASS="postgres superuser password: "
)

if defined PG_SUPER_PASS (
    echo ---- generating app db password ---- >> "%LOGFILE%"
    powershell -NoProfile -Command "[guid]::NewGuid().ToString('N')" > "%STEP%" 2>&1
    type "%STEP%" >> "%LOGFILE%"
    for /f "usebackq delims=" %%p in ("%STEP%") do set "APP_DB_PASS=%%p"
    if not defined APP_DB_PASS (
        echo Could not generate an application database password - see install.log.
        echo FAILED: app db password generation produced no output >> "%LOGFILE%"
        exit /b 1
    )

    set "PGPASSWORD=!PG_SUPER_PASS!"

    echo ---- creating erp_app role ---- >> "%LOGFILE%"
    "%PG_DIR%\bin\psql.exe" -h localhost -p %PGPORT% -U postgres -v ON_ERROR_STOP=1 -c "DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='%DB_USER%') THEN CREATE ROLE %DB_USER% LOGIN PASSWORD '!APP_DB_PASS!'; ELSE ALTER ROLE %DB_USER% PASSWORD '!APP_DB_PASS!'; END IF; END $$;" > "%STEP%" 2>&1
    set "ROLE_RC=!errorlevel!"
    type "%STEP%"
    type "%STEP%" >> "%LOGFILE%"

    echo ---- checking whether erp database exists ---- >> "%LOGFILE%"
    "%PG_DIR%\bin\psql.exe" -h localhost -p %PGPORT% -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='%DB_NAME%'" > "%STEP%" 2>&1
    type "%STEP%" >> "%LOGFILE%"
    set "DB_EXISTS="
    for /f "usebackq delims=" %%v in ("%STEP%") do set "DB_EXISTS=%%v"

    if "!DB_EXISTS!"=="1" (
        echo erp database already exists, skipping creation >> "%LOGFILE%"
        set "DB_RC=0"
    ) else (
        echo ---- creating erp database ---- >> "%LOGFILE%"
        "%PG_DIR%\bin\psql.exe" -h localhost -p %PGPORT% -U postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE %DB_NAME% OWNER %DB_USER%" > "%STEP%" 2>&1
        set "DB_RC=!errorlevel!"
        type "%STEP%"
        type "%STEP%" >> "%LOGFILE%"
    )

    set "PGPASSWORD="

    if not "!ROLE_RC!"=="0" (
        echo Creating the erp_app role failed - see the psql error above.
        echo FAILED: erp_app role creation, psql exit code !ROLE_RC! >> "%LOGFILE%"
        exit /b 1
    )
    if not "!DB_RC!"=="0" (
        echo Creating the erp database failed - see the psql error above.
        echo FAILED: erp database creation, psql exit code !DB_RC! >> "%LOGFILE%"
        exit /b 1
    )

    REM ---------------------------------------------------------------------
    REM 4. Write appsettings.Production.json with the real connection string
    REM ---------------------------------------------------------------------
    powershell -NoProfile -Command "$s = Get-Content '%BACKEND_DIR%\appsettings.json' -Raw | ConvertFrom-Json; $s.ConnectionStrings.ErpDatabase = 'Host=localhost;Port=%PGPORT%;Database=%DB_NAME%;Username=%DB_USER%;Password=!APP_DB_PASS!'; $s | ConvertTo-Json -Depth 10 | Set-Content '%BACKEND_DIR%\appsettings.Production.json'" > "%STEP%" 2>&1
    type "%STEP%" >> "%LOGFILE%"
    echo Role/database created and appsettings.Production.json written >> "%LOGFILE%"
) else (
    echo Skipped role/database creation and appsettings.Production.json generation.
    echo You must create them manually before the ErpHost service will start correctly.
    echo WARNING: skipped role/database creation - no superuser password available >> "%LOGFILE%"
)

REM ---------------------------------------------------------------------------
REM 5. Register + start the ERP Host API as a Windows service
REM ---------------------------------------------------------------------------
echo ---- registering ErpHost service ---- >> "%LOGFILE%"
sc query ErpHost >nul 2>&1
if %errorlevel%==0 (
    echo ErpHost service already registered, stopping for upgrade...
    net stop ErpHost >nul 2>&1
) else (
    sc create ErpHost binPath= "\"%BACKEND_DIR%\Erp.Api.exe\"" start= auto DisplayName= "ERP Host" > "%STEP%" 2>&1
    type "%STEP%"
    type "%STEP%" >> "%LOGFILE%"
    sc failure ErpHost reset= 86400 actions= restart/60000/restart/60000/restart/60000 >nul
)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\ErpHost" /v Environment /t REG_MULTI_SZ /d "ASPNETCORE_ENVIRONMENT=Production" /f >nul

REM Only the API port is opened to the LAN - never PostgreSQL's port (ARCHITECTURE.md sec.9).
REM profile=any because Windows frequently classifies a shop's own router/Wi-Fi as "Public"
REM (default for any newly-joined network unless the admin manually marks it Private) - a
REM private,domain-only rule silently does nothing on such a network, which looked like a random
REM connection timeout from the Slave even though the service was running fine.
netsh advfirewall firewall show rule name="ERP Host API" >nul 2>&1
if not %errorlevel%==0 (
    netsh advfirewall firewall add rule name="ERP Host API" dir=in action=allow protocol=TCP localport=5000 profile=any >nul
) else (
    netsh advfirewall firewall set rule name="ERP Host API" new profile=any >nul
)

REM UDP broadcast so Slave PCs can auto-discover this Host instead of needing its IP typed in by
REM hand (HostDiscoveryBroadcastService). Outbound is allowed by default on Windows; only inbound
REM needs an explicit rule, same reasoning (and same profile=any fix) as the API port above.
netsh advfirewall firewall show rule name="ERP Host Discovery" >nul 2>&1
if not %errorlevel%==0 (
    netsh advfirewall firewall add rule name="ERP Host Discovery" dir=in action=allow protocol=UDP localport=45678 profile=any >nul
) else (
    netsh advfirewall firewall set rule name="ERP Host Discovery" new profile=any >nul
)

echo ---- starting ErpHost service ---- >> "%LOGFILE%"
net start ErpHost > "%STEP%" 2>&1
set "NETSTART_RC=%errorlevel%"
type "%STEP%"
type "%STEP%" >> "%LOGFILE%"
if not "%NETSTART_RC%"=="0" (
    echo ErpHost service failed to start - check Windows Event Viewer, Application log, for details.
    echo FAILED: net start ErpHost, exit code %NETSTART_RC% >> "%LOGFILE%"
    exit /b 1
)
echo ErpHost service started >> "%LOGFILE%"

REM ---------------------------------------------------------------------------
REM 7. Register + start the WhatsApp bridge as its own Windows service, if bundled
REM ---------------------------------------------------------------------------
if exist "%INSTALL_DIR%whatsapp\index.js" (
    echo ---- WhatsApp bridge ---- >> "%LOGFILE%"
    sc query "ERP WhatsApp Bridge" >nul 2>&1
    if %errorlevel%==0 (
        echo ERP WhatsApp Bridge service already registered.
        echo ERP WhatsApp Bridge service already registered >> "%LOGFILE%"
    ) else (
        set "WA_NODE=%INSTALL_DIR%whatsapp\node.exe"
        if not exist "!WA_NODE!" set "WA_NODE=node"

        powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%find-free-port.ps1" -StartPort 3001 > "%STEP%" 2>&1
        type "%STEP%" >> "%LOGFILE%"
        set "WA_PORT="
        for /f "usebackq delims=" %%p in ("%STEP%") do set "WA_PORT=%%p"
        if "!WA_PORT!"=="" set "WA_PORT=3001"
        echo Using WhatsApp bridge port: !WA_PORT! >> "%LOGFILE%"

        pushd "%INSTALL_DIR%whatsapp"
        del /q resolved-port.txt >nul 2>&1
        "!WA_NODE!" win-service.cjs install !WA_PORT! > "%STEP%" 2>&1
        REM win-service.cjs re-checks the port itself and walks forward to the next free one if this
        REM one got taken between our check above and its own (or if run by hand with a stale port) -
        REM resolved-port.txt always holds whichever port it actually bound the service to.
        if exist resolved-port.txt (
            set /p WA_PORT=<resolved-port.txt
        )
        popd
        type "%STEP%"
        type "%STEP%" >> "%LOGFILE%"
        echo Bridge service bound to port: !WA_PORT! >> "%LOGFILE%"

        REM Point the backend at whichever settings file it will actually read - Production if the
        REM DB/role setup above ran, otherwise the base file (ASP.NET falls back to it for any key
        REM missing from a skipped Production file).
        set "WA_SETTINGS_FILE=%BACKEND_DIR%\appsettings.json"
        if exist "%BACKEND_DIR%\appsettings.Production.json" set "WA_SETTINGS_FILE=%BACKEND_DIR%\appsettings.Production.json"
        powershell -NoProfile -Command "$s = Get-Content '!WA_SETTINGS_FILE!' -Raw | ConvertFrom-Json; if (-not $s.Whatsapp) { $s | Add-Member -NotePropertyName Whatsapp -NotePropertyValue (New-Object PSObject) }; $s.Whatsapp | Add-Member -NotePropertyName BaileysBaseUrl -NotePropertyValue 'http://localhost:!WA_PORT!' -Force; $s | ConvertTo-Json -Depth 10 | Set-Content '!WA_SETTINGS_FILE!'" > "%STEP%" 2>&1
        type "%STEP%" >> "%LOGFILE%"
        echo WhatsApp bridge configured at http://localhost:!WA_PORT! >> "%LOGFILE%"
    )
) else (
    echo WhatsApp bridge not bundled with this package, skipping >> "%LOGFILE%"
)

REM Desktop/Start Menu shortcut to the bundled client app is created by installer.nsi itself
REM (native NSIS CreateShortcut), not from here - that's the pattern already proven working in
REM this org's other installer, and doesn't depend on PowerShell/WScript.Shell succeeding.

echo.
echo === Install complete ===
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do echo Slave PCs should connect to: %%a:5000
echo Default login: admin / ChangeMe123! - change this immediately from the Users screen
echo ==== install.bat completed successfully %date% %time% ==== >> "%LOGFILE%"
del "%STEP%" >nul 2>&1
endlocal
