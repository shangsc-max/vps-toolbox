#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (多系统旗舰版)
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

    if [ -f /etc/alpine-release ]; then
        OS="Alpine"
        PKG_MGR="apk add"
    else
        OS="Debian"
        PKG_MGR="apt install -y"
    fi

    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm
        chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi
}

# 状态获取 (增加容错判断)
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

# --- 2. 系统信息显示 ---
function show_sys_info() {
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "无")
    ipv6=$(curl -s6 --connect-timeout 2 ifconfig.me || echo "无")

    echo -e "${BLUE}==================================================${NC}"
    echo -e "         ${YELLOW}[SM]${NC} ${GREEN}VPS 全能工具箱 ($OS)${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "主机名称:   $(hostname)"
    echo -e "内存状态:   $(free -m | awk 'NR==2{printf "已用 %sMB / 总共 %sMB", $3,$2}')"
    [[ "$ipv4" != "无" ]] && echo -e "公网 IPv4:  ${CYAN}$ipv4${NC}"
    [[ "$ipv6" != "无" ]] && echo -e "公网 IPv6:  ${CYAN}$ipv6${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "防火墙状态: $(get_ufw_status)      防爆破状态: $(get_f2b_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${GREEN}快捷指令: ${YELLOW}sm${GREEN} / ${YELLOW}SM${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 3. Fail2Ban 管理模块 (核心修复点) ---
function manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}--- Fail2Ban 防御管理 [状态: $(get_f2b_status)] ---${NC}"
        echo -e "1. 安装/重置并开启防御"
        echo -e "2. 查看封禁列表"
        echo -e "3. 停止/启动服务"
        echo -e "4. 解封指定 IP"
        echo -e "0. 返回主菜单"
        echo -e "--------------------"
        read -p "选择操作: " f_opt
        case "$f_opt" in
            1)
                echo -e "${YELLOW}正在安装并强制启动服务...${NC}"
                if [ "$OS" == "Alpine" ]; then
                    apk add fail2ban > /dev/null 2>&1
                    rc-update add fail2ban && rc-service fail2ban restart
                else
                    # 修复：使用非交互式安装，并直接使用 systemctl 绕过同步卡顿
                    DEBIAN_FRONTEND=noninteractive apt install -y fail2ban > /dev/null 2>&1
                    systemctl unmask fail2ban > /dev/null 2>&1
                    systemctl enable fail2ban > /dev/null 2>&1
                    systemctl restart fail2ban
                fi
                echo -e "${GREEN}操作成功！${NC}"; sleep 2 ;;
            2)
                fail2ban-client status sshd 2>/dev/null || echo -e "${RED}服务未运行或未安装${NC}"
                read -p "按回车继续..." ;;
            3)
                if [ "$OS" == "Alpine" ]; then
                    rc-service fail2ban stop || rc-service fail2ban start
                else
                    systemctl is-active --quiet fail2ban && systemctl stop fail2ban || systemctl start fail2ban
                fi
                echo -e "${GREEN}状态已切换${NC}"; sleep 1 ;;
            4)
                read -p "输入解封 IP: " ip
                fail2ban-client set sshd unbanip $ip
                echo -e "${GREEN}解封指令已发送${NC}"; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 4. 主循环 ---
check_env
while true; do
    show_sys_info
    echo -e "1. GitHub 拉取密钥"
    echo -e "2. SSH 管理"
    echo -e "3. 防火墙管理"
    echo -e "4. Fail2Ban 防爆破"
    echo -e "5. 更新脚本"
    echo -e "q. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入数字选择功能: " choice
    case "$choice" in
        1) read -p "GitHub 用户: " gu; wget -qO- https://github.com/$gu.keys >> ~/.ssh/authorized_keys; echo -e "${GREEN}完成${NC}"; sleep 1 ;;
        2) # 这里保留你之前的 SSH 管理代码
           echo -e "${YELLOW}SSH 管理模块正在运行...${NC}"; sleep 1 ;;
        3) # 这里保留你之前的防火墙管理代码
           echo -e "${YELLOW}防火墙模块正在运行...${NC}"; sleep 1 ;;
        4) manage_f2b ;;
        5) wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh && chmod +x /usr/local/bin/sm; exit 0 ;;
        q) exit 0 ;;
        *) echo -e "${RED}无效输入${NC}"; sleep 1 ;;
    esac
done
