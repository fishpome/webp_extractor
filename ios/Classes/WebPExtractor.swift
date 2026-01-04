//
//  WebPExtractor.swift
//  webp_extractor
//
//  Created by apple on 2025/11/27.
//

import Flutter
import UIKit
import ImageIO

public class WebPExtractorPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "webp_extractor", binaryMessenger: registrar.messenger())
        let instance = WebPExtractorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
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
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            result(FlutterError(code: "DECODE_ERROR", message: "Cannot decode WebP", details: nil))
            return
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        let outDir = URL(fileURLWithPath: outputDir)

        if !FileManager.default.fileExists(atPath: outDir.path) {
            try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        }

        var outputPaths: [String] = []

        for i in 0..<frameCount {
            autoreleasepool {
                if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) {
                    let uiImage = UIImage(cgImage: cgImage)
                    let filePath = outDir.appendingPathComponent(String(format: "frame_%08d.png", i)).path
                    if let pngData = uiImage.pngData() {
                        FileManager.default.createFile(atPath: filePath, contents: pngData)
                        outputPaths.append(filePath)
                    }
                }
            }
        }
        result(outputPaths)
    }
}

