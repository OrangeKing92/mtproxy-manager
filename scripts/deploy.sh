#!/bin/bash
# MTProxy Deployment Script - One-click deployment for Debian/Ubuntu systems
# Usage: ./scripts/deploy.sh [--production|--dev|--update|--uninstall]

set -e  # Exit on any error

# Configuration
PROJECT_NAME="python-mtproxy"
INSTALL_DIR="/opt/${PROJECT_NAME}"
SERVICE_NAME="${PROJECT_NAME}"
USER_NAME="mtproxy"
LOG_DIR="/opt/${PROJECT_NAME}/logs"
CONFIG_DIR="/opt/${PROJECT_NAME}/config"
PYTHON_MIN_VERSION="3.8"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check system compatibility
check_system() {
    log_info "Checking system compatibility..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    
    case $ID in
        ubuntu|debian)
            log_success "Compatible OS detected: $PRETTY_NAME"
            ;;
        *)
            log_warning "Untested OS: $PRETTY_NAME (proceeding anyway)"
            ;;
    esac
    
    # Check Python version
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
        log_info "Python version: $PYTHON_VERSION"
        
        # Compare versions
        if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
            log_success "Python version is compatible"
        else
            log_error "Python $PYTHON_MIN_VERSION or higher is required"
            exit 1
        fi
    else
        log_error "Python 3 is not installed"
        exit 1
    fi
}

# Install system dependencies
install_dependencies() {
    log_info "Installing system dependencies..."
    
    apt-get update
    
    # Essential packages
    PACKAGES=(
        "python3"
        "python3-pip"
        "python3-venv"
        "python3-dev"
        "build-essential"
        "git"
        "curl"
        "systemd"
        "logrotate"
    )
    
    for package in "${PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing $package..."
            apt-get install -y "$package"
        else
            log_info "$package is already installed"
        fi
    done
    
    log_success "System dependencies installed"
}

# Create system user
create_user() {
    log_info "Creating system user..."
    
    if id "$USER_NAME" &>/dev/null; then
        log_info "User $USER_NAME already exists"
    else
        useradd --system --shell /bin/false --home-dir "$INSTALL_DIR" --create-home "$USER_NAME"
        log_success "Created user $USER_NAME"
    fi
}

# Setup project directories
setup_directories() {
    log_info "Setting up project directories..."
    
    # Create main directory
    mkdir -p "$INSTALL_DIR"
    
    # Create subdirectories
    mkdir -p "$LOG_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$INSTALL_DIR/data"
    mkdir -p "$INSTALL_DIR/backup"
    
    # Set permissions
    chown -R "$USER_NAME:$USER_NAME" "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$LOG_DIR"
    chmod 750 "$CONFIG_DIR"
    
    log_success "Project directories created"
}

# Install Python application
install_application() {
    log_info "Installing Python application..."
    
    # Determine source directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Copy application files
    if [[ -d "$SOURCE_DIR/mtproxy" ]]; then
        log_info "Copying application files..."
        cp -r "$SOURCE_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
        
        # Remove git directory and cache files
        rm -rf "$INSTALL_DIR/.git"
        find "$INSTALL_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        find "$INSTALL_DIR" -name "*.pyc" -delete 2>/dev/null || true
        
    else
        log_error "Source directory not found: $SOURCE_DIR"
        exit 1
    fi
    
    # Create virtual environment
    log_info "Creating Python virtual environment..."
    sudo -u "$USER_NAME" python3 -m venv "$INSTALL_DIR/venv"
    
    # Install Python dependencies
    log_info "Installing Python dependencies..."
    sudo -u "$USER_NAME" "$INSTALL_DIR/venv/bin/pip" install --upgrade pip
    sudo -u "$USER_NAME" "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"
    
    # Install application in development mode
    sudo -u "$USER_NAME" "$INSTALL_DIR/venv/bin/pip" install -e "$INSTALL_DIR"
    
    # Set permissions
    chown -R "$USER_NAME:$USER_NAME" "$INSTALL_DIR"
    
    log_success "Python application installed"
}

# Interactive configuration input
interactive_config() {
    echo
    echo "================================================"
    echo "MTProxy 交互式配置"
    echo "================================================"
    echo
    
    # Port configuration
    while true; do
        echo -e "请输入MTProxy监听端口 [1-65535]："
        read -p "（默认端口: 8443）: " INPUT_PORT
        [ -z "${INPUT_PORT}" ] && INPUT_PORT=8443
        
        # Validate port number
        if [[ "$INPUT_PORT" =~ ^[0-9]+$ ]] && [ "$INPUT_PORT" -ge 1 ] && [ "$INPUT_PORT" -le 65535 ]; then
            echo
            echo "端口设置: $INPUT_PORT"
            break
        else
            log_error "请输入有效的端口号 [1-65535]"
        fi
    done
    
    # Fake domain configuration
    while true; do
        echo
        echo -e "请输入TLS伪装域名："
        echo -e "（用于TLS流量伪装，提高连接成功率）"
        read -p "（默认域名: www.cloudflare.com）: " INPUT_DOMAIN
        [ -z "${INPUT_DOMAIN}" ] && INPUT_DOMAIN="www.cloudflare.com"
        
        # Validate domain accessibility
        log_info "正在验证域名可访问性..."
        HTTP_CODE=$(curl -I -m 10 -o /dev/null -s -w %{http_code} "https://$INPUT_DOMAIN" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" -eq "200" ] || [ "$HTTP_CODE" -eq "302" ] || [ "$HTTP_CODE" -eq "301" ]; then
            echo
            echo "伪装域名: $INPUT_DOMAIN (状态码: $HTTP_CODE)"
            break
        else
            log_warning "域名验证失败 (状态码: $HTTP_CODE)"
            echo "请重新输入或使用默认域名"
        fi
    done
    
    echo
    echo "配置确认："
    echo "  端口: $INPUT_PORT"
    echo "  伪装域名: $INPUT_DOMAIN"
    echo
    read -p "确认配置并继续？ [Y/n]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        log_info "配置已取消，重新开始..."
        interactive_config
        return
    fi
    
    # Set global variables
    MTPROXY_PORT="$INPUT_PORT"
    FAKE_DOMAIN="$INPUT_DOMAIN"
}

# Generate configuration
generate_config() {
    log_info "Generating configuration..."
    
    CONFIG_FILE="$CONFIG_DIR/mtproxy.conf"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        # Run interactive configuration if not in batch mode
        if [[ "${BATCH_MODE:-}" != "true" ]]; then
            interactive_config
        else
            # Use defaults for batch mode
            MTPROXY_PORT="${MTPROXY_PORT:-8443}"
            FAKE_DOMAIN="${FAKE_DOMAIN:-www.cloudflare.com}"
        fi
        
        # Generate random secret
        SECRET=$(openssl rand -hex 16)
        
        # Generate domain hex for TLS
        DOMAIN_LENGTH=$(echo -n "$FAKE_DOMAIN" | wc -c)
        DOMAIN_LENGTH_HEX=$(printf "%02x" $DOMAIN_LENGTH)
        DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps -c 256)
        TLS_SECRET="dd${SECRET}${DOMAIN_LENGTH_HEX}${DOMAIN_HEX}"
        
        # Display generated secret and require confirmation
        echo
        echo "================================================"
        echo "密钥生成完成"
        echo "================================================"
        echo "基础密钥: $SECRET"
        echo "TLS密钥: $TLS_SECRET"
        echo "伪装域名: $FAKE_DOMAIN"
        echo
        log_warning "请务必保存以上密钥信息！"
        echo
        
        if [[ "${BATCH_MODE:-}" != "true" ]]; then
            read -p "请确认已保存密钥信息，按回车键继续..."
        fi
        
        cat > "$CONFIG_FILE" << EOF
# MTProxy Configuration File
# Generated on $(date)

server:
  host: 0.0.0.0
  port: $MTPROXY_PORT
  secret: $SECRET
  tls_secret: $TLS_SECRET
  fake_domain: $FAKE_DOMAIN
  max_connections: 1000
  timeout: 300
  workers: 4

logging:
  level: INFO
  file: $LOG_DIR/mtproxy.log
  max_size: 100MB
  backup_count: 7

security:
  allowed_ips: []
  banned_ips: []
  rate_limit: 100

monitoring:
  stats_enabled: true
  stats_port: 8080
  health_check_interval: 30

telegram:
  api_id: null
  api_hash: null
  datacenter: auto
EOF

        chown "$USER_NAME:$USER_NAME" "$CONFIG_FILE"
        chmod 640 "$CONFIG_FILE"
        
        log_success "Configuration file created: $CONFIG_FILE"
    else
        log_info "Configuration file already exists"
        # Extract existing values
        MTPROXY_PORT=$(grep "port:" "$CONFIG_FILE" | awk '{print $2}')
        SECRET=$(grep "secret:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
        FAKE_DOMAIN=$(grep "fake_domain:" "$CONFIG_FILE" | awk '{print $2}')
        
        if [[ -z "$FAKE_DOMAIN" ]]; then
            FAKE_DOMAIN="www.cloudflare.com"
        fi
        
        # Generate TLS secret if not exists
        if ! grep -q "tls_secret:" "$CONFIG_FILE"; then
            DOMAIN_LENGTH=$(echo -n "$FAKE_DOMAIN" | wc -c)
            DOMAIN_LENGTH_HEX=$(printf "%02x" $DOMAIN_LENGTH)
            DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps -c 256)
            TLS_SECRET="dd${SECRET}${DOMAIN_LENGTH_HEX}${DOMAIN_HEX}"
            
            # Add TLS secret to config
            sed -i "/secret: $SECRET/a\\  tls_secret: $TLS_SECRET\n  fake_domain: $FAKE_DOMAIN" "$CONFIG_FILE"
        fi
    fi
}

# Setup systemd service
setup_systemd() {
    log_info "Setting up systemd service..."
    
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Python MTProxy Service
Documentation=https://github.com/your-repo/python-mtproxy
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python -m mtproxy.server
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
TimeoutStopSec=30

# Security settings
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$INSTALL_DIR $LOG_DIR

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log_success "Systemd service configured"
}

# Setup log rotation
setup_logrotate() {
    log_info "Setting up log rotation..."
    
    LOGROTATE_FILE="/etc/logrotate.d/$PROJECT_NAME"
    
    cat > "$LOGROTATE_FILE" << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $USER_NAME $USER_NAME
    postrotate
        systemctl reload-or-restart $SERVICE_NAME > /dev/null 2>&1 || true
    endscript
}
EOF

    log_success "Log rotation configured"
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."
    
    # Get the configured port
    local PROXY_PORT="${MTPROXY_PORT:-8443}"
    
    # Check if ufw is available
    if command -v ufw &> /dev/null; then
        # Enable UFW if not enabled
        if ! ufw status | grep -q "Status: active"; then
            log_info "Enabling UFW firewall..."
            ufw --force enable
        fi
        
        # Allow MTProxy port
        ufw allow "$PROXY_PORT/tcp" comment "MTProxy"
        
        # Allow SSH (make sure we don't lock ourselves out)
        ufw allow ssh
        
        log_success "Firewall configured (port $PROXY_PORT allowed)"
    else
        log_warning "UFW not found, skipping firewall configuration"
    fi
}

# Create management scripts
create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Create convenience scripts
    cat > "$INSTALL_DIR/mtproxy-start" << EOF
#!/bin/bash
systemctl start $SERVICE_NAME
EOF

    cat > "$INSTALL_DIR/mtproxy-stop" << EOF
#!/bin/bash
systemctl stop $SERVICE_NAME
EOF

    cat > "$INSTALL_DIR/mtproxy-restart" << EOF
#!/bin/bash
systemctl restart $SERVICE_NAME
EOF

    cat > "$INSTALL_DIR/mtproxy-status" << EOF
#!/bin/bash
systemctl status $SERVICE_NAME
EOF

    cat > "$INSTALL_DIR/mtproxy-logs" << EOF
#!/bin/bash
python3 $INSTALL_DIR/tools/log_viewer.py "\$@"
EOF

    # Make scripts executable
    chmod +x "$INSTALL_DIR"/mtproxy-*
    
    # Create symlinks in /usr/local/bin
    ln -sf "$INSTALL_DIR/tools/mtproxy_cli.py" /usr/local/bin/mtproxy-cli
    ln -sf "$INSTALL_DIR/tools/log_viewer.py" /usr/local/bin/mtproxy-logs
    ln -sf "$INSTALL_DIR/tools/health_check.py" /usr/local/bin/mtproxy-health
    
    log_success "Management scripts created"
}

# Production deployment
deploy_production() {
    log_info "Starting production deployment..."
    
    check_root
    check_system
    install_dependencies
    create_user
    setup_directories
    install_application
    generate_config
    setup_systemd
    setup_logrotate
    setup_firewall
    create_management_scripts
    
    log_success "Production deployment completed!"
    
    # Show connection information
    show_connection_info
}

# Development deployment
deploy_development() {
    log_info "Starting development deployment..."
    
    check_root
    check_system
    install_dependencies
    create_user
    setup_directories
    install_application
    generate_config
    setup_systemd
    create_management_scripts
    
    log_success "Development deployment completed!"
    
    # Show connection information
    show_connection_info
}

# Update deployment
update_deployment() {
    log_info "Updating deployment..."
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_error "Installation directory not found. Please run full deployment first."
        exit 1
    fi
    
    # Stop service
    log_info "Stopping service..."
    systemctl stop "$SERVICE_NAME" || true
    
    # Backup current installation
    BACKUP_DIR="$INSTALL_DIR/backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$INSTALL_DIR/mtproxy" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$INSTALL_DIR/tools" "$BACKUP_DIR/" 2>/dev/null || true
    
    # Update application
    install_application
    
    # Update dependencies
    log_info "Updating Python dependencies..."
    sudo -u "$USER_NAME" "$INSTALL_DIR/venv/bin/pip" install --upgrade -r "$INSTALL_DIR/requirements.txt"
    
    # Start service
    log_info "Starting service..."
    systemctl start "$SERVICE_NAME"
    
    log_success "Update completed!"
}

# Uninstall
uninstall() {
    log_info "Starting uninstallation..."
    
    # Stop and disable service
    log_info "Stopping and disabling service..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # Remove service file
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    
    # Remove logrotate configuration
    rm -f "/etc/logrotate.d/$PROJECT_NAME"
    
    # Remove symlinks
    rm -f /usr/local/bin/mtproxy-cli
    rm -f /usr/local/bin/mtproxy-logs
    rm -f /usr/local/bin/mtproxy-health
    
    # Remove installation directory
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "Removing installation directory..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # Remove user
    if id "$USER_NAME" &>/dev/null; then
        log_info "Removing user..."
        userdel "$USER_NAME" 2>/dev/null || true
    fi
    
    log_success "Uninstallation completed!"
}

# Show connection information
show_connection_info() {
    echo
    echo "================================================"
    echo "🎉 MTProxy 部署完成！"
    echo "================================================"
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
    
    # Get configuration from config file
    if [[ -f "$CONFIG_DIR/mtproxy.conf" ]]; then
        SECRET=$(grep "secret:" "$CONFIG_DIR/mtproxy.conf" | head -1 | awk '{print $2}' | tr -d '"')
        TLS_SECRET=$(grep "tls_secret:" "$CONFIG_DIR/mtproxy.conf" | awk '{print $2}' | tr -d '"')
        PORT=$(grep "port:" "$CONFIG_DIR/mtproxy.conf" | awk '{print $2}')
        FAKE_DOMAIN=$(grep "fake_domain:" "$CONFIG_DIR/mtproxy.conf" | awk '{print $2}' | tr -d '"')
    else
        SECRET="CHECK_CONFIG_FILE"
        TLS_SECRET="CHECK_CONFIG_FILE"
        PORT="8443"
        FAKE_DOMAIN="www.cloudflare.com"
    fi
    
    echo "📊 服务器信息:"
    echo "  IP地址: $SERVER_IP"
    echo "  端口: $PORT"
    echo "  基础密钥: $SECRET"
    echo "  TLS密钥: $TLS_SECRET"
    echo "  伪装域名: $FAKE_DOMAIN"
    echo
    echo "📱 Telegram代理链接:"
    echo "  普通模式: https://t.me/proxy?server=$SERVER_IP&port=$PORT&secret=$SECRET"
    echo "  TLS模式:  https://t.me/proxy?server=$SERVER_IP&port=$PORT&secret=$TLS_SECRET"
    echo
    echo "💡 使用方法:"
    echo "  1. 复制上面的任一代理链接"
    echo "  2. 在Telegram中打开链接"
    echo "  3. 点击'连接代理'即可使用"
    echo "  （推荐使用TLS模式，连接更稳定）"
    echo
    echo "🛠️ 管理命令:"
    echo "  启动:   systemctl start $SERVICE_NAME"
    echo "  停止:   systemctl stop $SERVICE_NAME"
    echo "  状态:   systemctl status $SERVICE_NAME"
    echo "  日志:   mtproxy-logs --follow"
    echo "  健康检查: mtproxy-health"
    echo "  命令行工具: mtproxy-cli status"
    echo
    echo "📁 文件位置:"
    echo "  配置文件: $CONFIG_DIR/mtproxy.conf"
    echo "  日志文件: $LOG_DIR/"
    echo "================================================"
}

# Main execution
main() {
    case "${1:-}" in
        --production|--prod)
            deploy_production
            ;;
        --development|--dev)
            deploy_development
            ;;
        --update)
            update_deployment
            ;;
        --uninstall)
            uninstall
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --production   Deploy for production use"
            echo "  --development  Deploy for development use"
            echo "  --update       Update existing deployment"
            echo "  --uninstall    Remove MTProxy installation"
            echo "  --help         Show this help message"
            ;;
        "")
            deploy_production
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Trap signals for cleanup
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"
