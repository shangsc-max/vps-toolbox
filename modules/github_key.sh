#!/bin/bash

read -p "请输入 GitHub 用户名：" GH_USER

URL="https://github.com/${GH_USER}.keys"

if curl -fsSL "$URL" > /tmp/gh_keys && [ -s /tmp/gh_keys ]; then
    mkdir -p ~/.ssh
    cat /tmp/gh_keys >> ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    echo "✅ SSH 密钥导入成功"
else
    echo "❌ 用户不存在或没有 SSH 公钥"
fi
