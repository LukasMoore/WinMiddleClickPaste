# MiddleClickPaste

Linux-style middle-click paste for Windows using AutoHotkey v2.

## Features

- **Selection Buffer**: Drag-select text to automatically copy it to a separate buffer
- **Middle-Click Paste**: Paste selection with middle-click in text fields, terminals, or Office apps
- **Clipboard Preservation**: Full clipboard state preserved (text, images, RTF, and all formats)
- **Terminal Support**: Uses correct copy/paste shortcuts for each terminal type

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

## Supported Applications

**Terminals**: Windows Terminal, cmd, PowerShell, Git Bash (mintty), ConEmu, VS Code (integrated terminal)

**Office**: Word, Excel, Outlook, PowerPoint

## Keybindings

| Key | Action |
|-----|--------|
| Middle-Click | Paste from selection buffer |
| F3 | Send native middle-click (for scrolling, etc.) |

## How It Works

- Standard apps: Text is copied immediately on drag-select using Ctrl+C
- Terminals: Selection is tracked, copied on paste using Ctrl+Shift+C (or Ctrl+Insert for legacy terminals)
- Paste uses Ctrl+V (or Ctrl+Shift+V for terminals)

## License

MIT
