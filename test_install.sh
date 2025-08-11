#!/bin/bash

# MTProxy 安装测试脚本
# 用于在开发环境中测试安装流程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_info "测试: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        print_success "$test_name"
        return 0
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        print_error "$test_name"
        return 1
    fi
}

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   MTProxy 安装测试套件                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_info "开始测试安装脚本和相关文件..."
echo ""

# 测试文件存在性
echo -e "${CYAN}=== 文件存在性测试 ===${NC}"
run_test "主安装脚本存在" "test -f install.sh"
run_test "快速安装脚本存在" "test -f quick_install.sh"
run_test "管理脚本存在" "test -f scripts/manage.sh"
run_test "验证脚本存在" "test -f scripts/validate.sh"
run_test "连接脚本存在" "test -f scripts/connection.sh"
run_test "README文件存在" "test -f README.md"
echo ""

# 测试脚本语法
echo -e "${CYAN}=== 脚本语法测试 ===${NC}"
run_test "主安装脚本语法" "bash -n install.sh"
run_test "管理脚本语法" "bash -n scripts/manage.sh"
run_test "验证脚本语法" "bash -n scripts/validate.sh"
run_test "连接脚本语法" "bash -n scripts/connection.sh"
echo ""

# 测试关键函数
echo -e "${CYAN}=== 函数定义测试 ===${NC}"

# 检查安装脚本中的关键函数
install_functions=(
    "check_root"
    "detect_os"
    "install_dependencies"
    "select_port"
    "generate_secret"
    "get_server_ip"
    "create_systemd_service"
    "show_installation_result"
)

for func in "${install_functions[@]}"; do
    run_test "安装脚本函数: $func" "grep -q \"^$func()\" install.sh"
done
echo ""

# 检查管理脚本中的关键函数
management_functions=(
    "show_banner"
    "show_main_menu"
    "start_service"
    "stop_service"
    "restart_service"
    "get_connection_info"
    "change_port"
    "change_secret"
)

for func in "${management_functions[@]}"; do
    run_test "管理脚本函数: $func" "grep -q \"^$func()\" scripts/manage.sh"
done
echo ""

# 测试配置项
echo -e "${CYAN}=== 配置项测试 ===${NC}"
run_test "服务名称定义" "grep -q 'SERVICE_NAME.*python-mtproxy' install.sh"
run_test "安装目录定义" "grep -q 'INSTALL_DIR.*opt.*python-mtproxy' install.sh"
run_test "配置文件路径定义" "grep -q 'CONFIG_FILE.*mtproxy.conf' scripts/manage.sh"
echo ""

# 测试系统兼容性检查
echo -e "${CYAN}=== 系统兼容性测试 ===${NC}"
run_test "Ubuntu/Debian支持" "grep -q 'debian' install.sh"
run_test "CentOS支持" "grep -q 'centos' install.sh"
run_test "包管理器检测" "grep -q 'apt\\|yum' install.sh"
echo ""

# 测试安全特性
echo -e "${CYAN}=== 安全特性测试 ===${NC}"
run_test "Root权限检查" "grep -q 'check_root' install.sh"
run_test "端口验证" "grep -q 'check_port' install.sh"
run_test "密钥生成" "grep -q 'openssl rand' install.sh"
run_test "防火墙配置" "grep -q 'ufw\\|firewall-cmd\\|iptables' install.sh"
echo ""

# 测试服务管理
echo -e "${CYAN}=== 服务管理测试 ===${NC}"
run_test "systemd服务创建" "grep -q 'systemctl' install.sh"
run_test "服务启用" "grep -q 'systemctl enable' install.sh"
run_test "服务状态检查" "grep -q 'systemctl.*active' scripts/manage.sh"
echo ""

# 测试错误处理
echo -e "${CYAN}=== 错误处理测试 ===${NC}"
run_test "错误退出处理" "grep -q 'set -e' install.sh"
run_test "错误函数定义" "grep -q 'print_error' install.sh"
run_test "配置验证" "grep -q 'validate.*config' scripts/validate.sh"
echo ""

# 测试用户体验
echo -e "${CYAN}=== 用户体验测试 ===${NC}"
run_test "进度提示" "grep -q 'print_info\\|print_success' install.sh"
run_test "颜色输出" "grep -q 'GREEN\\|RED\\|BLUE' install.sh"
run_test "交互式菜单" "grep -q 'read -p' scripts/manage.sh"
run_test "帮助信息" "grep -q 'help\\|usage' scripts/connection.sh"
echo ""

# 测试文档完整性
echo -e "${CYAN}=== 文档完整性测试 ===${NC}"
run_test "README标题" "grep -q '^# MTProxy' README.md"
run_test "安装说明" "grep -q '快速开始\\|安装' README.md"
run_test "使用说明" "grep -q '管理\\|命令' README.md"
run_test "故障排除" "grep -q '故障\\|问题' README.md"
echo ""

# 显示测试结果
echo -e "${CYAN}=== 测试结果总结 ===${NC}"
echo "总测试数: $TOTAL_TESTS"
echo -e "通过: ${GREEN}$PASSED_TESTS${NC}"
echo -e "失败: ${RED}$FAILED_TESTS${NC}"

success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo "成功率: ${success_rate}%"

echo ""
if [[ $FAILED_TESTS -eq 0 ]]; then
    print_success "🎉 所有测试通过！脚本可以发布使用"
    exit 0
elif [[ $success_rate -ge 90 ]]; then
    print_warning "⚠️  大部分测试通过，建议修复剩余问题后发布"
    exit 1
else
    print_error "❌ 测试失败过多，需要修复问题后重新测试"
    exit 1
fi
