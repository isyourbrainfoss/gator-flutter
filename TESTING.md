# Gator Flutter — Manual Test Matrix

Run these on a physical Android device (arm64) or emulator after `flutter run`.

## Setup

- Desktop peer with croc v10.4+ or GTK Gator installed
- Both devices on same network (or use default relay)

## Matrix

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | Phone → Desktop file | Add file on Send, start, enter code on desktop `croc` | File received on desktop |
| 2 | Desktop → Phone file | `croc send file` on desktop, receive on phone | File in save folder |
| 3 | Phone → Desktop text | Add Text on Send, start, receive on desktop | Text payload delivered |
| 4 | Desktop → Phone text | `croc send --text "hello"` | Received text dialog shown |
| 5 | QR code send | Start send, scan QR from another device | Code auto-filled |
| 6 | Paste code | Copy code from sender, Paste on Receive | Normalized code in field |
| 7 | Cancel mid-transfer | Start large file, tap Cancel | Transfer stops, UI resets |
| 8 | Share intent | Share image/file from Gallery to Gator | Appears in Send queue |
| 9 | Share text | Share URL/text from browser to Gator | Text added to Send queue |
| 10 | Preferences persist | Change relay/port, restart app | Settings retained |
| 11 | Auto-accept off | Disable `--yes` in prefs, receive | croc prompts (if visible in log) |
| 12 | croc missing | Remove assets binary, reinstall | Croc missing screen shown |

## Automated checks

```bash
flutter analyze
flutter test
flutter build apk --debug
```