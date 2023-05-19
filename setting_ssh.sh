#!/bin/bash

#检查是否安装sudo
if [ -x "$(command -v sudo)" ]; then
  echo "Sudo已安装"
else
  echo "Sudo 未安装，开始安装..."
  #安装Sudo
  apt install sudo -y
  
  echo "OpenSSH 安装完成"
fi

# 检查 SSH 是否安装
if [ -x "$(command -v ssh)" ]; then
  echo "OpenSSH 已经安装"
else
  echo "OpenSSH 未安装，开始安装..."
  
  # 安装 OpenSSH
  sudo apt-get update
  sudo apt-get install openssh-server -y
  
  # 启动 SSH 服务
  sudo systemctl enable ssh
  sudo systemctl start ssh
  
  echo "OpenSSH 安装完成"
fi


  
#建立密钥对
ssh-keygen

#安装公钥
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

#更改权限
chmod 600 /root/.ssh/authorized_keys

# 配置 SSH 登录方式为密钥登录
if ! grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
  sudo sed -i 's/^ChallengeResponseAuthentication yes$/&\nPasswordAuthentication no/' /etc/ssh/sshd_config
else
  sudo sed -i 's/^PasswordAuthentication yes$/PasswordAuthentication no/' /etc/ssh/sshd_config
fi

# 关闭 root 用户的密码登录
sudo sed -i 's/^PermitRootLogin.*$/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# 重新加载 SSH 配置
sudo service ssh reload

# 导出公钥到当前目录
if [ ! -d "$HOME/.ssh" ]; then
    mkdir $HOME/.ssh
fi

if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
    ssh-keygen -t rsa -N "" -f $HOME/.ssh/id_rsa
fi

cp $HOME/.ssh/id_rsa.pub .

echo "SSH 登录方式已配置为密钥登录，root 用户的密码登录已被禁用，公钥已导出到 $(pwd)/id_rsa.pub"
