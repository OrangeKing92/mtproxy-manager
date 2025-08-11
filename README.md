# MTProxy - 一键部署 Telegram 代理

简单易用的 MTProxy 代理服务器，支持一键安装和图形化管理。

## 🚀 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

安装完成后会显示连接信息，使用 `mtproxy` 命令打开管理面板。

## 🎛️ 管理面板

```bash
mtproxy
```

管理面板功能：
- **服务管理**: 启动/停止/重启服务、查看状态和日志
- **配置管理**: 修改端口、更换密钥、查看连接信息、生成二维码
- **系统管理**: 更新程序、卸载程序、系统信息、防火墙设置

## 📝 常用命令

```bash
# 安装
bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)

# 管理面板
mtproxy

# 服务控制
systemctl start python-mtproxy    # 启动
systemctl stop python-mtproxy     # 停止
systemctl restart python-mtproxy  # 重启
systemctl status python-mtproxy   # 状态

# 查看日志
journalctl -u python-mtproxy -f
```

## 🔧 快速操作

**查看连接信息**
```bash
mtproxy  # 选择 "10) 连接信息"
```

**生成二维码**
```bash
mtproxy  # 选择 "11) 生成二维码"
```

**修改端口**
```bash
mtproxy  # 选择 "7) 修改端口"
```

## 📁 配置文件

主配置: `/opt/python-mtproxy/config/mtproxy.conf`

## 🗑️ 卸载

```bash
mtproxy  # 选择 "14) 卸载程序"
```

---

**支持系统**: Ubuntu/Debian/CentOS  
**默认端口**: 8443  
**安装目录**: /opt/python-mtproxy