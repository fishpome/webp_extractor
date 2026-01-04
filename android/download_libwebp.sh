#!/bin/bash

# 下载预编译的 libwebp 库脚本
# 如果预编译库不可用，会提供编译说明

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPP_DIR="${SCRIPT_DIR}/src/main/cpp"
LIBS_DIR="${CPP_DIR}/libs"
INCLUDE_DIR="${CPP_DIR}/include"

echo "准备 libwebp 库文件..."

# 创建目录
mkdir -p "${LIBS_DIR}"
mkdir -p "${INCLUDE_DIR}"

# 下载 libwebp 源码（用于头文件）
LIBWEBP_VERSION="1.4.0"
LIBWEBP_DIR="${CPP_DIR}/libwebp-${LIBWEBP_VERSION}"

if [ ! -d "${LIBWEBP_DIR}" ]; then
    echo "下载 libwebp 源码 (用于头文件)..."
    cd "${CPP_DIR}"
    curl -L "https://github.com/webmproject/libwebp/archive/v${LIBWEBP_VERSION}.tar.gz" -o "libwebp.tar.gz"
    tar -xzf "libwebp.tar.gz"
    rm "libwebp.tar.gz"
fi

# 复制头文件
echo "复制头文件..."
if [ -d "${LIBWEBP_DIR}/src/webp" ]; then
    cp -r "${LIBWEBP_DIR}/src/webp" "${INCLUDE_DIR}/"
    echo "✅ 头文件已复制到 ${INCLUDE_DIR}/webp"
else
    echo "❌ 未找到头文件目录"
    exit 1
fi

# 检查是否已有预编译库
if [ -f "${LIBS_DIR}/arm64-v8a/libwebp.so" ]; then
    echo "✅ 检测到已有预编译库"
    echo "库文件位置: ${LIBS_DIR}"
    exit 0
fi

echo ""
echo "⚠️  未找到预编译的 libwebp 库文件"
echo ""
echo "请选择以下方式之一获取库文件："
echo ""
echo "方式 1: 使用 Android NDK 编译（推荐）"
echo "  运行: ./build_libwebp.sh"
echo ""
echo "方式 2: 手动下载预编译库"
echo "  1. 访问 https://github.com/webmproject/libwebp/releases"
echo "  2. 下载对应版本的 Android 预编译库"
echo "  3. 解压到: ${LIBS_DIR}/"
echo "    目录结构应该是:"
echo "    ${LIBS_DIR}/"
echo "    ├── armeabi-v7a/"
echo "    │   ├── libwebp.so"
echo "    │   └── libwebpdemux.so"
echo "    ├── arm64-v8a/"
echo "    │   ├── libwebp.so"
echo "    │   └── libwebpdemux.so"
echo "    └── ..."
echo ""
echo "方式 3: 使用简化版本（仅头文件，需要系统库）"
echo "  某些 Android 系统可能已包含 libwebp，可以尝试直接编译"
echo ""

# 提供快速编译选项
read -p "是否现在尝试使用 NDK 编译? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "${SCRIPT_DIR}/build_libwebp.sh" ]; then
        bash "${SCRIPT_DIR}/build_libwebp.sh"
    else
        echo "❌ 未找到 build_libwebp.sh 脚本"
        exit 1
    fi
else
    echo "请手动提供 libwebp 库文件后重新构建项目"
fi

