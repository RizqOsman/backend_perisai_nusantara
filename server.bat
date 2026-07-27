@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================================
:: Backend Perisai Nusantara - Windows Server Management Script
:: ============================================================
:: Usage:
::   server.bat start    - Start server
::   server.bat stop     - Stop server
::   server.bat restart  - Restart server
::   server.bat status   - Check server status
::   server.bat install  - Install dependencies
::   server.bat dev      - Start in development mode (nodemon)
:: ============================================================

:: --- Configuration ---
set "APP_NAME=Backend Perisai Nusantara"
set "APP_DIR=%~dp0"
:: Remove trailing backslash
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"
set "APP_ENTRY=app.js"
set "LOG_DIR=%APP_DIR%\logs"
set "DATA_DIR=%APP_DIR%\data"
set "LOG_FILE=%LOG_DIR%\server.log"
set "PID_FILE=%LOG_DIR%\server.pid"
set "ENV_FILE=%APP_DIR%\.env"

:: --- Banner ---
echo.
echo ========================================
echo   Backend Perisai Nusantara Server
echo ========================================
echo.

:: --- Route Command ---
if "%~1"=="" goto :usage
if /i "%~1"=="start" goto :start
if /i "%~1"=="stop" goto :stop
if /i "%~1"=="restart" goto :restart
if /i "%~1"=="status" goto :status
if /i "%~1"=="install" goto :install
if /i "%~1"=="dev" goto :dev
goto :usage

:: ============================================================
:: START - Jalankan server di background
:: ============================================================
:start
call :check_node
call :ensure_dirs
call :create_env_if_missing
call :check_modules

:: Baca PORT dari .env
set "PORT=5000"
if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
        set "KEY=%%a"
        :: Trim leading spaces
        for /f "tokens=*" %%k in ("!KEY!") do set "KEY=%%k"
        if "!KEY!"=="PORT" (
            set "VAL=%%b"
            for /f "tokens=*" %%v in ("!VAL!") do set "PORT=%%v"
        )
    )
)

:: Cek apakah sudah ada server running via PID file
if exist "%PID_FILE%" (
    set /p OLD_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !OLD_PID!" 2>nul | find /i "node" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [WARN]  Server sudah berjalan (PID: !OLD_PID!^)
        goto :eof
    )
)

:: Cek apakah port sudah dipakai
netstat -ano 2>nul | findstr ":!PORT! " | findstr "LISTENING" >nul 2>&1
if !errorlevel! equ 0 (
    echo [ERROR] Port !PORT! sudah digunakan oleh proses lain!
    echo         Gunakan: netstat -ano ^| findstr :!PORT!
    goto :eof
)

echo [INFO]  Starting %APP_NAME% pada port !PORT!...

:: Jalankan server di background via PowerShell
cd /d "%APP_DIR%"
powershell -Command "& { $p = Start-Process -FilePath 'node' -ArgumentList 'app.js' -WorkingDirectory '%APP_DIR%' -WindowStyle Hidden -PassThru; $p.Id | Out-File -FilePath '%PID_FILE%' -Encoding ascii -NoNewline }"

:: Tunggu server start
timeout /t 3 /nobreak >nul

:: Verifikasi dari PID file
if exist "%PID_FILE%" (
    set /p NEW_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !NEW_PID!" 2>nul | find /i "node" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [INFO]  Server berhasil dijalankan!
        echo [INFO]  PID: !NEW_PID!
        echo [INFO]  URL: http://localhost:!PORT!
    ) else (
        echo [ERROR] Server gagal start! Proses tidak aktif.
        del "%PID_FILE%" >nul 2>&1
    )
) else (
    echo [ERROR] Server gagal start! PID file tidak ditemukan.
)
goto :eof

:: ============================================================
:: STOP - Hentikan server
:: ============================================================
:stop
:: Baca PORT
set "PORT=5000"
if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
        set "KEY=%%a"
        for /f "tokens=*" %%k in ("!KEY!") do set "KEY=%%k"
        if "!KEY!"=="PORT" (
            set "VAL=%%b"
            for /f "tokens=*" %%v in ("!VAL!") do set "PORT=%%v"
        )
    )
)

:: Coba dari PID file dulu
if exist "%PID_FILE%" (
    set /p PID=<"%PID_FILE%"
    tasklist /FI "PID eq !PID!" 2>nul | find /i "node" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [INFO]  Menghentikan server (PID: !PID!^)...
        taskkill /PID !PID! /F >nul 2>&1
        del "%PID_FILE%" >nul 2>&1
        echo [INFO]  Server berhasil dihentikan.
        goto :eof
    ) else (
        del "%PID_FILE%" >nul 2>&1
    )
)

:: Fallback: cari dari port
set "FOUND_PID="
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":!PORT! " ^| findstr "LISTENING"') do (
    set "FOUND_PID=%%a"
)

if defined FOUND_PID (
    echo [INFO]  Ditemukan proses di port !PORT! (PID: !FOUND_PID!^). Menghentikan...
    taskkill /PID !FOUND_PID! /F >nul 2>&1
    del "%PID_FILE%" >nul 2>&1
    echo [INFO]  Server berhasil dihentikan.
) else (
    echo [WARN]  Server tidak sedang berjalan.
)
goto :eof

:: ============================================================
:: RESTART - Restart server
:: ============================================================
:restart
echo [INFO]  Restarting server...
call :stop
timeout /t 2 /nobreak >nul
call :start
goto :eof

:: ============================================================
:: STATUS - Cek status server
:: ============================================================
:status
:: Baca PORT
set "PORT=5000"
if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
        set "KEY=%%a"
        for /f "tokens=*" %%k in ("!KEY!") do set "KEY=%%k"
        if "!KEY!"=="PORT" (
            set "VAL=%%b"
            for /f "tokens=*" %%v in ("!VAL!") do set "PORT=%%v"
        )
    )
)

set "IS_RUNNING=0"
set "CURRENT_PID="

:: Cek dari PID file
if exist "%PID_FILE%" (
    set /p CURRENT_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !CURRENT_PID!" 2>nul | find /i "node" >nul 2>&1
    if !errorlevel! equ 0 set "IS_RUNNING=1"
)

:: Fallback: cek dari port
if !IS_RUNNING! equ 0 (
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":!PORT! " ^| findstr "LISTENING"') do (
        set "CURRENT_PID=%%a"
        set "IS_RUNNING=1"
    )
)

echo.
if !IS_RUNNING! equ 1 (
    echo [INFO]  Status  : RUNNING
    echo [INFO]  PID     : !CURRENT_PID!
    echo [INFO]  Port    : !PORT!
    echo [INFO]  URL     : http://localhost:!PORT!
    echo.
    :: Health check
    powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:!PORT!/health' -UseBasicParsing -TimeoutSec 5; if($r.StatusCode -eq 200) { Write-Host '[INFO]  Health  : OK' } else { Write-Host '[WARN]  Health  : FAILED' } } catch { Write-Host '[WARN]  Health  : FAILED (not responding)' }" 2>nul
    echo.
    :: Resource usage
    echo   Resource Usage:
    powershell -Command "Get-Process -Id !CURRENT_PID! -ErrorAction SilentlyContinue | Format-Table Id, CPU, @{N='Mem(MB)';E={[math]::Round($_.WorkingSet64/1MB,2)}}, StartTime -AutoSize" 2>nul
) else (
    echo [INFO]  Status  : STOPPED
)
echo.
goto :eof

:: ============================================================
:: INSTALL - Install dependencies
:: ============================================================
:install
call :check_node
echo [INFO]  Menginstall dependencies...
cd /d "%APP_DIR%"
npm install --production
echo [INFO]  Dependencies berhasil diinstall.
goto :eof

:: ============================================================
:: DEV - Development mode dengan nodemon
:: ============================================================
:dev
call :check_node
call :ensure_dirs
call :create_env_if_missing
call :check_modules

echo [INFO]  Starting development server (nodemon)...
cd /d "%APP_DIR%"
npx nodemon "%APP_ENTRY%"
goto :eof

:: ============================================================
:: Helper Functions
:: ============================================================

:check_node
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js tidak ditemukan! Silakan install Node.js.
    echo         https://nodejs.org/
    exit /b 1
)
for /f "tokens=*" %%v in ('node -v') do echo [INFO]  Node.js : %%v
goto :eof

:ensure_dirs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
goto :eof

:create_env_if_missing
if exist "%ENV_FILE%" goto :eof

echo [WARN]  File .env tidak ditemukan. Membuat default...

:: Generate random JWT secret
set "JWT_SECRET="
for /f "tokens=*" %%s in ('powershell -Command "-join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Max 16) })"') do set "JWT_SECRET=%%s"

if "!JWT_SECRET!"=="" set "JWT_SECRET=change_this_to_a_strong_secret_key_at_least_32_chars"

(
echo # Server
echo PORT=5000
echo HOST=0.0.0.0
echo.
echo # JWT
echo JWT_SECRET=!JWT_SECRET!
echo JWT_EXPIRES_IN=7d
echo.
echo # Database
echo DB_PATH=./data/perisai_nusantara.db
) > "%ENV_FILE%"

echo [INFO]  File .env berhasil dibuat.
goto :eof

:check_modules
if not exist "%APP_DIR%\node_modules" (
    echo [WARN]  node_modules tidak ditemukan. Running npm install...
    cd /d "%APP_DIR%"
    npm install
)
goto :eof

:: ============================================================
:: USAGE
:: ============================================================
:usage
echo Usage: %~nx0 {start^|stop^|restart^|status^|install^|dev}
echo.
echo Commands:
echo   start    - Jalankan server (production, background)
echo   stop     - Hentikan server
echo   restart  - Restart server
echo   status   - Cek status server + health check
echo   install  - Install dependencies (npm install)
echo   dev      - Jalankan development mode (nodemon)
echo.
goto :eof
