#!/bin/bash
# MTProxy Status Script

SERVICE_NAME="python-mtproxy"
PROJECT_DIR="/opt/python-mtproxy"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "MTProxy Status Report"
echo "===================="

# Check if systemd service exists
if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
    echo
    echo "Service Status:"
    echo "---------------"
    
    # Service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Service is active and running"
    else
        log_error "Service is not running"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log_info "Service is enabled (auto-start)"
    else
        log_warning "Service is disabled (manual start)"
    fi
    
    # Detailed status
    echo
    systemctl status "$SERVICE_NAME" --no-pager -l
    
else
    log_error "Service $SERVICE_NAME not found"
    log_info "Please run deployment script first: sudo ./scripts/deploy.sh"
    exit 1
fi

# Process information
echo
echo "Process Information:"
echo "-------------------"

PID=$(systemctl show "$SERVICE_NAME" --property=MainPID --value)
if [[ "$PID" != "0" && -n "$PID" ]]; then
    log_info "Process ID: $PID"
    
    # Process details
    if command -v ps >/dev/null 2>&1; then
        ps -p "$PID" -o pid,ppid,cmd,%cpu,%mem,etime 2>/dev/null || log_warning "Cannot get process details"
    fi
    
    # Memory and CPU usage
    if command -v top >/dev/null 2>&1; then
        echo
        log_info "Resource Usage:"
        top -p "$PID" -b -n 1 | tail -n +8 2>/dev/null | head -n 1 || log_warning "Cannot get resource usage"
    fi
else
    log_warning "No process found"
fi

# Network status
echo
echo "Network Status:"
echo "---------------"

if [[ -f "$PROJECT_DIR/config/mtproxy.conf" ]]; then
    PORT=$(grep "port:" "$PROJECT_DIR/config/mtproxy.conf" | awk '{print $2}' | tr -d '"' | head -n 1)
    
    if [[ -n "$PORT" ]]; then
        log_info "Configured port: $PORT"
        
        # Check if port is listening
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tlnp 2>/dev/null | grep -q ":$PORT "; then
                log_success "Port $PORT is listening"
            else
                log_error "Port $PORT is not listening"
            fi
        elif command -v ss >/dev/null 2>&1; then
            if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
                log_success "Port $PORT is listening"
            else
                log_error "Port $PORT is not listening"
            fi
        fi
        
        # Test port connectivity
        if command -v nc >/dev/null 2>&1; then
            if timeout 3 nc -z localhost "$PORT" 2>/dev/null; then
                log_success "Port $PORT is accessible"
            else
                log_warning "Port $PORT is not accessible locally"
            fi
        fi
    fi
fi

# Configuration status
echo
echo "Configuration:"
echo "--------------"

if [[ -f "$PROJECT_DIR/config/mtproxy.conf" ]]; then
    log_success "Configuration file exists"
    
    # Show key configuration values
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROJECT_DIR/tools/mtproxy_cli.py" ]]; then
        echo
        python3 "$PROJECT_DIR/tools/mtproxy_cli.py" status 2>/dev/null || log_warning "Cannot get detailed status"
    fi
else
    log_error "Configuration file not found"
fi

# Log status
echo
echo "Log Files:"
echo "----------"

LOG_DIR="$PROJECT_DIR/logs"
if [[ -d "$LOG_DIR" ]]; then
    log_success "Log directory exists: $LOG_DIR"
    
    # Show log files
    for log_file in "$LOG_DIR"/*.log; do
        if [[ -f "$log_file" ]]; then
            size=$(du -h "$log_file" 2>/dev/null | cut -f1)
            mtime=$(stat -c %y "$log_file" 2>/dev/null | cut -d. -f1)
            log_info "$(basename "$log_file"): $size (modified: $mtime)"
        fi
    done
    
    # Show recent log entries
    MAIN_LOG="$LOG_DIR/mtproxy.log"
    if [[ -f "$MAIN_LOG" ]]; then
        echo
        log_info "Recent log entries (last 5 lines):"
        tail -n 5 "$MAIN_LOG" 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    fi
else
    log_warning "Log directory not found"
fi

# System health
echo
echo "System Health:"
echo "--------------"

# Disk space
if command -v df >/dev/null 2>&1; then
    DISK_USAGE=$(df / | tail -1 | awk '{print $(NF-1)}' | sed 's/%//')
    if [[ "$DISK_USAGE" -lt 90 ]]; then
        log_success "Disk space OK ($DISK_USAGE% used)"
    else
        log_warning "Low disk space ($DISK_USAGE% used)"
    fi
fi

# Memory usage
if command -v free >/dev/null 2>&1; then
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ "$MEMORY_USAGE" -lt 80 ]]; then
        log_success "Memory usage OK ($MEMORY_USAGE% used)"
    else
        log_warning "High memory usage ($MEMORY_USAGE% used)"
    fi
fi

# Load average
if [[ -f /proc/loadavg ]]; then
    LOAD=$(cat /proc/loadavg | awk '{print $1}')
    log_info "Load average: $LOAD"
fi

echo
echo "===================="

# Connection information
if [[ -f "$PROJECT_DIR/config/mtproxy.conf" ]]; then
    echo
    echo "Connection Information:"
    echo "======================"
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
    
    # Get configuration values
    PORT=$(grep "port:" "$PROJECT_DIR/config/mtproxy.conf" | awk '{print $2}' | tr -d '"' | head -n 1)
    SECRET=$(grep "secret:" "$PROJECT_DIR/config/mtproxy.conf" | awk '{print $2}' | tr -d '"' | head -n 1)
    
    echo "Server: $SERVER_IP"
    echo "Port: ${PORT:-8443}"
    if [[ -n "$SECRET" && "$SECRET" != "auto_generate" ]]; then
        echo "Secret: $SECRET"
        echo
        echo "Telegram Link:"
        echo "tg://proxy?server=$SERVER_IP&port=${PORT:-8443}&secret=$SECRET"
    else
        echo "Secret: Not configured"
    fi
fi
