# Gator Flutter — Task list (2026-08-25)

Synthesized from 12 review agents (UX, prefs, theme, progress, performance,
stability, croc integration, errors, tests, Android, Linux, accessibility)
plus upstream **croc v11.3.2** (Gator was still on **11.0.1**, which is in a
published advisory range).

Each task is **solved** only when its acceptance criteria pass.

| ID | Task | Solved when |
|----|------|-------------|
| T1 | Bump bundled croc to **11.3.2**; pin one version; send custom codes via `CROC_SECRET` not `--code`; parse v11.2.4+ `On the other computer, run: croc …` plus legacy `Code is:` | `crocVersion` / build scripts / metainfo are 11.3.2; `rg 11.0.1` only in this changelog; `buildSendArgs` has no `--code`; parser tests cover both code formats |
| T2 | Transfer state bugs: `copyWith` can clear `receivedText` / `currentFile`; send `complete` only on exit 0; receive has `errorMessage`; map croc lines to human errors | Notifier tests: clear actually nulls; failed send is Error not Complete; invalid code snacks without shell output |
| T3 | Controllers stay alive; no double-start; Linux process-group kill; close stdin; `--ignore-stdin` in GUI; receive `canStart` excludes in-flight | Controllers are not `autoDispose`; second Start is a no-op; cancel tears down; `yes: false` does not hang |
| T4 | Real progress: filename from progressbar, speed/ETA, receive not labeled Sending, connecting/waiting/retry phases | Parser tests for `file.tar  64% \|…\| (100/153 GB, 8.5 MB/s)`; receive stays Receiving; card shows speed/ETA when present |
| T5 | Send/Receive UX: first-run copy, hide Exclude/Clear until needed, New transfer, confirm Clear/Cancel/Reset, readable codes, no camera QR on Linux | Smoke tests find new copy; Exclude gone on empty queue; after complete, New transfer restores Start |
| T6 | Desktop chrome: NavigationRail ≥800dp, shortcuts, locator returns null, About/Help, snackbar width, theme outline/nav | 1280-wide test uses rail; Linux missing-croc copy is not Obtainium; About is not 1.5.11 |
| T7 | Preferences: save-on-unfocus, confirm reset, advanced actually hides power-user flags, `highway` hash, `--out` / `--rename`, Android DNS not forced every load | Prefs tests: unfocus persists; toggle off hides Debug; `hash=highway` validates |
| T8 | Speed/native: cap service logs, skip trailing-buffer spam, Android save dir writable, `verifyCroc` off main thread, Flatpak home + README GPG | `_lines` ≤ 300; Android default save dir is app-specific; README install uses `--no-gpg-verify` or documents it |
| T9 | Tests for parser, notifiers, copyWith, prefs, widgets | `flutter analyze` and `flutter test` green |

Do **not** treat localization ARB extraction or a live device P2P run as required for this batch (manual matrix remains in TESTING.md).

## Status (2026-08-25)

| ID | Status | Notes |
|----|--------|-------|
| T1 | Solved | Bundled croc 11.3.2; `CROC_SECRET` for send; dual code parsers |
| T2 | Solved | Sentinel `copyWith`; failed transfers are Error; mapped croc errors |
| T3 | Solved | Controllers kept alive; process-group kill; `--ignore-stdin` + `--yes` |
| T4 | Solved | Progressbar filename/speed/ETA; receive stays Receiving |
| T5 | Solved | Empty-state copy; New transfer; confirms; Linux hides camera QR |
| T6 | Solved | NavigationRail ≥800dp; locator `null`; Help/About; snackbar width |
| T7 | Solved | Save-on-unfocus; advanced gating; `highway`; `--out`/`--rename` |
| T8 | Solved | Log cap; Android app-files save dir; async `verifyCroc`; Flatpak home |
| T9 | Solved | `flutter analyze` clean; `flutter test` 62 passed / 1 skipped |
