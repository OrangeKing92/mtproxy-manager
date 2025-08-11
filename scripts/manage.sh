#!/bin/bash

# MTProxy 本地管理脚本
# 用于管理已安装的MTProxy服务

set -e

# 配置
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

# 输出函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        echo "请使用: sudo bash manage.sh"
        exit 1
    fi
}

# 检查服务是否安装
check_installation() {
    if [[ ! -d $INSTALL_DIR ]]; then
        print_error "MTProxy未安装，请先运行安装脚本"
        exit 1
    fi
    
    if ! systemctl list-unit-files | grep -q $SERVICE_NAME; then
        print_error "MTProxy服务未注册"
        exit 1
    fi
}

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                     MTProxy 管理控制台                        ║
║                    Python MTProxy v2.0                       ║
║                  https://t.me/mtproxy_bot                     ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 获取服务状态
get_service_status() {
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}●${NC} 运行中"
        return 0
    elif systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "${RED}●${NC} 已停止"
        return 1
    else
        echo -e "${YELLOW}●${NC} 已禁用"
        return 2
    fi
}

# 获取服务信息
get_service_info() {
    local pid=$(systemctl show -p MainPID --value $SERVICE_NAME)
    local uptime=""
    local memory=""
    local cpu=""
    
    if [[ $pid != "0" ]]; then
        uptime=$(ps -o etime= -p $pid 2>/dev/null | tr -d ' ' || echo "未知")
        memory=$(ps -o rss= -p $pid 2>/dev/null | awk '{printf "%.1fM", $1/1024}' || echo "未知")
        cpu=$(ps -o %cpu= -p $pid 2>/dev/null | tr -d ' ' || echo "未知")
    fi
    
    echo "PID: ${pid:-未知}"
    echo "运行时间: ${uptime:-未知}"
    echo "内存使用: ${memory:-未知}"
    echo "CPU使用: ${cpu:-未知}%"
}

# 获取连接信息
get_connection_info() {
    if [[ ! -f $CONFIG_FILE ]]; then
        print_error "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    local server_ip=$(curl -s -m 5 ifconfig.me 2>/dev/null || curl -s -m 5 ipinfo.io/ip 2>/dev/null || echo "获取失败")
    local port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    local secret=$(grep "^secret:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    
    if [[ -z $port || -z $secret ]]; then
        print_error "无法读取配置信息"
        return 1
    fi
    
    echo -e "${CYAN}服务器信息:${NC}"
    echo "IP地址: $server_ip"
    echo "端口: $port"
    echo "密钥: $secret"
    echo ""
    echo -e "${CYAN}连接链接:${NC}"
    local link="tg://proxy?server=$server_ip&port=$port&secret=$secret"
    echo "$link"
    
    # 生成短链接格式（可选）
    echo ""
    echo -e "${CYAN}手动设置参数:${NC}"
    echo "服务器: $server_ip"
    echo "端口: $port"
    echo "密钥: $secret"
    
    return 0
}

# 显示主菜单
show_main_menu() {
    echo -e "${WHITE}"
    echo "┌─ 当前状态 ─────────────────────────────────────────────────┐"
    echo -n "│ 服务状态: "
    get_service_status
    echo "│"
    get_service_info | sed 's/^/│ /'
    echo "├─ 服务管理 ─────────────────────────────────────────────────┤"
    echo "│ 1) 启动服务    2) 停止服务    3) 重启服务    4) 查看状态    │"
    echo "│ 5) 查看日志    6) 重载配置    7) 开机自启    8) 禁用自启    │"
    echo "├─ 配置管理 ─────────────────────────────────────────────────┤"
    echo "│ 9) 连接信息    10) 修改端口   11) 更换密钥   12) 编辑配置   │"
    echo "│ 13) 生成二维码 14) 性能调优   15) 安全设置   16) 备份配置   │"
    echo "├─ 高级功能 ─────────────────────────────────────────────────┤"
    echo "│ 17) 流量统计   18) 用户管理   19) 更新程序   20) 卸载程序   │"
    echo "│ 21) 系统信息   22) 网络诊断   23) 日志分析   24) 帮助文档   │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo "│ 0) 退出程序                                                 │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

# 服务管理函数
start_service() {
    print_info "正在启动MTProxy服务..."
    if systemctl start $SERVICE_NAME; then
        sleep 2
        if systemctl is-active --quiet $SERVICE_NAME; then
            print_success "服务启动成功"
        else
            print_error "服务启动失败，请检查日志"
            return 1
        fi
    else
        print_error "服务启动失败"
        return 1
    fi
}

stop_service() {
    print_info "正在停止MTProxy服务..."
    if systemctl stop $SERVICE_NAME; then
        print_success "服务停止成功"
    else
        print_error "服务停止失败"
        return 1
    fi
}

restart_service() {
    print_info "正在重启MTProxy服务..."
    if systemctl restart $SERVICE_NAME; then
        sleep 2
        if systemctl is-active --quiet $SERVICE_NAME; then
            print_success "服务重启成功"
        else
            print_error "服务重启失败，请检查日志"
            return 1
        fi
    else
        print_error "服务重启失败"
        return 1
    fi
}

show_detailed_status() {
    echo -e "${CYAN}═══ 服务详细状态 ═══${NC}"
    systemctl status $SERVICE_NAME --no-pager -l
    
    echo ""
    echo -e "${CYAN}═══ 端口监听状态 ═══${NC}"
    local port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    if ss -tlnp | grep ":$port "; then
        print_success "端口 $port 正在监听"
    else
        print_warning "端口 $port 未在监听"
    fi
    
    echo ""
    echo -e "${CYAN}═══ 连接信息 ═══${NC}"
    get_connection_info
}

show_logs() {
    echo -e "${CYAN}═══ 服务日志 (最近50行) ═══${NC}"
    echo "提示: 按 Ctrl+C 退出日志查看"
    echo ""
    
    echo "1) 查看最近日志"
    echo "2) 实时日志跟踪"
    echo "3) 错误日志"
    echo "4) 返回主菜单"
    
    read -p "请选择 [1-4]: " log_choice
    
    case $log_choice in
        1)
            journalctl -u $SERVICE_NAME --no-pager -n 50
            ;;
        2)
            print_info "实时日志跟踪 (Ctrl+C 退出)"
            journalctl -u $SERVICE_NAME -f --no-pager
            ;;
        3)
            journalctl -u $SERVICE_NAME --no-pager -p err
            ;;
        4)
            return
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

reload_config() {
    print_info "重新加载配置..."
    if systemctl reload $SERVICE_NAME 2>/dev/null; then
        print_success "配置重新加载成功"
    else
        print_warning "重载失败，尝试重启服务..."
        restart_service
    fi
}

enable_autostart() {
    print_info "启用开机自启..."
    if systemctl enable $SERVICE_NAME; then
        print_success "开机自启已启用"
    else
        print_error "启用失败"
        return 1
    fi
}

disable_autostart() {
    print_info "禁用开机自启..."
    if systemctl disable $SERVICE_NAME; then
        print_success "开机自启已禁用"
    else
        print_error "禁用失败"
        return 1
    fi
}

change_port() {
    local current_port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    echo -e "${CYAN}当前端口: $current_port${NC}"
    echo ""
    
    echo "推荐端口:"
    echo "443  - HTTPS端口，不易被封"
    echo "8443 - 常用代理端口"
    echo "1080 - SOCKS代理端口"
    echo ""
    
    while true; do
        read -p "请输入新端口号 (1-65535): " new_port
        
        # 验证端口号
        if ! [[ $new_port =~ ^[0-9]+$ ]] || [ $new_port -lt 1 ] || [ $new_port -gt 65535 ]; then
            print_error "无效的端口号，请输入1-65535之间的数字"
            continue
        fi
        
        # 检查端口是否被占用
        if ss -tlnp | grep ":$new_port " >/dev/null 2>&1; then
            print_error "端口 $new_port 已被占用，请选择其他端口"
            continue
        fi
        
        # 确认修改
        read -p "确认将端口从 $current_port 修改为 $new_port? [y/N]: " confirm
        if [[ $confirm != [Yy] ]]; then
            print_info "取消修改"
            return
        fi
        
        # 备份配置文件
        cp $CONFIG_FILE "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        
        # 修改配置文件
        sed -i "s/^port: .*/port: $new_port/" $CONFIG_FILE
        print_success "端口已修改为: $new_port"
        
        # 重启服务
        if restart_service; then
            print_success "服务重启成功，新端口已生效"
            
            # 更新防火墙规则
            update_firewall_rules $current_port $new_port
        else
            print_error "服务重启失败，正在恢复原配置..."
            mv "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)" $CONFIG_FILE
            restart_service
        fi
        break
    done
}

change_secret() {
    local current_secret=$(grep "^secret:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    echo -e "${CYAN}当前密钥: $current_secret${NC}"
    echo ""
    
    echo "密钥生成方式:"
    echo "1) 自动生成随机密钥 (推荐)"
    echo "2) 手动输入密钥"
    echo "3) 返回主菜单"
    
    read -p "请选择 [1-3]: " choice
    
    case $choice in
        1)
            local new_secret=$(openssl rand -hex 16)
            print_info "生成的新密钥: $new_secret"
            ;;
        2)
            while true; do
                read -p "请输入32位十六进制密钥: " new_secret
                if [[ ${#new_secret} -eq 32 ]] && [[ $new_secret =~ ^[0-9a-fA-F]+$ ]]; then
                    break
                else
                    print_error "密钥必须是32位十六进制字符 (0-9, a-f, A-F)"
                fi
            done
            ;;
        3)
            return
            ;;
        *)
            print_error "无效选择"
            return
            ;;
    esac
    
    # 确认修改
    read -p "确认更换密钥? [y/N]: " confirm
    if [[ $confirm != [Yy] ]]; then
        print_info "取消修改"
        return
    fi
    
    # 备份配置文件
    cp $CONFIG_FILE "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 修改配置文件
    sed -i "s/^secret: .*/secret: $new_secret/" $CONFIG_FILE
    print_success "密钥已更新"
    
    # 重启服务
    if restart_service; then
        print_success "服务重启成功，新密钥已生效"
        echo ""
        print_info "请更新您的Telegram代理设置，使用新的连接信息"
    else
        print_error "服务重启失败，正在恢复原配置..."
        mv "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)" $CONFIG_FILE
        restart_service
    fi
}

edit_config() {
    print_info "打开配置文件编辑器..."
    echo "配置文件位置: $CONFIG_FILE"
    echo ""
    
    # 备份配置文件
    cp $CONFIG_FILE "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 选择编辑器
    if command -v nano >/dev/null; then
        nano $CONFIG_FILE
    elif command -v vim >/dev/null; then
        vim $CONFIG_FILE
    elif command -v vi >/dev/null; then
        vi $CONFIG_FILE
    else
        print_error "未找到可用的文本编辑器"
        return 1
    fi
    
    # 验证配置文件
    if validate_config; then
        read -p "配置文件已修改，是否重启服务使配置生效? [Y/n]: " restart_confirm
        if [[ $restart_confirm != [Nn] ]]; then
            restart_service
        fi
    else
        print_error "配置文件格式错误，正在恢复备份..."
        mv "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)" $CONFIG_FILE
        print_success "配置文件已恢复"
    fi
}

validate_config() {
    # 简单的配置文件验证
    if [[ ! -f $CONFIG_FILE ]]; then
        print_error "配置文件不存在"
        return 1
    fi
    
    local port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    local secret=$(grep "^secret:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    
    if [[ -z $port || ! $port =~ ^[0-9]+$ ]]; then
        print_error "配置文件中端口号无效"
        return 1
    fi
    
    if [[ -z $secret || ${#secret} -ne 32 || ! $secret =~ ^[0-9a-fA-F]+$ ]]; then
        print_error "配置文件中密钥无效"
        return 1
    fi
    
    print_success "配置文件验证通过"
    return 0
}

generate_qr_code() {
    print_info "正在生成连接二维码..."
    
    local server_ip=$(curl -s -m 5 ifconfig.me 2>/dev/null || echo "获取IP失败")
    local port=$(grep "^port:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    local secret=$(grep "^secret:" $CONFIG_FILE | cut -d: -f2 | tr -d ' ')
    
    if [[ $server_ip == "获取IP失败" ]]; then
        print_error "无法获取服务器公网IP"
        return 1
    fi
    
    local link="tg://proxy?server=$server_ip&port=$port&secret=$secret"
    
    echo -e "${CYAN}连接信息:${NC}"
    echo "服务器: $server_ip"
    echo "端口: $port"
    echo "密钥: $secret"
    echo ""
    echo -e "${CYAN}连接链接:${NC}"
    echo "$link"
    echo ""
    
    # 尝试生成二维码
    if command -v qrencode >/dev/null; then
        echo -e "${CYAN}二维码:${NC}"
        qrencode -t ANSI "$link"
        echo ""
        print_success "用手机扫描二维码即可添加代理"
    else
        print_warning "qrencode未安装，无法生成二维码"
        echo "安装命令: apt install qrencode (Ubuntu/Debian) 或 yum install qrencode (CentOS)"
    fi
}

update_firewall_rules() {
    local old_port=$1
    local new_port=$2
    
    print_info "更新防火墙规则..."
    
    # UFW防火墙
    if command -v ufw >/dev/null; then
        ufw delete allow $old_port/tcp 2>/dev/null || true
        ufw allow $new_port/tcp
        print_success "UFW规则已更新"
    # firewalld防火墙
    elif command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --remove-port=$old_port/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=$new_port/tcp
        firewall-cmd --reload
        print_success "firewalld规则已更新"
    # iptables防火墙
    elif command -v iptables >/dev/null; then
        iptables -D INPUT -p tcp --dport $old_port -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p tcp --dport $new_port -j ACCEPT
        print_success "iptables规则已更新"
    else
        print_warning "未检测到防火墙，请手动更新防火墙规则"
    fi
}

show_system_info() {
    echo -e "${CYAN}═══ 系统信息 ═══${NC}"
    echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
    echo "内核版本: $(uname -r)"
    echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')"
    echo "内存: $(free -h | grep Mem | awk '{print $2}')"
    echo "磁盘: $(df -h / | tail -1 | awk '{print $2}')"
    echo "负载: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    
    echo -e "${CYAN}═══ 网络信息 ═══${NC}"
    echo "公网IP: $(curl -s -m 5 ifconfig.me 2>/dev/null || echo '获取失败')"
    echo "本地IP: $(hostname -I | awk '{print $1}')"
    echo ""
    
    echo -e "${CYAN}═══ 服务信息 ═══${NC}"
    echo "安装目录: $INSTALL_DIR"
    echo "配置文件: $CONFIG_FILE"
    echo "服务状态: $(get_service_status)"
    get_service_info
}

# 主程序循环
main() {
    check_root
    check_installation
    
    while true; do
        show_banner
        show_main_menu
        
        read -p "请选择操作 [0-24]: " choice
        echo ""
        
        case $choice in
            1) start_service ;;
            2) stop_service ;;
            3) restart_service ;;
            4) show_detailed_status ;;
            5) show_logs ;;
            6) reload_config ;;
            7) enable_autostart ;;
            8) disable_autostart ;;
            9) get_connection_info ;;
            10) change_port ;;
            11) change_secret ;;
            12) edit_config ;;
            13) generate_qr_code ;;
            14) print_info "性能调优功能开发中..." ;;
            15) print_info "安全设置功能开发中..." ;;
            16) print_info "备份配置功能开发中..." ;;
            17) print_info "流量统计功能开发中..." ;;
            18) print_info "用户管理功能开发中..." ;;
            19) print_info "更新程序功能开发中..." ;;
            20) print_info "卸载程序功能开发中..." ;;
            21) show_system_info ;;
            22) print_info "网络诊断功能开发中..." ;;
            23) print_info "日志分析功能开发中..." ;;
            24) print_info "帮助文档功能开发中..." ;;
            0)
                print_info "感谢使用 MTProxy 管理脚本!"
                exit 0
                ;;
            *)
                print_error "无效选择，请输入 0-24"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..." -r
    done
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
