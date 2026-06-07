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
DEPLOY_NAME="$PROJECT_ROOT/deploy"
LOCAL_DB_PATH="$PROJECT_ROOT/dbData/enviro_data.db"
REMOTE_DB_PATH="$BOARD_DEST/deploy/dbData/enviro_data.db"
COPY_DB="no"

echo "[部署] 扫描build文件夹..."
QT_PROJECT_DIR="$HOME/QtProject"
BUILD_FOLDERS=()
if [ -d "$QT_PROJECT_DIR" ]; then
    while IFS= read -r -d '' folder; do
        [ -f "$folder/EnviroTrend_demo" ] && BUILD_FOLDERS+=("$folder")
    done < <(find "$QT_PROJECT_DIR" -maxdepth 1 -type d -name "build-*" -print0)
else
    echo "[错误] QtProject目录不存在" && exit 1
fi

[ ${#BUILD_FOLDERS[@]} -eq 0 ] && echo "[错误] 未找到build文件夹" && exit 1
echo "[部署] 找到 ${#BUILD_FOLDERS[@]} 个build文件夹"
select BUILD_DIR in "${BUILD_FOLDERS[@]}"; do [ -n "$BUILD_DIR" ] && break; done
EXECUTABLE="$BUILD_DIR/EnviroTrend_demo"

echo "[部署] 验证可执行文件: $EXECUTABLE"
if ! file "$EXECUTABLE" | grep -q "ARM"; then
    read -p "[警告] 非ARM版本，继续？(y/N): " confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "已取消" && exit 0
fi

echo "[部署] 准备部署文件夹..."
rm -rf "$DEPLOY_NAME" && mkdir -p "$DEPLOY_NAME"
cp "$EXECUTABLE" "$DEPLOY_NAME/" && chmod +x "$DEPLOY_NAME/EnviroTrend_demo"
[ -f "$PROJECT_ROOT/src/pySrc/predict.py" ] && cp "$PROJECT_ROOT/src/pySrc/predict.py" "$DEPLOY_NAME/" && chmod +x "$DEPLOY_NAME/predict.py" || { echo "[错误] predict.py不存在"; exit 1; }
mkdir -p "$DEPLOY_NAME/dbData"

echo "[部署] 数据库处理..."
if ssh "$BOARD_USER@$BOARD_IP" "[ -f $REMOTE_DB_PATH ]" 2>/dev/null && [ -f "$LOCAL_DB_PATH" ]; then
    read -p "[询问] 是否覆盖远程数据库？(y/N): " copy_db_confirm
    [ "$copy_db_confirm" = "y" ] && COPY_DB="yes"
fi
[ "$COPY_DB" = "yes" ] && cp "$LOCAL_DB_PATH" "$DEPLOY_NAME/dbData/" || touch "$DEPLOY_NAME/dbData/.gitkeep"

echo "[部署] 复制模型文件..."
[ -d "$PROJECT_ROOT/models" ] && mkdir -p "$DEPLOY_NAME/models" && cp -r "$PROJECT_ROOT/models/"* "$DEPLOY_NAME/models/" || { echo "[错误] 模型文件夹不存在"; exit 1; }

echo "[部署] 复制配置文件..."
cp "$CONFIG_FILE" "$DEPLOY_NAME/" || { echo "[警告] 配置文件复制失败"; }

cat > "$DEPLOY_NAME/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
export QT_QPA_PLATFORM=linuxfb
./EnviroTrend_demo
EOF
chmod +x "$DEPLOY_NAME/start.sh"

echo "[部署] 目标: $BOARD_USER@$BOARD_IP:$BOARD_DEST/deploy (数据库: $COPY_DB)"
read -p "[询问] 确认传输？(Y/n): " transfer_confirm
[ "$transfer_confirm" = "n" ] && echo "已取消" && exit 0

echo "[部署] 传输中..."
if [ "$COPY_DB" = "yes" ]; then
    scp -r "$DEPLOY_NAME" "$BOARD_USER@$BOARD_IP:$BOARD_DEST/" && echo "[成功] 传输完成" || { echo "[错误] 传输失败"; exit 1; }
else
    scp -r "$DEPLOY_NAME"/{EnviroTrend_demo,predict.py,start.sh,models} "$BOARD_USER@$BOARD_IP:$BOARD_DEST/deploy/" && echo "[成功] 传输完成（数据库未覆盖）" || { echo "[错误] 传输失败"; exit 1; }
fi
echo "[提示] 在开发板运行: cd ~/deploy && ./start.sh"