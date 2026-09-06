; ERP desktop client — NSIS installer.
; A single client app for every install — role-based permissions decide what a signed-in user can
; do, so there's no separate build variant. See app_shell.dart / auth permission gating.
;
; Build (from this directory, after build-release.ps1 has populated ..\dist\client-package):
;   makensis installer.nsi   -> ErpClientSetup.exe
; Requires NSIS (https://nsis.sourceforge.io/) on the build machine — not on the target PC.

!define PACKAGE_DIR "..\dist\client-package"
!define OUT_NAME "ErpClientSetup.exe"
!define APP_NAME "ERP"

; See installer.nsi in deploy\host\ for why these are set explicitly - this NSIS install's icon
; set doesn't include the bare "modern-install.ico"/"modern-uninstall.ico" MUI2 defaults to.
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install-colorful.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall-colorful.ico"

!include "MUI2.nsh"

Name "${APP_NAME}"
OutFile "${OUT_NAME}"
InstallDir "$PROGRAMFILES64\ErpApp"
RequestExecutionLevel admin
Unicode true

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
    ; Re-installing/upgrading while the app is still running locks erp_client.exe (and its DLLs),
    ; which blocks NSIS from overwriting them below - close it first. Errors are expected and
    ; ignored if it isn't running.
    nsExec::ExecToLog '"$SYSDIR\taskkill.exe" /IM erp_client.exe /F'
    Pop $0

    SetOutPath "$INSTDIR"
    File /r "${PACKAGE_DIR}\*.*"

    nsExec::ExecToLog '"$SYSDIR\cmd.exe" /c ""$INSTDIR\install.bat""'
    Pop $0

    ; Native NSIS shortcut instead of the PowerShell/WScript.Shell route install.bat used to take -
    ; matches the proven pattern from this org's other installer (MugilAngadi\installer.nsi).
    ; Points at %ProgramFiles%\ErpApp\erp_client.exe, not $INSTDIR\app\erp_client.exe - install.bat
    ; xcopies app\ flattened into %ProgramFiles%\ErpApp, which is where the app actually runs from.
    CreateShortcut "$DESKTOP\ERP.lnk" "$PROGRAMFILES64\ErpApp\erp_client.exe"
    CreateShortcut "$SMPROGRAMS\ERP.lnk" "$PROGRAMFILES64\ErpApp\erp_client.exe"

    WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
    nsExec::ExecToLog '"$SYSDIR\cmd.exe" /c ""$INSTDIR\uninstall.bat""'
    Pop $0

    Delete "$DESKTOP\ERP.lnk"
    Delete "$SMPROGRAMS\ERP.lnk"

    RMDir /r "$INSTDIR\app"
    Delete "$INSTDIR\install.bat"
    Delete "$INSTDIR\uninstall.bat"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir "$INSTDIR"
SectionEnd
