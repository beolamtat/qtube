@echo off
chcp 65001 >nul
title QTube - Đóng gói ứng dụng Windows

echo ===================================================
echo   Đóng gói QTube Standalone (Tự chạy không cần cài .NET)
echo ===================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% neq 0 (
    echo [!] Máy tính của bạn chưa cài .NET SDK.
    echo Vui lòng tải .NET 8.0 SDK từ: https://dotnet.microsoft.com/download/dotnet/8.0
    pause
    exit /b 1
)

set OUTPUT_DIR=%~dp0..\dist\QTube-Windows-x64
echo [*] Đang build và publish ra thư mục: %OUTPUT_DIR%
cd /d "%~dp0QTube.Windows"
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o "%OUTPUT_DIR%"

if %errorlevel% equ 0 (
    echo.
    echo ===================================================
    echo   THÀNH CÔNG!
    echo   File chạy được lưu tại: %OUTPUT_DIR%\QTube.Windows.exe
    echo   Bạn có thể mở thư mục trên và chạy trực tiếp!
    echo ===================================================
    explorer "%OUTPUT_DIR%"
) else (
    echo.
    echo [!] Đóng gói thất bại. Vui lòng kiểm tra thông báo lỗi phía trên.
)
pause
