cmake_minimum_required(VERSION 3.4.1)

# 首先尝试使用预编译库（如果存在）
set(WEBP_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libs/${ANDROID_ABI})
set(WEBP_LIB_PATH ${WEBP_LIB_DIR}/libwebp.so)
set(WEBPDEMUX_LIB_PATH ${WEBP_LIB_DIR}/libwebpdemux.so)

# 检查是否有预编译库
if(EXISTS ${WEBP_LIB_PATH} AND EXISTS ${WEBPDEMUX_LIB_PATH})
    message(STATUS "Using prebuilt libwebp from ${WEBP_LIB_DIR}")
    
    add_library(webp SHARED IMPORTED)
    set_target_properties(webp PROPERTIES IMPORTED_LOCATION ${WEBP_LIB_PATH})
    
    add_library(webpdemux SHARED IMPORTED)
    set_target_properties(webpdemux PROPERTIES IMPORTED_LOCATION ${WEBPDEMUX_LIB_PATH})
    
    set(WEBP_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)
    
else()
    # 从源码编译 libwebp
    message(STATUS "Building libwebp from source...")
    
    set(LIBWEBP_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libwebp-1.4.0)
    
    if(NOT EXISTS ${LIBWEBP_SOURCE_DIR}/CMakeLists.txt)
        message(FATAL_ERROR 
            "libwebp source not found at ${LIBWEBP_SOURCE_DIR}\n"
            "Please run: cd android && ./download_libwebp.sh"
        )
    endif()
    
    # 添加 libwebp 子项目
    add_subdirectory(${LIBWEBP_SOURCE_DIR} ${CMAKE_BINARY_DIR}/libwebp EXCLUDE_FROM_ALL)
    
    # libwebp 编译选项
    set(WEBP_BUILD_ANIM_UTILS ON CACHE BOOL "Build animation utilities")
    set(WEBP_BUILD_CWEBP OFF CACHE BOOL "Build cwebp tool")
    set(WEBP_BUILD_DWEBP OFF CACHE BOOL "Build dwebp tool")
    set(WEBP_BUILD_GIF2WEBP OFF CACHE BOOL "Build gif2webp tool")
    set(WEBP_BUILD_IMG2WEBP OFF CACHE BOOL "Build img2webp tool")
    set(WEBP_BUILD_VWEBP OFF CACHE BOOL "Build vwebp tool")
    set(WEBP_BUILD_WEBPINFO OFF CACHE BOOL "Build webpinfo tool")
    set(WEBP_BUILD_WEBPMUX ON CACHE BOOL "Build webpmux library")
    set(WEBP_BUILD_EXTRAS OFF CACHE BOOL "Build extra tools")
    
    # 设置头文件目录
    set(WEBP_INCLUDE_DIR ${LIBWEBP_SOURCE_DIR}/src)
endif()

# 创建 webp_wrapper 库
add_library(webp_wrapper SHARED
        webp_wrapper.cpp
)

# 设置头文件目录
target_include_directories(webp_wrapper PRIVATE ${WEBP_INCLUDE_DIR})
message(STATUS "Using libwebp headers from ${WEBP_INCLUDE_DIR}")

# 链接库
target_link_libraries(
        webp_wrapper
        webp
        webpdemux
        log
        jnigraphics
)
