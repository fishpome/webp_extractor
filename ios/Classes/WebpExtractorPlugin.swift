import Flutter
import UIKit
import SDWebImage
import SDWebImageWebPCoder

public class WebpExtractorPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "webp_extractor", binaryMessenger: registrar.messenger())
        let instance = WebpExtractorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // 注册 WebP coder
        let WebPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(WebPCoder)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "decodeWebP",
              let args = call.arguments as? [String: Any],
              let input = args["input"] as? String,
              let output = args["output"] as? String
        else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            // 下载网络 WebP
            guard let url = URL(string: input) else { return }
            URLSession.shared.dataTask(with: url) { data, _, error in
                guard let data else {
                    result(FlutterError(code: "DOWNLOAD_FAILED", message: error?.localizedDescription, details: nil))
                    return
                }
                self.decodeWebP(data: data, outputDir: output, result: result)
            }.resume()
        } else {
            // 本地文件
            let fileUrl = URL(fileURLWithPath: input)
            guard let data = try? Data(contentsOf: fileUrl) else {
                result(FlutterError(code: "FILE_NOT_FOUND", message: "File not found", details: nil))
                return
            }
            self.decodeWebP(data: data, outputDir: output, result: result)
        }
    }

    private func decodeWebP(data: Data, outputDir: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                guard let animatedImage = SDAnimatedImage(data: data) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "DECODE_ERROR", message: "Cannot decode WebP", details: nil))
                    }
                    return
                }

                let outDir = URL(fileURLWithPath: outputDir)
                if !FileManager.default.fileExists(atPath: outDir.path) {
                    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
                }

                // 获取 canvas 尺寸（所有帧统一尺寸）
                let canvasWidth = Int(animatedImage.size.width)
                let canvasHeight = Int(animatedImage.size.height)
                
                var frames: [[String: Any]] = []

                for i in 0..<animatedImage.animatedImageFrameCount {
                    autoreleasepool {
                        if let frame = animatedImage.animatedImageFrame(at: i),
                           let pngData = frame.pngData() {
                            let filePath = outDir.appendingPathComponent(String(format: "frame_%08d.png", i)).path
                            
                            if FileManager.default.createFile(atPath: filePath, contents: pngData) {
                                // 获取帧持续时间（毫秒）
                                // 使用 animatedImageDurationAtIndex: 方法获取每帧的持续时间
                                // 该方法返回 NSTimeInterval（秒），需要转换为毫秒
                                var duration: Int
                                let frameDuration = animatedImage.animatedImageDuration(at: i)
                                if frameDuration > 0 {
                                    duration = Int(frameDuration * 1000) // 秒转毫秒
                                    // WebP 规范：如果 duration <= 10ms，应设置为 100ms
                                    // 这是为了与浏览器和其他工具保持一致（如 gif2webp）
                                    if duration <= 10 {
                                        duration = 100
                                    }
                                } else {
                                    // 如果无法获取或为 0，使用默认值 100ms
                                    duration = 100
                                }
                                
                                frames.append([
                                    "path": filePath,
                                    "duration": duration,
                                    "width": canvasWidth,
                                    "height": canvasHeight
                                ])
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    result(frames)
                }
            }
        }
    }
}

