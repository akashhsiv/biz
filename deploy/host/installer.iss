; ERP Host — Inno Setup installer.
; Same thin-wrapper approach as installer.nsi: bundles the package built by build-release.ps1
; into Program Files and runs install.bat/uninstall.bat, which own all the actual logic.
;
; Build (from this directory, after build-release.ps1 has populated ..\dist\host-package\):
;   iscc installer.iss
; Requires Inno Setup (https://jrsoftware.org/isinfo.php) on the build machine — not on the target PC.

[Setup]
AppName=ERP Host
AppVersion=1.0
DefaultDirName={autopf}\ErpHost
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputBaseFilename=ErpHostSetup
OutputDir=.
Compression=lzma2
SolidCompression=yes

[Files]
Source: "..\dist\host-package\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Run]
Filename: "{cmd}"; Parameters: "/c ""{app}\install.bat"""; \
    Flags: runhidden waituntilterminated; \
    StatusMsg: "Provisioning PostgreSQL and registering the ERP Host service (this can take a minute)..."

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c ""{app}\uninstall.bat"""; \
    Flags: runhidden waituntilterminated; RunOnceId: "ErpHostUninstall"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\backend"
Type: filesandordirs; Name: "{app}\pgsql"
