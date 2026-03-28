# ═══════════════════════════════════════════════════════
#  Context — сборка MSI через WiX 6
#  Запускать из корня проекта: .\build-msi.ps1
# ═══════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"
$Version    = "1.0.0"
$Manufacturer = "YourName"
$SourceDir  = "$PSScriptRoot\src-tauri\target\release"
$WxsFile    = "$PSScriptRoot\src-tauri\wix\main.wxs"
$OutDir     = "$PSScriptRoot\src-tauri\target\release\bundle\msi"
$OutFile    = "$OutDir\Context_${Version}_x64.msi"

# Проверить что exe собран
if (-not (Test-Path "$SourceDir\context.exe")) {
    Write-Host "context.exe не найден. Сначала запусти:" -ForegroundColor Red
    Write-Host "  npx tauri build --bundles none" -ForegroundColor Yellow
    exit 1
}

# Проверить текстуры
foreach ($tex in @("texture_dark.png", "texture_light.png")) {
    $p = "$SourceDir\assets\$tex"
    if (-not (Test-Path $p)) {
        Write-Host "Не найден: $p" -ForegroundColor Red
        Write-Host "Скопируй текстуры в src-tauri\assets\" -ForegroundColor Yellow
        exit 1
    }
}

# Создать папку для MSI
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "Сборка MSI через WiX 6..." -ForegroundColor Cyan

wix build $WxsFile `
    -d "Version=$Version" `
    -d "Manufacturer=$Manufacturer" `
    -d "SourceDir=$SourceDir" `
    -o $OutFile `
    -ext WixToolset.UI.wixext

if ($LASTEXITCODE -ne 0) {
    Write-Host "Ошибка сборки MSI" -ForegroundColor Red
    exit 1
}

$size = [math]::Round((Get-Item $OutFile).Length / 1MB, 1)
Write-Host ""
Write-Host "✅ MSI готов!" -ForegroundColor Green
Write-Host "   $OutFile" -ForegroundColor White
Write-Host "   Размер: ${size} MB" -ForegroundColor White
