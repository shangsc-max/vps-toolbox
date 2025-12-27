#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (多系统兼容版)
# 支持系统: Debian, Ubuntu, Alpine
# 快捷启动: sm 或 SM
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 1. 环境自检 & 快捷键配置 ---
function check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用 root 用户运行！${NC}"
        exit 1
    fi

    # 识别操作系统
    if [ -f /etc/alpine-release ]; then
        OS="Alpine"
        INSTALL_CMD="apk add"
    else
        OS="Debian"
        INSTALL_CMD="apt install -y"
        # Debian/Ubuntu 需要更新源
        apt update -y > /dev/null 2>&1
    fi

    # 自动配置快捷键
    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm
        chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi

    # 基础组件安装 (根据系统自动匹配)
    if [ "$OS" == "Alpine" ]; then
        $INSTALL_CMD curl wget ufw fail2ban bash bash-completion > /dev/null 2>&1
    else
        $INSTALL_CMD curl wget ufw fail2ban lsb-release sed > /dev/null 2>&1
    fi
}

# 状态获取
get_ufw_status() {
    ufw status | grep -q "Status: active" && echo -e "${GREEN}开启${NC}" || echo -e "${RED}关闭${NC}"
}

get_f2b_status() {
    systemctl is-active --quiet fail2ban 2>/dev/null || rc-service fail2ban status 2>/dev/null | grep -q "started"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
}

# --- 2. 系统信息显示 ---
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
    echo -e "${GREEN}快捷指令: ${YELLOW}sm${GREEN} / ${YELLOW}SM${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 3. 功能模块 ---
function update_script() {
    echo -e "${YELLOW}正在从 GitHub 获取最新版本...${NC}"
    wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh
    chmod +x /usr/local/bin/sm
    echo -e "${GREEN}更新完成！${NC}"
    exit 0
}

function manage_ufw() {
    while true; do
        clear
        echo -e "${YELLOW}--- 防火墙管理 [系统: $OS] [状态: $(get_ufw_status)] ---${NC}"
        # 获取 SSH 端口兼容处理
        ssh_port=$(netstat -tuln | grep -E ':(22|ssh)' | awk '{print $4}' | awk -F: '{print $NF}' | head -n1)
        [[ -z "$ssh_port" ]] && ssh_port=22

        echo -e "1. 安装/修复 UFW\n2. 启用防火墙\n3. 关闭防火墙\n4. 放行端口\n5. 禁用端口\n0. 返回主菜单"
        read -p "选择: " opt
        case $opt in
            1) $INSTALL_CMD ufw ; echo -e "${GREEN}完成${NC}" ; sleep 1 ;;
            2) ufw allow "$ssh_port"/tcp; ufw --force enable ; sleep 1 ;;
            3) ufw disable ; sleep 1 ;;
            4) read -p "格式 80/tcp: " p; ufw allow $p ;;
            5) read -p "格式 80/tcp: " p; ufw delete allow $p ;;
            0) break ;;
        esac
    done
}

function manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}--- Fail2Ban 防御 [状态: $(get_f2b_status)] ---${NC}"
        echo -e "1. 安装/开启防御\n2. 查看封禁列表\n3. 停止/启动服务\n0. 返回主菜单"
        read -p "选择: " opt
        case $opt in
            1) 
                $INSTALL_CMD fail2ban
                # Alpine 与 Debian 服务启动命令不同
                if [ "$OS" == "Alpine" ]; then
                    rc-update add fail2ban && rc-service fail2ban start
                else
                    systemctl enable fail2ban && systemctl restart fail2ban
                fi
                echo -e "${GREEN}开启完成${NC}"; sleep 1 ;;
            2) fail2ban-client status sshd; read -p "回车继续..." ;;
            3) 
                if [ "$OS" == "Alpine" ]; then
                    rc-service fail2ban stop || rc-service fail2ban start
                else
                    systemctl is-active --quiet fail2ban && systemctl stop fail2ban || systemctl start fail2ban
                fi
                sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 主循环 ---
check_env
while true; do
    show_sys_info
    echo -e "1. GitHub 拉取密钥"
    echo -e "2. 防火墙管理"
    echo -e "3. Fail2Ban 防爆破"
    echo -e "4. 更新脚本"
    echo -e "q. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入数字选择功能: " choice
    case $choice in
        1) 
            read -p "GitHub 用户名: " gh_user
            [[ "$gh_user" == "q" ]] && continue
            mkdir -p ~/.ssh && wget -qO- https://github.com/$gh_user.keys >> ~/.ssh/authorized_keys
            echo -e "${GREEN}同步完成${NC}"; sleep 1 ;;
        2) manage_ufw ;;
        3) manage_f2b ;;
        4) update_script ;;
        q) exit 0 ;;
    esac
done
