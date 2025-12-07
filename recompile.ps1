$demoDir = "webcompiler"
$sourcesDir = "$demoDir/sources"
$filesJson = "$demoDir/files.json"
$lprFile = "$demoDir/webcompiler.lpr"
$binPath = "bin/pas2js.exe"
$fpcPath = "fpc"
$pas2js = "pas2js"

# New: verify required paths exist (fail fast)
function Report-Exists($label, $path) {
    if (Test-Path -LiteralPath $path) {
        $resolved = (Resolve-Path -LiteralPath $path).Path
        Write-Host "FOUND: $label => $resolved" -ForegroundColor Green
        return $true
    } else {
        Write-Host "MISSING: $label => $path" -ForegroundColor Red
        return $false
    }
}

$allOk = $true

# check demo dir and sources dir
$allOk = (Report-Exists "demoDir" $demoDir) -and $allOk
$allOk = (Report-Exists "sourcesDir" $sourcesDir) -and $allOk

# ensure files.json parent directory exists (files.json will be written)
$filesJsonParent = Split-Path -Parent $filesJson
$allOk = (Report-Exists "files.json parent" $filesJsonParent) -and $allOk

# check lpr file and compiler binary / fpc / pas2js paths
$allOk = (Report-Exists "lprFile" $lprFile) -and $allOk
$allOk = (Report-Exists "binPath (pas2js exe)" $binPath) -and $allOk
$allOk = (Report-Exists "fpcPath" $fpcPath) -and $allOk
$allOk = (Report-Exists "pas2js" $pas2js) -and $allOk

if (-not $allOk) {
    Write-Host "One or more required paths are missing. Aborting." -ForegroundColor Red
    exit 1
}

# warn if sources dir exists but is empty
$sourcesFiles = Get-ChildItem -Path $sourcesDir -File -ErrorAction SilentlyContinue
if (-not $sourcesFiles -or $sourcesFiles.Count -eq 0) {
    Write-Host "Warning: sources directory '$sourcesDir' contains no files." -ForegroundColor Yellow
}

Write-Host "Updating files.json..."
$files = Get-ChildItem -Path $sourcesDir -File | Select-Object -ExpandProperty Name
$files | ConvertTo-Json | Set-Content -Path $filesJson -Encoding UTF8

Write-Host "Compiling webcompiler.lpr..."
& $binPath -Tbrowser -Jc -O2 "-Fu$fpcPath/utils/pas2js" "-Fu$fpcPath/packages/fcl-json/src" "-Fu$fpcPath/packages/fcl-passrc/src" "-Fu$fpcPath/packages/pastojs/src" "-Fu$fpcPath/packages/fcl-js/src" "-Fu$pas2js/packages/*/src" $lprFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "Compilation Successful." -ForegroundColor Green
} else {
    Write-Host "Compilation Failed." -ForegroundColor Red
}
