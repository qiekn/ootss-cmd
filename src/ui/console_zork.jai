Zork_Input_Kind :: enum { BUSY; LINE; FILENAME; OVERWRITE; }

console_submit_zork :: (console: *Console_State, line: string) {
    // Bare aliases apply only to game commands; clear/cl remain valid names at a save-file prompt.
    if console.zork_input_kind == .LINE && (equal_nocase(line, "clear") || equal_nocase(line, "cl")) {
        command_clear(console, "");
        console_remember_input(console, line);
        console_finish_input(console);
        return;
    }
    if line.count && line[0] == #char "/" {
        position: s64;
        command := console_next_argument(line, *position);
        arguments := trim(slice(line, position, line.count - position));

        if      equal_nocase(command, "/back")  && !arguments.count { console.pending_action = .ZORK_BACK; }
        else if equal_nocase(command, "/help")  && !arguments.count { console_zork_help(console); }
        else if equal_nocase(command, "/clear") && !arguments.count { command_clear(console, ""); }
        else if equal_nocase(command, "/toggle") { command_toggle(console, arguments); }
        else {
            console_write(console, "Use /back, /help, /clear or /toggle full|small|normal|mini.", .ERROR);
            return;
        }
        console_remember_input(console, line);
        console_finish_input(console);
        return;
    }
    // Empty input is significant at the native filename prompt: it selects the default save.
    if console.zork_input_kind == .BUSY || console.pending_action != .NONE return;
    free(console.pending_zork_input);
    console.pending_zork_input = copy_string(line);
    console.pending_action = .ZORK_INPUT;
    console.zork_input_kind = .BUSY;
    console_write(console, tprint("$ %", line), .COMMAND);
    console_remember_input(console, line);
    console_finish_input(console);
}

console_zork_help :: (console: *Console_State) {
    print_help :: (console: *Console_State, text: string) {
        console_write(console, text, .INFO);
    }

    print_help(console, "save    <save_name>, or press Enter to use the default (.sav).");
    print_help(console, "restore <save_name>, or press Enter to use the default (.sav).");
    print_help(console, "                     note: save files are in data/zork/.");
    print_help(console, "quit: end Zork. /back: return to the console; type zork to resume.");
    print_help(console, "clear (cl, /clear): clear output. /toggle full|small|normal|mini: resize. Esc: hide.");
}

zork_save_filename :: (input: string, default_name: string) -> (name: string, error: string) {
    name := trim(input);
    if !name.count name = default_name;
    if !name.count name = "zork1.sav";
    if name == "." || name == ".." || name[name.count - 1] == #char "." {
        return "", "Enter a save filename, for example mailbox.sav.";
    }
    for c: name {
        if c < 32 || c == 127 || c == #char "/" || c == #char "\\" || c == #char ":" ||
           c == #char "<" || c == #char ">" || c == #char "\"" || c == #char "|" ||
           c == #char "?" || c == #char "*" {
            return "", "Use a filename without path separators or Windows filename punctuation. Saves stay in data/zork/.";
        }
    }
    stem_end := name.count;
    for c: name if c == #char "." { stem_end = it_index; break; }
    stem := trim(slice(name, 0, stem_end));
    for reserved: string.["CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"] {
        if equal_nocase(stem, reserved) return "", "That name is reserved by Windows. Choose another save name.";
    }
    if stem.count == 4 && (equal_nocase(slice(stem, 0, 3), "COM") || equal_nocase(slice(stem, 0, 3), "LPT")) &&
       stem[3] >= #char "0" && stem[3] <= #char "9" {
        return "", "That name is reserved by Windows. Choose another save name.";
    }
    // Always use .sav so a save cannot overwrite the interpreter, story or map.
    if name.count < 4 || !equal_nocase(slice(name, name.count - 4, 4), ".sav") name = tprint("%.sav", name);
    return name, "";
}

#scope_file
#import "Basic";
#import "String";
