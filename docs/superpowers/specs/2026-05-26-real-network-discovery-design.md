# Replace mock discovery with real desktop network discovery

**Issue:** [#1](https://github.com/bigwest60/streamsize/issues/1)
**Date:** 2026-05-26
**Status:** Approved

## Summary

Extend real mDNS network discovery to Windows and Linux desktop platforms. macOS already
has a working native Swift NWBrowser plugin; this design adds a pure-Dart mDNS fallback
for Windows and Linux while keeping the macOS path unchanged.

## Architecture

```
MDNSDiscoveryService
├── macOS: MethodChannel → Swift NWBrowser (unchanged)
└── Windows/Linux: DartMDNSDiscoveryService (new, multicast_dns package)

Both paths share the same _parseServiceName() classification logic.
```

## Changes

All changes are in `packages/platform_discovery/`. No changes to `main.dart` or the
client app wiring.

### 1. Add `multicast_dns` dependency

`packages/platform_discovery/pubspec.yaml` — add `multicast_dns: ^0.3.3`

### 2. Extract shared classification logic

Move `_parseServiceName` from `MDNSDiscoveryService` into a standalone function
in a new file `lib/src/device_classifier.dart`. Both `MDNSDiscoveryService`
(Swift results) and `DartMDNSDiscoveryService` (pure-Dart results) use it.

### 3. New `DartMDNSDiscoveryService`

File: `lib/src/dart_mdns_discovery_service.dart`

- Implements `DiscoveryService`
- Uses `multicast_dns` package to browse the same 5 Bonjour types:
  `_airplay._tcp`, `_googlecast._tcp`, `_hap._tcp`, `_raop._tcp`, `_smb._tcp`
- 5-second scan window (matching macOS behavior)
- Deduplicates results across service types
- TXT record inspection is not available in `multicast_dns`, so the NAS
  heuristic (model= key check) is unavailable. All `_smb` responders are
  classified as `laptop` with medium confidence (same as the existing safe
  default when model= is absent).

### 4. Modify `MDNSDiscoveryService`

- `isPlatformSupported` → `true` for macOS, Windows, Linux (was macOS-only)
- `discoverVisibleDevices()`:
  - On macOS: MethodChannel path (unchanged)
  - On Windows/Linux: delegate to `DartMDNSDiscoveryService`
- `DartMDNSDiscoveryService` is injectable via optional constructor param
  (testability — tests can provide a mock Dart service)
- Update tests to cover the platform branching

### 5. Tests

- Unit tests for `DartMDNSDiscoveryService` parsing (same structure as existing
  `mdns_discovery_service_test.dart`)
- Update existing `MDNSDiscoveryService` tests to cover the fallback path

## What stays unchanged

- `MockDiscoveryService` — test-only, unchanged
- Swift `StreamsizePlugin` — unchanged
- `main.dart` wiring — unchanged (already defaults to `MDNSDiscoveryService()`)
- `DiscoveryResult` / `DiscoveryService` interface — unchanged

## Non-goals

- No TXT record inspection (NAS heuristic) on Windows/Linux (library limitation)
- No persistence of scan results (deferred, see TODOS.md)
- No changes to the mock service or test infrastructure
