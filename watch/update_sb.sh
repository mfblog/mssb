#!/bin/bash

# 记录当前时间
echo "[$(date)] 开始更新 Sing-box..."

# 定义颜色变量
yellow="\033[33m"
reset="\033[0m"

# 获取系统架构
# 检测系统 CPU 架构，并返回标准格式（适用于多数构建/下载脚本）
detect_architecture() {
    case "$(uname -m)" in
        x86_64)     echo "amd64" ;;    # 64 位 x86 架构
        aarch64)    echo "arm64" ;;    # 64 位 ARM 架构
        armv7l)     echo "armv7" ;;    # 32 位 ARM 架构（常见于树莓派）
        armhf)      echo "armhf" ;;    # ARM 硬浮点
        s390x)      echo "s390x" ;;    # IBM 架构
        i386|i686)  echo "386" ;;      # 32 位 x86 架构
        *)
            echo -e "${yellow}不支持的CPU架构: $(uname -m)${reset}"
            exit 1
            ;;
    esac
}
arch=$(detect_architecture)
SING_BOX_URL=""https://github.com/herozmy/StoreHouse/releases/download/sing-box/sing-box-puernya-linux-${arch}.tar.gz""

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
if git clone --depth=1 https://github.com/Zephyruso/zashboard.git -b gh-pages /tmp/ui; then
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


