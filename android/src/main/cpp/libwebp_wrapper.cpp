#include <jni.h>
#include <string>
#include <android/log.h>
#include <webp/demux.h>
#include <webp/decode.h>
#include <stdio.h>

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "webp_wrapper", __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "webp_wrapper", __VA_ARGS__)

extern "C"
JNIEXPORT jobjectArray JNICALL
Java_com_example_webp_1extractor_WebpExtractorPlugin_decodeWebPNative(
        JNIEnv *env,
        jobject /* this */,
        jstring inputPath,
        jstring outputDirPath) {

    const char *input_file = env->GetStringUTFChars(inputPath, 0);
    const char *output_dir = env->GetStringUTFChars(outputDirPath, 0);

    // 读取整个文件
    FILE *file = fopen(input_file, "rb");
    if (!file) {
        LOGE("Cannot open input file");
        return nullptr;
    }
    fseek(file, 0, SEEK_END);
    size_t file_size = ftell(file);
    rewind(file);

    uint8_t *data = (uint8_t *) malloc(file_size);
    fread(data, 1, file_size, file);
    fclose(file);

    // WebP 动画解复用器
    WebPData webp_data;
    webp_data.bytes = data;
    webp_data.size = file_size;

    WebPDemuxer *demux = WebPDemux(&webp_data);
    if (!demux) {
        LOGE("WebPDemux failed");
        free(data);
        return nullptr;
    }

    int frame_count = WebPDemuxGetI(demux, WEBP_FF_FRAME_COUNT);

    // 创建 Java String 数组
    jobjectArray resultArray = env->NewObjectArray(frame_count,
                                                   env->FindClass("java/lang/String"),
                                                   env->NewStringUTF(""));

    WebPIterator iter;
    if (!WebPDemuxGetFrame(demux, 1, &iter)) {
        LOGE("No frame found");
        WebPDemuxReleaseIterator(&iter);
        free(data);
        return nullptr;
    }

    for (int i = 1; i <= frame_count; i++) {
        WebPDemuxGetFrame(demux, i, &iter);

        int width = iter.width;
        int height = iter.height;

        uint8_t *rgba = WebPDecodeRGBA(iter.fragment.bytes, iter.fragment.size, &width, &height);
        if (!rgba) {
            LOGE("Frame decode failed");
            continue;
        }

        char output_file[512];
        sprintf(output_file, "%s/frame_%d.png", output_dir, i - 1);

        FILE *pngFile = fopen(output_file, "wb");
        if (!pngFile) {
            LOGE("PNG create failed");
            continue;
        }

        // 简单写 RGBA → PNG（你可以替换为 lodepng 或 stb_image_write）
        // 这里用最简单的 lodepng
        lodepng_encode32_file(output_file, rgba, width, height);

        env->SetObjectArrayElement(resultArray, i - 1, env->NewStringUTF(output_file));

        WebPFree(rgba);
    }

    WebPDemuxReleaseIterator(&iter);
    WebPDemuxDelete(demux);
    free(data);

    return resultArray;
}
