#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (V4.0 纯净修复版)
# ====================================================

# 基础显示定义
INFO="[信息]"
SUCCESS="[成功]"
ERROR="[失败]"

# --- 核心工具函数 ---
smart_apt() {
    local pkg=$1
    echo -e "$INFO 正在检测并安装 $pkg ..."
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock
    dpkg --configure -a >/dev/null 2>&1
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1; then
        echo -e "$SUCCESS $pkg 安装/更新成功！"
        return 0
    else
        echo -e "$ERROR $pkg 安装失败，请检查网络。"
        return 1
    fi
}

# --- 状态获取逻辑 ---
get_ufw_status() { ufw status | grep -q "Status: active" && echo "【已开启】" || echo "【已关闭】"; }
get_f2b_status() { systemctl is-active --quiet fail2ban && echo "【运行中】" || echo "【已停止】"; }
get_ssh_root() { grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && echo "允许" || echo "禁止"; }
get_ssh_port() { grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22"; }

# --- 1. SSH 管理模块 ---
manage_ssh() {
    clear
    echo "================ SSH 安全管理 ================"
    echo " 当前端口: $(get_ssh_port)  |  Root 登录: $(get_ssh_root)"
    echo "----------------------------------------------"
    echo " 1. 修改 SSH 端口 (修改后会自动放行防火墙)"
    echo " 2. 禁止/允许 Root 密码登录"
    echo " 3. 重启 SSH 服务"
    echo " 0. 返回主菜单"
    echo "----------------------------------------------"
    read -p "选择操作: " opt
    case $opt in
        1) 
            read -p "请输入新端口: " p
            sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config
            ufw allow "$p"/tcp >/dev/null 2>&1
            systemctl restart ssh && echo "$SUCCESS 端口已改为 $p 并已放行防火墙" || echo "$ERROR 修改失败"
            sleep 2 ;;
        2) 
            if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
                sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
                echo "$SUCCESS 已禁止 Root 密码登录"
            else
                sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
                echo "$SUCCESS 已允许 Root 密码登录"
            fi
            systemctl restart ssh; sleep 2 ;;
        3) systemctl restart ssh && echo "$SUCCESS SSH 服务已重启"; sleep 1 ;;
    esac
}

# --- 2. 防火墙 (UFW) 管理模块 ---
manage_ufw() {
    while true; do
        clear
        echo "================ 防火墙 (UFW) 管理 ================"
        echo " 防火墙状态: $(get_ufw_status)"
        echo "---------------------------------------------------"
        echo " 1. 安装/启动防火墙 (自动放行 SSH)"
        echo " 2. 关闭防火墙"
        echo " 3. 彻底卸载 UFW"
        echo " 4. 允许 (Allow) 端口 (例如: 80 或 443/tcp)"
        echo " 5. 禁用 (Deny) 端口 (拒绝外部访问)"
        echo " 6. 删除 (Delete) 规则 (删除已有的放行/拒绝)"
        echo " 7. 查看当前详细规则清单"
        echo " 0. 返回主菜单"
        echo "---------------------------------------------------"
        read -p "选择操作: " opt
        case $opt in
            1) 
                smart_apt ufw
                p=$(get_ssh_port)
                ufw allow "$p"/tcp >/dev/null 2>&1
                echo "y" | ufw enable >/dev/null 2>&1
                echo "$SUCCESS 防火墙已启动并确保 SSH 正常连接"; sleep 2 ;;
            2) ufw disable && echo "$SUCCESS 防火墙已关闭"; sleep 1 ;;
            3) 
                ufw disable >/dev/null 2>&1
                apt-get purge -y ufw >/dev/null 2>&1
                echo "$SUCCESS UFW 已彻底卸载并清理配置"; sleep 2 ;;
            4) read -p "输入放行端口: " p; ufw allow "$p" && echo "$SUCCESS 端口 $p 已开放"; sleep 1 ;;
            5) read -p "输入禁用端口: " p; ufw deny "$p" && echo "$SUCCESS 端口 $p 已禁用"; sleep 1 ;;
            6) ufw status numbered; read -p "输入要删除的规则编号: " num; echo "y" | ufw delete "$num" && echo "$SUCCESS 规则已删除"; sleep 1 ;;
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
        echo " 2. 停止并禁用服务"
        echo " 3. 彻底卸载 Fail2Ban"
        echo " 4. 查看当前封禁列表 (SSH)"
        echo " 5. 手动解封某个 IP"
        echo " 0. 返回主菜单"
        echo "-----------------------------------------------------"
        read -p "选择操作: " opt
        case $opt in
            1)
                smart_apt fail2ban
                echo -e "[sshd]\nenabled = true\nport = ssh\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5\nbantime = 3600" > /etc/fail2ban/jail.local
                touch /var/log/auth.log && rm -f /var/run/fail2ban/fail2ban.sock
                systemctl unmask fail2ban >/dev/null 2>&1
                systemctl enable fail2ban >/dev/null 2>&1
                systemctl restart fail2ban && echo "$SUCCESS 服务启动并自愈完成" || echo "$ERROR 启动失败"
                sleep 2 ;;
            2) systemctl stop fail2ban && systemctl disable fail2ban && echo "$SUCCESS 服务已停止并禁用"; sleep 1 ;;
            3) 
                systemctl stop fail2ban >/dev/null 2>&1
                apt-get purge -y fail2ban >/dev/null 2>&1
                rm -rf /etc/fail2ban && echo "$SUCCESS Fail2Ban 已清理干净"; sleep 2 ;;
            4) fail2ban-client status sshd; read -p "按回车继续..." ;;
            5) read -p "输入 IP: " ip; fail2ban-client set sshd unbanip "$ip" && echo "$SUCCESS $ip 已解除锁定"; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 主界面 ---
[[ $EUID -ne 0 ]] && echo "请用 root 用户运行" && exit 1
while true; do
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "N/A")
    echo "=================================================="
    echo "         [SM] VPS 旗舰工具箱 (V4.0 纯净版)"
    echo "--------------------------------------------------"
    echo " 系统 IP : $ipv4      SSH 端口 : $(get_ssh_port)"
    echo " 防火墙  : $(get_ufw_status)      防爆破   : $(get_f2b_status)"
    echo " Root登录: $(get_ssh_root)"
    echo "--------------------------------------------------"
    echo "  1. SSH 端口与安全管理"
    echo "  2. 防火墙 (UFW) 管理 (放行/禁用)"
    echo "  3. Fail2Ban 防爆破管理 (安装/卸载)"
    echo "  4. GitHub 密钥一键同步"
    echo "  5. 更新重启脚本"
    echo "  q. 退出脚本"
    echo "=================================================="
    read -p "请输入选项: " choice
    case "$choice" in
        1) manage_ssh ;;
        2) manage_ufw ;;
        3) manage_f2b ;;
        4) 
            read -p "GitHub 用户名: " user
            mkdir -p ~/.ssh && wget -qO- https://github.com/$user.keys >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys && echo "$SUCCESS 密钥同步成功"; sleep 2 ;;
        5) 
            echo "$INFO 正在从 GitHub 更新..."
            wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh && chmod +x /usr/local/bin/sm && exec sm ;;
        q) exit 0 ;;
    esac
done
