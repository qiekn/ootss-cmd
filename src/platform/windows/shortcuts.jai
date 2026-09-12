shortcuts_install :: () -> string {
    if shortcuts_hook || !console.config.shortcuts.count return "";
    shortcuts_hook = SetWindowsHookExW(13, shortcuts_keyboard_hook, Win.GetModuleHandleW(null), 0);
    if !shortcuts_hook return tprint("Could not install command shortcuts (Windows error %).", Win.GetLastError());
    shortcuts = .{};
    shortcuts.enabled = true;
    for i: 0..shortcuts.down.count-1 {
        if shortcut_physical_key(cast(u32) i) == i shortcuts.down[i] = Win.GetAsyncKeyState(cast(s32) i) < 0;
    }
    shortcuts_refresh_target();
    return "";
}

shortcuts_blocked :: () -> bool {
    return editor_save_prompt.active || overlay.quit_requested || overlay.show_requested || overlay.quick_requested ||
           overlay.toggle_requested || tray_has_request() || process_console_should_exit();
}

shortcuts_refresh_target :: () {
    if !shortcuts.enabled return;
    game := overlay.game;
    pid := process_window_pid(game);
    if game != shortcuts.game || pid != shortcuts.pid {
        // Revalidate a changed identity outside the hook, including a reused HWND.
        game = find_game_window();
        pid = process_window_pid(game);
    }
    shortcuts_set_target(*shortcuts, game, pid, Win.GetForegroundWindow(), shortcuts_blocked());
}

shortcuts_handle_key :: (vk: u32, down: bool, injected: bool, foreground: Win.HWND) -> bool {
    if !shortcuts.enabled || injected || vk >= shortcuts.down.count return false;
    valid_target := shortcuts.game && shortcuts.game == overlay.game &&
                    shortcuts.pid && process_window_pid(shortcuts.game) == shortcuts.pid;
    consumed, triggered := shortcut_filter_key(*shortcuts, console.config.shortcuts, vk, down, injected,
                                               foreground, !valid_target || shortcuts_blocked());
    // Hook order changes when recording or noclip starts. A consumed mapping still interrupts standalone playback.
    if triggered send_input_filter_keyboard(0x100, 0, foreground);
    return consumed;
}

shortcuts_update :: () {
    if !shortcuts.enabled return;
    shortcuts_refresh_target();
    shortcuts_dispatch_next(*shortcuts, *console, shortcuts.game, shortcuts.pid, Win.GetForegroundWindow(), shortcuts_blocked());
}

shortcuts_deinit :: () {
    if shortcuts_hook UnhookWindowsHookEx(shortcuts_hook);
    shortcuts_hook = null;
    shortcuts = .{};
}

#scope_file
#import "Basic";
Win :: #import "Windows";
shortcuts_hook: *void;

Shortcut_Keyboard_Event :: struct { vk, scan, flags, time: u32; extra: u64; }

shortcuts_keyboard_hook :: (code: s32, message: u64, data: s64) -> s64 #c_call {
    push_context {
        if code >= 0 && (message == 0x100 || message == 0x104 || message == 0x101 || message == 0x105) {
            key := cast(*Shortcut_Keyboard_Event) data;
            if shortcuts_handle_key(key.vk, message == 0x100 || message == 0x104, (key.flags & 0x12) != 0,
                                     Win.GetForegroundWindow()) return 1;
        }
        return CallNextHookEx(shortcuts_hook, code, message, data);
    }
}

user32 :: #library,system "user32";
SetWindowsHookExW :: (kind: s32, callback: (code: s32, message: u64, data: s64) -> s64 #c_call,
                     instance: Win.HINSTANCE, thread: u32) -> *void #foreign user32;
UnhookWindowsHookEx :: (hook: *void) -> s32 #foreign user32;
CallNextHookEx :: (hook: *void, code: s32, message: u64, data: s64) -> s64 #foreign user32;
