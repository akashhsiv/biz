; ERP Slave/Host-desktop — NSIS installer.
; One script builds either package variant, selected at compile time — the install.bat logic and
; shortcut naming are identical either way, only the bundled app\ payload (and the exe's own
; cosmetic APP_VARIANT baked in at `flutter build` time) differs. See app_variant.dart.
;
; Build (from this directory, after build-release.ps1 has populated ..\dist\):
;   makensis /DVARIANT=slave installer.nsi   -> ErpSlaveSetup.exe      (installs from ..\dist\slave-package)
;   makensis /DVARIANT=host  installer.nsi   -> ErpSlaveHostSetup.exe  (installs from ..\dist\slave-host-package)
; Requires NSIS (https://nsis.sourceforge.io/) on the build machine — not on the target PC.

!ifndef VARIANT
    !define VARIANT "slave"
!endif

!if "${VARIANT}" == "host"
    !define PACKAGE_DIR "..\dist\slave-host-package"
    !define OUT_NAME "ErpSlaveHostSetup.exe"
    !define APP_NAME "ERP (Host desktop)"
!else
    !define PACKAGE_DIR "..\dist\slave-package"
    !define OUT_NAME "ErpSlaveSetup.exe"
    !define APP_NAME "ERP"
!endif

; See installer.nsi in deploy\host\ for why these are set explicitly - this NSIS install's icon
; set doesn't include the bare "modern-install.ico"/"modern-uninstall.ico" MUI2 defaults to.
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install-colorful.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall-colorful.ico"

!include "MUI2.nsh"

Name "${APP_NAME}"
OutFile "${OUT_NAME}"
InstallDir "$PROGRAMFILES64\ErpSlave"
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
    ; Points at %ProgramFiles%\ErpSlave\erp_client.exe, not $INSTDIR\app\erp_client.exe - install.bat
    ; xcopies app\ flattened into %ProgramFiles%\ErpSlave, which is where the app actually runs from.
    CreateShortcut "$DESKTOP\ERP.lnk" "$PROGRAMFILES64\ErpSlave\erp_client.exe"
    CreateShortcut "$SMPROGRAMS\ERP.lnk" "$PROGRAMFILES64\ErpSlave\erp_client.exe"

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
