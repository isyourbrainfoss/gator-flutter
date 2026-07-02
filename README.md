# Gator (Flutter / Android)

Flutter Android port of [Gator](https://github.com/isyourbrainfoss/gator) — a Material 3 frontend for [croc](https://github.com/schollz/croc) encrypted P2P file transfer.

## Install on Android (Obtainium)

[Obtainium](https://github.com/ImranR98/Obtainium) installs APKs directly from GitHub Releases and can notify you when updates are available.

1. Install Obtainium from F-Droid, IzzyOnDroid, or its [GitHub releases](https://github.com/ImranR98/Obtainium/releases).
2. Add this app using the repository URL:

   ```
   https://github.com/isyourbrainfoss/gator-flutter
   ```

3. Obtainium should auto-detect **GitHub** as the source. Use this APK filter (arm64-only, ~25 MB):

   ```
   gator-.*-arm64-v8a\.apk
   ```

4. Tap **Get updates** / install the latest release APK.

   If a download fails with *Connection closed*, retry on Wi‑Fi or pick the latest `arm64-v8a` asset (not the older ~70 MB universal APK on v1.5.0).

**One-tap add (Obtainium installed):** open this link on your phone:

```
https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/isyourbrainfoss/gator-flutter
```

Releases are published when a `v*` tag is pushed (for example `v1.5.1`). Each release includes `gator-<version>-arm64-v8a.apk` (arm64 phones only).

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