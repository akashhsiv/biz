# Stages everything the Host and client installers (install.bat plus the NSIS/Inno wrappers around
# it) need, into deploy\dist\. Run this before compiling installer.nsi/installer.iss, or before
# zipping a package for the batch-only install path.
#
# Usage (from anywhere):
#   powershell -ExecutionPolicy Bypass -File deploy\build-release.ps1
#
# Requires: .NET 9 SDK and Flutter on PATH. Does NOT require NSIS/Inno Setup - those only compile
# the GUI wrappers afterward, separately, and are not needed to produce a working batch-only package.
param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$deployRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $deployRoot
$distRoot = Join-Path $deployRoot "dist"

function Step($message) {
    Write-Host ""
    Write-Host "=== $message ===" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------------------------
# Host package: backend publish + install/uninstall scripts + (preserved) pgsql\ binaries
# ---------------------------------------------------------------------------------------------
Step "Publishing backend (win-x64, self-contained)"
$hostPackageDir = Join-Path $distRoot "host-package"
$backendOut = Join-Path $hostPackageDir "backend"
$backendProj = Join-Path $repoRoot "backend\src\Erp.Api\Erp.Api.csproj"

New-Item -ItemType Directory -Force -Path $hostPackageDir | Out-Null
if (Test-Path $backendOut) { Remove-Item -Recurse -Force $backendOut }

dotnet publish $backendProj -c $Configuration -r win-x64 --self-contained true `
    -p:PublishSingleFile=false -o $backendOut
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed with exit code $LASTEXITCODE" }

Copy-Item (Join-Path $deployRoot "host\install.bat") $hostPackageDir -Force
Copy-Item (Join-Path $deployRoot "host\uninstall.bat") $hostPackageDir -Force

$pgsqlDir = Join-Path $hostPackageDir "pgsql"
if (-not (Test-Path (Join-Path $pgsqlDir "bin\pg_ctl.exe"))) {
    # A full PostgreSQL install (via the official installer, not just the portable zip) has the
    # same bin\/lib\/share\ layout the portable "binaries" zip does - reuse it directly if this
    # build machine happens to have one, instead of always requiring a separate portable download.
    $localPg = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\pg_ctl.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($localPg) {
        $localPgRoot = Split-Path (Split-Path $localPg.FullName)
        Write-Host "Found local PostgreSQL install at $localPgRoot - copying bin\/lib\/share\ into pgsql\"
        New-Item -ItemType Directory -Force -Path $pgsqlDir | Out-Null
        foreach ($sub in "bin", "lib", "share") {
            Copy-Item (Join-Path $localPgRoot $sub) (Join-Path $pgsqlDir $sub) -Recurse -Force
        }
    } else {
        New-Item -ItemType Directory -Force -Path $pgsqlDir | Out-Null
        @"
This folder must contain the PostgreSQL Windows x86-64 "binaries" zip (portable, no installer)
extracted directly here, so that pgsql\bin\pg_ctl.exe exists.

Download from EnterpriseDB's PostgreSQL Windows binaries page - pick the version matching what
this project developed/tested against (PostgreSQL 16) and the "binaries" zip, not the interactive
installer. Extract its contents (bin\, lib\, share\, ...) into this folder, then re-run
build-release.ps1 (it will detect pg_ctl.exe and stop overwriting this folder) or just run
install.bat directly if packaging by hand.

Alternatively, if this build machine already has PostgreSQL installed (via the normal installer,
e.g. under C:\Program Files\PostgreSQL\<version>\), build-release.ps1 will detect and reuse its
bin\/lib\/share\ folders automatically next run - no manual copy needed in that case.
"@ | Set-Content (Join-Path $pgsqlDir "README-PUT-POSTGRESQL-BINARIES-HERE.txt")
        Write-Warning "pgsql\ has no PostgreSQL binaries yet - see host-package\pgsql\README-PUT-POSTGRESQL-BINARIES-HERE.txt"
    }
} else {
    Write-Host "pgsql\ already has PostgreSQL binaries, leaving as-is."
}

# ---------------------------------------------------------------------------------------------
# PDF rendering: bundle a pre-downloaded Chromium so PuppeteerPdfRenderer never needs to fetch it
# at runtime on the shop PC - that shop PC has no internet by design (ARCHITECTURE.md), and a
# multi-hundred-MB download on the first PDF click would blow well past any reasonable timeout.
# ---------------------------------------------------------------------------------------------
Step "Bundling Chromium for PDF rendering"
$chromiumDest = Join-Path $backendOut "chromium-cache"
if (-not (Test-Path (Join-Path $chromiumDest "Chrome"))) {
    $localChromiumCache = Get-ChildItem (Join-Path $repoRoot "backend\src\Erp.Api\bin") -Recurse -Directory -Filter "chromium-cache" -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "Chrome") } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($localChromiumCache) {
        Write-Host "Found a previously-downloaded Chromium cache at $($localChromiumCache.FullName) - copying into backend\chromium-cache\"
        Copy-Item $localChromiumCache.FullName $chromiumDest -Recurse -Force
    } else {
        Write-Warning "No local Chromium cache found under backend\src\Erp.Api\bin\**\chromium-cache - PDF rendering will try to download Chromium on first use on the target PC, which requires internet access and will likely time out. Run the backend locally once (any PDF request) to populate a cache, then re-run build-release.ps1."
    }
} else {
    Write-Host "backend\chromium-cache\ already bundled, leaving as-is."
}

# ---------------------------------------------------------------------------------------------
# WhatsApp bridge: bundled into the Host package too, so install.bat can register it as its own
# Windows service (ERP WhatsApp Bridge) - it must auto-start on its own, a shop can't be expected
# to run `npm start` by hand.
# ---------------------------------------------------------------------------------------------
Step "Staging the WhatsApp bridge (node_modules + bundled node.exe)"
$waSourceDir = Join-Path $repoRoot "whatsapp-service"
$waPackageDir = Join-Path $hostPackageDir "whatsapp"

if (-not (Test-Path (Join-Path $waSourceDir "node_modules"))) {
    Push-Location $waSourceDir
    try {
        npm install
        if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
}

if (Test-Path $waPackageDir) { Remove-Item -Recurse -Force $waPackageDir }
New-Item -ItemType Directory -Force -Path $waPackageDir | Out-Null
foreach ($item in "index.js", "win-service.cjs", "package.json", "package-lock.json", "node_modules") {
    $src = Join-Path $waSourceDir $item
    if (Test-Path $src) { Copy-Item $src (Join-Path $waPackageDir $item) -Recurse -Force }
}

$waNodeExe = Join-Path $waPackageDir "node.exe"
if (-not (Test-Path $waNodeExe)) {
    $localNode = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($localNode) {
        Write-Host "Bundling local Node.js runtime from $($localNode.Source)"
        Copy-Item $localNode.Source $waNodeExe -Force
    } else {
        Write-Warning "No local node.exe found - whatsapp\ will fall back to a system-installed Node.js at install time, or you can drop node.exe in there by hand."
    }
}

# ---------------------------------------------------------------------------------------------
# Client package: a single Flutter build for every install — one app, permissions/role decide
# what a signed-in user can do, so there's no separate variant to build.
# ---------------------------------------------------------------------------------------------
Step "Building Flutter Windows app"
$frontendDir = Join-Path $repoRoot "frontend"
Push-Location $frontendDir
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$clientPackageDir = Join-Path $distRoot "client-package"
$appOut = Join-Path $clientPackageDir "app"
New-Item -ItemType Directory -Force -Path $clientPackageDir | Out-Null
if (Test-Path $appOut) { Remove-Item -Recurse -Force $appOut }

$flutterReleaseDir = Join-Path $frontendDir "build\windows\x64\runner\Release"
Copy-Item $flutterReleaseDir $appOut -Recurse

Copy-Item (Join-Path $deployRoot "client\install.bat") $clientPackageDir -Force
Copy-Item (Join-Path $deployRoot "client\uninstall.bat") $clientPackageDir -Force
Copy-Item (Join-Path $deployRoot "client\make-shortcuts.ps1") $clientPackageDir -Force

# ---------------------------------------------------------------------------------------------
# Bundle the client app into the Host package too, so ErpHostSetup.exe alone gives whoever runs
# the backend a desktop shortcut to actually use the app, not just a running backend service with
# nothing to click.
# ---------------------------------------------------------------------------------------------
Step "Bundling the client app into the Host package"
$clientDir = Join-Path $hostPackageDir "client"
if (Test-Path $clientDir) { Remove-Item -Recurse -Force $clientDir }
Copy-Item $appOut $clientDir -Recurse
Copy-Item (Join-Path $deployRoot "client\make-shortcuts.ps1") $hostPackageDir -Force

Step "Done"
Write-Host "Packages staged under $distRoot :"
Write-Host "  host-package\    -> zip as-is for the batch-only install path, or compile"
Write-Host "                     deploy\host\installer.nsi / installer.iss against it"
Write-Host "  client-package\  -> the single desktop client, for every install (makensis/iscc, or as-is)"

