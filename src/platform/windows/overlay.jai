OVERLAY_HEIGHT_PERCENT :: 70;
OVERLAY_OPACITY: u8 : 220;
OVERLAY_FULL_GUARD_PIXELS :: 1;
QUICK_COMMAND_WIDTH :: 560;
QUICK_COMMAND_HEIGHT :: 56;
QUICK_COMMAND_MARGIN :: 16;

Overlay_State :: struct {
    window: Win.HWND;
    game: Win.HWND;
    previous_focus: Win.HWND;
    bounds: Win.RECT;
    native_bounds: Win.RECT;
    clipped: bool;
    mode: Console_Mode;
    full_mode: Console_Mode;
    visible := false;
    toggle_requested := false;
    show_requested := false;
    quick_requested := false;
    quit_requested := false;
    game_hotkey_registered := false;
    colon_hotkey_registered := false;
    semicolon_hotkey_registered := false;
    opening_punctuation: bool;
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
    overlay.native_bounds = r;
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
                bounds.bottom += origin.y;
                dpi := cast(s32) GetDpiForWindow(overlay.game);
                return overlay_bounds_for_mode(bounds, overlay.mode, ifx dpi > 0 then dpi else 96);
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
    return overlay_bounds_for_mode(bounds, overlay.mode, overlay_dpi());
}

overlay_bounds_for_mode :: (viewport: Win.RECT, mode: Console_Mode, dpi: s32) -> Win.RECT {
    bounds := viewport;
    if mode == .MINI {
        available_width := max(cast(s32) 1, bounds.right - bounds.left);
        available_height := max(cast(s32) 1, bounds.bottom - bounds.top);
        margin_x := min(QUICK_COMMAND_MARGIN * dpi / 96, (available_width - 1) / 2);
        margin_y := min(QUICK_COMMAND_MARGIN * dpi / 96, (available_height - 1) / 2);
        width := min(QUICK_COMMAND_WIDTH * dpi / 96, available_width - 2 * margin_x);
        height := min(QUICK_COMMAND_HEIGHT * dpi / 96, available_height - 2 * margin_y);
        bounds.left += margin_x;
        bounds.right = bounds.left + width;
        bounds.bottom -= margin_y;
        bounds.top = bounds.bottom - height;
    } else {
        percent := cast(s32)(ifx mode == .FULL then 100 else ifx mode == .SMALL then 30 else OVERLAY_HEIGHT_PERCENT);
        bounds.bottom = bounds.top + max(cast(s32) 1, (bounds.bottom - bounds.top) * percent / 100);
    }
    return bounds;
}

overlay_native_bounds :: (visible: Win.RECT, mode: Console_Mode) -> Win.RECT {
    bounds := visible;
    // A monitor-sized OpenGL drawable can trigger a driver's fullscreen transition.
    // Oversize its right edge, then clip that column so the visible console still fits exactly.
    if mode == .FULL bounds.right += OVERLAY_FULL_GUARD_PIXELS;
    return bounds;
}

overlay_content_dimensions :: () -> (width: s32, height: s32) {
    return overlay.bounds.right - overlay.bounds.left, overlay.bounds.bottom - overlay.bounds.top;
}

overlay_apply_bounds :: (bounds: Win.RECT) -> bool {
    native := overlay_native_bounds(bounds, overlay.mode);
    full := overlay.mode == .FULL;
    width := bounds.right - bounds.left;
    height := bounds.bottom - bounds.top;
    old := overlay.bounds;
    old_native := overlay.native_bounds;
    if bounds.left == old.left && bounds.top == old.top && bounds.right == old.right && bounds.bottom == old.bottom &&
       native.right == old_native.right && overlay.clipped == full return true;

    if full && (!overlay.clipped || width != old.right - old.left || height != old.bottom - old.top) {
        region := CreateRectRgn(0, 0, width, height);
        if !region return false;
        // SetWindowRgn owns the region only after success. Clip before exposing the larger window.
        if !SetWindowRgn(overlay.window, region, 0) {
            Win.DeleteObject(region);
            return false;
        }
        overlay.clipped = true;
    }
    if !Win.SetWindowPos(overlay.window, Win.HWND_TOPMOST, native.left, native.top,
                        native.right - native.left, native.bottom - native.top, Win.SWP_NOACTIVATE) return false;
    if !full && overlay.clipped {
        if !SetWindowRgn(overlay.window, null, 0) return false;
        overlay.clipped = false;
    }
    overlay.bounds = bounds;
    overlay.native_bounds = native;
    return true;
}

overlay_set_mode :: (mode: Console_Mode) {
    overlay.mode = mode;
    if mode != .MINI overlay.full_mode = mode;
    if mode == .MINI overlay_image_hide();
    if overlay.visible overlay_update_bounds();
}

overlay_present_output :: (console: *Console_State) {
    // Ordinary output stays in scrollback; explicit subtitle requests resize on submission.
    console.reveal_output = false;
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
    return overlay_apply_bounds(bounds);
}

overlay_show :: (mode: Console_Mode = .NORMAL) {
    if overlay.quit_requested return;
    overlay.game = find_game_window();
    if !overlay.game || !IsWindow(overlay.game) {
        overlay.game = null;
        if overlay.visible overlay_hide(restore_game = false);
        return;
    }
    current := Win.GetForegroundWindow();
    if current != overlay.window overlay.previous_focus = current;
    overlay_set_mode(mode);
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
    overlay_image_hide();
    Win.ShowWindow(overlay.window, Win.SW_HIDE);
    if restore_game {
        target := ifx overlay.game && IsWindow(overlay.game) then overlay.game else overlay.previous_focus;
        if target && IsWindow(target) SetForegroundWindow(target);
    }
}

overlay_update_focus :: () {
    if overlay.visible && Win.GetForegroundWindow() != overlay.window {
        overlay_hide(restore_game = false);
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
    if Win.GetAsyncKeyState(Win.VK_OEM_1) >= 0 overlay.opening_punctuation = false;
    wanted := foreground == overlay.window || (overlay.game && foreground == overlay.game);
    if wanted && !overlay.game_hotkey_registered {
        overlay.game_hotkey_registered = RegisterHotKey(overlay.window, 1, MOD_NOREPEAT, Win.VK_OEM_3) != 0;
    } else if !wanted && overlay.game_hotkey_registered {
        UnregisterHotKey(overlay.window, 1);
        overlay.game_hotkey_registered = false;
    }

    wanted_colon := overlay.game && foreground == overlay.game;
    // Keep consuming the opening key until it is released, then allow ':' in console input.
    if (overlay.colon_hotkey_registered || overlay.opening_punctuation) &&
       foreground == overlay.window && Win.GetAsyncKeyState(Win.VK_OEM_1) < 0 {
        wanted_colon = true;
    }
    if wanted_colon && !overlay.colon_hotkey_registered {
        overlay.colon_hotkey_registered = RegisterHotKey(overlay.window, 3, MOD_SHIFT | MOD_NOREPEAT, Win.VK_OEM_1) != 0;
    } else if !wanted_colon && overlay.colon_hotkey_registered {
        UnregisterHotKey(overlay.window, 3);
        overlay.colon_hotkey_registered = false;
    }

    wanted_semicolon := overlay.game && foreground == overlay.game;
    if (overlay.semicolon_hotkey_registered || overlay.opening_punctuation) &&
       foreground == overlay.window && Win.GetAsyncKeyState(Win.VK_OEM_1) < 0 {
        wanted_semicolon = true;
    }
    if wanted_semicolon && !overlay.semicolon_hotkey_registered {
        overlay.semicolon_hotkey_registered = RegisterHotKey(overlay.window, 4, MOD_NOREPEAT, Win.VK_OEM_1) != 0;
    } else if !wanted_semicolon && overlay.semicolon_hotkey_registered {
        UnregisterHotKey(overlay.window, 4);
        overlay.semicolon_hotkey_registered = false;
    }
}

overlay_destroy :: () {
    if overlay.game_hotkey_registered UnregisterHotKey(overlay.window, 1);
    if overlay.colon_hotkey_registered UnregisterHotKey(overlay.window, 3);
    if overlay.semicolon_hotkey_registered UnregisterHotKey(overlay.window, 4);
    if overlay.visible overlay_hide(Win.GetForegroundWindow() == overlay.window);
    overlay_image_destroy();
    Win.DestroyWindow(overlay.window);
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

overlay_window_proc :: (window: Win.HWND, message: u32, wparam: u64, lparam: s64) -> s64 #c_call {
    push_context {
        if tray_handle_message(window, message, wparam, lparam) return 0;
        if message == WM_HOTKEY && wparam == 1 {
            overlay.toggle_requested = true;
            return 0;
        }
        if message == WM_HOTKEY && wparam == 3 {
            overlay.show_requested = true;
            return 0;
        }
        if message == WM_HOTKEY && wparam == 4 {
            overlay.quick_requested = true;
            return 0;
        }
        if message == Win.WM_CLOSE {
            overlay.quit_requested = true;
            return 0;
        }
        if message == Win.WM_ERASEBKGND || message == Win.WM_DPICHANGED return 0;
        // Do not insert the toggle key into the command line if a WM_CHAR is also queued.
        if message == Win.WM_CHAR && (wparam == #char "`" || wparam == #char "~") return 0;
        if message == Win.WM_CHAR &&
           ((wparam == #char ":" && overlay.colon_hotkey_registered) ||
            (wparam == #char ";" && overlay.semicolon_hotkey_registered)) return 0;
        if message == Win.WM_KEYDOWN && wparam == Win.VK_OEM_3 && !overlay.game_hotkey_registered &&
           Win.GetKeyState(Win.VK_CONTROL) >= 0 {
            if (lparam & 0x40000000) == 0 overlay.toggle_requested = true;
            return 0;
        }
        return Input.MyWindowProc(window, message, wparam, lparam);
    }
}

WM_HOTKEY :: 0x0312;
MOD_SHIFT :: 0x0004;
MOD_NOREPEAT :: 0x4000;
LWA_ALPHA :: 0x0002;

user32 :: #library,system "user32";
gdi32 :: #library,system "gdi32";

IsWindow :: (window: Win.HWND) -> s32 #foreign user32;
IsIconic :: (window: Win.HWND) -> s32 #foreign user32;
SetForegroundWindow :: (window: Win.HWND) -> s32 #foreign user32;
SetFocus :: (window: Win.HWND) -> Win.HWND #foreign user32;
SetLayeredWindowAttributes :: (window: Win.HWND, color: u32, alpha: u8, flags: u32) -> s32 #foreign user32;
SetWindowRgn :: (window: Win.HWND, region: Win.HGDIOBJ, redraw: s32) -> s32 #foreign user32;
CreateRectRgn :: (left: s32, top: s32, right: s32, bottom: s32) -> Win.HGDIOBJ #foreign gdi32;
RegisterHotKey :: (window: Win.HWND, id: s32, modifiers: u32, key: u32) -> s32 #foreign user32;
UnregisterHotKey :: (window: Win.HWND, id: s32) -> s32 #foreign user32;
GetDpiForWindow :: (window: Win.HWND) -> u32 #foreign user32;
SetProcessDpiAwarenessContext :: (awareness: *void) -> s32 #foreign user32;
