@echo off
title Stop PHP + MySQL Server

set PHP_SERVICE=PHPServer
set MYSQL_SERVICE=MySQLPortable

:: Check admin
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [ERROR] Please run as Administrator.
    pause & exit /b 1
)

echo [INFO] Stopping PHP service...
net stop %PHP_SERVICE% >nul 2>&1
echo [OK] PHP stopped.

echo [INFO] Stopping MySQL service...
net stop %MYSQL_SERVICE% >nul 2>&1
echo [OK] MySQL stopped.

echo.
echo All services stopped.
pause