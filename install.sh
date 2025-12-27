#!/bin/bash
# VPS 工具箱 v1.0
# 作者：shang-max

clear

BASE_DIR=$(cd "$(dirname "$0")" && pwd)

source $BASE_DIR/core/utils.sh
source $BASE_DIR/core/system_info.sh
source $BASE_DIR/core/detect_env.sh
source $BASE_DIR/core/update_system.sh

cat $BASE_DIR/assets/logo.txt

check_root
show_system_info
detect_env
update_system_menu

while true; do
    echo
    echo "========= VPS 工具箱 主菜单 ========="
    echo "1. GitHub 一键拉取 SSH 密钥"
    echo "2. SSH 管理"
    echo "3. 防火墙管理（UFW）"
    echo "4. Fail2Ban 防暴力破解"
    echo "0. 退出"
    echo "==================================="
    read -p "请输入选项：" choice

    case $choice in
        1) bash $BASE_DIR/modules/github_key.sh ;;
        2) bash $BASE_DIR/modules/ssh_manage.sh ;;
        3) bash $BASE_DIR/modules/firewall.sh ;;
        4) bash $BASE_DIR/modules/fail2ban.sh ;;
        0) exit 0 ;;
        *) echo "❌ 无效选项，请重新输入" ;;
    esac
done
