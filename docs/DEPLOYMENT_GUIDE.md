# EnviroTrend_demo 部署指南

## 概述

本项目提供了一个自动化部署脚本 `deploy.sh`，用于将 EnviroTrend_demo 项目打包并传输到开发板。

## 已确认的配置

### 1. 可执行文件验证
- **当前可执行文件**：`EnviroTrend_demo`
- **架构**：ELF 32-bit LSB executable, ARM, EABI5 version 1
- **确认**：这是开发板用的 ARM 版本可执行文件

### 2. 数据库路径配置
- **修改文件**：`src/core/backstage.cpp`
- **路径机制**：使用 `QCoreApplication::applicationDirPath()` 确保数据库路径与可执行文件位置相关联
- **数据库位置**：`可执行文件所在目录/dbData/enviro_data.db`
- **优势**：无论在哪个目录运行程序都能正确找到数据库

## 使用方法

### 方法 1：自动打包和传输（推荐）

```bash
# 运行部署脚本
./deploy.sh
```

**脚本功能**：
1. 验证可执行文件架构（ARM vs x86-64）
2. 创建部署文件夹 `deploy/`
3. 复制所有必要文件
4. 检查 Qt 依赖
5. 生成部署说明文档
6. 询问是否传输到开发板
7. 自动传输到 `debian@192.168.0.100:/home/debian`

**传输确认**：
- 脚本会询问：`确认传输？(y/n):`
- 输入 `y` 或 `Y` 开始传输
- 输入 `n` 取消传输

### 方法 2：仅打包，手动传输

```bash
# 运行部署脚本，在传输确认时输入 n
./deploy.sh

# 然后手动传输
scp -r deploy/ debian@192.168.0.100:/home/debian/
```

## 部署文件夹结构

```
deploy/
├── EnviroTrend_demo          # ARM 可执行文件
├── pySrc/                    # Python 脚本
│   ├── predict.py            # AI 预测脚本
│   ├── train.py              # 训练脚本
│   ├── view_db.py            # 数据库查看脚本
│   ├── migrate_csv_to_sqlite.py  # 数据迁移脚本
│   └── test_migration.py     # 测试脚本
├── dbData/                   # 数据库目录
│   └── enviro_data.db       # SQLite 数据库文件
└── README.txt                # 部署说明
```

## 开发板运行步骤

### 1. 传输文件到开发板

使用部署脚本自动传输：
```bash
./deploy.sh
# 输入 y 确认传输
```

或手动传输：
```bash
scp -r deploy/ debian@192.168.0.100:/home/debian/
```

### 2. 在开发板上运行

```bash
# SSH 连接到开发板
ssh debian@192.168.0.100

# 进入部署目录
cd /home/debian/deploy

# 运行程序
./EnviroTrend_demo
```

### 3. 查看数据库

```bash
# 在开发板上
cd /home/debian/deploy
python3 pySrc/view_db.py
```

## 需要传输的文件

所有文件都已包含在 `deploy` 文件夹中，主要包括：

1. **可执行文件**：`EnviroTrend_demo`（ARM 版本）
2. **Python 脚本**：`pySrc/` 目录下的所有 `.py` 文件
3. **数据库文件**：`dbData/enviro_data.db`
4. **说明文档**：`README.txt`

## 数据库文件位置

### 开发环境
- **位置**：`dbData/enviro_data.db`
- **相对路径**：程序所在目录的 `dbData` 子目录

### 开发板环境
- **位置**：`/home/debian/deploy/dbData/enviro_data.db`
- **自动创建**：程序首次运行时自动创建
- **路径机制**：使用 `QCoreApplication::applicationDirPath()` 确保路径正确

## 开发板依赖要求

### Qt 5 库
```bash
sudo apt install -y \
    libqt5core5a \
    libqt5gui5 \
    libqt5widgets5 \
    libqt5qml5 \
    libqt5quick5 \
    libqt5charts5 \
    libqt5sql5-sqlite
```

### Python 3 及库
```bash
sudo apt install -y python3 python3-pip
pip3 install numpy pandas scikit-learn tensorflow
```

## 网络配置

### 开发板信息
- **用户名**：debian
- **IP 地址**：192.168.0.100
- **目标目录**：/home/debian

### 连接测试
```bash
# 测试 SSH 连接
ssh debian@192.168.0.100 "echo '连接成功'"
```

## 注意事项

1. **架构验证**：脚本会自动验证可执行文件架构，防止错误部署
2. **强制覆盖**：传输时会强制覆盖开发板上的同名文件
3. **数据库路径**：数据库文件必须保持在 `dbData/` 目录下
4. **文件结构**：不要移动或重命名 `deploy` 文件夹中的文件
5. **权限设置**：脚本会自动设置可执行权限

## 故障排除

### 问题 1：无法连接到开发板
```
[错误] 无法连接到开发板 debian@192.168.0.100
```

**解决方案**：
1. 检查开发板是否开机
2. 检查网络连接是否正常
3. 检查 SSH 服务是否启动
4. 检查 IP 地址是否正确

### 问题 2：可执行文件架构错误
```
[警告] 这是虚拟机用的 x86-64 版本，不是开发板版本！
```

**解决方案**：
1. 重新编译项目，使用开发板的交叉编译工具链
2. 确保使用正确的构建配置（eflubancat）

### 问题 3：程序运行时找不到数据库
```
[DB] Failed to open database: unable to open database file
```

**解决方案**：
1. 确保在 `deploy` 目录下运行程序
2. 检查 `dbData` 目录是否存在
3. 检查文件权限是否正确

## 脚本配置

如需修改传输目标，编辑 `deploy.sh` 文件中的配置：

```bash
BOARD_USER="debian"        # 开发板用户名
BOARD_IP="192.168.0.100"  # 开发板 IP 地址
BOARD_DEST="/home/debian"   # 目标目录
```

## 总结

1. **可执行文件验证**：脚本自动验证 ARM 架构
2. **数据库路径优化**：使用相对路径，确保跨平台兼容
3. **统一部署文件夹**：所有文件集中在 `deploy/` 目录
4. **自动传输功能**：可选择自动传输到开发板
5. **详细说明文档**：包含完整的部署和运行说明

**现在你可以使用 `./deploy.sh` 将项目部署到开发板了。**