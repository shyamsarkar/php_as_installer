@echo off
setlocal EnableDelayedExpansion
title PHP + MySQL Portable Installer
echo [INFO] Running installer from: %~f0

:: ============================================================
::  CONFIG — change these if needed
:: ============================================================
set INSTALL_DIR=C:\php-app
set APP_DIR=%INSTALL_DIR%\app
set PHP_DIR=%INSTALL_DIR%\php
set MYSQL_DIR=%INSTALL_DIR%\mysql
set MYSQL_DATA=%INSTALL_DIR%\mysql-data
set NSSM=%INSTALL_DIR%\nssm.exe
set LOCK_FILE=%INSTALL_DIR%\.installed
set PHP_PORT=8000
set SCRIPT_DIR=%~dp0
set PHP_SERVICE=PHPServer
set MYSQL_SERVICE=MySQLPortable

:: ============================================================
::  DATABASE CONFIG — change these to your preferred values
:: ============================================================
set DB_NAME=myapp
set DB_USER=appuser
set DB_PASS=secret123
set DB_ROOT_PASS=root123

:: ============================================================
::  CHECK FOR ADMIN
:: ============================================================
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [ERROR] Please run this script as Administrator.
    echo Right-click INSTALL.bat and choose "Run as administrator"
    pause
    exit /b 1
)

:: ============================================================
::  CHECK VC++ RUNTIME (VCRUNTIME140_1.dll)
:: ============================================================
set VCRUNTIME_SYS32=0
set VCRUNTIME_SYSWOW64=0
if exist "%SystemRoot%\System32\VCRUNTIME140_1.dll" set VCRUNTIME_SYS32=1
if exist "%SystemRoot%\SysWOW64\VCRUNTIME140_1.dll" set VCRUNTIME_SYSWOW64=1
if "%VCRUNTIME_SYS32%"=="0" if "%VCRUNTIME_SYSWOW64%"=="0" (
    echo.
    echo [ERROR] Missing Microsoft Visual C++ Runtime (VCRUNTIME140_1.dll)
    echo         MySQL cannot start without it.
    echo.
    echo [FIX] Install the latest Visual C++ Redistributable (2015-2022) and retry.
    echo       x64: https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo       x86: https://aka.ms/vs/17/release/vc_redist.x86.exe
    echo.
    echo [DIAG] Windows architecture:
    wmic os get osarchitecture 2>nul
    echo [DIAG] Checking expected paths:
    if exist "%SystemRoot%\System32\VCRUNTIME140_1.dll" (
        echo   FOUND: %SystemRoot%\System32\VCRUNTIME140_1.dll
    ) else (
        echo   MISSING: %SystemRoot%\System32\VCRUNTIME140_1.dll
    )
    if exist "%SystemRoot%\SysWOW64\VCRUNTIME140_1.dll" (
        echo   FOUND: %SystemRoot%\SysWOW64\VCRUNTIME140_1.dll
    ) else (
        echo   MISSING: %SystemRoot%\SysWOW64\VCRUNTIME140_1.dll
    )
    echo.
    echo [TIP] If you just installed the redistributable, reboot Windows and try again.
    echo.
    choice /c YN /n /m "Do you want to continue anyway? (Y/N): "
    if %errorLevel%==2 exit /b 1
)
if "%VCRUNTIME_SYSWOW64%"=="0" (
    echo.
    echo [WARN] 32-bit VC++ runtime not found in SysWOW64.
    echo        If MySQL is 32-bit, install the x86 redistributable and reboot.
    echo        Otherwise you can continue.
)

:: ============================================================
::  CHECK C: DRIVE EXISTS
:: ============================================================
if not exist "C:\" (
    echo.
    echo [ERROR] C:\ drive not found on this system.
    echo [INFO]  Available drives:
    wmic logicaldisk get caption 2>nul
    echo.
    echo [INFO]  Please edit INSTALL_DIR in this script to use an available drive.
    echo         Example: set INSTALL_DIR=D:\php-app
    pause
    exit /b 1
)

:: ============================================================
::  COPY PACKAGE FROM USB (IF NOT RUNNING FROM C:)
:: ============================================================
set SOURCE_DRIVE=%~d0
if /I not "%SOURCE_DRIVE%"=="C:" (
    set STAGE_DIR=%INSTALL_DIR%\_package
    echo.
    echo [INFO] Detected source drive %SOURCE_DRIVE%. Copying package to C: ...
    if not exist "%STAGE_DIR%" mkdir "%STAGE_DIR%" 2>nul
    robocopy "%SCRIPT_DIR%" "%STAGE_DIR%" /E /NFL /NDL /NJH /NJS /NP >nul
    if %errorLevel% GEQ 8 (
        echo [ERROR] Failed to copy package to %STAGE_DIR%.
        echo         Please check the USB drive and try again.
        pause
        exit /b 1
    )
    set SCRIPT_DIR=%STAGE_DIR%\
    echo [OK] Package copied to %STAGE_DIR%.
)

:: ============================================================
::  CHECK FOR PARTIAL/BROKEN INSTALL (folder exists, no lock file)
:: ============================================================
if exist "%INSTALL_DIR%" (
    if not exist "%LOCK_FILE%" (
        echo.
        echo [WARN] Found an incomplete or broken installation at %INSTALL_DIR%
        echo        ^(folder exists but no lock file found^)
        echo.
        echo This usually means a previous install failed halfway.
        echo.
        echo   [1] Clean up and reinstall
        echo   [2] Exit and investigate manually
        echo.
        set /p BROKEN_CHOICE="Enter choice (1/2): "
        if "!BROKEN_CHOICE!"=="1" (
            echo [INFO] Cleaning up broken install...
            net stop %PHP_SERVICE% >nul 2>&1
            net stop %MYSQL_SERVICE% >nul 2>&1
            sc delete %MYSQL_SERVICE% >nul 2>&1
            if exist "%NSSM%" (
                "%NSSM%" remove %PHP_SERVICE% confirm >nul 2>&1
            )
            rd /s /q "%INSTALL_DIR%" >nul 2>&1
            echo [OK] Cleaned. Proceeding with fresh install...
            goto FRESH_INSTALL
        ) else (
            echo [INFO] Exiting. You can manually delete %INSTALL_DIR% and rerun.
            pause
            exit /b 0
        )
    )
)

:: ============================================================
::  ALREADY INSTALLED CHECK
:: ============================================================
if exist "%LOCK_FILE%" (
    cls
    echo ============================================================
    echo   PHP + MySQL Portable Installer
    echo ============================================================
    echo(
    echo [INFO] PHP App is already installed at %INSTALL_DIR%
    echo [INFO] Lock file: %LOCK_FILE%
    echo(
    echo [INFO] Installed components:
    if exist "%APP_DIR%\" (echo   [OK] App folder: %APP_DIR%) else (echo   [MISSING] App folder: %APP_DIR%)
    if exist "%PHP_DIR%\" (echo   [OK] PHP folder: %PHP_DIR%) else (echo   [MISSING] PHP folder: %PHP_DIR%)
    if exist "%MYSQL_DIR%\" (echo   [OK] MySQL folder: %MYSQL_DIR%) else (echo   [MISSING] MySQL folder: %MYSQL_DIR%)
    if exist "%MYSQL_DATA%\" (echo   [OK] MySQL data: %MYSQL_DATA%) else (echo   [MISSING] MySQL data: %MYSQL_DATA%)
    if exist "%NSSM%" (echo   [OK] NSSM: %NSSM%) else (echo   [MISSING] NSSM: %NSSM%)
    echo(
    echo(
    echo What would you like to do?
    echo(   [1] Reinstall (clean install)
    echo(   [2] Start Server
    echo(   [3] Stop Server
    echo(   [4] Exit
    echo(
    set /p CHOICE="Enter choice (1/2/3/4): "

    if "!CHOICE!"=="1" goto CLEAN_INSTALL
    if "!CHOICE!"=="2" goto START_SERVER
    if "!CHOICE!"=="3" goto STOP_SERVER
    if "!CHOICE!"=="4" goto END
    echo Invalid choice. Exiting.
    goto END
)

goto FRESH_INSTALL

:: ============================================================
::  CLEAN INSTALL — remove old installation
:: ============================================================
:CLEAN_INSTALL
echo.
echo [WARNING] This will remove all existing files in %INSTALL_DIR%
set /p CONFIRM="Are you sure? (yes/no): "
if /i "!CONFIRM!" NEQ "yes" goto END

echo [INFO] Stopping existing services...
call :STOP_MYSQL_SILENT
call :STOP_PHP_SILENT

echo [INFO] Removing old installation...
sc delete %MYSQL_SERVICE% >nul 2>&1
"%NSSM%" stop %PHP_SERVICE% >nul 2>&1
"%NSSM%" remove %PHP_SERVICE% confirm >nul 2>&1
rd /s /q "%INSTALL_DIR%" >nul 2>&1
echo [INFO] Clean done. Starting fresh install...

:: ============================================================
::  FRESH INSTALL
:: ============================================================
:FRESH_INSTALL
echo.
echo ============================================================
echo   PHP + MySQL Portable Installer
echo ============================================================
echo.
echo [INFO] Installing to %INSTALL_DIR% ...
echo.

:: Create directories — warn if subfolders already exist
echo [STEP 1/8] Creating directories...
mkdir "%INSTALL_DIR%" 2>nul

for %%F in (app php mysql mysql-data) do (
    if exist "%INSTALL_DIR%\%%F" (
        echo [WARN] Folder already exists: %INSTALL_DIR%\%%F — will overwrite contents.
    ) else (
        mkdir "%INSTALL_DIR%\%%F" 2>nul
    )
)

:: Copy NSSM
echo [STEP 2/8] Copying NSSM...
if not exist "%SCRIPT_DIR%nssm.exe" (
    echo [ERROR] nssm.exe not found in package. Expected: %SCRIPT_DIR%nssm.exe
    echo         Download from https://nssm.cc/download ^(~350KB^)
    pause & exit /b 1
)
copy /Y "%SCRIPT_DIR%nssm.exe" "%NSSM%" >nul
echo [OK] NSSM copied.

:: Copy PHP
echo [STEP 3/8] Copying PHP...
if not exist "%SCRIPT_DIR%php\" (
    echo [ERROR] PHP folder not found in package. Expected: %SCRIPT_DIR%php\
    pause & exit /b 1
)
xcopy /E /I /Y "%SCRIPT_DIR%php\*" "%PHP_DIR%\" >nul
echo [OK] PHP copied.

:: Configure PHP (enable mysqli / pdo_mysql)
echo [STEP 4/8] Configuring PHP (mysqli)...
if not exist "%PHP_DIR%\php.ini" (
    copy /Y "%PHP_DIR%\php.ini-production" "%PHP_DIR%\php.ini" >nul
)
findstr /i /r "^extension_dir" "%PHP_DIR%\php.ini" >nul
if %errorLevel% NEQ 0 (
    echo extension_dir="ext" >> "%PHP_DIR%\php.ini"
)
findstr /i /r "^extension=mysqli" "%PHP_DIR%\php.ini" >nul
if %errorLevel% NEQ 0 (
    echo extension=mysqli >> "%PHP_DIR%\php.ini"
)
findstr /i /r "^extension=pdo_mysql" "%PHP_DIR%\php.ini" >nul
if %errorLevel% NEQ 0 (
    echo extension=pdo_mysql >> "%PHP_DIR%\php.ini"
)
echo [OK] PHP configured.

:: Copy MySQL
echo [STEP 5/8] Copying MySQL...
if not exist "%SCRIPT_DIR%mysql\" (
    echo [ERROR] MySQL folder not found in package. Expected: %SCRIPT_DIR%mysql\
    pause & exit /b 1
)
xcopy /E /I /Y "%SCRIPT_DIR%mysql\*" "%MYSQL_DIR%\" >nul
echo [OK] MySQL copied.

:: Copy Application
echo [STEP 6/8] Copying application...
if not exist "%SCRIPT_DIR%app\" (
    echo [ERROR] App folder not found in package. Expected: %SCRIPT_DIR%app\
    pause & exit /b 1
)
xcopy /E /I /Y "%SCRIPT_DIR%app\*" "%APP_DIR%\" >nul
echo [OK] Application copied.

:: Add to PATH
echo [STEP 7/8] Adding PHP and MySQL to system PATH...
call :ADD_TO_PATH "%PHP_DIR%"
call :ADD_TO_PATH "%MYSQL_DIR%\bin"
echo [OK] PATH updated.

:: Initialize MySQL
echo.
echo [INFO] Initializing MySQL database...
if not exist "%MYSQL_DIR%\bin\mysqld.exe" (
    echo [ERROR] mysqld.exe not found in %MYSQL_DIR%\bin\
    pause & exit /b 1
)

:: Create my.ini config
(
    echo [mysqld]
    echo basedir=%MYSQL_DIR:\=/%
    echo datadir=%MYSQL_DATA:\=/%
    echo port=3306
    echo [client]
    echo port=3306
) > "%MYSQL_DIR%\my.ini"

:: Initialize data directory
"%MYSQL_DIR%\bin\mysqld.exe" --initialize-insecure --basedir="%MYSQL_DIR%" --datadir="%MYSQL_DATA%" >nul 2>&1
echo [OK] MySQL initialized.

:: Install MySQL as Windows service
"%MYSQL_DIR%\bin\mysqld.exe" --install MySQLPortable --defaults-file="%MYSQL_DIR%\my.ini" >nul 2>&1
net start MySQLPortable >nul 2>&1
echo [OK] MySQL service started.

:: ============================================================
::  STEP 7/7 — Create database, user and set root password
:: ============================================================
echo [STEP 8/8] Setting up database, user and PHP service...

:: Wait a moment for MySQL to fully start
timeout /t 3 /nobreak >nul

:: Write SQL setup script to a temp file
(
    echo -- Set root password
    echo ALTER USER 'root'@'localhost' IDENTIFIED BY '%DB_ROOT_PASS%';
    echo FLUSH PRIVILEGES;
    echo.
    echo -- Create database
    echo CREATE DATABASE IF NOT EXISTS `%DB_NAME%`;
    echo.
    echo -- Create app user with full access to the database
    echo CREATE USER IF NOT EXISTS '%DB_USER%'@'localhost' IDENTIFIED BY '%DB_PASS%';
    echo GRANT ALL PRIVILEGES ON `%DB_NAME%`.* TO '%DB_USER%'@'localhost';
    echo FLUSH PRIVILEGES;
) > "%INSTALL_DIR%\setup.sql"

:: Run SQL using root (no password yet since --initialize-insecure)
"%MYSQL_DIR%\bin\mysql.exe" -u root --connect-expired-password < "%INSTALL_DIR%\setup.sql" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [WARN] Database setup had issues. You may need to set it up manually.
) else (
    echo [OK] Database '%DB_NAME%' created.
    echo [OK] User '%DB_USER%' created with access to '%DB_NAME%'.
    echo [OK] Root password set.
)

:: Delete temp SQL file
del "%INSTALL_DIR%\setup.sql" >nul 2>&1

:: ── Install PHP as Windows Service via NSSM ──────────────────
:: Remove old service if exists
sc query %PHP_SERVICE% >nul 2>&1
if %errorLevel% EQU 0 (
    echo [INFO] Removing old PHP service...
    "%NSSM%" stop %PHP_SERVICE% >nul 2>&1
    "%NSSM%" remove %PHP_SERVICE% confirm >nul 2>&1
)

:: Install PHP service
"%NSSM%" install %PHP_SERVICE% "%PHP_DIR%\php.exe" >nul 2>&1
"%NSSM%" set %PHP_SERVICE% AppParameters "-S localhost:%PHP_PORT% -t \"%APP_DIR%\"" >nul 2>&1
"%NSSM%" set %PHP_SERVICE% DisplayName "PHP App Server (port %PHP_PORT%)" >nul 2>&1
"%NSSM%" set %PHP_SERVICE% Description "PHP built-in web server for php-app" >nul 2>&1
"%NSSM%" set %PHP_SERVICE% Start SERVICE_AUTO_START >nul 2>&1
"%NSSM%" set %PHP_SERVICE% AppStdout "%INSTALL_DIR%\php-server.log" >nul 2>&1
"%NSSM%" set %PHP_SERVICE% AppStderr "%INSTALL_DIR%\php-error.log" >nul 2>&1

net start %PHP_SERVICE% >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [WARN] PHP service failed to start. Check %INSTALL_DIR%\php-error.log
) else (
    echo [OK] PHP service installed and running.
    echo [OK] Auto-starts on Windows boot.
)

:: Copy helper scripts
copy /Y "%SCRIPT_DIR%scripts\start-server.bat" "%INSTALL_DIR%\start-server.bat" >nul 2>nul
copy /Y "%SCRIPT_DIR%scripts\stop-server.bat" "%INSTALL_DIR%\stop-server.bat" >nul 2>nul

:: Write lock file
echo Installed on %DATE% %TIME% > "%LOCK_FILE%"
echo Install Dir: %INSTALL_DIR% >> "%LOCK_FILE%"
echo Database: %DB_NAME% >> "%LOCK_FILE%"
echo DB User: %DB_USER% >> "%LOCK_FILE%"

echo.
echo ============================================================
echo   Installation Complete!
echo ============================================================
echo.
echo   App folder  : %APP_DIR%
echo   PHP         : %PHP_DIR%
echo   MySQL       : %MYSQL_DIR%
echo   Server URL  : http://localhost:%PHP_PORT%
echo.
echo   Database    : %DB_NAME%
echo   DB User     : %DB_USER%
echo   DB Password : %DB_PASS%
echo   Root Pass   : %DB_ROOT_PASS%
echo.
echo   Use start-server.bat / stop-server.bat in %INSTALL_DIR%
echo.

:: Start server after install
goto START_SERVER

:: ============================================================
::  START SERVER
:: ============================================================
:START_SERVER
echo.
echo [INFO] Checking MySQL service...
sc query %MYSQL_SERVICE% | find "RUNNING" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [INFO] Starting MySQL service...
    net start %MYSQL_SERVICE% >nul 2>&1
)
echo [OK] MySQL is running.

echo [INFO] Checking PHP service...
sc query %PHP_SERVICE% | find "RUNNING" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [INFO] Starting PHP service...
    net start %PHP_SERVICE% >nul 2>&1
    if %errorLevel% NEQ 0 (
        echo [ERROR] PHP service failed to start. Check %INSTALL_DIR%\php-error.log
        goto END
    )
)
echo [OK] PHP service is running.
echo.
echo   Server : http://localhost:%PHP_PORT%
echo   Logs   : %INSTALL_DIR%\php-server.log
echo   Errors : %INSTALL_DIR%\php-error.log
echo.
echo [TIP] Both services auto-start on Windows boot.
echo [TIP] Use stop-server.bat to stop.
goto END

:: ============================================================
::  STOP SERVER
:: ============================================================
:STOP_SERVER
echo.
echo [INFO] Stopping PHP service...
call :STOP_PHP_SILENT
echo [INFO] Stopping MySQL service...
call :STOP_MYSQL_SILENT
echo [OK] All services stopped.
goto END

:: ============================================================
::  HELPER: STOP PHP silently
:: ============================================================
:STOP_PHP_SILENT
net stop %PHP_SERVICE% >nul 2>&1
exit /b

:: ============================================================
::  HELPER: STOP MYSQL silently
:: ============================================================
:STOP_MYSQL_SILENT
net stop %MYSQL_SERVICE% >nul 2>&1
exit /b

:: ============================================================
::  HELPER: ADD to system PATH (no duplicates)
:: ============================================================
:ADD_TO_PATH
set NEW_PATH=%~1
echo %PATH% | find /i "%NEW_PATH%" >nul 2>&1
if %errorLevel% NEQ 0 (
    setx /M PATH "%PATH%;%NEW_PATH%" >nul 2>&1
)
exit /b

:END
echo.
pause
endlocal
