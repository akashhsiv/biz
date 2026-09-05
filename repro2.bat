@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "BACKEND_DIR=C:\Program Files\ErpHost\backend"
echo BEFORE_SECTION5

echo sc query stub >nul 2>&1
if 1==0 (
    echo ErpHost service already registered, stopping for upgrade...
    echo net stop stub >nul 2>&1
) else (
    echo sc create ErpHost binPath= "\"%BACKEND_DIR%\Erp.Api.exe\"" start= auto DisplayName= "ERP Host" >nul
    echo sc failure ErpHost reset= 86400 actions= restart/60000/restart/60000/restart/60000 >nul
)
echo reg add stub >nul

echo AFTER_SC_BLOCK

echo netsh show stub >nul 2>&1
if 1==0 (
    echo netsh advfirewall firewall add rule name="ERP Host API" dir=in action=allow protocol=TCP localport=5000 profile=private,domain >nul
)

echo AFTER_FIREWALL_BLOCK

echo net start stub
if 1==0 (
    echo ErpHost service failed to start
    exit /b 1
)
echo AFTER_NETSTART_BLOCK

if exist "C:\nonexistent_client\erp_client.exe" (
    echo shortcut stub
    echo Desktop/Start Menu shortcut created
)

echo AFTER_SHORTCUT_BLOCK
echo === Install complete ===
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do echo Slave PCs should connect to: %%a:5000
echo Default login: admin / ChangeMe123!
echo DONE
endlocal
