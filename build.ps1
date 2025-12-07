$ErrorActionPreference = "Stop"

$demoDir = "webcompiler"
$sourcesDir = "$demoDir/sources"
$filesJson = "$demoDir/files.json"
$lprFile = "$demoDir/webcompiler.lpr"
$fpcPath = "fpc"
$pas2jsPath = "pas2js"

# --- Compiler Download Logic ---

$downloadUrl = "https://getpas2js.freepascal.org/downloads/windows/pas2js-win64-x86_64-current.zip"
$compilerDist = "compiler_dist"
$localBin = "bin/pas2js.exe"
$foundBin = ""

# 1. Check environment variable
if ($env:PAS2JS_BIN -and (Test-Path $env:PAS2JS_BIN)) {
    $foundBin = $env:PAS2JS_BIN
}
# 2. Check local bin folder
elseif (Test-Path $localBin) {
    $foundBin = $localBin
}
# 3. Check PATH (simple check)
elseif (Get-Command "pas2js.exe" -ErrorAction SilentlyContinue) {
    $foundBin = "pas2js.exe"
}

# 4. Download if missing
if (-not $foundBin) {
    Write-Host "Compiler not found. Downloading..." -ForegroundColor Cyan
    
    if (-not (Test-Path $compilerDist)) {
        New-Item -ItemType Directory -Force -Path $compilerDist | Out-Null
    }

    $zipFile = Join-Path $compilerDist "pas2js.zip"
    
    # Download
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile
    }
    catch {
        Write-Error "Failed to download compiler: $_"
        exit 1
    }

    Write-Host "Extracting..." -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath $compilerDist -Force

    # Locate the binary
    $foundFiles = Get-ChildItem -Path $compilerDist -Filter "pas2js.exe" -Recurse -File
    if ($foundFiles) {
        $foundBin = $foundFiles[0].FullName
        Write-Host "Found compiler at: $foundBin" -ForegroundColor Green
    } else {
        Write-Error "Could not find pas2js.exe in extracted files."
        exit 1
    }
} else {
    Write-Host "Using compiler: $foundBin" -ForegroundColor Green
}

# --- Setup & Compile ---

# Verify required paths
if (-not (Test-Path $sourcesDir)) {
    Write-Error "Sources directory '$sourcesDir' not found."
    exit 1
}

if (-not (Test-Path $fpcPath)) {
    Write-Error "FPC directory '$fpcPath' not found. Did you check out submodules?"
    exit 1
}

# Generate files.json
Write-Host "Generating $filesJson..." -ForegroundColor Cyan
$files = Get-ChildItem -Path $sourcesDir -File | Sort-Object Name | Select-Object -ExpandProperty Name
$files | ConvertTo-Json | Set-Content -Path $filesJson -Encoding UTF8

# Check crucial unit
$cacheUnit = Join-Path $fpcPath "utils/pas2js/webfilecache.pp"
if (-not (Test-Path $cacheUnit)) {
    Write-Warning "Crucial unit '$cacheUnit' not found. Compilation might fail."
}

# Compile
Write-Host "Compiling $lprFile..." -ForegroundColor Cyan

$params = @(
    "-Tbrowser",
    "-Jc",
    "-O2",
    "-Fu$fpcPath/utils/pas2js",
    "-Fu$fpcPath/packages/fcl-json/src",
    "-Fu$fpcPath/packages/fcl-passrc/src",
    "-Fu$fpcPath/packages/pastojs/src",
    "-Fu$fpcPath/packages/fcl-js/src",
    "-Fu$pas2jsPath/packages/*/src",
    $lprFile
)

& $foundBin $params

if ($LASTEXITCODE -eq 0) {
    Write-Host "Compilation Successful." -ForegroundColor Green
} else {
    Write-Host "Compilation Failed." -ForegroundColor Red
    exit 1
}