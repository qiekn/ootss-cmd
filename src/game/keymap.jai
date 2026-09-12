Game_Key :: struct { vk: u32; scan: u16; extended: bool; }
Game_Keymap :: struct {
    up, down, left, right: Game_Key;
    undo, activate, switch_character, dragon, take, restart, fast, slow: Game_Key;
}

game_key_for_vk :: (vk: u32) -> Game_Key {
    code := MapVirtualKeyW(vk, 4); // MAPVK_VK_TO_VSC_EX preserves E0 for arrow keys.
    extended := (code & 0xff00) == 0xe000 || (vk >= 0x21 && vk <= 0x28) ||
                vk == 0x2d || vk == 0x2e || vk == 0xa3 || vk == 0xa5;
    return .{vk, cast(u16)(code & 0xff), extended};
}

game_keymap_defaults :: () -> Game_Keymap {
    return .{game_key_for_vk(#char "W"), game_key_for_vk(#char "S"),
             game_key_for_vk(#char "A"), game_key_for_vk(#char "D"),
             game_key_for_vk(#char "Z"), game_key_for_vk(#char "X"),
             game_key_for_vk(#char "C"), game_key_for_vk(#char "F"),
             game_key_for_vk(#char "V"), game_key_for_vk(#char "R"),
             game_key_for_vk(0x20), game_key_for_vk(0xa2)};
}

game_keymap_parse :: (source: string, map: *Game_Keymap, only_action: string = "") -> string {
    lines := split(source, #char "\n");
    defer free(lines.data);
    keyboard := false;
    for raw: lines {
        line := trim(raw);
        if !line.count || line[0] == #char "#" continue;
        if line[0] == #char "[" {
            keyboard = equal_nocase(line, "[UserKeyboard]");
            continue;
        }
        if !keyboard continue;
        end: s64;
        while end < line.count && line[end] != #char " " && line[end] != #char "\t" end += 1;
        if end == line.count continue;
        name := slice(line, 0, end);
        action := trim(slice(line, end, line.count - end));
        comment := find_index_from_left(action, "#");
        if comment >= 0 action = trim(slice(action, 0, comment));
        if only_action.count && !equal_nocase(action, only_action) continue;
        target: *Game_Key;
        if equal_nocase(action, "Forward")         target = *map.up;
        if equal_nocase(action, "Backward")        target = *map.down;
        if equal_nocase(action, "Left")            target = *map.left;
        if equal_nocase(action, "Right")           target = *map.right;
        if equal_nocase(action, "Undo")            target = *map.undo;
        if equal_nocase(action, "Activate")        target = *map.activate;
        if equal_nocase(action, "CharacterSwitch") target = *map.switch_character;
        if equal_nocase(action, "FriendlyDragon")  target = *map.dragon;
        if equal_nocase(action, "TakeOrDrop")      target = *map.take;
        if equal_nocase(action, "Restart")         target = *map.restart;
        if equal_nocase(action, "HoldForFastTime") target = *map.fast;
        if equal_nocase(action, "HoldForSlowTime") target = *map.slow;
        if !target continue;
        key := game_parse_key_name(name);
        if !key.scan return tprint("Unsupported key '%' for % in User.keymap.", name, action);
        target.* = key;
    }
    return "";
}

game_keymap_load :: (map: *Game_Keymap, only_action: string = "") -> (message: string, ready: bool) {
    map.* = game_keymap_defaults();
    // The Known Folder API also supports relocated Saved Games folders.
    saved_games := Win.GUID.{0x4c5c32ff, 0xbb9d, 0x43b0, .[0xb5, 0xb4, 0x2d, 0x72, 0xe5, 0x4e, 0xaa, 0xa4]};
    folder: *u16;
    if SHGetKnownFolderPath(*saved_games, 0, null, *folder) < 0 return "Could not locate Saved Games; using default keyboard bindings.", true;
    defer CoTaskMemFree(folder);
    length: s32;
    while folder[length] length += 1;
    path := tprint("%/Order of the Sinking Star/User.keymap", wide_to_utf8(folder, length,, temp));
    text, success := read_entire_file(path, log_errors = false);
    if !success return "User.keymap was not found; using the game's default keyboard bindings.", true;
    defer free(text);
    error := game_keymap_parse(text, map, only_action);
    return error, !error.count;
}

game_key_for_symbol :: (map: *Game_Keymap, symbol: u8) -> Game_Key {
    if symbol == {
        case #char "U"; return map.up;
        case #char "D"; return map.down;
        case #char "L"; return map.left;
        case #char "R"; return map.right;
        case #char "C"; return map.switch_character;
        case #char "X"; return map.activate;
        case #char "F"; return map.dragon;
        case #char "V"; return map.take;
    }
    if symbol >= #char "0" && symbol <= #char "9" return game_key_for_vk(symbol);
    return .{};
}

game_symbol_for_vk :: (map: *Game_Keymap, vk: u32) -> u8 {
    for symbol: "UDLRCXFV0123456789" if game_key_for_symbol(map, symbol).vk == vk return symbol;
    return 0;
}

#scope_file
#import "Basic";
#import "String";
#import "File";
#import "Windows_Utf8";
Win :: #import "Windows";

game_parse_key_name :: (name: string) -> Game_Key {
    if name.count == 1 {
        c := name[0];
        if c >= #char "a" && c <= #char "z" c -= #char "a" - #char "A";
        if (c >= #char "A" && c <= #char "Z") || (c >= #char "0" && c <= #char "9") return game_key_for_vk(c);
    }
    Key_Name :: struct { name: string; vk: u32; }
    for key: Key_Name.[.{"Space", 0x20}, .{"Shift", 0xa0}, .{"Control", 0xa2}, .{"Alt", 0xa4},
        .{"Tab", 9}, .{"Enter", 13}, .{"Backspace", 8}, .{"Up", 0x26}, .{"Down", 0x28},
        .{"Left", 0x25}, .{"Right", 0x27}, .{"Escape", 0x1b}] {
        if equal_nocase(name, key.name) return game_key_for_vk(key.vk);
    }
    return .{};
}

user32 :: #library,system "user32";
shell32 :: #library,system "shell32";
ole32 :: #library,system "ole32";
MapVirtualKeyW :: (code: u32, mode: u32) -> u32 #foreign user32;
SHGetKnownFolderPath :: (folder: *Win.GUID, flags: u32, token: Win.HANDLE, path: **u16) -> s32 #foreign shell32;
CoTaskMemFree :: (memory: *void) #foreign ole32;
