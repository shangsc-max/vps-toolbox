#!/bin/bash

while true; do
    echo
    echo "====== 防火墙（UFW）======"
    echo "1. 安装并启用防火墙"
    echo "2. 放行端口（TCP/UDP）"
    echo "3. 禁用端口（自动保护 SSH）"
    echo "4. 关闭防火墙"
    echo "0. 返回"
    read -p "请选择：" f

    SSH_PORT=$(ss -tnlp | grep sshd | awk -F: '{print $NF}' | head -n1)

    case $f in
        1)
            ufw enable
            ufw allow $SSH_PORT/tcp
            echo "✅ 防火墙已启用，SSH 端口已放行"
            ;;
        2)
            read -p "端口：" p
            read -p "协议(tcp/udp)：" proto
            ufw allow $p/$proto
            echo "✅ 已放行 $p/$proto"
            ;;
        3)
            read -p "端口：" p
            if [ "$p" == "$SSH_PORT" ]; then
                echo "❌ 不能封禁当前 SSH 端口"
            else
                ufw delete allow $p
                echo "✅ 已禁用端口 $p"
            fi
            ;;
        4)
            ufw disable
            echo "⚠ 防火墙已关闭"
            ;;
        0) break ;;
        *) echo "❌ 无效选项" ;;
    esac
done
