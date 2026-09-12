APP_ICON_RESOURCE_ID :: 2;
TRAY_CALLBACK_MESSAGE :: 0x8001;
TRAY_ICON_ID :: 1;

Tray_Action :: enum u32 { NONE; SHOW :: 1001; HIDE :: 1002; EXIT :: 1003; }
Tray_State :: struct {
    window: Win.HWND;
    icon: Win.HICON;
    registered: bool;
    version4: bool;
    taskbar_created: u32;
    menu_requested: bool;
    menu_position: Win.POINT;
    action: Tray_Action;
}
tray: Tray_State;

tray_init :: (window: Win.HWND) -> bool {
    tray.window = window;
    tray.icon = cast(Win.HICON) LoadImageW(Win.GetModuleHandleW(null), cast(*u16) APP_ICON_RESOURCE_ID,
        IMAGE_ICON, Win.GetSystemMetrics(Win.SM_CXSMICON), Win.GetSystemMetrics(Win.SM_CYSMICON), LR_SHARED);
    if !tray.icon return false;
    tray.taskbar_created = RegisterWindowMessageW(utf8_to_wide("TaskbarCreated",, temp));
    return tray_register();
}

tray_deinit :: () {
    if tray.window {
        data := tray_icon_data();
        Shell_NotifyIconW(NIM_DELETE, *data);
    }
    // LoadImageW uses LR_SHARED; Windows owns the icon handle.
    tray = .{};
}

tray_has_request :: () -> bool {
    return tray.menu_requested || tray.action != .NONE;
}

tray_update :: () {
    if tray.window && !tray.registered tray_register();
}

tray_handle_message :: (window: Win.HWND, message: u32, wparam: u64, lparam: s64) -> bool {
    if !tray.window || window != tray.window return false;
    if tray.taskbar_created && message == tray.taskbar_created {
        tray.registered = false;
        tray_register();
        return true;
    }
    if message == Win.WM_COMMAND {
        command := cast(u32)(wparam & 0xffff);
        if command >= cast(u32) Tray_Action.SHOW && command <= cast(u32) Tray_Action.EXIT {
            tray.action = cast(Tray_Action) command;
            return true;
        }
        return false;
    }
    if message != TRAY_CALLBACK_MESSAGE return false;

    event := cast(u32)(lparam & 0xffff);
    if tray.version4 {
        if ((lparam >> 16) & 0xffff) != TRAY_ICON_ID return false;
    } else if wparam != TRAY_ICON_ID return false;

    if event == NIN_SELECT || event == NIN_KEYSELECT || event == Win.WM_LBUTTONUP {
        tray.action = .SHOW;
    } else if event == Win.WM_CONTEXTMENU || (!tray.version4 && event == Win.WM_RBUTTONUP) {
        tray.menu_requested = true;
        if tray.version4 {
            tray.menu_position.x = cast,trunc(s16) wparam;
            tray.menu_position.y = cast,trunc(s16) (wparam >> 16);
        } else {
            Win.GetCursorPos(*tray.menu_position);
        }
    }
    return true;
}

tray_process_requests :: () {
    if tray.menu_requested {
        tray.menu_requested = false;
        menu := tray_create_menu();
        if menu {
            defer DestroyMenu(menu);
            point := tray.menu_position;
            if point.x == -1 && point.y == -1 Win.GetCursorPos(*point);
            SetForegroundWindow(tray.window);
            selected := TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                point.x, point.y, 0, tray.window, null);
            PostMessageW(tray.window, Win.WM_NULL, 0, 0);
            if selected tray.action = cast(Tray_Action) selected;
        }
    }

    action := tray.action;
    tray.action = .NONE;
    if action == .SHOW overlay.show_requested = true;
    if action == .HIDE overlay_hide();
    if action == .EXIT overlay.quit_requested = true;
}

#scope_file
#import "Basic";
#import "Windows_Utf8";
Win :: #import "Windows";

tray_create_menu :: () -> Win.HMENU {
    menu := CreatePopupMenu();
    if !menu return null;
    success := AppendMenuW(menu, 0, cast(u64) Tray_Action.SHOW, utf8_to_wide("Show Console (&S)",, temp)) &&
               AppendMenuW(menu, 0, cast(u64) Tray_Action.HIDE, utf8_to_wide("Hide Console (&H)",, temp)) &&
               AppendMenuW(menu, MF_SEPARATOR, 0, null) &&
               AppendMenuW(menu, 0, cast(u64) Tray_Action.EXIT, utf8_to_wide("Quit (&X)",, temp));
    if !success {
        DestroyMenu(menu);
        return null;
    }
    return menu;
}

tray_register :: () -> bool {
    data := tray_icon_data();
    tray.registered = Shell_NotifyIconW(NIM_ADD, *data) != 0;
    if !tray.registered return false;
    data.timeout_or_version = 4;
    tray.version4 = Shell_NotifyIconW(NIM_SETVERSION, *data) != 0;
    return true;
}

tray_icon_data :: () -> Notify_Icon_Data {
    data: Notify_Icon_Data;
    data.size = size_of(Notify_Icon_Data);
    data.window = tray.window;
    data.id = TRAY_ICON_ID;
    data.flags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
    data.callback_message = TRAY_CALLBACK_MESSAGE;
    data.icon = tray.icon;
    tip := utf8_to_wide("OotSS CMD",, temp);
    for i: 0..data.tip.count-2 {
        data.tip[i] = tip[i];
        if !tip[i] break;
    }
    return data;
}

Notify_Icon_Data :: struct {
    size: u32;
    window: Win.HWND;
    id: u32;
    flags: u32;
    callback_message: u32;
    icon: Win.HICON;
    tip: [128] u16;
    state: u32;
    state_mask: u32;
    info: [256] u16;
    timeout_or_version: u32;
    info_title: [64] u16;
    info_flags: u32;
    guid: Win.GUID;
    balloon_icon: Win.HICON;
}
#assert(size_of(Notify_Icon_Data) == 976);

NIM_ADD :: 0;
NIM_DELETE :: 2;
NIM_SETVERSION :: 4;
NIF_MESSAGE :: 1;
NIF_ICON :: 2;
NIF_TIP :: 4;
NIF_SHOWTIP :: 0x80;
NIN_SELECT :: 0x0400;
NIN_KEYSELECT :: 0x0401;
IMAGE_ICON :: 1;
LR_SHARED :: 0x8000;
MF_SEPARATOR :: 0x0800;
TPM_RIGHTBUTTON :: 0x0002;
TPM_NONOTIFY :: 0x0080;
TPM_RETURNCMD :: 0x0100;

user32 :: #library,system "user32";
shell32 :: #library,system "shell32";
LoadImageW :: (instance: Win.HINSTANCE, name: *u16, type: u32, width: s32, height: s32, flags: u32) -> Win.HANDLE #foreign user32;
RegisterWindowMessageW :: (name: *u16) -> u32 #foreign user32;
Shell_NotifyIconW :: (message: u32, data: *Notify_Icon_Data) -> s32 #foreign shell32;
CreatePopupMenu :: () -> Win.HMENU #foreign user32;
AppendMenuW :: (menu: Win.HMENU, flags: u32, id: u64, text: *u16) -> s32 #foreign user32;
TrackPopupMenu :: (menu: Win.HMENU, flags: u32, x: s32, y: s32, reserved: s32, owner: Win.HWND, exclude: *Win.RECT) -> u32 #foreign user32;
DestroyMenu :: (menu: Win.HMENU) -> s32 #foreign user32;
PostMessageW :: (window: Win.HWND, message: u32, wparam: u64, lparam: s64) -> s32 #foreign user32;
SetForegroundWindow :: (window: Win.HWND) -> s32 #foreign user32;
