# Schatz voip-only top-level CMakeLists.
#
# In CI this file REPLACES drklo/telegram's TMessagesProj/jni/CMakeLists.txt so the
# proven voip/tgcalls/webrtc build (voip/CMakeLists.txt, unchanged) compiles into a
# standalone libtgcallsjni.so instead of the full libtmessages.
#
# Preamble and targets mirror drklo/telegram's jni/CMakeLists.txt, minus only what the
# voip stack never touches (tlottie, tgnet, breakpad, sqlite - those serve the app UI/DB).
# ffmpeg/vpx/dav1d/tdutils ARE link deps of the voip stack (group streaming parts, glue
# logging) and come in as prebuilts from jni/prebuild/lib/<abi>/.
# Source of truth: drklo/telegram @ master (see native/README.md).

cmake_minimum_required(VERSION 3.16)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_CXX_FLAGS "-DANDROID -g")
set(CMAKE_C_FLAGS "-w -std=c11 -DANDROID -D_LARGEFILE_SOURCE=1 -g -Wno-error=implicit-function-declaration")
set(CMAKE_ASM_FLAGS "${CFLAGS} -x assembler-with-cpp")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffunction-sections -fdata-sections -fvisibility=hidden -flto=full")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ffunction-sections -fdata-sections -fvisibility=hidden -fvisibility-inlines-hidden -flto=full")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -flto=full -Wl,--gc-sections -Wl,--icf=safe -Wl,-Bsymbolic")

if (${ANDROID_ABI} STREQUAL "armeabi-v7a" OR ${ANDROID_ABI} STREQUAL "arm64-v8a")
    enable_language(ASM)
else()
    enable_language(ASM_NASM)
endif()

set(CAN_COMPILE_SME FALSE CACHE INTERNAL "Disable libyuv SME" FORCE)
add_subdirectory(
        third_party/libyuv
        ${CMAKE_CURRENT_BINARY_DIR}/libyuv
        EXCLUDE_FROM_ALL)

# Abseil
set(ABSL_PROPAGATE_CXX_STD ON)
set(ABSL_BUILD_TESTING OFF)
set(ABSL_ENABLE_INSTALL OFF)
add_subdirectory(
        third_party/absl
        ${CMAKE_CURRENT_BINARY_DIR}/absl
        EXCLUDE_FROM_ALL)

add_library(webrtc_absl INTERFACE)
target_link_libraries(webrtc_absl INTERFACE
        absl::base
        absl::strings
        absl::str_format
        absl::cord
        absl::synchronization
        absl::time
        absl::status
        absl::statusor
        absl::hash
        absl::flat_hash_map
        absl::flat_hash_set
        absl::flags
        absl::flags_parse
        absl::random_random
        absl::random_distributions
        absl::crc32c
        absl::log
        absl::check
)

# Prebuilt static libraries required by the voip stack (from jni/prebuild/lib/<abi>/).
add_library(avutil STATIC IMPORTED)
set_target_properties(avutil PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libavutil.a)

add_library(avformat STATIC IMPORTED)
set_target_properties(avformat PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libavformat.a)

add_library(avcodec STATIC IMPORTED)
set_target_properties(avcodec PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libavcodec.a)

add_library(swresample STATIC IMPORTED)
set_target_properties(swresample PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libswresample.a)

add_library(swscale STATIC IMPORTED)
set_target_properties(swscale PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libswscale.a)

add_library(libvpx STATIC IMPORTED)
set_target_properties(libvpx PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libvpx.a)

add_library(libdav1d STATIC IMPORTED)
set_target_properties(libdav1d PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libdav1d.a)

add_library(crypto STATIC IMPORTED)
set_target_properties(crypto PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libcrypto.a)

add_library(ssl STATIC IMPORTED)
set_target_properties(ssl PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libssl.a)

add_library(libopus STATIC IMPORTED)
set_target_properties(libopus PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libopus.a)

add_library(tde2e STATIC IMPORTED)
set_target_properties(tde2e PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libtde2e.a)

add_library(tdutils STATIC IMPORTED)
set_target_properties(tdutils PROPERTIES IMPORTED_LOCATION ${CMAKE_HOME_DIRECTORY}/prebuild/lib/${ANDROID_ABI}/libtdutils.a)

# voip: rnnoise + tgcalls_tp (libsrtp, usrsctp, crc32c) + tgcalls (+ webrtc subset) + voipandroid
# (platform/android + our schatz_glue.cpp). Unchanged from upstream.
include(${CMAKE_HOME_DIRECTORY}/voip/CMakeLists.txt)

# cpufeatures: same module Telegram pulls in; fall back to the NDK sources directly.
if (COMMAND android_ndk_import_module_cpufeatures)
    include(AndroidNdkModules)
    android_ndk_import_module_cpufeatures()
elseif(EXISTS ${ANDROID_NDK}/sources/android/cpufeatures/cpu-features.c)
    add_library(cpufeatures STATIC ${ANDROID_NDK}/sources/android/cpufeatures/cpu-features.c)
    target_include_directories(cpufeatures PUBLIC ${ANDROID_NDK}/sources/android/cpufeatures)
else()
    message(FATAL_ERROR "cpufeatures module not found")
endif()

# Standalone JNI shared library. FileLog.cpp is compiled in directly (the glue's
# DEBUG_D/DEBUG_REF macros resolve to FileLog::getInstance() and Telegram builds it
# inside its tgnet target; we do not need the rest of tgnet).
add_library(tgcallsjni SHARED
        tgnet/FileLog.cpp)

target_include_directories(tgcallsjni PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR})

target_link_options(tgcallsjni PRIVATE "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/exports.map")

# Same link set as drklo/telegram's NATIVE_LIB (minus tgnet/tlottie/sqlite/breakpad,
# which the voip stack does not reference), plus jnigraphics for the glue's bitmap paths.
target_link_libraries(tgcallsjni
        -Wl,--whole-archive rnnoise openh264 voipandroid -Wl,--no-whole-archive
        webrtc_absl
        tgcalls
        wasm
        tgcalls_tp
        swscale
        avformat
        avcodec
        swresample
        libvpx
        libdav1d
        libopus
        tde2e
        tdutils
        yuv
        avutil
        ssl
        crypto
        jnigraphics
        cpufeatures
        log
        z
        GLESv2
        EGL
        android
        OpenSLES)
