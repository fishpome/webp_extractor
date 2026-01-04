package com.example.webp_extractor

import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

// 帧信息数据类（需要能被 JNI 访问）
data class FrameInfo(
    val path: String,
    val duration: Int,  // 毫秒
    val width: Int,
    val height: Int
)

class WebpExtractorPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel
  private lateinit var context: android.content.Context
  private var libraryLoaded = false

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "webp_extractor")
    channel.setMethodCallHandler(this)
    context = binding.applicationContext

    try {
      System.loadLibrary("webp_wrapper")
      libraryLoaded = true
      Log.d("WebpExtractorPlugin", "Native library loaded successfully")
    } catch (e: UnsatisfiedLinkError) {
      libraryLoaded = false
      Log.w("WebpExtractorPlugin", "Failed to load native library: ${e.message}. Using fallback SDK.")
    }
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "decodeWebP") {
      result.notImplemented()
      return
    }

    val input = call.argument<String>("input") ?: run {
      result.error("INVALID_ARGUMENT", "Input path is required", null)
      return
    }

    val outputDir = call.argument<String>("output") ?: run {
      result.error("INVALID_ARGUMENT", "Output directory is required", null)
      return
    }

    Thread {
      try {
        // ❗ 下载 URL / 处理 file:// / 绝对路径
        val localPath = resolveInput(input)

        if (localPath == null || !File(localPath).exists()) {
          postError(result, "Input file does not exist: $localPath")
          return@Thread
        }

        // 确保输出目录存在
        val outputDirectory = File(outputDir)
        if (!outputDirectory.exists()) {
          outputDirectory.mkdirs()
        }

        // ❗ 首选 native 解码
        if (libraryLoaded) {
          try {
            val framesInfo = decodeWebPNative(localPath, outputDir)
            // 将 JNI 返回的帧信息转换为 List<FrameInfo>
            val frames = if (framesInfo != null) {
              framesInfo.toList()
            } else {
              emptyList()
            }
            if (frames.isNotEmpty()) {
              // 转换为 Flutter 可用的格式：List<Map<String, Any>>
              val frameMaps = frames.map { frame ->
                mapOf(
                  "path" to frame.path,
                  "duration" to frame.duration,
                  "width" to frame.width,
                  "height" to frame.height
                )
              }
              postSuccess(result, frameMaps)
            return@Thread
            } else {
              Log.w("WebpExtractorPlugin", "Native decode returned empty frames. Falling back.")
            }
          } catch (e: Exception) {
            Log.w("WebpExtractorPlugin", "Native decode failed: ${e.message}. Falling back.", e)
          }
        }

        // ❗ fallback: Android SDK（只能解第一帧）
        val frames = decodeWebPWithAndroidSDK(localPath, outputDir)
        // Fallback 也转换为新格式
        val frameMaps = frames.map { path ->
          val bitmap = BitmapFactory.decodeFile(path)
          val width = bitmap?.width ?: 0
          val height = bitmap?.height ?: 0
          bitmap?.recycle()
          mapOf(
            "path" to path,
            "duration" to 100, // 默认 100ms
            "width" to width,
            "height" to height
          )
        }
        postSuccess(result, frameMaps)

      } catch (e: Exception) {
        postError(result, e.message ?: "Unknown error")
      }
    }.start()
  }

  /** 统一处理 input → 本地路径 */
  private fun resolveInput(input: String): String? {
    return when {
      input.startsWith("http://") || input.startsWith("https://") ->
        downloadToCache(input)

      input.startsWith("file://") ->
        input.removePrefix("file://")

      else ->
        input
    }
  }

  /** 下载网络 WebP 到 cache，并返回本地路径 */
  private fun downloadToCache(urlStr: String): String? {
    return try {
      val url = URL(urlStr)
      val conn = url.openConnection() as HttpURLConnection
      conn.connect()

      val file = File(context.cacheDir, "webp_${System.currentTimeMillis()}.webp")
      file.outputStream().use { output ->
        conn.inputStream.use { input -> input.copyTo(output) }
      }
      file.absolutePath
    } catch (e: Exception) {
      Log.e("WebpExtractorPlugin", "Download failed: ${e.message}")
      null
    }
  }

  /** Android SDK fallback：只能解第一帧 */
  private fun decodeWebPWithAndroidSDK(localPath: String, outputDir: String): List<String> {
    val outputDirectory = File(outputDir)
    if (!outputDirectory.exists()) outputDirectory.mkdirs()

    val inputStream = File(localPath).inputStream()
    val frames = mutableListOf<String>()

    try {
      val bitmap = BitmapFactory.decodeStream(inputStream)
        ?: throw Exception("BitmapFactory.decodeStream returned null")

      val outputFile = File(outputDirectory, "frame_0.png")
      FileOutputStream(outputFile).use { fos ->
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, fos)
      }

      frames.add(outputFile.absolutePath)
      bitmap.recycle()

    } finally {
      inputStream.close()
    }

    return frames
  }

  private fun postSuccess(result: MethodChannel.Result, frames: List<Map<String, Any>>) {
    android.os.Handler(android.os.Looper.getMainLooper()).post {
      result.success(frames)
    }
  }

  private fun postError(result: MethodChannel.Result, message: String) {
    android.os.Handler(android.os.Looper.getMainLooper()).post {
      result.error("DECODE_ERROR", message, null)
    }
  }

  external fun decodeWebPNative(inputPath: String, outputDir: String): Array<FrameInfo>?

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
