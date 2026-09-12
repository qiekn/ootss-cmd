console_play_saved_solution :: (console: *Console_State, filename := SOLUTIONS_FILE) {
    request := console.pending_play;
    console.pending_play = .{};
    defer free(request.source);
    if !request.source.count return;
    if !file_exists(filename) {
        console_write(console, tprint("Saved solutions file not found: %", filename), .ERROR);
        return;
    }
    database: Solutions_Database;
    defer solutions_free(*database);
    // Play the saved record without importing answers or reading game coordinates.
    error := solutions_load(*database, filename, marker_file = "", answer_file = "");
    if error.count { console_write(console, error, .ERROR); return; }
    index := solution_find_name(*database, request.source, ignore_case = true);
    if index < 0 {
        console_write(console, tprint("Unknown saved level: %", request.source), .ERROR);
        return;
    }
    solution := database.entries[index].solution;
    if !trim(solution).count {
        console_write(console, tprint("No saved solution for %.", database.entries[index].name), .ERROR);
        return;
    }
    console_queue_send_source(console, solution, request);
}

console_run_pending_send :: (console: *Console_State) -> s64 {
    if !console.pending_send.count return 0;

    can_start := overlay.visible && !overlay.quit_requested && Win.GetForegroundWindow() == overlay.window;
    if can_start {
        // Keep focus here until the submitting key and modifiers have been released.
        for key: s32.[Win.VK_RETURN, Win.VK_SHIFT, Win.VK_CONTROL, Win.VK_MENU, Win.VK_LWIN, Win.VK_RWIN] {
            if Win.GetAsyncKeyState(key) < 0 return 0;
        }
    }

    commands := console.pending_send;
    hold_ms := console.pending_send_hold_ms;
    interval_ms := console.pending_send_interval_ms;
    time_mode := console.pending_send_time_mode;
    interruptible := console.pending_send_interruptible;
    console.pending_send = "";
    console.pending_reset = false;
    console.pending_send_hold_ms = DEFAULT_HOLD;
    console.pending_send_interval_ms = DEFUALT_INTERVAL;
    console.pending_send_time_mode = .NORMAL;
    console.pending_send_interruptible = false;
    defer free(commands);
    if !can_start {
        console_write(console, "Send cancelled before starting.", .ERROR);
        return 0;
    }

    game := find_game_window();
    if !game {
        console_write(console, tprint("Game not found: %", GAME_EXECUTABLE), .ERROR);
        return 0;
    }

    modifier: Game_Key;
    if time_mode != .NORMAL {
        keymap: Game_Keymap;
        action := ifx time_mode == .FAST then "HoldForFastTime" else "HoldForSlowTime";
        message, ready := game_keymap_load(*keymap, only_action = action);
        if message.count console_write(console, message, ifx ready then .INFO else .ERROR);
        if !ready return 0;
        modifier = ifx time_mode == .FAST then keymap.fast else keymap.slow;
    }
    if interruptible {
        error := send_input_begin(game);
        if error.count { console_write(console, error, .ERROR); return 0; }
    }
    defer if interruptible send_input_end();

    if !overlay_focus_game_for_input(game, poll = console_poll_send) {
        cancelled := overlay.toggle_requested || overlay.show_requested || overlay.quick_requested ||
                     overlay.quit_requested || tray_has_request() || send_input_interrupted();
        message := ifx cancelled then "Send cancelled before starting." else "Could not focus the game. No keys were sent.";
        console_write(console, message, .ERROR);
        return 0;
    }

    // Give the game a short moment to process activation before its first key press.
    sleep_milliseconds(100);
    result := send_sequence(commands, hold_ms, interval_ms, target_window = game, poll = console_poll_send,
                            modifier_scan = modifier.scan, modifier_extended = modifier.extended);
    if !result.success && result.error == "Send cancelled." && send_input_interrupted() {
        result.error = "Stopped by player input.";
    }
    if result.success {
        console_write(console, tprint("Sent % keys.", result.sent_keys));
    } else {
        key_count := validate_send(commands);
        console_write(console, tprint("% Sent %/% keys.", result.error, result.sent_keys, key_count), .ERROR);
    }
    return result.sent_keys;
}

#scope_file

#import "Basic";
#import "String";
#import "File_Utilities";
Win :: #import "Windows";
Input :: #import "Input";

console_poll_send :: () -> bool {
    // Called outside the main event iteration because this refreshes events_this_frame.
    if process_console_should_exit() overlay.quit_requested = true;
    Input.update_window_events();
    for event: Input.events_this_frame {
        if event.type == .QUIT overlay.quit_requested = true;
    }
    overlay_update_hotkey();
    return !overlay.toggle_requested && !overlay.show_requested && !overlay.quick_requested && !overlay.quit_requested &&
           !tray_has_request() && !send_input_interrupted();
}
