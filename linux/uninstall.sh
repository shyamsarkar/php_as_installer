#!/bin/bash

# ============================================================
#  CONFIG
# ============================================================
INSTALL_DIR="/opt/php-app"
LOCK_FILE="$INSTALL_DIR/.installed"
SERVICE_NAME="php-app"
DB_ROOT_PASS="root123"
BACKUP_DIR="$HOME/php-app-backup"

# ============================================================
#  COLORS
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ============================================================
#  CHECK ROOT
# ============================================================
if [ "$EUID" -ne 0 ]; then
    err "Please run as root or with sudo."
    echo "    sudo bash uninstall.sh"
    exit 1
fi

# ============================================================
#  CHECK IF INSTALLED
# ============================================================
if [ ! -f "$LOCK_FILE" ]; then
    echo ""
    info "No installation found at $INSTALL_DIR"
    info "Nothing to uninstall."
    exit 0
fi

# ============================================================
#  CONFIRM UNINSTALL
# ============================================================
echo ""
echo "============================================================"
echo "  PHP + MySQL Uninstaller for Ubuntu"
echo "============================================================"
echo ""
echo "  This will:"
echo "    - Stop PHP and MySQL services"
echo "    - Remove PHP systemd service"
echo "    - Delete all files in $INSTALL_DIR"
echo ""
echo "  Your original app files will be DELETED."
echo "  Make sure you have a backup if needed."
echo ""

# Ask about backup first
read -rp "Take database backup before uninstalling? (yes/no): " BACKUP_CHOICE

echo ""
read -rp "Type YES to confirm uninstall: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    info "Uninstall cancelled."
    exit 0
fi

echo ""
info "Starting uninstall..."
echo ""

# ── STEP 1/5 — Database backup ───────────────────────────────
echo "[STEP 1/5] Database backup..."
if [ "$BACKUP_CHOICE" == "yes" ]; then

    # Make sure MySQL is running
    if ! systemctl is-active --quiet mysql; then
        info "Starting MySQL for backup..."
        systemctl start mysql
        sleep 2
    fi

    # Create timestamped backup folder
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_PATH="${BACKUP_DIR}_${TIMESTAMP}"
    mkdir -p "$BACKUP_PATH"

    info "Backing up all databases..."
    mysqldump -u root -p"$DB_ROOT_PASS" --all-databases > "$BACKUP_PATH/all-databases.sql" 2>/dev/null

    if [ -f "$BACKUP_PATH/all-databases.sql" ] && [ -s "$BACKUP_PATH/all-databases.sql" ]; then
        ok "Database backup saved to:"
        echo "     $BACKUP_PATH/all-databases.sql"
    else
        warn "Backup may have failed. Check manually before proceeding."
        read -rp "Continue uninstall anyway? (yes/no): " PROCEED
        if [ "$PROCEED" != "yes" ]; then
            info "Uninstall cancelled. Your data is safe."
            exit 0
        fi
    fi
else
    info "Skipping backup."
fi

# ── STEP 2/5 — Stop services ─────────────────────────────────
echo "[STEP 2/5] Stopping services..."
systemctl stop "$SERVICE_NAME" >nul 2>&1
ok "PHP service stopped."
systemctl stop mysql >nul 2>&1
ok "MySQL service stopped."

# ── STEP 3/5 — Remove PHP service ────────────────────────────
echo "[STEP 3/5] Removing PHP systemd service..."
systemctl disable "$SERVICE_NAME" >nul 2>&1
rm -f "/etc/systemd/system/$SERVICE_NAME.service"
systemctl daemon-reload
ok "PHP service removed."

# ── STEP 4/5 — Remove packages (optional) ────────────────────
echo "[STEP 4/5] Removing PHP and MySQL packages..."
read -rp "  Remove PHP and MySQL packages from system? (yes/no): " REMOVE_PKGS
if [ "$REMOVE_PKGS" == "yes" ]; then
    apt-get remove -y php php-mysql php-cli mysql-server >nul 2>&1
    apt-get autoremove -y >nul 2>&1
    ok "Packages removed."
else
    info "Skipping package removal. PHP and MySQL still installed on system."
fi

# ── STEP 5/5 — Delete files ───────────────────────────────────
echo "[STEP 5/5] Deleting installation folder..."
rm -rf "$INSTALL_DIR"
if [ -d "$INSTALL_DIR" ]; then
    warn "Could not fully delete $INSTALL_DIR. Please delete manually."
else
    ok "$INSTALL_DIR deleted."
fi

# ── DONE ─────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Uninstall Complete!"
echo "============================================================"
echo ""
echo "  PHP service  : removed"
echo "  Files        : deleted"
if [ "$BACKUP_CHOICE" == "yes" ]; then
    echo "  DB Backup    : ${BACKUP_DIR}_<timestamp>/all-databases.sql"
fi
echo ""