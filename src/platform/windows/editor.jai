Editor_Event :: struct {
    kind: enum { KEY; TEXT; DOWN; UP; MOVE; WHEEL; CANCEL; PLAY; STEP; UNDO; TOGGLE_SIZE; SPEED_UP; SPEED_DOWN; SPEED_FAST; SPEED_TURTLE; COPY; GAME_KEY; CLOSE; };
    x, y: s32;
    key: u32;
    shift, ctrl, alt, repeat: bool;
}

Editor_Window :: struct {
    handle: Win.HWND;
    dc: Win.HDC;
    bounds: Win.RECT;
    visible: bool;
    dpi: s32 = 96;
    hook: *void;
    physical_down: [256] bool;
    transport_key_consumed: [256] bool;
    speed_key_consumed: [256] bool;
    events: [1024] Editor_Event;
    event_count: s64;
    overflow: bool;
}
editor_window: Editor_Window;

editor_window_handle :: () -> Win.HWND { return editor_window.handle; }

editor_window_create :: () -> bool {
    if editor_window.handle return true;
    instance := Win.GetModuleHandleW(null);
    name := utf8_to_wide("OOTSS Solution Editor",, temp);
    wc: Win.WNDCLASSEXW;
    wc.cbSize = size_of(Win.WNDCLASSEXW);
    wc.style = Win.CS_HREDRAW | Win.CS_VREDRAW;
    wc.lpfnWndProc = editor_window_proc;
    wc.hInstance = instance;
    wc.hIcon = Win.LoadIconW(instance, cast(*u16) APP_ICON_RESOURCE_ID);
    wc.hIconSm = wc.hIcon;
    wc.hCursor = Win.LoadCursorW(null, Win.IDC_ARROW);
    wc.lpszClassName = name;
    if !Win.RegisterClassExW(*wc) && Win.GetLastError() != 1410 return false;
    editor_window.handle = Win.CreateWindowExW(
        Win.WS_EX_LAYERED | Win.WS_EX_TOOLWINDOW | Win.WS_EX_TOPMOST | Win.WS_EX_NOACTIVATE,
        name, name, Win.WS_POPUP | Win.WS_CLIPCHILDREN | Win.WS_CLIPSIBLINGS,
        0, 0, 1100, 248, null, null, instance, null);
    if !editor_window.handle return false;
    if !SetLayeredWindowAttributes(editor_window.handle, 0, 236, 2) {
        Win.DestroyWindow(editor_window.handle);
        editor_window.handle = null;
        return false;
    }
    Simp.prepare_window(editor_window.handle, wanted_msaa = 0);
    Simp.set_render_target(editor_window.handle, .LEFT_HANDED);
    editor_window.dc = Win.wglGetCurrentDC();
    Simp.set_render_target(overlay.window, .LEFT_HANDED);
    return true;
}

editor_game_valid :: () -> bool {
    return editor.game && IsWindow(editor.game) != 0 && game_window_pid(editor.game) == editor.game_pid;
}

editor_window_update :: () {
    if editor.open && editor_save_prompt.active && (!editor_game_valid() || IsIconic(editor.game)) {
        // An exit confirmation remains usable even after the game has closed or minimized.
        if !editor_window.visible {
            Win.SetWindowPos(editor_window.handle, Win.HWND_TOPMOST, 0, 0, 0, 0,
                             Win.SWP_NOMOVE | Win.SWP_NOSIZE | Win.SWP_NOACTIVATE | Win.SWP_SHOWWINDOW);
            editor_window.visible = true;
        }
        return;
    }
    foreground := Win.GetForegroundWindow();
    wanted := editor.open && editor_game_valid() && !IsIconic(editor.game) &&
              (editor_save_prompt.active || overlay.visible || foreground == editor.game || foreground == editor_window.handle);
    if !wanted { editor_window_hide(); return; }
    bounds: Win.RECT;
    origin: Win.POINT;
    if !Win.GetClientRect(editor.game, *bounds) || !Win.ClientToScreen(editor.game, *origin) {
        editor_window_hide();
        return;
    }
    dpi := cast(s32) GetDpiForWindow(editor.game);
    editor_window.dpi = ifx dpi > 0 then dpi else 96;
    scale := cast(float) editor_window.dpi / 96;
    width := min(bounds.right, cast(s32)((ifx editor_view.minimized then 720 else 1120) * scale));
    height := min(bounds.bottom, cast(s32)((ifx editor_view.minimized then 84 else 248) * scale));
    margin := cast(s32)((ifx editor_view.minimized then 18 else 36) * scale);
    x := origin.x + (bounds.right - width) / 2;
    y := origin.y + bounds.bottom - height - min(margin, max(cast(s32) 0, bounds.bottom - height));
    old := editor_window.bounds;
    if x != old.left || y != old.top || width != old.right - old.left || height != old.bottom - old.top || !editor_window.visible {
        Win.SetWindowPos(editor_window.handle, Win.HWND_TOPMOST, x, y, width, height, Win.SWP_NOACTIVATE | Win.SWP_SHOWWINDOW);
        editor_window.bounds = .{x, y, x + width, y + height};
        editor_window.visible = true;
    }
    editor_window_update_z_order();
}

editor_window_update_z_order :: () {
    // Activating a fullscreen game can cover an already-visible editor without changing its bounds.
    // Keep the timeline below the active console and above the game, without taking input focus.
    insert_after := Win.HWND_TOPMOST;
    if overlay.visible {
        if GetWindow(overlay.window, GW_HWNDNEXT) == editor_window.handle return;
        insert_after = overlay.window;
    } else {
        above := GetWindow(editor.game, GW_HWNDPREV);
        while above {
            if above == editor_window.handle return;
            above = GetWindow(above, GW_HWNDPREV);
        }
    }
    Win.SetWindowPos(editor_window.handle, insert_after, 0, 0, 0, 0,
                     Win.SWP_NOMOVE | Win.SWP_NOSIZE | Win.SWP_NOACTIVATE);
}

editor_window_hide :: () {
    if editor.transport.held_step != 0 editor_pause();
    editor_view_cancel_drag();
    if editor_window.visible Win.ShowWindow(editor_window.handle, Win.SW_HIDE);
    editor_window.visible = false;
}

editor_window_set_drag_cursor :: (dragging: bool) {
    if !editor_window.handle return;
    cursor := ifx dragging then Win.IDC_HAND else Win.IDC_ARROW;
    Win.SetCursor(Win.LoadCursorW(null, cursor));
}

editor_window_destroy :: () {
    if !editor_window.handle return;
    Simp.set_render_target(overlay.window, .LEFT_HANDED);
    Win.DestroyWindow(editor_window.handle);
    editor_window.handle = null;
}

editor_focus_game :: () {
    if editor_game_valid() SetForegroundWindow(editor.game);
}

editor_focus_text :: () {
    if !editor.open || !editor_window.handle return;
    // Clicking timeline cells requests text focus in either editor size.
    SetForegroundWindow(editor_window.handle);
    SetFocus(editor_window.handle);
}

editor_install_keyboard_hook :: () -> bool {
    if editor_window.hook return true;
    for i: 0..255 editor_window.physical_down[i] = Win.GetAsyncKeyState(cast(s32) i) < 0;
    editor_window.event_count = 0;
    editor_window.overflow = false;
    for *consumed: editor_window.transport_key_consumed consumed.* = false;
    for *consumed: editor_window.speed_key_consumed consumed.* = false;
    editor_window.hook = SetWindowsHookExW(13, editor_keyboard_hook, Win.GetModuleHandleW(null), 0);
    return editor_window.hook != null;
}

editor_remove_keyboard_hook :: () {
    if editor_window.hook UnhookWindowsHookEx(editor_window.hook);
    editor_window.hook = null;
    editor_window.event_count = 0;
}

editor_physical_key_down :: (key: u32) -> bool {
    return key < editor_window.physical_down.count && editor_window.physical_down[key];
}

editor_modifiers_down :: (ignore_speed_keys := false) -> bool {
    for key: u32.[0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0x5b, 0x5c] {
        if editor_physical_key_down(key) && (!ignore_speed_keys || !editor_window.speed_key_consumed[key]) return true;
    }
    return false;
}

editor_input_overflowed :: () -> bool {
    result := editor_window.overflow;
    editor_window.overflow = false;
    return result;
}

editor_process_window_events :: () {
    count := editor_window.event_count;
    if !count return;
    events := editor_window.events;
    editor_window.event_count = 0;
    for i: 0..count-1 {
        event := events[i];
        if !editor.open continue;
        if event.kind == .PLAY editor_toggle_play();
        else if event.kind == .STEP editor_step(1);
        else if event.kind == .UNDO editor_step(-1);
        else if event.kind == .TOGGLE_SIZE editor_toggle_minimized();
        else if event.kind == .SPEED_UP editor_adjust_playback_speed(true);
        else if event.kind == .SPEED_DOWN editor_adjust_playback_speed(false);
        else if event.kind == .SPEED_FAST editor_set_playback_speed(.FAST);
        else if event.kind == .SPEED_TURTLE editor_set_playback_speed(.TURTLE);
        else if event.kind == .COPY editor_export_solution();
        else if event.kind == .GAME_KEY editor_on_game_key(event.key);
        else if event.kind == .CLOSE editor_close();
        else editor_handle_event(event);
    }
}

editor_time_key_matches :: (binding: Game_Key, vk: u32) -> bool {
    if binding.vk == vk return true;
    // User.keymap's generic modifier names apply to either side of the keyboard.
    if binding.vk == 0xa0 return vk == 0xa1 || vk == 0x10;
    if binding.vk == 0xa2 return vk == 0xa3 || vk == 0x11;
    if binding.vk == 0xa4 return vk == 0xa5 || vk == 0x12;
    return false;
}

editor_step_key_direction :: (vk: u32) -> s64 {
    if vk == 0xdd return 1;  // ]
    if vk == 0xdb return -1; // [
    return 0;
}

editor_filter_key :: (vk: u32, down: bool, injected: bool, foreground: Win.HWND) -> bool {
    if injected || vk >= 256 return false;
    if shortcuts_handle_key(vk, down, injected, foreground) return true;
    if freecam_filter_key(vk, down, injected, foreground, freecam_modifiers_down()) return true;
    // Whichever keyboard hook runs first owns noclip movement; never record the consumed physical key.
    if noclip_filter_key(vk, down, injected, foreground, editor_modifiers_down()) return true;
    was_down := editor_window.physical_down[vk];
    editor_window.physical_down[vk] = down;
    active := editor.open && !editor_save_prompt.active && (foreground == editor.game || foreground == editor_window.handle);
    if editor_window.speed_key_consumed[vk] {
        editor_window.speed_key_consumed[vk] = down;
        return true;
    }
    if editor_window.transport_key_consumed[vk] {
        editor_window.transport_key_consumed[vk] = down;
        return true;
    }
    if active && vk == #char "C" && down &&
       (editor_physical_key_down(0xa2) || editor_physical_key_down(0xa3) || editor_physical_key_down(0x11)) {
        if !was_down editor_queue_event(.{kind = .COPY});
        editor_window.transport_key_consumed[vk] = true;
        return true;
    }
    // Editor shortcuts take priority over the game's time-modifier bindings.
    step := editor_step_key_direction(vk);
    shortcut := vk == 0x20 || ((step != 0 || vk == #char "N" || vk == #char "J" ||
                              vk == #char "K" || vk == #char "L") && !editor_modifiers_down());
    if shortcut && active {
        if down && !was_down {
            event: Editor_Event;
            event.key = vk;
            if vk == 0x20 || vk == #char "K" event.kind = .PLAY;
            else if vk == #char "N" event.kind = .TOGGLE_SIZE;
            else if vk == #char "J" event.kind = .SPEED_UP;
            else if vk == #char "L" event.kind = .SPEED_DOWN;
            else if step > 0 event.kind = .STEP;
            else event.kind = .UNDO;
            editor_queue_event(event);
        }
        editor_window.transport_key_consumed[vk] = down;
        return true;
    }
    if active && editor.transport.playing && down && !was_down {
        fast := editor_time_key_matches(editor.keymap.fast, vk);
        slow := editor_time_key_matches(editor.keymap.slow, vk);
        if fast || slow {
            editor_queue_event(.{kind = ifx fast then .SPEED_FAST else .SPEED_TURTLE});
            editor_window.speed_key_consumed[vk] = true;
            return true;
        }
    }
    if editor.open && foreground == editor.game && down && !was_down {
        editor_queue_event(.{kind = .GAME_KEY, key = vk});
    }
    return false;
}

#scope_file
#import "Basic";
#import "Windows_Utf8";
Win :: #import "Windows";
Simp :: #import "Simp";

editor_queue_event :: (event: Editor_Event) {
    if editor_window.event_count == editor_window.events.count { editor_window.overflow = true; return; }
    editor_window.events[editor_window.event_count] = event;
    editor_window.event_count += 1;
}

editor_keyboard_hook :: (code: s32, message: u64, data: s64) -> s64 #c_call {
    push_context {
        if code >= 0 {
            key := cast(*Keyboard_Hook_Event) data;
            // Never record SendInput (including our held accelerator), nor treat it as Space playback.
            if editor_filter_key(key.vk, message == 0x100 || message == 0x104,
                                 (key.flags & 0x12) != 0, Win.GetForegroundWindow()) return 1;
        }
        return CallNextHookEx(editor_window.hook, code, message, data);
    }
}

editor_window_proc :: (window: Win.HWND, message: u32, wparam: u64, lparam: s64) -> s64 #c_call {
    push_context {
        if message == Win.WM_MOUSEACTIVATE return 3; // MA_NOACTIVATE: transport buttons leave the game active.
        if message == Win.WM_SETCURSOR && (lparam & 0xffff) == 1 { // HTCLIENT
            editor_window_set_drag_cursor(editor_view.dragging);
            return 1;
        }
        if message == Win.WM_CLOSE { editor_queue_event(.{kind = .CLOSE}); return 0; }
        if message == Win.WM_ERASEBKGND || message == Win.WM_DPICHANGED return 0;
        event: Editor_Event;
        // Win32 packs signed 16-bit coordinates; creation messages may contain pointer bits here.
        event.x = cast,trunc(s16) lparam;
        event.y = cast,trunc(s16) (lparam >> 16);
        event.ctrl = Win.GetKeyState(Win.VK_CONTROL) < 0;
        event.shift = Win.GetKeyState(Win.VK_SHIFT) < 0;
        event.alt = Win.GetKeyState(Win.VK_MENU) < 0;
        if message == Win.WM_LBUTTONDOWN {
            event.kind = .DOWN;
            Win.SetCapture(window);
        } else if message == Win.WM_LBUTTONUP {
            event.kind = .UP;
            editor_queue_event(event);
            Win.ReleaseCapture();
            return 0;
        } else if message == Win.WM_MOUSEMOVE event.kind = .MOVE;
        else if message == Win.WM_MOUSEWHEEL {
            event.kind = .WHEEL;
            event.y = cast,trunc(s16) (wparam >> 16);
        } else if message == 0x215 event.kind = .CANCEL; // WM_CAPTURECHANGED
        else if message == Win.WM_KEYDOWN || message == Win.WM_SYSKEYDOWN {
            event.kind = .KEY;
            event.key = cast(u32) wparam;
            event.repeat = (lparam & 0x40000000) != 0;
            if wparam == Win.VK_OEM_3 && !event.ctrl { overlay.show_requested = true; return 0; }
        } else if message == Win.WM_CHAR {
            if wparam == #char ":" { overlay.show_requested = true; return 0; }
            if wparam == #char ";" { overlay.quick_requested = true; return 0; }
            event.kind = .TEXT;
            event.key = cast(u32) wparam;
        } else return Win.DefWindowProcW(window, message, wparam, lparam);
        editor_queue_event(event);
        return 0;
    }
}

Keyboard_Hook_Event :: struct { vk, scan, flags, time: u32; extra: u64; }
GW_HWNDNEXT :: 2;
GW_HWNDPREV :: 3;
user32 :: #library,system "user32";
GetWindow :: (window: Win.HWND, relation: u32) -> Win.HWND #foreign user32;
SetWindowsHookExW :: (kind: s32, callback: (code: s32, message: u64, data: s64) -> s64 #c_call,
                     instance: Win.HINSTANCE, thread: u32) -> *void #foreign user32;
UnhookWindowsHookEx :: (hook: *void) -> s32 #foreign user32;
CallNextHookEx :: (hook: *void, code: s32, message: u64, data: s64) -> s64 #foreign user32;
IsWindow :: (window: Win.HWND) -> s32 #foreign user32;
IsIconic :: (window: Win.HWND) -> s32 #foreign user32;
GetDpiForWindow :: (window: Win.HWND) -> u32 #foreign user32;
SetForegroundWindow :: (window: Win.HWND) -> s32 #foreign user32;
SetFocus :: (window: Win.HWND) -> Win.HWND #foreign user32;
SetLayeredWindowAttributes :: (window: Win.HWND, color: u32, alpha: u8, flags: u32) -> s32 #foreign user32;
