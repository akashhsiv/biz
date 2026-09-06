# Called by install.bat - creates Desktop + Start Menu shortcuts pointing at the installed exe.
# Kept as its own file rather than an inline `powershell -Command` in the batch script: multi-line
# -Command strings with embedded quotes are fragile to get right across cmd.exe's caret-continuation
# and PowerShell's own argument parsing, a plain -File call isn't.
param(
    [Parameter(Mandatory = $true)][string]$InstallDir
)

$ErrorActionPreference = "Stop"
$exePath = Join-Path $InstallDir "erp_client.exe"
$shell = New-Object -ComObject WScript.Shell

$desktop = $shell.CreateShortcut((Join-Path $env:PUBLIC "Desktop\ERP.lnk"))
$desktop.TargetPath = $exePath
$desktop.WorkingDirectory = $InstallDir
$desktop.Save()

$startMenuDir = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
$startMenu = $shell.CreateShortcut((Join-Path $startMenuDir "ERP.lnk"))
$startMenu.TargetPath = $exePath
$startMenu.WorkingDirectory = $InstallDir
$startMenu.Save()
