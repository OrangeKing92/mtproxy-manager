# MTProxy 使用指南

## 🚀 快速开始

### 一键安装

```bash
# 方法1: 在线安装（推荐）
bash <(curl -fsSL https://raw.githubusercontent.com/your-repo/mtproxy/main/install.sh)

# 方法2: 下载后安装
git clone https://github.com/your-repo/mtproxy.git
cd mtproxy
sudo bash install.sh
```

### 安装过程

1. **系统检查**: 自动检测操作系统类型
2. **依赖安装**: 安装Python、Git等必要组件
3. **端口选择**: 选择代理服务端口（建议443或8443）
4. **密钥生成**: 自动生成32位安全密钥
5. **服务配置**: 创建systemd服务并启用自动启动
6. **防火墙配置**: 自动开放所需端口
7. **完成提示**: 显示连接信息和管理命令

## 🎛️ 管理界面

安装完成后，使用管理命令：

```bash
mtproxy
```

### 主菜单功能

#### 📋 服务管理
- **启动服务**: 启动MTProxy代理服务
- **停止服务**: 停止代理服务
- **重启服务**: 重启服务（配置修改后使用）
- **查看状态**: 显示服务运行状态和详细信息
- **查看日志**: 实时查看服务日志
- **重新加载配置**: 不重启服务的情况下重新加载配置

#### ⚙️ 配置管理
- **修改端口**: 更改代理服务端口
- **更换密钥**: 生成新的连接密钥
- **编辑配置**: 直接编辑配置文件
- **连接信息**: 显示完整的连接信息
- **生成二维码**: 生成连接二维码
- **性能优化**: 调整性能参数

#### 🔧 系统管理
- **更新程序**: 更新到最新版本
- **卸载程序**: 完全卸载MTProxy
- **系统信息**: 查看系统资源使用情况
- **防火墙设置**: 管理防火墙规则
- **流量统计**: 查看使用统计
- **备份还原**: 备份和恢复配置

## 📱 连接到Telegram

### 自动连接（推荐）

1. 复制安装完成后显示的连接链接
2. 在手机上打开链接
3. Telegram会自动提示添加代理
4. 点击"连接"即可

### 手动连接

1. 打开Telegram设置
2. 选择"数据和存储"
3. 点击"代理设置"
4. 选择"添加代理"
5. 选择"MTProto"
6. 填入服务器信息：
   - 服务器：你的服务器IP
   - 端口：选择的端口号
   - 密钥：生成的32位密钥

### 二维码连接

```bash
# 生成二维码
./scripts/connection.sh qr

# 保存二维码到文件
./scripts/connection.sh qr /path/to/qr.png
```

用手机扫描二维码即可自动添加代理。

## 🛠️ 常用管理命令

### 系统服务操作

```bash
# 启动服务
sudo systemctl start python-mtproxy

# 停止服务
sudo systemctl stop python-mtproxy

# 重启服务
sudo systemctl restart python-mtproxy

# 查看状态
sudo systemctl status python-mtproxy

# 查看日志
sudo journalctl -u python-mtproxy -f
```

### 快速管理

```bash
# 打开管理面板
mtproxy

# 获取连接信息
./scripts/connection.sh info

# 系统健康检查
./scripts/validate.sh

# 详细管理功能
./scripts/manage.sh
```

## 🔧 配置说明

### 主配置文件

位置：`/opt/python-mtproxy/config/mtproxy.conf`

```yaml
# 基本配置
host: 0.0.0.0          # 监听地址
port: 8443              # 监听端口
secret: your_secret     # 连接密钥

# 性能配置
max_connections: 1000   # 最大连接数
workers: 4              # 工作进程数
timeout: 300            # 连接超时时间

# 日志配置
log_level: INFO         # 日志级别
log_dir: /opt/python-mtproxy/logs  # 日志目录
```

### 修改配置

```bash
# 方法1: 使用管理面板
mtproxy
# 选择 "9) 编辑配置"

# 方法2: 直接编辑
sudo nano /opt/python-mtproxy/config/mtproxy.conf

# 修改后重启服务
sudo systemctl restart python-mtproxy
```

## 🚨 故障排除

### 常见问题及解决方案

#### 1. 服务无法启动

**检查步骤：**
```bash
# 查看错误日志
sudo journalctl -u python-mtproxy -n 50

# 检查配置文件
./scripts/validate.sh

# 检查端口占用
sudo ss -tlnp | grep :8443
```

**可能原因：**
- 端口被其他程序占用
- 配置文件格式错误
- 权限问题

#### 2. 无法连接

**检查步骤：**
```bash
# 检查服务状态
sudo systemctl status python-mtproxy

# 检查防火墙
sudo ufw status
sudo firewall-cmd --list-ports

# 测试端口连通性
telnet 你的服务器IP 8443
```

**可能原因：**
- 防火墙阻止连接
- 服务器提供商端口限制
- 服务未正常运行

#### 3. 连接不稳定

**优化建议：**
```bash
# 进入管理面板调整参数
mtproxy
# 选择 "12) 性能优化"

# 或编辑配置文件
sudo nano /opt/python-mtproxy/config/mtproxy.conf
```

**调整参数：**
- 增加 `max_connections`
- 调整 `workers` 数量
- 修改 `timeout` 时间

### 获取帮助

1. **运行系统检查**
   ```bash
   ./scripts/validate.sh
   ```

2. **查看详细日志**
   ```bash
   sudo journalctl -u python-mtproxy -f
   ```

3. **检查网络连通性**
   ```bash
   ./scripts/connection.sh test
   ```

## 🔄 维护和更新

### 定期维护

```bash
# 每周执行系统检查
./scripts/validate.sh

# 每月清理日志（如果需要）
sudo journalctl --vacuum-time=30d

# 检查更新
mtproxy
# 选择 "13) 更新程序"
```

### 备份配置

```bash
# 备份配置文件
sudo cp /opt/python-mtproxy/config/mtproxy.conf ~/mtproxy_backup.conf

# 或使用管理面板
mtproxy
# 选择 "18) 备份还原"
```

### 完全卸载

```bash
# 使用卸载脚本
sudo ./scripts/uninstall.sh

# 或使用管理面板
mtproxy
# 选择 "14) 卸载程序"
```

## 💡 最佳实践

### 安全建议

1. **定期更换密钥**
   ```bash
   mtproxy
   # 选择 "8) 更换密钥"
   ```

2. **使用推荐端口**
   - 443（HTTPS端口，推荐）
   - 8443（常用代理端口）

3. **监控服务状态**
   ```bash
   # 设置定期检查
   echo "0 */6 * * * /opt/python-mtproxy/scripts/validate.sh" | sudo crontab -
   ```

### 性能优化

1. **根据服务器配置调整参数**
   - 1核2G：max_connections=500, workers=2
   - 2核4G：max_connections=1000, workers=4
   - 4核8G+：max_connections=2000, workers=8

2. **监控资源使用**
   ```bash
   ./scripts/validate.sh
   ```

3. **定期重启服务**
   ```bash
   # 每周重启一次（可选）
   echo "0 3 * * 0 systemctl restart python-mtproxy" | sudo crontab -
   ```

## 📞 技术支持

如果遇到问题，请按以下顺序排查：

1. 🔍 **自助诊断**：运行 `./scripts/validate.sh`
2. 📋 **查看日志**：运行 `sudo journalctl -u python-mtproxy -f`
3. 📖 **阅读文档**：查看 README.md 和本使用指南
4. 🐛 **报告问题**：在GitHub提交Issue，附带诊断信息

**问题报告模板：**
```
**系统信息：**
- 操作系统：Ubuntu 20.04 / CentOS 8 / 其他
- 服务器配置：CPU核数、内存大小
- 网络环境：VPS提供商、地区

**问题描述：**
- 具体症状
- 错误信息
- 复现步骤

**诊断信息：**
```bash
./scripts/validate.sh
sudo systemctl status python-mtproxy
sudo journalctl -u python-mtproxy -n 20
```
```

记住：大多数问题都可以通过系统验证工具和日志分析快速解决！
