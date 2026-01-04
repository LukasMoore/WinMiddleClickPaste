# MiddleClickPaste

A Windows utility that brings Linux-style middle-click paste functionality to Windows using AutoHotkey v2.

## Features

- **Selection Buffer**: Automatically copies text when you drag-select with the left mouse button
- **Middle-Click Paste**: Pastes the selected text with middle-click (only in text fields and terminals)
- **Non-Destructive**: Preserves your regular clipboard contents
- **Terminal Support**: Works with Windows Terminal, cmd, PowerShell, Git Bash, and ConEmu

## Requirements

- [AutoHotkey v2.0](https://www.autohotkey.com/)

## Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Double-click `MiddleClickPaste.ahk` to run

## Run on Startup

1. Press `Win + R`, type `shell:startup`, and press Enter
2. Copy `MiddleClickPaste.ahk` into the Startup folder

## Usage

1. **Select text**: Drag to select text with the left mouse button
2. **Paste**: Middle-click in any text field or terminal to paste the selection

The script only pastes when:
- The cursor is over a text input field (I-beam cursor), or
- The cursor is over a supported terminal window

## Keybindings

| Key | Action |
|-----|--------|
| Middle-Click | Paste selection buffer |
| F3 | Send a real middle-click (bypasses paste behavior) |

## Supported Terminals

- Windows Terminal
- cmd / PowerShell console
- Git Bash (mintty)
- ConEmu

## License

[MIT](LICENSE) - Do whatever you want with this.
