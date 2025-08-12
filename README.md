# MTProxy Manager

Python实现的Telegram MTProxy代理服务器，具有完整的交互式安装和管理界面。

## ✨ 特性

- 🔧 **一键安装** - 全自动化部署，参考 [sunpma/mtp](https://github.com/sunpma/mtp.git) 的用户体验
- 🎛️ **交互式配置** - 简单易用的配置向导，智能端口检测
- 🌐 **Web管理** - 完整的Web管理界面
- 🔒 **安全可靠** - TLS支持，自动密钥生成
- ⚡ **高性能** - 异步架构，支持高并发

## 🚀 快速安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/install.sh)
```

## 🎮 安装演示

安装脚本包含完整的交互式配置向导：

### 1. 美观的启动界面
```
    __  __  _______  _____                       
   |  \/  ||__   __|  __ \                      
   | \  / |   | |  | |__) |_ __   ___  __  __  _   _ 
   | |\/| |   | |  |  ___/| '__| / _ \ \\\/  || | | |
   | |  | |   | |  | |    | |   | (_) |>  <| |_| |
   |_|  |_|   |_|  |_|    |_|   \___//_/\_\____/

      Telegram MTProxy Manager v3.1
      https://github.com/OrangeKing92/mtproxy-manager
```

### 2. 服务器信息检测
- 自动获取服务器IP地址
- 检测系统版本和架构
- 显示内存配置

### 3. 交互式配置向导
- **端口配置**: 智能检测端口冲突
- **域名选择**: 4种预设选项 + 自定义
- **密码验证**: 最小长度要求
- **配置确认**: 完整信息预览

### 4. 完整的连接信息
安装完成后显示：
- 📱 Telegram连接链接
- 🔧 Web管理面板地址
- 📖 常用管理命令

## 📱 使用方法

### 管理命令
```bash
mtproxy          # 打开管理面板
mtproxy status   # 查看运行状态
mtproxy restart  # 重启服务
mtproxy logs     # 查看运行日志
mtproxy stop     # 停止服务
```

### 系统服务
```bash
systemctl status python-mtproxy    # 查看状态
systemctl restart python-mtproxy   # 重启服务
journalctl -u python-mtproxy -f    # 查看日志
```

## 🔧 系统要求

- **操作系统**: Ubuntu 18.04+, Debian 10+, CentOS 7+
- **Python**: 3.8+
- **权限**: root用户
- **网络**: 外网访问权限

## 📋 更新日志

### v3.1 (当前版本)
- ✅ 修复git clone目录冲突错误
- ✅ 集成交互式配置功能
- ✅ 美化界面设计和用户体验
- ✅ 智能端口冲突检测
- ✅ 参考sunpma/mtp项目的优秀设计

### v3.0
- 初始Python实现
- 基础的一键安装功能
- Systemd服务支持

## 🤝 致谢

本项目在交互式安装体验方面参考了 [sunpma/mtp](https://github.com/sunpma/mtp.git) 项目的优秀设计。

## 📄 许可证

MIT License