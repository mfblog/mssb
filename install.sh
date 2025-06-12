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
                    echo -e "  类型: 路由服务 状态: ${green_text}运行中 ✅${reset}"
                    ;;
                "mosdns")
                    echo -e "  类型: DNS服务 状态: ${green_text}运行中 ✅${reset}"
                    ;;
                *)
                    echo -e "  类型: 未知 ${green_text}运行中 ✅${reset}"
                    ;;
            esac
        else
            case "$program" in
                "sing-box"|"mihomo")
                    echo -e "  类型: 路由服务 ${red_text}未运行 ❌${reset}"
                    ;;
                "mosdns")
                    echo -e "  类型: DNS服务 ${red_text}未运行 ❌${reset}"
                    ;;
                *)
                    echo -e "  类型: 未知 ${red_text}未运行 ❌${reset}"
                    ;;
            esac
        fi
    done

    # 检查看门狗服务状态
    for watch in "${watch_services[@]}"; do
        echo -e "\n服务名称: ${watch}"

        if supervisorctl status | grep -qE "^${watch}\s+RUNNING"; then
            echo -e "  类型: 监听服务 状态: ${green_text}运行中 ✅${reset}"
        else
            echo -e "  类型: 监听服务 状态: ${red_text}未运行 ❌${reset}"
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
# 检查并恢复配置文件
check_and_restore_config() {
    local config_type=$1
    local config_path=$2
    local backup_dir="/mssb/backup"
    
    if [ -d "$backup_dir" ]; then
        case "$config_type" in
            "sing-box")
                # 获取当前核心类型
                if [ -f "/mssb/sing-box/core_type" ]; then
                    core_type=$(cat "/mssb/sing-box/core_type")
                else
                    core_type="sing-box-reF1nd"  # 默认为 R核心
                fi
                
                # 根据核心类型选择对应的备份文件
                if [[ "$core_type" == "sing-box-reF1nd" ]]; then
                    latest_backup=$(ls -t "$backup_dir"/sing-box-r-config-*.json 2>/dev/null | head -n1)
                else
                    latest_backup=$(ls -t "$backup_dir"/sing-box-y-config-*.json 2>/dev/null | head -n1)
                fi
                ;;
            "mihomo")
                latest_backup=$(ls -t "$backup_dir"/mihomo-config-*.yaml 2>/dev/null | head -n1)
                ;;
            "mosdns")
                latest_backup=$(ls -t "$backup_dir"/mosdns-config-*.yaml 2>/dev/null | head -n1)
                ;;
            "proxy-device-list")
                latest_backup=$(ls -t "$backup_dir"/mosdns-proxy-device-list-*.txt 2>/dev/null | head -n1)
                ;;
        esac
        
        if [ -n "$latest_backup" ]; then
            echo -e "${green_text}发现 $config_type 的备份配置文件：${reset}"
            echo -e "备份文件：$latest_backup"
            read -p "是否恢复此备份？(y/n): " restore_choice
            if [ "$restore_choice" = "y" ]; then
                mkdir -p "$(dirname "$config_path")"
                cp "$latest_backup" "$config_path"
                log "$config_type 配置文件已从备份恢复"
                return 0
            fi
        fi
    fi
    return 1
}

# singbox配置文件复制（初始安装或更新安装时使用）
singbox_configure_files() {
    log "检查是否存在 /mssb/sing-box/config.json ..."
    CONFIG_JSON="/mssb/sing-box/config.json"
    backup_dir="/mssb/backup"
    mkdir -p "$backup_dir"
    
    # 获取当前核心类型
    if [ -f "/mssb/sing-box/core_type" ]; then
        core_type=$(cat "/mssb/sing-box/core_type")
    else
        core_type="sing-box-reF1nd"  # 默认为 R核心
    fi
    
    # 根据核心类型设置备份文件名
    if [[ "$core_type" == "sing-box-reF1nd" ]]; then
        BACKUP_JSON="$backup_dir/sing-box-r-config-$(date +%Y%m%d-%H%M%S).json"
        SOURCE_CONFIG="/mssb/sing-box/sing-box-r.json"
    else
        BACKUP_JSON="$backup_dir/sing-box-y-config-$(date +%Y%m%d-%H%M%S).json"
        SOURCE_CONFIG="/mssb/sing-box/sing-box-y.json"
    fi

    # 如果 config.json 存在，则进行备份
    if [ -f "$CONFIG_JSON" ]; then
        log "发现 config.json 文件，备份到 $backup_dir 目录..."
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

    # 复制对应核心的配置文件
    log "复制 $core_type 的配置文件..."
    if [ -f "$SOURCE_CONFIG" ]; then
        cp "$SOURCE_CONFIG" "$CONFIG_JSON" || { log "复制配置文件失败！退出脚本。"; exit 1; }
        log "成功复制 $core_type 配置文件到 /mssb/sing-box/config.json"
    else
        log "错误：找不到源配置文件 $SOURCE_CONFIG"
        exit 1
    fi
}

# singbox用户自定义设置（用于配置设置）
singbox_customize_settings() {
    echo -e "\n${green_text}=== Sing-box 配置设置 ===${reset}"
    echo -e "1. 检查是否有备份配置"
    echo -e "2. 生成新配置"
    echo -e "3. 手动配置"
    echo -e "${green_text}------------------------${reset}"
    
    # 检查并尝试恢复备份
    if check_and_restore_config "sing-box" "/mssb/sing-box/config.json"; then
        return
    fi
    
    read -p "请选择配置方式 (1/2/3): " config_choice
    
    case "$config_choice" in
        1)
            echo -e "${yellow}正在检查备份配置...${reset}"
            if check_and_restore_config "sing-box" "/mssb/sing-box/config.json"; then
                return
            else
                echo -e "${red}未找到备份配置，请选择其他配置方式${reset}"
                singbox_customize_settings
                return
            fi
            ;;
        2)
            echo -e "\n${green_text}=== 生成新配置 ===${reset}"
            echo -e "此选项将根据订阅链接自动生成配置"
            echo -e "注意："
            echo -e "1. 需要提供有效的订阅链接"
            echo -e "2. 多个订阅链接请用空格分隔"
            echo -e "3. 输入 q 可返回上一步"
            echo -e "${green_text}------------------------${reset}"
            
            while true; do
                read -p "请输入订阅链接（多个用空格分隔，输入 q 退出）： " suburls

                if [[ "$suburls" == "q" ]]; then
                    log "已取消自动生成配置，请手动编辑 /mssb/sing-box/config.json"
                    break
                fi

                valid=true
                for url in $suburls; do
                    if [[ $url != http* ]]; then
                        echo -e "${red}❌ 无效的订阅链接：$url（应以 http 开头）${reset}"
                        valid=false
                        break
                    fi
                done

                if [ "$valid" = true ]; then
                    echo -e "${green_text}✅ 已设置订阅链接地址：$suburls${reset}"
                    python3 update_sub.py -v "$suburls"
                    log "订阅链接处理完成"
                    break
                else
                    log "部分订阅链接不符合要求，请重新输入"
                fi
            done
            ;;
        3)
            echo -e "\n${yellow}请手动编辑 /mssb/sing-box/config.json${reset}"
            echo -e "配置文件位置：/mssb/sing-box/config.json"
            echo -e "编辑完成后请确保配置正确"
            ;;
        *)
            echo -e "${red}无效选择，请重新选择${reset}"
            singbox_customize_settings
            ;;
    esac
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
    echo -e "\n${green_text}=== Mihomo 配置设置 ===${reset}"
    echo -e "1. 检查是否有备份配置"
    echo -e "2. 生成新配置"
    echo -e "3. 手动配置"
    echo -e "${green_text}------------------------${reset}"
    
    # 检查并尝试恢复备份
    if check_and_restore_config "mihomo" "/mssb/mihomo/config.yaml"; then
        return
    fi
    
    read -p "请选择配置方式 (1/2/3): " config_choice
    
    case "$config_choice" in
        1)
            echo -e "${yellow}正在检查备份配置...${reset}"
            if check_and_restore_config "mihomo" "/mssb/mihomo/config.yaml"; then
                return
            else
                echo -e "${red}未找到备份配置，请选择其他配置方式${reset}"
                mihomo_customize_settings
                return
            fi
            ;;
        2)
            echo -e "\n${green_text}=== 生成新配置 ===${reset}"
            echo -e "此选项将根据订阅链接自动生成配置"
            echo -e "注意："
            echo -e "1. 需要提供有效的订阅链接"
            echo -e "2. mihomo模式暂时只支持单个订阅链接"
            echo -e "3. 输入 q 可返回上一步"
            echo -e "${green_text}------------------------${reset}"
            
            while true; do
                read -p "请输入订阅链接（输入 q 返回上一步）: " suburl
                if [[ "$suburl" == "q" ]]; then
                    log "已取消自动生成配置，请手动编辑 /mssb/mihomo/config.yaml"
                    break
                elif [[ -n "$suburl" ]]; then
                    if [[ $suburl != http* ]]; then
                        echo -e "${red}❌ 无效的订阅链接：$suburl（应以 http 开头）${reset}"
                        continue
                    fi
                    escaped_url=$(printf '%s\n' "$suburl" | sed 's/[&/\]/\\&/g')
                    sed -i "s|url: '机场订阅'|url: '$escaped_url'|" /mssb/mihomo/config.yaml
                    sed -i "s|interface-name: eth0|interface-name: $selected_interface|" /mssb/mihomo/config.yaml
                    echo -e "${green_text}✅ 订阅链接已写入${reset}"
                    break
                else
                    echo -e "${red}订阅链接不能为空，请重新输入或输入 q 退出${reset}"
                fi
            done
            ;;
        3)
            echo -e "\n${yellow}请手动编辑 /mssb/mihomo/config.yaml${reset}"
            echo -e "配置文件位置：/mssb/mihomo/config.yaml"
            echo -e "编辑完成后请确保配置正确"
            ;;
        *)
            echo -e "${red}无效选择，请重新选择${reset}"
            mihomo_customize_settings
            ;;
    esac
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
        log "默认y继续进行"
        selected_interface="$interface_name"
        log "您选择的网卡是: $selected_interface"
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
# mosdns配置文件复制
mosdns_configure_files() {
    log "检查是否存在 /mssb/mosdns/config.yaml ..."
    CONFIG_YAML="/mssb/mosdns/config.yaml"
    backup_dir="/mssb/backup"
    mkdir -p "$backup_dir"
    BACKUP_YAML="$backup_dir/mosdns-config-$(date +%Y%m%d-%H%M%S).yaml"

    # 如果 config.yaml 存在，则进行备份
    if [ -f "$CONFIG_YAML" ]; then
        log "发现 config.yaml 文件，备份到 $backup_dir 目录..."
        cp "$CONFIG_YAML" "$BACKUP_YAML" || { log "备份 config.yaml 失败！退出脚本。"; exit 1; }
    else
        log "未发现 config.yaml 文件，跳过备份步骤。"
    fi

    # 复制 mssb/mosdns 目录
    log "复制 mssb/mosdns 目录..."
    if [ -d "/mssb/mosdns" ]; then
        log "/mssb/mosdns 目录已存在，跳过替换。"
    else
        cp -r mssb/mosdns /mssb || { log "复制 mssb/mosdns 目录失败！退出脚本。"; exit 1; }
        log "成功复制 mssb/mosdns 目录到 /mssb"
    fi

    # 如果之前有备份 config.yaml，则恢复备份文件
    if [ -f "$BACKUP_YAML" ]; then
        log "恢复 config.yaml 文件到 /mssb/mosdns ..."
        cp "$BACKUP_YAML" "$CONFIG_YAML" || { log "恢复 config.yaml 失败！退出脚本。"; exit 1; }
        log "恢复完成"
    else
        # 使用默认配置，并提示用户修改 DNS
        echo -e "\n${yellow}=== 运营商 DNS 配置 ===${reset}"
        echo -e "默认已设置第一、第二解析为阿里公共 DNS：${green_text}223.5.5.5${reset}"
        echo -e "当前第三解析配置的运营商 DNS 为：${green_text}202.102.128.68${reset}"
        echo -e "建议修改为您所在运营商的 DNS 服务器地址，否则可能影响解析速度"
        echo -e "常见运营商 DNS：可以参考 https://ipw.cn/doc/else/dns.html"
        echo -e "  阿里：223.5.5.5, 223.6.6.6"
        echo -e "  腾讯：119.29.29.29, 119.28.28.28"
        echo -e "${green_text}------------------------${reset}"
        
        read -p "请输入您的运营商 DNS 地址（直接回车使用腾讯作为第三解析 119.29.29.29）：" dns_addr
        if [ -n "$dns_addr" ]; then
            # 验证输入的 IP 地址格式
            if [[ $dns_addr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                # 替换配置文件中的 DNS 地址
                sed -i "s/addr: \"202.102.128.68\"/addr: \"$dns_addr\"/" "$CONFIG_YAML"
                log "已更新运营商 DNS 地址为：$dns_addr"
            else
                log "输入的 DNS 地址格式不正确，将使用默认值 119.29.29.29"
                sed -i "s/addr: \"202.102.128.68\"/addr: \"119.29.29.29\"/" "$CONFIG_YAML"
            fi
        else
            log "使用默认 DNS 地址：119.29.29.29"
            sed -i "s/addr: \"202.102.128.68\"/addr: \"119.29.29.29\"/" "$CONFIG_YAML"
        fi
    fi
}

# 复制 mssb/mosdns fb 配置文件
cp_config_files() {
    log "复制 mssb/fb 目录..."
    check_and_copy_folder "fb"

    # 检查并恢复 mosdns 配置
    echo -e "\n${green_text}=== MosDNS 配置设置 ===${reset}"
    echo -e "1. 检查是否有备份配置"
    echo -e "2. 使用默认配置"
    echo -e "${green_text}------------------------${reset}"
    
    read -p "请选择配置方式 (1/2): " mosdns_choice
    
    case "$mosdns_choice" in
        1)
            # 检查是否有备份配置
            if check_and_restore_config "mosdns" "/mssb/mosdns/config.yaml"; then
                log "已从备份恢复 mosdns config.yaml"
            else
                log "未找到 mosdns config.yaml 备份，将使用默认配置"
                mosdns_configure_files
            fi
            
            # 检查并恢复 proxy-device-list.txt
            if check_and_restore_config "proxy-device-list" "/mssb/mosdns/proxy-device-list.txt"; then
                log "已从备份恢复 proxy-device-list.txt"
            else
                log "未找到 proxy-device-list.txt 备份，将使用默认配置"
            fi
            ;;
        2)
            log "使用默认 MosDNS 配置..."
            mosdns_configure_files
            ;;
        *)
            echo -e "${red}无效选择，将使用默认配置${reset}"
            mosdns_configure_files
            ;;
    esac

    # Filebrowser 配置设置
    # 启动 filebrowser 到后台
    filebrowser -c /mssb/fb/fb.json -d /mssb/fb/fb.db &
    # 记录进程 PID
    FB_PID=$!
    # 等待 2 秒让它初始化数据库
    sleep 1
    # 杀掉进程
    kill $FB_PID 2>/dev/null
    # 确保进程被杀死
    wait $FB_PID 2>/dev/null

    echo -e "\n${green_text}=== Filebrowser 配置设置 ===${reset}"
    echo -e "1. 启用密码登录（默认， 默认用户密码安装完提示，进入后可自行修改）"
    echo -e "2. 禁用密码登录（无需登录即可访问）"
    echo -e "${green_text}------------------------${reset}"
    
    read -p "请选择 Filebrowser 登录方式 (1/2): " fb_choice
    
    case "$fb_choice" in
        2)
            log "正在配置 Filebrowser 为无密码登录模式..."
            filebrowser config set --auth.method=noauth -c /mssb/fb/fb.json -d /mssb/fb/fb.db
            log "Filebrowser 已配置为无密码登录模式"
            ;;
        *)
            log "使用默认的密码登录模式..."
            filebrowser config set --auth.method=json -c /mssb/fb/fb.json -d /mssb/fb/fb.db
            log "Filebrowser 已配置为密码登录模式"
            ;;
    esac

    log "复制supervisor配置文件..."
    if [ "$core_name" = "sing-box" ]; then
        cp run_mssb/supervisord.conf /etc/supervisor/ || {
            log "复制 supervisord.conf 失败！退出脚本。"
            exit 1
        }
    elif [ "$core_name" = "mihomo" ]; then
        cp run_msmo/supervisord.conf /etc/supervisor/ || {
            log "复制 supervisord.conf 失败！退出脚本。"
            exit 1
        }
    else
        log "未识别的 core_name: $core_name，跳过复制 supervisor 配置文件。"
    fi

    # Supervisor 配置设置
    echo -e "\n${green_text}=== Supervisor 管理配置设置 ===${reset}"
    echo -e "1. 使用默认用户名密码（mssb/mssb123..）"
    echo -e "2. 自定义用户名密码"
    echo -e "3. 不设置用户名密码"
    echo -e "${green_text}------------------------${reset}"
    
    read -p "请选择 Supervisor 管理配置方式 (1/2/3): " supervisor_choice
    
    case "$supervisor_choice" in
        2)
            read -p "请输入用户名: " supervisor_username
            read -p "请输入密码: " supervisor_password
            
            if [ -n "$supervisor_username" ] && [ -n "$supervisor_password" ]; then
                sed -i "s/^username=.*/username=$supervisor_username/" /etc/supervisor/supervisord.conf
                sed -i "s/^password=.*/password=$supervisor_password/" /etc/supervisor/supervisord.conf
                log "已设置自定义 Supervisor 用户名和密码"
            else
                log "用户名或密码为空，将使用默认设置"
                sed -i "s/^username=.*/username=mssb/" /etc/supervisor/supervisord.conf
                sed -i "s/^password=.*/password=mssb123../" /etc/supervisor/supervisord.conf
            fi
            ;;
        3)
            sed -i "s/^username=.*/username=/" /etc/supervisor/supervisord.conf
            sed -i "s/^password=.*/password=/" /etc/supervisor/supervisord.conf
            log "已清除 Supervisor 用户名和密码设置"
            ;;
        *)
            sed -i "s/^username=.*/username=mssb/" /etc/supervisor/supervisord.conf
            sed -i "s/^password=.*/password=mssb123../" /etc/supervisor/supervisord.conf
            log "已设置默认 Supervisor 用户名和密码"
            ;;
    esac

    cp -r watch / || {
        log "复制 watch 目录失败！退出脚本。"
        exit 1
    }

    log "设置脚本可执行权限..."
    chmod +x /watch/*.sh || {
        log "设置 /watch/*.sh 权限失败！退出脚本。"
        exit 1
    }
}

# mihomo配置文件复制
mihomo_configure_files() {
    log "检查是否存在 /mssb/mihomo/config.yaml ..."
    CONFIG_YAML="/mssb/mihomo/config.yaml"
    backup_dir="/mssb/backup"
    mkdir -p "$backup_dir"
    BACKUP_YAML="$backup_dir/mihomo-config-$(date +%Y%m%d-%H%M%S).yaml"

    # 如果 config.yaml 存在，则进行备份
    if [ -f "$CONFIG_YAML" ]; then
        log "发现 config.yaml 文件，备份到 $backup_dir 目录..."
        cp "$CONFIG_YAML" "$BACKUP_YAML" || { log "备份 config.yaml 失败！退出脚本。"; exit 1; }
    else
        log "未发现 config.yaml 文件，跳过备份步骤。"
    fi

    # 复制 mssb/mihomo 目录
    log "复制 mssb/mihomo 目录..."
    if [ -d "/mssb/mihomo" ]; then
        log "/mssb/mihomo 目录已存在，跳过替换。"
    else
        cp -r mssb/mihomo /mssb || { log "复制 mssb/mihomo 目录失败！退出脚本。"; exit 1; }
        log "成功复制 mssb/mihomo 目录到 /mssb"
    fi

    # 如果之前有备份 config.yaml，则恢复备份文件
    if [ -f "$BACKUP_YAML" ]; then
        log "恢复 config.yaml 文件到 /mssb/mihomo ..."
        cp "$BACKUP_YAML" "$CONFIG_YAML" || { log "恢复 config.yaml 失败！退出脚本。"; exit 1; }
        log "恢复完成"
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
        # 确保 mihomo-router 服务被禁用和停止
        systemctl stop mihomo-router 2>/dev/null
        systemctl disable mihomo-router 2>/dev/null
        rm -f /etc/systemd/system/mihomo-router.service
        
        # 启动 sing-box-router
        systemctl daemon-reload
        systemctl enable --now sing-box-router || { log "启用 sing-box-router 服务失败！"; exit 1; }
        log "已重启 sing-box-router 服务。"
    elif [ "$core_name" = "mihomo" ]; then
        # 确保 sing-box-router 服务被禁用和停止
        systemctl stop sing-box-router 2>/dev/null
        systemctl disable sing-box-router 2>/dev/null
        rm -f /etc/systemd/system/sing-box-router.service
        
        # 启动 mihomo-router
        systemctl daemon-reload
        systemctl enable --now mihomo-router || { log "启用 mihomo-router 服务失败！"; exit 1; }
        log "已重启 mihomo-router 服务。"
    else
        log "未识别的 core_name: $core_name，跳过 systemd 服务重启。"
    fi
}
# 添加任务到 crontab
add_cron_jobs() {
    echo -e "\n${green_text}=== 定时更新任务设置 ===${reset}"
    
    # 先清除所有相关的定时任务
    (crontab -l | grep -v -e "# update_mosdns" -e "# update_sb" -e "# update_cn" -e "# update_mihomo") | crontab -
    log "已清除所有相关定时任务"
    
    # 询问是否更新 MosDNS
    read -p "是否启用 MosDNS 自动更新？(y/n) [默认: y]: " update_mosdns
    update_mosdns=${update_mosdns:-y}
    
    # 询问是否更新 CN 域名数据
    read -p "是否启用 MosDNS CN 域名数据自动更新？(y/n) [默认: y]: " update_cn
    update_cn=${update_cn:-y}
    
    # 根据核心类型询问相应的更新选项
    if [ "$core_name" = "sing-box" ]; then
        read -p "是否启用 Sing-box 自动更新？(y/n) [默认: y]: " update_core
        update_core=${update_core:-y}
        
        cron_jobs=()
        
        # 根据用户选择添加任务
        if [[ "$update_mosdns" =~ ^[Yy]$ ]]; then
            cron_jobs+=("0 4 * * 1 /watch/update_mosdns.sh # update_mosdns")
        fi
        
        if [[ "$update_cn" =~ ^[Yy]$ ]]; then
            cron_jobs+=("15 4 * * 1 /watch/update_cn.sh # update_cn")
        fi
        
        if [[ "$update_core" =~ ^[Yy]$ ]]; then
            cron_jobs+=("10 4 * * 1 /watch/update_sb.sh # update_sb")
        fi
        
    elif [ "$core_name" = "mihomo" ]; then
        read -p "是否启用 Mihomo 自动更新？(y/n) [默认: y]: " update_core
        update_core=${update_core:-y}
        
        cron_jobs=()
        
        # 根据用户选择添加任务
        if [[ "$update_mosdns" =~ ^[Yy]$ ]]; then
            cron_jobs+=("0 4 * * 1 /watch/update_mosdns.sh # update_mosdns")
        fi
        
        if [[ "$update_cn" =~ ^[Yy]$ ]]; then
            cron_jobs+=("15 4 * * 1 /watch/update_cn.sh # update_cn")
        fi
        
        if [[ "$update_core" =~ ^[Yy]$ ]]; then
            cron_jobs+=("10 4 * * 1 /watch/update_mihomo.sh # update_mihomo")
        fi
    else
        log "未识别的 core_name（$core_name），跳过定时任务设置。"
        return
    fi

    # 如果没有选择任何更新任务
    if [ ${#cron_jobs[@]} -eq 0 ]; then
        log "未选择任何更新任务，跳过定时任务设置。"
        return
    fi

    # 添加选中的定时任务
    for job in "${cron_jobs[@]}"; do
        if (crontab -l | grep -q -F "$job"); then
            log "定时任务已存在：$job"
        else
            (crontab -l; echo "$job") | crontab -
            log "定时任务已成功添加：$job"
        fi
    done
}

# 停止所有服务
stop_all_services() {
    log "正在停止所有服务..."
    
    # 停止 supervisor 管理的服务
    if command -v supervisorctl &>/dev/null; then
        supervisorctl stop all 2>/dev/null || true
    fi
    
    # 停止并禁用 sing-box-router
    if systemctl is-active sing-box-router &>/dev/null; then
        systemctl stop sing-box-router
        systemctl disable sing-box-router
    fi
    
    # 停止并禁用 mihomo-router
    if systemctl is-active mihomo-router &>/dev/null; then
        systemctl stop mihomo-router
        systemctl disable mihomo-router
    fi
    
    # 停止并禁用 nftables
    if systemctl is-active nftables &>/dev/null; then
        systemctl stop nftables
        systemctl disable nftables
    fi
    
    systemctl daemon-reload
    log "所有服务已停止。"
}

# 检查并设置本地 DNS
check_and_set_local_dns() {
    # 获取当前 DNS 设置
    current_dns=$(cat /etc/resolv.conf | grep -E "^nameserver" | head -n 1 | awk '{print $2}')
    
    if [ "$current_dns" != "$local_ip" ]; then
        echo -e "\n${yellow}提示：当前 DNS 设置不是本地 IP ($local_ip)${reset}"
        echo -e "${yellow}建议将 DNS 设置为本地 IP 以使用 MosDNS 服务${reset}"
        echo -e "${green_text}请选择操作：${reset}"
        echo -e "1) 设置为本地 IP ($local_ip)"
        echo -e "2) 保持当前设置 ($current_dns)"
        echo -e "${green_text}-------------------------------------------------${reset}"
        read -p "请输入选项 (1/2): " dns_choice

        case $dns_choice in
            1)
                echo "nameserver $local_ip" > /etc/resolv.conf
                echo -e "${green_text}已设置 DNS 为本地 IP ($local_ip)${reset}"
                ;;
            2)
                echo -e "${yellow}保持当前 DNS 设置 ($current_dns)${reset}"
                ;;
            *)
                echo -e "${red}无效选项，将保持当前设置${reset}"
                ;;
        esac
    else
        echo -e "${green_text}当前 DNS 已设置为本地 IP ($local_ip)${reset}"
    fi
}

# 启动所有服务
start_all_services() {
    log "正在启动所有服务..."
    
    # 检查并启动 nftables
    if [ -f "/etc/nftables.conf" ]; then
        # 备份当前配置
        cp /etc/nftables.conf /etc/nftables.conf.bak
        
        # 检查配置语法
        if nft -c -f /etc/nftables.conf; then
            nft flush ruleset
            sleep 1
            nft -f /etc/nftables.conf
            systemctl enable --now nftables || log "nftables 服务启动失败"
        else
            log "nftables 配置有语法错误，已取消加载"
            cp /etc/nftables.conf.bak /etc/nftables.conf
        fi
    fi
    
    # 检查并启动对应的路由服务
    if [ -f "/etc/systemd/system/sing-box-router.service" ]; then
        systemctl enable --now sing-box-router || log "sing-box-router 服务启动失败"
    elif [ -f "/etc/systemd/system/mihomo-router.service" ]; then
        systemctl enable --now mihomo-router || log "mihomo-router 服务启动失败"
    fi
    
    # 启动 supervisor 管理的服务
    if command -v supervisorctl &>/dev/null; then
        supervisorctl start all || log "supervisor 服务启动失败"
    fi
    
    log "所有服务启动完成。"
}

# 卸载所有服务
uninstall_all_services() {
    log "正在卸载所有服务..."
    
    # 停止所有服务
    stop_all_services
    
    # 创建备份目录
    backup_dir="/mssb/backup"
    mkdir -p "$backup_dir"
    
    # 检查当前使用的核心类型
    if [ -f "/mssb/sing-box/core_type" ]; then
        core_type=$(cat "/mssb/sing-box/core_type")
        log "检测到当前使用的核心类型：$core_type"
        
        # 根据核心类型备份配置文件
        if [[ "$core_type" == "sing-box-reF1nd" ]]; then
            if [ -f "/mssb/sing-box/config.json" ]; then
                log "备份 sing-box R核心配置文件..."
                cp "/mssb/sing-box/config.json" "$backup_dir/sing-box-r-config-$(date +%Y%m%d-%H%M%S).json"
            fi
        else
            if [ -f "/mssb/sing-box/config.json" ]; then
                log "备份 sing-box Y核心配置文件..."
                cp "/mssb/sing-box/config.json" "$backup_dir/sing-box-y-config-$(date +%Y%m%d-%H%M%S).json"
            fi
        fi
    else
        log "未检测到核心类型记录"
    fi
    
    if [ -f "/mssb/mihomo/config.yaml" ]; then
        log "备份 mihomo 配置文件..."
        cp "/mssb/mihomo/config.yaml" "$backup_dir/mihomo-config-$(date +%Y%m%d-%H%M%S).yaml"
    fi
    
    if [ -f "/mssb/mosdns/proxy-device-list.txt" ]; then
        log "备份 mosdns proxy-device-list.txt..."
        cp "/mssb/mosdns/proxy-device-list.txt" "$backup_dir/mosdns-proxy-device-list-$(date +%Y%m%d-%H%M%S).txt"
    fi

    if [ -f "/mssb/mosdns/config.yaml" ]; then
        log "备份 mosdns config.yaml..."
        cp "/mssb/mosdns/config.yaml" "$backup_dir/mosdns-config-$(date +%Y%m%d-%H%M%S).yaml"
    fi
    
    # 删除服务文件
    rm -f /etc/systemd/system/sing-box-router.service
    rm -f /etc/systemd/system/mihomo-router.service
    rm -f /etc/nftables.conf
    
    # 删除程序文件
    rm -f /usr/local/bin/mosdns
    rm -f /usr/local/bin/sing-box
    rm -f /usr/local/bin/mihomo
    rm -f /usr/local/bin/filebrowser
    
    # 删除配置目录（保留备份目录）
    find /mssb -mindepth 1 -maxdepth 1 -not -name "backup" -exec rm -rf {} +
    
    # 删除 supervisor 配置
    rm -f /etc/supervisor/supervisord.conf
    
    # 卸载 supervisor
    if command -v apt-get &>/dev/null; then
        apt-get remove -y supervisor >/dev/null 2>&1
        apt-get purge -y supervisor >/dev/null 2>&1
    fi
    
    # 清理定时任务
    log "清理定时任务..."
    (crontab -l | grep -v -e "# update_mosdns" -e "# update_sb" -e "# update_cn" -e "# update_mihomo") | crontab -
    
    systemctl daemon-reload
    log "所有服务已卸载完成。配置文件已备份到 $backup_dir 目录"
    log "卸载的核心类型：$core_type"
}

# 记录 Sing-box 核心版本
record_singbox_core() {
    local core_type=$1
    echo "$core_type" > /mssb/sing-box/core_type
    log "已记录 Sing-box 核心类型：$core_type 在/mssb/sing-box/core_type文件夹"
}

# reF1nd佬 R核心安装函数
singbox_r_install() {
    arch=$(detect_architecture)
    download_url="https://github.com/herozmy/StoreHouse/releases/download/sing-box-reF1nd/sing-box-reF1nd-dev-linux-${arch}.tar.gz"

    log "开始下载 reF1nd佬 R核心..."
    if ! wget -O sing-box.tar.gz "$download_url"; then
        error_log "下载失败，请检查网络连接"
        exit 1
    fi
    
    log "下载完成，开始安装"
    tar -zxvf sing-box.tar.gz > /dev/null 2>&1
    mv sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    rm -f sing-box.tar.gz
    
    # 记录核心类型
    record_singbox_core "sing-box-reF1nd"
}

# S核安装函数
singbox_s_install() {
    arch=$(detect_architecture)
    download_url="https://github.com/herozmy/StoreHouse/releases/download/sing-box-yelnoo/sing-box-yelnoo-linux-${arch}.tar.gz"

    log "开始下载 S佬Y核心..."
    if ! wget -O sing-box.tar.gz "$download_url"; then
        error_log "下载失败，请检查网络连接"
        exit 1
    fi
    
    log "下载完成，开始安装"
    tar -zxvf sing-box.tar.gz > /dev/null 2>&1
    mv sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    rm -f sing-box.tar.gz
    
    # 记录核心类型
    record_singbox_core "sing-box-yelnoo"
}

# P核安装函数
singbox_p_install() {
    arch=$(detect_architecture)
    download_url="https://github.com/herozmy/StoreHouse/releases/download/sing-box/sing-box-puernya-linux-${arch}.tar.gz"

    log "开始下载 Puer喵佬核心..."
    if ! wget -O sing-box.tar.gz "$download_url"; then
        error_log "下载失败，请检查网络连接"
        exit 1
    fi
    
    log "下载完成，开始安装"
    tar -zxvf sing-box.tar.gz
    mv sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    rm -f sing-box.tar.gz
    
    # 记录核心类型
    record_singbox_core "sing-box-puernya"
}

# 曦灵X核心安装函数
singbox_x_install() {
    arch=$(detect_architecture)
    download_url="https://github.com/herozmy/StoreHouse/releases/download/sing-box-x/sing-box-x.tar.gz"

    log "开始下载 曦灵X核心..."
    if ! wget -O sing-box.tar.gz "$download_url"; then
        error_log "下载失败，请检查网络连接"
        exit 1
    fi
    
    log "下载完成，开始安装"
    tar -zxvf sing-box.tar.gz > /dev/null 2>&1
    mv sing-box_linux_amd64 sing-box
    mv sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    rm -f sing-box.tar.gz
    
    # 记录核心类型
    record_singbox_core "sing-box-x"
}

# 修改 Supervisor 配置
modify_supervisor_config() {
    echo -e "\n${green_text}请选择 Supervisor 管理界面配置方式：${reset}"
    echo -e "${green_text}1) 使用默认配置（用户名：mssb，密码：mssb123..）${reset}"
    echo -e "${green_text}2) 自定义用户名和密码${reset}"
    echo -e "${green_text}3) 不设置用户名密码${reset}"
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "请输入选项 (1/2/3): " supervisor_choice

    case $supervisor_choice in
        1)
            # 使用默认配置
            supervisor_username="mssb"
            supervisor_password="mssb123.."
            ;;
        2)
            # 自定义用户名和密码
            read -p "请输入用户名: " supervisor_username
            read -p "请输入密码: " supervisor_password
            ;;
        3)
            # 不设置用户名密码
            supervisor_username=""
            supervisor_password=""
            ;;
        *)
            echo -e "${red_text}无效的选项${reset}"
            return 1
            ;;
    esac

    # 更新 Supervisor 配置
    if [ -f "/etc/supervisor/supervisord.conf" ]; then
        if [ -n "$supervisor_username" ] && [ -n "$supervisor_password" ]; then
            sed -i "s/^username=.*/username=$supervisor_username/" /etc/supervisor/supervisord.conf
            sed -i "s/^password=.*/password=$supervisor_password/" /etc/supervisor/supervisord.conf
        else
            sed -i "s/^username=.*/username=/" /etc/supervisor/supervisord.conf
            sed -i "s/^password=.*/password=/" /etc/supervisor/supervisord.conf
        fi
        systemctl restart supervisor.service
        supervisorctl reload
        echo -e "${green_text}Supervisor 配置已更新${reset}"
    else
        echo -e "${red_text}Supervisor 配置文件不存在${reset}"
        return 1
    fi
}

# 修改 Filebrowser 配置
modify_filebrowser_config() {
    echo -e "\n${green_text}请选择 Filebrowser 登录方式：${reset}"
    echo -e "${green_text}1) 使用密码登录${reset}"
    echo -e "${green_text}2) 禁用密码登录${reset}"
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "请输入选项 (1/2): " fb_choice

    case $fb_choice in
        1)
            # 使用密码登录
            if [ -f "/mssb/fb/fb.db" ]; then
                echo -e "\n${green_text}请选择密码设置方式：${reset}"
                echo -e "${green_text}1) 使用默认密码（admin/admin）${reset}"
                echo -e "${green_text}2) 自定义密码${reset}"
                echo -e "${green_text}-------------------------------------------------${reset}"
                read -p "请输入选项 (1/2): " password_choice

                supervisorctl stop filebrowser
                filebrowser config set --auth.method=json -c /mssb/fb/fb.json -d /mssb/fb/fb.db

                case $password_choice in
                    1)
                        # 使用默认密码
                        filebrowser users update admin --password "admin" -c /mssb/fb/fb.json -d /mssb/fb/fb.db
                        echo -e "${green_text}Filebrowser 已设置为使用默认密码（admin/admin）${reset}"
                        ;;
                    2)
                        # 自定义密码
                        read -p "请输入新密码（输入时可见）: " new_password
                        if [ -n "$new_password" ]; then
                            filebrowser users update admin --password "$new_password" -c /mssb/fb/fb.json -d /mssb/fb/fb.db
                            echo -e "${green_text}Filebrowser 密码已更新${reset}"
                        else
                            echo -e "${red_text}密码不能为空，将使用默认密码${reset}"
                            filebrowser users update admin --password "admin" -c /mssb/fb/fb.json -d /mssb/fb/fb.db
                        fi
                        ;;
                    *)
                        echo -e "${red_text}无效的选项，将使用默认密码${reset}"
                        filebrowser users update admin --password "admin" -c /mssb/fb/fb.json -d /mssb/fb/fb.db
                        ;;
                esac

                supervisorctl start filebrowser
            else
                echo -e "${red_text}Filebrowser 配置文件不存在${reset}"
                return 1
            fi
            ;;
        2)
            # 禁用密码登录
            if [ -f "/mssb/fb/fb.db" ]; then
                supervisorctl stop filebrowser
                filebrowser config set --auth.method=noauth -c /mssb/fb/fb.json -d /mssb/fb/fb.db
                supervisorctl start filebrowser
                echo -e "${green_text}Filebrowser 已禁用密码登录${reset}"
            else
                echo -e "${red_text}Filebrowser 配置文件不存在${reset}"
                return 1
            fi
            ;;
        *)
            echo -e "${red_text}无效的选项${reset}"
            return 1
            ;;
    esac
}

# 修改服务配置
modify_service_config() {
    echo -e "\n${green_text}请选择要修改的配置：${reset}"
    echo -e "${green_text}1) 修改 Supervisor 管理界面配置${reset}"
    echo -e "${green_text}2) 修改 Filebrowser 登录方式${reset}"
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "请输入选项 (1/2): " config_choice

    case $config_choice in
        1)
            modify_supervisor_config
            ;;
        2)
            modify_filebrowser_config
            ;;
        *)
            echo -e "${red_text}无效的选项${reset}"
            return 1
            ;;
    esac
}

# 检查 DNS 设置
check_dns_settings() {
    # 获取当前 DNS 设置
    current_dns=$(cat /etc/resolv.conf | grep -E "^nameserver" | head -n 1 | awk '{print $2}')
    
    if [ "$current_dns" = "$local_ip" ]; then
        echo -e "\n${yellow}警告：检测到当前 DNS 设置为本地 IP ($local_ip)${reset}"
        echo -e "${yellow}建议在停止服务前修改 DNS 设置，否则可能导致无法访问网络${reset}"
        echo -e "${green_text}请选择操作：${reset}"
        echo -e "1) 使用阿里 DNS (223.5.5.5)"
        echo -e "2) 使用腾讯 DNS (119.29.29.29)"
        echo -e "3) 自定义 DNS"
        echo -e "4) 保持当前设置"
        echo -e "${green_text}-------------------------------------------------${reset}"
        read -p "请输入选项 (1/2/3/4): " dns_choice

        case $dns_choice in
            1)
                echo "nameserver 223.5.5.5" > /etc/resolv.conf
                echo -e "${green_text}已设置 DNS 为 223.5.5.5${reset}"
                ;;
            2)
                echo "nameserver 119.29.29.29" > /etc/resolv.conf
                echo -e "${green_text}已设置 DNS 为 119.29.29.29${reset}"
                ;;
            3)
                read -p "请输入自定义 DNS 地址: " custom_dns
                if [[ $custom_dns =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    echo "nameserver $custom_dns" > /etc/resolv.conf
                    echo -e "${green_text}已设置 DNS 为 $custom_dns${reset}"
                else
                    echo -e "${red}无效的 DNS 地址格式，将使用默认的阿里 DNS${reset}"
                    echo "nameserver 223.5.5.5" > /etc/resolv.conf
                fi
                ;;
            4)
                echo -e "${yellow}保持当前 DNS 设置 ($current_dns)${reset}"
                ;;
            *)
                echo -e "${red}无效选项，将使用默认的阿里 DNS${reset}"
                echo "nameserver 223.5.5.5" > /etc/resolv.conf
                ;;
        esac
    fi
}

# 格式化路由规则并提示
format_route_rules() {
    echo -e "\n${yellow}请在主路由中添加以下路由规则：${reset}"

    # 主路由 DNS 设置
    echo -e "${green_text}┌───────────────────────────────────────────────┐${reset}"
    echo -e "${green_text}│ 主路由 DNS 设置                                 │${reset}"
    echo -e "${green_text}├───────────────────────────────────────────────┤${reset}"
    printf "${green_text}│ %-15s %-29s │${reset}\n" "DNS 服务器:" "$local_ip"
    echo -e "${green_text}└───────────────────────────────────────────────┘${reset}"

    # MosDNS 和 Mihomo fakeip 路由
    echo -e "${green_text}┌───────────────────────────────────────────────┐${reset}"
    echo -e "${green_text}│ MosDNS 和 Mihomo fakeip 路由                    │${reset}"
    echo -e "${green_text}├───────────────────────┬───────────────────────┤${reset}"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "目标地址" "网关"
    echo -e "${green_text}├───────────────────────┼───────────────────────┤${reset}"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "28.0.0.0/16" "$local_ip"
    echo -e "${green_text}└───────────────────────┴───────────────────────┘${reset}"

    # Telegram 路由
    echo -e "${green_text}┌───────────────────────────────────────────────┐${reset}"
    echo -e "${green_text}│ Telegram 路由                                   │${reset}"
    echo -e "${green_text}├───────────────────────┬───────────────────────┤${reset}"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "目标地址" "网关"
    echo -e "${green_text}├───────────────────────┼───────────────────────┤${reset}"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "149.154.160.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "149.154.164.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "149.154.172.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "91.108.4.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "91.108.20.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "91.108.56.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "91.108.8.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "95.161.64.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "91.108.12.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "91.108.16.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "67.198.55.0/24" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "109.239.140.0/24" "$local_ip"
    echo -e "${green_text}└───────────────────────┴───────────────────────┘${reset}"

    # Netflix 路由
    echo -e "${green_text}┌───────────────────────────────────────────────┐${reset}"
    echo -e "${green_text}│ Netflix 路由                                    │${reset}"
    echo -e "${green_text}├───────────────────────┬───────────────────────┤${reset}"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "目标地址" "网关"
    echo -e "${green_text}├───────────────────────┼───────────────────────┤${reset}"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "207.45.72.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "208.75.76.0/22" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "210.0.153.0/24" "$local_ip"
    printf "${green_text}│ %-21s │ %-21s │${reset}\n" "185.76.151.0/24" "$local_ip"
    echo -e "${green_text}└───────────────────────┴───────────────────────┘${reset}"

    echo -e "\n${yellow}注意：${reset}"
    echo -e "1. 请确保主路由已开启 IP 转发功能"
    echo -e "2. 所有路由的网关都设置为本机 IP：$local_ip"
    echo -e "3. 主路由的 DNS 服务器必须设置为本机 IP：$local_ip"
    echo -e "4. 添加路由后，相关服务将自动通过本机代理"
    echo -e "${green_text}-------------------------------------------------${reset}"
    echo -e "${green_text} routeros 具体可以参考: https://github.com/baozaodetudou/mssb/blob/main/docs/fakeip.md ${reset}"
}

# 主函数
main() {
    green_text="\e[32m"
    red_text="\e[31m"
    reset="\e[0m"

    # 主菜单
    echo -e "${green_text}------------------------注意：请使用 root 用户安装！！！-------------------------${reset}"
    echo -e "${green_text}请选择操作：${reset}"
    echo -e "${green_text}1) 安装/更新代理转发服务${reset}"
    echo -e "${red_text}2) 停止所有转发服务${reset}"
    echo -e "${red_text}3) 停止所有服务并卸载 + 删除所有相关文件${reset}"
    echo -e "${green_text}4) 启用所有服务${reset}"
    echo -e "${green_text}5) 修改服务配置${reset}"
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "请输入选项 (1/2/3/4/5): " main_choice

    case "$main_choice" in
        2)
            stop_all_services
            # 检查 DNS 设置
            check_dns_settings
            exit 0
            ;;
        3)
            uninstall_all_services
            # 检查 DNS 设置
            check_dns_settings
            exit 0
            ;;
        4)
            start_all_services
            # 检查并设置本地 DNS
            check_and_set_local_dns
            exit 0
            ;;
        5)
            # 修改服务配置
            modify_service_config
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
    echo -e "${green_text}Fake-ip 网关代理方案：sing-box/mihomo + MosDNS${reset}"
    echo "---支持 debian，其他系统未测试。理论上支持debian/ubuntu 安装前请确保系统未安装其他代理软件---"
    echo "---完全参考 https://github.com/herozmy/StoreHouse/tree/latest ---"
    echo -e "当前机器地址:${green_text}${local_ip}${reset}"
    check_installed
    check_core_status
    echo -e "${green_text}-------------------------------------------------${reset}"
    echo

    echo -e "${green_text}请选择安装方案：${reset}"
    echo "1) 方案1：Sing-box (支持订阅) + MosDNS"
    echo "2) 方案2：Mihomo + MosDNS"
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "请输入选项 (1/2): " choice
    case "$choice" in
        1)
            core_name="sing-box"
            log "你选择了方案1：Sing-box (支持订阅) + MosDNS"

            # 显示 Sing-box 核心版本选择
            echo -e "\n${green_text}请选择 Sing-box 核心版本：${reset}"
            echo -e "${yellow}1. Sing-box reF1nd佬 R核心${reset} <支持订阅> ${green_text}推荐${reset}"
            echo -e "${yellow}2. Sing-box S佬Y核心${reset} <支持订阅> ${green_text}推荐${reset}"
            echo -e "${yellow}说明: Sing-box Puer喵佬核心${reset} <支持订阅> ${green_text}停更不再支持${reset}"
            echo -e "${yellow}说明: Sing-box 曦灵X核心${reset} <支持订阅> ${green_text}停更不在支持${reset}"
            echo -e "${green_text}-------------------------------------------------${reset}"
            read -p "请输入选项 (1/2): " singbox_choice

            install_filebrower
            install_mosdns

            case "$singbox_choice" in
                1)
                    log "你选择了 Sing-box reF1nd佬 R核心"
                    singbox_r_install
                    ;;
                2)
                    log "你选择了 Sing-box S佬Y核心"
                    singbox_s_install
                    ;;
                *)
                    log "无效选项，将使用默认的 reF1nd佬 R核心"
                    singbox_r_install
                    ;;
            esac

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
        echo "- 4:15 更新 CN 域名数据"
    fi
    echo -e "${green_text}-------------------------------------------------${reset}"
    read -p "是否添加定时任务？(y/n): " enable_cron
    if [[ "$enable_cron" == "y" || "$enable_cron" == "Y" ]]; then
        add_cron_jobs
    else
        log "用户选择不添加定时任务。"
    fi

    # 检查并设置本地 DNS
    check_and_set_local_dns

    # 显示路由规则提示
    format_route_rules

    echo -e "${green_text}-------------------------------------------------${reset}"
    echo -e "${green_text}🎉 安装成功！以下是服务信息：${reset}"
    echo -e "🌐 Mosdns 统计界面：${green_text}http://${local_ip}:9099/graphic${reset}"
    echo
    echo -e "📦 Supervisor 管理界面：${green_text}http://${local_ip}:9001${reset}"
    if [ "$supervisor_choice" = "3" ]; then
        echo -e "   - 无需登录"
    elif [ "$supervisor_choice" = "2" ] && [ -n "$supervisor_username" ] && [ -n "$supervisor_password" ]; then
        echo -e "   - 用户名：$supervisor_username"
        echo -e "   - 密码：$supervisor_password"
    else
        echo -e "   - 用户名：mssb"
        echo -e "   - 密码：mssb123.."
    fi
    echo
    echo -e "🗂️  文件管理服务 Filebrowser：${green_text}http://${local_ip}:8088${reset}"
    if [ "$fb_choice" = "2" ]; then
        echo -e "   - 无需登录"
    else
        echo -e "   - 用户名：admin"
        echo -e "   - 密码：admin"
    fi
    echo
    echo -e "🕸️  Sing-box/Mihomo 面板 UI：${green_text}http://${local_ip}:9090/ui${reset}"
    echo -e "${green_text}-------------------------------------------------${reset}"


    log "脚本执行完成。"
}


main
