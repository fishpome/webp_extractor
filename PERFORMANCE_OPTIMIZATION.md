# WebP 解码性能优化指南

## 潜在性能问题

同时解压三个 WebP 并播放可能遇到以下问题：

### 1. **内存占用**
- 每个 WebP 解码时都会分配完整的 canvas 内存：`width * height * 4` 字节
- 例如：800x600 的 WebP，每帧约 1.9MB，100 帧约 190MB
- 同时解码 3 个：可能占用 500MB+ 内存

### 2. **CPU 占用**
- WebP 解码是 CPU 密集型操作
- 同时解码多个会竞争 CPU 资源
- 可能导致 UI 卡顿

### 3. **I/O 竞争**
- 同时写入多个 PNG 文件
- 磁盘 I/O 可能成为瓶颈

### 4. **线程管理**
- Android：每个解码任务创建新 Thread
- iOS：使用 DispatchQueue.global
- 没有并发数量限制

## 优化方案

### 方案 1: 串行解码（推荐用于内存受限场景）

```dart
// 串行解码，避免内存峰值
Future<List<List<FrameInfo>>> decodeMultipleSerial(
    List<String> webpPaths, String outputDir) async {
  List<List<FrameInfo>> allFrames = [];
  for (var path in webpPaths) {
    final frames = await WebPExtractor.extractFrames(path, outputDir);
    allFrames.add(frames);
  }
  return allFrames;
}
```

### 方案 2: 限制并发数量（推荐）

```dart
import 'dart:async';

class WebPExtractorPool {
  static final _semaphore = Semaphore(2); // 最多同时解码 2 个
  
  static Future<List<FrameInfo>> extractFramesWithLimit(
      String webpPathOrUrl, String outputDir) async {
    await _semaphore.acquire();
    try {
      return await WebPExtractor.extractFrames(webpPathOrUrl, outputDir);
    } finally {
      _semaphore.release();
    }
  }
}

// 使用
final futures = webpPaths.map((path) => 
  WebPExtractorPool.extractFramesWithLimit(path, outputDir)
).toList();
final results = await Future.wait(futures);
```

### 方案 3: 延迟解码（按需解码）

```dart
// 只解码当前需要播放的帧
class LazyWebPPlayer {
  final String webpPath;
  final String outputDir;
  List<FrameInfo>? _cachedFrames;
  
  Future<List<FrameInfo>> getFrames() async {
    if (_cachedFrames == null) {
      _cachedFrames = await WebPExtractor.extractFrames(webpPath, outputDir);
    }
    return _cachedFrames!;
  }
  
  // 只解码前 N 帧用于预览
  Future<List<FrameInfo>> getPreviewFrames(int count) async {
    // 需要修改 native 代码支持只解码部分帧
    // 或者先解码全部，然后只返回前 N 帧
    final allFrames = await getFrames();
    return allFrames.take(count).toList();
  }
}
```

### 方案 4: 优化 Native 代码（减少内存占用）

#### Android 优化建议：
1. **流式解码**：不保存所有帧到内存，解码一帧保存一帧后立即释放
2. **降低分辨率**：如果不需要原分辨率，可以缩放
3. **使用压缩格式**：保存为 JPEG 而不是 PNG（如果不需要透明度）

#### iOS 优化建议：
1. 使用 `autoreleasepool` 及时释放内存（已实现）
2. 考虑使用后台队列限制并发

## 实际建议

### 对于同时播放 3 个 WebP：

1. **使用并发限制**：最多同时解码 2 个
2. **预加载策略**：
   - 第一个立即解码
   - 第二个在第一个解码到 50% 时开始
   - 第三个在第一个完成后开始
3. **内存监控**：监控内存使用，必要时暂停解码
4. **降级策略**：如果内存不足，降低分辨率或减少帧数

### 代码示例：

```dart
class OptimizedWebPPlayer {
  static const maxConcurrent = 2;
  final _activeDecodes = <String>{};
  
  Future<List<FrameInfo>> decodeWithPriority(
      String webpPath, String outputDir, int priority) async {
    // 等待可用槽位
    while (_activeDecodes.length >= maxConcurrent) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    _activeDecodes.add(webpPath);
    try {
      return await WebPExtractor.extractFrames(webpPath, outputDir);
    } finally {
      _activeDecodes.remove(webpPath);
    }
  }
}
```

## 监控指标

建议监控：
- 内存使用峰值
- CPU 使用率
- 解码耗时
- 帧率（播放时）

如果出现性能问题，优先考虑：
1. 减少并发数量
2. 降低分辨率
3. 使用更轻量的格式（JPEG）
4. 实现流式解码

