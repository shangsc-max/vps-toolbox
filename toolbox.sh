#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (功能强化版)
# 作者: Shang-Max
# GitHub: https://github.com/shangsc-max/vps-toolbox
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 核心工具函数：智能安装 ---
smart_apt() {
    local pkg=$1
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock
    dpkg --configure -a >/dev/null 2>&1
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        echo -e "${CYAN}正在安装 $pkg ...${NC}"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
    fi
}

# --- 环境自检 ---
check_env() {
    [[ $EUID -ne 0 ]] && echo -e "${RED}错误：请使用 root 用户运行！${NC}" && exit 1
    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm && chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi
}

get_ufw_status() { ufw status 2>/dev/null | grep -q "active" && echo -e "${GREEN}开启${NC}" || echo -e "${RED}关闭${NC}"; }
get_f2b_status() { systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}已停止${NC}"; }

# --- 功能模块：防火墙管理 (强化版) ---
manage_ufw() {
    while true; do
        clear
        echo -e "${YELLOW}--- 防火墙管理 (UFW) [状态: $(get_ufw_status)] ---${NC}"
        echo -e "1. 安装/重置 UFW"
        echo -e "2. 开启防火墙 (默认放行 SSH)"
        echo -e "3. 关闭防火墙"
        echo -e "4. 放行指定端口 (如 80, 443)"
        echo -e "5. 阻止指定端口"
        echo -e "6. 查看当前所有规则"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) smart_apt "ufw"; sleep 1 ;;
            2) 
                ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d: -f2 | head -n1)
                [[ -z "$ssh_port" ]] && ssh_port=22
                ufw allow "$ssh_port"/tcp
                echo "y" | ufw enable
                echo -e "${GREEN}防火墙已启动，SSH 端口 $ssh_port 已放行${NC}"; sleep 2 ;;
            3) ufw disable; sleep 1 ;;
            4) 
                read -p "请输入要放行的端口: " port
                ufw allow "$port" && echo -e "${GREEN}端口 $port 已放行${NC}"; sleep 1 ;;
            5)
                read -p "请输入要阻止的端口: " port
                ufw deny "$port" && echo -e "${YELLOW}端口 $port 已阻止${NC}"; sleep 1 ;;
            6) ufw status numbered; read -p "回车继续..." ;;
            0) break ;;
        esac
    done
}

# --- 功能模块：Fail2Ban 管理 (细化版) ---
manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}--- Fail2Ban 防御设置 [状态: $(get_f2b_status)] ---${NC}"
        echo -e "1. 强制安装/深度自愈 (解决启动报错)"
        echo -e "2. 启动服务"
        echo -e "3. 停止服务"
        echo -e "4. 查看 SSH 封禁列表 (简略)"
        echo -e "5. 查看封禁详情 (查看具体被封 IP)"
        echo -e "6. 手动解封某个 IP"
        echo -e "7. 修改封禁时长 (默认 1小时)"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1)
                echo -e "${CYAN}正在自愈修复...${NC}"
                smart_apt "fail2ban"
                cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF
                touch /var/log/auth.log
                systemctl restart fail2ban
                echo -e "${GREEN}修复完成${NC}"; sleep 2 ;;
            2) systemctl start fail2ban && echo -e "${GREEN}服务已启动${NC}"; sleep 1 ;;
            3) systemctl stop fail2ban && echo -e "${YELLOW}服务已停止${NC}"; sleep 1 ;;
            4) fail2ban-client status sshd; read -p "回车继续..." ;;
            5) 
                if systemctl is-active --quiet fail2ban; then
                    echo -e "${CYAN}当前已封禁的 IP 详细清单：${NC}"
                    fail2ban-client status sshd | grep "IP list"
                else
                    echo -e "${RED}服务未运行${NC}"
                fi; read -p "回车继续..." ;;
            6)
                read -p "请输入要解封的 IP: " target_ip
                fail2ban-client set sshd unbanip "$target_ip" && echo -e "${GREEN}IP $target_ip 已解封${NC}"; sleep 2 ;;
            7)
                read -p "请输入封禁时长(秒，如 3600 为1小时): " btime
                sed -i "s/bantime =.*/bantime = $btime/" /etc/fail2ban/jail.local
                systemctl restart fail2ban
                echo -e "${GREEN}封禁时长已改为 $btime 秒${NC}"; sleep 2 ;;
            0) break ;;
        esac
    done
}

# --- 主界面 ---
check_env
while true; do
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "无")
    echo -e "${BLUE}==================================================${NC}"
    echo -e "          ${YELLOW}[SM]${NC} ${GREEN}Shang-Max VPS 增强工具箱${NC}"
    echo -e "系统版本:   $(lsb_release -d | cut -f2- 2>/dev/null || echo "Debian/Ubuntu")"
    echo -e "公网 IPv4:  ${CYAN}$ipv4${NC}"
    echo -e "防火墙: $(get_ufw_status)      防爆破: $(get_f2b_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "1. SSH 端口修改      2. 防火墙 (UFW) 管理"
    echo -e "3. Fail2Ban 防爆破   4. GitHub 密钥同步"
    echo -e "5. ${CYAN}更新重启脚本${NC}      q. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入选项: " choice
    case "$choice" in
        1) read -p "新 SSH 端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; systemctl restart ssh; echo -e "${GREEN}已修改为 $p${NC}"; sleep 1 ;;
        2) manage_ufw ;;
        3) manage_f2b ;;
        4) read -p "GitHub 用户: " gu; wget -qO- https://github.com/$gu.keys >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; echo -e "${GREEN}同步完成${NC}"; sleep 1 ;;
        5) wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh && chmod +x /usr/local/bin/sm && exec sm ;;
        q) exit 0 ;;
    esac
done
