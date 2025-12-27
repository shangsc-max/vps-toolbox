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
NC='\033[0m'

# --- 1. 环境自检 & 快捷键配置 ---
function check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用 root 用户运行！${NC}"
        exit 1
    fi
    # 始终确保 /usr/local/bin/sm 是最新的
    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm
        chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi
}

# --- 实时获取防火墙状态 ---
get_ufw_status() {
    # 使用 ufw status 直接判断，不留缓存
    if ufw status | grep -q "Status: active"; then
        echo -e "${GREEN}开启${NC}"
    else
        echo -e "${RED}关闭${NC}"
    fi
}

# --- 实时获取 Fail2Ban 状态 ---
get_f2b_status() {
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
}

# --- 2. 系统信息显示 ---
function show_sys_info() {
    clear
    # 获取本地 IPv4
    ipv4=$(curl -s4 ifconfig.me || echo "无")
    # 获取本地 IPv6
    ipv6=$(curl -s6 ifconfig.me || echo "无")

    echo -e "${BLUE}==================================================${NC}"
    echo -e "         ${YELLOW}[SM]${NC} ${GREEN}Shang-Max VPS 全能工具箱${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "主机名称:   $(hostname)"
    echo -e "系统版本:   $(lsb_release -d | cut -f2- 2>/dev/null || echo "Debian/Ubuntu")"
    echo -e "内存状态:   $(free -m | awk 'NR==2{printf "已用 %sMB / 总共 %sMB", $3,$2}')"
    
    # 智能显示 IP
    if [ "$ipv4" != "无" ]; then
        echo -e "公网 IPv4:  ${CYAN}$ipv4${NC}"
    fi
    if [ "$ipv6" != "无" ]; then
        echo -e "公网 IPv6:  ${CYAN}$ipv6${NC}"
    fi

    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "防火墙状态: $(get_ufw_status)"
    echo -e "防爆破状态: $(get_f2b_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${GREEN}提示：输入 ${YELLOW}sm${GREEN} 或 ${YELLOW}SM${GREEN} 可随时进入此界面${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 3. 更新脚本 ---
function update_script() {
    echo -e "${YELLOW}正在从 GitHub 获取最新版本...${NC}"
    wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh
    chmod +x /usr/local/bin/sm
    echo -e "${GREEN}脚本更新完成！请直接输入 sm 重新运行。${NC}"
    exit 0
}

# --- 4. GitHub 密钥 ---
function github_key() {
    read -p "请输入 GitHub 用户名 (q退出): " gh_user
    [[ "$gh_user" == "q" ]] && return
    user_check=$(curl -s -o /dev/null -L -w "%{http_code}" "https://github.com/$gh_user")
    if [ "$user_check" -ne 200 ]; then
        echo -e "${RED}错误：未找到用户${NC}"
    else
        key_content=$(curl -s "https://github.com/$gh_user.keys")
        if [ -z "$key_content" ]; then
            echo -e "${YELLOW}提示：该用户没上传过密钥${NC}"
        else
            mkdir -p ~/.ssh && echo "$key_content" >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
            echo -e "${GREEN}成功拉取密钥！${NC}"
        fi
    fi
}

# --- 5. SSH 管理 ---
function manage_ssh() {
    echo -e "${YELLOW}--- SSH 管理 ---${NC}"
    echo -e "1. 修改 SSH 端口\n2. 开启密钥并禁用密码\n3. 重启 SSH 服务"
    read -p "选择: " opt
    case $opt in
        1) read -p "新端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; ufw allow $p/tcp; echo -e "${GREEN}完成${NC}" ;;
        2) sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config; echo -e "${GREEN}密码已禁用${NC}" ;;
        3) systemctl restart ssh && echo -e "${GREEN}已重启${NC}" ;;
    esac
}

# --- 6. 防火墙管理 ---
function manage_ufw() {
    echo -e "${YELLOW}--- 防火墙管理 [状态: $(get_ufw_status)] ---${NC}"
    ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d: -f2 | head -n1)
    echo -e "1. 启用防火墙\n2. 关闭防火墙\n3. 放行端口\n4. 禁用端口\n5. 查看详细规则"
    read -p "选择: " opt
    case $opt in
        1) ufw allow "$ssh_port"/tcp; ufw --force enable ;;
        2) ufw disable ;;
        3) echo -e "${YELLOW}示例: 80/tcp${NC}"; read -p "输入端口/协议: " p; ufw allow $p ;;
        4) read -p "输入要禁用的: " p; [[ "$p" != *"$ssh_port"* ]] && ufw delete allow $p ;;
        5) ufw status verbose ;;
    esac
}

# --- 7. Fail2Ban ---
function manage_f2b() {
    echo -e "${YELLOW}--- Fail2Ban 防御 [状态: $(get_f2b_status)] ---${NC}"
    echo -e "1. 安装/重置防御配置\n2. 查看封禁列表\n3. 停止/开启服务\n4. 解封 IP\n5. 卸载 Fail2Ban"
    read -p "选择: " opt
    case $opt in
        1) 
            apt install -y fail2ban > /dev/null 2>&1
            cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 86400
EOF
            systemctl restart fail2ban
            echo -e "${GREEN}防御配置已生效${NC}" 
            ;;
        2) fail2ban-client status sshd ;;
        3) 
            if systemctl is-active --quiet fail2ban; then
                systemctl stop fail2ban && echo -e "${YELLOW}Fail2Ban 已停止${NC}"
            else
                systemctl start fail2ban && echo -e "${GREEN}Fail2Ban 已启动${NC}"
            fi
            ;;
        4) read -p "输入 IP: " ip; fail2ban-client set sshd unbanip $ip ;;
        5) systemctl stop fail2ban; apt purge -y fail2ban; echo -e "${YELLOW}已卸载${NC}" ;;
    esac
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
    echo -e "0. 退出"
    echo -e "--------------------------------------------------"
    read -p "请输入数字选择功能: " choice
    case $choice in
        1) github_key ;;
        2) manage_ssh ;;
        3) manage_ufw ;;
        4) manage_f2b ;;
        5) update_script ;;
        0) exit 0 ;;
    esac
    read -p "回车继续..."
done
