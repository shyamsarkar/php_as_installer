#!/bin/bash

SERVICE_NAME="php-app"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    err "Please run as root or with sudo."
    echo "    sudo bash stop-server.sh"
    exit 1
fi

info "Stopping PHP service..."
systemctl stop "$SERVICE_NAME" >nul 2>&1
ok "PHP stopped."

info "Stopping MySQL service..."
systemctl stop mysql >nul 2>&1
ok "MySQL stopped."

echo ""
echo "All services stopped."