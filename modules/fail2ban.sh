#!/bin/bash

while true; do
    echo
    echo "====== Fail2Ban ======"
    echo "1. 安装并启动"
    echo "2. 查看封禁 IP"
    echo "3. 解封 IP"
    echo "4. 停止 Fail2Ban"
    echo "0. 返回"
    read -p "请选择：" b

    case $b in
        1)
            systemctl enable fail2ban
            systemctl start fail2ban
            echo "✅ Fail2Ban 已启动（默认 3 次失败封 24 小时）"
            ;;
        2)
            fail2ban-client status sshd
            ;;
        3)
            read -p "输入要解封的 IP：" ip
            fail2ban-client set sshd unbanip $ip
            echo "✅ 已解封 $ip"
            ;;
        4)
            systemctl stop fail2ban
            echo "⚠ Fail2Ban 已停止"
            ;;
        0) break ;;
        *) echo "❌ 无效选项" ;;
    esac
done
