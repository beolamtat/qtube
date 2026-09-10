# PowerShell script to download official Windows binaries for QTube
# Run this script on Windows: powershell -ExecutionPolicy Bypass -File download-windows-tools.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$ToolsDir = Join-Path $ProjectDir "QTube.Windows\Tools"
$TempDir = Join-Path $ProjectDir "build\temp"

if (-not (Test-Path $ToolsDir)) {
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
}
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " QTube - Tải các công cụ phụ trợ cho Windows" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. yt-dlp.exe
$YtDlpPath = Join-Path $ToolsDir "yt-dlp.exe"
Write-Host "[1/3] Đang tải yt-dlp.exe mới nhất..." -ForegroundColor Yellow
Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile $YtDlpPath -UseBasicParsing
Write-Host " -> Đã tải yt-dlp.exe thành công!" -ForegroundColor Green

# 2. ffmpeg.exe
$FfmpegPath = Join-Path $ToolsDir "ffmpeg.exe"
if (-not (Test-Path $FfmpegPath)) {
    Write-Host "[2/3] Đang tải ffmpeg essentials cho Windows..." -ForegroundColor Yellow
    $FfmpegZip = Join-Path $TempDir "ffmpeg.zip"
    $FfmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    Invoke-WebRequest -Uri $FfmpegUrl -OutFile $FfmpegZip -UseBasicParsing
    
    Write-Host " -> Đang giải nén ffmpeg..." -ForegroundColor Yellow
    Expand-Archive -Path $FfmpegZip -DestinationPath $TempDir -Force
    $ExtractedFfmpeg = Get-ChildItem -Path $TempDir -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
    if ($ExtractedFfmpeg) {
        Copy-Item $ExtractedFfmpeg.FullName -Destination $FfmpegPath -Force
        Write-Host " -> Đã cài đặt ffmpeg.exe thành công!" -ForegroundColor Green
    }
} else {
    Write-Host "[2/3] ffmpeg.exe đã tồn tại, bỏ qua." -ForegroundColor Gray
}

# 3. QuickJS (quickjs-ng for Windows)
$QuickJsPath = Join-Path $ToolsDir "quickjs.exe"
if (-not (Test-Path $QuickJsPath)) {
    Write-Host "[3/3] Đang tải QuickJS JavaScript runtime..." -ForegroundColor Yellow
    $QjsZip = Join-Path $TempDir "quickjs.zip"
    $QjsUrl = "https://github.com/quickjs-ng/quickjs/releases/download/v0.16.2/qjs-windows-x86_64.zip"
    try {
        Invoke-WebRequest -Uri $QjsUrl -OutFile $QjsZip -UseBasicParsing
        Expand-Archive -Path $QjsZip -DestinationPath $TempDir -Force
        $ExtractedQjs = Get-ChildItem -Path $TempDir -Recurse -Filter "qjs.exe" | Select-Object -First 1
        if ($ExtractedQjs) {
            Copy-Item $ExtractedQjs.FullName -Destination $QuickJsPath -Force
            Write-Host " -> Đã cài đặt quickjs.exe thành công!" -ForegroundColor Green
        }
    } catch {
        Write-Host " -> Cảnh báo: Không tải được QuickJS tự động. yt-dlp vẫn chạy bình thường với browser fallback." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "[3/3] quickjs.exe đã tồn tại, bỏ qua." -ForegroundColor Gray
}

# Dọn dẹp thư mục tạm
if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Hoàn tất! Tất cả công cụ đã sẵn sàng trong: " -ForegroundColor Green
Write-Host " $ToolsDir" -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan
