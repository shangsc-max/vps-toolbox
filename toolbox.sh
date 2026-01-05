#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (纯净修复版)
# ====================================================

# 基础颜色定义 (简化版，防止乱码)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# --- 核心工具函数 ---
smart_apt() {
    local pkg=$1
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock
    dpkg --configure -a >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1
}

# --- 状态检测 ---
get_ufw_status() { ufw status 2>/dev/null | grep -q "active" && echo "ON" || echo "OFF"; }
get_f2b_status() { systemctl is-active --quiet fail2ban 2>/dev/null && echo "RUN" || echo "STOP"; }
get_ssh_root() { grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && echo "YES" || echo "NO"; }
get_ssh_port() { grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22"; }

# --- 模块功能 ---
manage_ssh() {
    clear
    echo "--------------------------------------------------"
    echo "            SSH 安全加固管理"
    echo "--------------------------------------------------"
    echo " 1. 修改 SSH 端口"
    echo " 2. 开/关 Root 密码登录"
    echo " 3. 设置 10分钟闲置断开"
    echo " 4. 查看登录失败记录"
    echo " 0. 返回"
    echo "--------------------------------------------------"
    read -p "选择: " opt
    case $opt in
        1) read -p "新端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; ufw allow "$p"/tcp; systemctl restart ssh; echo "完成"; sleep 1 ;;
        2) 
            if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
                sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
            else
                sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
            fi
            systemctl restart ssh; echo "已切换"; sleep 1 ;;
        3) echo "ClientAliveInterval 600" >> /etc/ssh/sshd_config; systemctl restart ssh; sleep 1 ;;
        4) lastb -n 10; read -p "回车继续" ;;
    esac
}

manage_ufw() {
    clear
    echo "--------------------------------------------------"
    echo "            UFW 防火墙策略管理"
    echo "--------------------------------------------------"
    echo " 1. 开启防火墙 (放行SSH)"
    echo " 2. 关闭防火墙"
    echo " 3. 放行 Web 常用端口 (80/443)"
    echo " 4. 手动输入端口放行"
    echo " 5. 查看拦截日志"
    echo " 0. 返回"
    echo "--------------------------------------------------"
    read -p "选择: " opt
    case $opt in
        1) smart_apt ufw; p=$(get_ssh_port); ufw allow "$p"/tcp; echo "y" | ufw enable; sleep 1 ;;
        2) ufw disable; sleep 1 ;;
        3) ufw allow 80/tcp; ufw allow 443/tcp; echo "已放行"; sleep 1 ;;
        4) read -p "端口: " p; ufw allow "$p"; sleep 1 ;;
        5) tail -n 20 /var/log/ufw.log; read -p "回车继续" ;;
    esac
}

manage_f2b() {
    clear
    echo "--------------------------------------------------"
    echo "            Fail2Ban 防爆破管理"
    echo "--------------------------------------------------"
    echo " 1. 深度修复 (解决启动报错)"
    echo " 2. 启动服务"
    echo " 3. 停止服务"
    echo " 4. 查看封禁列表"
    echo " 5. 手动解封 IP"
    echo " 0. 返回"
    echo "--------------------------------------------------"
    read -p "选择: " opt
    case $opt in
        1)
            smart_apt fail2ban
            echo -e "[sshd]\nenabled = true\nport = ssh\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5\nbantime = 3600" > /etc/fail2ban/jail.local
            touch /var/log/auth.log && rm -f /var/run/fail2ban/fail2ban.sock
            systemctl unmask fail2ban && systemctl restart fail2ban
            echo "修复完成"; sleep 1 ;;
        2) systemctl start fail2ban; sleep 1 ;;
        3) systemctl stop fail2ban; sleep 1 ;;
        4) fail2ban-client status sshd; read -p "回车继续" ;;
        5) read -p "IP: " ip; fail2ban-client set sshd unbanip "$ip"; sleep 1 ;;
    esac
}

# --- 主界面 ---
while true; do
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "N/A")
    echo -e "${BLUE}==================================================${PLAIN}"
    echo -e "         ${YELLOW}[SM] VPS 旗舰工具箱 (V3.1)${PLAIN}"
    echo -e "${BLUE}--------------------------------------------------${PLAIN}"
    echo -e " 系统 IP : ${CYAN}$ipv4${PLAIN}      SSH 端口 : ${CYAN}$(get_ssh_port)${PLAIN}"
    echo -e " 防火墙  : $(get_ufw_status)            防爆破   : $(get_f2b_status)"
    echo -e " Root登录: $(get_ssh_root)"
    echo -e "${BLUE}--------------------------------------------------${PLAIN}"
    echo -e "  1. SSH 安全管理        2. 防火墙 (UFW) 管理"
    echo -e "  3. Fail2Ban 管理       4. GitHub 密钥同步"
    echo -e "  5. ${CYAN}更新脚本${PLAIN}            q. 退出脚本"
    echo -e "${BLUE}==================================================${PLAIN}"
    read -p "请输入选项: " choice
    case "$choice" in
        1) manage_ssh ;;
        2) manage_ufw ;;
        3) manage_f2b ;;
        4) 
            read -p "GitHub 用户名: " user
            mkdir -p ~/.ssh && wget -qO- https://github.com/$user.keys >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys && echo "同步成功"; sleep 1 ;;
        5) 
            wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh && chmod +x /usr/local/bin/sm && exec sm ;;
        q) exit 0 ;;
    esac
done
