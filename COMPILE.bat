@echo off
setlocal
cd /d "%~dp0"
title LS:RP - Compile
set "CEF_PHONE_DEFINE="
if /I "%~1"=="cef" set "CEF_PHONE_DEFINE=GTASANVN_CEF_PHONE=1"

if not exist "qawno\pawncc.exe" (
    echo [ERROR] Khong tim thay qawno\pawncc.exe
    pause
    exit /b 1
)

if not exist "qawno\include\a_mysql.inc" goto deps
if not exist "qawno\include\samp_bcrypt.inc" goto deps
if not exist "qawno\include\YSI_Coding\y_hooks.inc" goto deps
goto compile

:deps
echo Dang cai dependency...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup_dependencies.ps1"
if errorlevel 1 (
    echo [ERROR] Khong cai duoc dependency.
    pause
    exit /b 1
)

:compile
echo.
echo ===== COMPILE LS:RP BASE =====
"qawno\pawncc.exe" "gamemodes\main.pwn" -i"qawno\include" -o"gamemodes\main.amx" %CEF_PHONE_DEFINE%
if errorlevel 1 (
    echo.
    echo [FAILED] Compile co loi. Gui log compiler cho ChatGPT.
    pause
    exit /b 1
)

if not exist "gamemodes\main.amx" (
    echo [ERROR] Khong tao duoc gamemodes\main.amx
    pause
    exit /b 1
)

echo.
echo [OK] gamemodes\main.amx
pause
exit /b 0
