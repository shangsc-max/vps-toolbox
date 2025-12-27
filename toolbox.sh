#!/bin/bash

# ====================================================
# 脚本名称: Shang-Max VPS 全能工具箱 (最终版)
# 作者: Shang-Max
# GitHub: https://github.com/shang-max/vps-toolbox
# ====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- 1. 环境准备与自检 ---
function check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用 root 用户运行！${NC}"
        exit 1
    fi
    echo -e "${YELLOW}正在检查并安装必要组件 (curl, ufw, fail2ban)...${NC}"
    apt update -y > /dev/null 2>&1
    apt install -y curl wget ufw fail2ban lsb-release sed > /dev/null 2>&1
}

# --- 2. 系统信息展示 ---
function show_sys_info() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "           ${GREEN}Shang-Max VPS 工具箱${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "主机名称:   $(hostname)"
    echo -e "系统版本:   $(lsb_release -d | cut -f2-)"
    echo -e "CPU 型号:   $(lscpu | grep 'Model name' | cut -f2 -d: | sed 's/^[ \t]*//')"
    echo -e "内存状态:   $(free -m | awk 'NR==2{printf "已用 %sMB / 总共 %sMB", $3,$2}')"
    echo -e "公网 IP:    $(curl -s ifconfig.me)"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 3. GitHub 密钥拉取 ---
function github_key() {
    echo -e "${YELLOW}--- GitHub 密钥拉取 ---${NC}"
    read -p "请输入 GitHub 用户名 (输入 q 退出): " gh_user
    [[ "$gh_user" == "q" ]] && return
    
    status=$(curl -o /dev/null -s -w "%{http_code}" https://github.com/$gh_user.keys)
    if [ "$status" -eq 200 ]; then
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        curl -L https://github.com/$gh_user.keys >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo -e "${GREEN}成功！已将 $gh_user 的密钥加入授权列表。${NC}"
    else
        echo -e "${RED}错误：找不到用户 $gh_user，请检查拼写。${NC}"
    fi
}

# --- 4. SSH 管理 ---
function manage_ssh() {
    echo -e "${YELLOW}--- SSH 管理 ---${NC}"
    echo -e "1. 修改 SSH 端口\n2. 开启密钥登录并禁用密码\n3. 重启 SSH 服务"
    read -p "请选择: " ssh_opt
    case $ssh_opt in
        1)
            read -p "输入新端口 (1-65535): " new_port
            sed -i "s/^#\?Port.*/Port $new_port/" /etc/ssh/sshd_config
            ufw allow "$new_port"/tcp > /dev/null 2>&1
            echo -e "${GREEN}端口已设为 $new_port (已自动在防火墙放行)${NC}"
            ;;
        2)
            sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
            echo -e "${GREEN}密码登录已禁用，请确保你已拉取 GitHub 密钥！${NC}"
            ;;
        3) systemctl restart ssh && echo -e "${GREEN}服务已重启${NC}" ;;
    esac
}

# --- 5. 防火墙 (UFW) 管理 ---
function manage_ufw() {
    ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d: -f2 | head -n1)
    echo -e "${YELLOW}--- 防火墙管理 ---${NC}"
    echo -e "1. 启用防火墙\n2. 放行端口 (需区分 TCP/UDP)\n3. 禁用端口\n4. 重启防火墙\n5. 关闭并卸载\n6. 查看当前规则"
    read -p "请选择: " fw_opt
    case $fw_opt in
        1)
            ufw allow "$ssh_port"/tcp
            ufw --force enable
            echo -e "${GREEN}防火墙开启，已放行 SSH 端口 $ssh_port${NC}"
            ;;
        2)
            read -p "输入端口 (如 80): " p
            read -p "协议 (1.tcp 2.udp 3.两者): " proto
            [[ $proto == "1" ]] && ufw allow $p/tcp
            [[ $proto == "2" ]] && ufw allow $p/udp
            [[ $proto == "3" ]] && ufw allow $p
            ;;
        3)
            read -p "输入要禁用的端口: " p
            if [[ "$p" == "$ssh_port" ]]; then
                echo -e "${RED}禁止封锁当前 SSH 端口！${NC}"
            else
                ufw delete allow $p
            fi
            ;;
        4) ufw reload ;;
        5) ufw disable && echo -e "${YELLOW}防火墙已关闭${NC}" ;;
        6) ufw status verbose ;;
    esac
    echo -e "${BLUE}提示: Docker 容器端口不受 UFW 限制，请在创建容器时注意安全。${NC}"
}

# --- 6. Fail2Ban 管理 ---
function manage_f2b() {
    echo -e "${YELLOW}--- Fail2Ban 管理 ---${NC}"
    echo -e "1. 安装并开启基础防御 (3次错封24小时)\n2. 查看封禁名单\n3. 解封指定 IP\n4. 设置 IP 白名单\n5. 停止并卸载"
    read -p "请选择: " f2b_opt
    case $f2b_opt in
        1)
            cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
findtime = 600
EOF
            systemctl restart fail2ban
            echo -e "${GREEN}防御已开启。${NC}"
            ;;
        2) fail2ban-client status sshd ;;
        3) read -p "输入 IP: " ip; fail2ban-client set sshd unbanip $ip ;;
        4) 
            read -p "输入白名单 IP: " ip
            sed -i "/^ignoreip/d" /etc/fail2ban/jail.local
            echo "ignoreip = 127.0.0.1/8 ::1 $ip" >> /etc/fail2ban/jail.local
            systemctl restart fail2ban
            ;;
        5) systemctl stop fail2ban && apt purge -y fail2ban ;;
    esac
}

# --- 7. 主循环 ---
check_env
while true; do
    show_sys_info
    echo -e "1. GitHub 拉取密钥"
    echo -e "2. SSH 管理"
    echo -e "3. 防火墙 (UFW) 管理"
    echo -e "4. Fail2Ban (防暴力破解) 管理"
    echo -e "0. 退出"
    echo -e "--------------------------------------------------"
    read -p "请输入数字: " main_choice
    case $main_choice in
        1) github_key ;;
        2) manage_ssh ;;
        3) manage_ufw ;;
        4) manage_f2b ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项，请重新选择${NC}" ;;
    esac
    echo -e "${BLUE}按回车键返回主菜单...${NC}"
    read
done
