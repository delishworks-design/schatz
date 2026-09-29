#!/usr/bin/env bash
# Builds libtgcallsjni.so for ONE ABI from a prepared drklo/telegram jni/ tree.
# Used by .github/workflows/build-apk.yml (native job). Also runnable locally if an
# NDK + the sparse checkout exist.
#
# Usage: build.sh <abi> <jni-dir> <out-dir> [ndk-dir]
#   abi      arm64-v8a | armeabi-v7a
#   jni-dir  path to drklo/telegram/TMessagesProj/jni (submodules initialized)
#   out-dir  receives <out-dir>/<abi>/libtgcallsjni.so
#   ndk-dir  defaults to $ANDROID_NDK_HOME / $ANDROID_NDK_ROOT
set -euo pipefail

ABI="${1:?abi required}"
JNI_DIR="${2:?jni dir required}"
OUT_DIR="${3:?out dir required}"
NDK="${4:-${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}}"

if [[ -z "$NDK" || ! -f "$NDK/build/cmake/android.toolchain.cmake" ]]; then
    # GitHub runners keep the NDK under $ANDROID_HOME/ndk/<version>
    NDK="$(ls -d "${ANDROID_HOME:-/opt/android-sdk}/ndk"/*/ 2>/dev/null | sort -V | tail -1 || true)"
fi
if [[ -z "$NDK" || ! -f "$NDK/build/cmake/android.toolchain.cmake" ]]; then
    echo "ERROR: Android NDK not found (set ANDROID_NDK_HOME)" >&2
    exit 1
fi
echo "Using NDK: $NDK"

NATIVE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Graft: our top-level CMakeLists replaces Telegram's (voip-only target list) and our
# adapted glue replaces the upstream Instance glue in-place, so voip/CMakeLists.txt's
# source list stays untouched.
cp "$NATIVE_DIR/CMakeLists.txt"     "$JNI_DIR/CMakeLists.txt"
cp "$NATIVE_DIR/schatz_glue.cpp"    "$JNI_DIR/voip/org_telegram_messenger_voip_Instance.cpp"
cp "$NATIVE_DIR/schatz_glue.h"      "$JNI_DIR/voip/schatz_glue.h"
cp "$NATIVE_DIR/exports.map"        "$JNI_DIR/exports.map"

BUILD_DIR="$JNI_DIR/build-schatz-$ABI"
cmake -S "$JNI_DIR" -B "$BUILD_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-26 \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release

cmake --build "$BUILD_DIR" --parallel "$(nproc)" --target tgcallsjni

mkdir -p "$OUT_DIR/$ABI"
cp "$BUILD_DIR/libtgcallsjni.so" "$OUT_DIR/$ABI/libtgcallsjni.so"
echo "OK: $OUT_DIR/$ABI/libtgcallsjni.so ($(stat -c%s "$OUT_DIR/$ABI/libtgcallsjni.so") bytes)"
