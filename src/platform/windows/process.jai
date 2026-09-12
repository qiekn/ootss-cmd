process_window_pid :: (window: Win.HWND) -> u32 {
    pid: u32;
    GetWindowThreadProcessId(window, *pid);
    return pid;
}

process_find_window :: (executable: string, window_class: string, preferred_title: string) -> Win.HWND {
    search: Process_Window_Search = .{executable, window_class, preferred_title, null};
    EnumWindows(process_find_window_callback, cast(s64) *search);
    return search.result;
}

process_image_path :: (window: Win.HWND) -> string {
    if !window return "";
    process := OpenProcess(0x1000, 0, process_window_pid(window)); // QUERY_LIMITED_INFORMATION
    if !process return "";
    defer Win.CloseHandle(process);
    buffer: [32768] u16;
    length: u32 = buffer.count;
    if !QueryFullProcessImageNameW(process, 0, buffer.data, *length) return "";
    return wide_to_utf8(buffer.data, cast(s32) length,, temp);
}

#scope_file
#import "Basic";
#import "String";
#import "Windows_Utf8";
Win :: #import "Windows";

Process_Window_Search :: struct {
    executable, window_class, preferred_title: string;
    result: Win.HWND;
}

process_find_window_callback :: (window: Win.HWND, parameter: s64) -> s32 #c_call {
    push_context {
        search := cast(*Process_Window_Search) parameter;
        if !IsWindowVisible(window) return 1;
        class_buffer: [256] u16;
        length := GetClassNameW(window, class_buffer.data, class_buffer.count);
        if wide_to_utf8(class_buffer.data, length,, temp) != search.window_class return 1;

        pid := process_window_pid(window);
        process := OpenProcess(0x1000, 0, pid); // PROCESS_QUERY_LIMITED_INFORMATION
        if !process return 1;
        defer Win.CloseHandle(process);
        path_buffer: [2048] u16;
        path_length: u32 = path_buffer.count;
        if !QueryFullProcessImageNameW(process, 0, path_buffer.data, *path_length) return 1;
        path := wide_to_utf8(path_buffer.data, cast(s32) path_length,, temp);
        name_start: s64;
        for c: path if c == #char "/" || c == #char "\\" name_start = it_index + 1;
        if !equal_nocase(slice(path, name_start, path.count - name_start), search.executable) return 1;

        if !search.result search.result = window;
        title_buffer: [256] u16;
        title_length := GetWindowTextW(window, title_buffer.data, title_buffer.count);
        if wide_to_utf8(title_buffer.data, title_length,, temp) == search.preferred_title {
            search.result = window;
            return 0;
        }
        return 1;
    }
}

user32 :: #library,system "user32";
kernel32 :: #library,system "kernel32";
EnumWindows :: (callback: (window: Win.HWND, parameter: s64) -> s32 #c_call, parameter: s64) -> s32 #foreign user32;
GetClassNameW :: (window: Win.HWND, text: *u16, capacity: s32) -> s32 #foreign user32;
GetWindowTextW :: (window: Win.HWND, text: *u16, capacity: s32) -> s32 #foreign user32;
GetWindowThreadProcessId :: (window: Win.HWND, pid: *u32) -> u32 #foreign user32;
IsWindowVisible :: (window: Win.HWND) -> s32 #foreign user32;
OpenProcess :: (access: u32, inherit: s32, pid: u32) -> Win.HANDLE #foreign kernel32;
QueryFullProcessImageNameW :: (process: Win.HANDLE, flags: u32, path: *u16, length: *u32) -> s32 #foreign kernel32;
