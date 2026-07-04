#!/usr/bin/env bash
# Install Gator over USB and stream filtered logcat for debugging.
#
# Usage:
#   ./tool/install_and_log.sh              # build debug APK, install, log
#   ./tool/install_and_log.sh --release    # use release APK instead
#   ./tool/install_and_log.sh --no-build   # install existing APK only
#
# Phone setup (one time):
#   Settings → About phone → tap Build number 7× → Developer options
#   Enable "USB debugging", connect cable, accept the RSA prompt on the phone.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD=1
RELEASE=0

for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    --release) RELEASE=1 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if ! command -v adb >/dev/null; then
  echo "adb not found. Install Android platform-tools." >&2
  exit 1
fi

echo "==> Checking for devices..."
adb devices -l
if ! adb get-state >/dev/null 2>&1; then
  echo
  echo "No device detected. Plug in the phone, enable USB debugging, and retry." >&2
  exit 1
fi

if [[ "$BUILD" -eq 1 ]]; then
  if [[ "$RELEASE" -eq 1 ]]; then
    echo "==> Building release APK..."
    flutter build apk --release
    APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
  else
    echo "==> Building debug APK..."
    flutter build apk --debug
    APK="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
  fi
else
  if [[ "$RELEASE" -eq 1 ]]; then
    APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
  else
    APK="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
  fi
fi

if [[ ! -f "$APK" ]]; then
  echo "APK not found: $APK" >&2
  exit 1
fi

echo "==> Installing $APK"
adb install -r "$APK"

echo "==> Launching Gator"
adb shell am start -n org.gator.gator/.MainActivity

echo "==> Streaming logs (Ctrl+C to stop)"
echo "    Reproduce the issue on the phone now."
echo
adb logcat -c
adb logcat -v time \
  | grep --line-buffered -E 'GatorQrScanner|GatorMainActivity|CameraX|flutter|AndroidRuntime|FATAL'