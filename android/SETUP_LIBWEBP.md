# libwebp 库设置说明

## ✅ 自动设置（推荐）

项目已配置为**自动从源码编译 libwebp**，无需手动操作！

### 快速开始

1. **下载 libwebp 源码和头文件**（如果还没有）：
   ```bash
   cd android
   ./download_libwebp.sh
   ```

2. **直接构建项目**：
   ```bash
   ./gradlew build
   ```
   
   CMake 会自动从源码编译 libwebp 库。

## 工作原理

CMakeLists.txt 会：
1. 首先检查是否有预编译库（`libs/${ANDROID_ABI}/libwebp.so`）
2. 如果没有，自动从 `libwebp-1.4.0/` 源码目录编译
3. 使用已下载的头文件（`include/webp/`）

## 手动设置预编译库（可选）

如果你想使用预编译库而不是从源码编译：

1. 创建目录结构：
   ```
   android/src/main/cpp/
   ├── libs/
   │   ├── armeabi-v7a/
   │   │   ├── libwebp.so
   │   │   └── libwebpdemux.so
   │   ├── arm64-v8a/
   │   │   ├── libwebp.so
   │   │   └── libwebpdemux.so
   │   └── ... (其他 ABI)
   ```

2. 将预编译的 `.so` 文件放到对应目录

3. CMake 会自动检测并使用预编译库

## 验证

构建项目后，检查：
- `android/build/intermediates/cmake/` 目录中是否有生成的 `libwebp_wrapper.so`
- APK 的 `lib/` 目录中是否包含 `libwebp_wrapper.so`

## 故障排除

### 如果遇到编译错误

1. 确保已运行 `./download_libwebp.sh` 下载源码
2. 检查 Android NDK 是否正确安装
3. 查看构建日志中的具体错误信息

### 回退方案

如果无法编译 libwebp，代码会自动回退到 Android SDK 方法（只能解码第一帧，不支持动画）。

