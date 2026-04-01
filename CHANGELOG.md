# Changelog

All notable changes to Streamsize are documented here.

## [0.1.0.0] - 2026-04-01

### Added
- **mDNS device discovery** — uses NWBrowser (replacing deprecated NetServiceBrowser) to scan the local network for Apple TVs, Chromecasts, AirPlay speakers, HomeKit accessories, SMB shares, and NAS devices
- **NAS device support** — new `DeviceCategory.nas` type; NAS devices add +10 Mbps download and +5 Mbps upload to the recommendation
- **Manual device add** — bottom sheet lets users add a device by category when mDNS can't see it (smart TVs, consoles, tablets, etc.)
- **Confidence badge** — recommendation result shows a scored confidence badge (High/Medium/Low) based on how many devices were detected
- **Speed test** — one-tap speed test on the results screen so users can compare their current plan against the recommendation
- **Shareable results** — share button on results screen lets users send their recommendation summary via any system share target
- **Empty state** — devices step shows a friendly empty state with a manual-add prompt when no devices are found
- **Streamsize guide tooltip** — badge on results screen explains the recommendation confidence model

### Changed
- Color palette unified to warm terracotta (`#E07A5F`) — removed violet `#7C5CFC` that was leaking into step bubbles and progress bar
- Border radius normalized to a consistent tier scale (16/24/28/36/999)
- "Done" button on final step relabeled to "Start over" and now correctly resets the flow

### Fixed
- Overflow crash on results screen — `_ResultNarrativeCard` title row now wraps with `Expanded`
- `MissingPluginException` on launch — `StreamsizePlugin.swift` wired into `MainFlutterWindow.swift`
- mDNS callbacks stabilized — `DispatchGroup.leave()` only called from the 5-second `asyncAfter` guard, never from `browseResultsChangedHandler`
