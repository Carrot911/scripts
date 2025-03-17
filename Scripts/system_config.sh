#!/bin/bash

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# 检查并安装必要的工具
check_and_install_tools() {
    # 检查并安装必要的工具
    for tool in curl jq; do
        if ! command -v $tool &> /dev/null; then
            echo "正在安装 $tool..."
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y $tool
            elif command -v yum &> /dev/null; then
                sudo yum install -y $tool
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y $tool
            elif command -v pacman &> /dev/null; then
                sudo pacman -Sy --noconfirm $tool
            fi
        fi
    done
}

# 系统信息查询函数
get_system_info() {
    # 检查并安装必要的工具
    check_and_install_tools
    # 主机名
    local hostname=$(uname -n)
    
    # 系统版本
    local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')
    
    # Linux版本
    local kernel_version=$(uname -r)
    
    # CPU信息
    local cpu_arch=$(uname -m)
    local cpu_info=$(lscpu | awk -F': +' '/Model name:/ {print $2; exit}')
    local cpu_cores=$(nproc)
    local cpu_freq=$(cat /proc/cpuinfo | grep "MHz" | head -n 1 | awk '{printf "%.1f GHz\n", $4/1000}')
    
    # CPU使用率
    local cpu_usage_percent=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.0f\n", (($2+$4-u1) * 100 / (t-t1))}' \
        <(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat))
    
    # 系统负载
    local load=$(uptime | awk '{print $(NF-2), $(NF-1), $NF}')
    
    # 内存信息
    local mem_info=$(free -m | awk 'NR==2{if($2>=1024) printf "%.2f/%.2f GB (%.2f%%)", $3/1024, $2/1024, $3*100/$2; else printf "%.2f/%.2f MB (%.2f%%)", $3, $2, $3*100/$2}')
    local swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; if(total>=1024) printf "%.2fGB/%.2fGB (%.0f%%)", used/1024, total/1024, percentage; else printf "%.0fMB/%.0fMB (%.0f%%)", used, total, percentage}')
    
    # 硬盘使用情况
    local disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')
    
    # 网络信息
    local received="N/A"
    local sent="N/A"
    if command -v ip &> /dev/null; then
        # 使用 ip 命令获取网络统计信息
        local interface=$(ip route | grep default | awk '{print $5}')
        if [ -n "$interface" ]; then
            received=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null | awk '{printf "%.2f MB", $1/1024/1024}' || echo "N/A")
            sent=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null | awk '{printf "%.2f MB", $1/1024/1024}' || echo "N/A")
        fi
    fi
    
    # 网络算法
    local congestion_algorithm="N/A"
    if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
        congestion_algorithm=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "N/A")
    fi
    
    # 运营商和IP信息
    local ipv4_address="N/A"
    local isp_info="N/A"
    local location="N/A"
    
    # 尝试多个API获取IP地址
    for api in "https://api.ipify.org" "https://ifconfig.me/ip" "https://icanhazip.com"; do
        ipv4_address=$(curl -s $api 2>/dev/null)
        if [ -n "$ipv4_address" ] && [[ $ipv4_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
    done

    if [ "$ipv4_address" != "N/A" ]; then
        # 尝试多个API获取ISP和位置信息
        for api in "https://ipapi.co/$ipv4_address/json/" "https://ipinfo.io/$ipv4_address/json" "https://ip-api.com/json/$ipv4_address"; do
            local ipinfo=$(curl -s $api 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$ipinfo" ]; then
                case $api in
                    *ipapi.co*)
                        isp_info=$(echo "$ipinfo" | jq -r '.org' 2>/dev/null || echo "N/A")
                        location=$(echo "$ipinfo" | jq -r '.country_name + ", " + .region + ", " + .city' 2>/dev/null || echo "N/A")
                        ;;
                    *ipinfo.io*)
                        isp_info=$(echo "$ipinfo" | jq -r '.org' 2>/dev/null || echo "N/A")
                        location=$(echo "$ipinfo" | jq -r '.country + ", " + .region + ", " + .city' 2>/dev/null || echo "N/A")
                        ;;
                    *ip-api.com*)
                        isp_info=$(echo "$ipinfo" | jq -r '.isp' 2>/dev/null || echo "N/A")
                        location=$(echo "$ipinfo" | jq -r '.country + ", " + .regionName + ", " + .city' 2>/dev/null || echo "N/A")
                        ;;
                esac
                [ "$isp_info" != "null" ] && [ "$location" != "null" ] && break
            fi
        done
    fi

    # 网络拥塞控制算法
    local congestion_algorithm="N/A"
    if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
        congestion_algorithm=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "N/A")
    fi
    
    # DNS地址
    local dns_addresses=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | tr '\n' ' ' || echo "N/A")
    
    # 系统时间
    local current_time=$(date "+%Y-%m-%d %I:%M %p")
    
    # 运行时长
    local uptime_info=$(uptime -p | sed 's/up //')

    # 用户信息
    local current_user=$(whoami)
    # 获取用户组并添加权限说明
    local user_groups_raw=$(groups)
    local user_groups=""
    for group in $user_groups_raw; do
        case $group in
            "root")
                user_groups+="$group (系统管理员组，拥有最高权限)\n"
                ;;
            "sudo")
                user_groups+="$group (可使用sudo命令的用户组)\n"
                ;;
            "adm")
                user_groups+="$group (系统监控和日志访问组)\n"
                ;;
            "wheel")
                user_groups+="$group (系统管理组，类似sudo组)\n"
                ;;
            "docker")
                user_groups+="$group (可以使用Docker的用户组)\n"
                ;;
            "www-data")
                user_groups+="$group (Web服务器用户组)\n"
                ;;
            "video")
                user_groups+="$group (视频设备访问组)\n"
                ;;
            "audio")
                user_groups+="$group (音频设备访问组)\n"
                ;;
            "plugdev")
                user_groups+="$group (可移动设备访问组)\n"
                ;;
            *)
                user_groups+="$group (普通用户组)\n"
                ;;
        esac
    done
    local last_login=$(last -1 $current_user 2>/dev/null | head -1 | awk '{print $4, $5, $6, $7}' || echo "暂无登录记录")
    local user_shell=$(grep "^$current_user:" /etc/passwd | cut -d: -f7 || echo "/bin/bash")
    
    # 输出信息
    echo -e "\n-------------"
    printf "${CYAN}%s${NC} %s\n" "主机名:" "$hostname"
    printf "${CYAN}%s${NC} %s\n" "系统版本:" "$os_info"
    printf "${CYAN}%s${NC} %s\n" "Linux版本:" "$kernel_version"
    echo "-------------"
    printf "${PURPLE}%s${NC} %s\n" "当前用户:" "$current_user"
    printf "${PURPLE}%s${NC}\n" "用户组:"
    echo -e "$user_groups"
    printf "${PURPLE}%s${NC} %s\n" "最近登录:" "${last_login:-暂无登录记录}"
    printf "${PURPLE}%s${NC} %s\n" "默认Shell:" "$user_shell"
    echo "-------------"
    printf "${YELLOW}%s${NC} %s\n" "CPU架构:" "$cpu_arch"
    printf "${YELLOW}%s${NC} %s\n" "CPU型号:" "$cpu_info"
    printf "${YELLOW}%s${NC} %s\n" "CPU核心数:" "$cpu_cores"
    printf "${YELLOW}%s${NC} %s\n" "CPU频率:" "$cpu_freq"
    echo "-------------"
    printf "${RED}%s${NC} %s%%\n" "CPU占用:" "$cpu_usage_percent"
    printf "${RED}%s${NC} %s\n" "物理内存:" "$mem_info"
    printf "${RED}%s${NC} %s\n" "虚拟内存:" "$swap_info"
    printf "${RED}%s${NC} %s\n" "硬盘占用:" "$disk_info"
    echo "-------------"
    printf "${GREEN}%s${NC} %s\n" "网络算法:" "$congestion_algorithm"
    echo "-------------"
    printf "${GRAY}%s${NC} %s\n" "运营商:" "$isp_info"
    printf "${GRAY}%s${NC} %s\n" "IPv4地址:" "$ipv4_address"
    printf "${GRAY}%s${NC} %s\n" "DNS地址:" "$dns_addresses"
    printf "${GRAY}%s${NC} %s\n" "地理位置:" "$location"
    printf "${GRAY}%s${NC} %s\n" "系统时间:" "$current_time"
    echo "-------------"
    printf "${CYAN}%s${NC} %s\n" "运行时长:" "$uptime_info"
    echo
}

# SSH安全配置函数
configure_ssh() {
    echo "正在配置SSH安全设置..."
    
    # 创建SSH密钥对
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    
    # 确保.ssh目录权限正确
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_rsa
    chmod 644 ~/.ssh/id_rsa.pub
    
    # 配置SSH服务
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # 修改SSH配置
    sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    
    # 将公钥添加到authorized_keys
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    
    # 复制私钥到当前目录
    cp ~/.ssh/id_rsa ./private_key
    chmod 600 ./private_key
    
    echo "请选择导出私钥的方式："
    echo "1. 复制到剪贴板"
    echo "2. 通过Web服务器下载"
    echo "3. 跳过"
    
    read -p "请选择 (1-3): " export_choice
    
    case $export_choice in
        1)
            if command -v clip.exe &> /dev/null; then
                cat ./private_key | clip.exe
                echo "私钥内容已复制到剪贴板"
            else
                echo "当前系统不支持剪贴板操作"
            fi
            ;;
        2)
            echo "启动临时Web服务器用于下载私钥文件..."
            python3 -c '
import http.server
import socketserver
import os
import time
import threading

def stop_server(httpd):
    time.sleep(60)  # 60秒后自动关闭服务器
    print("\n服务器即将关闭...")
    httpd.shutdown()

os.chdir(os.path.dirname(os.path.abspath("./private_key")))
PORT = 8000
Handler = http.server.SimpleHTTPRequestHandler
httpd = socketserver.TCPServer(("0.0.0.0", PORT), Handler)
print(f"\n私钥文件可通过以下地址下载（60秒内有效）：\nhttp://localhost:{PORT}/private_key")
threading.Thread(target=stop_server, args=(httpd,), daemon=True).start()
httpd.serve_forever()
' &
            ;;
        3)
            echo "已跳过导出"
            ;;
        *)
            echo "无效的选择"
            ;;
    esac
    
    # 重启SSH服务
    sudo systemctl restart sshd
    
    echo "SSH安全配置完成！"
    echo "请妥善保管私钥文件，并删除服务器上的副本"
}

# 按任意键返回函数
press_any_key() {
    echo -e "\n按任意键返回上一级..."
    read -n 1 -s -r
}

# 检查软件安装状态
check_software_status() {
    local software=$1
    if command -v $software &> /dev/null; then
        echo -e "${GREEN}已安装${NC}"
    else
        echo -e "${RED}未安装${NC}"
    fi
}

# 安装常用软件函数
manage_common_software() {
    while true; do
        clear
        echo "常用软件管理"
        echo "-------------"
        
        # 定义要检查的软件列表
        local software_list=("nginx" "git" "curl" "btop" "wget" "vim" "tmux" "unzip" "jq" "zsh")
        
        # 显示软件安装状态
        for ((i=0; i<${#software_list[@]}; i++)); do
            local status=$(check_software_status ${software_list[$i]})
            printf "%2d. %-15s %s\n" $((i+1)) "${software_list[$i]}" "$status"
        done
        
        echo "-------------"
        echo "a. 安装所有未安装的软件"
        echo "b. 返回上一级"
        echo "c. 卸载并清除软件残留"
        echo "-------------"
        
        read -p "请选择操作: " sub_choice
        
        case $sub_choice in
            b)
                break
                ;;
            [1-9]|10)
                local index=$((sub_choice-1))
                if [ $index -lt ${#software_list[@]} ]; then
                    local software=${software_list[$index]}
                    if ! command -v $software &> /dev/null; then
                        echo "正在安装 $software..."
                        if [ "$software" = "zsh" ]; then
                            if command -v apt &> /dev/null; then
                                sudo apt update && sudo apt install -y zsh
                            elif command -v yum &> /dev/null; then
                                sudo yum install -y zsh
                            elif command -v dnf &> /dev/null; then
                                sudo dnf install -y zsh
                            elif command -v pacman &> /dev/null; then
                                sudo pacman -Sy --noconfirm zsh
                            fi
                            # 设置 ZSH 为默认 shell
                            chsh -s $(which zsh)
                            
                            # 检查是否已安装 Oh My Zsh
                            if [ ! -d "$HOME/.oh-my-zsh" ]; then
                                echo "正在安装 Oh My Zsh..."
                                # 安装 Oh My Zsh
                                sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
                                
                                # 检查安装是否成功
                                if [ -d "$HOME/.oh-my-zsh" ]; then
                                    # 应用主题设置
                                    if [ -f "$HOME/.zshrc" ]; then
                                        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
                                        echo "ZSH 和 Oh My Zsh 安装完成，主题已设置为agnoster，请重新登录以使用新的shell"
                                    else
                                        echo "警告：未找到.zshrc文件，请手动配置Oh My Zsh主题"
                                    fi
                                else
                                    echo "警告：Oh My Zsh安装可能失败，请手动检查安装状态"
                                fi
                            else
                                echo "Oh My Zsh 已经安装"
                            fi
                        elif command -v apt &> /dev/null; then
                            sudo apt update && sudo apt install -y $software
                        elif command -v yum &> /dev/null; then
                            sudo yum install -y $software
                        elif command -v dnf &> /dev/null; then
                            sudo dnf install -y $software
                        elif command -v pacman &> /dev/null; then
                            sudo pacman -Sy --noconfirm $software
                        fi
                        echo "$software 安装完成"
                    else
                        echo "$software 已经安装"
                    fi
                fi
                ;;
            a)
                echo "正在安装所有未安装的软件..."
                for software in "${software_list[@]}"; do
                    if ! command -v $software &> /dev/null; then
                        echo "正在安装 $software..."
                        if command -v apt &> /dev/null; then
                            sudo apt update && sudo apt install -y $software
                        elif command -v yum &> /dev/null; then
                            sudo yum install -y $software
                        elif command -v dnf &> /dev/null; then
                            sudo dnf install -y $software
                        elif command -v pacman &> /dev/null; then
                            sudo pacman -Sy --noconfirm $software
                        fi
                    fi
                done
                echo "所有软件安装完成"
                ;;
            b)
                return
                ;;
            c)
                echo "请选择要卸载的软件编号（1-${#software_list[@]}）："
                read -p "输入编号: " uninstall_choice
                if [[ $uninstall_choice =~ ^[0-9]+$ ]] && [ $uninstall_choice -ge 1 ] && [ $uninstall_choice -le ${#software_list[@]} ]; then
                    local software=${software_list[$((uninstall_choice-1))]}
                    if command -v $software &> /dev/null; then
                        # 检查系统关键依赖
                        local critical_deps=("systemd" "bash" "login" "sudo" "ssh")
                        local is_critical=false
                        for dep in "${critical_deps[@]}"; do
                            if [ "$software" = "$dep" ]; then
                                is_critical=true
                                break
                            fi
                        done

                        if [ "$is_critical" = true ]; then
                            echo "警告：$software 是系统关键组件，卸载可能导致系统无法正常工作。"
                            read -p "确定要继续卸载吗？(y/N): " confirm
                            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                                echo "已取消卸载"
                                continue
                            fi
                        fi

                        # 检查软件依赖关系
                        echo "正在检查依赖关系..."
                        local dep_check=true
                        if command -v apt &> /dev/null; then
                            apt-cache rdepends $software | grep -v "$software" | grep -q "^"
                            dep_check=$?
                        elif command -v dnf &> /dev/null; then
                            dnf repoquery --installed --whatrequires $software | grep -q "."
                            dep_check=$?
                        elif command -v pacman &> /dev/null; then
                            pacman -Qi $software | grep "Required By" | grep -q "None"
                            dep_check=$?
                        fi

                        if [ $dep_check = 0 ]; then
                            echo "警告：其他软件包依赖于 $software，卸载可能影响系统功能"
                            read -p "确定要继续卸载吗？(y/N): " confirm
                            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                                echo "已取消卸载"
                                continue
                            fi
                        fi

                        echo "正在卸载 $software 及其配置文件..."
                        # 如果是卸载zsh，需要先切换回bash
                        if [ "$software" = "zsh" ]; then
                            echo "切换默认shell为bash..."
                            sudo chsh -s /bin/bash $(whoami)
                            # 删除oh-my-zsh配置
                            if [ -d "$HOME/.oh-my-zsh" ]; then
                                rm -rf "$HOME/.oh-my-zsh"
                                rm -f "$HOME/.zshrc"
                            fi
                        fi
                        if command -v apt &> /dev/null; then
                            sudo apt purge -y $software
                            sudo apt autoremove -y
                        elif command -v yum &> /dev/null; then
                            sudo yum remove -y $software
                            sudo yum autoremove -y
                        elif command -v dnf &> /dev/null; then
                            sudo dnf remove -y $software
                            sudo dnf autoremove -y
                        elif command -v pacman &> /dev/null; then
                            sudo pacman -Rns --noconfirm $software
                        fi
                        echo "$software 已完全卸载"
                    else
                        echo "$software 未安装"
                    fi
                else
                    echo "无效的选择"
                fi
                ;;
            *)
                echo "无效的选择"
                ;;
        esac
        
        press_any_key
    done
}

# HTTPS证书管理函数
manage_https() {
    while true; do
        clear
        echo "HTTPS证书管理"
        echo "-------------"
        
        # 检查是否安装了必要的工具
        if ! command -v nginx &> /dev/null; then
            echo "未检测到 Nginx，正在安装..."
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y nginx
            elif command -v yum &> /dev/null; then
                sudo yum install -y nginx
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y nginx
            elif command -v pacman &> /dev/null; then
                sudo pacman -Sy --noconfirm nginx
            fi
        fi
        
        # 检查是否安装了certbot
        if ! command -v certbot &> /dev/null; then
            echo "未检测到 Certbot，正在安装..."
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y certbot python3-certbot-nginx
            elif command -v yum &> /dev/null; then
                sudo yum install -y certbot python3-certbot-nginx
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y certbot python3-certbot-nginx
            elif command -v pacman &> /dev/null; then
                sudo pacman -Sy --noconfirm certbot certbot-nginx
            fi
        fi
        
        # 获取所有配置的网站
        echo "检测到的网站："
        echo "-------------"
        local sites=($(find /etc/nginx/sites-enabled/ -type l -exec basename {} \;))
        local i=1
        
        if [ ${#sites[@]} -eq 0 ]; then
            echo "未检测到任何网站配置"
        else
            for site in "${sites[@]}"; do
                # 检查是否有SSL证书
                if grep -q "ssl_certificate" "/etc/nginx/sites-enabled/$site"; then
                    local cert_path=$(grep "ssl_certificate" "/etc/nginx/sites-enabled/$site" | awk '{print $2}' | tr -d ';')
                    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2)
                    local expiry_epoch=$(date -d "$expiry_date" +%s)
                    local now_epoch=$(date +%s)
                    local days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
                    
                    if [ $days_left -lt 30 ]; then
                        echo "$i. $site (SSL证书将在 $days_left 天后过期) [需要续期]"
                    else
                        echo "$i. $site (SSL证书有效期还剩 $days_left 天)"
                    fi
                else
                    echo "$i. $site (未启用HTTPS)"
                fi
                i=$((i+1))
            done
        fi
        
        echo "-------------"
        echo "1. 为网站添加HTTPS证书"
        echo "2. 续期已有的证书"
        echo "0. 返回上一级"
        echo "-------------"
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                read -p "请输入域名: " domain
                if [ -n "$domain" ]; then
                    echo "正在为 $domain 申请SSL证书..."
                    sudo certbot --nginx -d "$domain"
                    echo "证书配置完成"
                else
                    echo "域名不能为空"
                fi
                ;;                
            2)
                echo "正在续期所有证书..."
                sudo certbot renew
                echo "证书续期完成"
                ;;                
            0)
                break
                ;;                
            *)
                echo "无效的选择"
                ;;                
        esac
        
        press_any_key
    done
}

# 主函数
main() {
    while true; do
        clear
        echo "1. 系统信息查询"
        echo "2. 管理常用软件"
        echo "3. 修改系统设置"
        echo "4. 管理HTTPS证书"
        echo "5. 退出"
        
        read -p "请选择功能 (1-5): " choice
        
        case $choice in
            1)
                get_system_info
                press_any_key
                ;;                
            2)
                manage_common_software
                ;;                
            3)
                while true; do
                    clear
                    echo "系统设置"
                    echo "-------------"
                    echo "1. 调整为上海时区"
                    echo "2. 设置主机名"
                    echo "3. 配置SSH安全设置"
                    echo "-------------"
                    echo "0. 返回主菜单"
                    echo "-------------"
                    read -p "请选择功能 (0-3): " sub_choice

                    case $sub_choice in
                        1)
                            echo "正在设置系统时区为上海时区..."
                            ;;                        
                        3)
                            configure_ssh
                            press_any_key
                            ;;                        
                        1)
                            echo "正在设置系统时区为上海时区..."
                            sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
                            if [ $? -eq 0 ]; then
                                echo "时区已成功设置为上海时区"
                                echo "当前系统时间: $(date)"
                            else
                                echo "时区设置失败，请检查系统权限或手动设置"
                            fi
                            press_any_key
                            ;;                        
                        2)
                            read -p "请输入新的主机名: " new_hostname
                            if [ -n "$new_hostname" ]; then
                                if sudo hostnamectl set-hostname "$new_hostname" 2>/dev/null; then
                                    echo "主机名已成功修改为: $new_hostname"
                                else
                                    echo "$new_hostname" | sudo tee /etc/hostname > /dev/null
                                    sudo hostname "$new_hostname"
                                    if grep -q "127.0.0.1" /etc/hosts; then
                                        sudo sed -i "s/127.0.0.1 .*/127.0.0.1       $new_hostname localhost/g" /etc/hosts
                                    else
                                        echo "127.0.0.1       $new_hostname localhost" | sudo tee -a /etc/hosts > /dev/null
                                    fi
                                    echo "主机名已成功修改为: $new_hostname"
                                fi
                                echo "需要重新登录后生效"
                            else
                                echo "主机名不能为空"
                            fi
                            press_any_key
                            ;;                        
                        0)
                            break
                            ;;                        
                        *)
                            echo "无效的选择"
                            press_any_key
                            ;;                        
                    esac
                done
                ;;            
            4)
                manage_https
                ;;            
            5)
                exit 0
                ;;            
            *)
                echo "无效的选择"
                press_any_key
                ;;            
        esac
    done
}

# 执行主函数
main
