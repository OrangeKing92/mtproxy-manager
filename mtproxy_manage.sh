#!/bin/bash

# MTProxy 管理脚本
# 简单、直接、实用

INSTALL_DIR="/opt/mtproxy"
SCRIPT_PATH="$INSTALL_DIR/mtproxy.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_usage() {
    echo -e "${BLUE}MTProxy 管理工具${NC}"
    echo ""
    echo "用法: bash mtproxy_manage.sh [命令]"
    echo ""
    echo "命令:"
    echo -e "  ${GREEN}start${NC}     启动 MTProxy 服务"
    echo -e "  ${RED}stop${NC}      停止 MTProxy 服务"
    echo -e "  ${YELLOW}restart${NC}   重启 MTProxy 服务"
    echo -e "  ${BLUE}status${NC}    查看服务状态"
    echo -e "  ${BLUE}log${NC}       查看运行日志"
    echo -e "  ${BLUE}links${NC}     显示代理链接"
    echo -e "  ${RED}uninstall${NC} 卸载 MTProxy"
    echo ""
}

check_install() {
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}❌ MTProxy 未安装${NC}"
        echo "请先运行: bash deploy.sh"
        exit 1
    fi
}

case "$1" in
    start)
        check_install
        echo -e "${GREEN}🚀 启动 MTProxy...${NC}"
        bash "$SCRIPT_PATH" start
        ;;
    stop)
        check_install
        echo -e "${RED}🛑 停止 MTProxy...${NC}"
        bash "$SCRIPT_PATH" stop
        ;;
    restart)
        check_install
        echo -e "${YELLOW}🔄 重启 MTProxy...${NC}"
        bash "$SCRIPT_PATH" restart
        ;;
    status)
        check_install
        echo -e "${BLUE}📊 MTProxy 状态:${NC}"
        bash "$SCRIPT_PATH" status
        ;;
    log)
        check_install
        echo -e "${BLUE}📋 MTProxy 日志:${NC}"
        if [[ -f "$INSTALL_DIR/mtproxy.log" ]]; then
            tail -f "$INSTALL_DIR/mtproxy.log"
        else
            echo -e "${YELLOW}⚠️  日志文件不存在${NC}"
        fi
        ;;
    links)
        check_install
        echo -e "${BLUE}🔗 代理链接:${NC}"
        if [[ -f "$INSTALL_DIR/proxy_links.txt" ]]; then
            cat "$INSTALL_DIR/proxy_links.txt"
        else
            bash "$SCRIPT_PATH" info
        fi
        ;;
    uninstall)
        check_install
        echo -e "${RED}🗑️  卸载 MTProxy...${NC}"
        read -p "确认卸载? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "$SCRIPT_PATH" uninstall
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}✅ MTProxy 已完全卸载${NC}"
        fi
        ;;
    *)
        show_usage
        ;;
esac
