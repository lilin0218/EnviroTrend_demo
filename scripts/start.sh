#!/bin/bash
# 启动脚本

cd "$(dirname "$0")"
export QT_QPA_PLATFORM=linuxfb
./EnviroTrend_demo
