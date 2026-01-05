#!/bin/bash

# ====================================================
# 脚本名称: [SM] Shang-Max VPS 工具箱 (GitHub 旗舰版)
# 作者: Shang-Max
# GitHub: https://github.com/shangsc-max/vps-toolbox
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 核心工具函数 ---
smart_apt() {
    local pkg=$1
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock
    dpkg --configure -a >/dev/null 2>&1
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        echo -e "${CYAN}正在安装 $pkg ...${NC}"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
    fi
}

check_env() {
    [[ $EUID -ne 0 ]] && echo -e "${RED}错误：请使用 root 用户运行！${NC}" && exit 1
    if [[ "$0" != "/usr/local/bin/sm" ]]; then
        cp "$0" /usr/local/bin/sm && chmod +x /usr/local/bin/sm
        ln -sf /usr/local/bin/sm /usr/local/bin/SM
    fi
}

# --- 状态获取 ---
get_ufw_status() { ufw status 2>/dev/null | grep -q "active" && echo -e "${GREEN}开启${NC}" || echo -e "${RED}关闭${NC}"; }
get_f2b_status() { systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}运行中${NC}" || echo -e "${RED}已停止${NC}"; }
get_ssh_root_status() { grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && echo -e "${RED}允许${NC}" || echo -e "${GREEN}禁止${NC}"; }
get_ssh_port() { grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22"; }

# --- 功能模块：SSH 安全增强 ---
manage_ssh() {
    while true; do
        clear
        echo -e "${YELLOW}--- SSH 安全增强管理 ---${NC}"
        echo -e "当前端口: $(get_ssh_port)  |  Root登录: $(get_ssh_root_status)"
        echo -e "--------------------------------------------------"
        echo -e "1. 修改 SSH 端口"
        echo -e "2. 禁止/允许 Root 密码登录"
        echo -e "3. 设置 SSH 闲置 10 分钟自动断开"
        echo -e "4. 查看最近 10 条登录失败记录"
        echo -e "5. 重启 SSH 服务"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) read -p "输入新端口: " p; sed -i "s/^#\?Port.*/Port $p/" /etc/ssh/sshd_config; ufw allow "$p"/tcp; echo -e "${GREEN}已修改并放行 UFW 端口${NC}"; sleep 1 ;;
            2) 
                if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
                    sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
                    echo -e "${GREEN}Root 登录已禁止 (请确保已设置密钥登录)${NC}"
                else
                    sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
                    echo -e "${YELLOW}Root 登录已允许${NC}"
                fi; sleep 2 ;;
            3)
                sed -i "/ClientAliveInterval/d" /etc/ssh/sshd_config
                sed -i "/ClientAliveCountMax/d" /etc/ssh/sshd_config
                echo "ClientAliveInterval 600" >> /etc/ssh/sshd_config
                echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config
                echo -e "${GREEN}已开启 600 秒超时自动断开${NC}"; sleep 2 ;;
            4) lastb -n 10; read -p "按回车继续..." ;;
            5) systemctl restart ssh && echo -e "${GREEN}服务已重启${NC}"; sleep 1 ;;
            0) break ;;
        esac
    done
}

# --- 功能模块：防火墙 (UFW) 进阶 ---
manage_ufw() {
    while true; do
        clear
        echo -e "${YELLOW}--- 防火墙 (UFW) 策略管理 ---${NC}"
        echo -e "1. 开启防火墙 (自动放行当前 SSH 端口)"
        echo -e "2. 关闭防火墙"
        echo -e "3. 一键放行 Web 常用端口 (80, 443)"
        echo -e "4. 一键放行 Docker/常用协议 (8080, 5000, 1194)"
        echo -p "5. 手动输入端口放行"
        echo -e "6. 查看实时拦截日志"
        echo -e "0. 返回主菜单"
        read -p "选择操作: " opt
        case $opt in
            1) 
                smart_apt "ufw"
                port=$(get_ssh_port)
                ufw allow "$port"/tcp && echo "y" | ufw enable
                echo -e "${GREEN}防火墙已开启并保护 SSH${NC}"; sleep 2 ;;
            2) ufw disable; sleep 1 ;;
            3) ufw allow 80/tcp && ufw allow 443/tcp && echo -e "${GREEN}HTTP/HTTPS 已放行${NC}"; sleep 1 ;;
            4) ufw allow 8080/tcp && ufw allow 5000/tcp && ufw allow 1194/udp; echo -e "${GREEN}常用端口已放行${NC}"; sleep 1 ;;
            5) read -p "输入端口号: " p; ufw allow "$p"; sleep 1 ;;
            6) echo -e "${CYAN}按 Ctrl+C 退出查看记录：${NC}"; tail -f /var/log/ufw.log ;;
            0) break ;;
        esac
    done
}

# --- 功能模块：GitHub 密钥同步 (防锁死增强版) ---
manage_github_keys() {
    clear
    echo -e "${YELLOW}--- GitHub 密钥同步管理 ---${NC}"
    read -p "请输入您的 GitHub 用户名: " username
    if [[ -z "$username" ]]; then echo "取消同步"; return; fi
    
    echo -e "1. 追加模式 (保留现有密钥，最安全)"
    echo -e "2. 覆盖模式 (删除旧密钥，仅保留 GitHub 密钥)"
    read -p "请选择模式: " mode
    
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    case $mode in
        1) wget -qO- https://github.com/"$username".keys >> ~/.ssh/authorized_keys ;;
        2) wget -qO- https://github.com/"$username".keys > ~/.ssh/authorized_keys ;;
        *) echo "无效选择"; return ;;
    esac
    
    chmod 600 ~/.ssh/authorized_keys
    echo -e "${GREEN}密钥同步完成！您可以尝试通过 GitHub 关联的私钥登录了。${NC}"
    sleep 2
}

# --- 主界面 ---
check_env
while true; do
    clear
    ipv4=$(curl -s4 --connect-timeout 2 ifconfig.me || echo "无")
    echo -e "${BLUE}==================================================${NC}"
    echo -e "          ${YELLOW}[SM]${NC} ${GREEN}Shang-Max VPS 增强工具箱${NC}"
    echo -e "系统版本:   $(lsb_release -d | cut -f2- 2>/dev/null || echo "Debian/Ubuntu")"
    echo -e "公网 IPv4:  ${CYAN}$ipv4${NC}"
    echo -e "SSH 端口:   $(get_ssh_port)      Root 登录: $(get_ssh_root_status)"
    echo -e "防火墙:     $(get_ufw_status)      防爆破:    $(get_f2b_status)"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "1. SSH 安全管理      2. 防火墙 (UFW) 管理"
    echo -e "3. Fail2Ban 防爆破   4. GitHub 密钥同步"
    echo -e "5. ${CYAN}更新重启脚本${NC}      q. 退出脚本"
    echo -e "--------------------------------------------------"
    read -p "请输入选项: " choice
    case "$choice" in
        1) manage_ssh ;;
        2) manage_ufw ;;
        3) manage_f2b ;; # 沿用之前的 fail2ban 逻辑
        4) manage_github_keys ;;
        5) wget -qO /usr/local/bin/sm https://raw.githubusercontent.com/shangsc-max/vps-toolbox/main/toolbox.sh && chmod +x /usr/local/bin/sm && exec sm ;;
        q) exit 0 ;;
    esac
done
