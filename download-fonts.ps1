# Run this once to download all fonts for offline use
# Then fonts will load even without internet connection

$fontsDir = "$PSScriptRoot\src\fonts"
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null

$googleFontsUrl = "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Bebas+Neue&family=Russo+One&family=Dela+Gothic+One&family=Rubik+Mono+One&family=Days+One&family=Alegreya+Sans+SC:wght@400;500;700&family=Cormorant+SC:wght@400;500;600;700&display=swap"

Write-Host "Downloading Google Fonts CSS..."
$headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
$css = Invoke-WebRequest -Uri $googleFontsUrl -Headers $headers -UseBasicParsing

# Extract all woff2 URLs
$urls = [regex]::Matches($css.Content, 'url\((https://[^)]+\.woff2)\)') | ForEach-Object { $_.Groups[1].Value }

Write-Host "Found $($urls.Count) font files, downloading..."
$fontFaces = $css.Content

foreach ($url in $urls) {
    $filename = [System.IO.Path]::GetFileName($url) -replace '\?.*',''
    $localPath = "$fontsDir\$filename"
    if (-not (Test-Path $localPath)) {
        Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing
        Write-Host "  Downloaded: $filename"
    }
    $fontFaces = $fontFaces -replace [regex]::Escape($url), "./fonts/$filename"
}

# Save the modified CSS with local paths
$fontFaces | Out-File -FilePath "$PSScriptRoot\src\fonts\fonts.css" -Encoding UTF8
Write-Host "`nDone! Now update index.html:"
Write-Host "Replace Google Fonts <link> tags with:"
Write-Host '  <link rel="stylesheet" href="fonts/fonts.css">'
