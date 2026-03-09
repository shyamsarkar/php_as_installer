@echo off
setlocal EnableDelayedExpansion
title Start PHP + MySQL Server

set INSTALL_DIR=C:\php-app
set PHP_PORT=8000
set LOCK_FILE=%INSTALL_DIR%\.installed
set PHP_SERVICE=PHPServer
set MYSQL_SERVICE=MySQLPortable

:: Check admin
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [ERROR] Please run as Administrator.
    pause & exit /b 1
)

:: Check installed
if not exist "%LOCK_FILE%" (
    echo [ERROR] App is not installed yet. Please run INSTALL.bat first.
    pause & exit /b 1
)

:: Start MySQL
echo [INFO] Checking MySQL service...
sc query %MYSQL_SERVICE% | find "RUNNING" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [INFO] Starting MySQL...
    net start %MYSQL_SERVICE% >nul 2>&1
    echo [OK] MySQL started.
) else (
    echo [OK] MySQL already running.
)

:: Start PHP service
echo [INFO] Checking PHP service...
sc query %PHP_SERVICE% | find "RUNNING" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [INFO] Starting PHP service...
    net start %PHP_SERVICE% >nul 2>&1
    if %errorLevel% NEQ 0 (
        echo [ERROR] PHP service failed to start.
        echo         Check logs at %INSTALL_DIR%\php-error.log
        pause & exit /b 1
    )
    echo [OK] PHP service started.
) else (
    echo [OK] PHP service already running.
)

echo.
echo   Server  : http://localhost:%PHP_PORT%
echo   Logs    : %INSTALL_DIR%\php-server.log
echo   Errors  : %INSTALL_DIR%\php-error.log
echo.
echo [TIP] Both services auto-start on Windows boot.
echo [TIP] Use stop-server.bat to stop.
pause
endlocal