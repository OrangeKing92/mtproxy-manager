#!/bin/bash

# MTProxy 一键部署测试脚本
# 用于测试从GitHub仓库直接部署

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[测试]${NC} $1"; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
print_error() { echo -e "${RED}[错误]${NC} $1"; }

# GitHub仓库地址
REPO_URL="https://github.com/OrangeKing92/mtproxy-manager.git"
REPO_RAW_URL="https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                MTProxy 一键部署测试                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_info "开始测试从GitHub仓库一键部署..."
echo ""

# 1. 停止现有服务（如果存在）
print_info "1. 检查并停止现有MTProxy服务..."
if systemctl is-active --quiet python-mtproxy 2>/dev/null; then
    print_warning "发现运行中的MTProxy服务，正在停止..."
    sudo systemctl stop python-mtproxy || true
    sudo systemctl disable python-mtproxy || true
    print_success "服务已停止"
else
    print_info "未发现运行中的服务"
fi

# 2. 清理现有安装
print_info "2. 清理现有安装文件..."
if [ -d "/opt/python-mtproxy" ]; then
    print_warning "发现现有安装目录，正在清理..."
    sudo rm -rf /opt/python-mtproxy
    print_success "安装目录已清理"
fi

if [ -f "/usr/local/bin/mtproxy" ]; then
    print_warning "发现现有命令链接，正在清理..."
    sudo rm -f /usr/local/bin/mtproxy
    print_success "命令链接已清理"
fi

if [ -f "/etc/systemd/system/python-mtproxy.service" ]; then
    print_warning "发现现有systemd服务，正在清理..."
    sudo rm -f /etc/systemd/system/python-mtproxy.service
    sudo systemctl daemon-reload
    print_success "systemd服务已清理"
fi

# 3. 测试在线一键安装
print_info "3. 测试在线一键安装..."
echo ""
print_info "方法1: 使用curl直接安装"
echo -e "${YELLOW}命令: ${NC}bash <(curl -fsSL ${REPO_RAW_URL}/install.sh)"
echo ""

read -p "是否开始在线安装测试？(y/N): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    print_info "开始在线安装..."
    if curl -fsSL "${REPO_RAW_URL}/install.sh" | bash; then
        print_success "在线安装测试成功！"
        ONLINE_TEST_SUCCESS=true
    else
        print_error "在线安装测试失败！"
        ONLINE_TEST_SUCCESS=false
    fi
else
    print_warning "跳过在线安装测试"
    ONLINE_TEST_SUCCESS=false
fi

echo ""

# 4. 测试克隆安装
print_info "4. 测试Git克隆安装..."
echo ""
read -p "是否测试Git克隆安装？(y/N): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    # 如果在线安装成功，先清理
    if [ "$ONLINE_TEST_SUCCESS" = true ]; then
        print_info "清理在线安装结果..."
        sudo systemctl stop python-mtproxy || true
        sudo systemctl disable python-mtproxy || true
        sudo rm -rf /opt/python-mtproxy
        sudo rm -f /usr/local/bin/mtproxy
        sudo rm -f /etc/systemd/system/python-mtproxy.service
        sudo systemctl daemon-reload
    fi
    
    print_info "开始Git克隆安装..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    print_info "克隆仓库: $REPO_URL"
    if git clone "$REPO_URL" mtproxy-test; then
        cd mtproxy-test
        print_info "运行安装脚本..."
        if sudo bash install.sh; then
            print_success "Git克隆安装测试成功！"
            GIT_TEST_SUCCESS=true
        else
            print_error "Git克隆安装测试失败！"
            GIT_TEST_SUCCESS=false
        fi
    else
        print_error "Git克隆失败！"
        GIT_TEST_SUCCESS=false
    fi
    
    # 清理临时目录
    rm -rf "$TEMP_DIR"
else
    print_warning "跳过Git克隆安装测试"
    GIT_TEST_SUCCESS=false
fi

echo ""

# 5. 验证安装结果
if [ "$ONLINE_TEST_SUCCESS" = true ] || [ "$GIT_TEST_SUCCESS" = true ]; then
    print_info "5. 验证安装结果..."
    
    # 检查服务状态
    if systemctl is-active --quiet python-mtproxy; then
        print_success "✓ MTProxy服务正在运行"
    else
        print_error "✗ MTProxy服务未运行"
    fi
    
    # 检查安装目录
    if [ -d "/opt/python-mtproxy" ]; then
        print_success "✓ 安装目录存在"
    else
        print_error "✗ 安装目录不存在"
    fi
    
    # 检查管理命令
    if [ -f "/usr/local/bin/mtproxy" ]; then
        print_success "✓ 管理命令可用"
    else
        print_error "✗ 管理命令不可用"
    fi
    
    # 检查配置文件
    if [ -f "/opt/python-mtproxy/config/mtproxy.conf" ]; then
        print_success "✓ 配置文件存在"
    else
        print_error "✗ 配置文件不存在"
    fi
    
    # 运行系统验证
    if [ -f "/opt/python-mtproxy/scripts/validate.sh" ]; then
        print_info "运行系统验证..."
        if /opt/python-mtproxy/scripts/validate.sh; then
            print_success "✓ 系统验证通过"
        else
            print_warning "⚠ 系统验证有问题，请检查"
        fi
    fi
    
    # 显示连接信息
    if [ -f "/opt/python-mtproxy/scripts/connection.sh" ]; then
        print_info "获取连接信息..."
        /opt/python-mtproxy/scripts/connection.sh info
    fi
    
    echo ""
    print_success "🎉 部署测试完成！"
    print_info "管理命令: mtproxy"
    print_info "系统检查: /opt/python-mtproxy/scripts/validate.sh"
    print_info "连接信息: /opt/python-mtproxy/scripts/connection.sh info"
    
else
    print_warning "未进行安装测试"
fi

echo ""
print_info "测试完成！"

# 询问是否保留安装
echo ""
read -p "是否保留当前安装？(Y/n): " keep_install
if [[ $keep_install =~ ^[Nn]$ ]]; then
    print_info "正在清理安装..."
    sudo systemctl stop python-mtproxy || true
    sudo systemctl disable python-mtproxy || true
    sudo rm -rf /opt/python-mtproxy
    sudo rm -f /usr/local/bin/mtproxy
    sudo rm -f /etc/systemd/system/python-mtproxy.service
    sudo systemctl daemon-reload
    print_success "安装已清理"
else
    print_success "安装已保留，您可以继续使用"
fi
