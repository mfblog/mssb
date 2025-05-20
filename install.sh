#!/bin/bash

# 日志输出函数
log() {
    echo "[$(date)] $1"
}

# 系统更新和软件包安装
update_system() {
    log "更新系统..."
    if ! apt update && apt -y upgrade; then
        log "系统更新失败！退出脚本。"
        exit 1
    fi

    log "安装必要的软件包..."
    if ! apt install -y supervisor inotify-tools curl git wget tar gawk sed cron unzip nano nftables; then
        log "软件包安装失败！退出脚本。"
        exit 1
    fi
}

# 设置时区
set_timezone() {
    log "设置时区为Asia/Shanghai"
    if ! timedatectl set-timezone Asia/Shanghai; then
        log "时区设置失败！退出脚本。"
        exit 1
    fi
    log "时区设置成功"
}

# 检测系统架构
detect_architecture() {
    ARCH="amd64"
    case "$(uname -m)" in
        "aarch64")
            ARCH="arm64"
            log "检测到 CPU 架构为 arm64。"
            ;;
        "x86_64")
            ARCH="amd64"
            log "检测到 CPU 架构为 amd64。"
            ;;
        *)
            log "无法识别的 CPU 架构：$(uname -m)。脚本退出。"
            exit 1
            ;;
    esac
}

install_mosdns() {
  # 下载并安装 MosDNS
  log "开始下载 MosDNS..."
  LATEST_MOSDNS_VERSION=$(curl -sL -o /dev/null -w %{url_effective} https://github.com/IrineSistiana/mosdns/releases/latest | awk -F '/' '{print $NF}')
  MOSDNS_URL="https://github.com/IrineSistiana/mosdns/releases/download/${LATEST_MOSDNS_VERSION}/mosdns-linux-${ARCH}.zip"

  log "从 $MOSDNS_URL 下载 MosDNS..."
  if curl -L -o /tmp/mosdns.zip "$MOSDNS_URL"; then
      log "MosDNS 下载成功。"
  else
      log "MosDNS 下载失败，请检查网络连接或 URL 是否正确。"
      exit 1
  fi

  log "解压 MosDNS..."
  if unzip -o /tmp/mosdns.zip -d /usr/local/bin; then
      log "MosDNS 解压成功。"
  else
      log "MosDNS 解压失败，请检查压缩包是否正确。"
      exit 1
  fi

  log "设置 MosDNS 可执行权限..."
  if chmod +x /usr/local/bin/mosdns; then
      log "设置权限成功。"
  else
      log "设置权限失败，请检查文件路径和权限设置。"
      exit 1
  fi
}

install_filebrower() {
  # 下载并安装 Filebrowser
    log "开始下载 Filebrowser..."
    LATEST_FILEBROWSER_VERSION=$(curl -sL -o /dev/null -w %{url_effective} https://github.com/filebrowser/filebrowser/releases/latest | awk -F '/' '{print $NF}')
    FILEBROWSER_URL="https://github.com/filebrowser/filebrowser/releases/download/${LATEST_FILEBROWSER_VERSION}/linux-${ARCH}-filebrowser.tar.gz"

    log "从 $FILEBROWSER_URL 下载 Filebrowser..."
    if curl -L --fail -o /tmp/filebrowser.tar.gz "$FILEBROWSER_URL"; then
        log "Filebrowser 下载成功。"
    else
        log "Filebrowser 下载失败，请检查网络连接或 URL 是否正确。"
        exit 1
    fi

    log "解压 Filebrowser..."
    if tar -zxvf /tmp/filebrowser.tar.gz -C /usr/local/bin; then
        log "Filebrowser 解压成功。"
    else
        log "Filebrowser 解压失败，请检查压缩包是否正确。"
        exit 1
    fi

    log "设置 Filebrowser 可执行权限..."
    if chmod +x /usr/local/bin/filebrowser; then
        log "Filebrowser 设置权限成功。"
    else
        log "Filebrowser 设置权限失败，请检查文件路径和权限设置。"
        exit 1
    fi
}

# 安装 Sing-Box
install_singbox() {
    log "开始安装 Sing-Box"

    # 检查 ARCH 并设置 SB_ARCH
    if [ "$ARCH" == "arm64" ]; then
        SB_ARCH="arm64"
    else
        SB_ARCH="$ARCH"  # 默认使用 ARCH 的值
    fi

    # 定义下载 URL
    # SING_BOX_URL="https://raw.githubusercontent.com/herozmy/herozmy-private/main/sing-box-puernya/sing-box-linux-$SB_ARCH.tar.gz"
    SING_BOX_URL=""https://github.com/herozmy/StoreHouse/releases/download/sing-box/sing-box-puernya-linux-$SB_ARCH.tar.gz""

    # 下载文件
    log "正在下载 Sing-Box: $SING_BOX_URL"
    wget -O "sing-box-linux-$SB_ARCH.tar.gz" "$SING_BOX_URL"
    if [ $? -ne 0 ]; then
        log "Sing-Box 下载失败！退出脚本。"
        exit 1
    fi

    # 解压文件
    tar -zxvf "sing-box-linux-$SB_ARCH.tar.gz"
    if [ $? -ne 0 ]; then
        log "解压失败，请检查文件完整性！退出脚本。"
        exit 1
    fi

    # 检查是否已安装
    if [ -f "/usr/local/bin/sing-box" ]; then
        log "检测到已安装的 Sing-Box"
        read -p "是否替换升级？(y/n): " replace_confirm
        if [ "$replace_confirm" == "y" ]; then
            log "正在替换升级 Sing-Box"
            mv -f sing-box /usr/local/bin/
            log "Sing-Box 替换升级完成"
        else
            log "用户取消了替换升级操作"
        fi
    else
        mv -f sing-box /usr/local/bin/
        log "Sing-Box 安装完成"
    fi

    # 清理临时文件
    rm -f "sing-box-linux-$SB_ARCH.tar.gz"
    log "临时文件已清理"
}

# 用户自定义设置
customize_settings() {
    echo "是否选择生成配置（更新安装请选择n）？(y/n)"
    echo "生成配置文件需要添加机场订阅，如自建vps请选择n"
    read choice
    if [ "$choice" = "y" ]; then
        while true; do
            read -p "输入订阅连接（可以输入多个，以空格分隔）：" suburls
            valid=true

            # 遍历每个输入的链接，验证是否符合格式要求
            for url in $suburls; do
                if [[ $url != http* ]]; then
                    echo "无效的订阅连接：$url，请以 http 开头。"
                    valid=false
                    break
                fi
            done

            # 如果所有链接都有效，将它们一次性传递给 Python 脚本
            if [ "$valid" = true ]; then
                echo "已设置订阅连接地址：$suburls"
                # 调用 Python 脚本，并将所有链接作为一个参数传递
                python3 update_sub.py -v "$suburls"
                log "订阅连接地址设置完成。"
                break
            else
                log "部分订阅连接无效，请重新输入。"
            fi
        done
    elif [ "$choice" = "n" ]; then
        log "请手动配置 config.json."
    else
        log "无效选择，请输入 y 或 n。"
    fi
}

# UI 源码安装
install_ui() {
    echo "是否更新 UI 源码？(y/n)"
    read choice
    if [ "$choice" = "y" ]; then
        git clone --depth=1 https://github.com/metacubex/metacubexd.git -b gh-pages /tmp/ui
        cp -r /tmp/ui/* /mssb/sing-box/ui/
        rm -rf /tmp/ui
        log "UI 源码更新完成。"
    elif [ "$choice" = "n" ]; then
        log "请手动下载源码并解压至 /mssb/sing-box/ui。地址: https://github.com/metacubex/metacubexd"
    fi
}

################################安装tproxy################################
install_tproxy() {
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "debian" ]; then
        echo "当前系统为 Debian 系统"
    elif [ "$ID" = "ubuntu" ]; then
        echo "当前系统为 Ubuntu 系统"
        echo "关闭 53 端口监听"

        # 确保 DNSStubListener 没有已经被设置为 no
        if grep -q "^DNSStubListener=no" /etc/systemd/resolved.conf; then
            echo "DNSStubListener 已经设置为 no, 无需修改"
        else
            sed -i '/^#*DNSStubListener/s/#*DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
            echo "DNSStubListener 已被设置为 no"
            systemctl restart systemd-resolved.service
            sleep 1
        fi
    else
        echo "当前系统不是 Debian 或 Ubuntu. 请更换系统"
        exit 0
    fi
else
    echo "无法识别系统，请更换 Ubuntu 或 Debian"
    exit 0
fi

    echo "创建系统转发"
# 判断是否已存在 net.ipv4.ip_forward=1
    if ! grep -q '^net.ipv4.ip_forward=1$' /etc/sysctl.conf; then
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    fi

# 判断是否已存在 net.ipv6.conf.all.forwarding = 1
    if ! grep -q '^net.ipv6.conf.all.forwarding = 1$' /etc/sysctl.conf; then
        echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
    fi
    echo "系统转发创建完成"
    sleep 1
    echo "开始创建nftables tproxy转发"
    apt install nftables -y
# 写入tproxy rule
# 判断文件是否存在
    if [ ! -f "/etc/systemd/system/sing-box-router.service" ]; then
    cat <<EOF > "/etc/systemd/system/sing-box-router.service"
[Unit]
Description=sing-box TProxy Rules
After=network.target
Wants=network.target

[Service]
User=root
Type=oneshot
RemainAfterExit=yes
# there must be spaces before and after semicolons
ExecStart=/sbin/ip rule add fwmark 1 table 100 ; /sbin/ip route add local default dev lo table 100 ; /sbin/ip -6 rule add fwmark 1 table 101 ; /sbin/ip -6 route add local ::/0 dev lo table 101
ExecStop=/sbin/ip rule del fwmark 1 table 100 ; /sbin/ip route del local default dev lo table 100 ; /sbin/ip -6 rule del fwmark 1 table 101 ; /sbin/ip -6 route del local ::/0 dev lo table 101

[Install]
WantedBy=multi-user.target
EOF
    echo "sing-box-router 服务创建完成"
    else
    echo "警告：sing-box-router 服务文件已存在，无需创建"
    fi
################################写入nftables################################
check_interfaces
echo "" > "/etc/nftables.conf"
cat <<EOF > "/etc/nftables.conf"
#!/usr/sbin/nft -f
flush ruleset
table inet sing-box {
  set local_ipv4 {
    type ipv4_addr
    flags interval
    elements = {
      10.0.0.0/8,
      127.0.0.0/8,
      169.254.0.0/16,
      172.16.0.0/12,
      192.168.0.0/16,
      240.0.0.0/4
    }
  }

  set local_ipv6 {
    type ipv6_addr
    flags interval
    elements = {
      ::ffff:0.0.0.0/96,
      64:ff9b::/96,
      100::/64,
      2001::/32,
      2001:10::/28,
      2001:20::/28,
      2001:db8::/32,
      2002::/16,
      fc00::/7,
      fe80::/10
    }
  }

  chain sing-box-tproxy {
    fib daddr type { unspec, local, anycast, multicast } return
    ip daddr @local_ipv4 return
    ip6 daddr @local_ipv6 return
    udp dport { 123 } return
    meta l4proto { tcp, udp } meta mark set 1 tproxy to :7896 accept
  }

  chain sing-box-mark {
    fib daddr type { unspec, local, anycast, multicast } return
    ip daddr @local_ipv4 return
    ip6 daddr @local_ipv6 return
    udp dport { 123 } return
    meta mark set 1
  }

  chain mangle-output {
    type route hook output priority mangle; policy accept;
    meta l4proto { tcp, udp } skgid != 1 ct direction original goto sing-box-mark
  }

  chain mangle-prerouting {
    type filter hook prerouting priority mangle; policy accept;
    iifname { wg0, lo, $selected_interface } meta l4proto { tcp, udp } ct direction original goto sing-box-tproxy
  }
}
EOF
    echo "nftables规则写入完成"
    echo "清空 nftalbes 规则"
    nft flush ruleset
    sleep 1
    echo "新规则生效"
    sleep 1
    nft -f /etc/nftables.conf
    install_over
}
################################sing-box安装结束################################
install_over() {
    echo "启用相关服务"
    systemctl enable --now nftables
    systemctl enable --now sing-box-router
}

# 网卡检测
check_interfaces() {
    interfaces=$(ip -o link show | awk -F': ' '{print $2}')
    # 输出物理网卡名称
    for interface in $interfaces; do
        if [[ $interface =~ ^(en|eth).* ]]; then
            interface_name=$(echo "$interface" | awk -F'@' '{print $1}')
            echo "您的网卡是：$interface_name"
        fi
    done
    read -p "脚本自行检测的是否是您要的网卡？(y/n): " confirm_interface
    if [ "$confirm_interface" = "y" ]; then
        selected_interface="$interface_name"
        log "您选择的网卡是: $selected_interface"
    elif [ "$confirm_interface" = "n" ]; then
        read -p "请自行输入您的网卡名称: " selected_interface
        log "您输入的网卡名称是: $selected_interface"
    else
        log "无效的选择"
        exit 1
    fi
}

# 配置文件和脚本设置
configure_files() {
    log "检查是否存在 /mssb/sing-box/config.json ..."
    CONFIG_JSON="/mssb/sing-box/config.json"
    BACKUP_JSON="/tmp/config_backup.json"

    # 如果 config.json 存在，则进行备份
    if [ -f "$CONFIG_JSON" ]; then
        log "发现 config.json 文件，备份到 /tmp 目录..."
        cp "$CONFIG_JSON" "$BACKUP_JSON" || { log "备份 config.json 失败！退出脚本。"; exit 1; }
    else
        log "未发现 config.json 文件，跳过备份步骤。"
    fi

    # 函数：检查并复制文件夹
    check_and_copy_folder() {
        local folder_name=$1
        if [ -d "/mssb/$folder_name" ]; then
            log "/mssb/$folder_name 文件夹已存在，跳过替换。"
        else
            cp -r "mssb/$folder_name" "/mssb/" || { log "复制 mssb/$folder_name 目录失败！退出脚本。"; exit 1; }
            log "成功复制 mssb/$folder_name 目录到 /mssb/"
        fi
    }

    log "复制配置文件..."
    cp supervisord.conf /etc/supervisor/ || { log "复制 supervisord.conf 失败！退出脚本。"; exit 1; }
    cp -r watch / || { log "复制 watch 目录失败！退出脚本。"; exit 1; }

    # 复制 mssb/sing-box 目录
    log "复制 mssb/sing-box 目录..."
    check_and_copy_folder "fb"
    check_and_copy_folder "mosdns"
    if [ -d "/mssb/sing-box" ]; then
        log "/mssb/sing-box 目录已存在，跳过替换。"
    else
        cp -r mssb/sing-box /mssb || { log "复制 mssb/sing-box 目录失败！退出脚本。"; exit 1; }
        log "成功复制 mssb/sing-box 目录到 /mssb"
    fi

    # 如果之前有备份 config.json，则恢复备份文件
    if [ -f "$BACKUP_JSON" ]; then
        log "恢复 config.json 文件到 /mssb/sing-box ..."
        cp "$BACKUP_JSON" "$CONFIG_JSON" || { log "恢复 config.json 失败！退出脚本。"; exit 1; }
        log "恢复完成，删除临时备份文件..."
        rm -f "$BACKUP_JSON"
    fi

    log "设置脚本可执行权限..."
    chmod +x /watch/*.sh || { log "设置 /watch/*.sh 权限失败！退出脚本。"; exit 1; }
}


reload_service() {
  # 重启 Supervisor
    log "重启 Supervisor..."
    if ! supervisorctl stop all; then
        log "停止 Supervisor 失败！"
        exit 1
    fi
    log "Supervisor 停止成功。"
    sleep 2

    if ! supervisorctl reload; then
        log "重启 Supervisor 失败！"
        exit 1
    fi
    log "Supervisor 重启成功。"
    sleep 2
    systemctl restart sing-box-router


}




# 定义定时任务的表达式和任务脚本的路径
cron_jobs=(
    # 每周一凌晨 4:00 执行更新 MosDNS 的脚本
    "0 4 * * 1 /watch/update_mosdns.sh"

    # 每周一凌晨 4:10 执行更新 Sing-Box 的脚本
    "10 4 * * 1 /watch/update_sb.sh"

    # 每周一凌晨 4:15 执行更新中国节点的脚本
    "15 4 * * 1 /watch/update_cn.sh"
)

# 函数：将任务添加到 crontab 中

# 添加任务到 crontab
add_cron_jobs() {
    # 先删除现有的重复任务（如果存在）
    (crontab -l | grep -v -e "# update_mosdns" -e "# update_sb" -e "# update_cn") | crontab -

    for job in "${cron_jobs[@]}"; do
        # 检查任务是否已存在
        if (crontab -l | grep -q -F "$job"); then
            log "定时任务已存在：$job"
        else
            # 将新的任务添加到 crontab 中
            (crontab -l; echo "$job") | crontab -
            log "定时任务已成功添加：$job"
        fi
    done
}


# 主函数
main() {
    update_system
    set_timezone
    detect_architecture
    install_filebrower
    install_mosdns
    install_singbox
    configure_files
    customize_settings
    install_ui
    install_tproxy
    reload_service
    add_cron_jobs
    log "脚本执行完成。"
}

main
