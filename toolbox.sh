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

# --- 1. 核心工具函数：智能安装 (解决 dpkg 锁占用) ---
smart_apt() {
    local pkg=$1
    local max_retries=2
    local count=0

    while [ $count -le $max_retries ]; do
        echo -e "${CYAN}正在安装依赖: $pkg ...${NC}"
        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
            return 0
        else
            count=$((count + 1))
            echo -e "${YELLOW}检测到安装冲突或锁占用，正在尝试自动修复 (第 $count 次重试)...${NC}"
            rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock
            dpkg --configure -a
            sleep 2
        fi
    done
    echo -e "${RED}无法安装 $pkg，请手动检查系统状态。${NC}"
    return 1
}

# --- 2. 环境自检 & 快捷键配置 ---
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

get_docker_fix_status() {
    if [ -f "/etc/docker/daemon.json" ] && grep -q '"iptables": false' /etc/docker/daemon.json; then
        echo -e "${GREEN}已加固${NC}"
    else
        echo -e "${YELLOW}默认/未加固${NC}"
    fi
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
    echo -e "Docker加固: $(get_docker_fix_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
}

# --- 4. 各功能模块 ---

function manage_ssh() {
    while true; do
        clear
        echo -e "${YELLOW}--- SSH 安全管理 ---${NC}"
        echo -e "1. 修改 SSH 端口"
        echo -e "2. 禁用密码登录 (仅限密钥)"
        echo -e "3. 重启 SSH 服务"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) read -p "输入新端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; ufw allow $p/tcp; echo -e "${GREEN}端口已修改并放行${NC}"; sleep 1 ;;
            2) sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config; echo -e "${GREEN}密码登录已禁用${NC}"; sleep 1 ;;
            3) systemctl restart ssh && echo -e "${GREEN}SSH 服务已重启${NC}"; sleep 1 ;;
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
        echo -e "4. 放行端口 (如: 80/tcp)"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) apt-get update && smart_apt "ufw" && echo -e "${GREEN}安装完成${NC}"; sleep 1 ;;
            2) 
                ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d: -f2 | head -n1)
                [[ -z "$ssh_port" ]] && ssh_port=22
                ufw allow "$ssh_port"/tcp && ufw --force enable && echo -e "${GREEN}已开启并放行 SSH${NC}"; sleep 1 ;;
            3) ufw disable; sleep 1 ;;
            4) read -p "输入端口/协议: " p; ufw allow $p ;;
            0) break ;;
        esac
    done
}

function manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}--- Fail2Ban 防御管理 [状态: $(get_f2b_status)] ---${NC}"
        echo -e "1. 安装/重置 Fail2Ban"
        echo -e "2. 查看 SSH 封禁列表"
        echo -e "3. 停止/启动 服务"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) 
                if smart_apt "fail2ban"; then
                    systemctl unmask fail2ban && systemctl enable fail2ban && systemctl restart fail2ban
                    echo -e "${GREEN}安装并开启成功${NC}"
                fi; sleep 2 ;;
            2) fail2ban-client status sshd; read -p "回车继续..." ;;
            3) systemctl is-active --quiet fail2ban && systemctl stop fail2ban || systemctl start fail2ban; sleep 1 ;;
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
    echo -e "5. ${CYAN}更新脚本${NC}          0. 脚本使用说明"
    echo -e "q. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入数字选择功能: " choice
    case "$choice" in
        1) manage_ssh ;;
        2) manage_ufw ;;
        3) manage_f2b ;;
        4) read -p "GitHub 用户: " gu; wget -qO- https://github.com/$gu.keys >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; echo -e "${GREEN}密钥同步完成${NC}"; sleep 1 ;;
        5) 
            echo -e "${YELLOW}正在从 GitHub 获取最新版本...${NC}"
            if wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh; then
                chmod +x /usr/local/bin/sm
                echo -e "${GREEN}更新成功！正在重启脚本...${NC}"
                sleep 1
                exec sm
            else
                echo -e "${RED}更新失败，请检查网络连接！${NC}"
                sleep 2
            fi ;;
        0) clear; echo "请参考 GitHub 项目主页获取帮助"; read -p "按回车继续..." ;;
        q) exit 0 ;;
    esac
done
