# CountBar

A minimalist tally counter that lives in your macOS menu bar. Click to count, right-click to manage. Track multiple counters with daily reset schedules, set goals, and view your history in a built-in dashboard.

Inspired by [Countly](https://apps.apple.com/hk/app/countly-tally-count-on-menu/id6529533104) — built as a free, open-source alternative.

## Features

- **One-click counting** — left-click the menu bar icon to increment the active counter
- **Multiple counters** — track pushups, water, tasks, anything; switch which one shows in the menu bar
- **Daily goals** — set a target per counter; the menu bar ring changes color as you progress (red → orange → yellow → blue → green)
- **Auto-reset** — configure a daily reset time per counter, or set them to never reset
- **Dashboard** — last 7/30/all-time totals, daily averages, current and longest streaks, goal hit rate, 30-day chart, 12-week activity heatmap
- **Adapts to your theme** — dark/light mode, follows your accent color
- **Privacy-first** — all data stored locally; nothing leaves your machine

## Screenshots

_(Add screenshots of the menu bar icon, popover, and dashboard here)_

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ to build from source

## Installation

### From source (only option for now)

1. Clone the repo:
```
   git clone https://github.com/yourusername/countbar.git
   cd countbar
```
2. Open `CountBar.xcodeproj` in Xcode
3. Build and run (⌘R)

### Pre-built releases

Coming soon. Watch the [Releases](https://github.com/yourusername/countbar/releases) page.

## Usage

- **Left-click** the menu bar icon → increment the active counter
- **Right-click** the menu bar icon → open the popover
- In the popover: add counters, edit names (double-click), set goals, set reset schedules, switch active counter
- **⌘D** in the popover → open the dashboard

## Roadmap

- [ ] Notarized DMG releases
- [ ] Homebrew Cask
- [ ] Optional iCloud sync
- [ ] Per-counter SF Symbol picker
- [ ] Global hotkey for increment

## Tech

- SwiftUI + AppKit (`NSStatusItem` for menu bar, `MenuBarExtra` was too restrictive for the click-handling we wanted)
- SwiftData for persistence
- Swift Charts for the dashboard

## Contributing

Issues and PRs welcome. For larger features, open an issue first to discuss.

## License

MIT — see [LICENSE](LICENSE).