#!/bin/bash
# MTProxy Uninstall Script

set -e

SERVICE_NAME="python-mtproxy"
PROJECT_NAME="python-mtproxy"
INSTALL_DIR="/opt/${PROJECT_NAME}"
USER_NAME="mtproxy"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

echo "MTProxy Uninstallation"
echo "====================="
echo
log_info "This will completely remove MTProxy from your system."
echo

# Confirmation
read -p "Are you sure you want to uninstall MTProxy? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Uninstallation cancelled"
    exit 0
fi

# Stop service
log_info "Stopping MTProxy service..."
if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    log_success "Service stopped"
else
    log_info "Service not found"
fi

# Disable service
log_info "Disabling MTProxy service..."
systemctl disable "$SERVICE_NAME" 2>/dev/null || true
log_success "Service disabled"

# Remove systemd service file
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [[ -f "$SERVICE_FILE" ]]; then
    log_info "Removing systemd service file..."
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    log_success "Service file removed"
fi

# Remove logrotate configuration
LOGROTATE_FILE="/etc/logrotate.d/$PROJECT_NAME"
if [[ -f "$LOGROTATE_FILE" ]]; then
    log_info "Removing logrotate configuration..."
    rm -f "$LOGROTATE_FILE"
    log_success "Logrotate configuration removed"
fi

# Remove global commands and symlinks  
log_info "Removing command symlinks..."
rm -f /usr/local/bin/mtproxy
rm -f /usr/local/bin/mtproxy-cli
rm -f /usr/local/bin/mtproxy-logs
rm -f /usr/local/bin/mtproxy-health
log_success "Symlinks removed"

# Create backup of configuration
if [[ -d "$INSTALL_DIR/config" ]]; then
    BACKUP_DIR="/tmp/${PROJECT_NAME}-backup-$(date +%Y%m%d_%H%M%S)"
    log_info "Creating configuration backup at $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -r "$INSTALL_DIR/config" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$INSTALL_DIR/logs" "$BACKUP_DIR/" 2>/dev/null || true
    log_success "Configuration backed up to $BACKUP_DIR"
fi

# Remove installation directory
if [[ -d "$INSTALL_DIR" ]]; then
    log_info "Removing installation directory..."
    rm -rf "$INSTALL_DIR"
    log_success "Installation directory removed"
fi

# Remove user
if id "$USER_NAME" &>/dev/null; then
    log_info "Removing user $USER_NAME..."
    userdel "$USER_NAME" 2>/dev/null || true
    log_success "User removed"
else
    log_info "User $USER_NAME not found"
fi

# Remove user's home directory if it exists and is empty
USER_HOME="/home/$USER_NAME"
if [[ -d "$USER_HOME" ]]; then
    if [[ -z "$(ls -A "$USER_HOME" 2>/dev/null)" ]]; then
        log_info "Removing empty user home directory..."
        rmdir "$USER_HOME" 2>/dev/null || true
    else
        log_info "User home directory not empty, leaving it intact"
    fi
fi

# Firewall cleanup
if command -v ufw &> /dev/null; then
    log_info "Removing firewall rules..."
    
    # Remove MTProxy port rule
    ufw delete allow 8443/tcp 2>/dev/null || true
    
    # Try to remove rule by comment
    ufw --force delete $(ufw status numbered | grep "MTProxy" | awk '{print $1}' | tr -d '[]' | head -n 1) 2>/dev/null || true
    
    log_success "Firewall rules cleaned up"
fi

# Clean up any remaining processes
log_info "Checking for remaining processes..."
if pgrep -f "mtproxy" > /dev/null; then
    log_info "Killing remaining MTProxy processes..."
    pkill -f "mtproxy" 2>/dev/null || true
    sleep 2
    pkill -9 -f "mtproxy" 2>/dev/null || true
fi

# Optional: Remove Python packages (ask user)
echo
read -p "Do you want to remove Python packages installed for MTProxy? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Removing Python packages..."
    
    # This is tricky because we don't want to remove system packages
    # We'll only suggest manual removal
    echo "To manually remove Python packages, you can run:"
    echo "  pip3 uninstall cryptography pycryptodome click colorama psutil requests pyyaml python-dateutil tabulate watchdog"
    echo
    log_info "Note: Only run this if these packages are not used by other applications"
fi

echo
log_success "MTProxy uninstallation completed!"
echo
echo "What was removed:"
echo "  ✓ MTProxy service and systemd configuration"
echo "  ✓ Installation directory ($INSTALL_DIR)"
echo "  ✓ System user ($USER_NAME)"
echo "  ✓ Command-line tools and symlinks"
echo "  ✓ Logrotate configuration"
echo "  ✓ Firewall rules"

if [[ -n "${BACKUP_DIR:-}" ]]; then
    echo
    echo "Configuration backup saved to: $BACKUP_DIR"
    echo "You can safely delete this backup after verifying the uninstallation."
fi

echo
echo "To reinstall MTProxy in the future, run:"
echo "  sudo ./scripts/deploy.sh"
