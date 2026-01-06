#Requires AutoHotkey v2.0
#SingleInstance Force

SelectionClip := ""
StartX := 0
StartY := 0
SourceWinHwnd := 0  ; Track which window the selection was made in
TerminalSelectionHwnd := 0  ; Track terminal with pending selection (persists across clicks)

; Track where mouse drag starts
~LButton:: {
    global StartX, StartY, SourceWinHwnd
    MouseGetPos &StartX, &StartY, &SourceWinHwnd
}

; Check if window is an Office app (Word, Excel, Outlook, PowerPoint)
IsOfficeApp(WinClass) {
    return (WinClass = "OpusApp"           ; Word
         || WinClass = "XLMAIN"            ; Excel
         || WinClass = "rctrl_renwnd32"    ; Outlook
         || WinClass = "PPTFrameClass")    ; PowerPoint
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
        if IsTerminalWindow(WinClass, WinUnderMouse) {
            global TerminalSelectionHwnd
            TerminalSelectionHwnd := WinUnderMouse  ; Remember this terminal has a pending selection
            return
        }

        ; Clear terminal selection when selecting in non-terminal
        global TerminalSelectionHwnd
        TerminalSelectionHwnd := 0

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

; Copy from a terminal window and return the copied text
CopyFromTerminal(WinHwnd) {
    WinClass := WinGetClass(WinHwnd)
    OldClip := A_Clipboard
    A_Clipboard := ""

    WinActivate WinHwnd
    if !WinWaitActive(WinHwnd,, 0.5)
        return ""
    Sleep 50

    if (WinClass = "CASCADIA_HOSTING_WINDOW_CLASS")
        SendInput "^+c"
    else if (WinClass = "Chrome_WidgetWin_1")
        SendInput "^+c"  ; VS Code terminal uses Ctrl+Shift+C
    else
        SendInput "^{Insert}"

    result := ""
    if ClipWait(0.5) {
        result := A_Clipboard
    }
    A_Clipboard := OldClip
    return result
}

; Middle-click: paste only if cursor is over a text field or terminal
~MButton:: {
    global SelectionClip

    MouseGetPos ,, &WinUnderMouse
    WinClass := WinGetClass(WinUnderMouse)
    IsTerminal := IsTerminalWindow(WinClass, WinUnderMouse)
    IsOffice := IsOfficeApp(WinClass)

    if (A_Cursor = "IBeam" || IsTerminal || IsOffice) {
        OldClip := A_Clipboard

        ; Check if selection was made in a terminal (need to copy from there first)
        global TerminalSelectionHwnd
        if (TerminalSelectionHwnd && WinExist(TerminalSelectionHwnd)) {
            copied := CopyFromTerminal(TerminalSelectionHwnd)
            if (copied != "") {
                SelectionClip := copied
                TerminalSelectionHwnd := 0  ; Clear after copying
            }
        }

        if (SelectionClip = "") {
            A_Clipboard := OldClip
            return
        }

        WinActivate WinUnderMouse
        Sleep 30

        ; Click to focus (skip for terminals and Office - they don't need it)
        if (!IsTerminal && !IsOffice) {
            Click
            Sleep 30
        }

        ; Paste from buffer
        A_Clipboard := SelectionClip
        if (WinClass = "CASCADIA_HOSTING_WINDOW_CLASS" || (WinClass = "Chrome_WidgetWin_1" && IsTerminal))
            SendInput "^+v"  ; Windows Terminal and VS Code terminal use Ctrl+Shift+V
        else
            SendInput "^v"
        Sleep 50
        A_Clipboard := OldClip
    }
}

; F3 sends real middle-click if needed
F3:: SendInput "{MButton}"
