@echo off
setlocal EnableDelayedExpansion
title PHP + MySQL Uninstaller

set INSTALL_DIR=C:\php-app
set LOCK_FILE=%INSTALL_DIR%\.installed
set PHP_SERVICE=PHPServer
set MYSQL_SERVICE=MySQLPortable
set NSSM=%INSTALL_DIR%\nssm.exe
set MYSQL_DIR=%INSTALL_DIR%\mysql
set DB_ROOT_PASS=root123
set BACKUP_DIR=%USERPROFILE%\Desktop\php-app-backup

:: ============================================================
::  CHECK FOR ADMIN
:: ============================================================
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [ERROR] Please run this script as Administrator.
    echo Right-click UNINSTALL.bat and choose "Run as administrator"
    pause
    exit /b 1
)

:: ============================================================
::  CHECK IF INSTALLED
:: ============================================================
if not exist "%LOCK_FILE%" (
    echo.
    echo [INFO] No installation found at %INSTALL_DIR%
    echo        Nothing to uninstall.
    pause
    exit /b 0
)

:: ============================================================
::  CONFIRM UNINSTALL
:: ============================================================
echo.
echo ============================================================
echo   PHP + MySQL Uninstaller
echo ============================================================
echo.
echo   This will:
echo     - Stop PHP and MySQL services
echo     - Remove both Windows services
echo     - Delete all files in %INSTALL_DIR%
echo     - Remove PHP and MySQL from system PATH
echo.
echo   Your original app files will be DELETED.
echo   Make sure you have a backup if needed.
echo.
set /p CONFIRM="Type YES to confirm uninstall: "
if /i "!CONFIRM!" NEQ "YES" (
    echo [INFO] Uninstall cancelled.
    pause
    exit /b 0
)

:: ============================================================
::  CONFIRM UNINSTALL
:: ============================================================
echo.
echo ============================================================
echo   PHP + MySQL Uninstaller
echo ============================================================
echo.
echo   This will:
echo     - Stop PHP and MySQL services
echo     - Remove both Windows services
echo     - Delete all files in %INSTALL_DIR%
echo     - Remove PHP and MySQL from system PATH
echo.
echo   Your original app files will be DELETED.
echo   Make sure you have a backup if needed.
echo.

:: Ask about backup first
set TAKE_BACKUP=no
set /p BACKUP_CHOICE="Take database backup before uninstalling? (yes/no): "
if /i "!BACKUP_CHOICE!"=="yes" set TAKE_BACKUP=yes

echo.
set /p CONFIRM="Type YES to confirm uninstall: "
if /i "!CONFIRM!" NEQ "YES" (
    echo [INFO] Uninstall cancelled.
    pause
    exit /b 0
)

echo.
echo [INFO] Starting uninstall...
echo.

:: ============================================================
::  STEP 1/5 — DATABASE BACKUP
:: ============================================================
echo [STEP 1/5] Database backup...
if /i "!TAKE_BACKUP!"=="yes" (

    :: Make sure MySQL is running for backup
    sc query %MYSQL_SERVICE% | find "RUNNING" >nul 2>&1
    if %errorLevel% NEQ 0 (
        echo [INFO] Starting MySQL for backup...
        net start %MYSQL_SERVICE% >nul 2>&1
        timeout /t 3 /nobreak >nul
    )

    :: Create backup folder on Desktop with timestamp
    set TIMESTAMP=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
    set TIMESTAMP=!TIMESTAMP: =0!
    set BACKUP_PATH=%BACKUP_DIR%_!TIMESTAMP!
    mkdir "!BACKUP_PATH!" >nul 2>&1

    :: Dump all databases
    echo [INFO] Backing up all databases...
    "%MYSQL_DIR%\bin\mysqldump.exe" -u root -p%DB_ROOT_PASS% --all-databases > "!BACKUP_PATH!\all-databases.sql" 2>nul

    if exist "!BACKUP_PATH!\all-databases.sql" (
        echo [OK] Database backup saved to:
        echo      !BACKUP_PATH!\all-databases.sql
    ) else (
        echo [WARN] Backup may have failed. Check manually before proceeding.
        set /p PROCEED="Continue uninstall anyway? (yes/no): "
        if /i "!PROCEED!" NEQ "yes" (
            echo [INFO] Uninstall cancelled. Your data is safe.
            pause
            exit /b 0
        )
    )
) else (
    echo [INFO] Skipping backup.
)

:: ============================================================
::  STOP SERVICES
:: ============================================================
echo [STEP 2/5] Stopping services...
net stop %PHP_SERVICE% >nul 2>&1
echo [OK] PHP service stopped.
net stop %MYSQL_SERVICE% >nul 2>&1
echo [OK] MySQL service stopped.

:: ============================================================
::  REMOVE SERVICES
:: ============================================================
echo [STEP 3/5] Removing Windows services...

:: Remove PHP service via NSSM
if exist "%NSSM%" (
    "%NSSM%" remove %PHP_SERVICE% confirm >nul 2>&1
    echo [OK] PHP service removed.
) else (
    sc delete %PHP_SERVICE% >nul 2>&1
    echo [OK] PHP service removed.
)

:: Remove MySQL service
sc delete %MYSQL_SERVICE% >nul 2>&1
echo [OK] MySQL service removed.

:: ============================================================
::  REMOVE FROM PATH
:: ============================================================
echo [STEP 4/5] Removing from system PATH...

:: Remove PHP from PATH
call :REMOVE_FROM_PATH "%INSTALL_DIR%\php"

:: Remove MySQL from PATH
call :REMOVE_FROM_PATH "%INSTALL_DIR%\mysql\bin"

echo [OK] PATH cleaned.

:: ============================================================
::  DELETE FILES
:: ============================================================
echo [STEP 5/5] Deleting installation folder...
cd /d "C:\"
rd /s /q "%INSTALL_DIR%" >nul 2>&1
if exist "%INSTALL_DIR%" (
    echo [WARN] Could not fully delete %INSTALL_DIR%
    echo        Some files may be in use. Please delete manually.
) else (
    echo [OK] %INSTALL_DIR% deleted.
)

:: ============================================================
::  DONE
:: ============================================================
echo.
echo ============================================================
echo   Uninstall Complete!
echo ============================================================
echo.
echo   PHP service    : removed
echo   MySQL service  : removed
echo   Files          : deleted
echo   PATH           : cleaned
if /i "!TAKE_BACKUP!"=="yes" (
    echo   DB Backup      : %BACKUP_DIR%_^<timestamp^>\all-databases.sql
)
echo.
echo   You may restart your computer to fully clear any
echo   remaining service entries from Windows.
echo.
pause
endlocal
goto :EOF

:: ============================================================
::  HELPER: REMOVE from system PATH
:: ============================================================
:REMOVE_FROM_PATH
set REMOVE_PATH=%~1
set NEW_PATH=
:: Loop through PATH entries and rebuild without the target
for %%P in ("%PATH:;=" "%") do (
    set ENTRY=%%~P
    if /i "!ENTRY!" NEQ "%REMOVE_PATH%" (
        if defined NEW_PATH (
            set NEW_PATH=!NEW_PATH!;!ENTRY!
        ) else (
            set NEW_PATH=!ENTRY!
        )
    )
)
setx /M PATH "!NEW_PATH!" >nul 2>&1
exit /b