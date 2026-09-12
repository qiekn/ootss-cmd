noclip_install_hook :: () -> string {
    if noclip_hook return "";
    noclip_hook = SetWindowsHookExW(13, noclip_keyboard_hook, Win.GetModuleHandleW(null), 0);
    if !noclip_hook return tprint("Could not install noclip input handling (Windows error %).", Win.GetLastError());
    return "";
}

noclip_remove_hook :: () {
    if noclip_hook UnhookWindowsHookEx(noclip_hook);
    noclip_hook = null;
}

noclip_modifiers_down :: () -> bool {
    for key: s32.[Win.VK_SHIFT, Win.VK_CONTROL, Win.VK_MENU, Win.VK_LWIN, Win.VK_RWIN] {
        if Win.GetAsyncKeyState(key) < 0 return true;
    }
    return false;
}

#scope_file
#import "Basic";
Win :: #import "Windows";
noclip_hook: *void;

Noclip_Keyboard_Event :: struct { vk, scan, flags, time: u32; extra: u64; }

noclip_keyboard_hook :: (code: s32, message: u64, data: s64) -> s64 #c_call {
    push_context {
        if code >= 0 && (message == 0x100 || message == 0x104 || message == 0x101 || message == 0x105) {
            key := cast(*Noclip_Keyboard_Event) data;
            if shortcuts_handle_key(key.vk, message == 0x100 || message == 0x104, (key.flags & 0x12) != 0,
                                     Win.GetForegroundWindow()) return 1;
            if noclip_filter_key(key.vk, message == 0x100 || message == 0x104, (key.flags & 0x12) != 0,
                                 Win.GetForegroundWindow(), noclip_modifiers_down()) return 1;
        }
        return CallNextHookEx(noclip_hook, code, message, data);
    }
}

user32 :: #library,system "user32";
SetWindowsHookExW :: (kind: s32, callback: (code: s32, message: u64, data: s64) -> s64 #c_call,
                     instance: Win.HINSTANCE, thread: u32) -> *void #foreign user32;
UnhookWindowsHookEx :: (hook: *void) -> s32 #foreign user32;
CallNextHookEx :: (hook: *void, code: s32, message: u64, data: s64) -> s64 #foreign user32;
