#!/bin/bash

# ==========================================
# 基础配置与个人信息
# ==========================================
CURRENT_VERSION="1.0.0"
RAW_URL="https://raw.githubusercontent.com/qmsdh/qmstool/main"
WEBSITE="https://blog.qmsdh.com/" 
TG_GROUP="https://t.me/qmsdh_chat"

# 字体颜色定义
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 必须以 root 用户运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：必须使用 root 权限运行此脚本！${PLAIN}" 
   exit 1
fi

check_update() {
    echo -e "${YELLOW}正在连接 GitHub 检查工具箱更新...${PLAIN}"
    REMOTE_VERSION=$(curl -fsSL --connect-timeout 5 "${RAW_URL}/version.txt" | tr -d '\r\n ')
    
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}检查更新失败，请检查网络连接或 GitHub 访问状态。${PLAIN}"
    elif [ "$REMOTE_VERSION" != "$CURRENT_VERSION" ]; then
        echo -e "${GREEN}发现新版本 [$REMOTE_VERSION]！当前版本 [$CURRENT_VERSION]${PLAIN}"
        read -p "是否现在自动升级工具箱？(y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            echo -e "${YELLOW}正在从仓库下载最新版工具箱...${PLAIN}"
            curl -fsSL "${RAW_URL}/qmstool.sh" -o /usr/local/bin/qmstool
            chmod +x /usr/local/bin/qmstool
            echo -e "${GREEN}升级成功！请重新输入 qmstool 启动新版本。${PLAIN}"
            exit 0
        fi
    else
        echo -e "${GREEN}当前已是最新版本 ($CURRENT_VERSION)。${PLAIN}"
    fi
    echo ""
    read -p "按回车键返回主菜单..."
}

show_banner() {
    clear
    echo -e "${BLUE}==================================================${PLAIN}"
    echo -e "          ${GREEN}欢迎使用 QMS Linux 聚合工具箱${PLAIN}          "
    echo -e "          版本: ${YELLOW}v$CURRENT_VERSION${PLAIN}   "
    echo -e "          官网: ${BLUE}$WEBSITE${PLAIN} "
    echo -e "          TG群: ${BLUE}$TG_GROUP${PLAIN} "
    echo -e "${BLUE}==================================================${PLAIN}"
}

while true; do
    show_banner
    echo -e "${YELLOW}[ 自研核心功能 ]${PLAIN}"
    echo -e " 1. 一键修改 DNS"
    echo -e " 2. 一键配置 Swap 虚拟内存"
    echo -e " 3. 一键多开 Alist 网盘"
    echo ""
    echo -e "${YELLOW}[ 聚合网络一键端 ]${PLAIN}"
    echo -e " 4. 一键搭建 Vless+hy2 节点 (fscarmen-Sing-Box)"
    echo -e " 5. 一键运行 官方版 Speedtest 测速"
    echo ""
    echo -e "${YELLOW}[ 工具箱管理 ]${PLAIN}"
    echo -e " 6. 检查并更新主控程序"
    echo -e " 0. 退出工具箱"
    echo -e "${BLUE}==================================================${PLAIN}"
    
    read -p "请输入数字选择功能: " choice
    
    case $choice in
        1)
            echo -e "${YELLOW}正在远程载入 DNS 配置脚本...${PLAIN}"
            bash <(curl -sSL "${RAW_URL}/dns_set.sh")
            read -p "执行完毕，按回车键返回主菜单..."
            ;;
        2)
            echo -e "${YELLOW}正在远程载入 Swap 配置脚本...${PLAIN}"
            bash <(curl -sSL "${RAW_URL}/swap_set.sh")
            ;;
        3)
            echo -e "${YELLOW}正在远程载入 Alist 配置脚本...${PLAIN}"
            bash <(curl -sSL "${RAW_URL}/alist_set.sh")
            ;;
        4)
            echo -e "${YELLOW}正在运行 Vless 一键搭建脚本...${PLAIN}"
            bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) -l --LANGUAGE c --CHOOSE_PROTOCOLS bcj --START_PORT 20000 --PORT_NGINX y
            read -p "脚本执行完毕，按回车键返回主菜单..."
            ;;
        5)
            echo -e "${YELLOW}正在安装并运行 Ookla Speedtest...${PLAIN}"
            apt-get update -y
            apt-get install -y curl
            curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
            apt-get install -y speedtest
            echo -e "${GREEN}环境配置完毕，开始测速：${PLAIN}"
            speedtest
            read -p "测速完毕，按回车键返回主菜单..."
            ;;
        6)
            check_update
            ;;
        0)
            echo -e "${GREEN}感谢使用 QMS 工具箱，再见！${PLAIN}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效输入，请重新选择！${PLAIN}"
            sleep 1
            ;;
    esac
done