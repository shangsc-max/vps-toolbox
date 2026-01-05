#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (GitHub 旗舰增强版)
# 作者: Shang-Max
# GitHub: https://github.com/shangsc-max/vps-toolbox
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 1. 核心工具函数：智能安装 (解决 dpkg 锁占用与服务异常) ---
smart_apt() {
    local pkg=$1
    echo -e "${CYAN}正在检测并安装依赖: $pkg ...${NC}"
    
    # 强制清理可能存在的残留锁
    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock
    dpkg --configure -a >/dev/null 2>&1

    # 尝试安装
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
        return 0
    else
        echo -e "${YELLOW}首次安装失败，尝试更新源并重试...${NC}"
        apt-get update
        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
            return 0
        else
            echo -e "${RED}严重错误：无法安装 $pkg。请手动执行 'sudo apt install $pkg' 查看错误。${NC}"
            return 1
        fi
    fi
}

# --- 2. 环境自检 & 快捷键 ---
function check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用 root 用户运行！${NC}"
        exit 1
    fi
    # 自动配置系统快捷键
    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm
        chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi
}

# 状态获取函数
get_ufw_status() {
    ufw status 2>/dev/null | grep -q "Status: active" && echo -e "${GREEN}开启${NC}" || echo -e "${RED}关闭${NC}"
}

get_f2b_status() {
    systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}已停止${NC}"
}

# --- 3. 系统信息显示 ---
function show_sys_info() {
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "无")
    echo -e "${BLUE}==================================================${NC}"
    echo -e "          ${YELLOW}[SM]${NC} ${GREEN}Shang-Max VPS 全能工具箱${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "系统版本:   $(lsb_release -d | cut -f2- 2>/dev/null || echo "Debian/Ubuntu")"
    echo -e "公网 IPv4:  ${CYAN}$ipv4${NC}"
    echo -e "防火墙状态: $(get_ufw_status)      防爆破状态: $(get_f2b_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
}

# --- 4. 功能模块 ---

function manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}--- Fail2Ban 防御管理 [状态: $(get_f2b_status)] ---${NC}"
        echo -e "1. 安装/重置 Fail2Ban"
        echo -e "2. 查看 SSH 封禁列表"
        echo -e "3. 启动/停止 服务"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) 
                if smart_apt "fail2ban"; then
                    systemctl unmask fail2ban
                    systemctl enable fail2ban
                    systemctl restart fail2ban
                    echo -e "${GREEN}Fail2Ban 配置并开启成功${NC}"
                fi; sleep 2 ;;
            2) 
                if systemctl is-active --quiet fail2ban; then
                    fail2ban-client status sshd
                else
                    echo -e "${RED}服务未运行，无法查看列表。请先执行选项 1 安装或选项 3 启动。${NC}"
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

function manage_ufw() {
    while true; do
        clear
        echo -e "${YELLOW}--- 防火墙管理 [状态: $(get_ufw_status)] ---${NC}"
        echo -e "1. 安装/重置 UFW"
        echo -e "2. 启用防火墙 (自动放行 SSH)"
        echo -e "3. 关闭防火墙"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) smart_apt "ufw" && echo -e "${GREEN}安装完成${NC}"; sleep 1 ;;
            2) 
                ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d: -f2 | head -n1)
                [[ -z "$ssh_port" ]] && ssh_port=22
                ufw allow "$ssh_port"/tcp && ufw --force enable
                echo -e "${GREEN}防火墙已启动，放行 SSH 端口: $ssh_port${NC}"; sleep 2 ;;
            3) ufw disable; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 主循环 ---
check_env
while true; do
    show_sys_info
    echo -e "1. SSH 管理          2. 防火墙管理"
    echo -e "3. Fail2Ban 防爆破   4. GitHub 密钥同步"
    echo -e "5. ${CYAN}更新并重启脚本${NC}    q. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入数字选择: " choice
    case "$choice" in
        1) read -p "输入新端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; systemctl restart ssh; echo -e "${GREEN}端口已改为 $p${NC}"; sleep 1 ;;
        2) manage_ufw ;;
        3) manage_f2b ;;
        4) read -p "GitHub 用户: " gu; wget -qO- https://github.com/$gu.keys >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; echo -e "${GREEN}密钥同步完成${NC}"; sleep 1 ;;
        5) 
            echo -e "${YELLOW}正在更新脚本...${NC}"
            if wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh; then
                chmod +x /usr/local/bin/sm
                echo -e "${GREEN}更新成功！正在自动重启...${NC}"
                sleep 1
                exec sm
            else
                echo -e "${RED}更新失败，请检查网络连接！${NC}"; sleep 2
            fi ;;
        q) exit 0 ;;
    esac
done
