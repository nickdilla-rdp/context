#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════════
#  Context — Release Build Script
#  Запустите из корня проекта: .\build-release.ps1
# ═══════════════════════════════════════════════════════════════

param(
    [string]$Version = "1.0.0",
    [switch]$Sign = $false,
    [string]$CertThumbprint = ""
)

$ErrorActionPreference = "Stop"
Write-Host "══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Context — Building release v$Version" -ForegroundColor Cyan  
Write-Host "══════════════════════════════════════" -ForegroundColor Cyan

# 1. Check prerequisites
Write-Host "`n[1/5] Checking prerequisites..." -ForegroundColor Yellow
$checks = @{
    "cargo"  = "Rust не установлен. Запустите: winget install Rustlang.Rustup"
    "node"   = "Node.js не установлен. Запустите: winget install OpenJS.NodeJS.LTS"
    "wix"    = "WiX не найден. Запустите: dotnet tool install --global wix"
}
foreach ($cmd in $checks.Keys) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "  ✗ $($checks[$cmd])" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ $cmd" -ForegroundColor Green
}

# 2. Install npm deps
Write-Host "`n[2/5] Installing npm dependencies..." -ForegroundColor Yellow
npm install --silent
if ($LASTEXITCODE -ne 0) { Write-Host "npm install failed" -ForegroundColor Red; exit 1 }

# 3. Download fonts if not present
if (-not (Test-Path "src\fonts\fonts.css")) {
    Write-Host "`n[3/5] Downloading fonts..." -ForegroundColor Yellow
    & "$PSScriptRoot\download-fonts.ps1"
} else {
    Write-Host "`n[3/5] Fonts already downloaded ✓" -ForegroundColor Green
}

# 4. Sign setup (optional)
if ($Sign -and $CertThumbprint) {
    Write-Host "`n[4/5] Code signing enabled: $CertThumbprint" -ForegroundColor Yellow
    $env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD = ""
    # Set in tauri.conf.json or via env vars
} else {
    Write-Host "`n[4/5] Skipping code signing (use -Sign -CertThumbprint to enable)" -ForegroundColor Gray
}

# 5. Build
Write-Host "`n[5/5] Building Tauri app..." -ForegroundColor Yellow
$env:TAURI_SKIP_DEVSERVER_CHECK = "true"
npx tauri build

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n✗ Build failed!" -ForegroundColor Red
    exit 1
}

# Show output
$msiPath = Get-ChildItem -Path "src-tauri\target\release\bundle\msi\*.msi" -ErrorAction SilentlyContinue | Select-Object -First 1
$exePath = "src-tauri\target\release\bundle\nsis\*.exe"

Write-Host "`n══════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✓ Build successful!" -ForegroundColor Green
Write-Host "══════════════════════════════════════" -ForegroundColor Green

if ($msiPath) {
    $size = [math]::Round($msiPath.Length / 1MB, 1)
    Write-Host "`n  MSI: $($msiPath.FullName)" -ForegroundColor White
    Write-Host "  Size: ${size} MB" -ForegroundColor White
}

Write-Host "`nExe size:"
$exeFile = "src-tauri\target\release\context.exe"
if (Test-Path $exeFile) {
    $exeSize = [math]::Round((Get-Item $exeFile).Length / 1MB, 1)
    Write-Host "  context.exe: ${exeSize} MB" -ForegroundColor White
}
