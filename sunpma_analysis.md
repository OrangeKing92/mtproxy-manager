# sunpma/mtp项目分析报告

## 项目概述

[sunpma/mtp](https://github.com/sunpma/mtp) 是一个专门针对中国网络环境优化的MTProxy TLS版本，具有更强的反检测能力。

## 核心差异分析

### 1. TLS域名伪装机制

**sunpma版本的关键优势：**

```bash
# 生成TLS Secret的方式
domain_hex=$(xxd -pu <<<$domain | sed 's/0a//g')
client_secret="ee${secret}${domain_hex}"
```

**关键发现：**
- 使用 `ee` 前缀标识TLS模式
- 将域名转换为十六进制并附加到secret后
- 默认伪装域名：`azure.microsoft.com`（微软Azure，在中国有合法业务）

### 2. 与我们当前项目的差异

| 功能 | sunpma版本 | 我们的项目 | 优势 |
|------|------------|------------|------|
| **TLS伪装** | ✅ 完整实现 | ✅ 有配置但可能有问题 | sunpma更成熟 |
| **域名选择** | azure.microsoft.com | cloudflare.com | sunpma选择更安全 |
| **Secret格式** | ee+secret+domain_hex | 配置不一致 | sunpma格式标准 |
| **安装简化** | 一键脚本 | 复杂配置 | sunpma更易用 |
| **架构支持** | x86_64/ARM多架构 | 主要x86_64 | sunpma支持更广 |

### 3. 反GFW特性

**sunpma的优势：**

1. **智能架构检测**：
   - x86_64：使用官方MTProxy
   - ARM等：使用mtg（更轻量的Go实现）

2. **域名验证**：
   ```bash
   http_code=$(curl -I -m 10 -o /dev/null -s -w %{http_code} $input_domain)
   if [ $http_code -eq "200" ] || [ $http_code -eq "302" ] || [ $http_code -eq "301" ]; then
   ```

3. **NAT环境支持**：
   ```bash
   nat_info=$(get_nat_ip_param)
   if [[ $nat_ip != $public_ip ]]; then
       nat_info="--nat-info ${nat_ip}:${public_ip}"
   fi
   ```

## 问题诊断

**您的连接失败可能原因：**

1. **Secret格式不正确**：
   - 当前配置有两个不同secret
   - TLS secret应该是 `ee+secret+domain_hex` 格式

2. **域名选择问题**：
   - `cloudflare.com` 可能在某些地区有检测
   - `azure.microsoft.com` 更安全

3. **MTProxy版本差异**：
   - sunpma使用的是优化版本
   - 对GFW有更好的对抗能力

## 建议的解决方案

### 方案1：直接使用sunpma版本（推荐）

在您的服务器上重新部署sunpma版本：

```bash
# 卸载当前版本
systemctl stop mtproxy
rm -rf /opt/python-mtproxy

# 安装sunpma版本
mkdir /home/mtproxy && cd /home/mtproxy
curl -s -o mtproxy.sh https://raw.githubusercontent.com/sunpma/mtp/master/mtproxy.sh
chmod +x mtproxy.sh
bash mtproxy.sh
```

### 方案2：修复当前项目

基于sunpma的实现修复我们的项目：

1. **统一Secret配置**
2. **修改伪装域名为azure.microsoft.com**
3. **添加NAT支持**
4. **使用正确的TLS Secret格式**

## sunpma版本的优势总结

1. **专门针对中国网络环境优化**
2. **更好的反检测能力**
3. **简化的部署流程**
4. **成熟的TLS伪装实现**
5. **多架构支持**

建议先尝试sunpma版本，这很可能直接解决您的连接问题。
