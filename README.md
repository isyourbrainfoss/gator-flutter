# Gator (Flutter / Android)

Flutter Android port of [Gator](https://github.com/isyourbrainfoss/gator) — a Material 3 frontend for [croc](https://github.com/schollz/croc) encrypted P2P file transfer.

## Install on Android (Obtainium)

[Obtainium](https://github.com/ImranR98/Obtainium) installs APKs directly from a release source and can notify you when updates are available.

### Recommended: Direct APK Link (stable mirror)

GitHub Release downloads use short-lived signed URLs (`release-assets.githubusercontent.com`) that often fail on mobile with *Connection closed while receiving data*. Use the stable `gh-pages` mirror instead (no signed tokens):

1. Install Obtainium from F-Droid, IzzyOnDroid, or its [GitHub releases](https://github.com/ImranR98/Obtainium/releases).
2. Add app → pick **Direct APK Link** as the source (or override source if needed).
3. Paste this URL:

   ```
   https://raw.githubusercontent.com/isyourbrainfoss/gator-flutter/gh-pages/gator-arm64-v8a.apk
   ```

4. Tap **Get updates** / install.

Obtainium detects new versions from the APK content (partial hash). Release CI updates this file on each `v*` tag.

**“App conflict” on update:** releases before v1.5.3 were signed with ephemeral CI debug keys, so Android blocks in-place updates. Uninstall the old Gator, then install again from Obtainium (your settings are not preserved). v1.5.3+ uses a stable release key so future updates work normally.

**One-tap add (Obtainium installed):**

```
https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://raw.githubusercontent.com/isyourbrainfoss/gator-flutter/gh-pages/gator-arm64-v8a.apk
```

### Alternative: GitHub Releases

If Pages works but you prefer GitHub as the source:

```
https://github.com/isyourbrainfoss/gator-flutter
```

APK filter (arm64-only, ~39 MB):

```
gator-.*-arm64-v8a\.apk
```

Or use the stable release asset name: `gator-arm64-v8a.apk`.

Releases are published when a `v*` tag is pushed (for example `v1.5.1`). Each release includes `gator-<version>-arm64-v8a.apk` and updates the Pages mirror (arm64 phones only).

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run   # Android device/emulator, or -d linux for desktop dev
```

### Build assets

```bash
./tool/build_croc_android.sh   # croc binary (requires Go)
./tool/generate_icons.sh       # launcher icons from GTK SVG
```

croc builds arm64-v8a by default; set `ANDROID_NDK_HOME` for additional ABIs.

### Manual testing

See [TESTING.md](TESTING.md) for the device test matrix.

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).