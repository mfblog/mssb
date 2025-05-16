
# Mosdns + Singbox 虚拟机分流代理项目 纯自用版本

## 项目简介
自用项目目前没有适配新版本singbox

封装 `mosdns` 和 `singbox` 两个服务，实现高效的分流代理。同时，结合 `filebrowser` 用于配置文件的可视化管理，并使用 `MetaCubeXD` 作为 `singbox` 的前端显示界面。

完全参考 https://github.com/herozmy/StoreHouse/tree/latest 主要是想有个界面修改配置以及监听重启

---

## 项目功能

- **supervisor**: 进程管理
- **高效分流代理**：基于 `mosdns` 的 DNS 解析与 `singbox` 的代理功能。
- **可视化管理**：使用 `filebrowser` 管理 `mosdns` 和 `singbox` 的配置文件。
- **简洁前端**：通过 `MetaCubeXD` 提供 `singbox` 的用户界面。

---

## 架构图

```plaintext
+------------------+           +------------------+
|     filebrowser  |           |    MetaCubeXD    |
+------------------+           +------------------+
           |                             |
+------------------+           +------------------+
|      mosdns      | ----------->     singbox     |
+------------------+           +------------------+

服务端口分配：
- 8088: filebrowser（文件管理服务，默认账号密码 admin / admin）
- 9001: supervisor（进程管理界面，默认账号密码 mssb / mssb123..）
- 6666: singbox 的 DNS 服务端口
- 7891: singbox 的 SOCKS5 代理端口
- 7890: singbox 的 TProxy 透明代理端口
- 53: mosdns 的 DNS 服务端口
- 9090: singbox 的 Web UI 界面端口
```

---

## 安装命令

仅适用于 Debian 12 环境：

```bash
git clone https://github.com/baozaodetudou/mssb.git -b lxc && cd mssb && bash install.sh
```

---

## 查看日志

使用以下命令查看日志：

```bash
tail -f /var/log/supervisor/*.log
```

- **日志文件路径**: `/var/log/supervisor/*.log`
- **说明**:
    - `-f`: 持续输出最新日志内容
    - `*.log`: 匹配所有 `.log` 文件

---

## 备注

1. **文件管理服务（filebrowser）**
    - 服务端口：8088
    - 默认用户：`admin`
    - 默认密码：`admin`

2. **进程管理界面（supervisor）**
    - 服务端口：9001
    - 默认用户：`mssb`
    - 默认密码：`mssb123..`

3. **服务功能**
    - `mosdns` 提供 DNS 解析功能
    - `singbox` 实现代理服务，支持 SOCKS5 和透明代理模式
    - `MetaCubeXD` 提供用户友好的 Web 界面
4. **使用方法**
   - 安装完成后只需要把你主路由的dns设置成debain主机的ip
   - 支持分流设置,可以把你需要科学上网的设备ip写入/mssb/mosdns/proxy-device-list.txt 这个文件,只有ip在这个文件里的设备会走singbox代理，不在的只会走mosdns的加速功能

---

