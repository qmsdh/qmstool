#!/bin/bash
# ==========================================
# 描述: Linux Swap 交换分区一键管理脚本
# ==========================================

SWAP_FILE="/swapfile"

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[31m❌ 错误: 请使用 root 权限运行此脚本\033[0m"
        exit 1
    fi
}

create_swap() {
    local mode=$1
    echo -e "\n当前系统根目录可用空间如下："
    df -h /
    echo ""
    read -p "请输入需要设置的 Swap 大小 (单位: MB，例如 2048 表示 2GB): " swap_mb

    if ! [[ "$swap_mb" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31m❌ 错误: 请输入有效的纯数字！\033[0m"
        return 1
    fi

    if swapon --show | grep -q "$SWAP_FILE"; then
        echo "正在关闭现有的 Swap..."
        swapoff "$SWAP_FILE"
    fi
    if [ -f "$SWAP_FILE" ]; then
        rm -f "$SWAP_FILE"
    fi

    echo -e "\033[33m正在创建大小为 ${swap_mb}MB 的 Swap 文件，请耐心等待...\033[0m"
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$swap_mb" status=progress

    echo "设置权限并格式化..."
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"

    echo "启用 Swap..."
    swapon "$SWAP_FILE"

    sed -i "\|\^$SWAP_FILE|d" /etc/fstab 

    if [ "$mode" == "permanent" ]; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        echo -e "\033[32m✅ 成功: Swap 已创建并设置为【永久生效】。\033[0m"
    else
        echo -e "\033[32m✅ 成功: Swap 已创建并设置为【临时生效】。\033[0m"
    fi
}

remove_swap() {
    echo -e "\033[33m正在关闭并删除 Swap...\033[0m"
    if swapon --show | grep -q "$SWAP_FILE"; then
        swapoff "$SWAP_FILE"
    fi
    if [ -f "$SWAP_FILE" ]; then
        rm -f "$SWAP_FILE"
    fi
    sed -i "\|\^$SWAP_FILE|d" /etc/fstab
    echo -e "\033[32m✅ 成功: Swap 已彻底关闭并清理干净。\033[0m"
}

show_menu() {
    clear
    echo "======================================="
    echo "       Swap 交换分区一键管理工具       "
    echo "======================================="
    echo "  1. 设置自定义 Swap (临时生效)"
    echo "  2. 设置自定义 Swap (永久生效)"
    echo "  3. 一键关闭并彻底删除 Swap"
    echo "  4. 查看当前 Swap 状态"
    echo "  0. 返回主菜单"
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
        0) echo "返回主菜单..."; break ;;
        *) echo -e "\033[31m❌ 无效选项，请重新输入。\033[0m"; sleep 1 ;;
    esac
}

check_root
while true; do
    show_menu
done