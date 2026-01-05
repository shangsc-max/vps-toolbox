#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (V5.0 最终版)
# ====================================================

# --- 核心状态检测 (带容错) ---
get_ufw_status() {
    if ! command -v ufw &> /dev/null; then
        echo "【未安装】"
    else
        ufw status | grep -q "Status: active" && echo "【已开启】" || echo "【已关闭】"
    fi
}

get_f2b_status() {
    if ! command -v fail2ban-client &> /dev/null; then
        echo "【未安装】"
    else
        systemctl is-active --quiet fail2ban && echo "【运行中】" || echo "【已停止】"
    fi
}

get_ssh_root() { grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && echo "允许" || echo "禁止"; }
get_ssh_port() { grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22"; }

# --- 通用提示函数 ---
msg_ok() { echo -e "\n[成功] $1\n"; sleep 2; }
msg_err() { echo -e "\n[失败] $1\n"; sleep 2; }
msg_info() { echo -e "\n[信息] $1..."; }

# --- 1. SSH 管理模块 ---
manage_ssh() {
    clear
    echo "================ SSH 安全与加固 ================"
    echo " 当前端口: $(get_ssh_port)  |  Root 登录: $(get_ssh_root)"
    echo "------------------------------------------------"
    echo " 1. 修改 SSH 端口 (自动放行新端口)"
    echo " 2. 禁止/允许 Root 密码登录"
    echo " 3. 查看最近 10 条登录失败记录"
    echo " 4. 重启 SSH 服务"
    echo " 0. 返回主菜单"
    echo "------------------------------------------------"
    read -p "选择: " opt
    case $opt in
        1) 
            read -p "新端口: " p
            sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config
            command -v ufw &> /dev/null && ufw allow "$p"/tcp &> /dev/null
            systemctl restart ssh && msg_ok "端口已改为 $p" || msg_err "修改失败" ;;
        2) 
            if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
                sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
                msg_ok "已禁止 Root 登录"
            else
                sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
                msg_ok "已允许 Root 登录"
            fi
            systemctl restart ssh ;;
        3) lastb -n 10; read -p "按回车继续..." ;;
        4) systemctl restart ssh && msg_ok "服务已重启" ;;
    esac
}

# --- 2. 防火墙 (UFW) 管理模块 ---
manage_ufw() {
    while true; do
        clear
        echo "================ 防火墙 (UFW) 管理 ================"
        echo " 防火墙状态: $(get_ufw_status)"
        echo "---------------------------------------------------"
        echo " 1. 安装并启动 (默认放行 SSH)"
        echo " 2. 关闭防火墙"
        echo " 3. 彻底卸载 UFW"
        echo " 4. 允许 (Allow) 端口"
        echo " 5. 拒绝 (Deny) 端口"
        echo " 6. 删除 (Delete) 指定规则"
        echo " 7. 查看当前规则清单"
        echo " 0. 返回主菜单"
        echo "---------------------------------------------------"
        read -p "选择: " opt
        case $opt in
            1)
                msg_info "正在安装 UFW"
                apt-get update &> /dev/null && apt-get install -y ufw &> /dev/null
                p=$(get_ssh_port)
                ufw allow "$p"/tcp &> /dev/null
                echo "y" | ufw enable &> /dev/null
                msg_ok "防火墙已开启" ;;
            2) ufw disable &> /dev/null && msg_ok "防火墙已关闭" ;;
            3) 
                ufw disable &> /dev/null
                apt-get purge -y ufw &> /dev/null && msg_ok "UFW 已彻底卸载" ;;
            4) read -p "放行端口: " p; ufw allow "$p" && msg_ok "已开放 $p" ;;
            5) read -p "禁用端口: " p; ufw deny "$p" && msg_ok "已禁用 $p" ;;
            6) ufw status numbered; read -p "输入规则编号: " n; echo "y" | ufw delete "$n" && msg_ok "规则已删除" ;;
            7) ufw status numbered; read -p "按回车继续..." ;;
            0) break ;;
        esac
    done
}

# --- 3. Fail2Ban 管理模块 ---
manage_f2b() {
    while true; do
        clear
        echo "================ Fail2Ban 防爆破管理 ================"
        echo " 服务状态: $(get_f2b_status)"
        echo "-----------------------------------------------------"
        echo " 1. 安装/修复 并启动 (一键配置 SSH 防护)"
        echo " 2. 停止服务"
        echo " 3. 彻底卸载 Fail2Ban"
        echo " 4. 查看封禁列表"
        echo " 5. 手动解封 IP"
        echo " 0. 返回主菜单"
        echo "-----------------------------------------------------"
        read -p "选择: " opt
        case $opt in
            1)
                msg_info "执行深度安装与配置"
                apt-get update &> /dev/null && apt-get install -y fail2ban &> /dev/null
                echo -e "[sshd]\nenabled = true\nport = ssh\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5\nbantime = 3600" > /etc/fail2ban/jail.local
                touch /var/log/auth.log
                systemctl unmask fail2ban &> /dev/null
                systemctl restart fail2ban && msg_ok "Fail2Ban 已运行" || msg_err "启动失败" ;;
            2) systemctl stop fail2ban && msg_ok "服务已停止" ;;
            3) 
                systemctl stop fail2ban &> /dev/null
                apt-get purge -y fail2ban &> /dev/null
                rm -rf /etc/fail2ban && msg_ok "已彻底卸载" ;;
            4) 
                if command -v fail2ban-client &> /dev/null; then
                    fail2ban-client status sshd
                else
                    msg_err "请先安装服务"
                fi; read -p "按回车继续..." ;;
            5) read -p "解封 IP: " ip; fail2ban-client set sshd unbanip "$ip" && msg_ok "已解封" ;;
            0) break ;;
        esac
    done
}

# --- 主界面 ---
while true; do
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "N/A")
    echo "=================================================="
    echo "         [SM] VPS 工具箱 (V5.0 终极版)"
    echo "--------------------------------------------------"
    echo " 系统 IP : $ipv4        SSH 端口 : $(get_ssh_port)"
    echo " 防火墙  : $(get_ufw_status)      防爆破   : $(get_f2b_status)"
    echo " Root登录: $(get_ssh_root)"
    echo "--------------------------------------------------"
    echo "  1. SSH 安全管理        2. 防火墙 (UFW) 管理"
    echo "  3. Fail2Ban 防爆破     4. GitHub 密钥同步"
    echo "  5. 更新重启脚本        q. 退出脚本"
    echo "=================================================="
    read -p "请输入选择: " choice
    case "$choice" in
        1) manage_ssh ;;
        2) manage_ufw ;;
        3) manage_f2b ;;
        4) 
            read -p "GitHub 用户: " user
            mkdir -p ~/.ssh && wget -qO- https://github.com/$user.keys >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys && msg_ok "密钥同步成功" ;;
        5) 
            msg_info "同步 GitHub 最新版"
            wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh && chmod +x /usr/local/bin/sm && exec sm ;;
        q) exit 0 ;;
    esac
done
