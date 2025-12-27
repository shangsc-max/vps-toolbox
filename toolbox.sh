#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (全系统全功能版)
# 作者: Shang-Max
# 支持系统: Debian, Ubuntu, Alpine
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 1. 环境自检 & 系统识别 ---
function check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用 root 用户运行！${NC}"
        exit 1
    fi

    # 识别系统类型
    if [ -f /etc/alpine-release ]; then
        OS="Alpine"
        PKG_MGR="apk add"
    else
        OS="Debian"
        PKG_MGR="apt install -y"
    fi

    # 自动配置快捷键
    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm
        chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi
}

# 状态获取 (兼容 systemd 和 openrc)
get_ufw_status() {
    ufw status 2>/dev/null | grep -q "Status: active" && echo -e "${GREEN}开启${NC}" || echo -e "${RED}关闭${NC}"
}

get_f2b_status() {
    if [ "$OS" == "Alpine" ]; then
        rc-service fail2ban status 2>/dev/null | grep -q "started" && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}已停止${NC}"
    else
        systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}已停止${NC}"
    fi
}

get_docker_fix_status() {
    if [ -f "/etc/docker/daemon.json" ] && grep -q '"iptables": false' /etc/docker/daemon.json; then
        echo -e "${GREEN}已加固${NC}"
    else
        echo -e "${YELLOW}默认/未加固${NC}"
    fi
}

# --- 2. 脚本使用说明 ---
function show_help() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "         ${YELLOW}[SM] 脚本使用说明 & 兼容性${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "1. 快捷调取：输入 ${YELLOW}sm${NC} 或 ${YELLOW}SM${NC} 即可启动。"
    echo -e "2. 系统支持：当前已识别为 ${CYAN}$OS Linux${NC}。"
    echo -e "3. 逻辑说明：子菜单输入 ${YELLOW}0${NC} 返回上一级，主菜单输入 ${YELLOW}q${NC} 退出。"
    echo -e "4. Docker加固：无论系统，只要有 Docker 均可开启加固。"
    echo -e "${BLUE}==================================================${NC}"
    read -p "按回车返回主菜单..."
}

# --- 3. 系统信息显示 ---
function show_sys_info() {
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "无")
    ipv6=$(curl -s6 --connect-timeout 2 ifconfig.me || echo "无")

    echo -e "${BLUE}==================================================${NC}"
    echo -e "         ${YELLOW}[SM]${NC} ${GREEN}Shang-Max VPS 全能工具箱${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "操作系统:   ${CYAN}$OS Linux${NC}"
    echo -e "主机名称:   $(hostname)"
    echo -e "内存状态:   $(free -m | awk 'NR==2{printf "已用 %sMB / 总共 %sMB", $3,$2}')"
    [[ "$ipv4" != "无" ]] && echo -e "公网 IPv4:  ${CYAN}$ipv4${NC}"
    [[ "$ipv6" != "无" ]] && echo -e "公网 IPv6:  ${CYAN}$ipv6${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "防火墙状态: $(get_ufw_status)      防爆破状态: $(get_f2b_status)"
    echo -e "Docker加固: $(get_docker_fix_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${GREEN}快捷指令: ${YELLOW}sm${GREEN} / ${YELLOW}SM${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 4. SSH 管理 ---
function manage_ssh() {
    while true; do
        clear
        echo -e "${YELLOW}--- SSH 安全管理 ($OS) ---${NC}"
        echo -e "1. 修改 SSH 端口\n2. 禁用密码登录\n3. 重启 SSH 服务\n0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) read -p "新端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; ufw allow $p/tcp; echo -e "${GREEN}完成${NC}" ; sleep 1 ;;
            2) sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config; echo -e "${GREEN}已禁用${NC}" ; sleep 1 ;;
            3) 
                if [ "$OS" == "Alpine" ]; then rc-service sshd restart; else systemctl restart ssh; fi
                echo -e "${GREEN}已重启${NC}" ; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 5. 防火墙管理 ---
function manage_ufw() {
    while true; do
        clear
        echo -e "${YELLOW}--- 防火墙管理 [状态: $(get_ufw_status)] ---${NC}"
        ssh_port=$(netstat -tuln 2>/dev/null | grep -E ':(22|ssh)' | awk '{print $4}' | awk -F: '{print $NF}' | head -n1)
        [[ -z "$ssh_port" ]] && ssh_port=22
        
        echo -e "1. 安装/修复 UFW\n2. 启用防火墙\n3. 关闭防火墙\n4. 放行端口\n5. 禁用端口"
        echo -e "6. ${GREEN}开启 Docker 安全加固${NC}\n7. ${RED}关闭 Docker 加固 (恢复默认)${NC}\n0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) $PKG_MGR ufw; echo -e "${GREEN}完成${NC}"; sleep 1 ;;
            2) ufw allow "$ssh_port"/tcp; ufw --force enable ; sleep 1 ;;
            3) ufw disable ; sleep 1 ;;
            4) read -p "端口/协议: " p; ufw allow $p ;;
            5) read -p "端口/协议: " p; ufw delete allow $p ;;
            6) 
                if ! command -v docker &> /dev/null; then echo -e "${RED}未安装 Docker${NC}"; else
                [ ! -d "/etc/docker" ] && mkdir -p /etc/docker
                echo -e '{\n  "iptables": false\n}' > /etc/docker/daemon.json
                if [ "$OS" == "Alpine" ]; then rc-service docker restart; else systemctl restart docker; fi
                echo -e "${GREEN}加固开启${NC}"; fi; sleep 1 ;;
            7) 
                if [ -f "/etc/docker/daemon.json" ]; then rm /etc/docker/daemon.json; 
                if [ "$OS" == "Alpine" ]; then rc-service docker restart; else systemctl restart docker; fi
                echo -e "${YELLOW}已恢复默认${NC}"; fi; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 6. Fail2Ban ---
function manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}--- Fail2Ban 防御 [状态: $(get_f2b_status)] ---${NC}"
        echo -e "1. 安装/重置配置\n2. 查看封禁列表\n3. 停止/启动服务\n4. 解封 IP\n0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) 
                $PKG_MGR fail2ban
                if [ "$OS" == "Alpine" ]; then rc-update add fail2ban; rc-service fail2ban start; 
                else systemctl enable fail2ban; systemctl restart fail2ban; fi
                echo -e "${GREEN}配置完成${NC}"; sleep 1 ;;
            2) fail2ban-client status sshd; read -p "回车继续..." ;;
            3) 
                if [ "$OS" == "Alpine" ]; then rc-service fail2ban stop || rc-service fail2ban start;
                else systemctl is-active --quiet fail2ban && systemctl stop fail2ban || systemctl start fail2ban; fi
                sleep 1 ;;
            4) read -p "输入 IP: " ip; fail2ban-client set sshd unbanip $ip ;;
            0) break ;;
        esac
    done
}

# --- 主循环 ---
check_env
while true; do
    show_sys_info
    echo -e "${CYAN}0. 脚本使用说明${NC}"
    echo -e "1. GitHub 拉取密钥"
    echo -e "2. SSH 管理"
    echo -e "3. 防火墙管理"
    echo -e "4. Fail2Ban 防爆破"
    echo -e "5. 更新脚本"
    echo -e "q. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入数字选择功能: " choice
    case $choice in
        0) show_help ;;
        1) read -p "GitHub 用户名: " gu; mkdir -p ~/.ssh; wget -qO- https://github.com/$gu.keys >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; echo -e "${GREEN}完成${NC}"; sleep 1 ;;
        2) manage_ssh ;;
        3) manage_ufw ;;
        4) manage_f2b ;;
        5) 
            echo -e "${YELLOW}更新中...${NC}"
            wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh
            chmod +x /usr/local/bin/sm; exit 0 ;;
        q) exit 0 ;;
    esac
done
