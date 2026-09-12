//
// @TODO Hey, qiekn. We need to figure out pointer address and offset of player's position in overward
//

GAME_POSITION_POINTER_RVA :: 0x009af218;

game_read_position :: () -> (position: Game_Position, error: string) {
    position: Game_Position;
    window := find_game_window();
    if !window return position, "Game not found: sinking_star.exe.";
    pid: u32;
    GetWindowThreadProcessId(window, *pid);
    process := OpenProcess(0x1000 | 0x0010, 0, pid); // QUERY_LIMITED_INFORMATION | VM_READ
    if !process return position, tprint("Could not read the game process (Windows error %).", Win.GetLastError());
    defer Win.CloseHandle(process);

    base, error := game_module_base(pid);
    if error.count return position, error;
    position, error = game_read_position_from(process, base);
    return position, error;
}

game_read_position_from :: (process: Win.HANDLE, base: u64) -> (position: Game_Position, error: string) {
    position: Game_Position;
    pointer: u64;
    received: u64;
    if !ReadProcessMemory(process, cast(*void)(base + GAME_POSITION_POINTER_RVA), *pointer, 8, *received) || received != 8 {
        return position, "Could not read the position pointer. The game may still be loading.";
    }
    if !pointer return position, "Position is unavailable while the game is loading.";
    // Cheat Engine's one-level pointer: *(module + RVA), then floats at +0/+4/+8.
    if !ReadProcessMemory(process, cast(*void) pointer, *position, size_of(Game_Position), *received) || received != size_of(Game_Position) {
        return position, "Could not read the game's position coordinates.";
    }
    for coordinate: position {
        bits := (cast(*u32) *coordinate).*;
        if (bits & 0x7f800000) == 0x7f800000 return position, "The game returned an invalid position.";
    }
    return position, "";
}

game_position_text :: (position: Game_Position) -> string {
    return tprint("(%, %, %)", formatFloat(position[0], mode = .SHORTEST),
                  formatFloat(position[1], mode = .SHORTEST), formatFloat(position[2], mode = .SHORTEST));
}

#scope_file
#import "Basic";
#import "String";
#import "Windows_Utf8";
Win :: #import "Windows";

game_module_base :: (pid: u32) -> (base: u64, error: string) {
    snapshot := CreateToolhelp32Snapshot(0x00000008 | 0x00000010, pid);
    if snapshot == cast(Win.HANDLE) -1 return 0, "Could not inspect the game's modules.";
    defer Win.CloseHandle(snapshot);
    entry: Module_Entry;
    entry.size = size_of(Module_Entry);
    more := Module32FirstW(snapshot, *entry);
    while more {
        length: s32;
        while length < entry.name.count && entry.name[length] length += 1;
        name := wide_to_utf8(entry.name.data, length,, temp);
        if equal_nocase(name, "sinking_star.exe") return cast(u64) entry.base, "";
        more = Module32NextW(snapshot, *entry);
    }
    return 0, "Could not find sinking_star.exe in the game's module list.";
}

Module_Entry :: struct {
    size, module_id, process_id, global_usage, process_usage: u32;
    base: *u8;
    base_size: u32;
    module: Win.HMODULE;
    name: [256] u16;
    path: [260] u16;
}
#assert(size_of(Module_Entry) == 1080);
#assert(size_of(Game_Position) == 12);

user32 :: #library,system "user32";
kernel32 :: #library,system "kernel32";
GetWindowThreadProcessId :: (window: Win.HWND, pid: *u32) -> u32 #foreign user32;
OpenProcess :: (access: u32, inherit: s32, pid: u32) -> Win.HANDLE #foreign kernel32;
ReadProcessMemory :: (process: Win.HANDLE, address: *void, buffer: *void, bytes: u64, received: *u64) -> s32 #foreign kernel32;
CreateToolhelp32Snapshot :: (flags: u32, pid: u32) -> Win.HANDLE #foreign kernel32;
Module32FirstW :: (snapshot: Win.HANDLE, entry: *Module_Entry) -> s32 #foreign kernel32;
Module32NextW :: (snapshot: Win.HANDLE, entry: *Module_Entry) -> s32 #foreign kernel32;
