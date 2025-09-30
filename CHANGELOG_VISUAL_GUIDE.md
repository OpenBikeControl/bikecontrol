# Changelog Integration - Visual Guide

This document provides a visual walkthrough of the changelog integration features.

## Feature 1: Changelog Menu Item

The changelog can be accessed from the app menu:

```
[Menu Button (⋮)]
  ├── Donate ♥
  ├── [Debug options]
  ├── Changelog        ← NEW
  ├── Feedback
  └── License
```

When clicked, it opens the Changelog page.

## Feature 2: Changelog Page

The Changelog page displays all version history in a clean, scrollable list:

```
┌─────────────────────────────────────────┐
│ ← Changelog                             │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ Version 2.6.0        2025-09-28   │ │
│  │                                   │ │
│  │ • Fix crashes on some Android     │ │
│  │   devices                         │ │
│  │ • refactor touch placements: show │ │
│  │   touches on screen, fix misplaced│ │
│  │   coordinates - should fix #64    │ │
│  │ • show firmware version of        │ │
│  │   connected device                │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ Version 2.5.0        2025-09-25   │ │
│  │                                   │ │
│  │ • Improve usability               │ │
│  │ • SwiftControl is now available   │ │
│  │   via the Play Store              │ │
│  │ • SwiftControl will continue to   │ │
│  │   be available to download for    │ │
│  │   free on GitHub                  │ │
│  └───────────────────────────────────┘ │
│                                         │
│  [... more versions ...]               │
│                                         │
└─────────────────────────────────────────┘
```

## Feature 3: What's New Dialog

When the app is opened for the first time after an update, a dialog appears automatically:

```
      ┌─────────────────────────────┐
      │ What's New                  │
      │ Version 2.6.0               │
      ├─────────────────────────────┤
      │                             │
      │ • Fix crashes on some       │
      │   Android devices           │
      │                             │
      │ • refactor touch            │
      │   placements: show touches  │
      │   on screen, fix misplaced  │
      │   coordinates - should fix  │
      │   #64                       │
      │                             │
      │ • show firmware version of  │
      │   connected device          │
      │                             │
      ├─────────────────────────────┤
      │                  [Got it!]  │
      └─────────────────────────────┘
```

## Feature 4: Play Store Script

Developers can extract the latest changelog entry for Play Store uploads:

```bash
$ ./scripts/get_latest_changelog.sh
• Fix crashes on some Android devices
• refactor touch placements: show touches on screen, fix misplaced coordinates - should fix #64
• show firmware version of connected device
```

This output can be directly copied to the Play Store release notes.

## Implementation Flow

### On App Start:
```
1. App starts → RequirementsPage.initState()
2. settings.init() completes
3. _checkAndShowChangelog() is called
4. PackageInfo.fromPlatform() gets current version
5. settings.getLastSeenVersion() gets stored version
6. If versions differ → ChangelogDialog.showIfNeeded()
7. Dialog displays latest changelog entry
8. settings.setLastSeenVersion() updates stored version
```

### When User Opens Changelog:
```
1. User clicks Menu → Changelog
2. Navigator.push() → ChangelogPage
3. ChangelogParser.parse() loads CHANGELOG.md
4. Parser extracts all version entries
5. ListView displays entries in cards
```

### When Preparing Play Store Release:
```
1. Developer runs ./scripts/get_latest_changelog.sh
2. Script extracts text between first two ### headers
3. Script formats with bullet points
4. Developer copies output to Play Store console
```

## Data Storage

Version tracking uses SharedPreferences:
```
Key: 'last_seen_version'
Value: '2.6.0' (current app version)
```

This is compared with `PackageInfo.version` on each app start to detect updates.

## Changelog Format

The CHANGELOG.md file follows this format:
```markdown
### VERSION (DATE)
- Change description
- Another change
  - Sub-bullet point (indented with 2 spaces)
```

The parser extracts:
- Version number (e.g., "2.6.0")
- Date (e.g., "2025-09-28")
- All bullet points (both main and sub-bullets)
