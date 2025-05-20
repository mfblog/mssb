#!/bin/bash

# 记录当前时间
echo "[$(date)] 开始更新 Sing-box..."

# 判断 CPU 架构
if [[ $(uname -m) == "aarch64" ]]; then
    TARGETARCH="arm64"
    echo "[$(date)] 检测到 CPU 架构为 armv8。"
elif [[ $(uname -m) == "x86_64" ]]; then
    TARGETARCH="amd64"
    echo "[$(date)] 检测到 CPU 架构为 amd64。"
else
    TARGETARCH="未知"
    echo "[$(date)] 无法识别的 CPU 架构：$(uname -m)，脚本退出。"
    exit 1  # 退出状态为 1，表示错误退出
fi

SING_BOX_URL=""https://github.com/herozmy/StoreHouse/releases/download/sing-box/sing-box-puernya-linux-${TARGETARCH}.tar.gz""

# 下载最新的 sing-box
echo "[$(date)] 正在从 $SING_BOX_URL 下载 Sing-box..."
if wget -O /tmp/sing-box.tar.gz $SING_BOX_URL; then
    echo "[$(date)] Sing-box 下载成功。"
else
    echo "[$(date)] Sing-box 下载失败，请检查网络连接或 URL 是否正确。"
    exit 1
fi

# 解压并安装 sing-box
echo "[$(date)] 正在解压 Sing-box..."
if tar -zxvf /tmp/sing-box.tar.gz -C /usr/local/bin; then
    echo "[$(date)] Sing-box 解压成功。"
else
    echo "[$(date)] Sing-box 解压失败，请检查压缩包是否正确。"
    exit 1
fi

# 设置执行权限
echo "[$(date)] 正在设置 Sing-box 可执行权限..."
if chmod +x /usr/local/bin/sing-box; then
    echo "[$(date)] 设置执行权限成功。"
else
    echo "[$(date)] 设置执行权限失败，请检查文件路径和权限设置。"
    exit 1
fi

# 追加 Git 克隆命令，更新 UI 文件
echo "[$(date)] 正在从 GitHub 克隆最新的 UI 文件..."
if git clone --depth=1 https://github.com/metacubex/metacubexd.git -b gh-pages /tmp/ui; then
    cp -r /tmp/ui/* /mssb/sing-box/ui/
    echo "[$(date)] UI 文件克隆成功。"
else
    echo "[$(date)] UI 文件克隆失败，请检查 GitHub URL 或网络连接。"
    exit 1
fi

# 更新完成日志
echo "[$(date)] Sing-box 更新并重启成功，UI 文件已更新。"

# 清理临时文件
rm -rf /tmp/*

# 重启 sing-box 服务
echo "[$(date)] 正在通过 Supervisor 重启 Sing-box 服务..."
if supervisorctl restart sing-box && systemctl restart sing-box-router; then
    echo "[$(date)] Sing-box 服务重启成功。"
else
    echo "[$(date)] Sing-box 服务重启失败，请检查 Supervisor 配置。"
    exit 1
fi


