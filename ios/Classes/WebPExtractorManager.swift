//
//  WebPExtractorManager.swift
//  webp_extractor
//
//  Created by apple on 2025/11/27.
//

import UIKit
import SDWebImageWebPCoder

class WebPExtractorManager {
    
    static let webPCoder = SDImageWebPCoder.shared
    
    /// 解码 WebP（本地或网络）为 PNG 文件序列
    static func decodeWebP(
        from data: Data,
        outputDir: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.decodeFrames(data: data, outputDir: outputDir)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    
    /// 逐帧解码（不会占用大量内存）
    private static func decodeFrames(data: Data, outputDir: String) throws -> [String] {
        
        guard let animatedImage = webPCoder.decodedImage(with: data, options: nil) as? SDAnimatedImage else {
            throw NSError(domain: "webp.decode", code: -1, userInfo: [NSLocalizedDescriptionKey: "decode failed"])
        }
        
        let frameCount = animatedImage.animatedImageFrameCount
        let outputURL = URL(fileURLWithPath: outputDir)
        
        if !FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        }
        
        var pngPaths: [String] = []
        
        for i in 0..<frameCount {
            autoreleasepool {
                guard let frame = animatedImage.animatedImageFrame(at: i) else { return }
                let fileName = String(format: "frame_%08d.png", i)
                let filePath = outputURL.appendingPathComponent(fileName).path
                
                if let pngData = frame.pngData() {
                    FileManager.default.createFile(atPath: filePath, contents: pngData)
                    pngPaths.append(filePath)
                }
            }
        }
        return pngPaths
    }
}

