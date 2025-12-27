#!/bin/bash

update_system_menu() {
    echo
    read -p "是否对新机器进行初始化更新？(y/n)：" yn
    if [[ $yn == "y" ]]; then
        update_system
    fi
}

update_system() {
    echo "🔄 正在更新系统并安装基础组件..."

    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt upgrade -y
        apt install -y curl wget sudo lsof net-tools ufw fail2ban
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum install -y curl wget sudo lsof net-tools epel-release
        yum install -y ufw fail2ban
    fi

    echo "✅ 系统初始化完成"
}
