OVERLAY_HEIGHT_PERCENT :: 70;
OVERLAY_OPACITY: u8 : 220;
GAME_TITLE :: "Order of the Sinking Star";
GAME_EXECUTABLE :: "sinking_star.exe";

Overlay_State :: struct {
    window: Win.HWND;
    game: Win.HWND;
    previous_focus: Win.HWND;
    bounds: Win.RECT;
    visible := false;
    toggle_requested := false;
    show_requested := false;
    quit_requested := false;
    game_hotkey_registered := false;
    global_hotkey_registered := false;
    colon_hotkey_registered := false;
}

overlay: Overlay_State;

overlay_create :: () -> bool {
    instance := Win.GetModuleHandleW(null);
    class_name := utf8_to_wide("OOTSS Helper Console",, temp);
    wc: Win.WNDCLASSEXW;
    wc.cbSize = size_of(Win.WNDCLASSEXW);
    // Layered windows cannot use CS_OWNDC, unlike Window_Creation's default class.
    wc.style = Win.CS_HREDRAW | Win.CS_VREDRAW;
    wc.hInstance = instance;
    wc.hIcon = Win.LoadIconW(instance, cast(*u16) APP_ICON_RESOURCE_ID);
    wc.hIconSm = wc.hIcon;
    wc.lpfnWndProc = overlay_window_proc;
    wc.hCursor = Win.LoadCursorW(null, Win.IDC_ARROW);
    wc.lpszClassName = class_name;
    if !Win.RegisterClassExW(*wc) return false;

    overlay.previous_focus = Win.GetForegroundWindow();
    overlay.game = find_game_window();
    overlay.bounds = overlay_desired_bounds();
    r := overlay.bounds;
    overlay.window = Win.CreateWindowExW(
        Win.WS_EX_LAYERED | Win.WS_EX_TOOLWINDOW | Win.WS_EX_TOPMOST,
        class_name, utf8_to_wide("OOTSS Console",, temp),
        Win.WS_POPUP | Win.WS_CLIPCHILDREN | Win.WS_CLIPSIBLINGS,
        r.left, r.top, r.right - r.left, r.bottom - r.top,
        null, null, instance, null);
    if !overlay.window return false;

    if !SetLayeredWindowAttributes(overlay.window, 0, OVERLAY_OPACITY, LWA_ALPHA) {
        Win.DestroyWindow(overlay.window);
        overlay.window = null;
        return false;
    }
    overlay.global_hotkey_registered = RegisterHotKey(overlay.window, 2, MOD_CONTROL | MOD_NOREPEAT, Win.VK_OEM_3) != 0;
    return true;
}

overlay_desired_bounds :: () -> Win.RECT {
    bounds: Win.RECT;
    origin: Win.POINT;
    if overlay.game && !IsIconic(overlay.game) {
        if Win.GetClientRect(overlay.game, *bounds) && Win.ClientToScreen(overlay.game, *origin) {
            if bounds.right > 0 && bounds.bottom > 0 {
                bounds.left = origin.x;
                bounds.top = origin.y;
                bounds.right += origin.x;
                bounds.bottom = origin.y + bounds.bottom * OVERLAY_HEIGHT_PERCENT / 100;
                return bounds;
            }
        }
    }

    reference := ifx overlay.game then overlay.game else overlay.previous_focus;
    monitor := Win.MonitorFromWindow(reference, Win.MONITOR_DEFAULTTONEAREST);
    info: Win.MONITORINFO;
    info.cbSize = size_of(Win.MONITORINFO);
    if Win.GetMonitorInfoW(monitor, *info) {
        bounds = info.rcMonitor;
    } else {
        bounds.right = 1280;
        bounds.bottom = 720;
    }
    bounds.bottom = bounds.top + (bounds.bottom - bounds.top) * OVERLAY_HEIGHT_PERCENT / 100;
    return bounds;
}

overlay_update_game :: () {
    previous_game := overlay.game;
    overlay.game = find_game_window();
    if !overlay.game {
        if overlay.visible overlay_hide(restore_game = false);
        return;
    }
    // Open once when a game window appears; respect subsequent manual hiding.
    if overlay.game != previous_game overlay_show();
}

overlay_update_bounds :: () -> bool {
    if !overlay.game || !IsWindow(overlay.game) {
        if overlay.visible overlay_hide(restore_game = false);
        return false;
    }
    bounds := overlay_desired_bounds();
    old := overlay.bounds;
    if bounds.left == old.left && bounds.top == old.top && bounds.right == old.right && bounds.bottom == old.bottom {
        return true;
    }
    if Win.SetWindowPos(overlay.window, Win.HWND_TOPMOST, bounds.left, bounds.top,
                       bounds.right - bounds.left, bounds.bottom - bounds.top, Win.SWP_NOACTIVATE) {
        overlay.bounds = bounds;
        return true;
    }
    return false;
}

overlay_show :: () {
    if overlay.quit_requested return;
    overlay.game = find_game_window();
    if !overlay.game || !IsWindow(overlay.game) {
        overlay.game = null;
        if overlay.visible overlay_hide(restore_game = false);
        return;
    }
    current := Win.GetForegroundWindow();
    if current != overlay.window overlay.previous_focus = current;
    if IsIconic(overlay.game) Win.ShowWindow(overlay.game, Win.SW_RESTORE);
    SetForegroundWindow(overlay.game);
    if !overlay_update_bounds() return;
    overlay.visible = true;
    Win.ShowWindow(overlay.window, Win.SW_SHOW);
    Win.SetWindowPos(overlay.window, Win.HWND_TOPMOST, 0, 0, 0, 0,
                     Win.SWP_NOMOVE | Win.SWP_NOSIZE | Win.SWP_SHOWWINDOW);
    SetForegroundWindow(overlay.window);
    SetFocus(overlay.window);
}

overlay_hide :: (restore_game := true) {
    overlay.visible = false;
    Win.ShowWindow(overlay.window, Win.SW_HIDE);
    if restore_game {
        target := ifx overlay.game && IsWindow(overlay.game) then overlay.game else overlay.previous_focus;
        if target && IsWindow(target) SetForegroundWindow(target);
    }
}

overlay_focus_game_for_input :: (game: Win.HWND, poll: () -> bool = null) -> bool {
    if !game || !IsWindow(game) return false;
    if IsIconic(game) Win.ShowWindow(game, Win.SW_RESTORE);
    SetForegroundWindow(game);
    // Activating a window on another input queue can finish after SetForegroundWindow returns.
    if !overlay_wait_for_game_focus(game, poll) return false;

    overlay.game = game;
    overlay_hide(restore_game = false);
    return overlay_wait_for_game_focus(game, poll);
}

overlay_wait_for_game_focus :: (game: Win.HWND, poll: () -> bool) -> bool {
    deadline := seconds_since_init() + 1.0;
    while seconds_since_init() < deadline {
        if poll && !poll() return false;
        if !IsWindow(game) || Win.GetAsyncKeyState(Win.VK_ESCAPE) < 0 return false;
        if Win.GetForegroundWindow() == game return true;
        sleep_milliseconds(10);
    }
    return false;
}

overlay_update_hotkey :: () {
    foreground := Win.GetForegroundWindow();
    wanted := foreground == overlay.window || (overlay.game && foreground == overlay.game);
    if wanted && !overlay.game_hotkey_registered {
        overlay.game_hotkey_registered = RegisterHotKey(overlay.window, 1, MOD_NOREPEAT, Win.VK_OEM_3) != 0;
    } else if !wanted && overlay.game_hotkey_registered {
        UnregisterHotKey(overlay.window, 1);
        overlay.game_hotkey_registered = false;
    }

    wanted_colon := overlay.game && foreground == overlay.game && !overlay.visible;
    // Keep consuming the opening key until it is released, then allow ':' in console input.
    if overlay.colon_hotkey_registered && foreground == overlay.window && Win.GetAsyncKeyState(Win.VK_OEM_1) < 0 {
        wanted_colon = true;
    }
    if wanted_colon && !overlay.colon_hotkey_registered {
        overlay.colon_hotkey_registered = RegisterHotKey(overlay.window, 3, MOD_SHIFT | MOD_NOREPEAT, Win.VK_OEM_1) != 0;
    } else if !wanted_colon && overlay.colon_hotkey_registered {
        UnregisterHotKey(overlay.window, 3);
        overlay.colon_hotkey_registered = false;
    }
}

overlay_destroy :: () {
    if overlay.game_hotkey_registered UnregisterHotKey(overlay.window, 1);
    if overlay.global_hotkey_registered UnregisterHotKey(overlay.window, 2);
    if overlay.colon_hotkey_registered UnregisterHotKey(overlay.window, 3);
    if overlay.visible overlay_hide(Win.GetForegroundWindow() == overlay.window);
    Win.DestroyWindow(overlay.window);
}

find_game_window :: () -> Win.HWND {
    result: Win.HWND;
    EnumWindows(find_game_callback, cast(s64) *result);
    return result;
}

overlay_dpi :: () -> s32 {
    dpi := GetDpiForWindow(overlay.window);
    return cast(s32) ifx dpi then dpi else 96;
}

overlay_enable_dpi_awareness :: () {
    // Per-monitor DPI awareness keeps game coordinates and overlay pixels in the same space.
    if !SetProcessDpiAwarenessContext(cast(*void) -4) Win.SetProcessDPIAware();
}

#scope_file

#import "Basic";
#import "String";
#import "Windows_Utf8";
Win :: #import "Windows";
Input :: #import "Input";

find_game_callback :: (window: Win.HWND, parameter: s64) -> s32 #c_call {
    push_context {
        if !IsWindowVisible(window) return 1;
        class_buffer: [256] u16;
        length := GetClassNameW(window, class_buffer.data, class_buffer.count);
        class_name := wide_to_utf8(class_buffer.data, length,, temp);
        if class_name != "Default Window Class" return 1;

        process_id: u32;
        GetWindowThreadProcessId(window, *process_id);
        process := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, process_id);
        if !process return 1;
        defer Win.CloseHandle(process);
        path_buffer: [2048] u16;
        path_length: u32 = path_buffer.count;
        if !QueryFullProcessImageNameW(process, 0, path_buffer.data, *path_length) return 1;
        path := wide_to_utf8(path_buffer.data, cast(s32) path_length,, temp);
        name_start: s64;
        for c: path if c == #char "/" || c == #char "\\" name_start = it_index + 1;
        if !equal_nocase(slice(path, name_start, path.count - name_start), GAME_EXECUTABLE) return 1;

        result := cast(*Win.HWND) parameter;
        if !result.* result.* = window;
        title_buffer: [256] u16;
        title_length := GetWindowTextW(window, title_buffer.data, title_buffer.count);
        title := wide_to_utf8(title_buffer.data, title_length,, temp);
        if title == GAME_TITLE {
            result.* = window;
            return 0;
        }
        return 1;
    }
}

overlay_window_proc :: (window: Win.HWND, message: u32, wparam: u64, lparam: s64) -> s64 #c_call {
    push_context {
        if tray_handle_message(window, message, wparam, lparam) return 0;
        if message == WM_HOTKEY && (wparam == 1 || wparam == 2) {
            overlay.toggle_requested = true;
            return 0;
        }
        if message == WM_HOTKEY && wparam == 3 {
            overlay.show_requested = true;
            return 0;
        }
        if message == Win.WM_CLOSE {
            overlay.quit_requested = true;
            return 0;
        }
        if message == Win.WM_ERASEBKGND || message == Win.WM_DPICHANGED return 0;
        // Do not insert the toggle key into the command line if a WM_CHAR is also queued.
        if message == Win.WM_CHAR && (wparam == #char "`" || wparam == #char "~") return 0;
        if message == Win.WM_KEYDOWN && wparam == Win.VK_OEM_3 && !overlay.game_hotkey_registered {
            if (lparam & 0x40000000) == 0 overlay.toggle_requested = true;
            return 0;
        }
        return Input.MyWindowProc(window, message, wparam, lparam);
    }
}

WM_HOTKEY :: 0x0312;
MOD_CONTROL :: 0x0002;
MOD_SHIFT :: 0x0004;
MOD_NOREPEAT :: 0x4000;
LWA_ALPHA :: 0x0002;
PROCESS_QUERY_LIMITED_INFORMATION :: 0x1000;

user32 :: #library,system "user32";
kernel32 :: #library,system "kernel32";

EnumWindows :: (callback: (window: Win.HWND, parameter: s64) -> s32 #c_call, parameter: s64) -> s32 #foreign user32;
GetClassNameW :: (window: Win.HWND, text: *u16, capacity: s32) -> s32 #foreign user32;
GetWindowTextW :: (window: Win.HWND, text: *u16, capacity: s32) -> s32 #foreign user32;
GetWindowThreadProcessId :: (window: Win.HWND, process_id: *u32) -> u32 #foreign user32;
IsWindow :: (window: Win.HWND) -> s32 #foreign user32;
IsWindowVisible :: (window: Win.HWND) -> s32 #foreign user32;
IsIconic :: (window: Win.HWND) -> s32 #foreign user32;
SetForegroundWindow :: (window: Win.HWND) -> s32 #foreign user32;
SetFocus :: (window: Win.HWND) -> Win.HWND #foreign user32;
SetLayeredWindowAttributes :: (window: Win.HWND, color: u32, alpha: u8, flags: u32) -> s32 #foreign user32;
RegisterHotKey :: (window: Win.HWND, id: s32, modifiers: u32, key: u32) -> s32 #foreign user32;
UnregisterHotKey :: (window: Win.HWND, id: s32) -> s32 #foreign user32;
GetDpiForWindow :: (window: Win.HWND) -> u32 #foreign user32;
SetProcessDpiAwarenessContext :: (awareness: *void) -> s32 #foreign user32;
OpenProcess :: (access: u32, inherit_handle: s32, process_id: u32) -> Win.HANDLE #foreign kernel32;
QueryFullProcessImageNameW :: (process: Win.HANDLE, flags: u32, path: *u16, length: *u32) -> s32 #foreign kernel32;
