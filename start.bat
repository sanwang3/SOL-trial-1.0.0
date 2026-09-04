@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

echo.
echo ========================================
echo    Solana Monitor - Start Script
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] Checking Rust environment...
where rustc >nul 2>&1
if %errorlevel% neq 0 (
    echo [Error] Rust not installed
    echo [Hint] Visit https://rustup.rs/ to install Rust
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('rustc --version') do set RUST_VERSION=%%i
echo [OK] Rust installed: %RUST_VERSION%

echo.
echo [2/3] Building project...
if exist "target\release\sol-monitor.exe" (
    echo [OK] Detected existing binary
    set /p REBUILD="Rebuild? (y/N): "
    if /i "!REBUILD!" neq "y" goto :run
)

echo Building, this may take a few minutes...
cargo build --release
if %errorlevel% neq 0 (
    echo [Error] Build failed
    pause
    exit /b 1
)
echo [OK] Build complete

:run
echo.
echo [3/3] Starting monitor service...
echo.
echo ========================================
echo    Solana Monitor - Running
echo ========================================
echo.
echo   Web Panel: http://localhost:8080
echo   Press Ctrl+C to stop
echo ========================================
echo.

start /b cmd /c "timeout /t 3 >nul && start http://localhost:8080"

target\release\sol-monitor.exe

pause
