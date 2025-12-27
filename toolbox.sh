#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (全系统修复版)
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

    # 识别系统类型并安装基础依赖
    if [ -f /etc/alpine-release ]; then
        OS="Alpine"
        apk update > /dev/null 2>&1
        apk add curl wget ufw fail2ban bash grep net-tools > /dev/null 2>&1
    else
        OS="Debian"
        apt update -y > /dev/null 2>&1
        apt install -y curl wget ufw fail2ban lsb-release sed net-tools > /dev/null 2>&1
    fi

    # 快捷键配置
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
        echo -e "${YELLOW}未加固${NC}"
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
    echo -e "Docker加固: $(get_docker_fix_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${GREEN}快捷指令: ${YELLOW}sm${GREEN} / ${YELLOW}SM${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 3. Fail2Ban 管理 (修复输入无反应) ---
function manage_f2b() {
    while true; do
        clear
        echo -e "${YELLOW}--- Fail2Ban 防御管理 [状态: $(get_f2b_status)] ---${NC}"
        echo -e "1. 安装并开启基础防御"
        echo -e "2. 查看封禁列表 (sshd)"
        echo -e "3. 停止/启动服务"
        echo -e "4. 解封指定 IP"
        echo -e "0. 返回主菜单"
        echo -e "--------------------"
        read -p "请输入数字选择: " f_opt
        case "$f_opt" in
            1)
                echo -e "${YELLOW}正在配置...${NC}"
                if [ "$OS" == "Alpine" ]; then
                    apk add fail2ban > /dev/null 2>&1
                    rc-update add fail2ban && rc-service fail2ban restart
                else
                    apt install -y fail2ban > /dev/null 2>&1
                    systemctl enable fail2ban && systemctl restart fail2ban
                fi
                echo -e "${GREEN}防御已开启！${NC}"; sleep 2 ;;
            2)
                fail2ban-client status sshd
                read -p "按回车继续..." ;;
            3)
                if [ "$OS" == "Alpine" ]; then
                    rc-service fail2ban stop || rc-service fail2ban start
                else
                    systemctl is-active --quiet fail2ban && systemctl stop fail2ban || systemctl start fail2ban
                fi
                echo -e "${GREEN}状态已切换${NC}"; sleep 1 ;;
            4)
                read -p "输入要解封的 IP: " target_ip
                fail2ban-client set sshd unbanip $target_ip
                echo -e "${GREEN}解封指令已发送${NC}"; sleep 1 ;;
            0) break ;;
            *) echo -e "${RED}输入无效，请重新选择${NC}"; sleep 1 ;;
        esac
    done
}

# --- 4. 其他功能模块 (保持原样) ---
function manage_ufw() {
    while true; do
        clear
        echo -e "${YELLOW}--- 防火墙管理 [状态: $(get_ufw_status)] ---${NC}"
        ssh_port=$(netstat -tuln | grep -E ':(22|ssh)' | awk '{print $4}' | awk -F: '{print $NF}' | head -n1)
        [[ -z "$ssh_port" ]] && ssh_port=22
        echo -e "1. 启用防火墙\n2. 关闭防火墙\n3. 修复 Docker 漏洞\n0. 返回主菜单"
        read -p "选择: " u_opt
        case "$u_opt" in
            1) ufw allow "$ssh_port"/tcp; ufw --force enable; sleep 1 ;;
            2) ufw disable; sleep 1 ;;
            3) 
                if ! command -v docker &> /dev/null; then echo -e "${RED}未安装 Docker${NC}"; else
                mkdir -p /etc/docker && echo -e '{"iptables": false}' > /etc/docker/daemon.json
                [ "$OS" == "Alpine" ] && rc-service docker restart || systemctl restart docker
                echo -e "${GREEN}加固完成${NC}"; fi; sleep 2 ;;
            0) break ;;
        esac
    done
}

# --- 主循环 ---
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
        2) # 这里可以放之前的 SSH 管理代码
           echo "SSH 管理待完善"; sleep 1 ;;
        3) manage_ufw ;;
        4) manage_f2b ;;
        5) wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh && chmod +x /usr/local/bin/sm; exit 0 ;;
        q) exit 0 ;;
        *) echo -e "${RED}无效输入${NC}"; sleep 1 ;;
    esac
done
