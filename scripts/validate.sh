#!/bin/bash

# MTProxy 配置验证脚本
# 用于验证配置文件和系统环境

set -e

# 配置
INSTALL_DIR="/opt/python-mtproxy"
CONFIG_FILE="$INSTALL_DIR/config/mtproxy.conf"
SERVICE_NAME="python-mtproxy"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 输出函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_title() { echo -e "${CYAN}=== $1 ===${NC}"; }

# 验证结果统计
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# 记录检查结果
record_result() {
    local status=$1
    local message=$2
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case $status in
        "pass")
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            print_success "$message"
            ;;
        "fail")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            print_error "$message"
            ;;
        "warn")
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            print_warning "$message"
            ;;
    esac
}

# 检查文件和目录
check_files_and_directories() {
    print_title "文件和目录检查"
    
    # 检查安装目录
    if [[ -d "$INSTALL_DIR" ]]; then
        record_result "pass" "安装目录存在: $INSTALL_DIR"
    else
        record_result "fail" "安装目录不存在: $INSTALL_DIR"
        return 1
    fi
    
    # 检查配置目录
    if [[ -d "$INSTALL_DIR/config" ]]; then
        record_result "pass" "配置目录存在"
    else
        record_result "fail" "配置目录不存在"
    fi
    
    # 检查日志目录
    if [[ -d "$INSTALL_DIR/logs" ]]; then
        record_result "pass" "日志目录存在"
    else
        record_result "warn" "日志目录不存在，将自动创建"
        mkdir -p "$INSTALL_DIR/logs" 2>/dev/null || record_result "fail" "无法创建日志目录"
    fi
    
    # 检查配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        record_result "pass" "配置文件存在"
    else
        record_result "fail" "配置文件不存在: $CONFIG_FILE"
    fi
    
    # 检查Python虚拟环境
    if [[ -d "$INSTALL_DIR/venv" ]]; then
        record_result "pass" "Python虚拟环境存在"
    else
        record_result "fail" "Python虚拟环境不存在"
    fi
    
    # 检查Python可执行文件
    if [[ -f "$INSTALL_DIR/venv/bin/python" ]]; then
        record_result "pass" "Python解释器存在"
    else
        record_result "fail" "Python解释器不存在"
    fi
}

# 检查配置文件内容
check_config_content() {
    print_title "配置文件内容检查"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        record_result "fail" "配置文件不存在，跳过内容检查"
        return 1
    fi
    
    # 检查基本配置项
    local host=$(grep "^host:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
    local port=$(grep "^port:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
    local secret=$(grep "^secret:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
    
    # 验证host
    if [[ -n "$host" ]]; then
        record_result "pass" "主机地址配置: $host"
    else
        record_result "fail" "主机地址未配置"
    fi
    
    # 验证端口
    if [[ -n "$port" && "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
        record_result "pass" "端口配置有效: $port"
    else
        record_result "fail" "端口配置无效: $port"
    fi
    
    # 验证密钥
    if [[ -n "$secret" && ${#secret} -eq 32 && "$secret" =~ ^[0-9a-fA-F]+$ ]]; then
        record_result "pass" "密钥格式正确"
    else
        record_result "fail" "密钥格式错误 (需要32位十六进制)"
    fi
    
    # 检查其他配置项
    local max_connections=$(grep "^max_connections:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
    if [[ -n "$max_connections" && "$max_connections" =~ ^[0-9]+$ ]]; then
        record_result "pass" "最大连接数配置: $max_connections"
    else
        record_result "warn" "最大连接数配置无效或未设置"
    fi
    
    local workers=$(grep "^workers:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
    if [[ -n "$workers" && "$workers" =~ ^[0-9]+$ ]]; then
        record_result "pass" "工作进程数配置: $workers"
    else
        record_result "warn" "工作进程数配置无效或未设置"
    fi
    
    # 检查日志配置
    local log_level=$(grep "^log_level:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
    if [[ "$log_level" =~ ^(DEBUG|INFO|WARNING|ERROR|CRITICAL)$ ]]; then
        record_result "pass" "日志级别配置: $log_level"
    else
        record_result "warn" "日志级别配置无效: $log_level"
    fi
}

# 检查系统服务
check_system_service() {
    print_title "系统服务检查"
    
    # 检查服务文件是否存在
    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        record_result "pass" "服务文件存在"
    else
        record_result "fail" "服务文件不存在"
        return 1
    fi
    
    # 检查服务是否已注册
    if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        record_result "pass" "服务已注册到systemd"
    else
        record_result "fail" "服务未注册到systemd"
    fi
    
    # 检查服务是否启用
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        record_result "pass" "服务开机自启已启用"
    else
        record_result "warn" "服务开机自启未启用"
    fi
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        record_result "pass" "服务正在运行"
    else
        record_result "warn" "服务未运行"
    fi
    
    # 检查服务配置语法
    if systemctl --dry-run reload "$SERVICE_NAME" 2>/dev/null; then
        record_result "pass" "服务配置语法正确"
    else
        record_result "fail" "服务配置语法错误"
    fi
}

# 检查网络和端口
check_network_and_ports() {
    print_title "网络和端口检查"
    
    local port=$(grep "^port:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ' 2>/dev/null)
    
    if [[ -z "$port" ]]; then
        record_result "fail" "无法从配置文件获取端口号"
        return 1
    fi
    
    # 检查端口是否被占用
    if ss -tlnp | grep ":$port " >/dev/null 2>&1; then
        record_result "pass" "端口 $port 正在监听"
    else
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            record_result "fail" "服务运行中但端口 $port 未监听"
        else
            record_result "warn" "端口 $port 未监听 (服务未运行)"
        fi
    fi
    
    # 检查防火墙规则
    if command -v ufw >/dev/null && ufw status | grep -q "$port"; then
        record_result "pass" "UFW防火墙规则已配置"
    elif command -v firewall-cmd >/dev/null && firewall-cmd --list-ports | grep -q "$port"; then
        record_result "pass" "firewalld防火墙规则已配置"
    elif command -v iptables >/dev/null && iptables -L | grep -q "$port"; then
        record_result "pass" "iptables防火墙规则已配置"
    else
        record_result "warn" "未检测到防火墙规则，可能影响外部访问"
    fi
    
    # 检查网络连通性
    if curl -s --connect-timeout 5 ifconfig.me >/dev/null; then
        record_result "pass" "外网连接正常"
    else
        record_result "warn" "外网连接异常，可能影响IP获取"
    fi
}

# 检查Python环境
check_python_environment() {
    print_title "Python环境检查"
    
    local python_path="$INSTALL_DIR/venv/bin/python"
    
    if [[ -f "$python_path" ]]; then
        # 检查Python版本
        local python_version=$($python_path --version 2>&1)
        record_result "pass" "Python版本: $python_version"
        
        # 检查pip
        if [[ -f "$INSTALL_DIR/venv/bin/pip" ]]; then
            record_result "pass" "pip包管理器存在"
        else
            record_result "warn" "pip包管理器不存在"
        fi
        
        # 检查关键依赖包
        local packages=("cryptography" "pycryptodome")
        for package in "${packages[@]}"; do
            if $python_path -c "import $package" 2>/dev/null; then
                record_result "pass" "Python包 $package 已安装"
            else
                record_result "fail" "Python包 $package 未安装"
            fi
        done
        
        # 检查mtproxy模块
        if [[ -d "$INSTALL_DIR/mtproxy" || -f "$INSTALL_DIR/mtproxy.py" ]]; then
            record_result "pass" "MTProxy模块存在"
        else
            record_result "fail" "MTProxy模块不存在"
        fi
        
    else
        record_result "fail" "Python解释器不存在: $python_path"
    fi
}

# 检查系统资源
check_system_resources() {
    print_title "系统资源检查"
    
    # 检查内存使用
    local mem_total=$(free -m | grep '^Mem:' | awk '{print $2}')
    local mem_used=$(free -m | grep '^Mem:' | awk '{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    if [[ $mem_percent -lt 80 ]]; then
        record_result "pass" "内存使用率: ${mem_percent}%"
    elif [[ $mem_percent -lt 90 ]]; then
        record_result "warn" "内存使用率较高: ${mem_percent}%"
    else
        record_result "fail" "内存使用率过高: ${mem_percent}%"
    fi
    
    # 检查磁盘空间
    local disk_usage=$(df "$INSTALL_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        record_result "pass" "磁盘使用率: ${disk_usage}%"
    elif [[ $disk_usage -lt 90 ]]; then
        record_result "warn" "磁盘使用率较高: ${disk_usage}%"
    else
        record_result "fail" "磁盘使用率过高: ${disk_usage}%"
    fi
    
    # 检查系统负载
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    local cpu_cores=$(nproc)
    
    if command -v bc >/dev/null; then
        local load_percent=$(echo "scale=0; $load_avg * 100 / $cpu_cores" | bc)
        if [[ $load_percent -lt 70 ]]; then
            record_result "pass" "系统负载正常: ${load_avg} (${load_percent}%)"
        elif [[ $load_percent -lt 90 ]]; then
            record_result "warn" "系统负载较高: ${load_avg} (${load_percent}%)"
        else
            record_result "fail" "系统负载过高: ${load_avg} (${load_percent}%)"
        fi
    else
        record_result "pass" "系统负载: $load_avg"
    fi
}

# 检查日志文件
check_log_files() {
    print_title "日志文件检查"
    
    local log_dir="$INSTALL_DIR/logs"
    
    if [[ -d "$log_dir" ]]; then
        record_result "pass" "日志目录存在"
        
        # 检查各种日志文件
        local log_files=("mtproxy.log" "mtproxy-error.log" "mtproxy-access.log")
        for log_file in "${log_files[@]}"; do
            if [[ -f "$log_dir/$log_file" ]]; then
                local file_size=$(du -h "$log_dir/$log_file" | cut -f1)
                record_result "pass" "日志文件 $log_file 存在 (大小: $file_size)"
                
                # 检查日志文件是否过大
                local size_mb=$(du -m "$log_dir/$log_file" | cut -f1)
                if [[ $size_mb -gt 100 ]]; then
                    record_result "warn" "日志文件 $log_file 过大 (${size_mb}MB)，建议清理"
                fi
            else
                record_result "warn" "日志文件 $log_file 不存在"
            fi
        done
        
        # 检查日志目录权限
        if [[ -w "$log_dir" ]]; then
            record_result "pass" "日志目录可写"
        else
            record_result "fail" "日志目录不可写"
        fi
    else
        record_result "fail" "日志目录不存在"
    fi
}

# 安全检查
check_security() {
    print_title "安全检查"
    
    # 检查文件权限
    local config_perms=$(stat -c "%a" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$config_perms" == "600" || "$config_perms" == "644" ]]; then
        record_result "pass" "配置文件权限安全: $config_perms"
    else
        record_result "warn" "配置文件权限可能不安全: $config_perms"
    fi
    
    # 检查服务运行用户
    local service_user=$(systemctl show -p User --value "$SERVICE_NAME" 2>/dev/null)
    if [[ "$service_user" == "root" ]]; then
        record_result "warn" "服务以root用户运行，存在安全风险"
    elif [[ -n "$service_user" ]]; then
        record_result "pass" "服务运行用户: $service_user"
    else
        record_result "warn" "无法获取服务运行用户信息"
    fi
    
    # 检查密钥强度
    local secret=$(grep "^secret:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ' 2>/dev/null)
    if [[ -n "$secret" ]]; then
        # 简单的密钥强度检查
        if echo "$secret" | grep -qE '^[0-9a-fA-F]{32}$'; then
            record_result "pass" "密钥格式符合要求"
        else
            record_result "fail" "密钥格式不符合要求"
        fi
    fi
}

# 性能测试
check_performance() {
    print_title "性能检查"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        local pid=$(systemctl show -p MainPID --value "$SERVICE_NAME")
        
        if [[ "$pid" != "0" && "$pid" != "" ]]; then
            # 检查进程资源使用
            local cpu_usage=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')
            local mem_usage=$(ps -o %mem= -p "$pid" 2>/dev/null | tr -d ' ')
            local mem_rss=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1fMB", $1/1024}')
            
            if [[ -n "$cpu_usage" ]]; then
                if (( $(echo "$cpu_usage < 50" | bc -l 2>/dev/null || echo "1") )); then
                    record_result "pass" "CPU使用率: ${cpu_usage}%"
                else
                    record_result "warn" "CPU使用率较高: ${cpu_usage}%"
                fi
            fi
            
            if [[ -n "$mem_usage" ]]; then
                if (( $(echo "$mem_usage < 10" | bc -l 2>/dev/null || echo "1") )); then
                    record_result "pass" "内存使用率: ${mem_usage}% ($mem_rss)"
                else
                    record_result "warn" "内存使用率较高: ${mem_usage}% ($mem_rss)"
                fi
            fi
            
            # 检查进程运行时间
            local uptime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
            if [[ -n "$uptime" ]]; then
                record_result "pass" "进程运行时间: $uptime"
            fi
        else
            record_result "warn" "无法获取进程信息"
        fi
    else
        record_result "warn" "服务未运行，跳过性能检查"
    fi
}

# 生成修复建议
generate_fix_suggestions() {
    print_title "修复建议"
    
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        echo -e "${RED}发现 $FAILED_CHECKS 个严重问题，需要立即修复:${NC}"
        echo ""
        
        # 检查安装目录
        if [[ ! -d "$INSTALL_DIR" ]]; then
            echo "• 重新运行安装脚本: bash install.sh"
        fi
        
        # 检查配置文件
        if [[ ! -f "$CONFIG_FILE" ]]; then
            echo "• 重新生成配置文件或从备份恢复"
        fi
        
        # 检查服务注册
        if ! systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
            echo "• 重新注册系统服务: systemctl enable $SERVICE_NAME"
        fi
        
        # 检查Python环境
        if [[ ! -f "$INSTALL_DIR/venv/bin/python" ]]; then
            echo "• 重新创建Python虚拟环境"
        fi
    fi
    
    if [[ $WARNING_CHECKS -gt 0 ]]; then
        echo -e "${YELLOW}发现 $WARNING_CHECKS 个警告，建议优化:${NC}"
        echo ""
        
        echo "• 启用服务开机自启: systemctl enable $SERVICE_NAME"
        echo "• 配置防火墙规则允许代理端口"
        echo "• 定期清理过大的日志文件"
        echo "• 考虑使用非root用户运行服务"
    fi
    
    if [[ $FAILED_CHECKS -eq 0 && $WARNING_CHECKS -eq 0 ]]; then
        print_success "所有检查都通过，系统运行正常！"
    fi
}

# 显示验证结果摘要
show_summary() {
    print_title "验证结果摘要"
    
    echo "总检查项: $TOTAL_CHECKS"
    echo -e "通过: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "警告: ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "失败: ${RED}$FAILED_CHECKS${NC}"
    echo ""
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    if [[ $success_rate -ge 90 ]]; then
        print_success "系统健康度: ${success_rate}% (优秀)"
    elif [[ $success_rate -ge 80 ]]; then
        print_warning "系统健康度: ${success_rate}% (良好)"
    elif [[ $success_rate -ge 70 ]]; then
        print_warning "系统健康度: ${success_rate}% (一般)"
    else
        print_error "系统健康度: ${success_rate}% (需要修复)"
    fi
}

# 主验证函数
main() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   MTProxy 系统验证工具                        ║"
    echo "║                     v2.0 完整检查                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    print_info "开始进行系统验证..."
    echo ""
    
    # 执行各项检查
    check_files_and_directories
    echo ""
    
    check_config_content
    echo ""
    
    check_system_service
    echo ""
    
    check_network_and_ports
    echo ""
    
    check_python_environment
    echo ""
    
    check_system_resources
    echo ""
    
    check_log_files
    echo ""
    
    check_security
    echo ""
    
    check_performance
    echo ""
    
    # 显示结果
    show_summary
    echo ""
    
    generate_fix_suggestions
    
    # 返回适当的退出代码
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        exit 1
    elif [[ $WARNING_CHECKS -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
