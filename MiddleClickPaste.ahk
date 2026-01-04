#Requires AutoHotkey v2.0
#SingleInstance Force

SelectionClip := ""
StartX := 0
StartY := 0

; Track where mouse drag starts
~LButton:: {
    global StartX, StartY
    MouseGetPos &StartX, &StartY
}

; On release, if mouse moved (drag select), copy to buffer
~LButton Up:: {
    global SelectionClip, StartX, StartY
    MouseGetPos &EndX, &EndY
    if (Abs(EndX - StartX) > 10 || Abs(EndY - StartY) > 10) {
        Sleep 50
        OldClip := A_Clipboard
        A_Clipboard := ""
        SendInput "^c"
        if ClipWait(0.3) {
            SelectionClip := A_Clipboard
        }
        A_Clipboard := OldClip
    }
}

; Middle-click: paste only if cursor is over a text field or terminal
~MButton:: {
    global SelectionClip
    if (SelectionClip = "")
        return

    MouseGetPos ,, &WinUnderMouse
    WinClass := WinGetClass(WinUnderMouse)

    ; Check if over text field (I-beam) or terminal window
    IsTerminal := (WinClass = "CASCADIA_HOSTING_WINDOW_CLASS"  ; Windows Terminal
                || WinClass = "ConsoleWindowClass"             ; cmd/PowerShell
                || WinClass = "mintty"                         ; Git Bash
                || WinClass = "VirtualConsoleClass")           ; ConEmu

    if (A_Cursor = "IBeam" || IsTerminal) {
        WinActivate WinUnderMouse
        Sleep 30

        ; Click to focus (skip for terminals - they don't need it)
        if (!IsTerminal) {
            Click
            Sleep 30
        }

        ; Paste from buffer
        OldClip := A_Clipboard
        A_Clipboard := SelectionClip
        SendInput "^v"
        Sleep 50
        A_Clipboard := OldClip
    }
}

; F3 sends real middle-click if needed
F3:: SendInput "{MButton}"
