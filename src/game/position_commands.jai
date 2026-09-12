console_position_command_ready :: (state: *Console_State) -> bool {
    if state.pending_action != .NONE || state.pending_send.count || state.pending_position_change {
        console_write(state, "A command is already waiting to run.", .ERROR);
        return false;
    }
    return true;
}

console_parse_coordinates :: (arguments: string, axes: string, required: s64) -> (position: Game_Position, error: string) {
    position: Game_Position;
    cursor: s64;
    for axis: axes {
        argument := console_next_argument(arguments, *cursor);
        if !argument.count {
            if it_index >= required break;
            return position, "Missing coordinates.";
        }
        value, success, remainder := string_to_float64(argument);
        if !success || remainder.count || !is_finite(value) || abs(value) > GAME_POSITION_LIMIT {
            return position, tprint("% must be a finite number between -1000000 and 1000000.", slice(axes, it_index, 1));
        }
        position[axis - #char "x"] = cast(float) value;
    }
    if console_next_argument(arguments, *cursor).count return position, "Too many coordinates.";
    return position, "";
}

console_queue_position_request :: (state: *Console_State, arguments: string, axes: string, required: s64,
                                   relative: bool, usage: string) {
    position, error := console_parse_coordinates(arguments, axes, required);
    if error.count { console_write(state, tprint("% Usage: %", error, usage), .ERROR); return; }
    if !console_position_command_ready(state) return;
    if relative && (axes == "x" || axes == "y") {
        delta := position[axes[0] - #char "x"];
        if delta == 0 { console_write(state, "No movement: the offset is zero."); return; }
    }
    state.pending_position = position;
    state.pending_position_relative = relative;
    state.pending_position_take = false;
    state.pending_action = .SET_POSITION;
}

command_move :: (state: *Console_State, arguments: string) {
    cursor: s64;
    option := console_next_argument(arguments, *cursor);
    axis: string;
    if equal_nocase(option, "-x") axis = "x";
    else if equal_nocase(option, "-y") axis = "y";
    else if equal_nocase(option, "-z") axis = "z";
    if axis.count {
        console_queue_position_request(state, slice(arguments, cursor, arguments.count - cursor), axis, 1, true,
                                       tprint("move -% <value>", axis));
        return;
    }
    console_queue_position_request(state, arguments, "xyz", 2, true, "move <dx> <dy> [dz] or move -x|-y|-z <value>");
}

command_move_xy :: (state: *Console_State, arguments: string) {
    console_queue_position_request(state, arguments, "xy", 2, true, "move_xy <dx> <dy>");
}

command_switch :: (state: *Console_State, arguments: string) {
    cursor: s64;
    name := console_next_argument(arguments, *cursor);
    if !name.count || console_next_argument(arguments, *cursor).count {
        console_write(state, "Usage: switch <level_name>", .ERROR);
        return;
    }
    if !console_position_command_ready(state) return;
    free(state.pending_switch_level);
    state.pending_switch_level = copy_string(name);
    state.pending_action = .SWITCH_LEVEL;
}

console_prepare_switch :: (state: *Console_State, filename := "data/marker.json") {
    catalog: Solutions_Database;
    defer solutions_free(*catalog);
    error := level_catalog_load(*catalog, filename);
    if error.count { console_write(state, error, .ERROR); return; }
    index := solution_find_name(*catalog, state.pending_switch_level, ignore_case = true);
    if index < 0 { console_write(state, tprint("Unknown level entrance: %.", state.pending_switch_level), .ERROR); return; }
    state.pending_position = catalog.entries[index].position;
    state.pending_position_relative = false;
    state.pending_position_take = true;
    state.pending_position_change = true;
}

console_queue_marker_action :: (state: *Console_State, action: Console_Action, name := "", new_name := "") -> bool {
    for candidate: string.[name, new_name] {
        if candidate.count && !position_marker_name_valid(candidate) {
            console_write(state, "Marker names must use letters, digits, Unicode, _, - or . (up to 128 bytes).", .ERROR);
            return false;
        }
    }
    if !console_position_command_ready(state) return false;
    free(state.pending_marker_name);
    free(state.pending_marker_new_name);
    state.pending_marker_name = copy_string(name);
    state.pending_marker_new_name = copy_string(new_name);
    state.pending_action = action;
    return true;
}

command_mark :: (state: *Console_State, arguments: string) {
    tokens: [4] string;
    count, cursor: s64;
    while true {
        argument := console_next_argument(arguments, *cursor);
        if !argument.count break;
        if count == tokens.count { console_write(state, "Usage: mark [name] [x y z]", .ERROR); return; }
        tokens[count] = argument;
        count += 1;
    }
    if count == 2 { console_write(state, "Usage: mark [name] [x y z]", .ERROR); return; }
    name := ifx count == 1 || count == 4 then tokens[0] else "";
    position: Game_Position;
    if count >= 3 {
        start := ifx count == 4 then 1 else 0;
        error: string;
        position, error = console_parse_coordinates(tprint("% % %", tokens[start], tokens[start + 1], tokens[start + 2]), "xyz", 3);
        if error.count { console_write(state, error, .ERROR); return; }
    }
    if !console_queue_marker_action(state, .MARK_POSITION, name) return;
    state.pending_position = position;
    state.pending_marker_current = count < 3;
}

command_add_markers :: (state: *Console_State, arguments: string) {
    cursor: s64;
    subject := console_next_argument(arguments, *cursor);
    position, error := console_parse_coordinates(slice(arguments, cursor, arguments.count - cursor), "xyz", 3);
    if !equal_nocase(subject, "markers") || error.count {
        console_write(state, "Usage: add markers <x> <y> <z>", .ERROR);
        return;
    }
    if !console_queue_marker_action(state, .MARK_POSITION) return;
    state.pending_position = position;
    state.pending_marker_current = false;
}

command_list_markers :: (state: *Console_State, arguments: string) {
    if !equal_nocase(trim(arguments), "markers") { console_write(state, "Usage: list markers", .ERROR); return; }
    console_queue_marker_action(state, .LIST_MARKERS);
}

command_remove_markers :: (state: *Console_State, arguments: string) {
    cursor: s64;
    subject := console_next_argument(arguments, *cursor);
    name := console_next_argument(arguments, *cursor);
    if !equal_nocase(subject, "markers") || !name.count || console_next_argument(arguments, *cursor).count {
        console_write(state, "Usage: remove markers <name>", .ERROR);
        return;
    }
    console_queue_marker_action(state, .REMOVE_MARKER, name);
}

command_rename_marker :: (state: *Console_State, arguments: string) {
    cursor: s64;
    name := console_next_argument(arguments, *cursor);
    new_name := console_next_argument(arguments, *cursor);
    if !name.count || !new_name.count || console_next_argument(arguments, *cursor).count {
        console_write(state, "Usage: rename <name> <new_name>", .ERROR);
        return;
    }
    console_queue_marker_action(state, .RENAME_MARKER, name, new_name);
}

command_back :: (state: *Console_State, arguments: string) {
    cursor: s64;
    name := console_next_argument(arguments, *cursor);
    if !name.count || console_next_argument(arguments, *cursor).count { console_write(state, "Usage: back|tp <name>", .ERROR); return; }
    console_queue_marker_action(state, .BACK_POSITION, name);
}

command_reset_or_markers :: (state: *Console_State, arguments: string) {
    if !arguments.count { command_reset(state, arguments); return; }
    cursor: s64;
    subject := console_next_argument(arguments, *cursor);
    registers := console_next_argument(arguments, *cursor);
    if !equal_nocase(subject, "marker") || !equal_nocase(registers, "registers") ||
       console_next_argument(arguments, *cursor).count {
        console_write(state, "Usage: reset (alias: r), or reset marker registers", .ERROR);
        return;
    }
    console_queue_marker_action(state, .RESET_MARKERS);
}

console_run_marker_action :: (state: *Console_State, filename := POSITION_MARKERS_FILE,
                              read_position: () -> (Game_Position, string) = game_read_position) {
    action := state.pending_action;
    if action != .MARK_POSITION && action != .LIST_MARKERS && action != .REMOVE_MARKER &&
       action != .RENAME_MARKER && action != .BACK_POSITION && action != .RESET_MARKERS return;
    markers: Position_Markers;
    defer position_markers_free(*markers);
    // Reload before every operation so commands and external edits share the latest saved state.
    error := position_markers_load(*markers, filename);
    if error.count { console_write(state, error, .ERROR); return; }
    if action == .LIST_MARKERS {
        if !markers.entries.count console_write(state, "No position markers.");
        for entry: markers.entries console_write(state, tprint("%  %", entry.name, game_position_text(entry.position)));
        return;
    }
    if action == .BACK_POSITION {
        index := position_marker_find(*markers, state.pending_marker_name);
        if index < 0 { console_write(state, tprint("Unknown position marker: %.", state.pending_marker_name), .ERROR); return; }
        state.pending_position = markers.entries[index].position;
        state.pending_position_relative = false;
        state.pending_position_take = false;
        state.pending_position_change = true;
        return;
    }
    message: string;
    if action == .MARK_POSITION {
        position := state.pending_position;
        if state.pending_marker_current {
            position, error = read_position();
            if error.count { console_write(state, error, .ERROR); return; }
        }
        name := position_marker_put(*markers, position, state.pending_marker_name);
        message = tprint("Marked % at %.", name, game_position_text(position));
    } else if action == .REMOVE_MARKER {
        error = position_marker_remove(*markers, state.pending_marker_name);
        message = tprint("Removed marker %.", state.pending_marker_name);
    } else if action == .RENAME_MARKER {
        error = position_marker_rename(*markers, state.pending_marker_name, state.pending_marker_new_name);
        message = tprint("Renamed % to %.", state.pending_marker_name, state.pending_marker_new_name);
    } else {
        position_marker_registers_reset(*markers);
        message = "Cleared a-z registers. Next register: a. Custom markers were kept.";
    }
    if !error.count error = position_markers_write(*markers, filename);
    if error.count console_write(state, error, .ERROR);
    else console_write(state, message);
}

console_run_pending_position :: (state: *Console_State) {
    if !state.pending_position_change return;
    can_start, waiting := console_submission_ready(state, sends_input = state.pending_position_take);
    if waiting return;
    state.pending_position_change = false;
    if !can_start { console_write(state, "Position change cancelled before starting.", .ERROR); return; }
    console_set_game_position(state);
}

console_set_game_position :: (state: *Console_State) {
    console_change_game_position(state, state.pending_position, state.pending_position_relative,
                                 take_after = state.pending_position_take);
}

game_direction_delta :: (direction: u8) -> Game_Position {
    result: Game_Position;
    if direction == #char "U" result[1] = 1;
    if direction == #char "D" result[1] = -1;
    if direction == #char "L" result[0] = -1;
    if direction == #char "R" result[0] = 1;
    return result;
}

console_change_game_position :: (state: *Console_State, requested: Game_Position, relative: bool,
                                 from_game := false, report_success := true, take_after := false) -> bool {
    if editor_save_prompt.active {
        console_write(state, "Finish or cancel the save confirmation before changing position.", .ERROR);
        return false;
    }
    game := find_game_window();
    if !game { console_write(state, "Game not found: sinking_star.exe.", .ERROR); return false; }
    already_in_game := from_game || state.submission.shortcut;
    if !from_game && !console_submission_target_matches(state.submission, game, process_window_pid(game)) {
        console_write(state, "Position change cancelled: the target game changed.", .ERROR);
        return false;
    }
    if already_in_game && Win.GetForegroundWindow() != game return false;
    pid := process_window_pid(game);
    take: Game_Key;
    if take_after {
        keymap: Game_Keymap;
        message, ready := game_keymap_load(*keymap, only_action = "TakeOrDrop");
        if message.count console_write(state, message, ifx ready then .INFO else .ERROR);
        if !ready return false;
        take = keymap.take;
        if Win.GetAsyncKeyState(cast(s32) take.vk) < 0 {
            console_write(state, "Release the game's TakeOrDrop key before switching levels.", .ERROR);
            return false;
        }
    }
    if editor.open {
        editor_pause();
        editor_view_cancel_drag();
        if editor.transport.held.scan || editor.transport.time_held {
            console_write(state, "Could not release the editor's held keys. Position was not changed.", .ERROR);
            return false;
        }
    }
    memory, error := process_open_memory(game, GAME_EXECUTABLE, writable = true);
    if error.count { console_write(state, error, .ERROR); return false; }
    defer process_close_memory(*memory);
    if take_after {
        error = send_input_begin(game);
        if error.count { console_write(state, error, .ERROR); return false; }
    }
    defer if take_after send_input_end();
    destination: Game_Position;
    player: Game_Player_Location;
    changed: bool;
    locator: *Game_Manager_Locator;
    if from_game locator = *noclip.locator;
    error, changed = game_write_position_to(memory, requested, relative, instant = true,
                                             written_position = *destination, written_player = *player,
                                             required_scene = ifx take_after then "overworld" else "", locator = locator);
    if changed editor_on_game_position_changed();
    if error.count { console_write(state, error, .ERROR); return false; }
    if !already_in_game {
        if !overlay_focus_game_for_input(game, poll = console_poll_send) {
            console_write(state, tprint("Teleported to %, but the game did not gain focus.", game_position_text(destination)), .ERROR);
            return false;
        }
    }
    if take_after {
        current: Game_Position;
        if process_window_pid(game) != pid || !game_player_location_current(memory, player) ||
           !process_read_memory(memory.handle, player.entity, *current, size_of(Game_Position)) ||
           !game_position_valid(current) || !solution_position_equal(current, destination) {
            console_write(state, "Teleported, but the player or position changed before TakeOrDrop. No key was sent.", .ERROR);
            return false;
        }
        result := send_key_cycle(take.scan, take.extended, target_window = game, poll = console_poll_send);
        if !result.success {
            console_write(state, tprint("Teleported to %. TakeOrDrop failed: %", game_position_text(destination), result.error), .ERROR);
            return false;
        }
    }
    if report_success console_write(state, tprint("Teleported to %.%", game_position_text(destination),
                                                  ifx take_after then " Sent TakeOrDrop." else ""));
    return true;
}

#scope_file
#import "Basic";
#import "String";
#import "Math";
Win :: #import "Windows";
