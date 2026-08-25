#!/usr/bin/env bash
# Build a Gator Flutter Flatpak for the current (or requested) CPU architecture.
# Pattern matches Flowlog: prebuild Flutter Linux release, then flatpak-builder.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLATPAK_DIR="$ROOT/flatpak"
ARCH="${1:-$(uname -m)}"
CROC_VERSION="${CROC_VERSION:-11.3.2}"

case "$ARCH" in
  x86_64|amd64)
    FLATPAK_ARCH=x86_64
    FLUTTER_OUT=x64
    CROC_ASSET="croc_v${CROC_VERSION}_Linux-64bit.tar.gz"
    ;;
  aarch64|arm64)
    FLATPAK_ARCH=aarch64
    FLUTTER_OUT=arm64
    CROC_ASSET="croc_v${CROC_VERSION}_Linux-ARM64.tar.gz"
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

if ! command -v flatpak-builder >/dev/null; then
  echo "flatpak-builder is required." >&2
  exit 1
fi

if ! command -v flutter >/dev/null; then
  echo "flutter is required." >&2
  exit 1
fi

echo "==> Installing GNOME Platform 48 (if missing)"
flatpak install -y --user flathub org.gnome.Platform//48 org.gnome.Sdk//48 >/dev/null 2>&1 || \
  flatpak install -y flathub org.gnome.Platform//48 org.gnome.Sdk//48

echo "==> Building Flutter Linux release ($FLATPAK_ARCH)"
cd "$ROOT"
flutter pub get
flutter build linux --release

BUNDLE="$ROOT/build/linux/$FLUTTER_OUT/release/bundle"
if [[ ! -f "$BUNDLE/gator" ]]; then
  echo "Missing Linux bundle at $BUNDLE" >&2
  exit 1
fi

ICON_SRC="$ROOT/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
ICON_DST="$FLATPAK_DIR/org.gator.gator.png"
cp "$ICON_SRC" "$ICON_DST"

echo "==> Fetching croc $CROC_VERSION ($CROC_ASSET)"
curl -fsSL "https://github.com/schollz/croc/releases/download/v${CROC_VERSION}/${CROC_ASSET}" \
  | tar -xz -C "$FLATPAK_DIR" croc
chmod +x "$FLATPAK_DIR/croc"
"$FLATPAK_DIR/croc" --version || true

echo "==> Packaging Flatpak bundle"
tar -czf "$FLATPAK_DIR/gator-linux-bundle.tar.gz" -C "$BUNDLE" .

REPO_DIR="${REPO_DIR:-$FLATPAK_DIR/repo}"
mkdir -p "$REPO_DIR"
BUILD_DIR="${BUILD_DIR:-$FLATPAK_DIR/build-$FLATPAK_ARCH}"
rm -rf "$BUILD_DIR"

flatpak-builder \
  --user \
  --arch="$FLATPAK_ARCH" \
  --force-clean \
  --repo="$REPO_DIR" \
  "$BUILD_DIR" \
  "$FLATPAK_DIR/org.gator.gator.yml"

BUNDLE_OUT="$FLATPAK_DIR/org.gator.gator-${FLATPAK_ARCH}.flatpak"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_OUT" org.gator.gator \
  --arch="$FLATPAK_ARCH" \
  --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo

echo "==> Built:"
echo "    Repo:   $REPO_DIR"
echo "    Bundle: $BUNDLE_OUT"
echo
echo "Install locally:"
echo "  flatpak install --user --bundle $BUNDLE_OUT"
echo
echo "Or from the local repo:"
echo "  flatpak --user remote-add --if-not-exists --no-gpg-verify gator-local file://$REPO_DIR"
echo "  flatpak install --user gator-local org.gator.gator"
