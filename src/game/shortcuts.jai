Shortcut_Modifiers :: enum_flags u32 { CTRL; ALT; SHIFT; WIN; }

Command_Shortcut :: struct {
    name: string;
    vk: u32;
    modifiers: Shortcut_Modifiers;
    command: string;
    consume: bool;
}

Shortcut_Request :: struct {
    index: s64;
    game: Win.HWND;
    pid, key: u32;
}

Shortcut_State :: struct {
    enabled: bool;
    game: Win.HWND;
    pid: u32;
    down, consumed: [256] bool;
    queue: [64] Shortcut_Request;
    queue_start, queue_count: s64;
    overflow: bool;
}

shortcuts: Shortcut_State;

shortcut_base_key :: (name: string) -> u32 {
    if name.count == 1 {
        c := name[0];
        if c >= #char "a" && c <= #char "z" c -= #char "a" - #char "A";
        if (c >= #char "A" && c <= #char "Z") || (c >= #char "0" && c <= #char "9") return c;
    }
    if name.count >= 2 && name.count <= 3 && (name[0] == #char "F" || name[0] == #char "f") {
        number: u32;
        for c: slice(name, 1, name.count - 1) {
            if c < #char "0" || c > #char "9" return 0;
            number = number * 10 + c - #char "0";
        }
        if number >= 1 && number <= 24 return 0x70 + number - 1;
    }
    Key_Name :: struct { name: string; vk: u32; }
    for key: Key_Name.[
        .{"Space", 0x20}, .{"Enter", 0x0d}, .{"Return", 0x0d}, .{"Tab", 0x09}, .{"Backspace", 0x08},
        .{"Escape", 0x1b}, .{"Esc", 0x1b}, .{"Up", 0x26}, .{"Down", 0x28}, .{"Left", 0x25}, .{"Right", 0x27},
        .{"Home", 0x24}, .{"End", 0x23}, .{"PageUp", 0x21}, .{"PgUp", 0x21}, .{"PageDown", 0x22}, .{"PgDn", 0x22},
        .{"Insert", 0x2d}, .{"Ins", 0x2d}, .{"Delete", 0x2e}, .{"Del", 0x2e}, .{"CapsLock", 0x14},
        .{"NumLock", 0x90}, .{"ScrollLock", 0x91}, .{"Pause", 0x13}, .{"PrintScreen", 0x2c}
    ] if equal_nocase(name, key.name) return key.vk;
    return 0;
}

shortcut_key_parse :: (source: string) -> (vk: u32, modifiers: Shortcut_Modifiers, error: string) {
    modifiers: Shortcut_Modifiers;
    start: s64;
    for i: 0..source.count {
        if i != source.count && source[i] != #char "+" continue;
        part := trim(slice(source, start, i - start));
        if !part.count return 0, modifiers, "Expected a key, for example M or Ctrl+Shift+M.";
        if i == source.count {
            vk := shortcut_base_key(part);
            if !vk return 0, modifiers, tprint("Unknown shortcut key '%'. Use a letter, digit, F1-F24 or a named key.", part);
            return vk, modifiers, "";
        }
        modifier: Shortcut_Modifiers;
        if equal_nocase(part, "Ctrl") || equal_nocase(part, "Control") modifier = .CTRL;
        else if equal_nocase(part, "Alt") modifier = .ALT;
        else if equal_nocase(part, "Shift") modifier = .SHIFT;
        else if equal_nocase(part, "Win") modifier = .WIN;
        else return 0, modifiers, tprint("Unknown shortcut modifier '%'. Use Ctrl, Alt, Shift or Win.", part);
        if modifiers & modifier return 0, modifiers, "A shortcut modifier cannot be repeated.";
        modifiers |= modifier;
        start = i + 1;
    }
    return 0, modifiers, "Expected a shortcut key.";
}

shortcuts_free_bindings :: (bindings: *[..] Command_Shortcut) {
    for binding: bindings.* { free(binding.name); free(binding.command); }
    array_free(bindings.*);
}

shortcut_config_assignment :: (config: *Console_Config, source: string, consume: bool) -> string {
    name, command, error := console_parse_assignment(source);
    defer free(command);
    if error.count return error;
    vk, modifiers, key_error := shortcut_key_parse(name);
    if key_error.count return key_error;
    for *binding: config.shortcuts {
        if binding.vk != vk || binding.modifiers != modifiers continue;
        free(binding.name);
        free(binding.command);
        binding.* = .{copy_string(name), vk, modifiers, copy_string(command), consume};
        return "";
    }
    array_add(*config.shortcuts, .{copy_string(name), vk, modifiers, copy_string(command), consume});
    return "";
}

shortcut_physical_key :: (vk: u32) -> u32 {
    if vk == 0x10 return 0xa0; // Generic modifiers share the left key's physical state.
    if vk == 0x11 return 0xa2;
    if vk == 0x12 return 0xa4;
    return vk;
}

shortcuts_modifiers :: (state: *Shortcut_State) -> Shortcut_Modifiers {
    result: Shortcut_Modifiers;
    if state.down[0xa2] || state.down[0xa3] result |= .CTRL;
    if state.down[0xa4] || state.down[0xa5] result |= .ALT;
    if state.down[0xa0] || state.down[0xa1] result |= .SHIFT;
    if state.down[0x5b] || state.down[0x5c] result |= .WIN;
    return result;
}

shortcuts_input_released :: (state: *Shortcut_State, key: u32) -> bool {
    return key < state.down.count && !state.down[key] && !state.down[0x0d] && !shortcuts_modifiers(state);
}

shortcuts_clear_queue :: (state: *Shortcut_State) {
    state.queue_start = 0;
    state.queue_count = 0;
    state.overflow = false;
    // Retain physical/consumed state until release, including across focus loss.
}

shortcuts_set_target :: (state: *Shortcut_State, game: Win.HWND, pid: u32, foreground: Win.HWND, blocked := false) {
    if game != state.game || pid != state.pid || !game || !pid || foreground != game || blocked || !state.enabled {
        shortcuts_clear_queue(state);
    }
    state.game = game;
    state.pid = pid;
}

// Called by every input hook before its own game/editor behavior. No I/O, allocation or command execution here.
shortcut_filter_key :: (state: *Shortcut_State, bindings: [] Command_Shortcut, vk: u32, down: bool,
                        injected: bool, foreground: Win.HWND, blocked := false) -> (consume: bool, triggered: bool) {
    if injected || !state.enabled || vk >= state.down.count return false, false;
    vk = shortcut_physical_key(vk);
    was_down := state.down[vk];
    state.down[vk] = down;
    if !state.game || !state.pid || foreground != state.game || blocked shortcuts_clear_queue(state);
    if !down {
        consumed := state.consumed[vk];
        state.consumed[vk] = false;
        return consumed, false;
    }
    if was_down return state.consumed[vk], false; // Autorepeat and observations from other hooks.
    if !state.game || !state.pid || foreground != state.game || blocked return false, false;
    modifiers := shortcuts_modifiers(state);
    for binding: bindings {
        if binding.vk != vk || binding.modifiers != modifiers continue;
        state.consumed[vk] = binding.consume;
        if state.queue_count < state.queue.count {
            offset := (state.queue_start + state.queue_count) % state.queue.count;
            state.queue[offset] = .{index = it_index, game = state.game, pid = state.pid, key = vk};
            state.queue_count += 1;
        } else state.overflow = true;
        return binding.consume, true;
    }
    return false, false;
}

shortcut_is_position_command :: (state: *Console_State, source: string) -> bool {
    expanded, error := console_expand_aliases(state, source);
    defer free(expanded);
    if error.count return false;
    cursor: s64;
    name := console_next_argument(expanded, *cursor);
    if equal_nocase(name, "move") || equal_nocase(name, "move_xy") ||
       equal_nocase(name, "back") || equal_nocase(name, "tp") return true;
    return equal_nocase(name, "set") && equal_nocase(console_next_argument(expanded, *cursor), "position");
}

shortcuts_dispatch_next :: (state: *Shortcut_State, console: *Console_State, game: Win.HWND, pid: u32,
                            foreground: Win.HWND, blocked := false) -> bool {
    shortcuts_set_target(state, game, pid, foreground, blocked);
    if state.overflow {
        shortcuts_clear_queue(state);
        console_write(console, "Shortcut queue filled; release the keys and try again.", .ERROR);
        return false;
    }
    if !state.queue_count || console.pending_action != .NONE || console.pending_send.count ||
       console.pending_position_change return false;
    request := state.queue[state.queue_start];
    if request.game != game || request.pid != pid || request.index < 0 || request.index >= console.config.shortcuts.count {
        shortcuts_clear_queue(state);
        return false;
    }
    binding := console.config.shortcuts[request.index];
    // Teleports respond on keydown. Other commands wait for the physical chord to finish before they can send input
    // or focus a text field. Injected playback modifiers never delay or retrigger a shortcut.
    if !shortcuts_input_released(state, request.key) && !shortcut_is_position_command(console, binding.command) return false;
    state.queue_start = (state.queue_start + 1) % state.queue.count;
    state.queue_count -= 1;
    console.submission = .{shortcut = true, game = game, pid = pid, trigger_key = request.key};
    console_execute_command(console, binding.command);
    return true;
}

#scope_file
#import "Basic";
#import "String";
Win :: #import "Windows";
