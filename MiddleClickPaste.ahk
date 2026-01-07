#Requires AutoHotkey v2.0
#SingleInstance Force

; === Configuration ===
global Config := {
    DragThreshold: 10,          ; Minimum pixels to consider a drag selection
    CopyWaitTime: 0.3,          ; Seconds to wait for clipboard after copy
    TerminalCopyWait: 0.5,      ; Seconds to wait for terminal copy
    ActivateWait: 0.5,          ; Seconds to wait for window activation
    PostActionDelay: 50         ; Milliseconds delay after actions
}

; === State ===
global State := {
    SelectionClip: "",
    StartX: 0,
    StartY: 0
}

; === Window Classification ===

; Office apps that support text input
OfficeClasses := Map(
    "OpusApp", true,            ; Word
    "XLMAIN", true,             ; Excel
    "rctrl_renwnd32", true,     ; Outlook
    "PPTFrameClass", true       ; PowerPoint
)

; Terminal window classes
TerminalClasses := Map(
    "CASCADIA_HOSTING_WINDOW_CLASS", true,  ; Windows Terminal
    "ConsoleWindowClass", true,              ; cmd/PowerShell
    "mintty", true,                          ; Git Bash
    "VirtualConsoleClass", true              ; ConEmu
)

IsOfficeApp(WinClass) {
    global OfficeClasses
    return OfficeClasses.Has(WinClass)
}

IsTerminalWindow(WinClass, WinHwnd := 0) {
    global TerminalClasses
    if TerminalClasses.Has(WinClass)
        return true

    ; Check for VS Code (Electron app with specific process)
    if (WinClass = "Chrome_WidgetWin_1" && WinHwnd) {
        try {
            ProcName := ProcessGetName(WinGetPID(WinHwnd))
            return (ProcName = "Code.exe")
        } catch {
            return false
        }
    }
    return false
}

; === Safe Window Operations ===

SafeGetClass(WinHwnd) {
    try {
        return WinGetClass(WinHwnd)
    } catch {
        return ""
    }
}

SafeWinActivate(WinHwnd) {
    try {
        if !WinExist(WinHwnd)
            return false
        WinActivate(WinHwnd)
        return WinWaitActive(WinHwnd,, Config.ActivateWait)
    } catch {
        return false
    }
}

; === Clipboard Operations ===

; Preserve full clipboard state (including formats like images, RTF)
GetClipboardBackup() {
    try {
        return ClipboardAll()
    } catch {
        return ""
    }
}

RestoreClipboard(backup) {
    try {
        if (backup != "")
            A_Clipboard := backup
    } catch {
        ; Clipboard restore failed - not critical
    }
}

; Copy text from current selection using specified shortcut
CopySelection(shortcut := "^c", waitTime := 0.3) {
    clipBackup := GetClipboardBackup()
    A_Clipboard := ""

    SendInput shortcut

    if ClipWait(waitTime) {
        result := A_Clipboard
        RestoreClipboard(clipBackup)
        return result
    }

    RestoreClipboard(clipBackup)
    return ""
}

; Get the appropriate copy shortcut for a window
GetCopyShortcut(WinClass, IsTerminal) {
    if (!IsTerminal)
        return "^c"
    ; Modern terminals (Windows Terminal, VS Code) use Ctrl+Shift+C
    if (WinClass = "CASCADIA_HOSTING_WINDOW_CLASS" || WinClass = "Chrome_WidgetWin_1")
        return "^+c"
    ; Legacy terminals (cmd, ConEmu, mintty) use Ctrl+Insert
    return "^{Insert}"
}

; Paste text to current window
PasteToWindow(text, WinClass, IsTerminal) {
    if (text = "")
        return false

    clipBackup := GetClipboardBackup()
    A_Clipboard := text

    ; Use appropriate paste shortcut
    if (WinClass = "CASCADIA_HOSTING_WINDOW_CLASS" || (WinClass = "Chrome_WidgetWin_1" && IsTerminal))
        SendInput "^+v"
    else
        SendInput "^v"

    Sleep Config.PostActionDelay
    RestoreClipboard(clipBackup)
    return true
}

; === Hotkeys ===

; Track drag start position
~LButton:: {
    global State
    MouseGetPos &x, &y
    State.StartX := x
    State.StartY := y
}

; On drag release, capture selection
~LButton Up:: {
    global State, Config

    MouseGetPos &EndX, &EndY, &WinUnderMouse

    ; Check if this was a drag (not just a click)
    if (Abs(EndX - State.StartX) <= Config.DragThreshold
        && Abs(EndY - State.StartY) <= Config.DragThreshold)
        return

    ; Only attempt copy if cursor indicates text selection context
    if (A_Cursor != "IBeam")
        return

    WinClass := SafeGetClass(WinUnderMouse)
    if (WinClass = "")
        return

    ; Brief delay for selection to complete
    Sleep Config.PostActionDelay

    ; Use appropriate copy shortcut based on window type
    IsTerminal := IsTerminalWindow(WinClass, WinUnderMouse)
    copyShortcut := GetCopyShortcut(WinClass, IsTerminal)
    waitTime := IsTerminal ? Config.TerminalCopyWait : Config.CopyWaitTime

    copied := CopySelection(copyShortcut, waitTime)
    if (copied != "")
        State.SelectionClip := copied
}

; Middle-click paste (only in text-accepting contexts)
~MButton:: {
    global State

    MouseGetPos &MouseX, &MouseY, &WinUnderMouse
    WinClass := SafeGetClass(WinUnderMouse)
    if (WinClass = "")
        return

    IsTerminal := IsTerminalWindow(WinClass, WinUnderMouse)
    IsOffice := IsOfficeApp(WinClass)

    ; Only paste if cursor indicates text input, or in terminal/Office
    if !(A_Cursor = "IBeam" || IsTerminal || IsOffice)
        return

    ; Nothing to paste
    if (State.SelectionClip = "")
        return

    ; Activate target window
    if !SafeWinActivate(WinUnderMouse)
        return

    ; For standard apps (not terminal/Office), click to place cursor
    if (!IsTerminal && !IsOffice) {
        Click MouseX, MouseY
        Sleep Config.PostActionDelay
    }

    PasteToWindow(State.SelectionClip, WinClass, IsTerminal)
}

; Fallback: F3 sends native middle-click (for scroll wheel, etc.)
F3::SendInput "{MButton}"
