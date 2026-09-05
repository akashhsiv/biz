; ERP Slave/Host-desktop — Inno Setup installer.
; Same thin-wrapper approach as installer.nsi. One script, compiled twice with a different
; preprocessor define, produces either package variant.
;
; Build (from this directory, after build-release.ps1 has populated ..\dist\):
;   iscc /DVARIANT=slave installer.iss   -> ErpSlaveSetup.exe      (from ..\dist\slave-package)
;   iscc /DVARIANT=host  installer.iss   -> ErpSlaveHostSetup.exe  (from ..\dist\slave-host-package)
; Requires Inno Setup (https://jrsoftware.org/isinfo.php) on the build machine — not on the target PC.

#ifndef VARIANT
    #define VARIANT "slave"
#endif

#if VARIANT == "host"
    #define PackageDir "..\dist\slave-host-package"
    #define OutName "ErpSlaveHostSetup"
    #define AppName "ERP (Host desktop)"
#else
    #define PackageDir "..\dist\slave-package"
    #define OutName "ErpSlaveSetup"
    #define AppName "ERP"
#endif

[Setup]
AppName={#AppName}
AppVersion=1.0
DefaultDirName={autopf}\ErpSlave
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
    Flags: runhidden waituntilterminated; RunOnceId: "ErpSlaveUninstall"
