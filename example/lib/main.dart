import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webp_extractor/webp_extractor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';


  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      final tempDir = await getTemporaryDirectory();
      final outputDir = '${tempDir.path}/frames';

      final frameDir = Directory(outputDir);
      if (await frameDir.exists()) {
        await frameDir.delete(recursive: true);
      }

      await frameDir.create(recursive: true);

      platformVersion = "交流交流";

      // 网络 URL
      // final frames1 = await WebPExtractor.extractFrames(
      //     "https://example.com/animated.webp", outputDir);
      // debugPrint("网络 WebP 输出 PNG 帧: $frames1");

      // 本地文件
      final localPath = "https://storage.googleapis.com/ayd-files/videos/2025/11/23/f693d0e7e04de4403bee54c4a163e2e2d213535782c706ad07068b64376c1deb.webp";
      final frames2 = await WebPExtractor.extractFrames(localPath, outputDir);
      
      // 打印每帧的路径和时长
      debugPrint("本地 WebP 输出 PNG 帧数量: ${frames2.length}");
      for (var i = 0; i < frames2.length; i++) {
        final frame = frames2[i];
        debugPrint("帧 $i:");
        debugPrint("路径: ${frame.path}");
        debugPrint("时长: ${frame.duration}ms");
        debugPrint(" 尺寸: ${frame.width}x${frame.height}");
      }
      
      platformVersion = "已提取 ${frames2.length} 帧";

    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Running on: $_platformVersion\n'),
        ),
      ),
    );
  }
}
