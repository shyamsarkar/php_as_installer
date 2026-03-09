# PHP + MySQL Portable Installer

## Package Structure

```
📦 php-app-package.zip
├── INSTALL.bat          ← Run this first (as Administrator)
├── README.md
├── php/                 ← PHP binaries (copy from your php folder)
├── mysql/               ← MySQL binaries (copy from your mysql folder)
├── app/                 ← Your PHP application files
└── scripts/
    ├── start-server.bat
    └── stop-server.bat
```

---

## How to Use

### First Time Install
1. Extract the ZIP
2. Right-click `INSTALL.bat` → **Run as Administrator**
3. Everything installs automatically to `C:\php-app`
4. Server starts at **http://localhost:8000**

### Already Installed?
Running `INSTALL.bat` again shows a menu:
```
[1] Start Server
[2] Stop Server
[3] Reinstall (clean install)
[4] Exit
```

### Start / Stop Anytime
After install, shortcuts are copied to `C:\php-app\`:
- `start-server.bat` — starts PHP + MySQL
- `stop-server.bat`  — stops both

---

## What Gets Installed

| Component | Location         |
|-----------|-----------------|
| PHP       | C:\php-app\php  |
| MySQL     | C:\php-app\mysql|
| Your App  | C:\php-app\app  |
| MySQL Data| C:\php-app\mysql-data |

Both PHP and MySQL\bin are added to system PATH automatically.
MySQL runs as a Windows service called `MySQLPortable`.

---

## How to Prepare the Package

1. Download PHP (NTS ZIP) from https://windows.php.net/download
   → Extract and place contents in `php/` folder

2. Download MySQL Community ZIP from https://dev.mysql.com/downloads/mysql
   → Extract and place contents in `mysql/` folder

3. Place your PHP app files in `app/` folder

4. Zip everything → share the ZIP

---

## Notes
- Requires **Administrator** privileges to install
- MySQL port: **3306**
- PHP server port: **8000**
- Lock file at `C:\php-app\.installed` tracks installation
