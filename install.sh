#!/bin/bash

# MTProxy Manager 一键安装脚本
# 适用于 Ubuntu/Debian/CentOS 系统
# 作者: MTProxy Team
# 版本: 3.0
# 使用方法: bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)

set -e

# 配置
PROJECT_NAME="python-mtproxy"
INSTALL_DIR="/opt/${PROJECT_NAME}"
SERVICE_NAME="${PROJECT_NAME}"
USER_NAME="mtproxy"
PYTHON_MIN_VERSION="3.8"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 输出函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_title() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        echo "请使用: sudo bash install.sh"
        exit 1
    fi
}

# 检查系统兼容性
check_system() {
    print_info "检查系统兼容性..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu|debian)
                PACKAGE_MANAGER="apt"
                ;;
            centos|rhel|fedora)
                PACKAGE_MANAGER="yum"
                ;;
            *)
                print_warning "未测试的系统: $ID"
                PACKAGE_MANAGER="apt"
                ;;
        esac
    else
        print_warning "无法识别系统，假设为Debian/Ubuntu"
        PACKAGE_MANAGER="apt"
    fi
    
    print_success "系统检查完成 - $ID ($PACKAGE_MANAGER)"
}

# 安装依赖
install_dependencies() {
    print_info "安装系统依赖..."
    
    case $PACKAGE_MANAGER in
        apt)
            apt update
            apt install -y python3 python3-pip python3-venv git curl wget systemd
            ;;
        yum)
            yum update -y
            yum install -y python3 python3-pip git curl wget systemd
            ;;
    esac
    
    # 检查Python版本
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        print_success "Python版本检查通过: $PYTHON_VERSION"
    else
        print_error "Python版本过低: $PYTHON_VERSION，需要$PYTHON_MIN_VERSION+"
        exit 1
    fi
}

# 创建用户和目录
setup_environment() {
    print_info "设置环境..."
    
    # 创建用户
    if ! id "$USER_NAME" &>/dev/null; then
        useradd -r -s /bin/false -d "$INSTALL_DIR" "$USER_NAME"
        print_success "创建用户: $USER_NAME"
    fi
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"/{config,logs,data}
    
    # 设置权限
    chown -R "$USER_NAME:$USER_NAME" "$INSTALL_DIR"
    print_success "环境设置完成"
}

# 下载和安装代码
install_code() {
    print_info "安装MTProxy代码..."
    
    # 如果是从远程安装，下载代码
    if [[ ! -f "mtproxy/server.py" ]]; then
        cd /tmp
        git clone https://github.com/OrangeKing92/mtproxy-manager.git
        cd mtproxy-manager
    fi
    
    # 复制文件
    cp -r mtproxy "$INSTALL_DIR/"
    cp -r tools "$INSTALL_DIR/"
    cp -r config "$INSTALL_DIR/"
    
    # 复制依赖文件
    if [[ -f requirements.txt ]]; then
        cp requirements.txt "$INSTALL_DIR/"
    fi
    
    # 安装Python依赖
    cd "$INSTALL_DIR"
    if [[ -f requirements.txt ]]; then
        python3 -m pip install -r requirements.txt
    else
        # 创建基础requirements.txt
        cat > requirements.txt << 'EOF'
asyncio>=3.4.3
cryptography>=3.4.8
pycryptodome>=3.15.0
click>=8.0.0
colorama>=0.4.4
psutil>=5.8.0
requests>=2.25.1
pyyaml>=6.0
python-dateutil>=2.8.2
tabulate>=0.9.0
watchdog>=2.1.6
EOF
        python3 -m pip install -r requirements.txt
    fi
    
    print_success "代码安装完成"
}

# 配置服务
setup_service() {
    print_info "配置systemd服务..."
    
    # 生成配置文件
    python3 "$INSTALL_DIR/tools/mtproxy_cli.py" generate-config
    
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

# 创建管理命令
setup_management() {
    print_info "设置管理工具..."
    
    # 复制管理脚本
    if [[ -f scripts/manage.sh ]]; then
        cp scripts/manage.sh "$INSTALL_DIR/"
        cp scripts/uninstall.sh "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/manage.sh"
        chmod +x "$INSTALL_DIR/uninstall.sh"
    fi
    
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
    print_info "启动MTProxy服务..."
    
    systemctl start "$SERVICE_NAME"
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败"
        systemctl status "$SERVICE_NAME" --no-pager
        exit 1
    fi
}

# 显示连接信息
show_connection_info() {
    print_title "安装完成"
    
    echo "MTProxy已成功安装并启动！"
    echo ""
    echo "管理命令:"
    echo "  mtproxy          # 打开管理面板"
    echo ""
    echo "系统命令:"
    echo "  systemctl status python-mtproxy    # 查看状态"
    echo "  systemctl restart python-mtproxy   # 重启服务"
    echo "  journalctl -u python-mtproxy -f    # 查看日志"
    echo ""
    
    # 显示连接信息
    if [[ -f "$INSTALL_DIR/tools/mtproxy_cli.py" ]]; then
        echo "连接信息:"
        python3 "$INSTALL_DIR/tools/mtproxy_cli.py" proxy
    fi
    
    echo ""
    print_success "请运行 'mtproxy' 命令打开管理面板"
}

# 主安装函数
main() {
    print_title "MTProxy Manager 安装"
    
    echo -e "${YELLOW}MTProxy Manager - Python实现的Telegram代理${NC}"
    echo ""
    echo "特性:"
    echo "• 🔧 一键安装 - 自动化部署"
    echo "• 🎛️ 交互式管理 - 直观的命令行界面"
    echo "• 🌐 远程控制 - 完整的SSH远程管理"
    echo "• 🔒 安全可靠 - TLS支持，自动密钥生成"
    echo "• ⚡ 高性能 - 异步架构，支持高并发"
    echo ""
    echo "项目地址: https://github.com/OrangeKing92/mtproxy-manager"
    echo ""
    
    read -p "是否继续安装MTProxy Manager? [Y/n]: " confirm
    if [[ $confirm == [Nn] ]]; then
        print_info "取消安装"
        exit 0
    fi
    
    # 执行安装步骤
    check_root
    check_system
    install_dependencies
    setup_environment
    install_code
    setup_service
    setup_management
    start_service
    show_connection_info
}

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi