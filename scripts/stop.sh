#!/bin/bash
# MTProxy Stop Script

set -e

SERVICE_NAME="python-mtproxy"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root for systemd commands
if [[ $EUID -eq 0 ]]; then
    USE_SUDO=""
else
    USE_SUDO="sudo"
fi

# Check if systemd service exists
if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Stopping $SERVICE_NAME service..."
        
        $USE_SUDO systemctl stop "$SERVICE_NAME"
        
        # Wait a moment and check status
        sleep 2
        
        if ! systemctl is-active --quiet "$SERVICE_NAME"; then
            log_success "$SERVICE_NAME stopped successfully"
        else
            log_error "$SERVICE_NAME failed to stop"
            exit 1
        fi
    else
        log_info "$SERVICE_NAME is not running"
    fi
else
    log_error "Service $SERVICE_NAME not found"
    exit 1
fi
