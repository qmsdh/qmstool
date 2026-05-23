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

# 更新跳过记录文件路径
SKIP_FILE="$HOME/.qmstool_skip_version"

# 必须以 root 用户运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：必须使用 root 权限运行此脚本！${PLAIN}" 
   exit 1
fi

# ==========================================
# 启动时静默获取最新版本号
# ==========================================
# 设置 3 秒连接超时和 5 秒最大传输时间，防止网络不通导致脚本卡死
REMOTE_VERSION=$(curl -fsSL --connect-timeout 3 -m 5 "${RAW_URL}/version.txt" 2>/dev/null | tr -d '\r\n ')
if [[ -z "$REMOTE_VERSION" ]]; then
    REMOTE_VERSION="获取失败"
fi

# ==========================================
# 启动自动检查更新弹窗逻辑
# ==========================================
auto_check_update() {
    # 如果成功获取到远程版本，且远程版本与当前版本不一致
    if [[ "$REMOTE_VERSION" != "获取失败" && "$REMOTE_VERSION" != "$CURRENT_VERSION" ]]; then
        
        # 检查是否在跳过列表中
        if [[ -f "$SKIP_FILE" ]]; then
            SKIPPED_VERSION=$(cat "$SKIP_FILE")
            if [[ "$REMOTE_VERSION" == "$SKIPPED_VERSION" ]]; then
                return # 版本被标记为跳过，直接进入主菜单
            fi
        fi

        clear
        echo -e "${BLUE}==================================================${PLAIN}"
        echo -e "${GREEN}发现新版本！${PLAIN}"
        echo -e "当前版本: ${YELLOW}v$CURRENT_VERSION${PLAIN}"
        echo -e "最新版本: ${GREEN}v$REMOTE_VERSION${PLAIN}"
        echo -e "${BLUE}==================================================${PLAIN}"
        echo -e " 1. ${GREEN}立即更新${PLAIN} (自动下载并重新运行)"
        echo -e " 2. ${YELLOW}暂不更新${PLAIN} (下次运行脚本时仍会提示)"
        echo -e " 3. ${RED}跳过本次更新${PLAIN} (在出现更高版本前不再弹窗提示)"
        echo -e "${BLUE}==================================================${PLAIN}"
        read -p "请输入数字选择 [1-3]: " update_choice

        case $update_choice in
            1)
                echo -e "${YELLOW}正在从仓库下载最新版工具箱...${PLAIN}"
                curl -fsSL "${RAW_URL}/qmstool.sh" -o /usr/local/bin/qmstool
                chmod +x /usr/local/bin/qmstool
                # 更新成功后清理跳过记录文件
                rm -f "$SKIP_FILE"
                echo -e "${GREEN}升级成功！请重新输入 qmstool 启动新版本。${PLAIN}"
                exit 0
                ;;
            3)
                echo "$REMOTE_VERSION" > "$SKIP_FILE"
                echo -e "${YELLOW}已将 v$REMOTE_VERSION 标记为跳过，后续启动不再弹窗提示该版本。${PLAIN}"
                sleep 2
                ;;
            2|*)
                echo -e "${YELLOW}已暂缓更新，即将进入主菜单...${PLAIN}"
                sleep 1
                ;;
        esac
    fi
}

# ==========================================
# 手动检查更新逻辑 (菜单选项 6)
# ==========================================
check_update() {
    echo -e "${YELLOW}正在连接 GitHub 强制检查工具箱更新...${PLAIN}"
    # 手动检查时重新获取，忽略缓存和跳过记录
    LATEST_VERSION=$(curl -fsSL --connect-timeout 5 -m 5 "${RAW_URL}/version.txt" 2>/dev/null | tr -d '\r\n ')
    
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}检查更新失败，请检查网络连接或 GitHub 访问状态。${PLAIN}"
    elif [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
        echo -e "${GREEN}发现新版本 [v$LATEST_VERSION]！当前版本 [v$CURRENT_VERSION]${PLAIN}"
        read -p "是否现在自动升级工具箱？(y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            echo -e "${YELLOW}正在从仓库下载最新版工具箱...${PLAIN}"
            curl -fsSL "${RAW_URL}/qmstool.sh" -o /usr/local/bin/qmstool
            chmod +x /usr/local/bin/qmstool
            # 清理跳过记录
            rm -f "$SKIP_FILE"
            echo -e "${GREEN}升级成功！请重新输入 qmstool 启动新版本。${PLAIN}"
            exit 0
        fi
    else
        echo -e "${GREEN}当前已是最新版本 (v$CURRENT_VERSION)。${PLAIN}"
    fi
    echo ""
    read -p "按回车键返回主菜单..."
}

# ==========================================
# 界面展示与主循环
# ==========================================
show_banner() {
    clear
    echo -e "${BLUE}==================================================${PLAIN}"
    echo -e "          ${GREEN}欢迎使用 QMS Linux 聚合工具箱${PLAIN}          "
    echo -e "          当前版本: ${YELLOW}v$CURRENT_VERSION${PLAIN}   "
    # 在此处增加最新版本的显示
    if [[ "$REMOTE_VERSION" == "$CURRENT_VERSION" ]]; then
        echo -e "          最新版本: ${GREEN}v$REMOTE_VERSION (已是最新)${PLAIN}   "
    elif [[ "$REMOTE_VERSION" == "获取失败" ]]; then
         echo -e "          最新版本: ${RED}获取失败${PLAIN}   "
    else
        echo -e "          最新版本: ${RED}v$REMOTE_VERSION (可更新)${PLAIN}   "
    fi
    echo -e "          官网: ${BLUE}$WEBSITE${PLAIN} "
    echo -e "          TG群: ${BLUE}$TG_GROUP${PLAIN} "
    echo -e "${BLUE}==================================================${PLAIN}"
}

# 脚本运行之初执行一次自动检查逻辑
auto_check_update

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