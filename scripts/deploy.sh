#!/bin/bash
# MTProxy Local Deployment Script 
# 用于本地开发环境的部署脚本
# Usage: sudo ./scripts/deploy.sh [--dev|--prod]

set -e

# 配置
PROJECT_NAME="python-mtproxy"
INSTALL_DIR="/opt/${PROJECT_NAME}"
SERVICE_NAME="${PROJECT_NAME}"
USER_NAME="mtproxy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 输出函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 部署模式
MODE="prod"
if [[ "$1" == "--dev" ]]; then
    MODE="dev"
    print_info "开发模式部署"
else
    print_info "生产模式部署"
fi

# 安装系统依赖
install_dependencies() {
    print_info "安装系统依赖..."
    
    if command -v apt >/dev/null; then
        apt update
        apt install -y python3 python3-pip python3-venv systemd
    elif command -v yum >/dev/null; then
        yum update -y
        yum install -y python3 python3-pip systemd
    else
        print_error "不支持的包管理器"
        exit 1
    fi
    
    print_success "系统依赖安装完成"
}

# 创建用户和目录
setup_environment() {
    print_info "设置环境..."
    
    # 创建用户
    if ! id "$USER_NAME" &>/dev/null; then
        useradd -r -s /bin/false -d "$INSTALL_DIR" "$USER_NAME"
        print_success "创建用户: $USER_NAME"
    fi
    
    # 创建目录
    mkdir -p "$INSTALL_DIR"/{config,logs,data}
    
    # 设置权限
    chown -R "$USER_NAME:$USER_NAME" "$INSTALL_DIR"
    print_success "环境设置完成"
}

# 部署代码
deploy_code() {
    print_info "部署代码..."
    
    # 停止现有服务
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME"
        print_info "停止现有服务"
    fi
    
    # 复制代码
    cd "$PROJECT_ROOT"
    cp -r mtproxy "$INSTALL_DIR/"
    cp -r tools "$INSTALL_DIR/"
    cp -r config "$INSTALL_DIR/"
    
    # 复制依赖文件
    if [[ -f requirements.txt ]]; then
        cp requirements.txt "$INSTALL_DIR/"
    fi
    
    # 安装Python依赖
    cd "$INSTALL_DIR"
    python3 -m pip install -r requirements.txt
    
    # 设置权限
    chown -R "$USER_NAME:$USER_NAME" "$INSTALL_DIR"
    
    print_success "代码部署完成"
}

# 配置服务
setup_service() {
    print_info "配置systemd服务..."
    
    # 生成配置文件
    if [[ ! -f "$INSTALL_DIR/config/mtproxy.conf" ]]; then
        python3 "$INSTALL_DIR/tools/mtproxy_cli.py" generate-config
    fi
    
    # 创建systemd服务文件
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=MTProxy - Telegram Proxy Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 -m mtproxy.server
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

    # 重载systemd并启用服务
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    print_success "服务配置完成"
}

# 设置管理工具
setup_management() {
    print_info "设置管理工具..."
    
    # 复制管理脚本
    cp "$PROJECT_ROOT/scripts/manage.sh" "$INSTALL_DIR/"
    cp "$PROJECT_ROOT/scripts/uninstall.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/manage.sh"
    chmod +x "$INSTALL_DIR/uninstall.sh"
    
    # 创建全局命令
    cat > /usr/local/bin/mtproxy << 'EOF'
#!/bin/bash
exec sudo /opt/python-mtproxy/manage.sh "$@"
EOF
    chmod +x /usr/local/bin/mtproxy
    
    print_success "管理工具设置完成"
}

# 启动服务
start_service() {
    print_info "启动服务..."
    
    systemctl start "$SERVICE_NAME"
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "服务启动成功"
        
        # 显示状态
        systemctl status "$SERVICE_NAME" --no-pager -l
        
        # 显示连接信息
        if [[ -f "$INSTALL_DIR/tools/mtproxy_cli.py" ]]; then
            echo ""
            print_info "连接信息:"
            python3 "$INSTALL_DIR/tools/mtproxy_cli.py" proxy
        fi
    else
        print_error "服务启动失败"
        systemctl status "$SERVICE_NAME" --no-pager
        exit 1
    fi
}

# 主函数
main() {
    echo "MTProxy 本地部署脚本"
    echo "===================="
    echo ""
    
    check_root
    install_dependencies
    setup_environment
    deploy_code
    setup_service
    setup_management
    start_service
    
    echo ""
    print_success "部署完成！使用 'mtproxy' 命令管理服务"
}

# 执行主函数
main "$@"