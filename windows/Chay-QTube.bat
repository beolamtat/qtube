@echo off
chcp 65001 >nul
title QTube - Trình tải YouTube Hàng loạt

echo ===================================================
echo   QTube Native cho Windows (WinUI 3 / C#)
echo ===================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% neq 0 (
    echo [!] Máy tính của bạn chưa cài .NET SDK.
    echo Vui lòng tải và cài đặt .NET 8.0 SDK từ:
    echo https://dotnet.microsoft.com/download/dotnet/8.0
    echo.
    pause
    exit /b 1
)

echo [*] Đang biên dịch và khởi chạy QTube...
cd /d "%~dp0QTube.Windows"
dotnet run -c Release -r win-x64

if %errorlevel% neq 0 (
    echo.
    echo [!] Khởi chạy gặp lỗi. Bạn có thể mở dự án bằng Visual Studio 2022 để xem chi tiết.
    pause
)
