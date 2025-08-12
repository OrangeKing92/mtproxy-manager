# MTProxy Manager

🚀 **一键部署 Telegram MTProxy 代理的 Python 实现**

简单易用的 MTProxy 代理服务器，支持一键安装、图形化管理和远程控制。

## ✨ 特性

- 🔧 **一键安装** - 自动化部署脚本，支持主流 Linux 发行版
- 🎛️ **交互式管理** - 直观的命令行管理界面
- 🌐 **远程控制** - 完整的 SSH 远程管理支持
- 🔒 **安全可靠** - TLS 支持，自动密钥生成
- 📊 **实时监控** - 服务状态监控和日志查看
- ⚡ **高性能** - 异步架构，支持高并发连接

## 🚀 快速开始

### 方式1: 一键安装（推荐）

```bash
# 远程安装（推荐）
bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

### 方式2: 本地部署

```bash
# 克隆代码
git clone https://github.com/OrangeKing92/mtproxy-manager.git
cd mtproxy-manager

# 本地部署
sudo ./scripts/deploy.sh
```

### 管理面板

```bash
mtproxy  # 打开管理面板
```

安装完成后，系统会自动显示代理连接信息。

## 📱 连接到 Telegram

### 方法一：自动连接（推荐）
1. 复制安装完成后显示的连接链接
2. 在手机上打开链接，Telegram 会自动提示添加代理
3. 点击"连接代理"即可使用

### 方法二：手动配置
在 Telegram 设置中添加 MTProto 代理：
- **服务器**：你的服务器 IP
- **端口**：8443（默认）
- **密钥**：安装时生成的 32 位密钥

## 🎛️ 管理功能

运行 `mtproxy` 命令进入管理面板：

### 📋 服务管理
- 启动/停止/重启服务
- 查看服务状态和日志
- 实时监控连接数和流量

### ⚙️ 配置管理
- 修改监听端口
- 重新生成连接密钥
- 查看完整连接信息
- 生成连接二维码

### 🔧 系统工具
- 程序更新和卸载
- 系统信息查看
- 防火墙配置
- 配置文件备份恢复

## 📝 常用命令

```bash
# 管理面板
mtproxy

# 服务控制
systemctl start|stop|restart|status python-mtproxy

# 查看日志
journalctl -u python-mtproxy -f

# 快速获取连接信息
python tools/mtproxy_cli.py proxy
```

## 🔧 远程管理

### SSH 工具集

```bash
# 远程查看服务状态
ssh user@server "python /opt/python-mtproxy/tools/mtproxy_cli.py status"

# 远程获取代理信息
ssh user@server "python /opt/python-mtproxy/tools/mtproxy_cli.py proxy"

# 远程查看日志
ssh user@server "python /opt/python-mtproxy/tools/mtproxy_cli.py logs"

# 远程健康检查
ssh user@server "python /opt/python-mtproxy/tools/mtproxy_cli.py health"
```

### 批量管理

```bash
# 多服务器状态检查
for server in server1 server2 server3; do
    ssh $server "python /opt/python-mtproxy/tools/mtproxy_cli.py status"
done
```

## 📁 项目结构

```
mtproxy-manager/
├── mtproxy/           # 核心代理服务
│   ├── server.py      # 主服务器
│   ├── protocol.py    # 协议实现
│   ├── crypto.py      # 加密模块
│   └── ...
├── tools/             # 管理工具集
│   ├── mtproxy_cli.py # 命令行工具
│   ├── monitor.py     # 监控工具
│   └── ...
├── scripts/           # 部署和管理脚本
│   ├── deploy.sh      # 本地部署脚本
│   ├── manage.sh      # 服务管理脚本
│   └── uninstall.sh   # 卸载脚本
├── config/            # 配置文件模板
├── requirements.txt   # Python依赖
└── install.sh         # 一键安装脚本
```

### 使用说明

- **install.sh** - 一键安装脚本，适用于远程安装
- **scripts/deploy.sh** - 本地部署脚本，适用于开发环境
- **scripts/manage.sh** - 主要管理工具，安装后可通过`mtproxy`命令使用
- **scripts/uninstall.sh** - 完全卸载MTProxy

## 🛠️ 系统要求

- **操作系统**: Ubuntu 18.04+ / Debian 10+ / CentOS 7+
- **Python**: 3.8+
- **内存**: 最少 512MB，推荐 1GB+
- **网络**: 稳定的互联网连接和公网 IP
- **权限**: Root 或 sudo 权限

## 🔍 故障排除

### 常见问题

**服务无法启动？**
```bash
# 检查日志
journalctl -u python-mtproxy -n 50

# 检查端口占用
ss -tlnp | grep :8443

# 运行健康检查
python tools/mtproxy_cli.py health
```

**无法连接？**
```bash
# 检查防火墙
ufw status

# 测试端口连通性
telnet 你的服务器IP 8443
```

## 🗑️ 卸载

```bash
# 使用管理面板卸载
mtproxy  # 选择卸载选项

# 或运行卸载脚本
sudo /opt/python-mtproxy/scripts/uninstall.sh
```

## 📋 配置文件

主配置文件位于：`/opt/python-mtproxy/config/mtproxy.conf`

```yaml
server:
  host: 0.0.0.0
  port: 8443
  secret: auto_generate
  tls_secret: auto_generate
  fake_domain: www.cloudflare.com
  max_connections: 1000

logging:
  level: INFO
  file: logs/mtproxy.log
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

⭐ 如果这个项目对你有帮助，请给个 Star！