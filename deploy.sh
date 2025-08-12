#!/bin/bash

# MTProxy 交互式部署脚本
# 提供友好的用户交互界面

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                     ${WHITE}MTProxy 交互式部署工具${CYAN}                      ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║  ${GREEN}🚀 快速部署 Telegram MTProxy 代理服务器${CYAN}                        ║${NC}"
    echo -e "${CYAN}║  ${YELLOW}📡 支持 TLS 伪装，突破网络封锁${CYAN}                               ║${NC}"
    echo -e "${CYAN}║  ${BLUE}🔧 友好的交互式配置界面${CYAN}                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示系统信息
show_system_info() {
    echo -e "${BLUE}📊 系统信息检测${NC}"
    echo -e "   操作系统: $(uname -s)"
    echo -e "   内核版本: $(uname -r)"
    echo -e "   架构信息: $(uname -m)"
    echo -e "   当前用户: $(whoami)"
    echo -e "   服务器IP: $(curl -s ifconfig.me 2>/dev/null || echo '获取失败')"
    echo ""
}

# 检查权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ 错误：需要 root 权限运行此脚本${NC}"
        echo -e "${YELLOW}💡 请使用以下命令重新运行：${NC}"
        echo -e "   ${WHITE}sudo bash deploy.sh${NC}"
        echo ""
        exit 1
    fi
}

# 检查系统兼容性
check_system() {
    echo -e "${BLUE}🔍 检查系统兼容性...${NC}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}⚠️  正在安装 curl...${NC}"
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y curl
        elif command -v yum &> /dev/null; then
            yum install -y curl
        else
            echo -e "${RED}❌ 无法安装 curl，请手动安装后重试${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ 系统检查完成${NC}"
    echo ""
}

# 用户确认
confirm_install() {
    echo -e "${YELLOW}⚠️  重要提示：${NC}"
    echo -e "   • 此脚本将在您的服务器上安装 MTProxy"
    echo -e "   • 安装过程需要下载必要的组件"
    echo -e "   • 建议在全新的服务器上运行"
    echo ""
    
    while true; do
        read -p "$(echo -e ${WHITE}是否继续安装？[y/N]: ${NC})" yn
        case $yn in
            [Yy]* ) 
                echo -e "${GREEN}✅ 开始安装...${NC}"
                break;;
            [Nn]* ) 
                echo -e "${RED}❌ 安装已取消${NC}"
                exit 0;;
            "" ) 
                echo -e "${RED}❌ 安装已取消（默认选择 No）${NC}"
                exit 0;;
            * ) 
                echo -e "${YELLOW}请输入 y 或 n${NC}";;
        esac
    done
    echo ""
}

# 显示安装进度
show_progress() {
    local step=$1
    local total=$2
    local desc=$3
    
    local percent=$((step * 100 / total))
    local filled=$((step * 50 / total))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[%3d%%]${NC} [" $percent
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${desc}"
    
    if [ $step -eq $total ]; then
        echo ""
    fi
}

# 主安装函数
main_install() {
    local INSTALL_DIR="/opt/mtproxy"
    
    echo -e "${GREEN}🔧 开始安装 MTProxy...${NC}"
    echo ""
    
    # 步骤1: 创建目录
    show_progress 1 4 "创建安装目录..."
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    sleep 1
    
    # 步骤2: 下载脚本
    show_progress 2 4 "下载核心脚本..."
    if curl -fsSL https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.sh -o mtproxy.sh; then
        chmod +x mtproxy.sh
    else
        echo -e "\n${RED}❌ 下载失败，请检查网络连接${NC}"
        exit 1
    fi
    sleep 1
    
    # 步骤3: 准备安装
    show_progress 3 4 "准备安装环境..."
    sleep 1
    
    # 步骤4: 开始交互式安装
    show_progress 4 4 "启动交互式安装..."
    echo ""
    echo ""
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                      ${WHITE}开始交互式配置${CYAN}                           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}💡 提示：${NC}"
    echo -e "   • 选择版本时推荐选择 ${GREEN}2${NC} (9seconds 第三方版本)"
    echo -e "   • 端口推荐使用 ${GREEN}443${NC} 或 ${GREEN}8443${NC}"
    echo -e "   • 伪装域名推荐使用 ${GREEN}www.bing.com${NC} 或 ${GREEN}azure.microsoft.com${NC}"
    echo -e "   • TAG 可以联系 @MTProxybot 获取"
    echo ""
    echo -e "${WHITE}按回车键继续...${NC}"
    read
    
    # 运行原始安装脚本
    bash mtproxy.sh
}

# 显示完成信息
show_completion() {
    local INSTALL_DIR="/opt/mtproxy"
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                      ${WHITE}✅ 安装完成！${GREEN}                            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 管理命令：${NC}"
    echo -e "   ${WHITE}启动服务:${NC} bash $INSTALL_DIR/mtproxy.sh start"
    echo -e "   ${WHITE}停止服务:${NC} bash $INSTALL_DIR/mtproxy.sh stop"
    echo -e "   ${WHITE}重启服务:${NC} bash $INSTALL_DIR/mtproxy.sh restart"
    echo -e "   ${WHITE}查看状态:${NC} bash $INSTALL_DIR/mtproxy.sh status"
    echo -e "   ${WHITE}查看日志:${NC} bash $INSTALL_DIR/mtproxy.sh log"
    echo -e "   ${WHITE}卸载服务:${NC} bash $INSTALL_DIR/mtproxy.sh uninstall"
    echo ""
    echo -e "${YELLOW}🔗 代理连接信息：${NC}"
    if [ -f "$INSTALL_DIR/proxy_links.txt" ]; then
        echo -e "   已保存在: ${WHITE}$INSTALL_DIR/proxy_links.txt${NC}"
    else
        echo -e "   请运行 ${WHITE}bash $INSTALL_DIR/mtproxy.sh status${NC} 查看"
    fi
    echo ""
    echo -e "${PURPLE}📞 获取帮助：${NC}"
    echo -e "   • GitHub: https://github.com/OrangeKing92/mtproxy-manager"
    echo -e "   • 原项目: https://github.com/ellermister/mtproxy"
    echo ""
}

# 主函数
main() {
    show_welcome
    show_system_info
    check_root
    check_system
    confirm_install
    main_install
    show_completion
}

# 执行主函数
main "$@"
