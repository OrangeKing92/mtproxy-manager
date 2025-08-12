# MTProxy 一键部署

> 基于 [ellermister/mtproxy](https://github.com/ellermister/mtproxy) 的简化版本
> 
> **目标明确：就是要创建一个 MTProxy 代理，仅此而已。**

## 🚀 部署方式

### 方式1：交互式部署（推荐）

提供友好的用户界面，支持自定义配置：

```bash
# 推荐方式：下载后运行
wget -O deploy.sh https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/deploy.sh
sudo bash deploy.sh

# 或者克隆仓库
git clone https://github.com/OrangeKing92/mtproxy-manager.git
cd mtproxy-manager
sudo bash deploy.sh
```

> ⚠️ **注意**：交互式部署不支持管道执行（`wget -O- | bash`），请先下载脚本再运行。

**特点：**
- 🎨 美观的彩色界面
- 📊 系统信息检测
- 💡 智能推荐配置
- ⚡ 进度条显示
- 🛡️ 输入验证

### 方式2：快速部署

适用于自动化场景，使用预设配置：

```bash
# 直接运行
wget -O- https://raw.githubusercontent.com/OrangeKing92/mtproxy-manager/main/quick_deploy.sh | sudo bash

# 或下载后运行
git clone https://github.com/OrangeKing92/mtproxy-manager.git
cd mtproxy-manager
sudo bash quick_deploy.sh
```

**默认配置：**
- 端口：443
- 管理端口：8888
- 伪装域名：azure.microsoft.com
- 版本：9seconds (兼容性强)

## 📋 管理命令

**部署完成后，在服务器上使用以下命令管理MTProxy：**

```bash
# 启动服务
bash mtproxy_manage.sh start

# 停止服务
bash mtproxy_manage.sh stop

# 重启服务
bash mtproxy_manage.sh restart

# 查看状态
bash mtproxy_manage.sh status

# 查看日志
bash mtproxy_manage.sh log

# 显示代理链接（重要！）
bash mtproxy_manage.sh links

# 卸载服务
bash mtproxy_manage.sh uninstall
```

> 💡 **提示**：部署成功后，一定要运行 `bash mtproxy_manage.sh links` 获取代理链接！

## 📁 文件说明

- `deploy.sh` - 一键部署脚本
- `mtproxy_manage.sh` - 管理脚本
- `mtproxy_core.sh` - 核心脚本（来自ellermister）

## ⚡ 特点

- **极简设计** - 只做一件事：部署MTProxy
- **一键操作** - 部署和管理都是一条命令
- **基于成熟方案** - 使用经过验证的ellermister脚本
- **无过度设计** - 删除了所有不必要的功能

## 📝 许可证

本项目基于 ellermister/mtproxy 项目，请遵循其许可证要求。