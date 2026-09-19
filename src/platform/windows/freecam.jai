freecam_install_hook :: () -> string {
    if freecam_hook return "";
    freecam_hook = SetWindowsHookExW(13, freecam_keyboard_hook, Win.GetModuleHandleW(null), 0);
    if !freecam_hook return tprint("Could not install free-camera input handling (Windows error %).", Win.GetLastError());
    return "";
}

freecam_remove_hook :: () {
    if freecam_hook UnhookWindowsHookEx(freecam_hook);
    freecam_hook = null;
}

// Shift and Ctrl scale the camera speed. Alt and Win chords still consume the
// movement keys without moving, so modified presses never reach the game.
freecam_modifiers_down :: () -> bool {
    for key: s32.[Win.VK_MENU, Win.VK_LWIN, Win.VK_RWIN] if Win.GetAsyncKeyState(key) < 0 return true;
    return false;
}

freecam_speed_modifier :: () -> Freecam_Speed {
    if Win.GetAsyncKeyState(Win.VK_CONTROL) < 0 return .SLOW;
    if Win.GetAsyncKeyState(Win.VK_SHIFT) < 0 return .FAST;
    return .NORMAL;
}

// Raw input keeps reporting relative mouse motion while the game owns focus and
// the cursor is confined, which cursor positions cannot. The overlay window
// forwards WM_INPUT to the Input module, which accumulates the deltas.
freecam_install_mouse :: (window: Win.HWND) -> string {
    device := Win.RAWINPUTDEVICE.{usUsagePage = 1, usUsage = 2, dwFlags = RIDEV_INPUTSINK, hwndTarget = window};
    if !window || Win.RegisterRawInputDevices(*device, 1, size_of(Win.RAWINPUTDEVICE)) != 1 {
        return tprint("Could not receive mouse movement for the free camera (Windows error %).", Win.GetLastError());
    }
    freecam_mouse_registered = true;
    return "";
}

freecam_remove_mouse :: () {
    if !freecam_mouse_registered return;
    freecam_mouse_registered = false;
    // Return to the Input module's focus-following registration.
    device := Win.RAWINPUTDEVICE.{usUsagePage = 1, usUsage = 2};
    Win.RegisterRawInputDevices(*device, 1, size_of(Win.RAWINPUTDEVICE));
}

// Park the cursor at the game's client center and confine it there, so mouse
// motion only turns the view and any click still lands inside the game.
freecam_lock_cursor :: (game: Win.HWND) -> bool {
    bounds: Win.RECT;
    origin: Win.POINT;
    if !Win.GetClientRect(game, *bounds) || !Win.ClientToScreen(game, *origin) || bounds.right <= 0 || bounds.bottom <= 0 return false;
    center := Win.POINT.{origin.x + bounds.right / 2, origin.y + bounds.bottom / 2};
    current: Win.POINT;
    if !freecam_cursor.locked || center.x != freecam_cursor.center.x || center.y != freecam_cursor.center.y ||
       !Win.GetCursorPos(*current) || current.x != center.x || current.y != center.y {
        SetCursorPos(center.x, center.y);
    }
    freecam_cursor.locked = true;
    freecam_cursor.center = center;
    clip := Win.RECT.{center.x, center.y, center.x + 1, center.y + 1};
    return Win.ClipCursor(*clip) != 0; // Focus changes drop the clip, so reapply it every frame.
}

freecam_unlock_cursor :: () {
    if !freecam_cursor.locked return;
    freecam_cursor.locked = false;
    Win.ClipCursor(null);
}

#scope_file
#import "Basic";
Win :: #import "Windows";
freecam_hook: *void;
freecam_mouse_registered: bool;
freecam_cursor: struct { locked: bool; center: Win.POINT; };

RIDEV_INPUTSINK :: 0x00000100;

Freecam_Keyboard_Event :: struct { vk, scan, flags, time: u32; extra: u64; }

freecam_keyboard_hook :: (code: s32, message: u64, data: s64) -> s64 #c_call {
    push_context {
        if code >= 0 && (message == 0x100 || message == 0x104 || message == 0x101 || message == 0x105) {
            key := cast(*Freecam_Keyboard_Event) data;
            down := message == 0x100 || message == 0x104;
            injected := (key.flags & 0x12) != 0;
            foreground := Win.GetForegroundWindow();
            if shortcuts_handle_key(key.vk, down, injected, foreground) return 1;
            if freecam_filter_key(key.vk, down, injected, foreground, freecam_modifiers_down()) return 1;
        }
        return CallNextHookEx(freecam_hook, code, message, data);
    }
}

user32 :: #library,system "user32";
SetWindowsHookExW :: (kind: s32, callback: (code: s32, message: u64, data: s64) -> s64 #c_call,
                     instance: Win.HINSTANCE, thread: u32) -> *void #foreign user32;
UnhookWindowsHookEx :: (hook: *void) -> s32 #foreign user32;
CallNextHookEx :: (hook: *void, code: s32, message: u64, data: s64) -> s64 #foreign user32;
SetCursorPos :: (x: s32, y: s32) -> s32 #foreign user32;
