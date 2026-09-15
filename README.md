# Gator (Flutter)

Material 3 frontend for [croc](https://github.com/schollz/croc) encrypted P2P file transfer — Android APK and Linux Flatpak.
Companion to the GTK app [Gator](https://github.com/isyourbrainfoss/gator).

## Install on Linux (Flatpak)

Same approach as [Flowlog](https://github.com/isyourbrainfoss/Flowlog): CI builds Flutter Linux for **x86_64** and **aarch64**, publishes an ostree remote on GitHub Pages, and attaches `.flatpak` bundles to releases when a tag matches.

```bash
flatpak remote-add --if-not-exists --user --no-gpg-verify gator-flutter \
  https://isyourbrainfoss.github.io/gator-flutter/gator.flatpakrepo
flatpak install --user gator-flutter org.gator.gator
flatpak run org.gator.gator
```

Bundles croc (no host install required). App id is `org.gator.gator` (distinct from GTK Flatpak `org.gator.Gator`).

The GitHub Pages ostree remote is currently unsigned, so `--no-gpg-verify` is required. Prefer the `.flatpak` bundle from a GitHub Release if you want a one-shot install.

Local build:

```bash
./flatpak/build-flatpak.sh          # current arch
./flatpak/build-flatpak.sh x86_64
```

## Install on Android (Obtainium)

[Obtainium](https://github.com/ImranR98/Obtainium) installs APKs directly from a release source and can notify you when updates are available.

### Recommended: Standard JSON (stable mirror)

GitHub Release asset URLs (`release-assets.githubusercontent.com`) often fail on phones with *Connection closed while receiving data*. Use the `gh-pages` mirror instead.

1. Install Obtainium from F-Droid, IzzyOnDroid, or its [GitHub releases](https://github.com/ImranR98/Obtainium/releases).
2. **Add app** → source type **Direct APK Link** (Obtainium auto-detects JSON).
3. Paste this URL:

   ```
   https://raw.githubusercontent.com/isyourbrainfoss/gator-flutter/gh-pages/version.json
   ```

4. Tap **Get updates** / install.

`version.json` includes `versionCode`, `sha256sum`, and the APK URL. CI refreshes it on each `v*` tag.

**One-tap add (Obtainium installed):**

```
https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://raw.githubusercontent.com/isyourbrainfoss/gator-flutter/gh-pages/version.json
```

### Troubleshooting Obtainium updates

| Symptom | Fix |
|---------|-----|
| **“App not installed” / “App conflict” / signature error** | You have a build signed before v1.5.3 (ephemeral CI keys). **Uninstall Gator**, then install fresh from Obtainium. Settings are not preserved. v1.5.3+ uses one stable release key — updates after that work in-place. |
| **“No updates found”** but you expect a new release | Pull to refresh in Obtainium. Confirm [version.json](https://raw.githubusercontent.com/isyourbrainfoss/gator-flutter/gh-pages/version.json) shows a higher `versionCode` than your installed app (Settings → About in Gator, or Obtainium app details). |
| **Download fails / connection closed** | Do not use GitHub Release asset URLs on mobile. Use `version.json` above, not `github.com/.../releases/download/...`. |
| **Still on an old Obtainium entry** | Remove the app in Obtainium, re-add using the `version.json` URL (not the bare `.apk` link). |

### Alternative: Direct APK Link

If JSON does not work in your Obtainium version:

```
https://raw.githubusercontent.com/isyourbrainfoss/gator-flutter/gh-pages/gator-arm64-v8a.apk
```

### Alternative: GitHub Releases

If Pages works but you prefer GitHub as the source:

```
https://github.com/isyourbrainfoss/gator-flutter
```

APK filter (arm64-only, ~47 MB):

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
./tool/build_croc_android.sh   # croc 11.5.3 (requires Go 1.27+)
./tool/generate_icons.sh       # launcher icons from GTK SVG
```

croc builds arm64-v8a by default; set `ANDROID_NDK_HOME` for additional ABIs.

### Manual testing

See [TESTING.md](TESTING.md) for the device test matrix.

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).