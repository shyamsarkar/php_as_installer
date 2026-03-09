#!/bin/bash

# ============================================================
#  CONFIG — change these if needed
# ============================================================
INSTALL_DIR="/opt/php-app"
APP_DIR="$INSTALL_DIR/app"
PHP_PORT=8000
LOCK_FILE="$INSTALL_DIR/.installed"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="php-app"

# ============================================================
#  DATABASE CONFIG — change these to your preferred values
# ============================================================
DB_NAME="myapp"
DB_USER="appuser"
DB_PASS="secret123"
DB_ROOT_PASS="root123"

# ============================================================
#  COLORS
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ============================================================
#  CHECK ROOT
# ============================================================
if [ "$EUID" -ne 0 ]; then
    err "Please run as root or with sudo."
    echo "    sudo bash install.sh"
    exit 1
fi

# ============================================================
#  CHECK FOR PARTIAL/BROKEN INSTALL
# ============================================================
if [ -d "$INSTALL_DIR" ] && [ ! -f "$LOCK_FILE" ]; then
    echo ""
    warn "Found an incomplete or broken installation at $INSTALL_DIR"
    warn "(folder exists but no lock file found)"
    echo ""
    echo "This usually means a previous install failed halfway."
    echo ""
    echo "  [1] Clean up and reinstall"
    echo "  [2] Exit and investigate manually"
    echo ""
    read -rp "Enter choice (1/2): " BROKEN_CHOICE
    if [ "$BROKEN_CHOICE" == "1" ]; then
        info "Cleaning up broken install..."
        systemctl stop "$SERVICE_NAME" >nul 2>&1
        systemctl stop mysql >nul 2>&1
        systemctl disable "$SERVICE_NAME" >nul 2>&1
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        systemctl daemon-reload
        rm -rf "$INSTALL_DIR"
        ok "Cleaned. Proceeding with fresh install..."
    else
        info "Exiting. You can manually delete $INSTALL_DIR and rerun."
        exit 0
    fi
fi

# ============================================================
#  ALREADY INSTALLED CHECK
# ============================================================
if [ -f "$LOCK_FILE" ]; then
    echo ""
    info "PHP App is already installed at $INSTALL_DIR"
    echo ""
    echo "What would you like to do?"
    echo "  [1] Start Server"
    echo "  [2] Stop Server"
    echo "  [3] Reinstall (clean install)"
    echo "  [4] Exit"
    echo ""
    read -rp "Enter choice (1/2/3/4): " CHOICE
    case "$CHOICE" in
        1) bash "$INSTALL_DIR/start-server.sh"; exit 0 ;;
        2) bash "$INSTALL_DIR/stop-server.sh"; exit 0 ;;
        3)
            echo ""
            warn "This will remove all existing files in $INSTALL_DIR"
            read -rp "Are you sure? (yes/no): " CONFIRM
            if [ "$CONFIRM" != "yes" ]; then
                info "Reinstall cancelled."
                exit 0
            fi
            info "Stopping existing services..."
            systemctl stop "$SERVICE_NAME" >nul 2>&1
            systemctl disable "$SERVICE_NAME" >nul 2>&1
            rm -f "/etc/systemd/system/$SERVICE_NAME.service"
            systemctl daemon-reload
            rm -rf "$INSTALL_DIR"
            ok "Clean done. Starting fresh install..."
            ;;
        4) exit 0 ;;
        *) err "Invalid choice. Exiting."; exit 1 ;;
    esac
fi

# ============================================================
#  FRESH INSTALL
# ============================================================
echo ""
echo "============================================================"
echo "  PHP + MySQL Installer for Ubuntu"
echo "============================================================"
echo ""
info "Installing to $INSTALL_DIR ..."
echo ""

# ── STEP 1/6 — Check & create directories ───────────────────
echo "[STEP 1/6] Creating directories..."
mkdir -p "$INSTALL_DIR"

for FOLDER in app; do
    if [ -d "$INSTALL_DIR/$FOLDER" ]; then
        warn "Folder already exists: $INSTALL_DIR/$FOLDER — will overwrite contents."
    else
        mkdir -p "$INSTALL_DIR/$FOLDER"
    fi
done
ok "Directories ready."

# ── STEP 2/6 — Install PHP ───────────────────────────────────
echo "[STEP 2/6] Installing PHP..."
apt-get update -qq
apt-get install -y php php-mysql php-cli >nul 2>&1
if ! command -v php &>/dev/null; then
    err "PHP installation failed."
    exit 1
fi
ok "PHP $(php -r 'echo PHP_VERSION;') installed."

# ── STEP 3/6 — Install MySQL ─────────────────────────────────
echo "[STEP 3/6] Installing MySQL..."
apt-get install -y mysql-server >nul 2>&1
if ! command -v mysql &>/dev/null; then
    err "MySQL installation failed."
    exit 1
fi
ok "MySQL installed."

# Start MySQL if not running
systemctl start mysql
systemctl enable mysql >nul 2>&1
ok "MySQL service enabled."

# ── STEP 4/6 — Copy application ──────────────────────────────
echo "[STEP 4/6] Copying application..."
if [ ! -d "$SCRIPT_DIR/app" ]; then
    err "App folder not found in package. Expected: $SCRIPT_DIR/app"
    exit 1
fi
cp -r "$SCRIPT_DIR/app/." "$APP_DIR/"
ok "Application copied."

# ── STEP 5/6 — Setup database & user ─────────────────────────
echo "[STEP 5/6] Setting up database and user..."

# Wait for MySQL to be ready
sleep 2

mysql -u root <<EOF
-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';
FLUSH PRIVILEGES;

-- Create database
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;

-- Create app user
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -ne 0 ]; then
    warn "Database setup had issues. You may need to set it up manually."
else
    ok "Database '$DB_NAME' created."
    ok "User '$DB_USER' created with access to '$DB_NAME'."
    ok "Root password set."
fi

# ── STEP 6/6 — Install PHP as systemd service ────────────────
echo "[STEP 6/6] Installing PHP as system service..."

# Create systemd service file
cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=PHP App Server (port $PHP_PORT)
After=network.target mysql.service

[Service]
ExecStart=/usr/bin/php -S localhost:$PHP_PORT -t $APP_DIR
Restart=always
RestartSec=3
StandardOutput=append:$INSTALL_DIR/php-server.log
StandardError=append:$INSTALL_DIR/php-error.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >nul 2>&1
systemctl start "$SERVICE_NAME"

if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "PHP service installed and running."
    ok "Auto-starts on boot."
else
    warn "PHP service failed to start. Check: $INSTALL_DIR/php-error.log"
fi

# Copy helper scripts
cp "$SCRIPT_DIR/scripts/start-server.sh" "$INSTALL_DIR/start-server.sh"
cp "$SCRIPT_DIR/scripts/stop-server.sh" "$INSTALL_DIR/stop-server.sh"
chmod +x "$INSTALL_DIR/start-server.sh"
chmod +x "$INSTALL_DIR/stop-server.sh"

# ── Write lock file ───────────────────────────────────────────
cat > "$LOCK_FILE" <<EOF
Installed on $(date)
Install Dir: $INSTALL_DIR
Database: $DB_NAME
DB User: $DB_USER
EOF

echo ""
echo "============================================================"
echo "  Installation Complete!"
echo "============================================================"
echo ""
echo "  App folder  : $APP_DIR"
echo "  Server URL  : http://localhost:$PHP_PORT"
echo ""
echo "  Database    : $DB_NAME"
echo "  DB User     : $DB_USER"
echo "  DB Password : $DB_PASS"
echo "  Root Pass   : $DB_ROOT_PASS"
echo ""
echo "  Logs        : $INSTALL_DIR/php-server.log"
echo "  Errors      : $INSTALL_DIR/php-error.log"
echo ""
echo "  Use start-server.sh / stop-server.sh in $INSTALL_DIR"
echo ""