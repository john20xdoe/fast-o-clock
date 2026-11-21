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
    mood TEXT,                            -- Optional mood tag ('great', 'good', 'okay', 'hard')
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
- `int elapsedMinutes(DateTime nowUtc)`:
  - `(( (endTimeMs ?? nowUtc.millisecondsSinceEpoch) - startTimeMs ) ~/ 60000).clamp(0, maxInt)`
- `double progress(DateTime nowUtc)`:
  - `(elapsedMinutes(nowUtc) / targetDurationMin).clamp(0.0, 1.0)` (uncapped ratio available for over-goal badge display).
- `bool get isGoalMet`:
  - `endTimeMs != null && ((endTimeMs! - startTimeMs) >= targetDurationMin * 60000)`

---

## 2. Non-Overlapping Time Validation Rules

All record insertions and start/end edits must pass interval validation before SQLite commit. Let `:effective_end_ms = COALESCE(:candidate_end_ms, :now_utc_ms)` so that an active fast (`end_time_ms IS NULL`) is validated across `[candidate_start_ms, now_utc_ms]`:

1. **Boundary Sanity**:
   - `:candidate_start_ms <= :now_utc_ms` (cannot start a fast in the future).
   - If `:candidate_end_ms != null`:
     - `:candidate_end_ms <= :now_utc_ms` (cannot complete a fast in the future).
     - `:candidate_end_ms > :candidate_start_ms` (minimum duration: 1 minute).
2. **Overlap Query**:
   Two intervals `[A_start, A_end]` and `[B_start, B_end]` (where any active fast has `end = :now_utc_ms`) overlap if and only if:
   ```sql
   SELECT COUNT(*) FROM fast_records
   WHERE id != :current_id
     AND start_time_ms < COALESCE(:candidate_end_ms, :now_utc_ms)
     AND COALESCE(end_time_ms, :now_utc_ms) > :candidate_start_ms;
   ```
   - If `COUNT(*) > 0`, the edit/insert is rejected with a user-facing validation error identifying the conflicting fast.

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

Computed from elapsed fasting hours (`elapsedHours = elapsedSeconds / 3600.0`):

| Stage ID | Hour Range | Title | Short Summary |
|---|---|---|---|
| `fed` | `0h – 4h` | Blood Sugar Rise & Fall | Body digests last meal; insulin levels begin to drop. |
| `post_absorptive` | `4h – 8h` | Blood Sugar Drop | Blood glucose normalizes; glycogen reserves begin mobilizing. |
| `fat_burning` | `8h – 12h` | Fat Burning | Liver glycogen depletes; body shifts toward lipolysis for energy. |
| `ketosis` | `12h – 18h` | Ketosis | Ketone production increases as fat becomes primary fuel source. |
| `autophagy` | `18h+` | Deep Ketosis & Autophagy | Cellular cleanup and recycling processes accelerate. |

---

## 4. `SharedPreferences` Keys (`AppSettings`)

| Key | Type | Default | Description |
|---|---|---|---|
| `pref_is_onboarded` | `bool` | `false` | Whether first-run onboarding has been completed |
| `pref_theme_mode` | `String` | `'dark'` | `'dark'`, `'light'`, or `'system'` (Dark-first) |
| `pref_default_protocol_id` | `String` | `'16_8'` | Default protocol selected for new fasts |
| `pref_custom_duration_min` | `int` | `960` | Last used custom target duration in minutes |
| `pref_notify_goal_reached` | `bool` | `true` | Schedule local alert when target duration is reached |
| `pref_notify_eating_window` | `bool` | `false` | Schedule local alert when eating window ends (`<24h` protocols) |
| `pref_show_remaining_time` | `bool` | `false` | Timer display preference (`false` = Elapsed, `true` = Remaining) |

---

## 5. Streak & Summary Metrics Algorithm

### Current Streak (Consecutive Local Calendar Days with Goal Met)
1. Filter `history` to completed fasts where `isGoalMet == true` (`end_time_ms - start_time_ms >= target_duration_min * 60000`).
2. Map each qualifying fast's `end_time_ms` to its local calendar date `(year, month, day)` using `DateTime.fromMillisecondsSinceEpoch(endTimeMs, isUtc: true).toLocal()`, and collect into a deduplicated descending sorted set `qualifyingDays`.
3. Let `today` be the current local date `(now.year, now.month, now.day)` and `yesterday` be `today - 1 day`.
4. If `qualifyingDays` contains neither `today` nor `yesterday`, `currentStreak = 0`.
5. Otherwise, start from `cursor = qualifyingDays.contains(today) ? today : yesterday` and count consecutive days `cursor, cursor - 1, cursor - 2, ...` present in `qualifyingDays`.

### Summary Metrics
- **Total Fasts**: Count of all completed fasts (`end_time_ms IS NOT NULL`).
- **Average Fast Duration**: Mean `(end_time_ms - start_time_ms)` across completed fasts (0 if none).
- **Weekly Completion Bar**: For the last 7 local calendar days (`today - 6` through `today`), each day shows status: `Goal Met`, `Completed (< Goal)`, `Active`, or `None`.

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
     - Determine if it is a candidate write: either `id` does not exist locally (insert), or `id` exists locally with `incoming.updatedAtMs > local.updatedAtMs` (update).
     - Every candidate write (both insert and update) must pass the non-overlapping interval check (excluding its own `id`) and the single-active-fast check (`endTimeMs == null` only if no other active fast exists).
     - Valid candidates are inserted/updated; conflicting records are skipped and reported in the import summary (`Imported X, Updated Y, Skipped Z conflicting`).
2. **Replace All**:
   - Validate that incoming `records` have no internal overlaps and at most one record with `endTimeMs == null`.
   - `DELETE FROM fast_records`, insert all incoming records, apply incoming `settings`, and reschedule notifications for any active fast.
