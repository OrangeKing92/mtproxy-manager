# MTProxy - 一键部署 Telegram 代理服务器

一个功能完善、易于部署和管理的 MTProxy 代理服务器，支持一键安装、图形化管理和自动运维。

## ✨ 核心特性

### 🚀 零配置部署
- **一键安装**: 支持 Ubuntu/Debian/CentOS，全自动部署
- **智能检测**: 自动识别系统环境，安装所需依赖
- **防火墙配置**: 自动配置防火墙规则，无需手动设置
- **系统服务**: 自动注册 systemd 服务，支持开机自启

### 🎛️ 可视化管理
- **交互式菜单**: 直观的管理界面，所有功能一目了然
- **实时监控**: 服务状态、资源使用、连接统计实时显示
- **配置管理**: 在线编辑配置、一键重启、配置验证
- **连接信息**: 自动生成连接链接和二维码，一键分享

### 🛡️ 企业级可靠性
- **健康检查**: 全面的系统检查，问题及时发现
- **自动恢复**: 服务异常自动重启，保障连续运行
- **日志管理**: 详细的日志记录和分析，故障排查轻松
- **安全加固**: 配置验证、权限管理、防火墙集成

### 📱 用户友好
- **小白友好**: 全中文界面，详细的操作提示
- **多种格式**: 支持链接、二维码、配置文件等多种分享方式
- **批量操作**: 一键生成所有格式的连接信息
- **兼容性强**: 支持所有主流 Telegram 客户端

## 🚀 快速开始

### 方法一：一键安装（推荐）

```bash
# 一行命令完成安装
bash <(curl -fsSL https://raw.githubusercontent.com/your-repo/mtproxy/main/install.sh)
```

### 方法二：下载安装

```bash
# 下载项目
git clone https://github.com/your-repo/mtproxy.git
cd mtproxy

# 运行安装脚本
sudo bash install.sh
```

### 方法三：快速体验

```bash
# 最小化安装（仅用于测试）
curl -fsSL https://raw.githubusercontent.com/your-repo/mtproxy/main/quick_install.sh | bash
```

安装完成后，您将看到：

```
🎉 MTProxy安装成功!

📋 连接信息:
服务器: 你的服务器IP
端口: 8443
密钥: 生成的32位密钥

🔗 Telegram连接链接:
tg://proxy?server=你的IP&port=8443&secret=你的密钥

🛠️ 管理命令:
启动管理面板: mtproxy
```

## 🎛️ 管理界面

安装完成后，使用 `mtproxy` 命令打开管理面板：

```bash
mtproxy
```

### 管理界面功能

```
╔══════════════════════════════════════════════════════════════╗
║                     MTProxy 管理面板                          ║
╚══════════════════════════════════════════════════════════════╝

┌─ 服务管理 ─────────────────────────────────────────────────┐
│ 1) 启动服务          2) 停止服务          3) 重启服务        │
│ 4) 查看状态          5) 查看日志          6) 重新加载配置    │
├─ 配置管理 ─────────────────────────────────────────────────┤
│ 7) 修改端口          8) 更换密钥          9) 编辑配置        │
│ 10) 连接信息         11) 生成二维码       12) 性能优化       │
├─ 系统管理 ─────────────────────────────────────────────────┤
│ 13) 更新程序         14) 卸载程序         15) 系统信息       │
│ 16) 防火墙设置       17) 流量统计         18) 备份还原       │
└─────────────────────────────────────────────────────────────┘
```

### 常用操作

**查看连接信息**
```bash
# 显示连接信息
mtproxy
# 选择 "10) 连接信息"
```

**生成二维码**
```bash
# 生成连接二维码
./scripts/connection.sh qr
```

**修改端口**
```bash
# 进入管理面板修改端口
mtproxy
# 选择 "7) 修改端口"
```

**更换密钥**
```bash
# 进入管理面板更换密钥
mtproxy
# 选择 "8) 更换密钥"
```

## 🔧 高级配置

### 配置文件位置

主配置文件: `/opt/python-mtproxy/config/mtproxy.conf`

```yaml
# MTProxy Configuration File

[DEFAULT]
# 基本配置
host: 0.0.0.0
port: 8443
secret: your_32_char_secret

# 性能配置
max_connections: 1000
workers: 4
timeout: 300
buffer_size: 16384

# 日志配置
log_level: INFO
log_dir: /opt/python-mtproxy/logs
access_log: True
error_log: True

# 统计配置
stats_enabled: True
stats_port: 8080

# 安全配置
secure_only: False
allowed_users: []
```

### 端口配置

支持的端口配置：

- **443**: HTTPS端口，推荐使用，不易被封锁
- **8443**: 常用代理端口，默认选择
- **自定义**: 支持 1-65535 任意端口

### 性能调优

根据服务器配置调整参数：

```yaml
# 小型服务器 (1核2G)
max_connections: 500
workers: 2

# 中型服务器 (2核4G)
max_connections: 1000
workers: 4

# 大型服务器 (4核8G+)
max_connections: 2000
workers: 8
```

## 🛠️ 管理工具

### 连接信息生成器

```bash
# 显示连接信息
./scripts/connection.sh info

# 生成二维码
./scripts/connection.sh qr [输出文件]

# 仅输出连接链接
./scripts/connection.sh link

# 测试连通性
./scripts/connection.sh test

# 批量生成所有格式
./scripts/connection.sh batch [输出目录]
```

### 系统验证工具

```bash
# 完整系统检查
./scripts/validate.sh

# 检查结果说明:
# ✅ 通过: 系统正常
# ⚠️  警告: 建议优化
# ❌ 失败: 需要修复
```

### 本地管理脚本

```bash
# 详细管理功能
./scripts/manage.sh

# 快速操作
systemctl start python-mtproxy    # 启动
systemctl stop python-mtproxy     # 停止
systemctl restart python-mtproxy  # 重启
systemctl status python-mtproxy   # 状态
```

## 📊 监控和诊断

### 服务状态监控

```bash
# 查看服务状态
mtproxy
# 选择 "4) 查看状态"

# 或直接使用系统命令
systemctl status python-mtproxy
```

### 日志查看

```bash
# 实时日志
journalctl -u python-mtproxy -f

# 错误日志
journalctl -u python-mtproxy -p err

# 管理面板查看
mtproxy
# 选择 "5) 查看日志"
```

### 性能监控

```bash
# 系统资源使用
./scripts/validate.sh

# 连接统计
ss -tlnp | grep :8443

# 进程信息
ps aux | grep mtproxy
```

## 🔐 安全设置

### 防火墙配置

安装脚本会自动配置防火墙，支持：

- **UFW** (Ubuntu/Debian)
- **firewalld** (CentOS/RHEL)
- **iptables** (通用)

手动配置示例：

```bash
# UFW
sudo ufw allow 8443/tcp

# firewalld
sudo firewall-cmd --permanent --add-port=8443/tcp
sudo firewall-cmd --reload

# iptables
sudo iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
```

### 访问控制

在配置文件中设置访问控制：

```yaml
# 仅允许特定IP
allowed_users: ["192.168.1.100", "10.0.0.0/24"]

# 连接限制
max_connections: 1000
timeout: 300
```

### 密钥安全

- 使用32位十六进制随机密钥
- 定期更换密钥
- 避免使用简单或重复的密钥

## 🚨 故障排除

### 常见问题

**1. 服务无法启动**
```bash
# 检查日志
journalctl -u python-mtproxy -n 50

# 验证配置
./scripts/validate.sh

# 检查端口占用
ss -tlnp | grep :8443
```

**2. 连接失败**
```bash
# 检查防火墙
sudo ufw status
sudo firewall-cmd --list-ports

# 测试端口连通性
telnet 你的服务器IP 8443

# 检查服务状态
systemctl status python-mtproxy
```

**3. 性能问题**
```bash
# 检查系统资源
./scripts/validate.sh

# 调整配置参数
mtproxy
# 选择 "9) 编辑配置"
```

### 获取帮助

1. **运行诊断工具**
   ```bash
   ./scripts/validate.sh
   ```

2. **查看详细日志**
   ```bash
   journalctl -u python-mtproxy -f
   ```

3. **检查系统状态**
   ```bash
   mtproxy
   # 选择 "15) 系统信息"
   ```

## 📁 目录结构

```
/opt/python-mtproxy/           # 安装目录
├── mtproxy/                   # 核心程序
├── config/                    # 配置文件
│   └── mtproxy.conf          # 主配置文件
├── logs/                      # 日志文件
├── scripts/                   # 管理脚本
│   ├── start.sh              # 启动脚本
│   ├── stop.sh               # 停止脚本
│   ├── restart.sh            # 重启脚本
│   ├── manage.sh             # 管理脚本
│   ├── validate.sh           # 验证脚本
│   └── connection.sh         # 连接信息脚本
└── venv/                      # Python虚拟环境

/usr/local/bin/mtproxy         # 全局管理命令
/etc/systemd/system/python-mtproxy.service  # 系统服务
```

## 🔄 更新和卸载

### 更新程序

```bash
# 自动更新
mtproxy
# 选择 "13) 更新程序"

# 手动更新
cd /opt/python-mtproxy
git pull
sudo ./scripts/restart.sh
```

### 卸载程序

```bash
# 完全卸载
sudo ./scripts/uninstall.sh

# 或使用管理面板
mtproxy
# 选择 "14) 卸载程序"
```

## 💝 支持项目

如果这个项目对您有帮助，请考虑：

- ⭐ 给项目点个星星
- 🐛 报告问题和建议
- 🔧 提交代码改进
- 📢 分享给其他人

## 📜 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🔗 相关链接

- **项目主页**: https://github.com/your-repo/mtproxy
- **问题反馈**: https://github.com/your-repo/mtproxy/issues
- **文档中心**: https://github.com/your-repo/mtproxy/wiki
- **更新日志**: https://github.com/your-repo/mtproxy/releases

---

**快速安装命令**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/your-repo/mtproxy/main/install.sh)
```

安装完成后使用 `mtproxy` 命令进入管理界面！