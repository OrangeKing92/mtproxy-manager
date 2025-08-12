#!/bin/bash

# MTProxy 一键部署脚本
# 基于 ellermister/mtproxy 项目

set -e

echo "🚀 MTProxy 一键部署开始..."

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo "❌ 请使用 root 权限运行此脚本"
   echo "   sudo bash deploy.sh"
   exit 1
fi

# 创建安装目录
INSTALL_DIR="/opt/mtproxy"
echo "📁 创建安装目录: $INSTALL_DIR"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# 下载核心脚本
echo "⬇️  下载 MTProxy 核心脚本..."
curl -fsSL https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.sh -o mtproxy.sh
chmod +x mtproxy.sh

# 运行安装
echo "🔧 开始安装 MTProxy..."
bash mtproxy.sh

echo ""
echo "✅ MTProxy 部署完成！"
echo ""
echo "📋 管理命令："
echo "   启动服务: bash $INSTALL_DIR/mtproxy.sh start"
echo "   停止服务: bash $INSTALL_DIR/mtproxy.sh stop"
echo "   重启服务: bash $INSTALL_DIR/mtproxy.sh restart"
echo "   查看状态: bash $INSTALL_DIR/mtproxy.sh status"
echo "   查看日志: bash $INSTALL_DIR/mtproxy.sh log"
echo "   卸载服务: bash $INSTALL_DIR/mtproxy.sh uninstall"
echo ""
echo "🔗 代理链接已保存在: $INSTALL_DIR/proxy_links.txt"
