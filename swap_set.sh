#!/bin/bash
# ==========================================
# 描述: Linux Swap 交换分区一键管理脚本
# ==========================================

SWAP_FILE="/swapfile"

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[31m❌ 错误: 请使用 root 权限运行此脚本 (例如: sudo bash $0)\033[0m"
        exit 1
    fi
}

# 创建并启用 Swap
create_swap() {
    local mode=$1
    echo -e "\n当前系统根目录可用空间如下："
    df -h /
    echo ""
    read -p "请输入需要设置的 Swap 大小 (单位: MB，例如 2048 表示 2GB): " swap_mb

    # 验证输入是否为纯数字
    if ! [[ "$swap_mb" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31m❌ 错误: 请输入有效的纯数字！\033[0m"
        return 1
    fi

    # 1. 关闭并清理旧的 Swap
    if swapon --show | grep -q "$SWAP_FILE"; then
        echo "正在关闭现有的 Swap..."
        swapoff "$SWAP_FILE"
    fi
    if [ -f "$SWAP_FILE" ]; then
        rm -f "$SWAP_FILE"
    fi

    # 2. 创建新的 Swap 文件 (使用 dd 确保最高兼容性)
    echo -e "\033[33m正在创建大小为 ${swap_mb}MB 的 Swap 文件，这可能需要几十秒时间，请耐心等待...\033[0m"
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$swap_mb" status=progress

    # 3. 设置权限和格式化
    echo "设置权限并格式化..."
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"

    # 4. 启用 Swap
    echo "启用 Swap..."
    swapon "$SWAP_FILE"

    # 5. 处理 fstab (清理旧记录，防止重复)
    sed -i "\|\^$SWAP_FILE|d" /etc/fstab 

    if [ "$mode" == "permanent" ]; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        echo -e "\033[32m✅ 成功: Swap 已创建并设置为【永久生效】(重启后依然保留)。\033[0m"
    else
        echo -e "\033[32m✅ 成功: Swap 已创建并设置为【临时生效】(重启后自动失效)。\033[0m"
    fi
}

# 一键删除 Swap
remove_swap() {
    echo -e "\033[33m正在关闭并删除 Swap...\033[0m"
    if swapon --show | grep -q "$SWAP_FILE"; then
        swapoff "$SWAP_FILE"
    fi
    if [ -f "$SWAP_FILE" ]; then
        rm -f "$SWAP_FILE"
    fi
    # 从 /etc/fstab 中安全移除配置
    sed -i "\|\^$SWAP_FILE|d" /etc/fstab
    echo -e "\033[32m✅ 成功: Swap 已彻底关闭并从系统中清理干净。\033[0m"
}

# 交互菜单
show_menu() {
    clear
    echo "======================================="
    echo "       Swap 交换分区一键管理工具       "
    echo "======================================="
    echo "  1. 设置自定义 Swap (临时生效)"
    echo "  2. 设置自定义 Swap (永久生效)"
    echo "  3. 一键关闭并彻底删除 Swap"
    echo "  4. 查看当前 Swap 状态"
    echo "  0. 退出脚本"
    echo "======================================="
    read -p "请输入选项 [0-4]: " choice

    case $choice in
        1) create_swap "temporary"; echo -e "\n按回车键继续..."; read ;;
        2) create_swap "permanent"; echo -e "\n按回车键继续..."; read ;;
        3) remove_swap; echo -e "\n按回车键继续..."; read ;;
        4) 
            echo -e "\n--- 当前 Swap 挂载情况 ---"
            swapon --show
            echo -e "\n--- 内存整体使用情况 ---"
            free -h
            echo -e "\n按回车键继续..."
            read 
            ;;
        0) echo "退出脚本。"; exit 0 ;;
        *) echo -e "\033[31m❌ 无效选项，请重新输入。\033[0m"; sleep 1 ;;
    esac
}

# 主程序入口
check_root
while true; do
    show_menu
done