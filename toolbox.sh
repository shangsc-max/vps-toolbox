#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱
# 作者: Shang-Max
# GitHub: https://github.com/shangsc-max/vps-toolbox
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
    # 自动配置系统级快捷键
    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm
        chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi
}

# 状态获取函数
get_ufw_status() {
    ufw status | grep -q "Status: active" && echo -e "${GREEN}开启${NC}" || echo -e "${RED}关闭${NC}"
}

get_f2b_status() {
    systemctl is-active --quiet fail2ban && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}已停止${NC}"
}

# --- 2. 脚本使用说明菜单 ---
function show_help() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "         ${YELLOW}[SM] 脚本快捷操作与说明${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${CYAN}1. 快捷调取：${NC}"
    echo -e "   安装后在任何目录下输入 ${YELLOW}sm${NC} 或 ${YELLOW}SM${NC} 即可启动。"
    echo -e ""
    echo -e "${CYAN}2. 核心逻辑：${NC}"
    echo -e "   - ${GREEN}防火墙${NC}：启用时会自动放行当前的 SSH 端口，防止失联。"
    echo -e "   - ${GREEN}Docker加固${NC}：解决 Docker 自动修改规则绕过防火墙的漏洞。"
    echo -e "   - ${GREEN}Fail2Ban${NC}：默认配置为 3 次密码错误封禁 24 小时。"
    echo -e ""
    echo -e "${CYAN}3. 更新与维护：${NC}"
    echo -e "   选择菜单 [5] 即可同步您在 GitHub 上的最新修改。"
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
    echo -e "主机名称:   $(hostname)"
    echo -e "系统版本:   $(lsb_release -d | cut -f2- 2>/dev/null || echo "Debian/Ubuntu")"
    echo -e "内存状态:   $(free -m | awk 'NR==2{printf "已用 %sMB / 总共 %sMB", $3,$2}')"
    
    [[ "$ipv4" != "无" ]] && echo -e "公网 IPv4:  ${CYAN}$ipv4${NC}"
    [[ "$ipv6" != "无" ]] && echo -e "公网 IPv6:  ${CYAN}$ipv6${NC}"

    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "防火墙状态: $(get_ufw_status)"
    echo -e "防爆破状态: $(get_f2b_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${GREEN}快捷指令: ${YELLOW}sm${GREEN} / ${YELLOW}SM${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 功能函数集 ---
function update_script() {
    echo -e "${YELLOW}正在从 GitHub 获取最新版本...${NC}"
    wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh
    chmod +x /usr/local/bin/sm
    echo -e "${GREEN}脚本更新完成！请直接输入 sm 重新运行。${NC}"
    exit 0
}

function github_key() {
    read -p "请输入 GitHub 用户名 (q退出): " gh_user
    [[ "$gh_user" == "q" ]] && return
    user_check=$(curl -s -o /dev/null -L -w "%{http_code}" "https://github.com/$gh_user")
    if [ "$user_check" -ne 200 ]; then
        echo -e "${RED}错误：未找到用户${NC}"
    else
        key_content=$(curl -s "https://github.com/$gh_user.keys")
        mkdir -p ~/.ssh && echo "$key_content" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo -e "${GREEN}密钥同步成功！${NC}"
    fi
}

function manage_ssh() {
    echo -e "${YELLOW}--- SSH 管理 ---${NC}"
    echo -e "1. 修改 SSH 端口\n2. 禁用密码登录\n3. 重启 SSH 服务"
    read -p "选择: " opt
    case $opt in
        1) read -p "新端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; ufw allow $p/tcp; echo -e "${GREEN}端口已改并放行${NC}" ;;
        2) sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config; echo -e "${GREEN}密码登录已禁用${NC}" ;;
        3) systemctl restart ssh && echo -e "${GREEN}服务已重启${NC}" ;;
    esac
}

function manage_ufw() {
    echo -e "${YELLOW}--- 防火墙管理 [状态: $(get_ufw_status)] ---${NC}"
    ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d: -f2 | head -n1)
    echo -e "1. 启用防火墙\n2. 关闭防火墙\n3. 放行端口 (示例: 80/tcp)\n4. 禁用端口\n5. ${RED}修复 Docker 绕过防火墙漏洞${NC}\n6. 查看详细规则"
    read -p "选择: " opt
    case $opt in
        1) ufw allow "$ssh_port"/tcp; ufw --force enable ;;
        2) ufw disable ;;
        3) read -p "输入端口/协议: " p; ufw allow $p ;;
        4) read -p "输入端口/协议: " p; [[ "$p" != *"$ssh_port"* ]] && ufw delete allow $p ;;
        5) 
            if [ ! -d "/etc/docker" ]; then mkdir -p /etc/docker; fi
            cat > /etc/docker/daemon.json <<EOF
{"iptables": false}
EOF
            systemctl restart docker
            echo -e "${GREEN}Docker 安全加固完成！${NC}"
            ;;
        6) ufw status verbose ;;
    esac
}

function manage_f2b() {
    echo -e "${YELLOW}--- Fail2Ban 防御 [状态: $(get_f2b_status)] ---${NC}"
    echo -e "1. 安装/重置配置\n2. 查看封禁列表\n3. 停止/启动服务\n4. 解封 IP\n5. 卸载"
    read -p "选择: " opt
    case $opt in
        1) apt install -y fail2ban > /dev/null 2>&1; systemctl restart fail2ban; echo -e "${GREEN}配置已生效${NC}" ;;
        2) fail2ban-client status sshd ;;
        3) systemctl is-active --quiet fail2ban && systemctl stop fail2ban || systemctl start fail2ban ;;
        4) read -p "输入 IP: " ip; fail2ban-client set sshd unbanip $ip ;;
        5) systemctl stop fail2ban; apt purge -y fail2ban ;;
    esac
}

# --- 主循环 ---
check_env
while true; do
    show_sys_info
    echo -e "${CYAN}0. 脚本使用说明 & 快捷指令${NC}"
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
        1) github_key ;;
        2) manage_ssh ;;
        3) manage_ufw ;;
        4) manage_f2b ;;
        5) update_script ;;
        q) exit 0 ;;
    esac
    read -p "回车返回菜单..."
done
