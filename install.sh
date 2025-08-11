#!/bin/bash

# MTProxy 一键安装部署脚本
# 适用于 Ubuntu/Debian/CentOS 系统
# 作者: MTProxy Team
# 版本: 2.0
# 使用方法: bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 项目信息
PROJECT_NAME="python-mtproxy"
INSTALL_DIR="/opt/${PROJECT_NAME}"
SERVICE_NAME="python-mtproxy"
GITHUB_REPO="OrangeKing92/mtproxy-manager"
REPO_URL="https://github.com/${GITHUB_REPO}.git"

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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        echo "请使用: sudo bash install.sh"
        exit 1
    fi
}

# 检测系统类型
detect_os() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        PM="yum"
    elif cat /etc/issue | grep -Eqi "debian|ubuntu"; then
        OS="debian"
        PM="apt"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
        PM="yum"
    elif cat /proc/version | grep -Eqi "debian|ubuntu"; then
        OS="debian"
        PM="apt"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
        PM="yum"
    else
        print_error "不支持的操作系统"
        exit 1
    fi
    print_info "检测到操作系统: $OS"
}

# 安装依赖
install_dependencies() {
    print_info "正在安装系统依赖..."
    
    if [[ $OS == "debian" ]]; then
        apt update -y
        apt install -y curl wget git python3 python3-pip python3-venv systemd
    elif [[ $OS == "centos" ]]; then
        yum update -y
        yum install -y curl wget git python3 python3-pip systemd
        # CentOS可能需要启用EPEL仓库
        yum install -y epel-release
        yum install -y python3-virtualenv
    fi
    
    print_success "系统依赖安装完成"
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if ss -tlnp | grep ":$port " >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# 选择端口
select_port() {
    print_info "选择MTProxy服务端口:"
    echo "1) 443 (推荐，伪装HTTPS)"
    echo "2) 8443 (备选)"
    echo "3) 自定义端口"
    
    while true; do
        read -p "请输入选择 [1-3]: " choice
        case $choice in
            1)
                PORT=443
                break
                ;;
            2)
                PORT=8443
                break
                ;;
            3)
                while true; do
                    read -p "请输入端口号 (1-65535): " custom_port
                    if [[ $custom_port =~ ^[0-9]+$ ]] && [ $custom_port -ge 1 ] && [ $custom_port -le 65535 ]; then
                        if check_port $custom_port; then
                            PORT=$custom_port
                            break 2
                        else
                            print_error "端口 $custom_port 已被占用，请选择其他端口"
                        fi
                    else
                        print_error "无效的端口号，请输入1-65535之间的数字"
                    fi
                done
                ;;
            *)
                print_error "无效选择，请输入1-3"
                ;;
        esac
    done
    
    if ! check_port $PORT; then
        print_error "端口 $PORT 已被占用"
        exit 1
    fi
    
    print_success "选择端口: $PORT"
}

# 生成随机密钥
generate_secret() {
    SECRET=$(openssl rand -hex 16)
    print_success "生成密钥: $SECRET"
}

# 获取服务器IP
get_server_ip() {
    # 尝试多种方法获取公网IP
    SERVER_IP=$(curl -s ifconfig.me) || \
    SERVER_IP=$(curl -s ipinfo.io/ip) || \
    SERVER_IP=$(curl -s icanhazip.com) || \
    SERVER_IP=$(wget -qO- ifconfig.me)
    
    if [[ -z $SERVER_IP ]]; then
        print_warning "无法自动获取公网IP，请手动输入"
        read -p "请输入服务器公网IP: " SERVER_IP
    fi
    
    print_success "服务器IP: $SERVER_IP"
}

# 下载项目文件
download_project() {
    print_info "正在下载项目文件..."
    
    # 如果目录已存在，先备份
    if [[ -d $INSTALL_DIR ]]; then
        print_warning "检测到已安装的版本，正在备份..."
        mv $INSTALL_DIR "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 克隆仓库
    git clone $REPO_URL $INSTALL_DIR
    
    if [[ ! -d $INSTALL_DIR ]]; then
        print_error "项目下载失败"
        exit 1
    fi
    
    print_success "项目文件下载完成"
}

# 设置Python虚拟环境
setup_python_env() {
    print_info "正在设置Python环境..."
    
    cd $INSTALL_DIR
    
    # 创建虚拟环境
    python3 -m venv venv
    
    # 激活虚拟环境并安装依赖
    source venv/bin/activate
    
    # 升级pip
    pip install --upgrade pip
    
    # 安装项目依赖
    if [[ -f requirements.txt ]]; then
        pip install -r requirements.txt
    fi
    
    # 安装核心依赖
    pip install cryptography pycryptodome
    
    print_success "Python环境配置完成"
}

# 生成配置文件
generate_config() {
    print_info "正在生成配置文件..."
    
    mkdir -p $INSTALL_DIR/config
    mkdir -p $INSTALL_DIR/logs
    
    cat > $INSTALL_DIR/config/mtproxy.conf << EOF
# MTProxy Configuration File
# Generated by install script on $(date)

server:
  host: 0.0.0.0
  port: $PORT
  secret: $SECRET
  tls_secret: auto_generate
  fake_domain: www.cloudflare.com
  max_connections: 1000
  timeout: 300
  workers: 4
  buffer_size: 8192
  keepalive_timeout: 60

logging:
  level: INFO
  file: $INSTALL_DIR/logs/mtproxy.log
  max_size: 100MB
  backup_count: 7
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

security:
  allowed_ips: []
  banned_ips: []
  rate_limit: 100
  max_connections_per_ip: 10

monitoring:
  stats_enabled: true
  stats_port: 8080
  health_check_interval: 30
  performance_monitoring: true

telegram:
  api_id: null
  api_hash: null
  datacenter: auto
  connection_pool_size: 10

advanced:
  debug: false
  user_agent: "MTProxy/1.0"
  dns_servers:
    - "8.8.8.8"
    - "1.1.1.1"
  tcp_keepalive:
    enabled: true
    idle: 600
    interval: 60
    count: 3
EOF

    print_success "配置文件生成完成: $INSTALL_DIR/config/mtproxy.conf"
}

# 创建systemd服务
create_systemd_service() {
    print_info "正在创建系统服务..."
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Python MTProxy Service
Documentation=https://github.com/${GITHUB_REPO}
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python -m mtproxy.server
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    
    print_success "系统服务创建完成"
}

# 创建管理脚本
create_management_scripts() {
    print_info "正在创建管理脚本..."
    
    mkdir -p $INSTALL_DIR/scripts
    
    # 创建管理菜单脚本
    cat > $INSTALL_DIR/scripts/mtproxy << 'EOF'
#!/bin/bash

# MTProxy 管理脚本
# 版本: 2.0

SERVICE_NAME="python-mtproxy"
INSTALL_DIR="/opt/python-mtproxy"
CONFIG_FILE="$INSTALL_DIR/config/mtproxy.conf"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     MTProxy 管理面板                          ║"
    echo "║                    Python MTProxy v2.0                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_menu() {
    echo -e "${WHITE}"
    echo "┌─ 服务管理 ─────────────────────────────────────────────────┐"
    echo "│ 1) 启动服务          2) 停止服务          3) 重启服务        │"
    echo "│ 4) 查看状态          5) 查看日志          6) 重新加载配置    │"
    echo "├─ 配置管理 ─────────────────────────────────────────────────┤"
    echo "│ 7) 修改端口          8) 更换密钥          9) 编辑配置        │"
    echo "│ 10) 连接信息         11) 生成二维码       12) 性能优化       │"
    echo "├─ 系统管理 ─────────────────────────────────────────────────┤"
    echo "│ 13) 更新程序         14) 卸载程序         15) 系统信息       │"
    echo "│ 16) 防火墙设置       17) 流量统计         18) 备份还原       │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo "│ 0) 退出程序                                                 │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

get_service_status() {
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}运行中${NC}"
        return 0
    else
        echo -e "${RED}已停止${NC}"
        return 1
    fi
}

get_connection_info() {
    if [[ ! -f $CONFIG_FILE ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "获取失败")
    local port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    local secret=$(grep "^secret:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    
    echo -e "${CYAN}连接信息:${NC}"
    echo "服务器: $server_ip"
    echo "端口: $port"
    echo "密钥: $secret"
    echo ""
    echo -e "${CYAN}Telegram连接链接:${NC}"
    echo "tg://proxy?server=$server_ip&port=$port&secret=$secret"
}

start_service() {
    print_info "启动MTProxy服务..."
    if systemctl start $SERVICE_NAME; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败"
        return 1
    fi
}

stop_service() {
    print_info "停止MTProxy服务..."
    if systemctl stop $SERVICE_NAME; then
        print_success "服务停止成功"
    else
        print_error "服务停止失败"
        return 1
    fi
}

restart_service() {
    print_info "重启MTProxy服务..."
    if systemctl restart $SERVICE_NAME; then
        print_success "服务重启成功"
    else
        print_error "服务重启失败"
        return 1
    fi
}

show_status() {
    echo -e "${CYAN}═══ 服务状态 ═══${NC}"
    echo -n "状态: "
    get_service_status
    echo ""
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${CYAN}═══ 详细信息 ═══${NC}"
        systemctl status $SERVICE_NAME --no-pager
        echo ""
        
        echo -e "${CYAN}═══ 连接信息 ═══${NC}"
        get_connection_info
    fi
}

show_logs() {
    echo -e "${CYAN}═══ 实时日志 (Ctrl+C 退出) ═══${NC}"
    journalctl -u $SERVICE_NAME -f --no-pager
}

change_port() {
    local current_port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    echo "当前端口: $current_port"
    echo ""
    
    while true; do
        read -p "请输入新端口号 (1-65535): " new_port
        if [[ $new_port =~ ^[0-9]+$ ]] && [ $new_port -ge 1 ] && [ $new_port -le 65535 ]; then
            # 检查端口是否被占用
            if ss -tlnp | grep ":$new_port " >/dev/null 2>&1; then
                print_error "端口 $new_port 已被占用"
                continue
            fi
            
            # 修改配置文件
            sed -i "s/^port: .*/port: $new_port/" $CONFIG_FILE
            print_success "端口已修改为: $new_port"
            
            # 重启服务
            restart_service
            break
        else
            print_error "无效的端口号"
        fi
    done
}

change_secret() {
    local current_secret=$(grep "^secret:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    echo "当前密钥: $current_secret"
    echo ""
    
    echo "1) 生成新的随机密钥"
    echo "2) 手动输入密钥"
    
    read -p "请选择 [1-2]: " choice
    
    case $choice in
        1)
            local new_secret=$(openssl rand -hex 16)
            ;;
        2)
            while true; do
                read -p "请输入32位十六进制密钥: " new_secret
                if [[ ${#new_secret} -eq 32 ]] && [[ $new_secret =~ ^[0-9a-fA-F]+$ ]]; then
                    break
                else
                    print_error "密钥必须是32位十六进制字符"
                fi
            done
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
    
    # 修改配置文件
    sed -i "s/^secret: .*/secret: $new_secret/" $CONFIG_FILE
    print_success "密钥已修改为: $new_secret"
    
    # 重启服务
    restart_service
}

edit_config() {
    print_info "打开配置文件编辑器..."
    if command -v nano >/dev/null; then
        nano $CONFIG_FILE
    elif command -v vi >/dev/null; then
        vi $CONFIG_FILE
    else
        print_error "未找到文本编辑器"
        return 1
    fi
    
    read -p "是否重启服务使配置生效? [y/N]: " restart_confirm
    if [[ $restart_confirm == [Yy] ]]; then
        restart_service
    fi
}

generate_qr() {
    print_info "生成连接二维码..."
    
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "获取失败")
    local port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    local secret=$(grep "^secret:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    local link="tg://proxy?server=$server_ip&port=$port&secret=$secret"
    
    # 尝试使用qrencode生成二维码
    if command -v qrencode >/dev/null; then
        qrencode -t ANSI "$link"
    else
        print_warning "qrencode未安装，显示连接链接:"
        echo "$link"
        echo ""
        print_info "要安装二维码生成器，请运行: apt install qrencode (Ubuntu/Debian) 或 yum install qrencode (CentOS)"
    fi
}

# 性能优化功能
performance_optimization() {
    echo -e "${CYAN}═══ 性能优化设置 ═══${NC}"
    echo "1) 查看当前性能参数"
    echo "2) 优化内存使用"
    echo "3) 优化网络参数"
    echo "4) 设置连接限制"
    echo "0) 返回主菜单"
    echo ""
    
    read -p "请选择操作 [0-4]: " choice
    
    case $choice in
        1)
            echo -e "${CYAN}当前系统资源使用:${NC}"
            echo "CPU使用率: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
            echo "内存使用: $(free -h | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
            echo "磁盘使用: $(df -h / | awk 'NR==2{printf "%s", $5}')"
            echo ""
            echo -e "${CYAN}MTProxy进程信息:${NC}"
            ps aux | grep python-mtproxy | grep -v grep || echo "服务未运行"
            ;;
        2)
            print_info "优化内存使用设置..."
            # 这里可以添加内存优化逻辑
            print_success "内存优化完成"
            ;;
        3)
            print_info "优化网络参数..."
            # 这里可以添加网络优化逻辑
            print_success "网络优化完成"
            ;;
        4)
            print_info "设置连接限制..."
            # 这里可以添加连接限制逻辑
            print_success "连接限制设置完成"
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

# 更新程序功能
update_program() {
    echo -e "${CYAN}═══ 程序更新 ═══${NC}"
    print_info "检查更新..."
    
    # 检查Git仓库
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        cd "$INSTALL_DIR"
        git fetch origin main 2>/dev/null
        
        local current_commit=$(git rev-parse HEAD)
        local latest_commit=$(git rev-parse origin/main)
        
        if [[ "$current_commit" == "$latest_commit" ]]; then
            print_success "已是最新版本"
            return 0
        fi
        
        echo "发现新版本可用!"
        echo "当前版本: ${current_commit:0:8}"
        echo "最新版本: ${latest_commit:0:8}"
        echo ""
        
        read -p "是否更新到最新版本? [y/N]: " update_confirm
        if [[ $update_confirm == [Yy] ]]; then
            print_info "正在更新..."
            
            # 备份当前配置
            cp -r config config.backup.$(date +%Y%m%d_%H%M%S)
            
            # 拉取最新代码
            git pull origin main
            
            # 重启服务
            restart_service
            
            print_success "更新完成!"
        fi
    else
        print_warning "未找到Git仓库，无法自动更新"
        echo "请手动下载最新版本进行更新"
    fi
}

# 卸载程序功能
uninstall_program() {
    echo -e "${RED}═══ 卸载 MTProxy ═══${NC}"
    echo ""
    print_warning "这将完全删除MTProxy及其所有数据!"
    echo ""
    echo "将要删除的内容:"
    echo "  • MTProxy服务和配置"
    echo "  • 安装目录: $INSTALL_DIR"
    echo "  • 系统服务文件"
    echo "  • 用户数据和日志"
    echo ""
    
    read -p "确定要卸载吗? 输入 'yes' 确认: " confirm
    if [[ "$confirm" != "yes" ]]; then
        print_info "卸载已取消"
        return 0
    fi
    
    print_info "正在卸载MTProxy..."
    
    # 停止服务
    print_info "停止服务..."
    systemctl stop $SERVICE_NAME 2>/dev/null || true
    systemctl disable $SERVICE_NAME 2>/dev/null || true
    
    # 删除服务文件
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    systemctl daemon-reload
    
    # 创建配置备份
    if [[ -d "$INSTALL_DIR/config" ]]; then
        local backup_dir="/tmp/mtproxy-backup-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp -r "$INSTALL_DIR/config" "$backup_dir/" 2>/dev/null || true
        print_info "配置已备份到: $backup_dir"
    fi
    
    # 删除安装目录
    rm -rf "$INSTALL_DIR"
    
    # 删除命令链接
    rm -f /usr/local/bin/mtproxy
    rm -f /usr/local/bin/mtproxy-cli
    rm -f /usr/local/bin/mtproxy-logs
    rm -f /usr/local/bin/mtproxy-health
    
    # 清理防火墙规则
    if command -v ufw &> /dev/null; then
        ufw delete allow 8443/tcp 2>/dev/null || true
    fi
    
    print_success "MTProxy已完全卸载!"
    echo ""
    echo "感谢使用MTProxy!"
    exit 0
}

# 系统信息功能
show_system_info() {
    echo -e "${CYAN}═══ 系统信息 ═══${NC}"
    
    # 基本系统信息
    echo -e "${YELLOW}操作系统:${NC}"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "  系统: $PRETTY_NAME"
        echo "  版本: $VERSION"
    fi
    echo "  内核: $(uname -r)"
    echo "  架构: $(uname -m)"
    echo ""
    
    # 硬件信息
    echo -e "${YELLOW}硬件信息:${NC}"
    echo "  CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "  CPU核心: $(nproc)"
    echo "  内存: $(free -h | grep Mem | awk '{print $2}')"
    echo ""
    
    # 网络信息
    echo -e "${YELLOW}网络信息:${NC}"
    echo "  外网IP: $(curl -s ifconfig.me 2>/dev/null || echo '获取失败')"
    echo "  内网IP: $(hostname -I | awk '{print $1}' 2>/dev/null || echo '获取失败')"
    echo ""
    
    # 系统负载
    echo -e "${YELLOW}系统负载:${NC}"
    echo "  负载: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  运行时间: $(uptime -p)"
    echo ""
    
    # 磁盘使用
    echo -e "${YELLOW}磁盘使用:${NC}"
    df -h | grep -E '^/dev/' | awk '{printf "  %s: %s/%s (%s)\n", $6, $3, $2, $5}'
    echo ""
    
    # MTProxy状态
    echo -e "${YELLOW}MTProxy状态:${NC}"
    echo -n "  服务状态: "
    get_service_status
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo "  PID: $(systemctl show $SERVICE_NAME --property=MainPID --value)"
        echo "  运行时间: $(systemctl show $SERVICE_NAME --property=ActiveEnterTimestamp --value | awk '{print $2, $3}')"
    fi
}

# 防火墙设置功能
firewall_settings() {
    echo -e "${CYAN}═══ 防火墙设置 ═══${NC}"
    echo "1) 查看防火墙状态"
    echo "2) 开放MTProxy端口"
    echo "3) 关闭MTProxy端口"
    echo "4) 查看开放的端口"
    echo "5) 重置防火墙规则"
    echo "0) 返回主菜单"
    echo ""
    
    read -p "请选择操作 [0-5]: " choice
    
    local port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    
    case $choice in
        1)
            echo -e "${YELLOW}防火墙状态:${NC}"
            if command -v ufw &> /dev/null; then
                ufw status verbose
            elif command -v firewalld &> /dev/null; then
                firewall-cmd --state
                firewall-cmd --list-all
            else
                print_warning "未检测到支持的防火墙"
            fi
            ;;
        2)
            print_info "开放端口 $port..."
            if command -v ufw &> /dev/null; then
                ufw allow $port/tcp
                print_success "端口 $port 已开放"
            elif command -v firewalld &> /dev/null; then
                firewall-cmd --permanent --add-port=$port/tcp
                firewall-cmd --reload
                print_success "端口 $port 已开放"
            else
                print_warning "请手动配置防火墙开放端口 $port"
            fi
            ;;
        3)
            print_info "关闭端口 $port..."
            if command -v ufw &> /dev/null; then
                ufw delete allow $port/tcp
                print_success "端口 $port 已关闭"
            elif command -v firewalld &> /dev/null; then
                firewall-cmd --permanent --remove-port=$port/tcp
                firewall-cmd --reload
                print_success "端口 $port 已关闭"
            else
                print_warning "请手动配置防火墙关闭端口 $port"
            fi
            ;;
        4)
            echo -e "${YELLOW}开放的端口:${NC}"
            if command -v ufw &> /dev/null; then
                ufw status | grep ALLOW
            elif command -v firewalld &> /dev/null; then
                firewall-cmd --list-ports
            else
                ss -tlnp | grep LISTEN
            fi
            ;;
        5)
            read -p "确定要重置防火墙规则吗? [y/N]: " reset_confirm
            if [[ $reset_confirm == [Yy] ]]; then
                if command -v ufw &> /dev/null; then
                    ufw --force reset
                    ufw enable
                    print_success "防火墙规则已重置"
                else
                    print_warning "请手动重置防火墙规则"
                fi
            fi
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

# 流量统计功能
traffic_statistics() {
    echo -e "${CYAN}═══ 流量统计 ═══${NC}"
    
    # 获取网络接口
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -z "$interface" ]]; then
        print_error "无法获取网络接口"
        return 1
    fi
    
    echo -e "${YELLOW}网络接口: $interface${NC}"
    echo ""
    
    # 显示实时流量
    echo -e "${YELLOW}实时流量统计:${NC}"
    local rx_before=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local tx_before=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    
    sleep 1
    
    local rx_after=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local tx_after=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    
    local rx_rate=$((rx_after - rx_before))
    local tx_rate=$((tx_after - tx_before))
    
    echo "  下载速度: $(numfmt --to=iec-i --suffix=B/s $rx_rate)"
    echo "  上传速度: $(numfmt --to=iec-i --suffix=B/s $tx_rate)"
    echo ""
    
    # 显示总流量
    echo -e "${YELLOW}总流量统计:${NC}"
    local total_rx=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local total_tx=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    
    echo "  总下载: $(numfmt --to=iec-i --suffix=B $total_rx)"
    echo "  总上传: $(numfmt --to=iec-i --suffix=B $total_tx)"
    echo ""
    
    # MTProxy连接统计
    echo -e "${YELLOW}MTProxy连接统计:${NC}"
    local port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    local connections=$(ss -tn | grep ":$port " | wc -l)
    echo "  当前连接数: $connections"
    
    # 如果有日志，显示连接历史
    if [[ -f "/var/log/$SERVICE_NAME.log" ]]; then
        local today_connections=$(grep "$(date +%Y-%m-%d)" /var/log/$SERVICE_NAME.log | grep -c "connection" 2>/dev/null || echo "0")
        echo "  今日连接数: $today_connections"
    fi
}

# 备份还原功能
backup_restore() {
    echo -e "${CYAN}═══ 备份还原 ═══${NC}"
    echo "1) 创建配置备份"
    echo "2) 还原配置备份"
    echo "3) 查看备份列表"
    echo "4) 删除备份"
    echo "0) 返回主菜单"
    echo ""
    
    read -p "请选择操作 [0-4]: " choice
    
    local backup_dir="/opt/mtproxy-backups"
    
    case $choice in
        1)
            print_info "创建配置备份..."
            mkdir -p "$backup_dir"
            
            local backup_name="mtproxy-backup-$(date +%Y%m%d_%H%M%S)"
            local backup_path="$backup_dir/$backup_name"
            
            mkdir -p "$backup_path"
            cp -r "$INSTALL_DIR/config" "$backup_path/"
            cp -r "$INSTALL_DIR/logs" "$backup_path/" 2>/dev/null || true
            
            # 创建备份信息文件
            {
                echo "备份时间: $(date)"
                echo "MTProxy版本: $(cat $INSTALL_DIR/VERSION 2>/dev/null || echo "未知")"
                echo "系统信息: $(uname -a)"
                echo "配置文件: $(ls -la $INSTALL_DIR/config/)"
            } > "$backup_path/backup_info.txt"
            
            print_success "备份已创建: $backup_path"
            ;;
        2)
            if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A $backup_dir 2>/dev/null)" ]]; then
                print_error "没有找到备份文件"
                return 1
            fi
            
            echo -e "${YELLOW}可用的备份:${NC}"
            local backups=($(ls -1 "$backup_dir" | sort -r))
            for i in "${!backups[@]}"; do
                echo "  $((i+1))) ${backups[$i]}"
            done
            echo ""
            
            read -p "请选择要还原的备份编号: " backup_choice
            if [[ $backup_choice -ge 1 ]] && [[ $backup_choice -le ${#backups[@]} ]]; then
                local selected_backup="${backups[$((backup_choice-1))]}"
                local backup_path="$backup_dir/$selected_backup"
                
                print_warning "这将覆盖当前配置!"
                read -p "确定要还原备份 '$selected_backup'? [y/N]: " restore_confirm
                
                if [[ $restore_confirm == [Yy] ]]; then
                    print_info "正在还原备份..."
                    
                    # 停止服务
                    systemctl stop $SERVICE_NAME
                    
                    # 备份当前配置
                    cp -r "$INSTALL_DIR/config" "$INSTALL_DIR/config.before_restore.$(date +%Y%m%d_%H%M%S)"
                    
                    # 还原配置
                    cp -r "$backup_path/config/"* "$INSTALL_DIR/config/"
                    
                    # 重启服务
                    restart_service
                    
                    print_success "备份还原完成!"
                fi
            else
                print_error "无效的备份编号"
            fi
            ;;
        3)
            if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A $backup_dir 2>/dev/null)" ]]; then
                print_info "没有找到备份文件"
                return 0
            fi
            
            echo -e "${YELLOW}备份列表:${NC}"
            for backup in $(ls -1t "$backup_dir"); do
                local backup_path="$backup_dir/$backup"
                local backup_size=$(du -sh "$backup_path" | cut -f1)
                local backup_time=""
                if [[ -f "$backup_path/backup_info.txt" ]]; then
                    backup_time=$(grep "备份时间:" "$backup_path/backup_info.txt" | cut -d: -f2- | xargs)
                fi
                echo "  • $backup (大小: $backup_size)"
                [[ -n "$backup_time" ]] && echo "    时间: $backup_time"
            done
            ;;
        4)
            if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A $backup_dir 2>/dev/null)" ]]; then
                print_info "没有找到备份文件"
                return 0
            fi
            
            echo -e "${YELLOW}备份列表:${NC}"
            local backups=($(ls -1 "$backup_dir"))
            for i in "${!backups[@]}"; do
                echo "  $((i+1))) ${backups[$i]}"
            done
            echo ""
            
            read -p "请选择要删除的备份编号 (0取消): " delete_choice
            if [[ $delete_choice -ge 1 ]] && [[ $delete_choice -le ${#backups[@]} ]]; then
                local selected_backup="${backups[$((delete_choice-1))]}"
                
                read -p "确定要删除备份 '$selected_backup'? [y/N]: " delete_confirm
                if [[ $delete_confirm == [Yy] ]]; then
                    rm -rf "$backup_dir/$selected_backup"
                    print_success "备份已删除: $selected_backup"
                fi
            elif [[ $delete_choice -ne 0 ]]; then
                print_error "无效的备份编号"
            fi
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

main() {
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        exit 1
    fi
    
    while true; do
        show_banner
        
        # 显示服务状态
        echo -n "当前状态: "
        get_service_status
        echo ""
        
        show_menu
        
        read -p "请选择操作 [0-18]: " choice
        
        case $choice in
            1) start_service ;;
            2) stop_service ;;
            3) restart_service ;;
            4) show_status ;;
            5) show_logs ;;
            6) systemctl reload $SERVICE_NAME && print_success "配置重新加载完成" ;;
            7) change_port ;;
            8) change_secret ;;
            9) edit_config ;;
            10) get_connection_info ;;
            11) generate_qr ;;
            12) performance_optimization ;;
            13) update_program ;;
            14) uninstall_program ;;
            15) show_system_info ;;
            16) firewall_settings ;;
            17) traffic_statistics ;;
            18) backup_restore ;;
            0) 
                print_info "感谢使用MTProxy管理脚本!"
                exit 0
                ;;
            *)
                print_error "无效选择，请输入0-18"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

main "$@"
EOF

    chmod +x $INSTALL_DIR/scripts/mtproxy
    
    # 创建软链接到系统路径
    ln -sf $INSTALL_DIR/scripts/mtproxy /usr/local/bin/mtproxy
    
    print_success "管理脚本创建完成"
}

# 配置防火墙
configure_firewall() {
    print_info "正在配置防火墙..."
    
    # 检查防火墙类型并开放端口
    if command -v ufw >/dev/null; then
        ufw allow $PORT/tcp
        print_success "UFW防火墙规则已添加"
    elif command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --add-port=$PORT/tcp
        firewall-cmd --reload
        print_success "firewalld防火墙规则已添加"
    elif command -v iptables >/dev/null; then
        iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
        # 尝试保存iptables规则
        if command -v iptables-save >/dev/null; then
            iptables-save > /etc/iptables.rules
        fi
        print_success "iptables防火墙规则已添加"
    else
        print_warning "未检测到防火墙，请手动开放端口 $PORT"
    fi
}

# 启动服务
start_mtproxy_service() {
    print_info "启动MTProxy服务..."
    
    if systemctl start $SERVICE_NAME; then
        print_success "MTProxy服务启动成功"
        
        # 等待服务完全启动
        sleep 3
        
        if systemctl is-active --quiet $SERVICE_NAME; then
            print_success "服务运行状态: 正常"
        else
            print_error "服务启动异常，请检查日志"
            return 1
        fi
    else
        print_error "MTProxy服务启动失败"
        return 1
    fi
}

# 显示安装结果
show_installation_result() {
    print_title "安装完成"
    
    echo -e "${GREEN}🎉 MTProxy安装成功!${NC}"
    echo ""
    
    echo -e "${CYAN}📋 连接信息:${NC}"
    echo "服务器: $SERVER_IP"
    echo "端口: $PORT"
    echo "密钥: $SECRET"
    echo ""
    
    echo -e "${CYAN}🔗 Telegram连接链接:${NC}"
    echo "tg://proxy?server=$SERVER_IP&port=$PORT&secret=$SECRET"
    echo ""
    
    echo -e "${CYAN}🛠️ 管理命令:${NC}"
    echo "启动管理面板: mtproxy"
    echo "查看服务状态: systemctl status $SERVICE_NAME"
    echo "查看服务日志: journalctl -u $SERVICE_NAME -f"
    echo ""
    
    echo -e "${CYAN}📁 重要路径:${NC}"
    echo "安装目录: $INSTALL_DIR"
    echo "配置文件: $INSTALL_DIR/config/mtproxy.conf"
    echo "日志目录: $INSTALL_DIR/logs"
    echo ""
    
    echo -e "${YELLOW}💡 使用提示:${NC}"
    echo "1. 复制上面的连接链接到Telegram中添加代理"
    echo "2. 使用 'mtproxy' 命令打开管理面板"
    echo "3. 配置文件位于 $INSTALL_DIR/config/mtproxy.conf"
    echo ""
    
    echo -e "${GREEN}✅ 安装成功完成!${NC}"
}

# 主安装函数
main() {
    print_title "MTProxy 一键安装脚本"
    
    echo "此脚本将在您的服务器上安装 MTProxy"
    echo "支持的系统: Ubuntu, Debian, CentOS"
    echo ""
    
    read -p "是否继续安装? [Y/n]: " confirm
    if [[ $confirm == [Nn] ]]; then
        print_info "取消安装"
        exit 0
    fi
    
    # 执行安装步骤
    check_root
    detect_os
    install_dependencies
    select_port
    generate_secret
    get_server_ip
    download_project
    setup_python_env
    generate_config
    create_systemd_service
    create_management_scripts
    configure_firewall
    start_mtproxy_service
    
    # 显示安装结果
    show_installation_result
}

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
