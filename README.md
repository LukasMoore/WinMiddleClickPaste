# MiddleClickPaste

Linux-style middle-click paste for Windows using AutoHotkey v2.

## Features

- **Selection Buffer**: Drag-select text to automatically copy it to a separate buffer
- **Middle-Click Paste**: Paste selection with middle-click in text fields, terminals, or Office apps
- **Clipboard Preservation**: Full clipboard state preserved (text, images, RTF, and all formats)
- **Terminal Support**: Uses correct copy/paste shortcuts for each terminal type
- **UWP App Support**: Works with Windows Store apps (WhatsApp, etc.)
- **Electron App Support**: Works with Teams, Slack, Discord, Chrome, Edge, Firefox
- **Multi-Monitor Support**: Works correctly across multiple monitors

## Requirements

- [AutoHotkey v2.0](https://www.autohotkey.com/)

## Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Double-click `MiddleClickPaste.ahk` to run

**Run on Startup**: Press `Win+R`, type `shell:startup`, copy the script there.

## Usage

1. Drag-select text with left mouse button
2. Middle-click to paste

Works when cursor is over:
- Text input fields (I-beam cursor)
- Supported terminals
- Office apps
- UWP apps (WhatsApp, etc.)
- Electron apps (Teams, Slack, browsers)

## Supported Applications

**Terminals**: Windows Terminal, cmd, PowerShell, Git Bash (mintty), ConEmu, VS Code (integrated terminal)

**Office**: Word, Excel, Outlook, PowerPoint

**UWP Apps**: WhatsApp, and other Windows Store apps

**Electron Apps**: Microsoft Teams, Slack, Discord, Chrome, Edge, Firefox

## Keybindings

| Key | Action |
|-----|--------|
| Middle-Click | Paste from selection buffer |
| F3 | Pause/unpause script |
| F4 | Toggle debug logging |

## How It Works

- **Standard apps**: Text is copied immediately on drag-select using Ctrl+C
- **Terminals**: Uses Ctrl+Shift+C (or Ctrl+Insert for legacy terminals)
- **UWP/Electron apps**: Uses SendEvent with timing delays for reliability
- **Paste**: Uses Ctrl+V (or Ctrl+Shift+V for terminals)

## Troubleshooting

If paste isn't working in an app:
1. Press F4 to enable debug logging
2. Try the paste operation
3. Open `debug.log` in the script directory
4. Check what window class/process is detected

Common issues:
- **UWP apps**: Handled automatically via `WinUIDesktopWin32WindowClass` detection
- **Electron apps**: Detected by process name (Teams.exe, slack.exe, etc.)

## License

MIT
