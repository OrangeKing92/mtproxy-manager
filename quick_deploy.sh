#!/bin/bash

# MTProxy 快速部署脚本 (非交互式)
# 适用于自动化部署场景

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PORT=443
DEFAULT_MANAGE_PORT=8888
DEFAULT_DOMAIN="azure.microsoft.com"
DEFAULT_PROVIDER=2  # 9seconds 版本

echo -e "${CYAN}🚀 MTProxy 快速部署 (非交互式)${NC}"
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ 需要 root 权限运行此脚本${NC}"
   echo -e "${YELLOW}请使用: sudo bash quick_deploy.sh${NC}"
   exit 1
fi

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "127.0.0.1")
echo -e "${BLUE}📡 服务器IP: ${WHITE}$SERVER_IP${NC}"

# 创建安装目录
INSTALL_DIR="/opt/mtproxy"
echo -e "${BLUE}📁 创建目录: ${WHITE}$INSTALL_DIR${NC}"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# 下载脚本
echo -e "${BLUE}⬇️  下载核心脚本...${NC}"
if curl -fsSL https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.sh -o mtproxy.sh; then
    chmod +x mtproxy.sh
    echo -e "${GREEN}✅ 下载成功${NC}"
else
    echo -e "${RED}❌ 下载失败${NC}"
    exit 1
fi

# 生成随机密钥
SECRET=$(openssl rand -hex 16)
echo -e "${BLUE}🔐 生成密钥: ${WHITE}$SECRET${NC}"

# 创建自动配置文件
cat > auto_config.txt << EOF
$DEFAULT_PROVIDER
$DEFAULT_PORT
$DEFAULT_MANAGE_PORT
$DEFAULT_DOMAIN

EOF

echo -e "${BLUE}🔧 开始自动安装...${NC}"
echo -e "${YELLOW}配置信息:${NC}"
echo -e "   版本: 9seconds (推荐)"
echo -e "   端口: $DEFAULT_PORT"
echo -e "   管理端口: $DEFAULT_MANAGE_PORT"
echo -e "   伪装域名: $DEFAULT_DOMAIN"
echo -e "   密钥: $SECRET"
echo ""

# 运行安装 (使用配置文件作为输入)
bash mtproxy.sh < auto_config.txt

echo ""
echo -e "${GREEN}✅ 快速部署完成！${NC}"
echo ""
echo -e "${CYAN}📋 管理命令：${NC}"
echo -e "   启动: bash $INSTALL_DIR/mtproxy.sh start"
echo -e "   停止: bash $INSTALL_DIR/mtproxy.sh stop"
echo -e "   状态: bash $INSTALL_DIR/mtproxy.sh status"
echo ""
echo -e "${YELLOW}🔗 连接信息请查看: bash $INSTALL_DIR/mtproxy.sh status${NC}"
