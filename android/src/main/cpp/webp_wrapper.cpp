#include <jni.h>
#include <string>
#include <cstring>
#include <android/log.h>
#include <webp/demux.h>
#include <webp/decode.h>
#include <stdio.h>
#include <android/bitmap.h>
#include <vector>

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "webp_wrapper", __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "webp_wrapper", __VA_ARGS__)

// 辅助函数：使用 Android Bitmap API 保存 PNG
static bool saveBitmapAsPNG(JNIEnv *env, uint8_t *rgba, int width, int height, const char *output_path) {
    // 创建 Bitmap 配置
    jclass bitmapConfigClass = env->FindClass("android/graphics/Bitmap$Config");
    jfieldID argb8888Field = env->GetStaticFieldID(bitmapConfigClass, "ARGB_8888", "Landroid/graphics/Bitmap$Config;");
    jobject bitmapConfig = env->GetStaticObjectField(bitmapConfigClass, argb8888Field);

    // 创建 Bitmap
    jclass bitmapClass = env->FindClass("android/graphics/Bitmap");
    jmethodID createBitmapMethod = env->GetStaticMethodID(bitmapClass, "createBitmap",
                                                          "(IILandroid/graphics/Bitmap$Config;)Landroid/graphics/Bitmap;");
    jobject bitmap = env->CallStaticObjectMethod(bitmapClass, createBitmapMethod, width, height, bitmapConfig);

    if (!bitmap) {
        LOGE("Failed to create bitmap");
        return false;
    }

    // 将 RGBA 数据复制到 Bitmap
    void *bitmapPixels;
    int result = AndroidBitmap_lockPixels(env, bitmap, &bitmapPixels);
    if (result != ANDROID_BITMAP_RESULT_SUCCESS) {
        LOGE("Failed to lock bitmap pixels");
        env->DeleteLocalRef(bitmap);
        return false;
    }

    // RGBA 数据已经是正确的格式，直接复制
    memcpy(bitmapPixels, rgba, width * height * 4);
    AndroidBitmap_unlockPixels(env, bitmap);

    // 保存为 PNG
    jclass fileClass = env->FindClass("java/io/File");
    jmethodID fileConstructor = env->GetMethodID(fileClass, "<init>", "(Ljava/lang/String;)V");
    jstring pathStr = env->NewStringUTF(output_path);
    jobject file = env->NewObject(fileClass, fileConstructor, pathStr);

    jclass fileOutputStreamClass = env->FindClass("java/io/FileOutputStream");
    jmethodID fosConstructor = env->GetMethodID(fileOutputStreamClass, "<init>", "(Ljava/io/File;)V");
    jobject fos = env->NewObject(fileOutputStreamClass, fosConstructor, file);

    jclass compressFormatClass = env->FindClass("android/graphics/Bitmap$CompressFormat");
    jfieldID pngField = env->GetStaticFieldID(compressFormatClass, "PNG", "Landroid/graphics/Bitmap$CompressFormat;");
    jobject pngFormat = env->GetStaticObjectField(compressFormatClass, pngField);

    jmethodID compressMethod = env->GetMethodID(bitmapClass, "compress",
                                               "(Landroid/graphics/Bitmap$CompressFormat;ILjava/io/OutputStream;)Z");
    jboolean success = env->CallBooleanMethod(bitmap, compressMethod, pngFormat, 100, fos);

    // 清理资源
    jmethodID closeMethod = env->GetMethodID(fileOutputStreamClass, "close", "()V");
    env->CallVoidMethod(fos, closeMethod);

    env->DeleteLocalRef(bitmap);
    env->DeleteLocalRef(file);
    env->DeleteLocalRef(fos);
    env->DeleteLocalRef(pathStr);
    env->DeleteLocalRef(bitmapConfig);
    env->DeleteLocalRef(pngFormat);

    return success == JNI_TRUE;
}

extern "C"
JNIEXPORT jobjectArray JNICALL
Java_com_example_webp_1extractor_WebpExtractorPlugin_decodeWebPNative(
        JNIEnv *env,
        jobject /* this */,
        jstring inputPath,
        jstring outputDirPath) {

    const char *input_file = env->GetStringUTFChars(inputPath, nullptr);
    const char *output_dir = env->GetStringUTFChars(outputDirPath, nullptr);

    if (!input_file || !output_dir) {
        LOGE("Failed to get string chars");
        if (input_file) env->ReleaseStringUTFChars(inputPath, input_file);
        if (output_dir) env->ReleaseStringUTFChars(outputDirPath, output_dir);
        return nullptr;
    }

    // 读取整个文件
    FILE *file = fopen(input_file, "rb");
    if (!file) {
        LOGE("Cannot open input file: %s", input_file);
        env->ReleaseStringUTFChars(inputPath, input_file);
        env->ReleaseStringUTFChars(outputDirPath, output_dir);
        return nullptr;
    }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    rewind(file);

    if (file_size <= 0) {
        LOGE("Invalid file size: %ld", file_size);
        fclose(file);
        env->ReleaseStringUTFChars(inputPath, input_file);
        env->ReleaseStringUTFChars(outputDirPath, output_dir);
        return nullptr;
    }

    uint8_t *data = (uint8_t *) malloc(file_size);
    if (!data) {
        LOGE("Memory allocation failed");
        fclose(file);
        env->ReleaseStringUTFChars(inputPath, input_file);
        env->ReleaseStringUTFChars(outputDirPath, output_dir);
        return nullptr;
    }

    size_t read_size = fread(data, 1, file_size, file);
    fclose(file);

    if (read_size != (size_t)file_size) {
        LOGE("Failed to read entire file");
        free(data);
        env->ReleaseStringUTFChars(inputPath, input_file);
        env->ReleaseStringUTFChars(outputDirPath, output_dir);
        return nullptr;
    }

    // WebP 动画解复用器
    WebPData webp_data;
    webp_data.bytes = data;
    webp_data.size = file_size;

    WebPDemuxer *demux = WebPDemux(&webp_data);
    if (!demux) {
        LOGE("WebPDemux failed");
        free(data);
        env->ReleaseStringUTFChars(inputPath, input_file);
        env->ReleaseStringUTFChars(outputDirPath, output_dir);
        return nullptr;
    }

    int frame_count = WebPDemuxGetI(demux, WEBP_FF_FRAME_COUNT);
    if (frame_count <= 0) {
        LOGE("No frames found or invalid frame count: %d", frame_count);
        WebPDemuxDelete(demux);
        free(data);
        env->ReleaseStringUTFChars(inputPath, input_file);
        env->ReleaseStringUTFChars(outputDirPath, output_dir);
        return nullptr;
    }

    LOGD("Found %d frames", frame_count);

    // 统一使用动画 canvas 尺寸，保证所有导出的 PNG 尺寸一致
    int canvas_width = WebPDemuxGetI(demux, WEBP_FF_CANVAS_WIDTH);
    int canvas_height = WebPDemuxGetI(demux, WEBP_FF_CANVAS_HEIGHT);
    if (canvas_width <= 0 || canvas_height <= 0) {
        // 回退：如果获取不到 canvas 尺寸，就使用首帧尺寸
        WebPIterator tmpIter;
        if (WebPDemuxGetFrame(demux, 1, &tmpIter)) {
            canvas_width = tmpIter.width;
            canvas_height = tmpIter.height;
            WebPDemuxReleaseIterator(&tmpIter);
        } else {
            LOGE("Failed to get canvas size");
            WebPDemuxDelete(demux);
            free(data);
            env->ReleaseStringUTFChars(inputPath, input_file);
            env->ReleaseStringUTFChars(outputDirPath, output_dir);
            return nullptr;
        }
    }

    LOGD("Canvas size: %dx%d", canvas_width, canvas_height);

    // 持久化 canvas：用于按 WebP 规则叠加帧，保证和 iOS 播放效果一致
    uint8_t *canvas_rgba = (uint8_t *)calloc(canvas_width * canvas_height * 4, 1); // 初始全透明
    if (!canvas_rgba) {
        LOGE("Failed to allocate global canvas");
        WebPDemuxDelete(demux);
        free(data);
        env->ReleaseStringUTFChars(inputPath, input_file);
        env->ReleaseStringUTFChars(outputDirPath, output_dir);
        return nullptr;
    }

    // 存储成功保存的帧信息
    struct FrameData {
        std::string path;
        int duration;
        int width;
        int height;
    };
    std::vector<FrameData> saved_frames;

    // 保存上一帧信息，用于正确处理 dispose
    int prev_offset_x = 0;
    int prev_offset_y = 0;
    int prev_width = 0;
    int prev_height = 0;
    int prev_dispose = WEBP_MUX_DISPOSE_NONE;

    // 遍历所有帧
    for (int i = 1; i <= frame_count; i++) {
        WebPIterator iter;
        if (!WebPDemuxGetFrame(demux, i, &iter)) {
            LOGE("Failed to get frame %d", i);
            continue;
        }

        // 处理上一帧的 dispose_method（在绘制当前帧之前）
        // dispose 表示"上一帧显示完后，在绘制当前帧前要做什么"
        if (i > 1 && prev_dispose == WEBP_MUX_DISPOSE_BACKGROUND) {
            // 清理上一帧的区域为透明
            int prev_draw_width = prev_width;
            int prev_draw_height = prev_height;
            if (prev_offset_x + prev_draw_width > canvas_width) {
                prev_draw_width = canvas_width - prev_offset_x;
            }
            if (prev_offset_y + prev_draw_height > canvas_height) {
                prev_draw_height = canvas_height - prev_offset_y;
            }
            
            for (int y = 0; y < prev_draw_height; ++y) {
                for (int x = 0; x < prev_draw_width; ++x) {
                    int dst_index = ((y + prev_offset_y) * canvas_width + (x + prev_offset_x)) * 4;
                    canvas_rgba[dst_index + 0] = 0; // R
                    canvas_rgba[dst_index + 1] = 0; // G
                    canvas_rgba[dst_index + 2] = 0; // B
                    canvas_rgba[dst_index + 3] = 0; // A (透明)
                }
            }
        }

        int frame_width = iter.width;
        int frame_height = iter.height;

        if (frame_width <= 0 || frame_height <= 0) {
            LOGE("Invalid frame dimensions: %dx%d", frame_width, frame_height);
            WebPDemuxReleaseIterator(&iter);
            continue;
        }

        // 解码当前帧为 RGBA（帧自身尺寸）
        int decoded_width = frame_width;
        int decoded_height = frame_height;
        uint8_t *frame_rgba = WebPDecodeRGBA(iter.fragment.bytes, iter.fragment.size, &decoded_width, &decoded_height);
        if (!frame_rgba) {
            LOGE("Frame %d decode failed", i);
            WebPDemuxReleaseIterator(&iter);
            continue;
        }

        // 当前帧在 canvas 上的偏移
        int offset_x = iter.x_offset;
        int offset_y = iter.y_offset;

        // 边界保护，防止越界
        if (offset_x < 0) offset_x = 0;
        if (offset_y < 0) offset_y = 0;

        // 限制帧绘制区域不越界
        int draw_width = decoded_width;
        int draw_height = decoded_height;
        if (offset_x + draw_width > canvas_width) {
            draw_width = canvas_width - offset_x;
        }
        if (offset_y + draw_height > canvas_height) {
            draw_height = canvas_height - offset_y;
        }

        // 处理 blend_method：NO_BLEND 需要先清理当前帧区域为透明
        if (iter.blend_method == WEBP_MUX_NO_BLEND) {
            for (int y = 0; y < draw_height; ++y) {
                for (int x = 0; x < draw_width; ++x) {
                    int dst_index = ((y + offset_y) * canvas_width + (x + offset_x)) * 4;
                    canvas_rgba[dst_index + 0] = 0;
                    canvas_rgba[dst_index + 1] = 0;
                    canvas_rgba[dst_index + 2] = 0;
                    canvas_rgba[dst_index + 3] = 0;
                }
            }
        }

        // 将当前帧绘制到 canvas
        // 如果 blend_method == WEBP_MUX_BLEND，需要做 alpha 混合（over 操作）
        // 如果 blend_method == WEBP_MUX_NO_BLEND，直接覆盖（上面已清理）
        for (int y = 0; y < draw_height; ++y) {
            for (int x = 0; x < draw_width; ++x) {
                int src_index = (y * frame_width + x) * 4;
                int dst_index = ((y + offset_y) * canvas_width + (x + offset_x)) * 4;
                
                uint8_t src_r = frame_rgba[src_index + 0];
                uint8_t src_g = frame_rgba[src_index + 1];
                uint8_t src_b = frame_rgba[src_index + 2];
                uint8_t src_a = frame_rgba[src_index + 3];
                
                if (iter.blend_method == WEBP_MUX_BLEND && src_a < 255) {
                    // Alpha 混合：src over dst
                    // 如果 src 完全不透明，直接覆盖
                    if (src_a == 255) {
                        canvas_rgba[dst_index + 0] = src_r;
                        canvas_rgba[dst_index + 1] = src_g;
                        canvas_rgba[dst_index + 2] = src_b;
                        canvas_rgba[dst_index + 3] = src_a;
                    } else {
                        // Alpha 混合公式：result = src + dst * (1 - src_alpha)
                        uint8_t dst_r = canvas_rgba[dst_index + 0];
                        uint8_t dst_g = canvas_rgba[dst_index + 1];
                        uint8_t dst_b = canvas_rgba[dst_index + 2];
                        uint8_t dst_a = canvas_rgba[dst_index + 3];
                        
                        // 预乘 alpha 混合
                        float src_alpha = src_a / 255.0f;
                        float dst_alpha = dst_a / 255.0f;
                        float out_alpha = src_alpha + dst_alpha * (1.0f - src_alpha);
                        
                        if (out_alpha > 0.0f) {
                            float inv_out_alpha = 1.0f / out_alpha;
                            canvas_rgba[dst_index + 0] = (uint8_t)((src_r * src_alpha + dst_r * dst_alpha * (1.0f - src_alpha)) * inv_out_alpha);
                            canvas_rgba[dst_index + 1] = (uint8_t)((src_g * src_alpha + dst_g * dst_alpha * (1.0f - src_alpha)) * inv_out_alpha);
                            canvas_rgba[dst_index + 2] = (uint8_t)((src_b * src_alpha + dst_b * dst_alpha * (1.0f - src_alpha)) * inv_out_alpha);
                            canvas_rgba[dst_index + 3] = (uint8_t)(out_alpha * 255.0f);
                        } else {
                            canvas_rgba[dst_index + 0] = 0;
                            canvas_rgba[dst_index + 1] = 0;
                            canvas_rgba[dst_index + 2] = 0;
                            canvas_rgba[dst_index + 3] = 0;
                        }
                    }
                } else {
                    // NO_BLEND 或完全 opaque：直接覆盖
                    canvas_rgba[dst_index + 0] = src_r;
                    canvas_rgba[dst_index + 1] = src_g;
                    canvas_rgba[dst_index + 2] = src_b;
                    canvas_rgba[dst_index + 3] = src_a;
                }
            }
        }

        char output_file[512];
        snprintf(output_file, sizeof(output_file), "%s/frame_%08d.png", output_dir, i - 1);

        // 使用 Android Bitmap API 保存 PNG（统一 canvas 尺寸）
        if (saveBitmapAsPNG(env, canvas_rgba, canvas_width, canvas_height, output_file)) {
            FrameData frameData;
            frameData.path = std::string(output_file);
            frameData.duration = iter.duration;  // 毫秒
            frameData.width = canvas_width;
            frameData.height = canvas_height;
            saved_frames.push_back(frameData);
            LOGD("Saved frame %d to %s (duration=%dms, size=%dx%d, blend=%d, dispose=%d)", 
                 i, output_file, iter.duration, canvas_width, canvas_height, iter.blend_method, iter.dispose_method);
        } else {
            LOGE("Failed to save frame %d", i);
        }

        // 保存当前帧信息，供下一帧使用
        prev_offset_x = offset_x;
        prev_offset_y = offset_y;
        prev_width = draw_width;
        prev_height = draw_height;
        prev_dispose = iter.dispose_method;

        WebPFree(frame_rgba);
    WebPDemuxReleaseIterator(&iter);
    }

    WebPDemuxDelete(demux);
    free(data);
    free(canvas_rgba);
    env->ReleaseStringUTFChars(inputPath, input_file);
    env->ReleaseStringUTFChars(outputDirPath, output_dir);

    // 创建 Java FrameInfo 对象数组
    // Kotlin 顶层 data class 编译后的类名
    jclass frameInfoClass = env->FindClass("com/example/webp_extractor/FrameInfo");
    if (!frameInfoClass) {
        LOGE("Failed to find FrameInfo class");
        return nullptr;
    }

    // 获取 FrameInfo 构造函数
    jmethodID constructor = env->GetMethodID(frameInfoClass, "<init>", "(Ljava/lang/String;III)V");
    if (!constructor) {
        LOGE("Failed to find FrameInfo constructor");
        env->DeleteLocalRef(frameInfoClass);
        return nullptr;
    }

    jobjectArray resultArray = env->NewObjectArray(saved_frames.size(), frameInfoClass, nullptr);
    if (!resultArray) {
        LOGE("Failed to create FrameInfo array");
        env->DeleteLocalRef(frameInfoClass);
        return nullptr;
    }

    for (size_t i = 0; i < saved_frames.size(); i++) {
        jstring pathStr = env->NewStringUTF(saved_frames[i].path.c_str());
        jobject frameInfo = env->NewObject(frameInfoClass, constructor, 
                                          pathStr,
                                          saved_frames[i].duration,
                                          saved_frames[i].width,
                                          saved_frames[i].height);
        env->SetObjectArrayElement(resultArray, i, frameInfo);
        env->DeleteLocalRef(pathStr);
        env->DeleteLocalRef(frameInfo);
    }

    env->DeleteLocalRef(frameInfoClass);
    LOGD("Successfully decoded %zu frames", saved_frames.size());
    return resultArray;
}
