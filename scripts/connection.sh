#!/bin/bash

# MTProxy 连接信息生成脚本
# 用于生成连接信息、二维码和分享链接

set -e

# 配置
INSTALL_DIR="/opt/python-mtproxy"
CONFIG_FILE="$INSTALL_DIR/config/mtproxy.conf"
SERVICE_NAME="python-mtproxy"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 输出函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 获取配置信息
get_config_info() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
    
    # 解析嵌套的YAML配置，查找server节点下的配置
    local host=$(grep -A 20 "^server:" "$CONFIG_FILE" | grep "^\s*host:" | head -1 | cut -d: -f2 | tr -d ' ')
    local port=$(grep -A 20 "^server:" "$CONFIG_FILE" | grep "^\s*port:" | head -1 | cut -d: -f2 | tr -d ' ')
    local secret=$(grep -A 20 "^server:" "$CONFIG_FILE" | grep "^\s*secret:" | head -1 | cut -d: -f2 | tr -d ' ')
    
    # 如果找不到，尝试使用yq或python来解析YAML（如果可用）
    if [[ -z "$port" || -z "$secret" ]]; then
        if command -v yq >/dev/null 2>&1; then
            host=$(yq eval '.server.host' "$CONFIG_FILE" 2>/dev/null || echo "")
            port=$(yq eval '.server.port' "$CONFIG_FILE" 2>/dev/null || echo "")
            secret=$(yq eval '.server.secret' "$CONFIG_FILE" 2>/dev/null || echo "")
        elif command -v python3 >/dev/null 2>&1; then
            local yaml_result=$(python3 -c "
import yaml, sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = yaml.safe_load(f)
    server = config.get('server', {})
    host = server.get('host', '')
    port = server.get('port', '')
    secret = server.get('secret', '')
    print(f'{host}|{port}|{secret}')
except Exception as e:
    print('||')
" 2>/dev/null)
            if [[ "$yaml_result" != "||" ]]; then
                host=$(echo "$yaml_result" | cut -d'|' -f1)
                port=$(echo "$yaml_result" | cut -d'|' -f2) 
                secret=$(echo "$yaml_result" | cut -d'|' -f3)
            fi
        fi
    fi
    
    if [[ -z "$port" || -z "$secret" ]]; then
        print_error "配置文件中缺少必要信息"
        print_error "无法解析YAML配置文件，请检查配置格式"
        exit 1
    fi
    
    echo "$host|$port|$secret"
}

# 获取公网IP
get_public_ip() {
    local ip=""
    
    # 尝试多种方法获取公网IP
    for url in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ident.me" "whatismyip.akamai.com"; do
        ip=$(curl -s --connect-timeout 5 "$url" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
        if [[ -n "$ip" ]]; then
            break
        fi
    done
    
    # 如果还是获取不到，尝试备用方法
    if [[ -z "$ip" ]]; then
        ip=$(wget -qO- --timeout=5 ifconfig.me 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    fi
    
    if [[ -z "$ip" ]]; then
        print_warning "无法自动获取公网IP地址"
        read -p "请手动输入服务器公网IP: " ip
        
        # 验证IP格式
        if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            print_error "IP地址格式无效"
            exit 1
        fi
    fi
    
    echo "$ip"
}

# 验证服务器连通性
check_server_connectivity() {
    local server_ip=$1
    local port=$2
    
    print_info "检查服务器连通性..."
    
    # 检查端口是否开放
    if timeout 5 bash -c "</dev/tcp/$server_ip/$port" 2>/dev/null; then
        print_success "服务器 $server_ip:$port 连通正常"
        return 0
    else
        print_warning "服务器 $server_ip:$port 可能无法访问"
        print_warning "请检查防火墙设置和服务状态"
        return 1
    fi
}

# 生成Telegram代理链接
generate_telegram_link() {
    local server_ip=$1
    local port=$2
    local secret=$3
    
    echo "tg://proxy?server=$server_ip&port=$port&secret=$secret"
}

# 生成HTTP代理链接
generate_http_link() {
    local server_ip=$1
    local port=$2
    local secret=$3
    
    echo "https://t.me/proxy?server=$server_ip&port=$port&secret=$secret"
}

# 生成二维码
generate_qr_code() {
    local link=$1
    local output_file=$2
    
    if command -v qrencode >/dev/null; then
        if [[ -n "$output_file" ]]; then
            # 生成PNG格式二维码
            qrencode -t PNG -s 8 -m 2 -o "$output_file" "$link"
            print_success "二维码已保存到: $output_file"
        else
            # 在终端显示二维码
            echo ""
            print_info "二维码:"
            qrencode -t ANSI -m 2 "$link"
            echo ""
        fi
        return 0
    else
        print_warning "qrencode未安装，无法生成二维码"
        print_info "安装命令:"
        print_info "Ubuntu/Debian: apt install qrencode"
        print_info "CentOS/RHEL: yum install qrencode"
        print_info "Alpine: apk add qrencode"
        return 1
    fi
}

# 生成配置文档
generate_config_doc() {
    local server_ip=$1
    local port=$2
    local secret=$3
    local output_file=$4
    
    local telegram_link=$(generate_telegram_link "$server_ip" "$port" "$secret")
    local http_link=$(generate_http_link "$server_ip" "$port" "$secret")
    
    cat > "$output_file" << EOF
# MTProxy 连接配置

## 基本信息
- 服务器IP: $server_ip
- 端口: $port
- 密钥: $secret
- 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

## 连接方式

### 1. 直接链接 (推荐)
点击以下链接直接添加到Telegram:
$telegram_link

### 2. 网页链接
$http_link

### 3. 手动配置
在Telegram中手动添加代理:
1. 打开Telegram设置
2. 选择 "数据和存储"
3. 选择 "代理设置"
4. 点击 "添加代理"
5. 选择 "MTProto"
6. 填入以下信息:
   - 服务器: $server_ip
   - 端口: $port
   - 密钥: $secret

## 使用说明
1. 添加代理后，Telegram会自动连接
2. 连接成功后，状态栏会显示代理图标
3. 如果连接失败，请检查网络和防火墙设置

## 故障排除
- 确保服务器防火墙开放了端口 $port
- 检查服务器上MTProxy服务是否正常运行
- 验证网络环境是否支持代理连接

## 服务器状态检查
使用以下命令检查服务状态:
\`\`\`bash
systemctl status python-mtproxy
netstat -tlnp | grep $port
\`\`\`

---
生成工具: MTProxy Connection Generator v2.0
EOF

    print_success "配置文档已保存到: $output_file"
}

# 显示连接信息
show_connection_info() {
    local server_ip=$1
    local port=$2
    local secret=$3
    
    local telegram_link=$(generate_telegram_link "$server_ip" "$port" "$secret")
    local http_link=$(generate_http_link "$server_ip" "$port" "$secret")
    
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    MTProxy 连接信息                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    echo -e "${WHITE}📍 服务器信息${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "服务器地址: ${GREEN}$server_ip${NC}"
    echo -e "端口号: ${GREEN}$port${NC}"
    echo -e "连接密钥: ${GREEN}$secret${NC}"
    echo ""
    
    echo -e "${WHITE}🔗 连接链接${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Telegram链接:${NC}"
    echo "$telegram_link"
    echo ""
    echo -e "${CYAN}网页链接:${NC}"
    echo "$http_link"
    echo ""
    
    echo -e "${WHITE}📱 手动配置参数${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "代理类型: MTProto"
    echo "服务器: $server_ip"
    echo "端口: $port"
    echo "密钥: $secret"
    echo ""
    
    echo -e "${WHITE}💡 使用说明${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 复制上面的Telegram链接并在Telegram中打开"
    echo "2. 或者在Telegram设置中手动添加MTProto代理"
    echo "3. 填入上述服务器信息即可使用"
    echo ""
}

# 批量生成多种格式
batch_generate() {
    local server_ip=$1
    local port=$2
    local secret=$3
    local output_dir=$4
    
    if [[ -z "$output_dir" ]]; then
        output_dir="./mtproxy_info_$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$output_dir"
    
    print_info "正在生成多种格式的连接信息..."
    
    # 生成文本文档
    generate_config_doc "$server_ip" "$port" "$secret" "$output_dir/connection_info.txt"
    
    # 生成Markdown文档
    local telegram_link=$(generate_telegram_link "$server_ip" "$port" "$secret")
    cat > "$output_dir/README.md" << EOF
# MTProxy 连接配置

## 快速连接
点击链接直接添加: [$server_ip:$port]($telegram_link)

## 配置信息
| 项目 | 值 |
|------|-----|
| 服务器 | \`$server_ip\` |
| 端口 | \`$port\` |
| 密钥 | \`$secret\` |

## 连接链接
\`\`\`
$telegram_link
\`\`\`

生成时间: $(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # 生成JSON格式
    cat > "$output_dir/config.json" << EOF
{
  "server": "$server_ip",
  "port": $port,
  "secret": "$secret",
  "telegram_link": "$telegram_link",
  "generated_at": "$(date -Iseconds)"
}
EOF
    
    # 生成二维码
    if command -v qrencode >/dev/null; then
        qrencode -t PNG -s 8 -m 2 -o "$output_dir/qr_code.png" "$telegram_link"
        qrencode -t SVG -s 8 -m 2 -o "$output_dir/qr_code.svg" "$telegram_link"
        print_success "二维码已生成"
    fi
    
    # 生成分享脚本
    cat > "$output_dir/share.sh" << 'EOF'
#!/bin/bash
# MTProxy 分享脚本

config_file="config.json"
if [[ -f "$config_file" ]]; then
    server=$(grep '"server"' "$config_file" | cut -d'"' -f4)
    port=$(grep '"port"' "$config_file" | cut -d':' -f2 | tr -d ' ,')
    link=$(grep '"telegram_link"' "$config_file" | cut -d'"' -f4)
    
    echo "MTProxy 代理分享"
    echo "服务器: $server:$port"
    echo "连接链接: $link"
    
    if command -v qrencode >/dev/null && [[ -f "qr_code.png" ]]; then
        echo "二维码文件: qr_code.png"
    fi
else
    echo "配置文件不存在"
fi
EOF
    chmod +x "$output_dir/share.sh"
    
    print_success "所有文件已生成到目录: $output_dir"
    echo ""
    echo "生成的文件:"
    ls -la "$output_dir/"
}

# 主菜单
show_menu() {
    echo -e "${WHITE}"
    echo "┌─ 连接信息管理 ─────────────────────────────────────────────┐"
    echo "│ 1) 显示连接信息        2) 生成二维码         3) 保存配置    │"
    echo "│ 4) 批量生成文件        5) 连通性测试         6) 分享链接    │"
    echo "├─ 高级功能 ─────────────────────────────────────────────────┤"
    echo "│ 7) 自定义服务器IP      8) 生成多个配置       9) 导出配置    │"
    echo "│ 10) 生成安装脚本       11) 服务器状态        12) 帮助信息   │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo "│ 0) 退出程序                                                 │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

# 主程序
main() {
    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "MTProxy配置文件不存在，请先安装MTProxy"
        exit 1
    fi
    
    # 获取配置信息
    local config_info=$(get_config_info)
    local host=$(echo "$config_info" | cut -d'|' -f1)
    local port=$(echo "$config_info" | cut -d'|' -f2)
    local secret=$(echo "$config_info" | cut -d'|' -f3)
    
    # 如果没有命令行参数，显示交互菜单
    if [[ $# -eq 0 ]]; then
        while true; do
            echo -e "${CYAN}"
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║                  MTProxy 连接信息管理器                       ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo -e "${NC}"
            
            show_menu
            read -p "请选择操作 [0-12]: " choice
            echo ""
            
            case $choice in
                1)
                    local server_ip=$(get_public_ip)
                    show_connection_info "$server_ip" "$port" "$secret"
                    ;;
                2)
                    local server_ip=$(get_public_ip)
                    local telegram_link=$(generate_telegram_link "$server_ip" "$port" "$secret")
                    generate_qr_code "$telegram_link"
                    ;;
                3)
                    local server_ip=$(get_public_ip)
                    read -p "输入保存路径 (默认: ./mtproxy_config.txt): " output_file
                    output_file=${output_file:-./mtproxy_config.txt}
                    generate_config_doc "$server_ip" "$port" "$secret" "$output_file"
                    ;;
                4)
                    local server_ip=$(get_public_ip)
                    read -p "输入输出目录 (默认: 自动生成): " output_dir
                    batch_generate "$server_ip" "$port" "$secret" "$output_dir"
                    ;;
                5)
                    local server_ip=$(get_public_ip)
                    check_server_connectivity "$server_ip" "$port"
                    ;;
                6)
                    local server_ip=$(get_public_ip)
                    local telegram_link=$(generate_telegram_link "$server_ip" "$port" "$secret")
                    echo -e "${CYAN}分享链接:${NC}"
                    echo "$telegram_link"
                    echo ""
                    if command -v xclip >/dev/null; then
                        echo "$telegram_link" | xclip -selection clipboard
                        print_success "链接已复制到剪贴板"
                    elif command -v pbcopy >/dev/null; then
                        echo "$telegram_link" | pbcopy
                        print_success "链接已复制到剪贴板"
                    fi
                    ;;
                0)
                    print_info "感谢使用MTProxy连接信息管理器!"
                    exit 0
                    ;;
                *)
                    print_error "无效选择，请输入0-12"
                    ;;
            esac
            
            echo ""
            read -p "按回车键继续..." -r
        done
    fi
    
    # 命令行模式
    case $1 in
        "info"|"show")
            local server_ip=$(get_public_ip)
            show_connection_info "$server_ip" "$port" "$secret"
            ;;
        "qr"|"qrcode")
            local server_ip=$(get_public_ip)
            local telegram_link=$(generate_telegram_link "$server_ip" "$port" "$secret")
            generate_qr_code "$telegram_link" "$2"
            ;;
        "link")
            local server_ip=$(get_public_ip)
            local telegram_link=$(generate_telegram_link "$server_ip" "$port" "$secret")
            echo "$telegram_link"
            ;;
        "test"|"check")
            local server_ip=$(get_public_ip)
            check_server_connectivity "$server_ip" "$port"
            ;;
        "batch")
            local server_ip=$(get_public_ip)
            batch_generate "$server_ip" "$port" "$secret" "$2"
            ;;
        "help"|*)
            echo "MTProxy 连接信息生成器"
            echo ""
            echo "用法: $0 [命令] [选项]"
            echo ""
            echo "命令:"
            echo "  info/show          显示连接信息"
            echo "  qr/qrcode [文件]   生成二维码"
            echo "  link               输出连接链接"
            echo "  test/check         测试连通性"
            echo "  batch [目录]       批量生成文件"
            echo "  help               显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 info                    # 显示连接信息"
            echo "  $0 qr qr.png              # 生成二维码到文件"
            echo "  $0 link                   # 仅输出连接链接"
            echo "  $0 batch /tmp/mtproxy     # 批量生成到指定目录"
            ;;
    esac
}

# 检查是否为root用户（某些功能需要）
if [[ $EUID -eq 0 ]] && [[ $1 != "link" && $1 != "help" ]]; then
    print_warning "建议使用普通用户运行此脚本"
fi

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
