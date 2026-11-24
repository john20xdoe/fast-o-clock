# Fast O'Clock — Data Model & Algorithms

Specifications for SQLite schema, preferences keys, domain models, overlap validation, streak math, and JSON backup format.

---

## 1. SQLite Schema (`fast_oclock.db`, Version `1`)

### Table: `fast_records`

Stores both the currently active fast (`end_time_ms IS NULL`) and all completed historical fasts (`end_time_ms IS NOT NULL`).

```sql
CREATE TABLE fast_records (
    id TEXT PRIMARY KEY,                  -- 128-bit random hex ID (Random.secure())
    protocol_id TEXT NOT NULL,            -- e.g. '16_8', '18_6', 'custom'
    start_time_ms INTEGER NOT NULL,       -- UTC epoch milliseconds
    end_time_ms INTEGER,                  -- UTC epoch milliseconds; NULL = active fast
    target_duration_min INTEGER NOT NULL, -- Target duration in minutes (> 0)
    note TEXT,                            -- Optional completion note
    mood TEXT,                            -- Optional mood tag ('great', 'okay', 'challenging', 'bad')
    created_at_ms INTEGER NOT NULL,       -- UTC epoch milliseconds
    updated_at_ms INTEGER NOT NULL        -- UTC epoch milliseconds
);

-- Enforce at most ONE active fast across all SQLite versions
CREATE TRIGGER trg_single_active_fast_insert
BEFORE INSERT ON fast_records
WHEN NEW.end_time_ms IS NULL
BEGIN
    SELECT RAISE(ABORT, 'Active fast already exists')
    WHERE EXISTS (SELECT 1 FROM fast_records WHERE end_time_ms IS NULL);
END;

CREATE TRIGGER trg_single_active_fast_update
BEFORE UPDATE OF end_time_ms ON fast_records
WHEN NEW.end_time_ms IS NULL
BEGIN
    SELECT RAISE(ABORT, 'Active fast already exists')
    WHERE EXISTS (SELECT 1 FROM fast_records WHERE end_time_ms IS NULL AND id != NEW.id);
END;

-- Fast chronological queries & overlap checks
CREATE INDEX idx_fast_records_start ON fast_records (start_time_ms DESC);
CREATE INDEX idx_fast_records_end   ON fast_records (end_time_ms DESC);
```

### Derived Record Properties (`FastRecord` Dart Model)

- `bool get isActive => endTimeMs == null;`
- `Duration elapsedDuration([DateTime? nowUtc])`:
  - `((endTimeMs ?? nowUtcMs) - startTimeMs)` clamped `>= 0`.
- `double progress([DateTime? nowUtc])`:
  - `(elapsedDuration(nowUtc).inMilliseconds / (targetDurationMin * 60000.0)).clamp(0.0, 1.0)`.
- `bool get isGoalMet`:
  - `endTimeMs != null && ((endTimeMs! - startTimeMs) >= targetDurationMin * 60000)`

---

## 2. Non-Overlapping Time Validation Rules

All record insertions and start/end edits must pass interval validation before SQLite commit. Let `:effective_end_ms = COALESCE(:candidate_end_ms, :now_utc_ms)` so that an active fast (`end_time_ms IS NULL`) is validated across `[candidate_start_ms, now_utc_ms]`:

1. **Boundary Sanity**:
   - `:candidate_target_duration_min > 0`.
   - `:candidate_start_ms <= :now_utc_ms` (cannot start a fast in the future).
   - If `:candidate_end_ms != null`:
     - `:candidate_end_ms <= :now_utc_ms` (cannot complete a fast in the future).
     - `:candidate_end_ms >= :candidate_start_ms + 4 * 3600000` (minimum completed fast duration: **4 hours**, `DatabaseService.minCompletedFastDurationMs`).
2. **Overlap Query**:
   Two intervals `[A_start, A_end]` and `[B_start, B_end]` (where any active fast has `end = :now_utc_ms`) overlap if and only if:
   ```sql
   SELECT * FROM fast_records
   WHERE (? IS NULL OR id != ?)
     AND start_time_ms < COALESCE(:candidate_end_ms, :now_utc_ms)
     AND COALESCE(end_time_ms, :now_utc_ms) > :candidate_start_ms
   ORDER BY start_time_ms DESC
   LIMIT 1;
   ```
   - If a row is returned, the edit/insert is rejected with `FastValidationException` identifying the conflicting fast.

---

## 3. Domain Catalogs

### 3.1 Fasting Protocols (`FastProtocol`)

| `id` | Label | Fast Hours (`targetDurationMin`) | Eating Window Hours | Supports Eating Window Alert? |
|---|---|---|---|---|
| `14_10` | `14:10` | 14h (`840` min) | 10h (`600` min) | Yes |
| `16_8` | `16:8` *(Default)* | 16h (`960` min) | 8h (`480` min) | Yes |
| `18_6` | `18:6` | 18h (`1080` min) | 6h (`360` min) | Yes |
| `20_4` | `20:4` | 20h (`1200` min) | 4h (`240` min) | Yes |
| `23_1` | `23:1 (OMAD)` | 23h (`1380` min) | 1h (`60` min) | Yes |
| `36_0` | `36h (Monk)` | 36h (`2160` min) | N/A | No (`target >= 24h`) |
| `custom` | `Custom` | User-defined (`60..10080` min / 1h..168h) | `24h - target` if `< 24h`, else N/A | Only when `target < 1440` min |

### 3.2 Metabolic Stages (`MetabolicStage`)

Computed from elapsed fasting hours (`elapsedHours = elapsed.inSeconds / 3600.0`):

| Stage ID | Hour Range | Title | Short Summary |
|---|---|---|---|
| `blood_sugar_rise` | `0h – 2h` | Blood Sugar Rises | Post-meal digestion; blood glucose and insulin rise as food is absorbed. |
| `blood_sugar_fall` | `2h – 4h` | Blood Sugar Falls | Insulin clears glucose into cells; blood sugar and insulin drop toward baseline. |
| `post_absorptive` | `4h – 8h` | Glycogen Burn | Digestion finishes and insulin drops low; body taps liver glycogen for energy. |
| `fat_burning` | `8h – 12h` | Fat Burning | Liver glycogen depletes; body shifts toward lipolysis to burn fat for fuel. |
| `ketosis` | `12h – 18h` | Ketosis | Fat breakdown accelerates; liver produces ketones as a primary fuel source. |
| `autophagy` | `18h+` | Deep Ketosis & Autophagy | Ketone levels rise further while cellular cleanup and recycling ramp up. |

---

## 4. `SharedPreferences` Keys (`AppSettings`)

| Key | Type | Default | Description |
|---|---|---|---|
| `pref_is_onboarded` | `bool` | `false` | Whether first-run onboarding has been completed |
| `pref_theme_mode` | `String` | `'dark'` | `'dark'`, `'light'`, or `'system'` (Dark-first) |
| `pref_default_protocol_id` | `String` | `'16_8'` | Default protocol selected for new fasts |
| `pref_custom_duration_min` | `int` | `960` | Last used custom target duration in minutes |
| `pref_notify_goal_reached` | `bool` | `true` | Schedule local alert when target duration is reached |
| `pref_notify_eating_window` | `bool` | `false` | Schedule local alert 15m before eating window ends (`<24h` protocols) |
| `pref_show_remaining_time` | `bool` | `false` | Timer display preference (`false` = Elapsed, `true` = Remaining) |

---

## 5. Streak & Timeline Summary Metrics Algorithm (`TimelineSnapshot`)

### Global Streaks (Always All-Time, Unclipped by Range Tabs)
1. Filter `history` to completed fasts where `isGoalMet == true` (`end_time_ms - start_time_ms >= target_duration_min * 60000`).
2. Map each qualifying fast's `end_time_ms` to its local calendar date `DateTime(year, month, day)` and collect into `qualifyingDays`.
3. **Current Streak**:
   - Let `today` be `(now.year, now.month, now.day)` and `yesterday` be `DateTime(today.year, today.month, today.day - 1)`.
   - If `qualifyingDays` contains neither `today` nor `yesterday`, `currentStreak = 0`.
   - Otherwise, walk backward day-by-day from `today` (if present) else `yesterday` using `DateTime(y, m, d - 1)` while present.
4. **Best Streak**:
   - Sort unique `qualifyingDays` ascending and find the longest consecutive `+1 day` run (`DateTime(y, m, d + 1)` for DST safety).

### Range-Scoped KPIs (`7D`, `30D`, `All`)
- **Range Window** (by local `endTimeLocal` calendar day):
  - `7D`: `today - 6` through `today`
  - `30D`: `today - 29` through `today`
  - `All`: all completed records
- **Metrics in Range**:
  - `totalFastsInRange`: count of completed fasts in range
  - `goalMetCountInRange`: count with `isGoalMet == true`
  - `completionPercentInRange`: `round(goalMetCountInRange / totalFastsInRange * 100)` (`0` when empty)
  - `averageDurationInRange`: mean `(endTimeMs - startTimeMs)` across fasts in range (`Duration.zero` when empty)
  - `longestDurationInRange`: max `(endTimeMs - startTimeMs)` across fasts in range (`Duration.zero` when empty)
- **Filter Counts & History List Scope**: `allCount`, `goalMetCount`, `endedEarlyCount`, `withNotesCount`, and month-grouped history cards are scoped to the selected range (`7D`, `30D`, `All`) and then filtered by the selected filter chip (`All`, `Goal Met`, `Ended Early`, `Notes`). `currentStreak` and `bestStreak` remain global (all-time).

### Chart Buckets (`ChartBarBucket`)
- **`7D` / `30D` (Daily Single-Best-Fast Buckets)**:
  - One bucket per local calendar day (`today - 6 .. today` or `today - 29 .. today`).
  - When multiple completed fasts end on the same calendar day, select the **best/longest single fast** (`goalMet` beats `completedBelowGoal`, tie-break by longest elapsed duration) as `primaryRecord` and record `recordCount` + `goalMetCount` without summing durations.
  - If `today` has 0 completed fasts and `activeFast != null`, mark `status = active` with `duration = activeFast.elapsedDuration(nowUtc)` and `primaryRecord = null`.
- **`All` (Weekly-Average Buckets)**:
  - Up to 12 rolling 7-day windows ending `today` (`primaryRecord = null`, `isWeekly = true`).
  - `duration` is the mean fast duration in that week; `status` is `goalMet` if `duration.inMinutes >= defaultTargetMin || goalMetCount * 2 >= recordCount`, `completedBelowGoal` if `recordCount > 0` below threshold, or `none`.

---

## 6. JSON Backup & Restore Specification

### Payload Format (`fast_oclock_backup_YYYYMMDD.json`)

```json
{
  "schemaVersion": 1,
  "appId": "com.neurral.fast_oclock",
  "exportedAtMs": 1795238400000,
  "settings": {
    "defaultProtocolId": "16_8",
    "customDurationMin": 960,
    "themeMode": "dark",
    "notifyGoalReached": true,
    "notifyEatingWindow": false,
    "showRemainingTime": false
  },
  "records": [
    {
      "id": "b4a8c4e27c1a4b9f9a2d1f3e5d7c9b0a",
      "protocolId": "16_8",
      "startTimeMs": 1795152000000,
      "endTimeMs": 1795209600000,
      "targetDurationMin": 960,
      "note": "Felt energized",
      "mood": "great",
      "createdAtMs": 1795152000000,
      "updatedAtMs": 1795209600000
    }
  ]
}
```

### Import Modes
Both modes validate `schemaVersion == 1` and run within a single SQLite transaction:

1. **Merge by ID (Recommended Default)**:
   - For each incoming record:
     - Candidate write if `id` does not exist locally (insert) or `incoming.updatedAtMs > local.updatedAtMs` (update).
     - Candidate write must pass non-overlapping interval check (excluding own `id`), 4h minimum duration check for completed fasts, and single-active-fast check.
     - Valid candidates are inserted/updated; conflicting records are skipped and reported (`Imported X, Updated Y, Skipped Z conflicting`).
2. **Replace All**:
   - Validate all incoming records (no overlaps, >= 4h completed duration, at most one active fast).
   - `DELETE FROM fast_records`, insert all incoming records, apply incoming `settings`, and reschedule notifications for any active fast.
