#!/bin/bash

INSTALL_DIR="/opt/php-app"
LOCK_FILE="$INSTALL_DIR/.installed"
SERVICE_NAME="php-app"
PHP_PORT=8000

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    err "Please run as root or with sudo."
    echo "    sudo bash start-server.sh"
    exit 1
fi

if [ ! -f "$LOCK_FILE" ]; then
    err "App is not installed yet. Please run install.sh first."
    exit 1
fi

# Start MySQL
info "Checking MySQL service..."
if ! systemctl is-active --quiet mysql; then
    info "Starting MySQL..."
    systemctl start mysql
    ok "MySQL started."
else
    ok "MySQL already running."
fi

# Start PHP service
info "Checking PHP service..."
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    info "Starting PHP service..."
    systemctl start "$SERVICE_NAME"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        ok "PHP service started."
    else
        err "PHP service failed to start."
        echo "    Check: $INSTALL_DIR/php-error.log"
        exit 1
    fi
else
    ok "PHP service already running."
fi

echo ""
echo "  Server  : http://localhost:$PHP_PORT"
echo "  Logs    : $INSTALL_DIR/php-server.log"
echo "  Errors  : $INSTALL_DIR/php-error.log"
echo ""
echo "  Use stop-server.sh to stop."