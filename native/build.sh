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

# Symbol table for the unstripped binary. The crash handler reports the faulting PC as an offset
# from the .so base, and execinfo is stubbed on Android so there is no runtime backtrace - this
# table is what turns that offset into a function name.
LLVM_NM="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-nm"
if [[ -x "$LLVM_NM" ]]; then
    "$LLVM_NM" -C --defined-only -S "$BUILD_DIR/libtgcallsjni.so" > "$BUILD_DIR/libtgcallsjni.symbols.txt" 2>/dev/null || true
    echo "symbols: $(wc -l < "$BUILD_DIR/libtgcallsjni.symbols.txt" 2>/dev/null || echo 0) lines"
fi

# Strip debug/symbol bulk (LTO + -g make the .so ~220MB unstripped; packaging does
# not re-strip, so do it here - dynamic JNI exports are preserved).
STRIP="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
if [[ -x "$STRIP" ]]; then
    "$STRIP" --strip-unneeded "$BUILD_DIR/libtgcallsjni.so"
    echo "stripped: $(stat -c%s "$BUILD_DIR/libtgcallsjni.so") bytes"
fi

mkdir -p "$OUT_DIR/$ABI"
cp "$BUILD_DIR/libtgcallsjni.so" "$OUT_DIR/$ABI/libtgcallsjni.so"
# Kept outside the ABI directory on purpose: the CI APK job merges these artifacts straight into
# app/src/main/jniLibs, and anything inside an ABI folder gets packaged into the APK.
if [[ -f "$BUILD_DIR/libtgcallsjni.symbols.txt" ]]; then
    cp "$BUILD_DIR/libtgcallsjni.symbols.txt" "$OUT_DIR/symbols-$ABI.txt"
fi
echo "OK: $OUT_DIR/$ABI/libtgcallsjni.so ($(stat -c%s "$OUT_DIR/$ABI/libtgcallsjni.so") bytes)"
