#!/bin/bash

detect_env() {
    echo
    echo "🔍 正在检测环境..."

    if command -v docker >/dev/null 2>&1; then
        echo "⚠ 检测到 Docker，防火墙可能影响容器端口"
    else
        echo "✅ 未检测到 Docker"
    fi

    if command -v ufw >/dev/null 2>&1; then
        echo "✅ 已安装 UFW 防火墙"
    else
        echo "ℹ 尚未安装 UFW"
    fi
}
