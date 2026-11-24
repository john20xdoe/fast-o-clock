# Fast O'Clock — Timeline & Performance Redesign Plan

Focused plan for upgrading Tab 2 (`TimelineScreen`) and decoupling 1 Hz timer rebuilds across the app, following full completion of the initial MVP and UI/UX feedback rounds.

---

## Stage 0 — Sync `/design` Docs & Plan Baseline
- [x] Sync `design/ARCHITECTURE.md` (actual tree, `clockTick`, `dynamic_color`, fonts, 15m eating-window alert, debug export).
- [x] Sync `design/DATA_MODEL.md` (4h minimum duration, 4 mood tags, 6 `MetabolicStage` thresholds, Timeline metrics & bucket math).
- [x] Sync `design/UI_SPEC.md` (`FastingScreen`, `SettingsScreen`, `FastEditorSheet`, and redesigned `TimelineScreen`).

---

## Stage 1 — Performance Foundation: Isolate 1 Hz Ticker + Day Rollover
- **`lib/state/fasting_controller.dart`**:
  - Expose `ValueListenable<DateTime> clockTick` (`ValueNotifier`) and dispose it in `dispose()`.
  - Compute `localDayKey` on demand (`year * 10000 + month * 100 + day`) and track `_lastNotifiedDayKey`.
  - `_syncTicker()` immediately refreshes `clockTick.value = nowUtc`; `_ticker` updates `clockTick` every 1s **without** `notifyListeners()`, calling `notifyListeners()` only when `localDayKey` changes at local midnight.
  - `didChangeAppLifecycleState(resumed)` refreshes `clockTick` and notifies if the local day rolled over.
  - Add monotonic `historyVersion` incremented on `_reloadRecords()`, and memoize legacy stats getters (`currentStreak`, `averageFastDuration`, `lastSevenDaysSummary`).
- **`lib/screens/fasting_screen.dart`**:
  - Wrap time-dependent active & idle UI in `ValueListenableBuilder<DateTime>(valueListenable: controller.clockTick)` reading live `controller.nowUtc` directly.
- **`lib/app.dart`**:
  - Replace `context.watch<FastingController>()` in `FastOClockApp.build` with `Selector` on `(isInitialized, isOnboarded, flutterThemeMode)` so `MaterialApp` performs 0 rebuilds/sec during active fasts.
  - Keep `_pages[_selectedIndex]` (no `IndexedStack`) and pass `onFocusedRecordHandled` to `TimelineScreen`.

---

## Stage 2 — Pure Timeline View-Model & Memoized Stats
- **`lib/models/timeline_summary.dart`**:
  - `TimelineRange` (`d7`, `d30`, `all`) and `TimelineFilter` (`all`, `goalMet`, `endedEarly`, `withNotes`).
  - Single-pass $O(N)$ `TimelineSnapshot.build(...)` computing:
    - Global all-time `currentStreak` and `bestStreak` (DST-safe day stepping).
    - Range-scoped KPIs (`totalFastsInRange`, `goalMetCountInRange`, `completionPercentInRange`, `averageDurationInRange`, `longestDurationInRange`).
    - Daily single-best-fast chart buckets (`7D`/`30D`, without summing multi-fast days) and up to 12 weekly-average buckets (`All`, `primaryRecord = null`).
    - Pre-formatted `TimelineMonthHeader` and `TimelineRecordItem` rows (date, duration, window, goal delta, `FastProtocol`, `MetabolicStage`, `progressRatio`, `semanticLabel`).

---

## Stage 3 — Single Interactive Bar Chart
- **`lib/widgets/timeline_chart.dart`**:
  - `DurationBarChart` rendered with a single `CustomPainter` inside `RepaintBoundary`.
  - Dashed horizontal reference line labeled `Default <Xh>`, unified `#00C853` / `#FF8A00` colors, tap-to-inspect readout pill (`Edit` on daily completed bars; read-only summary on `All` weekly / empty / active bars), and full `Semantics` summary.

---

## Stage 4 — Redesigned `TimelineScreen`
- **`lib/screens/timeline_screen.dart`**:
  - `StatefulWidget` watching only `(historyVersion, activeFast?.id, localDayKey, targetDurationMin)` via `Selector`.
  - Compact header (`Timeline` + `+ Log Fast` tonal button; no occluding extended FAB).
  - Range `SegmentedButton` (`7D` | `30D` | `All`), 2×2 KPI strip, `DurationBarChart`, horizontally scrollable filter chips (`All`, `Goal Met`, `Ended Early`, `Notes`), and empty-filter `"Show All"` state.
  - Flattened `SliverList.builder` with `PageStorageKey('timeline_scroll')`, month headers, compact rows (~96–112dp) with distinct mood icons/tints, and `focusedRecordId` jump + 1.2s highlight pulse.

---

## Stage 5 — Tests & Verification
- **`test/models/timeline_summary_test.dart`**: Global streak vs range KPIs, same-day multi-fast selection, mixed protocols, `All` weekly buckets, month headers, filters, deltas, metabolic stages.
- **`test/state/fasting_controller_test.dart`**: `clockTick` ticks without `notifyListeners()`, `_syncTicker()` refreshes immediately, midnight rollover notifies once, live `localDayKey`, `historyVersion`, `dispose()`.
- **`test/screens/timeline_screen_test.dart`**: Header & no FAB, range toggle, filter chips & empty-filter reset, distinct mood icons, 0 rebuilds during active fast ticks, `focusedRecordId` highlight.

---

## Deferred (Future)
- **Day-Based / Recurring Fasting Patterns** (ADF, 1 day/week, 5-day) — deferred pending streak calculation analysis.
- **Google Drive Backup** — deferred; focus on local file backup improvements first.
