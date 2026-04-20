# SQLite 数据库迁移说明

## 概述
本项目已从 CSV 文件存储迁移到 SQLite 数据库存储，以提供更好的性能、数据完整性和扩展性。

## 数据库结构

### 表名: `sensor_data`

| 字段名 | 类型 | 说明 | 当前使用 |
|--------|------|------|----------|
| id | INTEGER | 主键，自增 | 已完成 |
| timestamp | DATETIME | 时间戳，带索引 | 已完成 |
| temp | REAL | 温度 (°C) | 已完成 |
| hum | REAL | 湿度 (%) | 已完成 |
| light | REAL | 光照强度 | 预留 |
| pm25 | REAL | PM2.5 (μg/m³) | 预留 |
| pm10 | REAL | PM10 (μg/m³) | 预留 |
| aqi | REAL | 空气质量指数 | 预留 |
| noise | REAL | 噪音 | 预留 |

### 索引
- `idx_timestamp`: 在 timestamp 字段上的索引，加速时间范围查询

## 文件变更清单

### 1. 项目配置
- **EnviroTrend_demo.pro**: 添加 `sql` 模块

### 2. C++ 后端
- **src/core/backstage.h**: 
  - 添加 SQLite 相关头文件
  - 添加数据库成员变量
  - 新增数据库初始化和操作函数

- **src/core/backstage.cpp**:
  - `initDatabase()`: 创建数据库和表结构
  - `loadBufferFromDatabase()`: 启动时加载历史数据
  - `updateDatabase()`: 插入新数据
  - `clearTempBuffer()/clearHumBuffer()`: 清空数据时同步更新数据库

### 3. Python 脚本
- **src/pySrc/predict.py**: 改用 SQLite 读取数据
- **src/pySrc/train.py**: 改用 SQLite 读取数据
- **src/pySrc/migrate_csv_to_sqlite.py**: 数据迁移工具（新增）

## 数据存储位置

- **旧路径**: `csvData/data.csv`
- **新路径**: `dbData/enviro_data.db`

## 使用说明

### 首次使用
1. 如果有旧的 CSV 数据，运行迁移工具：
   ```bash
   cd src/pySrc
   python3 migrate_csv_to_sqlite.py
   ```

2. 编译并运行 Qt 程序，数据库会自动创建

### 数据迁移
迁移工具会：
- 检查是否存在 CSV 文件
- 创建数据库目录和表结构
- 将 CSV 数据导入数据库
- 支持增量导入（不覆盖现有数据）

## 扩展新传感器

### 添加新传感器步骤
1. **数据库已预留字段**，无需修改表结构
2. **C++ 端修改**:
   - 在 `Backstage` 类中添加新传感器的成员变量
   - 修改 `updateDatabase()` 函数，插入新字段数据
   - 添加对应的 getter/setter 方法

3. **Python 端修改**:
   - 在 `predict.py` 和 `train.py` 中修改 SQL 查询，添加新字段
   - 调整特征工程逻辑

### 示例：添加光照传感器

#### C++ 端
```cpp
void Backstage::updateDatabase(double t, double h, double light) {
    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO sensor_data (timestamp, temp, hum, light) "
        "VALUES (:timestamp, :temp, :hum, :light)"
    );
    query.bindValue(":timestamp", now);
    query.bindValue(":temp", t);
    query.bindValue(":hum", h);
    query.bindValue(":light", light);
    query.exec();
}
```

#### Python 端
```python
query = """
    SELECT timestamp, temp, hum, light 
    FROM sensor_data 
    WHERE temp IS NOT NULL AND hum IS NOT NULL AND light IS NOT NULL
    ORDER BY timestamp DESC 
    LIMIT 2000
"""
```

## 性能优化

### 查询优化
- 使用索引加速时间范围查询
- 只查询需要的字段
- 使用 `LIMIT` 限制结果数量

### 写入优化
- 使用参数化查询防止 SQL 注入
- 批量操作时考虑使用事务

## 数据备份

### 备份数据库
```bash
cp dbData/enviro_data.db dbData/enviro_data_backup_$(date +%Y%m%d).db
```

### 导出为 CSV（如果需要）
```python
import sqlite3
import pandas as pd

conn = sqlite3.connect('dbData/enviro_data.db')
df = pd.read_sql_query("SELECT * FROM sensor_data", conn)
df.to_csv('backup.csv', index=False)
conn.close()
```

## 注意事项

1. **数据一致性**: SQLite 支持 ACID，数据写入具有原子性
2. **并发访问**: SQLite 支持多进程读取，但写入时会锁定数据库
3. **文件权限**: 确保程序对 `dbData` 目录有读写权限
4. **磁盘空间**: SQLite 比相同数据的 CSV 文件更节省空间
5. **兼容性**: Qt SQL 模块需要在开发板上可用

## 故障排查

### 数据库无法打开
- 检查 `dbData` 目录权限
- 检查 Qt SQL 模块是否正确安装

### 数据查询失败
- 检查 SQL 语法
- 使用 `qDebug()` 输出错误信息
- 使用 SQLite 命令行工具验证数据库

### 性能问题
- 确认索引已创建
- 使用 `EXPLAIN QUERY PLAN` 分析查询
- 考虑定期清理旧数据

## 测试验证

运行程序后，检查以下内容：
1. `dbData/enviro_data.db` 文件是否创建
2. 数据是否正常写入（使用 SQLite 工具查看）
3. 历史数据是否正确加载到内存缓冲区
4. Python 脚本能否正确读取数据