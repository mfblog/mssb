#!/bin/bash

# 记录当前时间
echo "[$(date)] 开始更新 mihomo..."

# 判断 CPU 架构
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

# 安装mihomo
mihomo_install() {
    arch=$(detect_architecture)
    download_url="https://github.com/herozmy/StoreHouse/releases/download/mihomo/mihomo-meta-linux-${arch}.tar.gz"
    log "开始下载 Mihomo 核心..."

    if ! wget -O /tmp/mihomo.tar.gz "$download_url"; then
        log "Mihomo 下载失败，请检查网络连接"
        exit 1
    fi

    log "Mihomo 下载完成，开始安装"
    tar -zxvf /tmp/mihomo.tar.gz -C /usr/local/bin > /dev/null 2>&1 || {
        log "解压 Mihomo 失败，请检查压缩包完整性"
        exit 1
    }

    chmod +x /usr/local/bin/mihomo || log "警告：未能设置 Mihomo 执行权限"
    rm -f /tmp/mihomo.tar.gz
    log "Mihomo 安装完成，临时文件已清理"
}

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


