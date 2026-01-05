#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (旗舰视觉版)
# 作者: Shang-Max
# GitHub: https://github.com/shangsc-max/vps-toolbox
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 1. 核心工具函数 ---
smart_apt() {
    local pkg=$1
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock
    dpkg --configure -a >/dev/null 2>&1
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        echo -e "${CYAN}正在安装 $pkg ...${NC}"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
    fi
}

# --- 2. 状态获取逻辑 ---
get_ufw_status() { ufw status 2>/dev/null | grep -q "active" && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"; }
get_f2b_status() { systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}RUN${NC}" || echo -e "${RED}STOP${NC}"; }
get_ssh_root() { grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && echo -e "${RED}YES${NC}" || echo -e "${GREEN}NO${NC}"; }
get_ssh_port() { grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22"; }

# --- 3. 菜单排版函数 ---
draw_line() { echo -e "${BLUE}--------------------------------------------------${NC}"; }

# --- 4. SSH 安全管理模块 ---
manage_ssh() {
    while true; do
        clear
        echo -e "${YELLOW}================ SSH 安全加固管理 ================${NC}"
        echo -e "  当前端口: $(get_ssh_port)          Root 登录: $(get_ssh_root)"
        draw_line
        echo -e "  1. 修改 SSH 端口"
        echo -e "  2. 禁止/允许 Root 密码登录"
        echo -e "  3. 设置 SSH 10分钟闲置自动断开"
        echo -e "  4. 查看最近 10 条登录失败记录(lastb)"
        echo -e "  5. 重启 SSH 服务"
        echo -e "  0. 返回主菜单"
        draw_line
        read -p "请输入选项: " opt
        case $opt in
            1) read -p "输入新端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; ufw allow "$p"/tcp; echo -e "${GREEN}已完成${NC}"; sleep 1 ;;
            2) 
                if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
                    sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
                    echo -e "${GREEN}已禁用 Root 密码登录${NC}"
                else
                    sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
                    echo -e "${YELLOW}已开启 Root 密码登录${NC}"
                fi; sleep 1 ;;
            3)
                sed -i "/ClientAliveInterval/d" /etc/ssh/sshd_config
                echo "ClientAliveInterval 600" >> /etc/ssh/sshd_config
                echo -e "${GREEN}超时设置已生效${NC}"; sleep 1 ;;
            4) lastb -n 10; read -p "回车继续..." ;;
            5) systemctl restart ssh && echo -e "${GREEN}SSH服务已重启${NC}"; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 5. 防火墙策略模块 ---
manage_ufw() {
    while true; do
        clear
        echo -e "${YELLOW}================ UFW 防火墙策略管理 ================${NC}"
        echo -e "  防火墙状态: $(get_ufw_status)"
        draw_line
        echo -e "  1. 开启防火墙 (自动放行 SSH)"
        echo -e "  2. 关闭防火墙"
        echo -e "  3. 一键放行 Web 常用 (80, 443, 8080)"
        echo -e "  4. 手动输入端口放行 (如 5000/tcp)"
        echo -e "  5. 查看当前放行规则清单"
        echo -e "  6. 查看实时拦截日志 (监控扫描)"
        echo -e "  0. 返回主菜单"
        draw_line
        read -p "请输入选项: " opt
        case $opt in
            1) 
                smart_apt "ufw"
                port=$(get_ssh_port)
                ufw allow "$port"/tcp && echo "y" | ufw enable
                echo -e "${GREEN}已开启并放行 SSH 端口${NC}"; sleep 1 ;;
            2) ufw disable; sleep 1 ;;
            3) ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 8080/tcp; echo -e "${GREEN}放行成功${NC}"; sleep 1 ;;
            4) read -p "端口/协议: " p; ufw allow "$p"; sleep 1 ;;
            5) ufw status numbered; read -p "回车继续..." ;;
            6) echo -e "${CYAN}Ctrl+C 退出日志监控...${NC}"; tail -f /var/log/ufw.log ;;
            0) break ;;
        esac
    done
}

# --- 6. GitHub 密钥同步 ---
manage_github() {
    clear
    echo -e "${YELLOW}================ GitHub 密钥安全同步 ================${NC}"
    read -p "请输入 GitHub 用户名: " user
    [[ -z "$user" ]] && return
    echo -e "  1. ${GREEN}追加模式${NC} (保留现有，最安全)"
    echo -e "  2. ${RED}覆盖模式${NC} (仅保留 GitHub 密钥)"
    read -p "选择模式: " mode
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    case $mode in
        1) wget -qO- https://github.com/"$user".keys >> ~/.ssh/authorized_keys ;;
        2) wget -qO- https://github.com/"$user".keys > ~/.ssh/authorized_keys ;;
    esac
    chmod 600 ~/.ssh/authorized_keys
    echo -e "${GREEN}同步完成！${NC}"; sleep 1
}

# --- 7. Fail2Ban 修复与管理 ---
manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}================ Fail2Ban 防爆破管理 ================${NC}"
        echo -e "  当前状态: $(get_f2b_status)"
        draw_line
        echo -e "  1. ${CYAN}深度自愈修复${NC} (解决无法启动报错)"
        echo -e "  2. 启动服务      3. 停止服务"
        echo -e "  4. 查看封禁列表  5. 查看拦截详情"
        echo -e "  6. 修改封禁时长  0. 返回主菜单"
        draw_line
        read -p "请输入选项: " opt
        case $opt in
            1)
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
                touch /var/log/auth.log && rm -f /var/run/fail2ban/fail2ban.sock
                systemctl restart fail2ban && echo -e "${GREEN}修复成功${NC}"; sleep 2 ;;
            2) systemctl start fail2ban; sleep 1 ;;
            3) systemctl stop fail2ban; sleep 1 ;;
            4) fail2ban-client status sshd; read -p "回车继续..." ;;
            5) fail2ban-client status sshd | grep "IP list"; read -p "回车继续..." ;;
            6) read -p "秒数: " s; sed -i "s/bantime =.*/bantime = $s/" /etc/fail2ban/jail.local; systemctl restart fail2ban; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 主界面 ---
[[ $EUID -ne 0 ]] && exit 1
while true; do
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "无")
    echo -e "${BLUE}==================================================${NC}"
    echo -e "          ${YELLOW}[SM]${NC} ${GREEN}Shang-Max VPS 旗舰工具箱${NC}"
    draw_line
    printf "  %-25s %-25s\n" "系统 IPv4: ${CYAN}$ipv4${NC}" "SSH 端口: ${CYAN}$(get_ssh_port)${NC}"
    printf "  %-25s %-25s\n" "防火墙: $(get_ufw_status)" "防爆破: $(get_f2b_status)"
    printf "  %-25s\n" "Root 登录: $(get_ssh_root)"
    draw_line
    echo -e "  1. ${WHITE}SSH 安全管理${NC}        2. ${WHITE}防火墙 (UFW) 管理${NC}"
    echo -e "  3. ${WHITE}Fail2Ban 管理${NC}       4. ${WHITE}GitHub 密钥同步${NC}"
    echo -e "  5. ${CYAN}更新重启脚本${NC}        q. ${RED}退出脚本${NC}"
    draw_line
    read -p "请输入选项: " choice
    case "$choice" in
        1) manage_ssh ;;
        2) manage_ufw ;;
        3) manage_f2b ;;
        4) manage_github ;;
        5) wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh && chmod +x /usr/local/bin/sm && exec sm ;;
        q) exit 0 ;;
    esac
done
