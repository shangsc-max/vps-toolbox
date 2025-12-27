#!/bin/bash

show_system_info() {
    echo
    echo "========= 服务器基本信息 ========="
    echo "系统：$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    echo "CPU 核心数：$(nproc)"
    echo "内存：$(free -h | awk '/Mem/ {print $2}')"
    echo "磁盘：$(df -h / | awk 'NR==2 {print $2}')"
    echo "主机名：$(hostname)"
    echo "本机 IP：$(curl -s ip.sb || curl -s ifconfig.me)"
    echo "当前 SSH 端口：$(ss -tnlp | grep sshd | awk -F: '{print $NF}' | head -n1)"
    echo "=================================="
}
