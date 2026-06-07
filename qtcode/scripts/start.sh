#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CONFIG_FILE="$SCRIPT_DIR/ip_config.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[错误] 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 读取配置文件
source "$CONFIG_FILE"

# 检查配置文件中的 BOARD_IP 是否已设置
if [ -z "$BOARD_IP" ]; then
    echo "[错误] 配置文件中未设置 BOARD_IP 变量"
    exit 1
fi

echo "[信息] 从配置文件读取到 BOARD_IP: $BOARD_IP"

# 清除 eth2 现有配置
echo "[信息] 正在清除 eth2 现有配置..."
ip addr flush dev eth2 2>/dev/null
ifconfig eth2 0.0.0.0 2>/dev/null

# 设置 eth2 为配置文件中指定的 IP
echo "[信息] 正在设置 eth2 IP 为 $BOARD_IP ..."
ifconfig eth2 "$BOARD_IP" netmask 255.255.255.0 up

# 可选：添加默认网关（如果需要通过主机上网）
# route add default gw 192.168.137.1 eth2 2>/dev/null

# 显示设置后的 IP 确认
echo "[信息] eth2 当前配置："
ip addr show eth2 | grep inet

chmod 666 /dev/dht11

chmod 666 /dev/input/event*

echo "Startup configuration completed at $(date)"

cd "$(dirname "$0")"
export QT_QPA_PLATFORM=linuxfb
./EnviroTrend_demo
