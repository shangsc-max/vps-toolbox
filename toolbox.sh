#!/bin/bash

# ====================================================
# 脚本名称: Shang-Max VPS 全能工具箱 (增强验证版)
# 作者: Shang-Max
# GitHub: https://github.com/shangsc-max/vps-toolbox
# ====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- 1. 环境准备与组件检测 ---
function check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用 root 用户运行！${NC}"
        exit 1
    fi
    # 自动安装必要组件 (静默安装)
    apt update -y > /dev/null 2>&1
    apt install -y curl wget ufw fail2ban lsb-release sed > /dev/null 2>&1
}

# --- 2. 系统信息显示 (汉字版) ---
function show_sys_info() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "           ${GREEN}Shang-Max VPS 工具箱${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "主机名称:   $(hostname)"
    echo -e "操作系统:   $(lsb_release -d | cut -f2-)"
    echo -e "CPU 型号:   $(lscpu | grep 'Model name' | cut -f2 -d: | sed 's/^[ \t]*//')"
    echo -e "内存状态:   $(free -m | awk 'NR==2{printf "已用 %sMB / 总共 %sMB", $3,$2}')"
    echo -e "公网 IP:    $(curl -s ifconfig.me)"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 3. 一键更新脚本 ---
function update_script() {
    echo -e "${YELLOW}正在从 GitHub 获取最新版本...${NC}"
    # 这里使用的是你正确的用户名 shangsc-max
    wget -N https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh
    chmod +x toolbox.sh
    echo -e "${GREEN}脚本更新完成！请重新运行。${NC}"
    exit 0
}

# --- 4. GitHub 密钥拉取 (增强验证) ---
function github_key() {
    echo -e "${YELLOW}--- GitHub 密钥同步 ---${NC}"
    read -p "请输入 GitHub 用户名 (输入 q 退出): " gh_user
    [[ "$gh_user" == "q" ]] && return

    # 1. 验证用户是否存在
    user_check=$(curl -s -o /dev/null -L -w "%{http_code}" "https://github.com/$gh_user")
    
    if [ "$user_check" -ne 200 ]; then
        echo -e "${RED}错误：未找到用户 [$gh_user]，请确认用户名是否正确。${NC}"
    else
        # 2. 用户存在，尝试拉取密钥
        key_content=$(curl -s "https://github.com/$gh_user.keys")
        if [ -z "$key_content" ]; then
            echo -e "${YELLOW}提示：用户 [$gh_user] 存在，但他没有在 GitHub 上传过任何公钥。${NC}"
        else
            mkdir -p ~/.ssh && chmod 700 ~/.ssh
            echo "$key_content" >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
            echo -e "${GREEN}成功！已将 $gh_user 的密钥同步到当前 VPS。${NC}"
        fi
    fi
}

# --- 5. SSH 管理 ---
function manage_ssh() {
    echo -e "${YELLOW}--- SSH 管理 ---${NC}"
    echo -e "1. 修改 SSH 端口\n2. 开启密钥登录并禁用密码\n3. 重启 SSH 服务"
    read -p "请选择: " ssh_opt
    case $ssh_opt in
        1)
            read -p "请输入新端口号: " new_port
            sed -i "s/^#\?Port.*/Port $new_port/" /etc/ssh/sshd_config
            ufw allow "$new_port"/tcp > /dev/null 2>&1
            echo -e "${GREEN}端口已修改为 $new_port，且已自动在防火墙放行。${NC}"
            ;;
        2)
            # 开启公钥登录，禁用密码登录
            sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
            sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
            echo -e "${GREEN}设置成功：已禁用密码登录，请务必确认密钥已拉取，否则会无法登录！${NC}"
            ;;
        3) systemctl restart ssh && echo -e "${GREEN}SSH 服务已重启。${NC}" ;;
    esac
}

# --- 6. 防火墙 (UFW) 管理 ---
function manage_ufw() {
    # 自动获取当前 SSH 端口，防止自锁
    ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d: -f2 | head -n1)
    
    echo -e "${YELLOW}--- 防火墙管理 ---${NC}"
    echo -e "1. 启用防火墙\n2. 放行端口\n3. 禁用端口\n4. 关闭防火墙\n5. 查看当前状态"
    read -p "请选择: " fw_opt
    case $fw_opt in
        1)
            ufw allow "$ssh_port"/tcp
            ufw --force enable
            echo -e "${GREEN}防火墙已启动，并放行了当前 SSH 端口 $ssh_port${NC}"
            ;;
        2)
            echo -e "${YELLOW}提示：放行请手动输入协议，例如 '80/tcp' 或 '53/udp'${NC}"
            read -p "请输入放行规则: " p_proto
            ufw allow $p_proto
            ;;
        3)
            read -p "请输入要禁用的端口/协议 (如 80/tcp): " p_proto
            if [[ "$p_proto" == *"$ssh_port"* ]]; then
                echo -e "${RED}禁止封锁当前 SSH 端口 $ssh_port！${NC}"
            else
                ufw delete allow $p_proto
            fi
            ;;
        4) ufw disable ;;
        5) ufw status ;;
    esac
}

# --- 7. Fail2Ban 管理 ---
function manage_f2b() {
    echo -e "${YELLOW}--- Fail2Ban 防御 ---${NC}"
    echo -e "1. 安装基础防御 (3次错封24小时)\n2. 查看封禁列表\n3. 解封 IP\n4. 卸载 Fail2Ban"
    read -p "选择: " f2b_opt
    case $f2b_opt in
        1)
            apt install -y fail2ban
            cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 86400
findtime = 600
EOF
            systemctl restart fail2ban
            echo -e "${GREEN}Fail2Ban 基础防御已开启。${NC}"
            ;;
        2) fail2ban-client status sshd ;;
        3) read -p "输入解封 IP: " ip; fail2ban-client set sshd unbanip $ip ;;
        4) apt purge -y fail2ban && echo -e "${YELLOW}已卸载。${NC}" ;;
    esac
}

# --- 主循环控制 ---
check_env
while true; do
    show_sys_info
    echo -e "1. GitHub 拉取密钥 (增强验证)"
    echo -e "2. SSH 管理"
    echo -e "3. 防火墙管理 (手动区分 tcp/udp)"
    echo -e "4. Fail2Ban 防爆破"
    echo -e "5. 更新脚本"
    echo -e "0. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入数字选择功能: " main_choice
    case $main_choice in
        1) github_key ;;
        2) manage_ssh ;;
        3) manage_ufw ;;
        4) manage_f2b ;;
        5) update_script ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项，请重新选择${NC}" ;;
    esac
    read -p "按回车键继续..."
done
