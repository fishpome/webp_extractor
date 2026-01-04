import 'dart:async';
import 'package:flutter/services.dart';

/// 帧信息数据类
class FrameInfo {
  final String path;
  final int duration; // 毫秒
  final int width;
  final int height;

  FrameInfo({
    required this.path,
    required this.duration,
    required this.width,
    required this.height,
  });

  /// 从 Map 创建 FrameInfo
  factory FrameInfo.fromMap(Map<dynamic, dynamic> map) {
    return FrameInfo(
      path: map['path'] as String,
      duration: map['duration'] as int,
      width: map['width'] as int,
      height: map['height'] as int,
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'duration': duration,
      'width': width,
      'height': height,
    };
  }
}

class WebPExtractor {
  static const MethodChannel _channel = MethodChannel('webp_extractor');
  
  // 并发控制：最多同时解码的任务数（避免内存和 CPU 过载）
  static int _maxConcurrent = 2;
  static final Set<String> _activeDecodes = <String>{};
  static final List<Completer<void>> _waitingQueue = [];

  /// 设置最大并发解码数量（默认 2）
  /// 建议值：1-3，取决于设备性能和 WebP 大小
  static void setMaxConcurrent(int max) {
    _maxConcurrent = max.clamp(1, 5);
  }

  /// [webpPathOrUrl] 可以是本地路径或网络 URL
  /// [outputDir] Flutter 层指定输出目录
  /// [useConcurrencyControl] 是否使用并发控制（默认 false，保持原有行为；批量解码时建议设为 true）
  /// 返回包含路径、持续时间、宽高的帧信息列表
  static Future<List<FrameInfo>> extractFrames(
      String webpPathOrUrl, String outputDir, {bool useConcurrencyControl = false}) async {
    if (useConcurrencyControl) {
      // 等待可用槽位（如果已达到最大并发数）
      final decodeKey = '$webpPathOrUrl|$outputDir';
      while (_activeDecodes.length >= _maxConcurrent) {
        final completer = Completer<void>();
        _waitingQueue.add(completer);
        await completer.future;
      }

      _activeDecodes.add(decodeKey);
      try {
        return await _extractFramesInternal(webpPathOrUrl, outputDir);
      } finally {
        _activeDecodes.remove(decodeKey);
        // 唤醒等待队列中的下一个任务
        if (_waitingQueue.isNotEmpty) {
          final next = _waitingQueue.removeAt(0);
          if (!next.isCompleted) {
            next.complete();
          }
        }
      }
    } else {
      // 不使用并发控制，直接解码（保持原有行为）
      return await _extractFramesInternal(webpPathOrUrl, outputDir);
    }
  }

  /// 内部解码方法（不包含并发控制）
  static Future<List<FrameInfo>> _extractFramesInternal(
      String webpPathOrUrl, String outputDir) async {
    final List<dynamic>? framesData = await _channel.invokeMethod('decodeWebP', {
      'input': webpPathOrUrl,
      'output': outputDir,
    });

    if (framesData == null) {
      return [];
    }

    return framesData
        .map((frame) => FrameInfo.fromMap(frame as Map<dynamic, dynamic>))
        .toList();
  }

  /// 批量解码多个 WebP（带并发控制）
  /// [webpPaths] WebP 路径列表
  /// [outputDir] 输出目录
  /// 返回按输入顺序对应的帧信息列表
  static Future<List<List<FrameInfo>>> extractFramesBatch(
      List<String> webpPaths, String outputDir) async {
    final futures = webpPaths.map((path) => extractFrames(path, outputDir));
    return await Future.wait(futures);
  }

  /// 兼容旧 API：只返回路径列表
  @Deprecated('Use extractFrames instead to get full frame information')
  static Future<List<String>> extractFramePaths(
      String webpPathOrUrl, String outputDir) async {
    final frames = await extractFrames(webpPathOrUrl, outputDir);
    return frames.map((frame) => frame.path).toList();
  }
}
