# MiddleClickPaste

Linux-style middle-click paste for Windows using AutoHotkey v2.

## Features

- **Selection Buffer**: Drag-select text to copy it to a separate buffer
- **Middle-Click Paste**: Paste selection with middle-click in text fields, terminals, or Office apps
- **Non-Destructive**: Regular clipboard remains unchanged

## Requirements

- [AutoHotkey v2.0](https://www.autohotkey.com/)

## Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Double-click `MiddleClickPaste.ahk` to run

**Run on Startup**: Press `Win + R`, type `shell:startup`, copy the script there.

## Usage

1. Drag-select text with left mouse button
2. Middle-click to paste

Works when cursor is over:
- Text input fields (I-beam cursor)
- Supported terminals
- Office apps

## Supported Applications

**Terminals**: Windows Terminal, cmd, PowerShell, Git Bash, ConEmu, VS Code

**Office**: Word, Excel, Outlook, PowerPoint

## Keybindings

| Key | Action |
|-----|--------|
| Middle-Click | Paste selection buffer |
| F3 | Send real middle-click |

## License

MIT
