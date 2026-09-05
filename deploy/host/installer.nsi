; ERP Host — NSIS installer.
; This is a thin GUI wrapper: it copies the same package layout install.bat already knows how to
; provision (backend\, pgsql\, install.bat, uninstall.bat) into Program Files, then runs
; install.bat/uninstall.bat as-is. All the actual install/uninstall logic lives in those two batch
; files (see install.bat's header comment) so there is exactly one place to fix if it's wrong.
;
; Build (from this directory, after build-release.ps1 has populated ..\dist\host-package\):
;   makensis installer.nsi
; Requires NSIS (https://nsis.sourceforge.io/) on the build machine — not needed on the target PC.

; This NSIS install's icon set doesn't include the bare "modern-install.ico"/"modern-uninstall.ico"
; MUI2 defaults to (only the -blue/-full/-colorful variants exist) - point at one that's actually
; present rather than let the missing default abort the build.
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install-colorful.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall-colorful.ico"

!include "MUI2.nsh"
!include "LogicLib.nsh"

Name "ERP Host"
OutFile "ErpHostSetup.exe"
InstallDir "$PROGRAMFILES64\ErpHost"
RequestExecutionLevel admin
Unicode true

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
    ; Re-installing/upgrading over an already-running install: PostgreSQL, the ERP Host API, and
    ; the WhatsApp bridge all hold their own .exe/.dll files open while running, which blocks NSIS
    ; from overwriting them below (File /r fails silently on locked files, or errors out) - stop
    ; all three first. Errors are expected and ignored on a first-ever install, where none of these
    ; services exist yet.
    DetailPrint "Stopping any existing ERP Host services before installing..."
    nsExec::ExecToLog '"$SYSDIR\net.exe" stop ErpHost'
    Pop $0
    nsExec::ExecToLog '"$SYSDIR\net.exe" stop "ERP WhatsApp Bridge"'
    Pop $0
    nsExec::ExecToLog '"$SYSDIR\net.exe" stop ErpPostgres'
    Pop $0

    SetOutPath "$INSTDIR"
    File /r "..\dist\host-package\*.*"

    DetailPrint "Provisioning PostgreSQL and registering the ERP Host service (this can take a minute)..."
    nsExec::ExecToLog '"$SYSDIR\cmd.exe" /c ""$INSTDIR\install.bat""'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_OK|MB_ICONSTOP "install.bat failed with exit code $0.$\r$\nCheck C:\ProgramData\ErpHost\install.log, or run $INSTDIR\install.bat manually from an elevated prompt to see the full output."
    ${EndIf}

    ; Native NSIS shortcut instead of the PowerShell/WScript.Shell route install.bat used to take -
    ; matches the proven pattern from this org's other installer (MugilAngadi\installer.nsi).
    IfFileExists "$INSTDIR\client\erp_client.exe" 0 +3
        CreateShortcut "$DESKTOP\ERP.lnk" "$INSTDIR\client\erp_client.exe"
        CreateShortcut "$SMPROGRAMS\ERP.lnk" "$INSTDIR\client\erp_client.exe"

    WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
    nsExec::ExecToLog '"$SYSDIR\cmd.exe" /c ""$INSTDIR\uninstall.bat""'
    Pop $0

    Delete "$DESKTOP\ERP.lnk"
    Delete "$SMPROGRAMS\ERP.lnk"

    RMDir /r "$INSTDIR\backend"
    RMDir /r "$INSTDIR\pgsql"
    RMDir /r "$INSTDIR\client"
    RMDir /r "$INSTDIR\whatsapp"
    Delete "$INSTDIR\install.bat"
    Delete "$INSTDIR\uninstall.bat"
    Delete "$INSTDIR\find-free-port.ps1"
    Delete "$INSTDIR\make-shortcuts.ps1"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir "$INSTDIR"
SectionEnd
