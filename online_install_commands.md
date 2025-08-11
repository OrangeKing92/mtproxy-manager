# MTProxy 在线一键安装命令

## 🚀 快速安装命令

### 方法1: 一行命令安装（推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

### 方法2: 使用wget（备选）

```bash
bash <(wget -qO- https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

### 方法3: 下载后安装

```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh -o mtproxy_install.sh

# 查看脚本内容（可选）
cat mtproxy_install.sh

# 运行安装
sudo bash mtproxy_install.sh
```

### 方法4: Git克隆完整安装

```bash
# 克隆仓库
git clone https://github.com/OrangeKing92/mtproxy-manager.git
cd mtproxy-manager

# 运行安装
sudo bash install.sh

# 或使用快速安装
sudo bash quick_install.sh
```

## 📱 安装后使用

安装完成后，使用以下命令：

```bash
# 打开管理面板
mtproxy

# 获取连接信息
mtproxy-info

# 系统健康检查
mtproxy-check

# 查看服务状态
sudo systemctl status python-mtproxy
```

## 🔧 高级安装选项

### 静默安装

```bash
# 使用默认配置静默安装
SILENT_INSTALL=true bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

### 自定义端口安装

```bash
# 指定端口安装
MTPROXY_PORT=8443 bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

### 开发版本安装

```bash
# 安装开发版本
INSTALL_DEV=true bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

## 🌐 支持的系统

- ✅ Ubuntu 18.04+
- ✅ Debian 9+  
- ✅ CentOS 7+
- ✅ Rocky Linux 8+
- ✅ AlmaLinux 8+

## 📋 系统要求

- 🖥️ **CPU**: 1核心+ (推荐2核心+)
- 💾 **内存**: 512MB+ (推荐1GB+)
- 💽 **存储**: 1GB+ 可用空间
- 🌐 **网络**: 公网IP和开放端口
- 🔧 **权限**: Root或sudo权限

## 🚨 注意事项

1. **确保网络连接正常**
2. **使用Root权限运行**
3. **开放防火墙端口**
4. **检查服务器提供商端口限制**

## 🔍 故障排除

如果安装失败，请尝试：

```bash
# 手动安装依赖
sudo apt update && sudo apt install -y curl git python3 python3-pip  # Ubuntu/Debian
sudo yum update && sudo yum install -y curl git python3 python3-pip  # CentOS

# 重新运行安装
bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

## 📞 获取帮助

- 📖 详细文档: [README.md](https://github.com/OrangeKing92/mtproxy-manager/blob/main/README.md)
- 🐛 问题报告: [GitHub Issues](https://github.com/OrangeKing92/mtproxy-manager/issues)
- 💬 使用指南: [USAGE.md](https://github.com/OrangeKing92/mtproxy-manager/blob/main/USAGE.md)
