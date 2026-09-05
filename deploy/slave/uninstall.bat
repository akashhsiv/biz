@echo off
REM ERP Slave/Host-desktop uninstaller (batch) — removes the installed app and its shortcuts.
REM There is no local data to preserve: the app only caches the saved Host URL and session token
REM (flutter_secure_storage/shared_preferences under the user's own profile), which Windows'
REM per-user app data is left alone by an all-users uninstall anyway.
REM
REM Usage: run as Administrator.

setlocal EnableExtensions

set "INSTALL_DIR=%ProgramFiles%\ErpSlave"

if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"
del "%PUBLIC%\Desktop\ERP.lnk" 2>nul
del "%ProgramData%\Microsoft\Windows\Start Menu\Programs\ERP.lnk" 2>nul

echo === Uninstall complete ===
endlocal
