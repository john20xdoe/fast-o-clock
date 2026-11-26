# Fast O'Clock — Privacy Policy & Health Data Notes (Draft)

> **Status:** Draft notes for future Play Store / Health Connect compliance and in-app privacy disclosure.

---

## 1. Core Privacy Posture (Offline-First)
- **Local-only storage:** All fasting records, notes, mood tags, and preferences are stored strictly on-device (SQLite + `SharedPreferences`).
- **No accounts, no cloud sync, no analytics/ads:** Fast O'Clock does not collect, transmit, sell, or share personal or health data with any developer server or third party.
- **User-controlled exports:** Backups (JSON export) are triggered explicitly by the user and saved/shared only to locations the user chooses.

---

## 2. Bedtime & Circadian Alignment Data
To help users and clinicians see late-night eating vs. sleep timing (gap between fast start / last meal and bedtime), Fast O'Clock supports two bedtime sources:

### A. Manual Bedtime (Default / Baseline)
- **Source:** User-entered typical bedtime (e.g., `23:00`) in Settings.
- **Storage:** Saved locally in `SharedPreferences`.
- **Permissions:** None required.
- **Role:** Always available as the primary setting and automatic fallback when Health Connect is disabled, denied, or missing a sleep log for a given night.

### B. Optional Health Connect Sleep Connection (Android)
- **Permission requested:** `android.permission.health.READ_SLEEP` (`SleepSessionRecord`, read-only).
- **Opt-in only:** Disabled by default; enabled only when the user explicitly toggles Health Connect sleep sync in Settings and grants OS permission.
- **What is read:** Sleep session start/end timestamps for recent nights to compute actual bedtime and pre-sleep fasting gap automatically.
- **Fallback behavior:** If Health Connect is unavailable, permission is revoked/denied, or no `SleepSessionRecord` exists for a night, the app silently falls back to the user's manual bedtime.
- **What is NOT done:**
  - App does **not** write or modify Health Connect records.
  - Sleep data is **never** uploaded off-device, logged to external analytics, or shared with third parties.

---

## 3. Google Play & Health Connect Compliance Checklist
Before shipping `READ_SLEEP` in production:
- [ ] Publish public Privacy Policy URL (covering offline storage + Health Connect `READ_SLEEP` limited use) and link it in Play Console and inside app Settings.
- [ ] Complete the **Health Connect App Declaration** in Google Play Console justifying `READ_SLEEP` (displaying fasting-to-bedtime circadian alignment).
- [ ] Show an in-app rationale explaining read-only local use + manual fallback *before* triggering the system Health Connect permission prompt.
- [ ] Handle permission revocation gracefully (auto-fallback to manual bedtime without blocking app usage).

---

## 4. User Controls & Deletion
- Users can edit or delete any fasting record, clear notes, or change/clear manual bedtime at any time.
- Users can disable Health Connect sync in app Settings or revoke `READ_SLEEP` anytime via Android **Settings → Health Connect → App permissions**.
- Uninstalling the app removes all locally stored fasting and preference data.
