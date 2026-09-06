; ERP desktop client — Inno Setup installer.
; Same thin-wrapper approach as installer.nsi. A single client app for every install —
; role-based permissions decide what a signed-in user can do.
;
; Build (from this directory, after build-release.ps1 has populated ..\dist\client-package):
;   iscc installer.iss   -> ErpClientSetup.exe
; Requires Inno Setup (https://jrsoftware.org/isinfo.php) on the build machine — not on the target PC.

#define PackageDir "..\dist\client-package"
#define OutName "ErpClientSetup"
#define AppName "ERP"

[Setup]
AppName={#AppName}
AppVersion=1.0
DefaultDirName={autopf}\ErpApp
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputBaseFilename={#OutName}
OutputDir=.
Compression=lzma2
SolidCompression=yes

[Files]
Source: "{#PackageDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Run]
Filename: "{cmd}"; Parameters: "/c ""{app}\install.bat"""; \
    Flags: runhidden waituntilterminated; StatusMsg: "Installing..."

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c ""{app}\uninstall.bat"""; \
    Flags: runhidden waituntilterminated; RunOnceId: "ErpClientUninstall"
