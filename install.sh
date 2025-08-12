#!/bin/bash

# MTProxy Manager 一键安装脚本
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

# 重定向到部署脚本
DEPLOY_SCRIPT_URL="https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/scripts/deploy.sh"

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

# 主安装函数 - 重定向到部署脚本
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
    
    print_info "正在下载并执行MTProxy Manager部署脚本..."
    
    # 下载并执行部署脚本
    if command -v curl >/dev/null; then
        bash <(curl -fsSL "$DEPLOY_SCRIPT_URL")
    elif command -v wget >/dev/null; then
        bash <(wget -qO- "$DEPLOY_SCRIPT_URL")
    else
        print_error "未找到curl或wget，无法下载安装脚本"
        echo ""
        echo "请手动安装curl或wget，然后重新运行此脚本"
        echo "Ubuntu/Debian: apt install curl"
        echo "CentOS/RHEL: yum install curl"
        exit 1
    fi
}

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi