#!/bin/bash

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ 请使用 root 用户运行脚本"
        exit 1
    fi
}
