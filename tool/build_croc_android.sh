#!/usr/bin/env bash
# Cross-compile croc v10.4.4 for Android and copy into Flutter assets.
set -euo pipefail

CROC_VERSION="10.4.4"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_DIR="$ROOT_DIR/assets/croc"
BUILD_DIR="${TMPDIR:-/tmp}/gator-croc-build-$$"

mkdir -p "$BUILD_DIR"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$BUILD_DIR"
if [[ ! -f go.mod ]]; then
  curl -sL "https://github.com/schollz/croc/archive/refs/tags/v${CROC_VERSION}.tar.gz" \
    | tar xz --strip-components=1
fi

build_abi() {
  local goarch="$1"
  local abi_dir="$2"
  echo "Building croc for android/$goarch → $abi_dir"
  mkdir -p "$ASSETS_DIR/$abi_dir"
  local jni_dir="$ROOT_DIR/android/app/src/main/jniLibs/$abi_dir"
  mkdir -p "$jni_dir"
  GOOS=android GOARCH="$goarch" CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" \
    -o "$ASSETS_DIR/$abi_dir/croc" .
  # Android can execute packaged native libs from nativeLibraryDir; extracted
  # assets in codeCacheDir are blocked on many devices (W^X / SELinux).
  cp "$ASSETS_DIR/$abi_dir/croc" "$jni_dir/libcroc.so"
  chmod +x "$jni_dir/libcroc.so"
}

# arm64 works without NDK (CGO_ENABLED=0).
build_abi arm64 arm64-v8a

# Optional ABIs need CGO + NDK. Skip unless explicitly requested.
if [[ "${BUILD_ALL_ABIS:-}" == "1" && -n "${ANDROID_NDK_HOME:-}" ]]; then
  build_abi arm armeabi-v7a || echo "Warning: armeabi-v7a build failed — skipping."
  build_abi amd64 x86_64 || echo "Warning: x86_64 build failed — skipping."
else
  echo "Note: building arm64-v8a only (set BUILD_ALL_ABIS=1 + ANDROID_NDK_HOME for more)."
fi

echo "Done. Assets in $ASSETS_DIR"
ls -la "$ASSETS_DIR"/*/croc 2>/dev/null || true