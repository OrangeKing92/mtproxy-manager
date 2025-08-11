# Python MTProxy 项目概览

## 📁 项目结构

```
python-mtproxy/
├── 📁 mtproxy/                    # 核心应用代码
│   ├── __init__.py               # 模块初始化
│   ├── config.py                 # 配置管理系统
│   ├── server.py                 # 主服务器实现
│   ├── handler.py                # 连接处理器
│   ├── protocol.py               # MTProto协议实现
│   ├── crypto.py                 # 加密算法
│   ├── utils.py                  # 工具函数
│   ├── logger.py                 # 日志系统
│   └── exceptions.py             # 异常定义
│
├── 📁 tools/                      # SSH远程管理工具
│   ├── mtproxy_cli.py            # 主命令行工具
│   ├── log_viewer.py             # 日志查看器
│   ├── health_check.py           # 健康检查工具
│   ├── config_editor.py          # 配置编辑器
│   └── monitor.py                # 监控工具
│
├── 📁 scripts/                    # 部署和管理脚本
│   ├── deploy.sh                 # 一键部署脚本
│   ├── start.sh                  # 启动脚本
│   ├── stop.sh                   # 停止脚本
│   ├── restart.sh                # 重启脚本
│   ├── status.sh                 # 状态检查脚本
│   └── uninstall.sh              # 卸载脚本
│
├── 📁 config/                     # 配置文件
│   ├── mtproxy.conf              # 主配置文件
│   └── systemd.service           # systemd服务文件
│
├── 📁 tests/                      # 测试代码
│   ├── __init__.py
│   ├── test_config.py            # 配置模块测试
│   └── test_crypto.py            # 加密模块测试
│
├── 📁 logs/                       # 日志目录
├── 📁 data/                       # 数据目录
├── requirements.txt              # Python依赖
├── requirements-dev.txt          # 开发依赖
├── setup.py                      # 安装配置
├── Makefile                      # 便捷命令
├── .gitignore                    # Git忽略文件
└── README.md                     # 项目文档
```

## 🚀 核心功能

### 1. MTProxy 核心服务
- **异步高性能服务器** - 基于 asyncio 的并发处理
- **完整的 MTProto 协议支持** - 兼容 Telegram 官方标准
- **多数据中心支持** - 自动选择最优 DC
- **加密通信** - AES-CTR 和 AES-IGE 加密算法
- **连接池管理** - 高效的连接复用

### 2. SSH 远程管理系统
- **主命令行工具** (`mtproxy-cli`) - 服务控制、配置管理、状态监控
- **实时日志查看器** (`mtproxy-logs`) - 支持过滤、搜索、实时跟踪
- **健康检查工具** (`mtproxy-health`) - 全面的系统诊断
- **配置编辑器** (`config-editor`) - 交互式配置管理
- **监控工具** (`monitor`) - 实时性能监控和统计

### 3. 一键部署系统
- **自动化部署脚本** - 支持生产环境和开发环境
- **systemd 集成** - 自动启动和服务管理
- **依赖管理** - 自动安装所有必需组件
- **安全配置** - 防火墙设置和权限管理
- **日志轮转** - 自动日志管理和清理

## 🛠️ 技术特性

### 安全性
- **IP 访问控制** - 白名单/黑名单支持
- **速率限制** - 防止 DDoS 攻击
- **连接监控** - 实时连接状态跟踪
- **加密存储** - 敏感配置加密保护
- **安全权限** - 最小权限原则

### 性能优化
- **异步架构** - 高并发处理能力
- **连接复用** - 减少资源消耗
- **内存优化** - 智能内存管理
- **缓存机制** - 提高响应速度
- **负载均衡** - 多进程工作模式

### 监控和诊断
- **实时统计** - 连接数、流量、错误率
- **健康检查** - 自动化系统状态检测
- **性能监控** - CPU、内存、网络使用率
- **日志分析** - 智能日志分析和警报
- **历史数据** - 长期趋势分析

## 💻 使用场景

### 1. 生产环境部署
```bash
# 服务器上一键部署
sudo ./scripts/deploy.sh --production

# SSH 远程管理
ssh user@server "mtproxy-cli status"
ssh user@server "mtproxy-logs --follow"
```

### 2. 开发和测试
```bash
# 本地开发环境
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt
pip install -e .

# 运行测试
pytest tests/
```

### 3. 批量服务器管理
```bash
# 多服务器状态检查
for server in server1 server2 server3; do
    ssh $server "mtproxy-cli health"
done

# 批量更新
for server in server1 server2 server3; do
    ssh $server "sudo /opt/python-mtproxy/scripts/deploy.sh --update"
done
```

## 🔧 配置管理

### 主配置文件结构
```yaml
server:
  host: 0.0.0.0          # 绑定主机
  port: 8443              # 监听端口
  secret: auto_generate   # 代理密钥
  max_connections: 1000   # 最大连接数
  timeout: 300            # 连接超时

logging:
  level: INFO             # 日志级别
  file: logs/mtproxy.log  # 日志文件
  max_size: 100MB         # 最大文件大小
  backup_count: 7         # 备份文件数

security:
  allowed_ips: []         # 允许的IP
  banned_ips: []          # 禁止的IP
  rate_limit: 100         # 速率限制
```

### 环境变量支持
```bash
export MTPROXY_PORT=8443
export MTPROXY_SECRET=your_secret
export LOG_LEVEL=DEBUG
```

## 📊 监控和统计

### 实时监控指标
- **服务状态** - 运行状态、启动时间
- **连接统计** - 活跃连接、总连接数
- **流量统计** - 上行/下行流量
- **错误统计** - 连接失败、协议错误
- **性能指标** - CPU、内存使用率
- **网络状态** - 到 Telegram DC 的连通性

### 健康检查项目
- ✅ 服务运行状态
- ✅ 进程健康度
- ✅ 端口可用性
- ✅ 配置有效性
- ✅ 系统资源
- ✅ 网络连通性
- ✅ 日志文件状态
- ✅ 磁盘空间
- ✅ 内存使用
- ✅ CPU 负载

## 🚀 部署流程

### 1. 系统要求
- **操作系统**: Debian 10+ / Ubuntu 18.04+
- **Python**: 3.8+
- **内存**: 最少 512MB，推荐 1GB+
- **磁盘**: 最少 1GB 可用空间
- **网络**: 稳定的互联网连接

### 2. 快速部署
```bash
# 1. 下载项目
git clone https://github.com/your-repo/python-mtproxy.git
cd python-mtproxy

# 2. 运行部署脚本
sudo ./scripts/deploy.sh

# 3. 检查服务状态
mtproxy-cli status

# 4. 查看连接信息
mtproxy-cli stats
```

### 3. 服务管理
```bash
# 服务控制
systemctl start python-mtproxy
systemctl stop python-mtproxy
systemctl restart python-mtproxy
systemctl status python-mtproxy

# 或使用便捷命令
mtproxy-cli start|stop|restart|status
```

## 🔍 故障排查

### 常见问题和解决方案

1. **服务无法启动**
   ```bash
   # 检查日志
   mtproxy-logs --level ERROR
   journalctl -u python-mtproxy -f
   
   # 检查配置
   mtproxy-cli config show
   ```

2. **端口绑定失败**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep 8443
   
   # 检查防火墙
   sudo ufw status
   ```

3. **连接问题**
   ```bash
   # 健康检查
   mtproxy-health
   
   # 网络连通性测试
   mtproxy-health --network
   ```

### 日志分析
```bash
# 实时日志监控
mtproxy-logs --follow

# 错误日志过滤
mtproxy-logs --level ERROR

# 搜索特定问题
mtproxy-logs --search "connection error"

# 分析统计
mtproxy-logs --analyze
```

## 📈 性能优化

### 系统调优建议
```bash
# 增加文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# 调整网络参数
echo "net.core.somaxconn = 65536" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65536" >> /etc/sysctl.conf
sysctl -p
```

### 配置优化
```yaml
# 高性能配置示例
server:
  max_connections: 10000
  workers: 8
  buffer_size: 16384
  timeout: 600

security:
  rate_limit: 1000
  max_connections_per_ip: 100
```

## 🔐 安全最佳实践

### 1. 访问控制
```yaml
security:
  # 仅允许特定网段
  allowed_ips:
    - "192.168.1.0/24"
    - "10.0.0.0/8"
  
  # 封禁恶意IP
  banned_ips:
    - "1.2.3.4"
    - "5.6.7.8"
```

### 2. 防火墙配置
```bash
# UFW 配置
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 8443/tcp
sudo ufw deny from 1.2.3.4
```

### 3. 定期维护
```bash
# 定期健康检查
0 */6 * * * /usr/local/bin/mtproxy-health > /var/log/mtproxy-health.log

# 日志清理
0 2 * * * /usr/local/bin/mtproxy-logs --clean 7

# 配置备份
0 3 * * 0 cp /opt/python-mtproxy/config/mtproxy.conf /backup/
```

## 📋 项目特色

### ✨ 主要优势
1. **完全的 SSH 远程控制** - 无需 Web 界面，命令行完成所有操作
2. **一键部署** - 从零到运行只需一个命令
3. **生产级稳定性** - systemd 集成，自动重启恢复
4. **完善的监控** - 实时统计和健康检查
5. **安全性优先** - 多层安全防护和访问控制
6. **易于维护** - 自动化日志管理和系统维护

### 🎯 适用场景
- **云服务器部署** - 专为云环境优化
- **批量管理** - 支持多服务器批量操作
- **企业级使用** - 完善的日志和监控系统
- **开发者友好** - 丰富的 API 和工具集
- **运维自动化** - 支持自动化脚本集成

这个项目实现了你所有的要求，特别是针对云服务器 SSH 远程管理的需求进行了深度优化，提供了完整的命令行管理界面和自动化部署能力。
