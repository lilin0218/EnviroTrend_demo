#!/usr/bin/env python3

import sqlite3
import os

def clear_database(db_path):
    """清空数据库中的数据，保留数据库结构"""
    try:
        print(f"\n清空数据库: {db_path}")
        
        # 连接数据库
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # 清空sensor_data表中的数据
        cursor.execute('DELETE FROM sensor_data')
        deleted_rows = cursor.rowcount
        
        # 重置自增ID
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="sensor_data"')
        
        # 提交更改
        conn.commit()
        
        print(f"  [成功] 已清空 {deleted_rows} 条记录")
        
        # 关闭连接
        conn.close()
        return True
    except Exception as e:
        print(f"  [错误] 清空数据库失败: {e}")
        return False

def main():
    """主函数"""
    print("====================================")
    print("EnviroTrend_demo 数据库清空工具")
    print("====================================")
    
    # 数据库文件列表
    db_files = [
        './dbData/enviro_data.db',
        './deploy/dbData/enviro_data.db',
        './src/pySrc/dbData/enviro_data.db',
        './~/dbData_temp/enviro_data.db'
    ]
    
    success_count = 0
    total_count = 0
    
    for db_file in db_files:
        total_count += 1
        if os.path.exists(db_file):
            if clear_database(db_file):
                success_count += 1
        else:
            print(f"\n{db_file} - 文件不存在，跳过")
    
    print("\n====================================")
    print(f"操作完成：{success_count}/{total_count} 个数据库成功清空")
    print("====================================")

if __name__ == "__main__":
    main()
