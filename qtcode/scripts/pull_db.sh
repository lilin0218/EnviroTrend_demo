#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT="$SCRIPT_DIR/.."
CONFIG_FILE="$SCRIPT_DIR/ip_config.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[错误] 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

BOARD_DB_PATH="$BOARD_DEST/deploy/dbData/enviro_data.db"
BOARD_LOG_PATH="$BOARD_DEST/deploy/logFile"
TARGET_DIR="$PROJECT_ROOT/deploy_backup"

echo "[拉取] 准备目录..."
mkdir -p "$TARGET_DIR/dbData" "$TARGET_DIR/logFile"

echo "[拉取] 数据库..."
rsync -avz "$BOARD_USER@$BOARD_IP:$BOARD_DB_PATH" "$TARGET_DIR/dbData/" 2>/dev/null || echo "[警告] 数据库拉取失败"

echo "[拉取] 日志文件..."
rsync -avz "$BOARD_USER@$BOARD_IP:$BOARD_LOG_PATH/" "$TARGET_DIR/logFile/" 2>/dev/null || echo "[警告] 日志拉取失败"

echo "[成功] 完成，文件已保存到: $TARGET_DIR"