# native/ — tgcalls voice/video engine (graft of Telegram Android's voip stack)

Telegram carries voice/video media in a separate C++ engine (**tgcalls** + a trimmed
**WebRTC**) — TDLib only performs signaling. This directory builds that engine into a
standalone `libtgcallsjni.so` for Schatz, exactly the way Telegram Android builds it,
but without libtmessages.

## How it works

CI checks out `drklo/telegram` (sparse, `TMessagesProj/jni` only), initializes 10
submodules, then `build.sh` grafts our files over theirs:

| Telegram file | Our file | Why |
|---|---|---|
| `jni/CMakeLists.txt` | `native/CMakeLists.txt` | voip-only target list (no ffmpeg/td/sqlite/tlottie) |
| `jni/voip/org_telegram_messenger_voip_Instance.cpp` | `native/schatz_glue.cpp` | package rename → `com.schatz.production.voip`, null-sink guard, `JNI_OnLoad` |
| `jni/voip/org_telegram_messenger_voip_Instance.h` | `native/schatz_glue.h` | matching renamed constants |
| `jni/exports.map` | `native/exports.map` | unchanged (exports `Java_*`, `JNI_OnLoad`) |

`jni/voip/CMakeLists.txt` and all voip/tgcalls/webrtc sources are used **unchanged** —
that is the point of the graft: Telegram's own build keeps compiling proven code.

The Kotlin side lives in `app/src/main/java/com/schatz/production/voip/`
(`Instance.kt` data classes, `NativeInstance.kt` externals, `TgCallsBridge.kt` facade).

## Local build

```sh
# one-time: sparse clone + submodules
git clone --depth 1 --filter=blob:none --sparse https://github.com/drklo/telegram tg
cd tg && git sparse-checkout set TMessagesProj/jni
git submodule update --init --depth 1 \
  TMessagesProj/jni/third_party/{libyuv,absl,boringssl,libvpx,dav1d,ffmpeg,wamr,openh264} \
  TMessagesProj/jni/third_party/xiph/opus TMessagesProj/jni/td
# then
native/build.sh arm64-v8a tg/TMessagesProj/jni out "$ANDROID_NDK_HOME"
```

## License

`schatz_glue.cpp` / `schatz_glue.h` are adapted from
[drklo/telegram](https://github.com/drklo/telegram) (`TMessagesProj/jni/voip/`,
GPL-2.0-or-later, commit = whatever `master` is at build time; the .so links the same
GPL sources). Distributing the APK therefore carries GPL-2.0 obligations for the native
library: keep this repo (and its `native/` sources) available alongside any APK you
share. The rest of Schatz is unaffected as a separate work.
