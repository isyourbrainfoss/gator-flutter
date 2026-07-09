# Gator Flutter Improvement Plan

Generated based on comprehensive code review (2026-07-09).

## Overview
Gator is a solid Flutter wrapper around croc for P2P encrypted transfers. The app has good test coverage on core logic, sophisticated platform handling, and feature parity. Improvements focus on maintainability, UX, architecture, and robustness.

Current status after initial agent work:
- Typed immutable `GatorSettings` model landed (replaces Map<String,dynamic>).
- Version handling modernized with `package_info_plus` + `appVersionProvider`.
- Shell logs are now bounded (kMaxLogLines = 300) with UI trim indicator.
- Analyze clean, full test suite green.
- Multiple subagents active for parallel execution.

## Task Breakdown & Dependencies

### Foundation (Completed / In-flight by agents)
1. **Typed Settings Model** (HIGH priority, foundational)
   - Created `GatorSettings` (@immutable, copyWith, fromMap/toMap, validation preserved).
   - Migrated SettingsRepository, SettingsNotifier, all consumers, croc arg builders.
   - Internal legacy map helpers kept for compat.
   - Files touched: models/gator_settings.dart, providers/settings_provider.dart, services/settings_repository.dart + croc_*.dart, features/**, tests.

2. **Versioning** (Quick win)
   - Added `package_info_plus: ^9.0.1`.
   - New `lib/providers/app_version_provider.dart` (FutureProvider).
   - Removed hardcoded `appVersion`, wired into About dialog with fallback.
   - Constants comment updated.

3. **Bounded Logs** (Quick win)
   - Added `kMaxLogLines = 300` in constants.
   - `appendLog` in Send/ReceiveNotifier now trims.
   - Send/Receive pages show "(trimmed)" in ExpansionTile title.

### Next Priority
4. **Controller Refactor** (HIGH, agent spawned)
   - Remove `BuildContext` from ReceiveController.
   - Move dialog triggers (`received_text_dialog`, `transfer_complete_dialog`) to page widgets via `ref.listen`.
   - Clean lifecycle / disposal.
   - Keep or evolve the controller + notifier pattern.
   - Dependencies: settings model complete.

5. **Preferences UX** (MEDIUM, agent spawned)
   - Add `showAdvancedSettings` (or local toggle + persisted).
   - Hide advanced sections (Relay/Proxy, certain sending opts) behind toggle by default.
   - Makes the app friendlier without losing power-user access.

6. **Error Handling & Logging** (MEDIUM)
   - Introduce consistent logging (debugPrint with tags or tiny util).
   - Replace `catch (_)` with logged errors in services (croc binary locator, transfer service, etc.).
   - Improve user-facing error messages.

7. **Progress & Transfer UX Polish** (MEDIUM)
   - Enhance TransferProgressCard: show current file name (if parsable), speed, ETA if feasible.
   - Better phase labels.

8. **Process & Lifecycle Robustness** (HIGH for reliability)
   - Review CrocTransferService cancellation, Android process kill, backgrounding.
   - Add app lifecycle observer in shell to handle pause/resume of transfers.
   - Consider EventChannel improvements on native side for better streaming.

### Lower / Ongoing
9. Update deps (careful with Riverpod 3).
10. Expand tests (error paths, controller logic, new features).
11. Croc binary update (current 10.4.4 → latest 10.4.12 via tool/build script). Test thoroughly.
12. Other: localization, SAF for folders, more desktop love.

## Execution Order Recommendation
1. Settings model (done)
2. Version + logs (done)
3. Controller refactor + prefs UX (in progress via agents)
4. Error handling + logging
5. Progress UX
6. Robustness + lifecycle
7. Deps + croc update + tests

## Risks
- Large refactor (settings) touched many call sites — mitigated by tests + analyze.
- Process spawning code is inherently platform-fragile.
- Concurrent agent edits were managed; filesystem shows clean results so far.

## Files Likely Touched by Major Work
- lib/models/gator_settings.dart (core)
- lib/providers/*
- lib/services/croc_* 
- lib/features/{send,receive,shell,preferences,dialogs}
- test/*
- pubspec.yaml
- android/ (if robustness work)

## How to Track
Subagents were spawned for parallel work:
- Version agent
- Logs + shell fix agent
- Typed settings agent
- Plan agent
- Controller refactor agent
- Preferences UX agent

Use `get_command_or_subagent_output` with their IDs for live status if needed.

After these, re-review and consider next batch (robustness, tests).

## Additional Ideas
- Contribute structured output flag to upstream croc to reduce parser heuristics.
- Add transfer history / recent codes.
- Better notifications for completed receives when app is backgrounded.

This plan keeps the spirit of the original GTK Gator while making the Flutter port more maintainable and user-friendly.
