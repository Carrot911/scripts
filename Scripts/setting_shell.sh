#!/bin/bash

# 检测是否有sudo权限
check_sudo() {
    if ! command -v sudo &> /dev/null; then
        echo "错误：未安装sudo，请先安装sudo或使用root用户运行此脚本"
        exit 1
    fi
}

# 检测IP地理位置
check_ip_location() {
    # 使用多个API备选，提高可靠性
    local country_code
    
    # 尝试使用ipapi.co
    country_code=$(curl -s -m 5 https://ipapi.co/country)
    
    # 如果失败，尝试使用ipinfo.io
    if [ -z "$country_code" ] || [ "$country_code" = "Undefined" ]; then
        country_code=$(curl -s -m 5 https://ipinfo.io/country)
    fi
    
    # 如果仍然失败，尝试使用cip.cc
    if [ -z "$country_code" ] || [ "$country_code" = "Undefined" ]; then
        country_code=$(curl -s -m 5 http://cip.cc | grep '地址' | cut -d ':' -f2 | awk '{print $1}')
        # 如果是中国，返回CN
        if echo "$country_code" | grep -q '中国'; then
            country_code="CN"
        fi
    fi
    
    # 如果仍然失败，尝试使用myip.la
    if [ -z "$country_code" ] || [ "$country_code" = "Undefined" ]; then
        country_code=$(curl -s -m 5 https://myip.la/en | grep -o 'Country: [^<]*' | cut -d ' ' -f2)
    fi
    
    # 如果所有API都失败了，返回UNKNOWN
    if [ -z "$country_code" ] || [ "$country_code" = "Undefined" ]; then
        echo "警告：无法获取地理位置信息，将使用默认配置"
        country_code="UNKNOWN"
    fi
    
    echo "$country_code"
}

# 检查并刷新环境变量
refresh_env() {
    if [ -f "$HOME/.zshrc" ]; then
        source "$HOME/.zshrc" || true
    fi
}

# 检测当前shell类型
if [ -n "$ZSH_VERSION" ]; then
    # 当前shell为zsh
    echo "当前shell为zsh"

    # 检测是否安装oh-my-zsh主题
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "未安装oh-my-zsh主题"
        
        # 检测IP地理位置
        country_code=$(check_ip_location)
        echo "检测到IP所在地区: $country_code"
        
        # 根据地理位置选择安装源
        if [ "$country_code" = "CN" ]; then
            echo "检测到中国大陆IP，使用国内镜像源..."
            # 尝试使用Gitee源
            if curl -fsSL --connect-timeout 5 https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh -o /dev/null; then
                echo "使用Gitee源安装oh-my-zsh..."
                REMOTE=https://gitee.com/mirrors/oh-my-zsh.git sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)" "" --unattended
            else
                # 尝试使用清华源
                echo "Gitee源连接失败，尝试使用清华源..."
                REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh/ohmyzsh.git sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)" "" --unattended
            fi
        else
            echo "使用GitHub官方源安装..."
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi
    else
        echo "已安装oh-my-zsh主题"
    fi
else
    # 当前shell不是zsh
    echo "当前shell不是zsh"
    check_sudo

    # 检测是否安装zsh
    if ! command -v zsh &> /dev/null; then
        echo "未安装zsh"
        # 安装zsh
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y zsh
        elif command -v yum &> /dev/null; then
            sudo yum install -y zsh
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y zsh
        else
            echo "错误：未找到支持的包管理器"
            exit 1
        fi
    else
        echo "已安装zsh"
    fi

    # 切换为zsh
    echo "正在将默认shell切换为zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
    if [ $? -ne 0 ]; then
        echo "警告：切换默认shell失败，请手动执行: chsh -s $(which zsh)"
    fi
fi

# 检测是否安装oh-my-zsh主题
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "未安装oh-my-zsh主题，开始安装..."
    
    # 检测IP地理位置
    country_code=$(check_ip_location)
    echo "检测到IP所在地区: $country_code"
    
    # 定义安装函数
    install_omz() {
        local install_url=$1
        local repo_url=$2
        echo "尝试使用 $3 安装oh-my-zsh..."
        
        # 创建临时安装脚本
        local temp_script=$(mktemp)
        if curl -fsSL --connect-timeout 10 --retry 3 --insecure "$install_url" -o "$temp_script"; then
            if [ -n "$repo_url" ]; then
                REMOTE="$repo_url" sh "$temp_script" --unattended
            else
                sh "$temp_script" --unattended
            fi
            local exit_code=$?
            rm -f "$temp_script"
            return $exit_code
        else
            rm -f "$temp_script"
            return 1
        fi
    }

    # 根据地理位置选择安装源
    if [ "$country_code" = "CN" ]; then
        echo "检测到中国大陆IP，优先使用国内镜像源..."
        if install_omz \
            "https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh" \
            "https://gitee.com/mirrors/oh-my-zsh.git" \
            "Gitee镜像源"; then
            echo "使用Gitee源安装成功"
        elif install_omz \
            "https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh" \
            "https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh/ohmyzsh.git" \
            "清华镜像源"; then
            echo "使用清华源安装成功"
        else
            echo "国内源安装失败，尝试使用GitHub官方源..."
            if install_omz \
                "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" \
                "" \
                "GitHub官方源"; then
                echo "使用GitHub源安装成功"
            else
                echo "所有源安装失败，请检查网络连接或手动安装"
                exit 1
            fi
        fi
    else
        echo "非中国大陆IP，使用GitHub官方源..."
        if install_omz \
            "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" \
            "" \
            "GitHub官方源"; then
            echo "使用GitHub源安装成功"
        else
            echo "GitHub源安装失败，尝试使用镜像源..."
            if install_omz \
                "https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh" \
                "https://gitee.com/mirrors/oh-my-zsh.git" \
                "Gitee镜像源"; then
                echo "使用Gitee源安装成功"
            else
                echo "所有源安装失败，请检查网络连接或手动安装"
                exit 1
            fi
        fi
    fi

    # 配置主题
    if [ -f "$HOME/.zshrc" ]; then
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
        echo "已设置agnoster主题"
    fi
else
    echo "已安装oh-my-zsh主题"
fi

# 刷新环境变量
refresh_env

echo "安装和配置完成，请重新登录以应用更改"
