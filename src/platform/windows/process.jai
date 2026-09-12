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

Process_Module :: struct { base, size: u64; }
Process_Memory :: struct {
    handle: Win.HANDLE;
    module: Process_Module;
}

process_open_memory :: (window: Win.HWND, executable: string, writable := false)
                       -> (memory: Process_Memory, error: string) {
    pid := process_window_pid(window);
    if !pid return .{}, "The game process is no longer available.";
    access: u32 = 0x1000 | 0x0010; // QUERY_LIMITED_INFORMATION | VM_READ
    if writable access |= 0x0020 | 0x0008; // VM_WRITE | VM_OPERATION
    handle := OpenProcess(access, 0, pid);
    if !handle return .{}, tprint("Could not open the game for % (Windows error %).",
                                 ifx writable then "position writing" else "reading", Win.GetLastError());
    module, error := process_find_module(pid, executable);
    if error.count { Win.CloseHandle(handle); return .{}, error; }
    return .{handle = handle, module = module}, "";
}

process_close_memory :: (memory: *Process_Memory) {
    if memory.handle Win.CloseHandle(memory.handle);
    memory.* = .{};
}

process_memory_range_valid :: (address: u64, bytes: u64) -> bool {
    last: u64 = 0x0000_7fff_ffff_ffff;
    return address >= 0x10000 && address <= last && bytes > 0 && bytes - 1 <= last - address;
}

process_module_contains :: (module: Process_Module, address: u64, bytes: u64) -> bool {
    return address >= module.base && bytes <= module.size && address - module.base <= module.size - bytes;
}

process_read_memory :: (process: Win.HANDLE, address: u64, buffer: *void, bytes: u64) -> bool {
    if !process_memory_range_valid(address, bytes) return false;
    received: u64;
    return ReadProcessMemory(process, cast(*void) address, buffer, bytes, *received) != 0 && received == bytes;
}

process_write_memory :: (process: Win.HANDLE, address: u64, buffer: *void, bytes: u64)
                        -> (success: bool, written: u64) {
    if !process_memory_range_valid(address, bytes) return false, 0;
    written: u64;
    success := WriteProcessMemory(process, cast(*void) address, buffer, bytes, *written) != 0;
    return success && written == bytes, written;
}

// Read the executable's mapped code section; callers own the returned buffer.
process_read_module_code :: (memory: Process_Memory) -> (code: [] u8, rva: u64, error: string) {
    dos: [64] u8;
    if !process_module_contains(memory.module, memory.module.base, dos.count) ||
       !process_read_memory(memory.handle, memory.module.base, *dos, dos.count) ||
       dos[0] != #char "M" || dos[1] != #char "Z" return .[], 0, "Invalid game executable header.";
    pe_rva := (cast(*u32)(dos.data + 0x3c)).*;
    header: [26] u8;
    pe := memory.module.base + pe_rva;
    if !process_module_contains(memory.module, pe, header.count) ||
       !process_read_memory(memory.handle, pe, *header, header.count) ||
       (cast(*u32) header.data).* != 0x00004550 ||
       (cast(*u16)(header.data + 4)).* != 0x8664 ||
       (cast(*u16)(header.data + 24)).* != 0x20b return .[], 0, "Expected a 64-bit Windows game executable.";
    count := (cast(*u16)(header.data + 6)).*;
    optional_size := (cast(*u16)(header.data + 20)).*;
    if count == 0 || count > 96 || optional_size < 0xf0 return .[], 0, "Invalid game section table.";
    sections := NewArray(count, Process_PE_Section);
    defer free(sections.data);
    table := pe + 24 + optional_size;
    bytes := cast(u64) sections.count * size_of(Process_PE_Section);
    if !process_module_contains(memory.module, table, bytes) ||
       !process_read_memory(memory.handle, table, sections.data, bytes) return .[], 0, "Could not read the game section table.";
    for section: sections {
        name: string = .{data = section.name.data, count = section.name.count};
        if name != ".text\0\0\0" continue;
        address := memory.module.base + section.rva;
        if !(section.flags & 0x20000000) || !section.virtual_size || section.virtual_size > 64 * 1024 * 1024 ||
           !process_module_contains(memory.module, address, section.virtual_size) return .[], 0, "Invalid game code section.";
        code := NewArray(section.virtual_size, u8);
        if !process_read_memory(memory.handle, address, code.data, cast(u64) code.count) {
            free(code.data);
            return .[], 0, "Could not read the game code section.";
        }
        return code, section.rva, "";
    }
    return .[], 0, "Could not find the game's code section.";
}

#scope_file
#import "Basic";
#import "String";
#import "Windows_Utf8";
Win :: #import "Windows";

process_find_module :: (pid: u32, executable: string) -> (module: Process_Module, error: string) {
    snapshot: Win.HANDLE;
    for 0..3 {
        snapshot = CreateToolhelp32Snapshot(0x00000008 | 0x00000010, pid);
        if snapshot != cast(Win.HANDLE) -1 break;
        if Win.GetLastError() != 24 break; // ERROR_BAD_LENGTH: the module list changed; retry.
    }
    if snapshot == cast(Win.HANDLE) -1 {
        return .{}, tprint("Could not inspect the game's modules (Windows error %).", Win.GetLastError());
    }
    defer Win.CloseHandle(snapshot);
    entry: Process_Module_Entry;
    entry.size = size_of(Process_Module_Entry);
    more := Module32FirstW(snapshot, *entry);
    while more {
        length: s32;
        while length < entry.name.count && entry.name[length] length += 1;
        if equal_nocase(wide_to_utf8(entry.name.data, length,, temp), executable) {
            return .{base = cast(u64) entry.base, size = entry.base_size}, "";
        }
        more = Module32NextW(snapshot, *entry);
    }
    return .{}, tprint("Could not find % in the game's module list.", executable);
}

Process_Module_Entry :: struct {
    size, module_id, process_id, global_usage, process_usage: u32;
    base: *u8;
    base_size: u32;
    module: Win.HMODULE;
    name: [256] u16;
    path: [260] u16;
}
#assert(size_of(Process_Module_Entry) == 1080);

Process_PE_Section :: struct {
    name: [8] u8;
    virtual_size, rva, raw_size, raw_offset, relocations, line_numbers: u32;
    relocation_count, line_count: u16;
    flags: u32;
}
#assert(size_of(Process_PE_Section) == 40);

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
ReadProcessMemory :: (process: Win.HANDLE, address: *void, buffer: *void, bytes: u64, received: *u64) -> s32 #foreign kernel32;
WriteProcessMemory :: (process: Win.HANDLE, address: *void, buffer: *void, bytes: u64, written: *u64) -> s32 #foreign kernel32;
CreateToolhelp32Snapshot :: (flags: u32, pid: u32) -> Win.HANDLE #foreign kernel32;
Module32FirstW :: (snapshot: Win.HANDLE, entry: *Process_Module_Entry) -> s32 #foreign kernel32;
Module32NextW :: (snapshot: Win.HANDLE, entry: *Process_Module_Entry) -> s32 #foreign kernel32;
