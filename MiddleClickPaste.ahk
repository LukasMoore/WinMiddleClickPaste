#Requires AutoHotkey v2.0
#SingleInstance Force

; === Coordinate Mode ===
; CRITICAL: Use screen coordinates for all mouse operations
; MouseGetPos returns coords relative to active window by default,
; but we click on windows that may not be active yet, causing misalignment
CoordMode "Mouse", "Screen"

; === Debug Mode ===
global DebugMode := false  ; F4 to toggle, F5 to clear, F6 to open log
global DebugLogFile := A_ScriptDir "\debug.log"

DebugMsg(msg) {
    global DebugMode, DebugLogFile
    if (!DebugMode)
        return

    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss.") SubStr(A_TickCount, -3)
    line := timestamp " | " msg "`n"

    try {
        FileAppend line, DebugLogFile
    } catch {
        ; File write failed - ignore
    }
}

DebugClear() {
    global DebugLogFile
    try {
        FileDelete DebugLogFile
    } catch {
        ; File doesn't exist or can't delete - ignore
    }
    DebugMsg("=== LOG CLEARED ===")
}

; F4 to toggle debug mode
F4:: {
    global DebugMode, DebugLogFile
    DebugMode := !DebugMode
    if (DebugMode) {
        DebugMsg("=== DEBUG MODE ON ===")
        ToolTip "Debug ON: " DebugLogFile, 10, 10
        SetTimer () => ToolTip(), -2000
    } else {
        ToolTip "Debug OFF", 10, 10
        SetTimer () => ToolTip(), -2000
    }
}

; F5 to clear debug log
F5:: {
    DebugClear()
    ToolTip "Log cleared", 10, 10
    SetTimer () => ToolTip(), -2000
}

; F6 to open log file
F6:: {
    global DebugLogFile
    if FileExist(DebugLogFile)
        Run DebugLogFile
    else {
        ToolTip "No log file yet", 10, 10
        SetTimer () => ToolTip(), -2000
    }
}

GetProcessName(WinHwnd) {
    try {
        return ProcessGetName(WinGetPID(WinHwnd))
    } catch {
        return "unknown"
    }
}

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
    StartY: 0,
    HadTextCursor: false  ; Track if cursor was text-type during drag
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

; Check if cursor indicates text selection context
; IBeam = standard text cursor
IsTextSelectionCursor(cursor) {
    return (cursor = "IBeam")
}

; Check if cursor could indicate text in browser-like apps
; Browsers/Electron apps use hand cursors that show as "Unknown" but can still select text
IsTextSelectionCursorBroad(cursor) {
    return (cursor = "IBeam" || cursor = "Unknown")
}

; Electron apps that support text selection but may not show IBeam cursor
; These use Chrome_WidgetWin_1 class but aren't terminals
ElectronTextApps := Map(
    "ms-teams.exe", true,       ; New Microsoft Teams
    "Teams.exe", true,          ; Old Microsoft Teams
    "slack.exe", true,          ; Slack
    "discord.exe", true,        ; Discord
    "chrome.exe", true,         ; Chrome browser
    "msedge.exe", true,         ; Edge browser
    "firefox.exe", true         ; Firefox browser
)

IsElectronTextApp(WinHwnd) {
    global ElectronTextApps
    try {
        WinClass := WinGetClass(WinHwnd)
        if (WinClass != "Chrome_WidgetWin_1" && WinClass != "MozillaWindowClass")
            return false
        ProcName := ProcessGetName(WinGetPID(WinHwnd))
        return ElectronTextApps.Has(ProcName)
    } catch {
        return false
    }
}

; Check if window is Microsoft Teams
IsTeamsApp(WinHwnd) {
    try {
        WinClass := WinGetClass(WinHwnd)
        if (WinClass != "Chrome_WidgetWin_1")
            return false
        ProcName := ProcessGetName(WinGetPID(WinHwnd))
        return (ProcName = "ms-teams.exe" || ProcName = "Teams.exe")
    } catch {
        return false
    }
}

; Check if window is a UWP app that needs direct paste (no click)
; These apps don't handle the extra left-click well
IsDirectPasteApp(WinHwnd) {
    try {
        WinClass := WinGetClass(WinHwnd)
        ProcName := ProcessGetName(WinGetPID(WinHwnd))

        ; UWP apps use WinUIDesktopWin32WindowClass
        if (WinClass = "WinUIDesktopWin32WindowClass")
            return true

        ; Also check specific processes
        directPasteApps := Map(
            "WhatsApp.exe", true,
            "WhatsApp.Root.exe", true,
            "ms-teams.exe", true,
            "Teams.exe", true
        )
        return directPasteApps.Has(ProcName)
    } catch {
        return false
    }
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
    DebugMsg("COPY: Starting, shortcut=" shortcut " wait=" waitTime)
    clipBackup := GetClipboardBackup()
    A_Clipboard := ""  ; Must be empty for ClipWait detection to work

    ; Small delay to ensure clipboard is ready to receive
    Sleep 10

    ; Use SendEvent for better compatibility with slow applications
    ; SendInput is faster but some apps can't keep up
    ; SetKeyDelay adds small delays between key down/up for reliability
    SetKeyDelay 10, 10
    DebugMsg("COPY: Sending " shortcut " via SendEvent")
    SendEvent shortcut

    ; Wait for clipboard to contain text (not just any data)
    DebugMsg("COPY: Waiting for clipboard...")
    if ClipWait(waitTime, 0) {  ; 0 = wait for text specifically
        result := A_Clipboard
        resultLen := StrLen(result)
        DebugMsg("COPY: Got " resultLen " chars")
        if (result != "") {
            RestoreClipboard(clipBackup)
            clipBackup := ""  ; Free memory per docs
            DebugMsg("COPY: SUCCESS - '" SubStr(result, 1, 30) (resultLen > 30 ? "..." : "") "'")
            return result
        }
    }

    DebugMsg("COPY: FAILED - ClipWait timeout or empty")
    RestoreClipboard(clipBackup)
    clipBackup := ""  ; Free memory per docs
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
PasteToWindow(text, WinClass, IsTerminal, IsElectronApp := false) {
    DebugMsg("PASTE: Starting, class=" WinClass " term=" IsTerminal " electron=" IsElectronApp)
    if (text = "") {
        DebugMsg("PASTE: FAILED - empty text")
        return false
    }

    clipBackup := GetClipboardBackup()
    A_Clipboard := text
    DebugMsg("PASTE: Clipboard set, " StrLen(text) " chars")

    ; Small delay to ensure clipboard is set before paste
    Sleep 10

    ; Use appropriate paste shortcut and method
    if (WinClass = "CASCADIA_HOSTING_WINDOW_CLASS" || (WinClass = "Chrome_WidgetWin_1" && IsTerminal)) {
        DebugMsg("PASTE: Sending ^+v (terminal)")
        SendInput "^+v"
    } else if (IsElectronApp) {
        ; Electron apps (Teams, Slack, browsers) need SendEvent for reliability
        DebugMsg("PASTE: Sending ^v via SendEvent (electron)")
        SetKeyDelay 10, 10
        SendEvent "^v"
    } else {
        DebugMsg("PASTE: Sending ^v via SendInput (standard)")
        SendInput "^v"
    }

    Sleep Config.PostActionDelay
    RestoreClipboard(clipBackup)
    clipBackup := ""  ; Free memory per docs
    DebugMsg("PASTE: Complete")
    return true
}

; === Hotkeys ===

; Track drag start position and initial cursor state
~LButton:: {
    global State
    MouseGetPos &x, &y, &win
    State.StartX := x
    State.StartY := y
    State.HadTextCursor := IsTextSelectionCursor(A_Cursor)

    DebugMsg("LBTN DOWN: pos=" x "," y " cursor=" A_Cursor " ibeam=" State.HadTextCursor)

    ; Monitor cursor during drag to catch text selection
    SetTimer(MonitorDragCursor, 50)
}

; Monitor cursor type during drag
MonitorDragCursor() {
    global State
    if !GetKeyState("LButton", "P") {
        SetTimer(MonitorDragCursor, 0)  ; Stop monitoring when button released
        return
    }
    ; If cursor becomes text-type during drag, record it
    if IsTextSelectionCursor(A_Cursor)
        State.HadTextCursor := true
}

; On drag release, capture selection
~LButton Up:: {
    global State, Config

    ; Stop the cursor monitor
    SetTimer(MonitorDragCursor, 0)

    MouseGetPos &EndX, &EndY, &WinUnderMouse
    procName := GetProcessName(WinUnderMouse)

    dragX := Abs(EndX - State.StartX)
    dragY := Abs(EndY - State.StartY)
    DebugMsg("LBTN UP: pos=" EndX "," EndY " drag=" dragX "," dragY " cursor=" A_Cursor)

    ; Check if this was a drag (not just a click)
    if (dragX <= Config.DragThreshold && dragY <= Config.DragThreshold) {
        DebugMsg("LBTN UP: Not a drag, ignoring")
        return
    }

    WinClass := SafeGetClass(WinUnderMouse)
    DebugMsg("LBTN UP: class=" WinClass " proc=" procName)
    if (WinClass = "") {
        DebugMsg("LBTN UP: No window class, ignoring")
        return
    }

    ; Check if this is an Electron/browser app (Teams, Slack, Chrome, etc.)
    ; These apps may not show IBeam cursor but still support text selection
    IsElectronApp := IsElectronTextApp(WinUnderMouse)
    DebugMsg("LBTN UP: HadTextCursor=" State.HadTextCursor " IsElectron=" IsElectronApp)

    ; Only attempt copy if:
    ; 1. Cursor was IBeam at any point during drag, OR
    ; 2. This is a known Electron app (cursor detection unreliable)
    if (!State.HadTextCursor && !IsElectronApp) {
        DebugMsg("LBTN UP: No text cursor and not Electron, SKIP copy")
        return
    }

    ; Give the application time to register the selection
    DebugMsg("LBTN UP: Waiting 100ms for selection...")
    Sleep 100

    ; Use appropriate copy shortcut based on window type
    IsTerminal := IsTerminalWindow(WinClass, WinUnderMouse)
    copyShortcut := GetCopyShortcut(WinClass, IsTerminal)
    waitTime := IsTerminal ? Config.TerminalCopyWait : Config.CopyWaitTime
    DebugMsg("LBTN UP: Copying with " copyShortcut " (terminal=" IsTerminal ")")

    copied := CopySelection(copyShortcut, waitTime)
    if (copied != "") {
        State.SelectionClip := copied
        DebugMsg("LBTN UP: Stored " StrLen(copied) " chars in SelectionClip")
    } else {
        DebugMsg("LBTN UP: Copy returned empty")
    }
}

; Middle-click paste (only in text-accepting contexts)
~MButton:: {
    global State

    MouseGetPos &MouseX, &MouseY, &WinUnderMouse
    WinClass := SafeGetClass(WinUnderMouse)
    procName := GetProcessName(WinUnderMouse)

    DebugMsg("===== MBUTTON CLICK =====")
    DebugMsg("MBTN: pos=" MouseX "," MouseY)
    DebugMsg("MBTN: cursor=" A_Cursor " class=" WinClass)
    DebugMsg("MBTN: process=" procName)

    if (WinClass = "") {
        DebugMsg("MBTN: No window class, ABORT")
        return
    }

    IsTerminal := IsTerminalWindow(WinClass, WinUnderMouse)
    IsOffice := IsOfficeApp(WinClass)
    IsElectronApp := IsElectronTextApp(WinUnderMouse)
    IsTeams := IsTeamsApp(WinUnderMouse)

    DebugMsg("MBTN: IsTerminal=" IsTerminal " IsOffice=" IsOffice)
    DebugMsg("MBTN: IsElectron=" IsElectronApp " IsTeams=" IsTeams)

    ; Only paste if cursor indicates text input, or in known app types
    ; IBeam = standard text input areas
    ; Electron apps (Teams, Slack, browsers) may not show IBeam in text fields
    canPaste := (A_Cursor = "IBeam" || IsTerminal || IsOffice || IsElectronApp)
    DebugMsg("MBTN: canPaste=" canPaste " (IBeam=" (A_Cursor = "IBeam") ")")

    if !canPaste {
        DebugMsg("MBTN: Not a paste context, ABORT")
        return
    }

    ; Nothing to paste
    clipLen := StrLen(State.SelectionClip)
    DebugMsg("MBTN: SelectionClip has " clipLen " chars")
    if (State.SelectionClip = "") {
        DebugMsg("MBTN: Nothing to paste, ABORT")
        return
    }

    ; UWP apps (Teams, WhatsApp) and special apps: direct Ctrl+V, no click
    ; These apps don't handle extra clicks well
    IsDirectPaste := IsDirectPasteApp(WinUnderMouse)
    DebugMsg("MBTN: IsDirectPaste=" IsDirectPaste)

    if (IsTeams || IsDirectPaste) {
        DebugMsg("MBTN: DIRECT PASTE PATH (Teams/UWP)")

        ; Backup and set clipboard
        clipBackup := GetClipboardBackup()
        A_Clipboard := State.SelectionClip
        DebugMsg("MBTN: Clipboard set to " StrLen(State.SelectionClip) " chars")

        ; Verify clipboard was set
        Sleep 50
        clipCheck := A_Clipboard
        DebugMsg("MBTN: Clipboard verify: " StrLen(clipCheck) " chars")

        ; Try SendEvent with key delay (more reliable than SendInput for some apps)
        DebugMsg("MBTN: Sending ^v via SendEvent")
        SetKeyDelay 50, 50
        SendEvent "^v"

        ; IMPORTANT: Wait longer before restoring - app needs time to read clipboard
        DebugMsg("MBTN: Waiting 500ms for paste to complete...")
        Sleep 500

        RestoreClipboard(clipBackup)
        DebugMsg("MBTN: Direct paste complete")
        return
    }

    ; Electron apps: just paste directly
    ; Middle-click should have already focused the text field
    ; Don't click - it can trigger unintended behavior (minimize, etc.)
    if (IsElectronApp) {
        DebugMsg("MBTN: ELECTRON PATH - PasteToWindow")
        Sleep 100  ; Wait for middle-click to be fully processed
        PasteToWindow(State.SelectionClip, WinClass, false, true)
        return
    }

    ; Activate target window
    DebugMsg("MBTN: STANDARD PATH - activating window")
    if !SafeWinActivate(WinUnderMouse) {
        DebugMsg("MBTN: WinActivate FAILED, ABORT")
        return
    }
    DebugMsg("MBTN: Window activated")

    ; For standard apps (not terminal/Office), click to place cursor
    if (!IsTerminal && !IsOffice) {
        DebugMsg("MBTN: Clicking at " MouseX "," MouseY)
        Click MouseX, MouseY
        Sleep Config.PostActionDelay
    }

    PasteToWindow(State.SelectionClip, WinClass, IsTerminal, false)
    DebugMsg("MBTN: Complete")
}

; Fallback: F3 sends native middle-click (for scroll wheel, etc.)
F3::SendInput "{MButton}"
