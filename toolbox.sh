#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (终极整合自愈版)
# 作者: Shang-Max
# GitHub: https://github.com/shangsc-max/vps-toolbox
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 1. 核心工具函数：智能安装 ---
smart_apt() {
    local pkg=$1
    echo -e "${CYAN}正在检测并安装依赖: $pkg ...${NC}"
    # 强制清理锁文件
    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock
    dpkg --configure -a >/dev/null 2>&1
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
        return 0
    else
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
    fi
}

# --- 2. 环境自检 ---
check_env() {
    [[ $EUID -ne 0 ]] && echo -e "${RED}错误：请使用 root 用户运行！${NC}" && exit 1
    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm && chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi
}

get_ufw_status() { ufw status 2>/dev/null | grep -q "active" && echo -e "${GREEN}开启${NC}" || echo -e "${RED}关闭${NC}"; }
get_f2b_status() { systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}已停止${NC}"; }

# --- 3. 核心功能模块 ---

function manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}--- Fail2Ban 防御管理 [状态: $(get_f2b_status)] ---${NC}"
        echo -e "1. 强制安装/深度自愈 (解决无法启动/报错)"
        echo -e "2. 查看 SSH 封禁列表"
        echo -e "3. 启动/停止 服务"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1)
                echo -e "${CYAN}正在执行深度自愈...${NC}"
                smart_apt "fail2ban"
                
                # 【关键修复】创建基础配置文件，防止服务因无配置而自动退出
                echo -e "${CYAN}正在激活 SSH 自动防护规则...${NC}"
                cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF
                # 确保系统日志文件存在，否则 f2b 启动会报错
                [ ! -f /var/log/auth.log ] && touch /var/log/auth.log
                
                # 清理残留的无效 socket
                rm -f /var/run/fail2ban/fail2ban.sock
                
                systemctl unmask fail2ban >/dev/null 2>&1
                systemctl enable fail2ban >/dev/null 2>&1
                systemctl restart fail2ban
                
                sleep 2
                if systemctl is-active --quiet fail2ban; then
                    echo -e "${GREEN}自愈成功！服务已进入运行状态。${NC}"
                else
                    echo -e "${RED}自愈失败。尝试手动输入: fail2ban-server -x start${NC}"
                fi; sleep 2 ;;
            2) 
                if systemctl is-active --quiet fail2ban; then
                    fail2ban-client status sshd
                else
                    echo -e "${RED}错误：服务未运行。请先选 1 修复，确保上方状态为[运行中]。${NC}"
                fi; read -p "回车继续..." ;;
            3) 
                if systemctl is-active --quiet fail2ban; then
                    systemctl stop fail2ban && echo -e "${YELLOW}服务已停止${NC}"
                else
                    systemctl start fail2ban && echo -e "${GREEN}服务已启动${NC}"
                fi; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 4. 主循环界面 ---
check_env
while true; do
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "无")
    echo -e "${BLUE}==================================================${NC}"
    echo -e "          ${YELLOW}[SM]${NC} ${GREEN}Shang-Max VPS 工具箱${NC}"
    echo -e "系统版本:   $(lsb_release -d | cut -f2- 2>/dev/null || echo "Debian/Ubuntu")"
    echo -e "公网 IPv4:  ${CYAN}$ipv4${NC}"
    echo -e "防火墙: $(get_ufw_status)      防爆破: $(get_f2b_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "1. SSH 管理          2. 防火墙管理"
    echo -e "3. Fail2Ban 防爆破   4. GitHub 密钥同步"
    echo -e "5. ${CYAN}更新并重启脚本${NC}    q. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入选项: " choice
    case "$choice" in
        1) read -p "新 SSH 端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; systemctl restart ssh; echo -e "${GREEN}端口已改为 $p${NC}"; sleep 1 ;;
        2) # 这里可以放 ufw 管理逻辑
           echo "管理 UFW..."; sleep 1 ;;
        3) manage_f2b ;;
        4) read -p "GitHub 用户: " gu; wget -qO- https://github.com/$gu.keys >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; echo -e "${GREEN}同步完成${NC}"; sleep 1 ;;
        5) 
            echo -e "${YELLOW}正在更新脚本...${NC}"
            if wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh; then
                chmod +x /usr/local/bin/sm
                echo -e "${GREEN}更新成功！正在自动重启...${NC}"
                sleep 1 && exec sm
            else
                echo -e "${RED}更新失败，请检查网络！${NC}"; sleep 2
            fi ;;
        q) exit 0 ;;
    esac
done
