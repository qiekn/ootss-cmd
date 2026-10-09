hud_panel_create :: (panel: *Hud_Panel) -> bool {
    if panel.window return true;
    name := utf8_to_wide("OOTSS HUD",, temp);
    instance := Win.GetModuleHandleW(null);
    wc: Win.WNDCLASSEXW;
    wc.cbSize = size_of(Win.WNDCLASSEXW);
    wc.hInstance = instance;
    wc.lpfnWndProc = hud_window_proc;
    wc.lpszClassName = name;
    if !Win.RegisterClassExW(*wc) && Win.GetLastError() != 1410 return false;
    panel.window = Win.CreateWindowExW(Win.WS_EX_LAYERED | Win.WS_EX_TOOLWINDOW | Win.WS_EX_TOPMOST |
        Win.WS_EX_NOACTIVATE | Win.WS_EX_TRANSPARENT, name, name, Win.WS_POPUP,
        0, 0, 1, 1, null, null, instance, null);
    if !panel.window return false;
    HudSetWindowDisplayAffinity(panel.window, 0x11);
    // Per-pixel alpha, without a color key or an OpenGL SwapBuffers wait.
    return true;
}

hud_panel_present :: (panel: *Hud_Panel, x: s32, y: s32, opacity: u8) -> bool {
    destination: Win.POINT = .{x, y};
    source: Win.POINT;
    size: Win.SIZE = .{panel.surface.width, panel.surface.height};
    blend: Hud_Blend_Function = .{0, 0, opacity, 1};
    if !HudUpdateLayeredWindow(panel.window, null, *destination, *size, panel.surface.dc, *source, 0, *blend, 2) {
        hud_panel_hide(panel);
        return false;
    }
    if !panel.visible Win.SetWindowPos(panel.window, Win.HWND_TOPMOST, 0, 0, 0, 0,
        Win.SWP_NOACTIVATE | Win.SWP_NOMOVE | Win.SWP_NOSIZE | Win.SWP_SHOWWINDOW);
    panel.visible = true;
    panel.x = x;
    panel.y = y;
    panel.opacity = opacity;
    return true;
}

hud_panel_hide :: (panel: *Hud_Panel) {
    if panel.window && panel.visible Win.ShowWindow(panel.window, Win.SW_HIDE);
    panel.visible = false;
}

hud_hide :: () {
    hud_panel_hide(*hud.info);
    hud_panel_hide(*hud.toast);
}

HudIsIconic :: (window: Win.HWND) -> s32 #foreign user32 "IsIconic";

#scope_file
#import "Windows_Utf8";
Win :: #import "Windows";
user32 :: #library,system "user32";
Hud_Blend_Function :: struct { operation, flags, opacity, format: u8; }
HudUpdateLayeredWindow :: (window: Win.HWND, destination_dc: Win.HDC, destination: *Win.POINT, size: *Win.SIZE,
    source_dc: Win.HDC, source: *Win.POINT, color: u32, blend: *Hud_Blend_Function, flags: u32) -> s32 #foreign user32 "UpdateLayeredWindow";
HudSetWindowDisplayAffinity :: (window: Win.HWND, affinity: u32) -> s32 #foreign user32 "SetWindowDisplayAffinity";
hud_window_proc :: (window: Win.HWND, message: u32, wparam: u64, lparam: s64) -> s64 #c_call {
    push_context {
        if message == Win.WM_NCHITTEST return -1;
        if message == Win.WM_MOUSEACTIVATE return 3;
        if message == Win.WM_ERASEBKGND return 1;
        return Win.DefWindowProcW(window, message, wparam, lparam);
    }
}
