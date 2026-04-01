# TODOS

Deferred work items captured during engineering review sessions.

---

## Scan results persistence across restarts

**What:** Persist the last scan result + user category corrections to local storage
(SharedPreferences or JSON file). On subsequent launches, show persisted result immediately
and run a background refresh instead of a 5-second blocking scan.

**Why:** Every return visit forces a 5-second spinner + re-correction of any category
overrides. Persistence removes the most common friction point for return users.

**Pros:** Perceived instant launch, corrections survive restarts, better for demo scenarios.

**Cons:** Cache staleness edge cases (device leaves network, user buys a new device).
Would need a "refresh" affordance so the user can force a new scan.

**Context:** No persistence layer exists yet. `shared_preferences` or plain JSON to
`path_provider` would work. The persisted data model is `List<DetectedDevice>` plus a
`Map<String, DeviceCategory>` for user overrides keyed by device display name. Scan
results are keyed by network (SSID or subnet) to avoid showing stale data when the user
moves to a different network.

**Depends on / blocked by:** NWBrowser mDNS implementation (this PR).

---

## Extract _ResultsStep widget from main.dart

**What:** Move the results screen implementation from `main.dart` into a dedicated
`apps/client_flutter/lib/widgets/results_step.dart` file.

**Why:** After the NWBrowser PR, `main.dart` will be ~600 lines with 4 new results-screen
elements (share button, speed test UI, confidence badge, speed comparison display).
Extracting the results step restores readability and makes each widget independently testable.

**Pros:** Smaller `main.dart`, easier navigation, widgets independently testable.

**Cons:** Cosmetic refactor only — no behavior change. Low urgency.

**Context:** Pure extraction, no logic changes. `_ResultsStep` → `ResultsStep` in
`lib/widgets/results_step.dart`. Import it back in `main.dart`.

**Priority:** P3 (cleanup, not blocking)

**Depends on / blocked by:** NWBrowser mDNS implementation (this PR).

---

## Speed test endpoint versioning

**What:** Add a lightweight smoke-test before the first speed test run — a HEAD request
to the Cloudflare endpoint to verify it's responding with 200. Cache the result for the
session. If it fails, show a more specific message ("Speed test endpoint unavailable")
rather than a generic "Test unavailable."

**Why:** `SpeedTestService` relies on undocumented Cloudflare/OVH URLs. Cloudflare could
change `/__down` without notice. Silent breakage shows "Test unavailable" to users — a
smoke-test would show "endpoint changed" in logs for faster diagnosis.

**Pros:** Faster diagnosis when endpoints break, better error messages for users.

**Cons:** One extra HTTP round-trip on first speed test. Low-probability failure mode.

**Context:** The HEAD request should be to `https://speed.cloudflare.com/__down?measId=0&bytes=0`.
If it returns 200, proceed. If not, log `SpeedTestService: endpoint smoke-test failed: {statusCode}`
and skip to fallback. OVH fallback has a stable URL contract (documented resource).

**Priority:** P2 (nice-to-have, not launch-blocking)

**Depends on / blocked by:** NWBrowser mDNS implementation (this PR).

---
