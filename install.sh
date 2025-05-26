#!/bin/bash

# 定义颜色变量
green_text="\033[32m"
yellow="\033[33m"
reset="\033[0m"
red='\033[1;31m'

# 获取本机 IP
local_ip=$(hostname -I | awk '{print $1}')

# 日志输出函数
log() {
    echo "[$(date +"%F %T")] $1"
}

# 系统更新和安装必要软件
update_system() {
    log "开始更新系统..."
    if ! apt update; then
        log "${red}系统更新失败，退出！${reset}"
        exit 1
    fi

    log "安装必要的软件包..."
    if ! apt install -y supervisor inotify-tools curl git wget tar gawk sed cron unzip nano nftables; then
        log "${red}软件包安装失败，退出！${reset}"
        exit 1
    fi
}
# 设置时区
set_timezone() {
    log "设置时区为Asia/Shanghai"
    if ! timedatectl set-timezone Asia/Shanghai; then
        log "${red}时区设置失败！退出脚本！${reset}"
        exit 1
    fi
    log "时区设置成功"
}

# 检查程序是否安装
check_installed() {
    programs=("sing-box" "mosdns" "mihomo" "filebrowser")
    echo -e "\n${yellow}检测本机安装情况 (本地IP: $local_ip)...${reset}"

    for program in "${programs[@]}"; do
        if [ -f "/usr/local/bin/$program" ]; then
            echo -e "  ${green_text}✔ 已安装${reset} - $program"
        else
            echo -e "  ${red}✘ 未安装${reset} - $program"
        fi
    done
}
# 检查服务是否启用
check_core_status() {
    green_text="\e[32m"
    red_text="\e[31m"
    reset="\e[0m"

    echo -e "\n检查服务状态..."
    echo -e "----------------------------------------"

    # 主程序服务
    core_programs=("sing-box" "mihomo" "mosdns")
    # 对应看门狗服务
    watch_services=("watch_sing_box" "watch_mihomo" "watch_mosdns")

    # 检查核心服务状态
    for program in "${core_programs[@]}"; do
        echo -e "\n服务名称: ${program}"

        if supervisorctl status | grep -qE "^${program}\s+RUNNING"; then
            case "$program" in
                "sing-box"|"mihomo")
                    echo -e "  类型: 路由服务"
                    echo -e "  状态: ${green_text}运行中 ✅${reset}"
                    ;;
                "mosdns")
                    echo -e "  类型: DNS服务"
                    echo -e "  状态: ${green_text}运行中 ✅${reset}"
                    ;;
                *)
                    echo -e "  类型: 未知"
                    echo -e "  状态: ${green_text}运行中 ✅${reset}"
                    ;;
            esac
        else
            case "$program" in
                "sing-box"|"mihomo")
                    echo -e "  类型: 路由服务"
                    echo -e "  状态: ${red_text}未运行 ❌${reset}"
                    ;;
                "mosdns")
                    echo -e "  类型: DNS服务"
                    echo -e "  状态: ${red_text}未运行 ❌${reset}"
                    ;;
                *)
                    echo -e "  类型: 未知"
                    echo -e "  状态: ${red_text}未运行 ❌${reset}"
                    ;;
            esac
        fi
    done

    # 检查看门狗服务状态
    for watch in "${watch_services[@]}"; do
        echo -e "\n服务名称: ${watch}"

        if supervisorctl status | grep -qE "^${watch}\s+RUNNING"; then
            echo -e "  类型: 看门狗服务"
            echo -e "  状态: ${green_text}运行中 ✅${reset}"
        else
            echo -e "  类型: 看门狗服务"
            echo -e "  状态: ${red_text}未运行 ❌${reset}"
        fi
    done

    echo -e "\n----------------------------------------"
}
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

# 安装mosdns
install_mosdns() {
  # 下载并安装 MosDNS
  log "开始下载 MosDNS..."
  arch=$(detect_architecture)
  log "系统架构是：$arch"
#  LATEST_MOSDNS_VERSION=$(curl -sL -o /dev/null -w %{url_effective} https://github.com/IrineSistiana/mosdns/releases/latest | awk -F '/' '{print $NF}')
#  MOSDNS_URL="https://github.com/IrineSistiana/mosdns/releases/download/${LATEST_MOSDNS_VERSION}/mosdns-linux-$arch.zip"
  MOSDNS_URL="https://github.com/herozmy/StoreHouse/releases/download/mosdns/mosdns-linux-$arch.zip"


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
# 安装filebrower
install_filebrower() {
  # 下载并安装 Filebrowser
    log "开始下载 Filebrowser..."
    arch=$(detect_architecture)
    log "系统架构是：$arch"
    LATEST_FILEBROWSER_VERSION=$(curl -sL -o /dev/null -w %{url_effective} https://github.com/filebrowser/filebrowser/releases/latest | awk -F '/' '{print $NF}')
    FILEBROWSER_URL="https://github.com/filebrowser/filebrowser/releases/download/${LATEST_FILEBROWSER_VERSION}/linux-$arch-filebrowser.tar.gz"

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
    arch=$(detect_architecture)
    log "系统架构是：$arch"
    # 定义下载 URL
    SING_BOX_URL="https://github.com/herozmy/StoreHouse/releases/download/sing-box/sing-box-puernya-linux-$arch.tar.gz"

    # 下载文件
    log "正在下载 Sing-Box: $SING_BOX_URL"
    wget -O "sing-box-linux-$arch.tar.gz" "$SING_BOX_URL"
    if [ $? -ne 0 ]; then
        log "Sing-Box 下载失败！退出脚本。"
        exit 1
    fi

    # 解压文件
    tar -zxvf "sing-box-linux-$arch.tar.gz"
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

    log "设置 sing-box 可执行权限..."
      if chmod +x /usr/local/bin/sing-box; then
          log "设置权限成功。"
      else
          log "设置权限失败，请检查文件路径和权限设置。"
          exit 1
      fi

    # 清理临时文件
    rm -f "sing-box-linux-$arch.tar.gz"
    log "临时文件已清理"
}
# singbox用户自定义设置
singbox_customize_settings() {
    echo "是否选择生成配置（更新安装请选择n）？(y/n)"
    echo "生成配置文件需要添加机场订阅，如自建 VPS 请选择 n"
    read choice
    if [ "$choice" = "y" ]; then
        while true; do
            read -p "输入订阅连接（多个用空格分隔，输入 q 退出）： " suburls

            if [[ "$suburls" == "q" ]]; then
                log "已取消自动生成配置，请手动编辑 /mssb/sing-box/config.json"
                break
            fi

            valid=true
            for url in $suburls; do
                if [[ $url != http* ]]; then
                    echo "❌ 无效的订阅连接：$url（应以 http 开头）"
                    valid=false
                    break
                fi
            done

            if [ "$valid" = true ]; then
                echo "✅ 已设置订阅连接地址：$suburls"
                python3 update_sub.py -v "$suburls"
                log "订阅连接处理完成。"
                break
            else
                log "部分订阅链接不符合要求，请重新输入。"
            fi
        done
    elif [ "$choice" = "n" ]; then
        log "你选择了手动配置，请编辑 /mssb/sing-box/config.json"
    else
        log "无效选择，请输入 y 或 n。"
        singbox_customize_settings  # 递归重新执行
    fi
}
# 安装mihomo
install_mihomo() {
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
# mihomo用户自定义设置
mihomo_customize_settings() {
    echo "是否选择生成配置（更新安装请选择n）？(y/n)"
    echo "生成配置文件需要添加机场订阅，如自建vps请选择n"
    read choice
    if [ "$choice" = "y" ]; then
        while true; do
            read -p "输入订阅连接（mihomo模式暂时只支持单个，多个需手动修改yaml文件），输入 q 返回上一步: " suburl
            if [[ "$suburl" == "q" ]]; then
                log "已取消自动生成配置，请手动编辑 /mssb/mihomo/config.yaml"
                break
            elif [[ -n "$suburl" ]]; then
                escaped_url=$(printf '%s\n' "$suburl" | sed 's/[&/\]/\\&/g')
                sed -i "s|url: '机场订阅'|url: '$escaped_url'|" /mssb/mihomo/config.yaml
                sed -i "s|interface-name: eth0|interface-name: $selected_interface|" /mssb/mihomo/config.yaml
                log "订阅链接已写入。"
                break
            else
                echo "订阅链接不能为空，请重新输入或输入 q 退出。"
            fi
        done
    elif [ "$choice" = "n" ]; then
        log "你选择了手动配置 /mssb/mihomo/config.yaml。"
    else
        log "无效选择，请输入 y 或 n。"
        mihomo_customize_settings  # 重新询问
    fi
}

# 检测ui是否存在
check_ui() {
    if [ -z "$core_name" ]; then
        echo -e "${red}未检测到核心程序名（core_name），请先设置 core_name${reset}"
        return 1
    fi

    ui_path="/mssb/${core_name}/ui"

    if [ -d "$ui_path" ]; then
        echo "检测到已有 UI，正在更新 WEBUI..."
        rm -rf "$ui_path"
        git_ui
    else
        echo "未检测到 UI，首次安装 WEBUI..."
        git_ui
    fi
}
# 下载UI源码
git_ui(){
    if git clone --depth=1 https://github.com/Zephyruso/zashboard.git -b gh-pages /mssb/${core_name}/ui; then
        echo -e "UI 源码拉取${green_text}成功${reset}。"
    else
        echo "拉取源码失败，请手动下载源码并解压至 /mssb/${core_name}/ui."
        echo "地址: https://github.com/Zephyruso/zashboard.git"
    fi
}

# 检查dns 53是否被占用
check_resolved(){
    if [ -f /etc/systemd/resolved.conf ]; then
        # 检测是否有未注释的 DNSStubListener 行
        dns_stub_listener=$(grep "^DNSStubListener=" /etc/systemd/resolved.conf)
        if [ -z "$dns_stub_listener" ]; then
            # 如果没有找到未注释的 DNSStubListener 行，检查是否有被注释的 DNSStubListener
            commented_dns_stub_listener=$(grep "^#DNSStubListener=" /etc/systemd/resolved.conf)
            if [ -n "$commented_dns_stub_listener" ]; then
                # 如果找到被注释的 DNSStubListener，取消注释并改为 no
                sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
                systemctl restart systemd-resolved.service
                green "53端口占用已解除"
            else
                green "未找到53端口占用配置，无需操作"
            fi
        elif [ "$dns_stub_listener" = "DNSStubListener=yes" ]; then
            # 如果找到 DNSStubListener=yes，则修改为 no
            sed -i 's/^DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
            systemctl restart systemd-resolved.service
            green "53端口占用已解除"
        elif [ "$dns_stub_listener" = "DNSStubListener=no" ]; then
            # 如果 DNSStubListener 已为 no，提示用户无需修改
            echo -e "${yellow}53端口未被占用，无需操作${reset}"
        fi
    else
        echo -e "${yellow} /etc/systemd/resolved.conf 不存在，无需操作${reset}"
    fi
}
# tproxy转发服务安装
install_tproxy() {
    check_resolved
    sleep 1
    echo -e "${yellow}配置tproxy${reset}"
    sleep 1
    echo -e "${yellow}创建系统转发${reset}"
    # 判断是否已存在 net.ipv4.ip_forward=1
    if ! grep -q '^net.ipv4.ip_forward=1$' /etc/sysctl.conf; then
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    fi

    # 判断是否已存在 net.ipv6.conf.all.forwarding = 1
#    if ! grep -q '^net.ipv6.conf.all.forwarding = 1$' /etc/sysctl.conf; then
#        echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
#    fi
    sleep 1
    echo -e "${green_text}系统转发创建完成${reset}"
    sleep 1
    echo -e "${yellow}开始创建nftables tproxy转发${reset}"
    apt install nftables -y
    # 写入tproxy rule
    # 判断文件是否存在"$core_name" = "sing-box"
    if [ ! -f "/etc/systemd/system/${core_name}-router.service" ]; then
    cat <<EOF > "/etc/systemd/system/${core_name}-router.service"
[Unit]
Description=${core_name} TProxy Rules
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
    echo "${core_name}-router 服务创建完成"
    else
    echo "警告：${core_name}-router 服务文件已存在，无需创建"
    fi
    ################################写入nftables################################
    check_interfaces
    if [ "$core_name" = "sing-box" ]; then
          echo "" > "/etc/nftables.conf"
              cat <<EOF > "/etc/nftables.conf"
#!/usr/sbin/nft -f
flush ruleset
table inet $core_name {
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

  chain ${core_name}-tproxy {
    fib daddr type { unspec, local, anycast, multicast } return
    ip daddr @local_ipv4 return
    ip6 daddr @local_ipv6 return
    udp dport { 123 } return
    meta l4proto { tcp, udp } meta mark set 1 tproxy to :7896 accept
  }

  chain ${core_name}-mark {
    fib daddr type { unspec, local, anycast, multicast } return
    ip daddr @local_ipv4 return
    ip6 daddr @local_ipv6 return
    udp dport { 123 } return
    meta mark set 1
  }

  chain mangle-output {
    type route hook output priority mangle; policy accept;
    meta l4proto { tcp, udp } skgid != 1 ct direction original goto ${core_name}-mark
  }

  chain mangle-prerouting {
    type filter hook prerouting priority mangle; policy accept;
    iifname { wg0, lo, $selected_interface } meta l4proto { tcp, udp } ct direction original goto ${core_name}-tproxy
  }
}
EOF
        elif [ "$core_name" = "mihomo" ]; then
          echo "" > "/etc/nftables.conf"
              cat <<EOF > "/etc/nftables.conf"
#!/usr/sbin/nft -f
flush ruleset
table inet $core_name {
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

  chain ${core_name}-tproxy {
    fib daddr type { unspec, local, anycast, multicast } return
    ip daddr @local_ipv4 return
    ip6 daddr @local_ipv6 return
    udp dport { 123 } return
    udp dport { 53 } accept
    meta l4proto { tcp, udp } meta mark set 1 tproxy to :7896 accept
  }

  chain ${core_name}-mark {
    fib daddr type { unspec, local, anycast, multicast } return
    ip daddr @local_ipv4 return
    ip6 daddr @local_ipv6 return
    udp dport { 123 } return
    udp dport { 53 } accept
    meta mark set 1
  }

  chain mangle-output {
    type route hook output priority mangle; policy accept;
    meta l4proto { tcp, udp } skgid != 1 ct direction original goto ${core_name}-mark
  }

  chain mangle-prerouting {
    type filter hook prerouting priority mangle; policy accept;
    iifname { wg0, lo, $selected_interface } meta l4proto { tcp, udp } ct direction original goto ${core_name}-tproxy
  }
}
EOF
        else
          log "未识别的 core_name: $core_name，跳过 启用相关服务。"
        fi

    echo -e "${green_text}nftables规则写入完成${reset}"
    sleep 1
    echo "清空 nftalbes 规则"
    nft flush ruleset
    sleep 1
    echo "新规则生效"
    sleep 1
    nft -f /etc/nftables.conf
    echo "启用相关服务"
    systemctl enable --now nftables
    if [ "$core_name" = "sing-box" ]; then
      # 启用 sing-box-router，禁用 mihomo-router
      systemctl disable --now mihomo-router &>/dev/null
      rm -f /etc/systemd/system/mihomo-router.service
      systemctl enable --now sing-box-router || { log "启用相关服务 失败！退出脚本。"; exit 1; }
    elif [ "$core_name" = "mihomo" ]; then
      # 启用 mihomo-router，禁用 sing-box-router
      systemctl disable --now sing-box-router &>/dev/null
      rm -f /etc/systemd/system/sing-box-router.service
      systemctl enable --now mihomo-router || { log "启用相关服务 失败！退出脚本。"; exit 1; }
    else
      log "未识别的 core_name: $core_name，跳过 启用相关服务。"
    fi
}

# 网卡检测或者手动输入
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
# 复制 mssb/mosdns fb 配置文件
cp_config_files() {
  log "复制 mssb/fb 目录..."
  check_and_copy_folder "fb"
  log "复制 mssb/mosdns 目录..."
  check_and_copy_folder "mosdns"
  log "复制supervisor配置文件..."
  # 根据 core_name 重启 systemd 服务
  if [ "$core_name" = "sing-box" ]; then
      cp run_mssb/supervisord.conf /etc/supervisor/ || { log "复制 supervisord.conf 失败！退出脚本。"; exit 1; }
  elif [ "$core_name" = "mihomo" ]; then
      cp run_msmo/supervisord.conf /etc/supervisor/ || { log "复制 supervisord.conf 失败！退出脚本。"; exit 1; }
  else
      log "未识别的 core_name: $core_name，跳过 复制supervisor配置文件。"
  fi
  cp -r watch / || { log "复制 watch 目录失败！退出脚本。"; exit 1; }
  log "设置脚本可执行权限..."
  chmod +x /watch/*.sh || { log "设置 /watch/*.sh 权限失败！退出脚本。"; exit 1; }
}

# singbox配置文件复制
singbox_configure_files() {
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
    # 复制 mssb/sing-box 目录
    log "复制 mssb/sing-box 目录..."
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
}
# mihomo配置文件复制
mihomo_configure_files() {
    log "检查是否存在 /mssb/mihomo/config.yaml ..."
    CONFIG_YAML="/mssb/mihomo/config.yaml"
    BACKUP_YAML="/tmp/mihomo_config.yaml"

    # 如果 config.json 存在，则进行备份
    if [ -f "$CONFIG_YAML" ]; then
        log "发现 config.yaml 文件，备份到 /tmp 目录..."
        cp "$CONFIG_YAML" "$BACKUP_YAML" || { log "备份 config.yaml 失败！退出脚本。"; exit 1; }
    else
        log "未发现 config.yaml 文件，跳过备份步骤。"
    fi
    # 复制 mssb/sing-box 目录
    log "复制 mssb/mihomo 目录..."
    if [ -d "/mssb/mihomo" ]; then
        log "/mssb/mihomo 目录已存在，跳过替换。"
    else
        cp -r mssb/mihomo /mssb || { log "复制 mssb/mihomo 目录失败！退出脚本。"; exit 1; }
        log "成功复制 mssb/mihomo目录到 /mssb"
    fi

    # 如果之前有备份 config.json，则恢复备份文件
    if [ -f "$BACKUP_YAML" ]; then
        log "恢复 config.json 文件到 /mssb/mihomo ..."
        cp "$BACKUP_YAML" "$CONFIG_YAML" || { log "恢复 config.yaml 失败！退出脚本。"; exit 1; }
        log "恢复完成，删除临时备份文件..."
        rm -f "$BACKUP_YAML"
    fi
}
# 服务启动和重载
reload_service() {
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

    # 根据 core_name 重启 systemd 服务
    if [ "$core_name" = "sing-box" ]; then
        systemctl restart sing-box-router
        log "已重启 sing-box-router 服务。"
    elif [ "$core_name" = "mihomo" ]; then
        systemctl restart mihomo-router
        log "已重启 mihomo-router 服务。"
    else
        log "未识别的 core_name: $core_name，跳过 systemd 服务重启。"
    fi
}
# 添加任务到 crontab
add_cron_jobs() {
    if [ "$core_name" = "sing-box" ]; then
        cron_jobs=(
            "0 4 * * 1 /watch/update_mosdns.sh # update_mosdns"
            "15 4 * * 1 /watch/update_cn.sh    # update_cn"
            "10 4 * * 1 /watch/update_sb.sh    # update_sb"
        )

        # 清除旧的 sing-box 相关任务
        (crontab -l | grep -v -e "# update_mosdns" -e "# update_sb" -e "# update_cn") | crontab -
    elif [ "$core_name" = "mihomo" ]; then
        cron_jobs=(
            "0 4 * * 1 /watch/update_mosdns.sh # update_mosdns"
            "15 4 * * 1 /watch/update_cn.sh    # update_cn"
            "10 4 * * 1 /watch/update_mihomo.sh   # update_mihomo"
        )

        # 清除旧的 mihomo 相关任务
        (crontab -l | grep -v -e "# update_mosdns" -e "# update_mihomo" -e "# update_cn") | crontab -
    else
        log "未识别的 core_name（$core_name），跳过定时任务设置。"
        return
    fi

    for job in "${cron_jobs[@]}"; do
        if (crontab -l | grep -q -F "$job"); then
            log "定时任务已存在：$job"
        else
            (crontab -l; echo "$job") | crontab -
            log "定时任务已成功添加：$job"
        fi
    done
}


# 主函数
main() {
    green_text="\e[32m"
    red_text="\e[31m"
    reset="\e[0m"

    echo -e "${green_text}------------------------注意：请使用 root 用户安装！！！-------------------------${reset}"
    echo -e "${green_text}请选择操作：${reset}"
    echo -e "${green_text}1) 安装/更新代理转发服务${reset}"
    echo -e "${red_text}2) 停止所有转发服务${reset}"
    echo -e "${red_text}3) 停止所有服务并卸载 + 删除所有相关文件${reset}"
    echo -e "${green_text}4) 启用所有服务${reset}"
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "请输入选项 (1/2/3/4): " main_choice

    case "$main_choice" in
        2)
            echo -e "${red_text}⛔ 正在停止所有转发相关服务...${reset}"
            supervisorctl stop all || echo "supervisorctl 未安装或未配置"
            systemctl stop sing-box-router.service 2>/dev/null
            systemctl stop mihomo-router.service 2>/dev/null
            systemctl stop nftables.service 2>/dev/null
            log "所有相关服务已停止。"
            exit 0
            ;;
        3)
            echo -e "${red_text}⚠️ 正在停止并卸载所有服务...${reset}"
            supervisorctl stop all || echo "supervisorctl 未安装或未配置"
            systemctl stop sing-box-router.service 2>/dev/null
            systemctl stop mihomo-router.service 2>/dev/null
            systemctl stop nftables.service 2>/dev/null

            systemctl disable sing-box-router.service 2>/dev/null
            systemctl disable mihomo-router.service 2>/dev/null
            systemctl disable nftables.service 2>/dev/null

            rm -rf /mssb
            rm -rf /etc/systemd/system/sing-box-router.service
            rm -rf /etc/systemd/system/mihomo-router.service
            rm -rf /etc/nftables.conf
            rm -rf /usr/local/bin/mosdns
            rm -f /etc/supervisor/supervisord.conf
            apt-get remove -y supervisor >/dev/null 2>&1
            apt-get purge -y supervisor >/dev/null 2>&1
            systemctl daemon-reload

            log "✅ 所有服务已停止，配置与文件已删除，supervisor 已卸载。"
            exit 0
            ;;
        4)
            echo -e "${green_text}✅ 正在启动所有转发相关服务...${reset}"
            # 启动 sing-box-router
            systemctl start sing-box-router.service 2>/dev/null || echo "❌ sing-box-router 启动失败"
            # 启动 mihomo-router
            systemctl start mihomo-router.service 2>/dev/null || echo "❌ mihomo-router 启动失败"
            # 清空 nftables 前备份，防止错误导致无规则运行
            cp /etc/nftables.conf /etc/nftables.conf.bak
            # 语法检查 nft 配置，避免意外
            if nft -c -f /etc/nftables.conf; then
                nft flush ruleset
                sleep 1
                nft -f /etc/nftables.conf
                systemctl start nftables.service 2>/dev/null || echo "❌ nftables 服务启动失败"
            else
                echo "⚠️ /etc/nftables.conf 有语法错误，已取消加载。"
            fi
            # 判断 supervisor 是否安装
            if command -v supervisorctl &>/dev/null; then
                supervisorctl start all || echo "❌ supervisorctl 执行失败"
            else
                echo "⚠️ supervisorctl 未安装"
            fi

            log "✅ 所有相关服务已启动完成。"
            exit 0
            ;;
        1)
            echo -e "${green_text}✅ 继续安装/更新代理服务...${reset}"
            ;;
        *)
            log "无效选项，退出脚本。"
            exit 1
            ;;
    esac

    update_system
    set_timezone

    echo -e "${green_text}-------------------------------------------------${reset}"
    echo -e "${green_text}Fake-ip 网关代理方案：sing-box P核/mihomo + MosDNS${reset}"
    echo "---支持 debian，其他系统未测试。理论上支持debian/ubuntu 安装前请确保系统未安装其他代理软件---"
    echo "---完全参考 https://github.com/herozmy/StoreHouse/tree/latest ---"
    echo -e "当前机器地址:${green_text}${local_ip}${reset}"
    check_installed
    check_core_status
    echo -e "${green_text}-------------------------------------------------${reset}"
    echo

    echo -e "${green_text}请选择安装方案：${reset}"
    echo "1) 方案1：Sing-box P核(支持订阅) + MosDNS"
    echo "2) 方案2：Mihomo + MosDNS"
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "请输入选项 (1/2): " choice
    case "$choice" in
        1)
            core_name="sing-box"
            log "你选择了方案1：Sing-box P核(支持订阅) + MosDNS"
            install_filebrower
            install_mosdns
            install_singbox
            cp_config_files
            singbox_configure_files
            singbox_customize_settings
            check_ui
            install_tproxy
            reload_service
            ;;
        2)
            core_name="mihomo"
            log "你选择了方案2：Mihomo + MosDNS"
            install_filebrower
            install_mosdns
            install_mihomo
            cp_config_files
            mihomo_configure_files
            check_ui
            mihomo_install_ui
            install_tproxy
            mihomo_customize_settings
            reload_service
            ;;
        *)
            log "无效选项，退出安装。"
            exit 1
            ;;
    esac

    echo
    echo -e "${green_text}-------------------------------------------------${reset}"
    echo "是否添加以下定时更新任务？每周一凌晨执行："
    echo "- 4:00 更新 MosDNS"
    if [ "$core_name" = "sing-box" ]; then
        echo "- 4:10 更新 Sing-box"
        echo "- 4:15 更新 CN 域名数据"
    else
        echo "- 4:10 更新 Mihomo"
    fi
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "是否添加定时任务？(y/n): " enable_cron
    if [[ "$enable_cron" == "y" || "$enable_cron" == "Y" ]]; then
        add_cron_jobs
    else
        log "用户选择不添加定时任务。"
    fi

    echo -e "${green_text}-------------------------------------------------${reset}"
    echo -e "${green_text}🎉 安装成功！以下是服务信息：${reset}"
    echo -e "📦 Supervisor 管理界面：${green_text}http://${local_ip}:9001${reset}"
    echo -e "   - 用户名：mssb"
    echo -e "   - 密码：mssb123.."
    echo
    echo -e "🗂️  文件管理服务 Filebrowser：${green_text}http://${local_ip}:8088${reset}"
    echo -e "   - 用户名：admin"
    echo -e "   - 密码：admin"
    echo
    echo -e "🕸️  Sing-box/Mihomo 面板 UI：${green_text}http://${local_ip}:9090${reset}"
    echo -e "   - 密码：mssb123.."
    echo -e "${green_text}-------------------------------------------------${reset}"


    log "脚本执行完成。"
}


main
