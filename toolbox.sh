#!/bin/bash

# ====================================================
# 脚本名称: Shang-Max VPS 全能工具箱
# 作者: Shang-Max
# 适用系统: Ubuntu / Debian
# ====================================================

# 定义颜色，让界面更好看
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

# --- 0. 环境自检与组件安装 ---
# 这个函数会在脚本启动时自动运行，安装必要的“零件”
function check_env() {
    # 检查是否为 root 用户
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：请使用 root 用户运行此脚本！提示：输入 sudo su 切换${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在检查并更新系统组件...${NC}"
    apt update -y > /dev/null 2>&1
    # 自动安装小白必备工具：curl(下载), ufw(防火墙), fail2ban(防爆破), lsb-release(看版本)
    for pkg in curl wget ufw fail2ban lsb-release git; do
        if ! command -v $pkg &> /dev/null; then
            apt install -y $pkg > /dev/null 2>&1
        fi
    done
}

# --- 1. 系统信息展示 (汉字版) ---
function show_sys_info() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "           ${GREEN}Shang-Max VPS 工具箱${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "主机名称:   $(hostname)"
    echo -e "操作系统:   $(lsb_release -d | cut -f2-)"
    echo -e "处理器(CPU): $(lscpu | grep 'Model name' | cut -f2 -d: | sed 's/^[ \t]*//')"
    echo -e "运行内存:   $(free -h | awk 'NR==2{print $2}') (总共) / $(free -h | awk 'NR==2{print $3}') (已用)"
    echo -e "本机 IP:    $(curl -s ifconfig.me || echo '获取失败')"
    echo -e "${BLUE}==================================================${NC}"
}

# --- 2. GitHub 密钥管理 ---
function github_key() {
    while true; do
        read -p "请输入 GitHub 用户名 (或输入 q 退出): " gh_user
        if [[ "$gh_user" == "q" ]]; then break; fi
        
        # 自动检测用户名是否有效 (检查返回状态码)
        status=$(curl -o /dev/null -s -w "%{http_code}" https://github.com/$gh_user.keys)
        if [ "$status" -eq 200 ]; then
            mkdir -p ~/.ssh && chmod 700 ~/.ssh
            curl -L https://github.com/$gh_user.keys >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
            echo -e "${GREEN}成功！已拉取 $gh_user 的公钥。你现在可以尝试用密钥登录了。${NC}"
            break
        else
            echo -e "${RED}用户名无效或该用户未设置公钥，请重新输入。${NC}"
        fi
    done
}

# --- 3. SSH 管理 ---
function manage_ssh() {
    echo -e "1. 修改 SSH 端口"
    echo -e "2. 开启密钥登录并禁用密码(更安全)"
    echo -e "3. 重启 SSH 服务"
    read -p "请选择: " ssh_opt
    case $ssh_opt in
        1)
            read -p "请输入新端口号 (1024-65535): " new_port
            sed -i "s/^#\?Port.*/Port $new_port/" /etc/ssh/sshd_config
            ufw allow "$new_port"/tcp # 自动帮你在防火墙放行新端口，防止断连
            echo -e "${GREEN}端口已改为 $new_port。重启 SSH 后生效。${NC}"
            ;;
        2)
            sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
            echo -e "${GREEN}已禁用密码登录，请确保你已上传密钥，否则将无法登录！${NC}"
            ;;
        3) systemctl restart ssh && echo -e "${GREEN}SSH 已重启。${NC}" ;;
    esac
}

# --- 4. 防火墙 (UFW) 管理 ---
function manage_ufw() {
    # 获取当前正在运行的 SSH 端口，防止自锁
    current_ssh=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d: -f2 | head -n1)
    
    echo -e "1. 安装/启动防火墙"
    echo -e "2. 放行端口 (例如: 80/tcp 或 53/udp)"
    echo -e "3. 禁用端口"
    echo -e "4. 关闭/卸载防火墙"
    read -p "请选择: " ufw_opt
    case $ufw_opt in
        1)
            ufw allow "$current_ssh"/tcp # 自动保护 SSH 端口
            ufw --force enable
            echo -e "${GREEN}防火墙已启动，并自动放行了当前 SSH 端口 $current_ssh${NC}"
            ;;
        2)
            read -p "输入端口和协议 (如 80/tcp): " p_proto
            ufw allow $p_proto
            ;;
        3)
            read -p "输入要禁用的端口和协议: " p_proto
            # 判断是否是当前的 SSH 端口，防止自杀
            if [[ "$p_proto" == *"$current_ssh"* ]]; then
                echo -e "${RED}警告：不能禁用当前 SSH 端口！${NC}"
            else
                ufw delete allow $p_proto
            fi
            ;;
        4) ufw disable ;;
    esac
    # Docker 提示：UFW 默认不拦截 Docker 映射的端口，这里建议小白使用默认设置
    echo -e "${YELLOW}提示: 如果你使用 Docker，请注意 Docker 会直接操作 iptables，UFW 有时可能失效。${NC}"
}

# --- 5. Fail2Ban 管理 ---
function manage_f2b() {
    echo -e "1. 安装并开启基础保护 (3次错封24小时)"
    echo -e "2. 查看当前封禁的 IP 列表"
    echo -e "3. 设置 IP 白名单 (不封禁自己)"
    echo -e "4. 停止并卸载 Fail2Ban"
    read -p "请选择: " f2b_opt
    case $f2b_opt in
        1)
            apt install -y fail2ban
            # 写入基础配置
            cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 86400
EOF
            systemctl restart fail2ban
            echo -e "${GREEN}Fail2Ban 已启动，策略：10分钟内错3次，封禁24小时。${NC}"
            ;;
        2) fail2ban-client status sshd ;;
        3) 
            read -p "输入要加白名单的 IP: " white_ip
            sed -i "/^ignoreip/d" /etc/fail2ban/jail.local
            echo "ignoreip = 127.0.0.1/8 ::1 $white_ip" >> /etc/fail2ban/jail.local
            systemctl restart fail2ban
            ;;
        4) systemctl stop fail2ban && apt purge -y fail2ban ;;
    esac
}

# --- 主循环菜单 ---
check_env
while true; do
    show_sys_info
    echo -e "1. GitHub 一键拉取密钥"
    echo -e "2. SSH 安全管理"
    echo -e "3. 防火墙 (UFW) 管理"
    echo -e "4. Fail2Ban (防爆破) 管理"
    echo -e "0. 退出脚本"
    echo -ne "${YELLOW}请输入数字选择功能: ${NC}"
    read main_opt
    case $main_opt in
        1) github_key ;;
        2) manage_ssh ;;
        3) manage_ufw ;;
        4) manage_f2b ;;
        0) exit 0 ;;
        *) echo -e "${RED}输入有误，请重新输入${NC}" ;;
    esac
    echo -e "${BLUE}按任意键返回主菜单...${NC}"
    read -n 1
done
