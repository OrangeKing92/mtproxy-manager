# MTProxy 一键部署

> 基于 [ellermister/mtproxy](https://github.com/ellermister/mtproxy) 的简化版本
> 
> **目标明确：就是要创建一个 MTProxy 代理，仅此而已。**

## 🚀 一键部署

**在您的Linux服务器上运行：**

```bash
# 方法1：直接运行（推荐）
wget -O- https://raw.githubusercontent.com/YOUR_USERNAME/MTPorxy/main/deploy.sh | sudo bash

# 方法2：下载后运行
git clone https://github.com/YOUR_USERNAME/MTPorxy.git
cd MTPorxy
sudo bash deploy.sh
```

> ⚠️ **注意**：请将上面的 `YOUR_USERNAME` 替换为您的GitHub用户名

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