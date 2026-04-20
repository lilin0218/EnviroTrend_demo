#!/bin/bash

# 数据拉取脚本 - 从开发板获取数据库和日志文件到项目目录

set -e

echo "===================================="
echo "EnviroTrend_demo 数据拉取脚本"
echo "===================================="

# 配置
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT="$SCRIPT_DIR/.."
BOARD_USER="debian"
BOARD_IP="192.168.3.86"
BOARD_DB_PATH="/home/debian/deploy/dbData/enviro_data.db"
BOARD_LOG_PATH="/home/debian/deploy/logFile"

# 目标目录 - 项目根目录下的单独文件夹
TARGET_DIR="$PROJECT_ROOT/deploy_backup"

echo ""
echo "1. 准备目标目录..."
mkdir -p "$TARGET_DIR/dbData"
mkdir -p "$TARGET_DIR/logFile"
echo "   目标目录：$TARGET_DIR"

echo ""
echo "2. 从开发板拉取数据库文件..."
echo "   源：$BOARD_USER@$BOARD_IP:$BOARD_DB_PATH"
echo "   目标：$TARGET_DIR/dbData/"

if rsync -avz --progress "$BOARD_USER@$BOARD_IP:$BOARD_DB_PATH" "$TARGET_DIR/dbData/"; then
    echo "   [成功] 数据库文件拉取成功"
else
    echo "   [警告] 数据库文件拉取失败（可能文件不存在）"
fi

echo ""
echo "3. 从开发板拉取日志文件..."
echo "   源：$BOARD_USER@$BOARD_IP:$BOARD_LOG_PATH/"
echo "   目标：$TARGET_DIR/logFile/"

if rsync -avz --progress "$BOARD_USER@$BOARD_IP:$BOARD_LOG_PATH/" "$TARGET_DIR/logFile/"; then
    echo "   [成功] 日志文件拉取成功"
else
    echo "   [警告] 日志文件拉取失败（可能目录不存在）"
fi

echo ""
echo "4. 拉取内容清单："
echo "------------------------"
echo "数据库文件："
ls -la "$TARGET_DIR/dbData/" 2>/dev/null || echo "   (空)"
echo ""
echo "日志文件："
ls -la "$TARGET_DIR/logFile/" 2>/dev/null || echo "   (空)"

echo ""
echo "===================================="
echo "[成功] 数据拉取完成！"
echo "===================================="
echo "所有文件已保存到：$TARGET_DIR"
echo ""
echo "数据库文件：$TARGET_DIR/dbData/enviro_data.db"
echo "日志文件：$TARGET_DIR/logFile/"
echo "===================================="