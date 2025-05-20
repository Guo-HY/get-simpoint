#!/bin/bash

# 检查参数是否足够
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <destination_directory>"
    exit 1
fi

# 获取源目录和目标目录
SOURCE_DIR="$1"
DEST_DIR="$2"

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# 检查目标目录是否存在，如果不存在则创建
if [ ! -d "$DEST_DIR" ]; then
    echo "Destination directory does not exist, creating: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# 查找源目录下的所有名为 'exe' 的子目录并拷贝其内容到目标目录
find "$SOURCE_DIR" -type d -name "exe" -exec sh -c 'cp -r "$0"/* "$1"' {} "$DEST_DIR" \;

echo "All files from 'exe' directories have been copied to $DEST_DIR"
