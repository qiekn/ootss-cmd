// Independent console playback owns these hooks only while send/send_alt is running.
// The solution editor keeps its own recording and shortcuts in platform/windows/editor.jai.
send_input_begin :: (target: Win.HWND) -> string {
    send_input_end();
    send_input_monitor.target = target;
    instance := Win.GetModuleHandleW(null);
    send_input_monitor.keyboard_hook = SetWindowsHookExW(13, send_keyboard_hook, instance, 0);
    if send_input_monitor.keyboard_hook {
        send_input_monitor.mouse_hook = SetWindowsHookExW(14, send_mouse_hook, instance, 0);
    }
    if !send_input_monitor.keyboard_hook || !send_input_monitor.mouse_hook {
        error := Win.GetLastError();
        send_input_end();
        return tprint("Could not watch for player input (Windows error %). No keys were sent.", error);
    }
    return "";
}

send_input_end :: () {
    if send_input_monitor.keyboard_hook UnhookWindowsHookEx(send_input_monitor.keyboard_hook);
    if send_input_monitor.mouse_hook UnhookWindowsHookEx(send_input_monitor.mouse_hook);
    send_input_monitor = .{};
}

send_input_interrupted :: () -> bool { return send_input_monitor.interrupted; }

send_input_filter_keyboard :: (message: u64, flags: u32, foreground: Win.HWND) {
    if !send_input_monitor.target || foreground != send_input_monitor.target || (flags & 0x12) != 0 return;
    if message == 0x100 || message == 0x104 send_input_monitor.interrupted = true; // Key down, including repeats.
}

send_input_filter_mouse :: (message: u64, flags: u32, foreground: Win.HWND) {
    if !send_input_monitor.target || foreground != send_input_monitor.target || (flags & 0x03) != 0 return;
    // Mouse movement alone is not a game command; clicks and wheel input interrupt playback.
    if message == 0x201 || message == 0x204 || message == 0x207 || message == 0x20b ||
       message == 0x20a || message == 0x20e send_input_monitor.interrupted = true;
}

#scope_file
#import "Basic";
Win :: #import "Windows";

send_input_monitor: struct {
    target: Win.HWND;
    keyboard_hook, mouse_hook: *void;
    interrupted: bool;
};

send_keyboard_hook :: (code: s32, message: u64, data: s64) -> s64 #c_call {
    push_context {
        if code >= 0 {
            key := cast(*Send_Keyboard_Hook_Event) data;
            send_input_filter_keyboard(message, key.flags, Win.GetForegroundWindow());
        }
        // Preserve the player's input so they can take over immediately.
        return CallNextHookEx(send_input_monitor.keyboard_hook, code, message, data);
    }
}

send_mouse_hook :: (code: s32, message: u64, data: s64) -> s64 #c_call {
    push_context {
        if code >= 0 {
            mouse := cast(*Send_Mouse_Hook_Event) data;
            send_input_filter_mouse(message, mouse.flags, Win.GetForegroundWindow());
        }
        return CallNextHookEx(send_input_monitor.mouse_hook, code, message, data);
    }
}

Send_Keyboard_Hook_Event :: struct { vk, scan, flags, time: u32; extra: u64; }
Send_Mouse_Hook_Event :: struct { point: Win.POINT; mouse_data, flags, time: u32; extra: u64; }

user32 :: #library,system "user32";
SetWindowsHookExW :: (kind: s32, callback: (code: s32, message: u64, data: s64) -> s64 #c_call,
                     instance: Win.HINSTANCE, thread: u32) -> *void #foreign user32;
UnhookWindowsHookEx :: (hook: *void) -> s32 #foreign user32;
CallNextHookEx :: (hook: *void, code: s32, message: u64, data: s64) -> s64 #foreign user32;
