# WebP Extractor Android 设置

## ✅ 已完成设置

libwebp 库已配置为**自动从源码编译**，无需手动提供库文件！

## 快速开始

### 1. 确保源码和头文件已下载

如果还没有运行过下载脚本：
```bash
cd android
./download_libwebp.sh
```

### 2. 构建项目

```bash
./gradlew clean build
```

或者通过 Android Studio 直接构建。

## 工作原理

- **CMakeLists.txt** 会自动检测：
  1. 优先使用预编译库（如果存在 `libs/${ANDROID_ABI}/libwebp.so`）
  2. 否则从 `libwebp-1.4.0/` 源码自动编译

- **头文件** 已准备好：`src/main/cpp/include/webp/`

- **构建脚本**：
  - `download_libwebp.sh` - 下载 libwebp 源码和头文件
  - `build_libwebp.sh` - 手动编译预编译库（可选）

## 文件结构

```
android/src/main/cpp/
├── CMakeLists.txt          # 自动编译配置
├── webp_wrapper.cpp        # JNI 包装代码
├── include/
│   └── webp/              # libwebp 头文件 ✅
├── libs/                   # 预编译库目录（可选）
│   └── ${ANDROID_ABI}/
└── libwebp-1.4.0/          # libwebp 源码 ✅
```

## 验证

构建成功后，检查：
```bash
find build/intermediates/cmake -name "libwebp_wrapper.so"
```

应该能看到生成的库文件。

## 故障排除

如果遇到问题，请查看 `SETUP_LIBWEBP.md` 获取详细说明。

