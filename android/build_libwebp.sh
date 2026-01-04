#!/bin/bash

# libwebp 自动构建脚本
# 此脚本会自动下载并编译 libwebp 库用于 Android

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPP_DIR="${SCRIPT_DIR}/src/main/cpp"
LIBS_DIR="${CPP_DIR}/libs"
INCLUDE_DIR="${CPP_DIR}/include"
LIBWEBP_VERSION="1.4.0"
LIBWEBP_URL="https://github.com/webmproject/libwebp/archive/v${LIBWEBP_VERSION}.tar.gz"

# 检查 Android SDK 和 NDK
if [ -z "$ANDROID_NDK" ]; then
    if [ -f "${SCRIPT_DIR}/local.properties" ]; then
        SDK_DIR=$(grep "sdk.dir" "${SCRIPT_DIR}/local.properties" | cut -d'=' -f2)
        if [ -n "$SDK_DIR" ]; then
            # 尝试查找 NDK
            NDK_VERSIONS=$(ls -1 "${SDK_DIR}/ndk" 2>/dev/null | sort -V | tail -1)
            if [ -n "$NDK_VERSIONS" ]; then
                ANDROID_NDK="${SDK_DIR}/ndk/${NDK_VERSIONS}"
            fi
        fi
    fi
fi

if [ -z "$ANDROID_NDK" ] || [ ! -d "$ANDROID_NDK" ]; then
    echo "错误: 未找到 Android NDK"
    echo "请设置 ANDROID_NDK 环境变量，或在 local.properties 中配置 sdk.dir"
    exit 1
fi

echo "使用 NDK: $ANDROID_NDK"

# 创建必要的目录
mkdir -p "${LIBS_DIR}"
mkdir -p "${INCLUDE_DIR}"

# 下载 libwebp 源码
LIBWEBP_DIR="${CPP_DIR}/libwebp-${LIBWEBP_VERSION}"
if [ ! -d "${LIBWEBP_DIR}" ]; then
    echo "下载 libwebp ${LIBWEBP_VERSION}..."
    cd "${CPP_DIR}"
    curl -L "${LIBWEBP_URL}" -o "libwebp-${LIBWEBP_VERSION}.tar.gz"
    tar -xzf "libwebp-${LIBWEBP_VERSION}.tar.gz"
    rm "libwebp-${LIBWEBP_VERSION}.tar.gz"
fi

# 编译函数
build_for_abi() {
    local ABI=$1
    local ARCH=$2
    local TOOLCHAIN=$3
    
    echo "编译 ${ABI}..."
    
    local BUILD_DIR="${CPP_DIR}/build_${ABI}"
    local OUTPUT_DIR="${LIBS_DIR}/${ABI}"
    
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${OUTPUT_DIR}"
    
    cd "${BUILD_DIR}"
    
    # 配置 CMake
    "${ANDROID_NDK}/build/cmake/android.toolchain.cmake" \
        -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK}/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="${ABI}" \
        -DANDROID_PLATFORM=android-21 \
        -DANDROID_STL=c++_shared \
        -DCMAKE_BUILD_TYPE=Release \
        -DWEBP_BUILD_ANIM_UTILS=ON \
        -DWEBP_BUILD_CWEBP=OFF \
        -DWEBP_BUILD_DWEBP=OFF \
        -DWEBP_BUILD_GIF2WEBP=OFF \
        -DWEBP_BUILD_IMG2WEBP=OFF \
        -DWEBP_BUILD_VWEBP=OFF \
        -DWEBP_BUILD_WEBPINFO=OFF \
        -DWEBP_BUILD_WEBPMUX=ON \
        -DWEBP_BUILD_EXTRAS=OFF \
        "${LIBWEBP_DIR}"
    
    # 编译
    cmake --build . --parallel
    
    # 复制库文件
    cp "${BUILD_DIR}/libwebp.so" "${OUTPUT_DIR}/"
    cp "${BUILD_DIR}/libwebpdemux.so" "${OUTPUT_DIR}/"
    
    echo "完成 ${ABI}"
}

# 复制头文件
echo "复制头文件..."
cp -r "${LIBWEBP_DIR}/src/webp" "${INCLUDE_DIR}/"

# 编译各个 ABI
build_for_abi "armeabi-v7a" "arm" "arm-linux-androideabi"
build_for_abi "arm64-v8a" "arm64" "aarch64-linux-android"
build_for_abi "x86" "x86" "i686-linux-android"
build_for_abi "x86_64" "x86_64" "x86_64-linux-android"

echo ""
echo "✅ libwebp 编译完成！"
echo "库文件位置: ${LIBS_DIR}"
echo "头文件位置: ${INCLUDE_DIR}/webp"

