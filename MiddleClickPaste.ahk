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

; Check if window is a terminal (or terminal-like app)
IsTerminalWindow(WinClass, WinHwnd := 0) {
    if (WinClass = "CASCADIA_HOSTING_WINDOW_CLASS"      ; Windows Terminal
     || WinClass = "ConsoleWindowClass"                 ; cmd/PowerShell
     || WinClass = "mintty"                             ; Git Bash
     || WinClass = "VirtualConsoleClass")               ; ConEmu
        return true

    ; Check for VS Code specifically (not all Electron apps)
    if (WinClass = "Chrome_WidgetWin_1" && WinHwnd) {
        try {
            ProcName := ProcessGetName(WinGetPID(WinHwnd))
            if (ProcName = "Code.exe")
                return true
        }
    }
    return false
}

; On release, if mouse moved (drag select), copy to buffer (skip for terminals)
~LButton Up:: {
    global SelectionClip, StartX, StartY
    MouseGetPos &EndX, &EndY, &WinUnderMouse
    if (Abs(EndX - StartX) > 10 || Abs(EndY - StartY) > 10) {
        WinClass := WinGetClass(WinUnderMouse)

        ; Skip auto-copy for terminals - they'll copy on middle-click instead
        if IsTerminalWindow(WinClass, WinUnderMouse)
            return

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

    MouseGetPos ,, &WinUnderMouse
    WinClass := WinGetClass(WinUnderMouse)
    IsTerminal := IsTerminalWindow(WinClass, WinUnderMouse)

    if (A_Cursor = "IBeam" || IsTerminal) {
        OldClip := A_Clipboard

        ; For terminals: copy the selection now, then paste
        if IsTerminal {
            A_Clipboard := ""
            if (WinClass = "CASCADIA_HOSTING_WINDOW_CLASS")
                SendInput "^+c"
            else if (WinClass = "Chrome_WidgetWin_1")
                SendInput "^c"  ; VS Code uses standard Ctrl+C
            else
                SendInput "^{Insert}"

            if ClipWait(0.3) {
                SelectionClip := A_Clipboard
            }
        }

        if (SelectionClip = "") {
            A_Clipboard := OldClip
            return
        }

        WinActivate WinUnderMouse
        Sleep 30

        ; Click to focus (skip for terminals - they don't need it)
        if (!IsTerminal) {
            Click
            Sleep 30
        }

        ; Paste from buffer
        A_Clipboard := SelectionClip
        SendInput "^v"
        Sleep 50
        A_Clipboard := OldClip
    }
}

; F3 sends real middle-click if needed
F3:: SendInput "{MButton}"
