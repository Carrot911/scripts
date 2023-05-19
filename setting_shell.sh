#!/bin/bash

# 检测当前shell类型
if [ -n "$ZSH_VERSION" ]; then
    # 当前shell为zsh
    echo "当前shell为zsh"

    # 检测是否安装oh-my-zsh主题
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "未安装oh-my-zsh主题"
        # 安装oh-my-zsh主题
        yes | sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "已安装oh-my-zsh主题"
    fi
else
    # 当前shell不是zsh
    echo "当前shell不是zsh"

    # 检测是否安装zsh
    if ! command -v zsh &> /dev/null; then
        echo "未安装zsh"
        # 安装zsh
        apt install zsh -y
    else
        echo "已安装zsh"
        # 切换为zsh
        chsh -s $(which zsh)
    fi

    # 检测是否安装oh-my-zsh主题
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "未安装oh-my-zsh主题"
        # 安装oh-my-zsh主题
        yes | sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "已安装oh-my-zsh主题"
    fi
fi
