#!/bin/bash
# ==========================================
# 秋名山一键修改 DNS 脚本 (适配 qmstool 工具箱)
# ==========================================

if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m❌ 错误：请使用 root 权限运行此脚本\033[0m"
    exit 1
fi

clear
echo -e "\033[36m==================================================\033[0m"
echo -e "             秋名山一键修改 DNS 脚本              "
echo -e "\033[36m==================================================\033[0m"
echo -e " 1) Cloudflare   1.1.1.1"
echo -e " 2) Cloudflare   1.0.0.1"
echo -e " 3) Google       8.8.8.8"
echo -e " 4) Google       8.8.4.4"
echo -e " 5) 阿里云       223.5.5.5"
echo -e " 6) 阿里云       223.6.6.6"
echo -e " 7) 腾讯云       119.29.29.29"
echo -e " 8) 自定义 DNS"
echo -e " 0) 取消并返回主菜单"
echo -e "\033[36m==================================================\033[0m"

printf "请输入序号 [0-8]: "
read choice

case "$choice" in
    1) DNS_IP="1.1.1.1"     ;;
    2) DNS_IP="1.0.0.1"     ;;
    3) DNS_IP="8.8.8.8"     ;;
    4) DNS_IP="8.8.4.4"     ;;
    5) DNS_IP="223.5.5.5"   ;;
    6) DNS_IP="223.6.6.6"   ;;
    7) DNS_IP="119.29.29.29";;
    8)
        printf "请输入自定义 DNS IP: "
        read DNS_IP
        if ! echo "$DNS_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
            echo -e "\033[31m❌ 无效的 IP 地址！\033[0m"
            exit 1
        fi
        ;;
    0) 
        echo "取消操作..."
        exit 0 
        ;;
    *)
        echo -e "\033[31m❌ 无效的选择。\033[0m"
        exit 1
        ;;
esac

cp /etc/resolv.conf /etc/resolv.conf.bak.$(date +%Y%m%d%H%M%S)
echo "nameserver $DNS_IP" > /etc/resolv.conf
echo -e "\033[32m✅ 已成功将 DNS 更改为：$DNS_IP\033[0m"