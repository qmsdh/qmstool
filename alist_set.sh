#!/bin/bash
# (此部分由于篇幅过长，省略了上半部分未变动的函数，你只需要把 alist_set.sh 最下方的 SHOW_MENU 和主程序入口改成如下内容即可)
# 【注意】直接找到你 alist_set.sh 文件的最底部，替换成下面的代码：

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
  echo -e "${RED_COLOR}  0. 返回主菜单${RES}"
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
    0) break ;;
    *) echo -e "${RED_COLOR}无效的选项${RES}" ;;
  esac
}

# 主程序入口 (强制交互式运行)
while true; do
  SHOW_MENU
  # 检查如果用户选择了 0 退出，直接跳出大循环
  if [ "$choice" = "0" ]; then
      break
  fi
  echo
  read -n 1 -s -r -p "按任意键继续..."
  clear
done