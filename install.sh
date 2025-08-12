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
            apt install -y python3 python3-pip python3-venv python3-full git curl wget systemd
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
        # 检查并删除已存在的目录
        if [[ -d "mtproxy-manager" ]]; then
            print_warning "删除已存在的目录: /tmp/mtproxy-manager"
            rm -rf mtproxy-manager
        fi
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
    
    # 创建虚拟环境
    cd "$INSTALL_DIR"
    print_info "创建Python虚拟环境..."
    python3 -m venv venv
    source venv/bin/activate
    
    # 升级pip
    pip install --upgrade pip
    
    # 安装Python依赖
    if [[ -f requirements.txt ]]; then
        pip install -r requirements.txt
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
        pip install -r requirements.txt
    fi
    
    print_success "代码安装完成"
}

# 交互式配置
interactive_config() {
    print_title "交互式配置"
    echo ""
    echo "请根据提示输入配置信息，按回车使用默认值："
    echo ""
    
    # 获取服务器IP
    SERVER_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || echo "127.0.0.1")
    
    # 交互式输入
    read -p "请输入客户端连接端口 [默认: 443]: " CLIENT_PORT
    CLIENT_PORT=${CLIENT_PORT:-443}
    
    read -p "请输入管理端口 [默认: 8080]: " ADMIN_PORT
    ADMIN_PORT=${ADMIN_PORT:-8080}
    
    read -p "请输入伪装域名 [默认: azure.microsoft.com]: " FAKE_DOMAIN
    FAKE_DOMAIN=${FAKE_DOMAIN:-azure.microsoft.com}
    
    read -p "请输入推广TAG (可选，回车跳过): " PROMO_TAG
    
    read -p "请输入管理员密码 [默认: admin123]: " ADMIN_PASSWORD
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin123}
    
    echo ""
    print_info "配置信息确认："
    echo "• 服务器IP: $SERVER_IP"
    echo "• 客户端端口: $CLIENT_PORT"  
    echo "• 管理端口: $ADMIN_PORT"
    echo "• 伪装域名: $FAKE_DOMAIN"
    echo "• 推广TAG: ${PROMO_TAG:-无}"
    echo "• 管理员密码: $ADMIN_PASSWORD"
    echo ""
    
    read -p "确认配置信息是否正确？[Y/n]: " confirm_config
    if [[ $confirm_config == [Nn] ]]; then
        print_info "重新配置..."
        interactive_config
        return
    fi
    
    # 保存配置到临时变量，稍后写入配置文件
    export MTPROXY_CLIENT_PORT="$CLIENT_PORT"
    export MTPROXY_ADMIN_PORT="$ADMIN_PORT"
    export MTPROXY_FAKE_DOMAIN="$FAKE_DOMAIN"
    export MTPROXY_PROMO_TAG="$PROMO_TAG"
    export MTPROXY_ADMIN_PASSWORD="$ADMIN_PASSWORD"
    export MTPROXY_SERVER_IP="$SERVER_IP"
    
    print_success "配置信息已保存"
}

# 生成配置文件
generate_config_with_params() {
    print_info "生成配置文件..."
    
    # 生成随机密钥
    SECRET=$(openssl rand -hex 16)
    
    # 生成配置文件
    cat > "$INSTALL_DIR/config/mtproxy.conf" << EOF
# MTProxy Configuration File
# Generated on $(date)

# Basic Settings
server:
  host: "0.0.0.0"
  port: ${MTPROXY_CLIENT_PORT}
  
# TLS Settings  
tls:
  enabled: true
  fake_domain: "${MTPROXY_FAKE_DOMAIN}"
  
# Proxy Settings
proxy:
  secret: "${SECRET}"
  tag: "${MTPROXY_PROMO_TAG}"
  
# Admin Settings
admin:
  enabled: true
  port: ${MTPROXY_ADMIN_PORT}
  username: "admin"
  password: "${MTPROXY_ADMIN_PASSWORD}"
  
# Security Settings
security:
  max_connections: 1000
  timeout: 300
  
# Logging
logging:
  level: "INFO"
  file: "logs/mtproxy.log"
  max_size: "10MB"
  backup_count: 5
EOF

    print_success "配置文件已生成: $INSTALL_DIR/config/mtproxy.conf"
}

# 配置服务
setup_service() {
    print_info "配置systemd服务..."
    
    # 生成配置文件 - 使用交互式配置的参数
    generate_config_with_params
    
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
ExecStart=$INSTALL_DIR/venv/bin/python -m mtproxy.server
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
    cat > /usr/local/bin/mtproxy << EOF
#!/bin/bash
cd "$INSTALL_DIR"
export PATH="$INSTALL_DIR/venv/bin:\$PATH"
exec sudo "$INSTALL_DIR/manage.sh" "\$@"
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
    
    # 读取配置文件中的密钥
    if [[ -f "$INSTALL_DIR/config/mtproxy.conf" ]]; then
        SECRET=$(grep "secret:" "$INSTALL_DIR/config/mtproxy.conf" | cut -d'"' -f2)
        
        echo "📱 Telegram连接信息:"
        echo "────────────────────────────────────────"
        echo "🌐 服务器IP: ${MTPROXY_SERVER_IP}"
        echo "🔌 端口: ${MTPROXY_CLIENT_PORT}"
        echo "🔑 密钥: ${SECRET}"
        echo "🎭 伪装域名: ${MTPROXY_FAKE_DOMAIN}"
        if [[ -n "${MTPROXY_PROMO_TAG}" ]]; then
            echo "🏷️  推广TAG: ${MTPROXY_PROMO_TAG}"
        fi
        echo ""
        echo "📋 连接链接:"
        if [[ -n "${MTPROXY_PROMO_TAG}" ]]; then
            echo "https://t.me/proxy?server=${MTPROXY_SERVER_IP}&port=${MTPROXY_CLIENT_PORT}&secret=ee${SECRET}${MTPROXY_FAKE_DOMAIN}&tag=${MTPROXY_PROMO_TAG}"
        else
            echo "https://t.me/proxy?server=${MTPROXY_SERVER_IP}&port=${MTPROXY_CLIENT_PORT}&secret=ee${SECRET}${MTPROXY_FAKE_DOMAIN}"
        fi
        echo ""
        echo "🔧 管理面板:"
        echo "http://${MTPROXY_SERVER_IP}:${MTPROXY_ADMIN_PORT}"
        echo "用户名: admin"
        echo "密码: ${MTPROXY_ADMIN_PASSWORD}"
        echo ""
    fi
    
    echo "📖 管理命令:"
    echo "  mtproxy          # 打开管理面板"
    echo "  mtproxy status   # 查看状态"
    echo "  mtproxy restart  # 重启服务"
    echo "  mtproxy logs     # 查看日志"
    echo ""
    echo "🔧 系统命令:"
    echo "  systemctl status python-mtproxy    # 查看状态"
    echo "  systemctl restart python-mtproxy   # 重启服务"
    echo "  journalctl -u python-mtproxy -f    # 查看日志"
    echo ""
    
    print_success "安装完成！请保存上述连接信息"
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
    interactive_config  # 添加交互式配置
    setup_service
    setup_management
    start_service
    show_connection_info
}

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi