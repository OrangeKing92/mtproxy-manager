#!/bin/bash
# MTProxy Restart Script

set -e

SERVICE_NAME="python-mtproxy"
PROJECT_DIR="/opt/python-mtproxy"

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
    log_info "Restarting $SERVICE_NAME service..."
    
    $USE_SUDO systemctl restart "$SERVICE_NAME"
    
    # Wait a moment and check status
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "$SERVICE_NAME restarted successfully"
        
        # Show status
        echo
        systemctl status "$SERVICE_NAME" --no-pager -l
        
        # Show connection info
        echo
        log_info "Connection Information:"
        if [[ -f "$PROJECT_DIR/tools/mtproxy_cli.py" ]]; then
            python3 "$PROJECT_DIR/tools/mtproxy_cli.py" status
        fi
    else
        log_error "$SERVICE_NAME failed to restart"
        echo
        log_info "Checking logs for errors:"
        journalctl -u "$SERVICE_NAME" --no-pager -l --since "1 minute ago"
        exit 1
    fi
else
    log_error "Service $SERVICE_NAME not found"
    log_info "Please run deployment script first: sudo ./scripts/deploy.sh"
    exit 1
fi
