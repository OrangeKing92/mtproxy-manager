#!/bin/bash

# MTProxy Manager 交互式安装脚本
# 作者: MTProxy Team
# 版本: 3.1
# 参考: https://github.com/sunpma/mtp.git
# 使用方法: bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install_interactive.sh)

set -e

# 配置
PROJECT_NAME="python-mtproxy"
INSTALL_DIR="/opt/${PROJECT_NAME}"
SERVICE_NAME="${PROJECT_NAME}"
USER_NAME="mtproxy"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
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
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
}

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "    __  __  _______  _____                       "
    echo "   |  \/  ||__   __|  __ \                      "
    echo "   | \  / |   | |  | |__) |_ __   ___  __  __  _   _ "
    echo "   | |\/| |   | |  |  ___/| '__| / _ \ \\\\\\/  || | | |"
    echo "   | |  | |   | |  | |    | |   | (_) |>  <| |_| |"
    echo "   |_|  |_|   |_|  |_|    |_|   \___//_/\_\\\\___/"
    echo ""
    echo -e "${WHITE}      Telegram MTProxy Manager v3.1${NC}"
    echo -e "${CYAN}      https://github.com/OrangeKing92/mtproxy-manager${NC}"
    echo ""
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        echo "请使用: sudo bash install_interactive.sh"
        exit 1
    fi
}

# 获取服务器信息
get_server_info() {
    print_info "获取服务器信息..."
    
    # 获取服务器IP
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || curl -s -4 ipecho.net/plain 2>/dev/null || echo "127.0.0.1")
    
    # 检测系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME="$PRETTY_NAME"
    else
        OS_NAME="Unknown Linux"
    fi
    
    # 检测CPU架构
    ARCH=$(uname -m)
    
    # 检测内存
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    
    echo ""
    echo -e "${GREEN}服务器信息:${NC}"
    echo "• IP地址: ${SERVER_IP}"
    echo "• 系统: ${OS_NAME}"
    echo "• 架构: ${ARCH}"
    echo "• 内存: ${MEM_TOTAL}"
    echo ""
}

# 交互式配置
interactive_setup() {
    print_title "交互式配置向导"
    
    echo -e "${YELLOW}请根据提示输入配置信息，直接按回车使用默认值${NC}"
    echo ""
    
    # 1. 客户端端口
    while true; do
        read -p "$(echo -e ${CYAN}请输入客户端连接端口${NC}) [默认: 443]: " CLIENT_PORT
        CLIENT_PORT=${CLIENT_PORT:-443}
        
        if [[ "$CLIENT_PORT" =~ ^[0-9]+$ ]] && [ "$CLIENT_PORT" -ge 1 ] && [ "$CLIENT_PORT" -le 65535 ]; then
            if netstat -tuln | grep ":$CLIENT_PORT " >/dev/null 2>&1; then
                print_warning "端口 $CLIENT_PORT 已被占用，请选择其他端口"
            else
                break
            fi
        else
            print_warning "请输入有效的端口号 (1-65535)"
        fi
    done
    
    # 2. 管理端口
    while true; do
        read -p "$(echo -e ${CYAN}请输入管理端口${NC}) [默认: 8080]: " ADMIN_PORT
        ADMIN_PORT=${ADMIN_PORT:-8080}
        
        if [[ "$ADMIN_PORT" =~ ^[0-9]+$ ]] && [ "$ADMIN_PORT" -ge 1 ] && [ "$ADMIN_PORT" -le 65535 ] && [ "$ADMIN_PORT" != "$CLIENT_PORT" ]; then
            if netstat -tuln | grep ":$ADMIN_PORT " >/dev/null 2>&1; then
                print_warning "端口 $ADMIN_PORT 已被占用，请选择其他端口"
            else
                break
            fi
        else
            print_warning "请输入有效的端口号 (1-65535)，且不能与客户端端口相同"
        fi
    done
    
    # 3. 伪装域名
    echo ""
    echo -e "${YELLOW}伪装域名选择:${NC}"
    echo "1) azure.microsoft.com (推荐)"
    echo "2) cdn.cloudflare.com"
    echo "3) www.google.com"
    echo "4) 自定义域名"
    echo ""
    
    while true; do
        read -p "$(echo -e ${CYAN}请选择伪装域名${NC}) [默认: 1]: " domain_choice
        domain_choice=${domain_choice:-1}
        
        case $domain_choice in
            1)
                FAKE_DOMAIN="azure.microsoft.com"
                break
                ;;
            2)
                FAKE_DOMAIN="cdn.cloudflare.com"
                break
                ;;
            3)
                FAKE_DOMAIN="www.google.com"
                break
                ;;
            4)
                read -p "$(echo -e ${CYAN}请输入自定义域名${NC}): " FAKE_DOMAIN
                if [[ -n "$FAKE_DOMAIN" ]]; then
                    break
                else
                    print_warning "域名不能为空"
                fi
                ;;
            *)
                print_warning "请输入有效选项 (1-4)"
                ;;
        esac
    done
    
    # 4. 推广TAG (可选)
    echo ""
    read -p "$(echo -e ${CYAN}请输入推广TAG${NC}) (可选，直接回车跳过): " PROMO_TAG
    
    # 5. 管理员密码
    while true; do
        read -p "$(echo -e ${CYAN}请输入管理员密码${NC}) [默认: admin123]: " ADMIN_PASSWORD
        ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin123}
        
        if [[ ${#ADMIN_PASSWORD} -ge 6 ]]; then
            break
        else
            print_warning "密码长度至少6位"
        fi
    done
    
    # 确认配置
    echo ""
    print_title "配置信息确认"
    echo -e "${GREEN}服务器IP:${NC} $SERVER_IP"
    echo -e "${GREEN}客户端端口:${NC} $CLIENT_PORT"  
    echo -e "${GREEN}管理端口:${NC} $ADMIN_PORT"
    echo -e "${GREEN}伪装域名:${NC} $FAKE_DOMAIN"
    echo -e "${GREEN}推广TAG:${NC} ${PROMO_TAG:-无}"
    echo -e "${GREEN}管理员密码:${NC} $ADMIN_PASSWORD"
    echo ""
    
    while true; do
        read -p "$(echo -e ${YELLOW}确认配置信息是否正确？${NC}) [Y/n]: " confirm_config
        case $confirm_config in
            [Yy]* | "")
                break
                ;;
            [Nn]*)
                print_info "重新配置..."
                interactive_setup
                return
                ;;
            *)
                print_warning "请输入 Y 或 n"
                ;;
        esac
    done
    
    # 保存配置
    export MTPROXY_CLIENT_PORT="$CLIENT_PORT"
    export MTPROXY_ADMIN_PORT="$ADMIN_PORT"
    export MTPROXY_FAKE_DOMAIN="$FAKE_DOMAIN"
    export MTPROXY_PROMO_TAG="$PROMO_TAG"
    export MTPROXY_ADMIN_PASSWORD="$ADMIN_PASSWORD"
    export MTPROXY_SERVER_IP="$SERVER_IP"
    
    print_success "配置信息已保存"
}

# 安装系统依赖
install_dependencies() {
    print_title "安装系统依赖"
    
    print_info "更新包管理器..."
    if command -v apt >/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt update -qq
        apt install -y python3 python3-pip python3-venv python3-full git curl wget openssl systemd netstat-nat >/dev/null 2>&1
    elif command -v yum >/dev/null; then
        yum update -y -q
        yum install -y python3 python3-pip git curl wget openssl systemd net-tools >/dev/null 2>&1
    else
        print_error "不支持的系统"
        exit 1
    fi
    
    # 检查Python版本
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        print_success "Python版本检查通过: $PYTHON_VERSION"
    else
        print_error "Python版本过低: $PYTHON_VERSION，需要3.8+"
        exit 1
    fi
}

# 安装MTProxy
install_mtproxy() {
    print_title "安装MTProxy"
    
    # 创建用户
    if ! id "$USER_NAME" &>/dev/null; then
        useradd -r -s /bin/false -d "$INSTALL_DIR" "$USER_NAME" >/dev/null 2>&1
        print_success "创建用户: $USER_NAME"
    fi
    
    # 创建目录
    mkdir -p "$INSTALL_DIR"/{config,logs,data}
    
    # 下载代码
    print_info "下载代码..."
    cd /tmp
    if [[ -d "mtproxy-manager" ]]; then
        rm -rf mtproxy-manager
    fi
    
    git clone -q https://github.com/OrangeKing92/mtproxy-manager.git
    cd mtproxy-manager
    
    # 复制文件
    cp -r mtproxy "$INSTALL_DIR/"
    cp -r tools "$INSTALL_DIR/"
    cp -r config "$INSTALL_DIR/"
    
    # 创建虚拟环境
    cd "$INSTALL_DIR"
    python3 -m venv venv >/dev/null 2>&1
    source venv/bin/activate
    
    # 安装依赖
    print_info "安装Python依赖..."
    pip install --upgrade pip -q
    
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
    
    pip install -r requirements.txt -q
    
    # 设置权限
    chown -R "$USER_NAME:$USER_NAME" "$INSTALL_DIR"
    
    print_success "MTProxy安装完成"
}

# 生成配置文件
generate_config() {
    print_title "生成配置文件"
    
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

    print_success "配置文件已生成"
}

# 配置服务
setup_service() {
    print_title "配置系统服务"
    
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
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    
    print_success "服务配置完成"
}

# 创建管理工具
setup_management() {
    print_title "配置管理工具"
    
    # 创建全局命令
    cat > /usr/local/bin/mtproxy << EOF
#!/bin/bash
cd "$INSTALL_DIR"
export PATH="$INSTALL_DIR/venv/bin:\$PATH"
exec sudo "$INSTALL_DIR/manage.sh" "\$@"
EOF
    chmod +x /usr/local/bin/mtproxy
    
    print_success "管理工具配置完成"
}

# 启动服务
start_service() {
    print_title "启动服务"
    
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
show_results() {
    print_banner
    print_title "🎉 安装完成"
    
    # 读取密钥
    SECRET=$(grep "secret:" "$INSTALL_DIR/config/mtproxy.conf" | cut -d'"' -f2)
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}📱 Telegram连接信息${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}🌐 服务器IP:${NC} ${MTPROXY_SERVER_IP}"
    echo -e "${CYAN}🔌 端口:${NC} ${MTPROXY_CLIENT_PORT}"
    echo -e "${CYAN}🔑 密钥:${NC} ${SECRET}"
    echo -e "${CYAN}🎭 伪装域名:${NC} ${MTPROXY_FAKE_DOMAIN}"
    if [[ -n "${MTPROXY_PROMO_TAG}" ]]; then
        echo -e "${CYAN}🏷️  推广TAG:${NC} ${MTPROXY_PROMO_TAG}"
    fi
    echo ""
    echo -e "${YELLOW}📋 连接链接:${NC}"
    if [[ -n "${MTPROXY_PROMO_TAG}" ]]; then
        echo "https://t.me/proxy?server=${MTPROXY_SERVER_IP}&port=${MTPROXY_CLIENT_PORT}&secret=ee${SECRET}${MTPROXY_FAKE_DOMAIN}&tag=${MTPROXY_PROMO_TAG}"
    else
        echo "https://t.me/proxy?server=${MTPROXY_SERVER_IP}&port=${MTPROXY_CLIENT_PORT}&secret=ee${SECRET}${MTPROXY_FAKE_DOMAIN}"
    fi
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}🔧 管理面板${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}🌐 访问地址:${NC} http://${MTPROXY_SERVER_IP}:${MTPROXY_ADMIN_PORT}"
    echo -e "${CYAN}👤 用户名:${NC} admin"
    echo -e "${CYAN}🔒 密码:${NC} ${MTPROXY_ADMIN_PASSWORD}"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}📖 常用命令${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}mtproxy${NC}          # 打开管理面板"
    echo -e "${YELLOW}mtproxy status${NC}   # 查看运行状态"
    echo -e "${YELLOW}mtproxy restart${NC}  # 重启服务"
    echo -e "${YELLOW}mtproxy logs${NC}     # 查看运行日志"
    echo -e "${YELLOW}mtproxy stop${NC}     # 停止服务"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    print_success "🎊 MTProxy安装完成！请保存上述连接信息"
    echo ""
}

# 主函数
main() {
    print_banner
    
    echo -e "${YELLOW}MTProxy Manager - Python实现的Telegram代理${NC}"
    echo ""
    echo "✨ 特性:"
    echo "• 🔧 一键安装 - 全自动化部署"
    echo "• 🎛️ 交互式配置 - 简单易用的配置向导"
    echo "• 🌐 Web管理 - 完整的Web管理界面"
    echo "• 🔒 安全可靠 - TLS支持，自动密钥生成"
    echo "• ⚡ 高性能 - 异步架构，支持高并发"
    echo ""
    echo -e "${CYAN}项目地址: https://github.com/OrangeKing92/mtproxy-manager${NC}"
    echo ""
    
    while true; do
        read -p "$(echo -e ${YELLOW}是否开始安装MTProxy Manager？${NC}) [Y/n]: " confirm
        case $confirm in
            [Yy]* | "")
                break
                ;;
            [Nn]*)
                print_info "取消安装"
                exit 0
                ;;
            *)
                print_warning "请输入 Y 或 n"
                ;;
        esac
    done
    
    # 执行安装步骤
    check_root
    get_server_info
    interactive_setup
    install_dependencies
    install_mtproxy
    generate_config
    setup_service
    setup_management
    start_service
    show_results
}

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
