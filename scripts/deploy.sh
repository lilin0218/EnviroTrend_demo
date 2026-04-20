#!/bin/bash

# 部署脚本 - 将 EnviroTrend_demo 项目部署到开发板
# 创建deploy文件夹并传输到开发板

set -e

echo "===================================="
echo "EnviroTrend_demo 部署脚本"
echo "===================================="

# 配置
# PROJECT_ROOT 基于脚本位置自动确定（scripts目录的父目录）
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT="$SCRIPT_DIR/.."
BOARD_USER="debian"
BOARD_IP="192.168.3.86"
BOARD_DEST="/home/debian"
DEPLOY_NAME="$PROJECT_ROOT/deploy"

# 查找QtProject目录下的build文件夹
QT_PROJECT_DIR="$HOME/QtProject"
BUILD_FOLDERS=()

echo ""
echo "1. 扫描QtProject目录下的build文件夹..."
if [ -d "$QT_PROJECT_DIR" ]; then
    while IFS= read -r -d '' folder; do
        if [ -f "$folder/EnviroTrend_demo" ]; then
            BUILD_FOLDERS+=("$folder")
        fi
    done < <(find "$QT_PROJECT_DIR" -maxdepth 1 -type d -name "build-*" -print0)
else
    echo "[错误] QtProject目录不存在: $QT_PROJECT_DIR"
    exit 1
fi

if [ ${#BUILD_FOLDERS[@]} -eq 0 ]; then
    echo "[错误] 未找到包含 EnviroTrend_demo 可执行文件的build文件夹"
    echo "请先编译项目"
    exit 1
fi

echo ""
echo "找到 ${#BUILD_FOLDERS[@]} 个build文件夹:"
select BUILD_DIR in "${BUILD_FOLDERS[@]}"; do
    if [ -n "$BUILD_DIR" ]; then
        echo "[选择] $BUILD_DIR"
        break
    else
        echo "[错误] 无效选择，请重新输入"
    fi
done

EXECUTABLE="$BUILD_DIR/EnviroTrend_demo"

echo ""
echo "2. 验证可执行文件..."
echo "   可执行文件: $EXECUTABLE"

# 检查可执行文件架构
FILE_INFO=$(file "$EXECUTABLE")
echo "   文件信息: $FILE_INFO"

if echo "$FILE_INFO" | grep -q "ARM"; then
    echo "[确认] 这是开发板用的 ARM 版本可执行文件"
else
    echo "[警告] 这可能不是ARM版本，请确认"
    read -p "是否继续？(y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "已取消部署"
        exit 0
    fi
fi

echo ""
echo "3. 准备部署文件夹..."

# 删除旧的deploy文件夹
if [ -d "$DEPLOY_NAME" ]; then
    rm -rf "$DEPLOY_NAME"
    echo "   [完成] 删除旧的deploy文件夹"
fi

# 创建deploy文件夹
mkdir -p "$DEPLOY_NAME"
echo "   [完成] 创建deploy文件夹"

# 复制可执行文件
cp "$EXECUTABLE" "$DEPLOY_NAME/"
chmod +x "$DEPLOY_NAME/EnviroTrend_demo"
echo "   [完成] 可执行文件已复制"

# 复制 Python 脚本（predict.py必须在可执行文件同级目录）
if [ -f "$PROJECT_ROOT/src/pySrc/predict.py" ]; then
    cp "$PROJECT_ROOT/src/pySrc/predict.py" "$DEPLOY_NAME/"
    chmod +x "$DEPLOY_NAME/predict.py"
    echo "   [完成] predict.py 已复制"
else
    echo "   [错误] predict.py 不存在"
    rm -rf "$DEPLOY_NAME"
    exit 1
fi

# 注意：开发板只需要predict.py，其他Python脚本不需要复制

# 复制数据库文件
mkdir -p "$DEPLOY_NAME/dbData"
if [ -f "$PROJECT_ROOT/dbData/enviro_data.db" ]; then
    cp "$PROJECT_ROOT/dbData/enviro_data.db" "$DEPLOY_NAME/dbData/"
    echo "   [完成] 数据库文件已复制"
else
    echo "   [提示] 数据库文件不存在，将在运行时自动创建"
fi

# 复制模型文件夹
if [ -d "$PROJECT_ROOT/models" ]; then
    mkdir -p "$DEPLOY_NAME/models"
    cp -r "$PROJECT_ROOT/models/"* "$DEPLOY_NAME/models/"
    echo "   [完成] 模型文件已复制"
else
    echo "   [错误] 模型文件夹不存在，无法继续部署"
    rm -rf "$DEPLOY_NAME"
    exit 1
fi

# 创建启动脚本
cat > "$DEPLOY_NAME/start.sh" << 'EOF'
#!/bin/bash
# 启动脚本

cd "$(dirname "$0")"
export QT_QPA_PLATFORM=linuxfb
./EnviroTrend_demo
EOF
chmod +x "$DEPLOY_NAME/start.sh"
echo "   [完成] 启动脚本已创建"

echo ""
echo "4. 部署文件夹内容："
find "$DEPLOY_NAME" -type f | sort

echo ""
echo "===================================="
echo "准备传输到开发板"
echo "目标: $BOARD_USER@$BOARD_IP:$BOARD_DEST/$DEPLOY_NAME"
echo "===================================="
read -p "确认传输？(y/n): " transfer_confirm

if [ "$transfer_confirm" = "y" ] || [ "$transfer_confirm" = "Y" ]; then
    echo ""
    echo "5. 传输deploy文件夹到开发板..."
    
    # 使用scp传输整个deploy文件夹
    if scp -r "$DEPLOY_NAME" "$BOARD_USER@$BOARD_IP:$BOARD_DEST/"; then
        echo ""
        echo "===================================="
        echo "[成功] 文件传输完成！"
        echo "===================================="
        echo ""
        echo "在开发板上运行："
        echo "  cd ~/deploy"
        echo "  ./start.sh"
        echo "  或者直接运行: ./EnviroTrend_demo"
        echo ""
        echo "查看数据库："
        echo "  cd ~/deploy"
        echo "  python3 pySrc/view_db.py"
        echo ""
        echo "注意："
        echo "  - 所有文件都在 ~/deploy/ 目录下"
        echo "  - predict.py 与可执行文件在同一目录"
        echo "  - 数据库文件在 dbData/ 目录"
        echo "===================================="
    else
        echo ""
        echo "[错误] 传输失败"
        echo "请检查："
        echo "  1. 开发板是否开机"
        echo "  2. 网络连接是否正常 (ping $BOARD_IP)"
        echo "  3. SSH 服务是否启动"
        echo "  4. 用户名和密码是否正确"
        exit 1
    fi
else
    echo ""
    echo "已取消传输"
    echo "部署文件夹保留在: $DEPLOY_NAME"
    echo "手动传输命令:"
    echo "  scp -r $DEPLOY_NAME $BOARD_USER@$BOARD_IP:$BOARD_DEST/"
fi
