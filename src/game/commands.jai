Console_Submission :: struct {
    quick: bool;
    shortcut: bool;
    game: Win.HWND;
    pid: u32;
    trigger_key: u32;
    focus_deadline: float64;
}

console_submit_window :: () {
    game := overlay.game;
    if console_submit_from(*console, overlay.mode, game, process_window_pid(game), seconds_since_init()) overlay_hide();
    else if overlay.mode == .MINI && console.pending_action == .SHOW_SUBTITLES {
        // Keep focus while expanding for the requested subtitles (or a lookup error).
        overlay_set_mode(overlay.full_mode);
    }
}

console_submit_from :: (state: *Console_State, mode: Console_Mode, game: Win.HWND, pid: u32, now: float64) -> bool {
    console_submit(state);
    if mode != .MINI || state.pending_action == .SHOW_SUBTITLES return false;
    // Capture the intended game before hiding. Pending commands may start only in
    // this same game after Enter/modifiers are released, never in another window.
    state.submission = .{quick = true, game = game, pid = pid, focus_deadline = now + 1};
    return true;
}

console_submission_target_matches :: (submission: Console_Submission, game: Win.HWND, pid: u32) -> bool {
    return (!submission.quick && !submission.shortcut) || (game && game == submission.game && pid && pid == submission.pid);
}

console_submission_origin_matches :: (submission: Console_Submission, visible: bool, foreground: Win.HWND,
                                      window: Win.HWND, game: Win.HWND, pid: u32) -> bool {
    if submission.shortcut return foreground == game && console_submission_target_matches(submission, game, pid);
    if submission.quick return !visible && foreground == game && console_submission_target_matches(submission, game, pid);
    return visible && foreground == window;
}

console_submission_ready :: (state: *Console_State, sends_input := true) -> (ready: bool, waiting: bool) {
    if overlay.quit_requested || overlay.show_requested || overlay.quick_requested || overlay.toggle_requested ||
       process_console_should_exit() || tray_has_request() return false, false;
    game := find_game_window();
    pid := process_window_pid(game);
    foreground := Win.GetForegroundWindow();
    if state.submission.quick && !overlay.visible &&
       console_submission_target_matches(state.submission, game, pid) &&
       (foreground == overlay.window || !foreground) && seconds_since_init() < state.submission.focus_deadline {
        return false, true; // Window activation can finish on the next game message.
    }
    if !console_submission_origin_matches(state.submission, overlay.visible, foreground, overlay.window, game, pid) {
        return false, false;
    }
    if state.submission.shortcut {
        if editor_save_prompt.active return false, false;
        if sends_input && !shortcuts_input_released(*shortcuts, state.submission.trigger_key) return false, true;
        return true, false;
    }
    for key: s32.[Win.VK_RETURN, Win.VK_SHIFT, Win.VK_CONTROL, Win.VK_MENU, Win.VK_LWIN, Win.VK_RWIN] {
        if Win.GetAsyncKeyState(key) < 0 return false, true;
    }
    return true, false;
}

console_show_current_level :: (console: *Console_State, read_scene: Game_Level_Query = game_read_scene) {
    name, error := read_scene();
    defer free(name);
    if error.count { console_write(console, error, .ERROR); return; }
    if equal_nocase(name, "overworld") console_write(console, "Current scene: Overworld (outside a small level).");
    else if game_scene_is_level(name) console_write(console, tprint("Current level: %", name));
    else console_write(console, tprint("Current scene: % (not a playable level).", name));
}

console_play_saved_solution :: (console: *Console_State, filename := SOLUTIONS_FILE,
                                custom_filename := CUSTOM_INPUTS_FILE, read_scene: Game_Level_Query = game_read_scene) {
    request := console.pending_play;
    console.pending_play = .{};
    defer free(request.source);
    name, error := game_resolve_level_name(request.source, read_scene);
    defer free(name);
    if error.count { console_write(console, error, .ERROR); return; }
    database: Solutions_Database;
    defer solutions_free(*database);
    // Play the saved record without importing answers or reading game coordinates.
    error = solutions_load(*database, filename, marker_file = "", answer_file = "");
    if error.count { console_write(console, error, .ERROR); return; }
    index := solution_find_name(*database, name, ignore_case = true);
    if index < 0 && request.source.count {
        error = custom_inputs_load(*database, custom_filename);
        if error.count { console_write(console, error, .ERROR); return; }
        index = solution_find_name(*database, name, ignore_case = true);
    }
    if index < 0 {
        console_write(console, tprint("No saved input found for %. Use edit to record a solution.", name), .ERROR);
        return;
    }
    solution := database.entries[index].solution;
    if !trim(solution).count {
        console_write(console, tprint("No saved input for %.", database.entries[index].name), .ERROR);
        return;
    }
    console_queue_send_source(console, solution, request);
}

console_run_pending_send :: (console: *Console_State) -> s64 {
    if !console.pending_send.count return 0;

    can_start, waiting := console_submission_ready(console);
    if waiting return 0;

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
    if !console_submission_target_matches(console.submission, game, process_window_pid(game)) {
        console_write(console, "Send cancelled: the target game changed.", .ERROR);
        return 0;
    }
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

    if console.submission.shortcut {
        if Win.GetForegroundWindow() != game {
            console_write(console, "Send cancelled: the game lost focus.", .ERROR);
            return 0;
        }
    } else if !overlay_focus_game_for_input(game, poll = console_poll_send) {
        cancelled := overlay.toggle_requested || overlay.show_requested || overlay.quick_requested ||
                     overlay.quit_requested || tray_has_request() || send_input_interrupted();
        message := ifx cancelled then "Send cancelled before starting." else "Could not focus the game. No keys were sent.";
        console_write(console, message, .ERROR);
        return 0;
    }

    // Give the game a short moment to process activation before its first key press.
    if !console.submission.shortcut sleep_milliseconds(100);
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

console_poll_send :: () -> bool {
    // Called outside the main event iteration because this refreshes events_this_frame.
    if process_console_should_exit() overlay.quit_requested = true;
    Input.update_window_events();
    for event: Input.events_this_frame {
        if event.type == .QUIT overlay.quit_requested = true;
    }
    overlay_update_hotkey();
    shortcuts_refresh_target();
    return !overlay.toggle_requested && !overlay.show_requested && !overlay.quick_requested && !overlay.quit_requested &&
           !tray_has_request() && !send_input_interrupted();
}

#scope_file
#import "Basic";
#import "String";
#import "File_Utilities";
Win :: #import "Windows";
Input :: #import "Input";
