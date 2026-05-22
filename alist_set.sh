#!/bin/bash
###############################################################################
#
# Alist Manager Script (Multi-Instance Edition)
#
# Description:
#   A management script for Alist supporting multi-instance (多开版本)
#   Provides installation, update, uninstallation and instance management
#
###############################################################################

# 在脚本开头添加错误处理函数
handle_error() {
    local exit_code=$1
    local error_msg=$2
    echo -e "${RED_COLOR}错误：${error_msg}${RES}"
    exit ${exit_code}
}

# 颜色配置
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
CYAN_COLOR='\e[1;36m'
RES='\e[0m'

# 检查依赖
if ! command -v curl >/dev/null 2>&1; then
    handle_error 1 "未找到 curl 命令，请先安装"
fi

if ! command -v tar >/dev/null 2>&1; then
    handle_error 1 "未找到 tar 命令，请先安装"
fi

# 配置部分
GH_PROXY=""
GH_REPO="AlistGo/alist"
GH_DOWNLOAD_URL="https://github.com/${GH_REPO}/releases/latest/download"

clear

# 获取平台架构
if command -v arch >/dev/null 2>&1; then
  platform=$(arch)
else
  platform=$(uname -m)
fi

ARCH="UNKNOWN"
if [ "$platform" = "x86_64" ]; then
  ARCH=amd64
elif [ "$platform" = "aarch64" ]; then
  ARCH=arm64
fi

# 权限和环境检查
if [ "$(id -u)" != "0" ]; then
    echo -e "\r\n${RED_COLOR}错误：请使用 root 权限运行此命令！${RES}\r\n"
    echo -e "提示：使用 ${GREEN_COLOR}sudo $0 $1${RES} 重试\r\n"
    exit 1
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，一键安装目前仅支持 x86_64 和 arm64 平台。\r\n"
  exit 1
elif ! command -v systemctl >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，无法确定你当前的 Linux 发行版，需要 systemd 支持。\r\n"
  exit 1
fi

# ================= 核心：多开状态管理模块 =================

# 获取所有已安装的实例信息
LIST_INSTANCES() {
    local services=$(ls /etc/systemd/system/alist*.service 2>/dev/null)
    if [ -z "$services" ]; then
        return 1
    fi
    for svc_file in $services; do
        local svc_name=$(basename "$svc_file" .service)
        local work_dir=$(grep "WorkingDirectory=" "$svc_file" | cut -d'=' -f2)
        local port="未知"
        if [ -f "$work_dir/data/config.json" ]; then
            port=$(grep '"http_port"' "$work_dir/data/config.json" | grep -oE '[0-9]+' | head -n1)
        fi
        local status="已停止"
        if systemctl is-active "$svc_name" >/dev/null 2>&1; then
            status="${GREEN_COLOR}运行中${RES}"
        else
            status="${RED_COLOR}已停止${RES}"
        fi
        echo "$svc_name|$work_dir|$port|$status"
    done
    return 0
}

# 打印实例列表表格
VIEW_INSTANCES() {
    local instances
    instances=$(LIST_INSTANCES)
    if [ $? -ne 0 ] || [ -z "$instances" ]; then
        echo -e "${YELLOW_COLOR}当前未检测到已安装的 Alist 实例。${RES}"
        return 1
    fi
    echo -e "\n${CYAN_COLOR}========== 已安装的 Alist 实例列表 ==========${RES}"
    printf "${CYAN_COLOR}%-5s | %-18s | %-6s | %-25s | %s${RES}\n" "序号" "服务名称" "端口" "安装目录" "运行状态"
    echo "-------------------------------------------------------------------------------"
    local i=1
    while IFS='|' read -r svc dir port status; do
        printf "%-5s | %-18s | %-6s | %-25s | %b\n" "$i" "$svc" "$port" "$dir" "$status"
        i=$((i+1))
    done <<< "$instances"
    echo "-------------------------------------------------------------------------------"
    return 0
}

# 交互式选择实例
SELECT_INSTANCE() {
    local action_name=$1
    local instances
    instances=$(LIST_INSTANCES)
    if [ $? -ne 0 ] || [ -z "$instances" ]; then
        echo -e "${RED_COLOR}未找到任何已安装的 Alist 实例，无法执行[${action_name}]操作。${RES}"
        return 1
    fi

    echo -e "\n${CYAN_COLOR}========== 请选择要 [${action_name}] 的实例 ==========${RES}"
    printf "${CYAN_COLOR}%-5s | %-18s | %-6s | %-25s | %s${RES}\n" "序号" "服务名称" "端口" "安装目录" "运行状态"
    echo "-------------------------------------------------------------------------------"
    local i=1
    declare -A svc_map
    declare -A dir_map
    while IFS='|' read -r svc dir port status; do
        printf "%-5s | %-18s | %-6s | %-25s | %b\n" "$i" "$svc" "$port" "$dir" "$status"
        svc_map[$i]=$svc
        dir_map[$i]=$dir
        i=$((i+1))
    done <<< "$instances"
    echo "-------------------------------------------------------------------------------"
    read -p "请输入对应序号 (输入 0 取消): " sel_idx

    if [[ "$sel_idx" =~ ^[0-9]+$ ]] && [ "$sel_idx" -gt 0 ] && [ "$sel_idx" -lt "$i" ]; then
        TARGET_SVC="${svc_map[$sel_idx]}"
        INSTALL_PATH="${dir_map[$sel_idx]}"
        return 0
    else
        echo -e "${YELLOW_COLOR}已取消或输入无效。${RES}"
        return 1
    fi
}

# 全局变量
ADMIN_USER=""
ADMIN_PASS=""
TARGET_PORT=""
TARGET_SVC=""
INSTALL_PATH=""

# 构建文件名
build_filename() {
    local os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch_name=""
    if [ "$ARCH" = "amd64" ]; then arch_name="amd64"
    elif [ "$ARCH" = "arm64" ]; then arch_name="arm64"
    else arch_name="$ARCH"
    fi
    case "$os_name" in
        "linux") echo "alist-linux-musl-$arch_name.tar.gz" ;;
        "darwin") echo "alist-darwin-$arch_name.tar.gz" ;;
        "freebsd") echo "alist-freebsd-$arch_name.tar.gz" ;;
        *) echo "alist-linux-musl-$arch_name.tar.gz" ;;
    esac
}

# 获取最新版本
get_latest_version() {
    local api_url="https://dapi.alistgo.com/v0/version/latest"
    local version_info=$(curl -s --connect-timeout 10 "$api_url" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$version_info" ]; then
        local version=$(echo "$version_info" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        local platform=$(echo "$version_info" | grep -o '"platform":"[^"]*"' | cut -d'"' -f4)
        local download_url=$(echo "$version_info" | grep -o '"download_url":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$version" ] && [ -n "$platform" ] && [ -n "$download_url" ]; then
            echo "$version|$platform|$download_url"
            return 0
        fi
    fi
    return 1
}

# 下载器
download_file() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0
    local wait_time=5

    while [ $retry_count -lt $max_retries ]; do
        echo -e "${YELLOW_COLOR}下载地址: $url${RES}"
        if curl -fL --connect-timeout 10 --retry 3 --retry-delay 3 -w "\nHTTP:%{http_code}\n" "$url" -o "$output"; then
            if [ -f "$output" ] && [ -s "$output" ]; then
                if head -c 2 "$output" | od -An -t x1 | tr -d ' \n' | grep -qi '^1f8b'; then
                    return 0
                fi
            fi
        fi
        retry_count=$((retry_count + 1))
        [ $retry_count -lt $max_retries ] && sleep $wait_time && wait_time=$((wait_time + 5))
    done
    return 1
}

# ================= 安装与初始化逻辑 =================

PRE_INSTALL_CHECK() {
    # 动态计算默认目录和端口
    local current_count=$(ls /etc/systemd/system/alist*.service 2>/dev/null | wc -l)
    local next_id=$((current_count + 1))
    local default_dir="/opt/alist_${next_id}"

    local highest_port=5243
    local instances=$(LIST_INSTANCES)
    if [ -n "$instances" ]; then
        while IFS='|' read -r svc dir port status; do
            if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -gt "$highest_port" ]; then
                highest_port=$port
            fi
        done <<< "$instances"
    fi
    local default_port=$((highest_port + 1))

    echo -e "\n${CYAN_COLOR}--- 实例配置 ---${RES}"
    read -p "请输入多开安装目录 [默认: $default_dir]: " input_dir
    INSTALL_PATH=${input_dir:-$default_dir}

    read -p "请输入该实例监听端口 [默认: $default_port]: " input_port
    TARGET_PORT=${input_port:-$default_port}
    TARGET_SVC="alist_${TARGET_PORT}"

    # 检查服务和目录是否被占用
    if [ -f "/etc/systemd/system/${TARGET_SVC}.service" ]; then
        echo -e "${RED_COLOR}错误：服务 ${TARGET_SVC} 已存在，请更换端口。${RES}"
        return 1
    fi
    if [ -d "$INSTALL_PATH/alist" ]; then
        echo -e "${RED_COLOR}错误：目录 $INSTALL_PATH 中已存在 alist 执行文件。${RES}"
        return 1
    fi

    mkdir -p "$INSTALL_PATH" || { echo -e "${RED_COLOR}无法创建目录!${RES}"; return 1; }
    echo -e "${GREEN_COLOR}实例准备就绪：路径 -> $INSTALL_PATH | 端口 -> $TARGET_PORT${RES}"
    return 0
}

INSTALL() {
  CURRENT_DIR=$(pwd)
  echo -e "${GREEN_COLOR}正在获取最新版本信息...${RES}"
  local version_info=$(get_latest_version)
  local version=""
  
  if [ $? -eq 0 ] && [ -n "$version_info" ]; then
    version=$(echo "$version_info" | cut -d'|' -f1)
    echo -e "${GREEN_COLOR}最新版本: $version${RES}"
    echo -e "${GREEN_COLOR}请选择下载源：${RES}\n 1. 官方镜像 (推荐)\n 2. GitHub 源"
    read -p "请选择 [1-2]: " download_choice

    case "${download_choice:-1}" in
      1)
        local filename=$(build_filename)
        local official_url="https://alistgo.com/download/Alist/v$version/$filename"
        echo -e "\r\n${GREEN_COLOR}下载 Alist ...${RES}"
        if ! download_file "$official_url" "/tmp/alist.tar.gz"; then
          echo -e "${RED_COLOR}官方下载失败！${RES}"; exit 1
        fi
        ;;
      2)
        read -p "请输入 GitHub 代理地址 (例如: https://ghproxy.com/) 或回车跳过: " proxy_input
        GH_PROXY="$proxy_input"
        GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/${GH_REPO}/releases/latest/download"
        echo -e "\r\n${GREEN_COLOR}下载 Alist ...${RES}"
        if ! download_file "${GH_DOWNLOAD_URL}/$(build_filename)" "/tmp/alist.tar.gz"; then
          echo -e "${RED_COLOR}下载失败！${RES}"; exit 1
        fi
        ;;
    esac
  else
    echo -e "${YELLOW_COLOR}无法获取最新版本信息，默认使用 GitHub 源${RES}"
    GH_DOWNLOAD_URL="https://github.com/${GH_REPO}/releases/latest/download"
    if ! download_file "${GH_DOWNLOAD_URL}/$(build_filename)" "/tmp/alist.tar.gz"; then
      echo -e "${RED_COLOR}下载失败！${RES}"; exit 1
    fi
  fi

  # 解压并部署
  if ! tar zxf /tmp/alist.tar.gz -C "$INSTALL_PATH/"; then
    echo -e "${RED_COLOR}解压失败！${RES}"
    exit 1
  fi

  if [ -f "$INSTALL_PATH/alist" ]; then
    echo -e "${GREEN_COLOR}下载解压成功，正在初始化实例及生成密码...${RES}"
    cd "$INSTALL_PATH"
    mkdir -p data
    
    # 获取随机密码并生成 config.json (必须指定 --data 参数实现隔离)
    ACCOUNT_INFO=$(./alist admin random --data data 2>&1)
    ADMIN_USER=$(echo "$ACCOUNT_INFO" | grep -i "username:" | sed 's/.*username://' | tr -d ' ' | tr -d '\r')
    ADMIN_PASS=$(echo "$ACCOUNT_INFO" | grep -i "password:" | sed 's/.*password://' | tr -d ' ' | tr -d '\r')
    
    # 核心：自动修改端口信息以支持多开
    if [ -f "data/config.json" ]; then
        sed -i -E "s/\"http_port\":[ \t]*[0-9]+/\"http_port\": $TARGET_PORT/g" data/config.json
        echo -e "${GREEN_COLOR}已自动将实例端口修改为: $TARGET_PORT${RES}"
    else
        echo -e "${YELLOW_COLOR}警告：未找到 config.json，你可能需要手动配置端口。${RES}"
    fi
    cd "$CURRENT_DIR"
  else
    echo -e "${RED_COLOR}安装失败！${RES}"; exit 1
  fi
  rm -f /tmp/alist*
}

INIT() {
  cat >/etc/systemd/system/${TARGET_SVC}.service <<EOF
[Unit]
Description=Alist service (${TARGET_SVC})
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/alist server --data data
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ${TARGET_SVC} >/dev/null 2>&1
}

SUCCESS() {
  clear
  LOCAL_IP=$(ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1)
  PUBLIC_IP=$(curl -s4 ip.sb || curl -s4 ifconfig.me || echo "获取失败")

  echo -e "${CYAN_COLOR}======================================================${RES}"
  echo -e " Alist 多开实例创建成功！"
  echo -e ""
  echo -e " 实例名称：${TARGET_SVC}"
  echo -e " 访问地址："
  echo -e "   局域网：http://${LOCAL_IP}:${TARGET_PORT}/"
  echo -e "   公网：  http://${PUBLIC_IP}:${TARGET_PORT}/"
  echo -e " 安装目录：$INSTALL_PATH"
  echo -e ""
  if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
    echo -e " 账号信息："
    echo -e " 默认账号：${GREEN_COLOR}$ADMIN_USER${RES}"
    echo -e " 初始密码：${GREEN_COLOR}$ADMIN_PASS${RES}"
  fi
  echo -e "${CYAN_COLOR}======================================================${RES}"

  if ! INSTALL_CLI; then
    echo -e "${YELLOW_COLOR}提醒：全局命令行管理器更新跳过。${RES}"
  fi

  echo -e "\n${GREEN_COLOR}正在启动服务 [${TARGET_SVC}]...${RES}"
  systemctl restart ${TARGET_SVC}
  echo -e "\n管理: 随时输入 ${GREEN_COLOR}alist${RES} 或 ${GREEN_COLOR}alist-manager${RES} 调出本菜单"
}

# ================= 维护与管理逻辑 =================

UPDATE() {
    if ! SELECT_INSTANCE "更新"; then return; fi

    echo -e "${GREEN_COLOR}开始更新实例 [${TARGET_SVC}] ...${RES}"
    local version_info=$(get_latest_version)
    if [ $? -eq 0 ] && [ -n "$version_info" ]; then
        local version=$(echo "$version_info" | cut -d'|' -f1)
        echo -e "${GREEN_COLOR}最新版本: $version${RES}"
    fi

    echo -e "${GREEN_COLOR}停止服务 ${TARGET_SVC}${RES}"
    systemctl stop ${TARGET_SVC}
    cp "$INSTALL_PATH/alist" "/tmp/alist_bak_$TARGET_PORT"

    local official_url="https://alistgo.com/download/Alist/v$version/$(build_filename)"
    echo -e "${GREEN_COLOR}正在下载新版...${RES}"
    if ! download_file "$official_url" "/tmp/alist.tar.gz"; then
        echo -e "${RED_COLOR}下载失败，正在恢复...${RES}"
        mv "/tmp/alist_bak_$TARGET_PORT" "$INSTALL_PATH/alist"
        systemctl start ${TARGET_SVC}
        return 1
    fi

    tar zxf /tmp/alist.tar.gz -C "$INSTALL_PATH/"
    rm -f /tmp/alist.tar.gz "/tmp/alist_bak_$TARGET_PORT"
    
    echo -e "${GREEN_COLOR}启动服务 ${TARGET_SVC}${RES}"
    systemctl restart ${TARGET_SVC}
    echo -e "${GREEN_COLOR}实例 [${TARGET_SVC}] 更新完成！${RES}"
}

UNINSTALL() {
    if ! SELECT_INSTANCE "卸载"; then return; fi

    echo -e "${RED_COLOR}警告：即将卸载实例 [${TARGET_SVC}]，这会清空其在 ${INSTALL_PATH} 的所有文件！${RES}"
    read -p "确认卸载吗？[Y/n]: " choice
    case "${choice:-y}" in
        [yY]|"")
            echo -e "${GREEN_COLOR}停止并禁用服务...${RES}"
            systemctl stop ${TARGET_SVC}
            systemctl disable ${TARGET_SVC} 2>/dev/null
            
            echo -e "${GREEN_COLOR}删除相关文件...${RES}"
            rm -rf "$INSTALL_PATH"
            rm -f "/etc/systemd/system/${TARGET_SVC}.service"
            systemctl daemon-reload
            
            echo -e "${GREEN_COLOR}实例 [${TARGET_SVC}] 已彻底删除。${RES}"
            ;;
        *) echo -e "${GREEN_COLOR}已取消操作。${RES}" ;;
    esac
}

RESET_PASSWORD() {
    if ! SELECT_INSTANCE "重置密码"; then return; fi

    echo -e "\n请选择操作方式"
    echo -e "${GREEN_COLOR}1、生成随机密码${RES}"
    echo -e "${GREEN_COLOR}2、手动设置新密码${RES}"
    echo -e "0、返回主菜单"
    read -p "请输入选项 [0-2]: " choice

    cd "$INSTALL_PATH"
    case "$choice" in
        1)
            echo -e "${GREEN_COLOR}正在生成随机密码...${RES}"
            ./alist admin random --data data 2>&1 | grep -iE "username:|password:" | sed 's/.*username:/账号: /i' | sed 's/.*password:/密码: /i'
            ;;
        2)
            read -p "请输入新密码: " new_password
            if [ -z "$new_password" ]; then echo -e "${RED_COLOR}密码不能为空${RES}"; return; fi
            echo -e "${GREEN_COLOR}正在设置...${RES}"
            ./alist admin set "$new_password" --data data 2>&1 | grep -iE "username:|password:" | sed 's/.*username:/账号: /i' | sed 's/.*password:/密码: /i'
            ;;
        0) return ;;
    esac
}

INSTALL_CLI() {
    MANAGER_PATH="/usr/local/sbin/alist-manager"
    COMMAND_LINK="/usr/local/bin/alist"
    SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

    mkdir -p "$(dirname "$MANAGER_PATH")" "$(dirname "$COMMAND_LINK")"
    cp "$SCRIPT_PATH" "$MANAGER_PATH" && chmod 755 "$MANAGER_PATH"
    ln -sf "$MANAGER_PATH" "$COMMAND_LINK"
    return 0
}

# ================= 主菜单界面 =================

SHOW_MENU() {
  echo -e "\n${CYAN_COLOR}================================================${RES}"
  echo -e "${CYAN_COLOR}          Alist 多开管理脚本 (增强版)${RES}"
  echo -e "${CYAN_COLOR}================================================${RES}"
  echo -e "${GREEN_COLOR}  1. 安装新实例 (支持多开)${RES}"
  echo -e "${GREEN_COLOR}  2. 更新指定实例${RES}"
  echo -e "${GREEN_COLOR}  3. 卸载指定实例${RES}"
  echo -e "------------------------------------------------"
  echo -e "${GREEN_COLOR}  4. 查看已安装实例 (目录、端口、状态)${RES}"
  echo -e "${GREEN_COLOR}  5. 重置指定实例密码${RES}"
  echo -e "------------------------------------------------"
  echo -e "${GREEN_COLOR}  6. 启动实例${RES}"
  echo -e "${GREEN_COLOR}  7. 停止实例${RES}"
  echo -e "${GREEN_COLOR}  8. 重启实例${RES}"
  echo -e "------------------------------------------------"
  echo -e "${RED_COLOR}  0. 退出脚本${RES}"
  echo -e "${CYAN_COLOR}================================================${RES}"
  read -p "请输入对应数字执行操作 [0-8]: " choice

  case "$choice" in
    1)
      if PRE_INSTALL_CHECK; then
          INSTALL && INIT && SUCCESS
      fi
      ;;
    2) UPDATE ;;
    3) UNINSTALL ;;
    4) VIEW_INSTANCES ;;
    5) RESET_PASSWORD ;;
    6)
      if SELECT_INSTANCE "启动"; then
          systemctl start ${TARGET_SVC}
          echo -e "${GREEN_COLOR}服务 ${TARGET_SVC} 已下发启动命令${RES}"
      fi ;;
    7)
      if SELECT_INSTANCE "停止"; then
          systemctl stop ${TARGET_SVC}
          echo -e "${GREEN_COLOR}服务 ${TARGET_SVC} 已停止${RES}"
      fi ;;
    8)
      if SELECT_INSTANCE "重启"; then
          systemctl restart ${TARGET_SVC}
          echo -e "${GREEN_COLOR}服务 ${TARGET_SVC} 已重启${RES}"
      fi ;;
    0) exit 0 ;;
    *) echo -e "${RED_COLOR}无效的选项${RES}" ;;
  esac
}

# 主程序入口 (强制交互式运行)
while true; do
  SHOW_MENU
  echo
  read -n 1 -s -r -p "按任意键继续..."
  clear
done