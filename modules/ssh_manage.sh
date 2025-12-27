#!/bin/bash

while true; do
    echo
    echo "====== SSH 管理 ======"
    echo "1. 修改 SSH 端口"
    echo "2. 启用密钥登录（禁用密码）"
    echo "3. 重启 SSH 服务"
    echo "0. 返回"
    read -p "请选择：" c

    case $c in
        1)
            read -p "请输入新 SSH 端口：" NEW_PORT
            sed -i "s/^#Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
            sed -i "s/^Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
            ufw allow $NEW_PORT/tcp 2>/dev/null
            systemctl restart sshd
            echo "✅ SSH 端口已修改为 $NEW_PORT"
            ;;
        2)
            sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
            sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
            systemctl restart sshd
            echo "✅ 已禁用密码登录（请确认你有 SSH 密钥）"
            ;;
        3)
            systemctl restart sshd
            echo "✅ SSH 已重启"
            ;;
        0) break ;;
        *) echo "❌ 无效选项" ;;
    esac
done
