Solution_Editor :: struct {
    open: bool;
    recording: bool;
    custom: bool;
    synchronized := true;
    game: Win.HWND;
    game_pid: u32;
    record: Solution_Record;
    timeline: Solution_Timeline;
    transport: Editor_Transport;
    keymap: Game_Keymap;
    status: string;
    status_error: bool;
    focus_requested: bool;
    focus_from_console: bool;
    focus_deadline: float64;
    ready_at: float64;
    reset_requested: bool;
    test_after_reset: bool;
    reset_timeline: Solution_Timeline;
}
editor: Solution_Editor;

editor_position_allowed :: (position: Game_Position) -> bool {
    // @TODO: Check whether this position corresponds to a playable level.
    // The user will add this check. For now every readable position may open the editor.
    return true;
}

editor_set_status :: (message: string, error := false) {
    free(editor.status);
    editor.status = copy_string(message);
    editor.status_error = error;
    if error console_write(*console, message, .ERROR);
}

editor_open_solution :: (level_name: string = "", custom_only := false) {
    game := find_game_window();
    if !game { console_write(*console, "Game not found: sinking_star.exe.", .ERROR); return; }
    temporary := !custom_only && equal_nocase(level_name, "temp");
    position: Game_Position;
    if !temporary && !level_name.count {
        error: string;
        position, error = game_read_position();
        if error.count { console_write(*console, error, .ERROR); return; }
        if !editor_position_allowed(position) return;
    }
    database: Solutions_Database;
    defer solutions_free(*database);
    record: Solution_Record;
    defer solution_record_free(*record);
    custom := temporary || custom_only;
    error: string;
    if temporary record.area = copy_string("none");
    else {
        if custom error = custom_inputs_load(*database);
        else error = solutions_load(*database);
        if error.count { console_write(*console, error, .ERROR); return; }
        index := ifx level_name.count then solution_find_name(*database, level_name, ignore_case = true)
                                     else solution_find_position(*database, position);
        if level_name.count && index < 0 && !custom {
            error = custom_inputs_load(*database);
            if error.count { console_write(*console, error, .ERROR); return; }
            index = solution_find_name(*database, level_name, ignore_case = true);
            custom = true;
        }
        if level_name.count && index < 0 {
            console_write(*console, tprint("Unknown level or custom input: %", level_name), .ERROR);
            return;
        }
        if index >= 0 record = solution_record_copy(database.entries[index]);
        else {
            record.position = position;
            record.name = copy_string(tprint("position_%", game_position_text(position)));
            record.area = copy_string("custom");
        }
    }
    same_record := !temporary && editor.custom == custom &&
                   (ifx level_name.count then equal_nocase(editor.record.name, record.name)
                                         else solution_position_equal(editor.record.position, position));
    if editor.open && editor.synchronized && editor.game == game &&
       editor.game_pid == game_window_pid(game) && same_record {
        overlay_hide();
        editor_set_minimized(false);
        editor_window_update();
        return;
    }
    timeline: Solution_Timeline;
    defer array_free(timeline.keys);
    error = timeline_load(*timeline, record.solution);
    if error.count {
        console_write(*console, error, .ERROR);
        return;
    }
    keymap: Game_Keymap;
    keymap_ready: bool;
    error, keymap_ready = game_keymap_load(*keymap);
    if error.count console_write(*console, error, ifx keymap_ready then .INFO else .ERROR);
    if !keymap_ready return;
    // Validate the requested session before asking to save or discard the existing one.
    if editor.open && !editor_close(after = .OPEN, next_level = level_name, next_custom = custom_only) return;
    if !editor_window_create() || !editor_install_keyboard_hook() {
        console_write(*console, "Could not create the solution editor or install its input hook.", .ERROR);
        return;
    }
    editor.record = record;
    record = .{};
    editor.timeline = timeline;
    timeline = .{};
    editor.keymap = keymap;
    editor.custom = custom;
    editor.transport = .{};
    editor.game = game;
    editor.game_pid = game_window_pid(game);
    editor.open = true;
    editor.recording = false;
    editor.synchronized = true;
    editor.focus_requested = false;
    editor.focus_from_console = false;
    editor.ready_at = 0;
    editor_view.minimized = false;
    editor_view_reset();
    if temporary editor_set_status("Temporary input. Record or edit, then Save with a custom name.");
    else editor_set_status("Click future cells, then use WASD or arrow keys; drag the strip to seek.");
    overlay_hide();
    editor_window_update();
}

editor_emit_key :: (key: Game_Key, key_up: bool) -> string {
    success, error := send_key_event(key.scan, key_up, key.extended);
    return error;
}

editor_pause :: () {
    error := editor_transport_stop(*editor.transport, *editor.timeline, editor_emit_key);
    editor.reset_requested = false;
    editor.test_after_reset = false;
    array_free(editor.reset_timeline.keys);
    editor.reset_timeline = .{};
    editor.focus_requested = false;
    editor.focus_from_console = false;
    editor.ready_at = 0;
    if error.count editor_set_status(error, true);
    editor_view.wheeling = false;
}

editor_busy :: () -> bool {
    return editor.reset_requested || editor_transport_busy(*editor.transport, *editor.timeline);
}

editor_seek :: (position: s64, playing := false, scrubbing := false) {
    if !editor.open return;
    if editor_save_prompt.active { editor_set_status("Finish or cancel the save confirmation before seeking."); return; }
    if !editor.synchronized {
        editor_set_status("The game changed outside this timeline. Reopen with edit <level_name> or edit solution.", true);
        return;
    }
    if !editor_transport_busy(*editor.transport, *editor.timeline) editor.ready_at = 0;
    editor.transport.target = max(0, min(editor.timeline.keys.count, position));
    editor.transport.playing = playing;
    editor.transport.test_playback = false;
    editor.transport.speed = .NORMAL;
    editor.transport.scrubbing = scrubbing;
    editor.transport.held_step = 0;
    editor.transport.undo_delay_ms = EDITOR_FORWARD_DELAY;
    editor_view.recording_motion = false;
    if !scrubbing editor_view.wheeling = false;
    editor.focus_from_console = Win.GetForegroundWindow() == overlay.window;
    editor_set_status(ifx playing then "Playing" else "Paused");
}

editor_jump_solution :: (position: s64) {
    if !editor.open { console_write(*console, "Open a solution editor before using jump.", .ERROR); return; }
    target := ifx position == -1 then editor.timeline.keys.count else position;
    // Validate before pausing, moving focus, or changing any transport state.
    if target < 0 || target > editor.timeline.keys.count {
        console_write(*console, tprint("Jump must be between 0 and % (or $ for the end).", editor.timeline.keys.count), .ERROR);
        return;
    }
    if !editor.synchronized {
        editor_set_status("The game changed outside this timeline. Reset level or Reopen with edit <level_name>.", true);
        return;
    }
    if editor_save_prompt.active { console_write(*console, "Finish or cancel the save confirmation before jump.", .ERROR); return; }
    editor_pause();
    if editor.transport.held.scan || editor.transport.time_held return;
    editor_view_cancel_drag();
    editor_seek(target);
    console_write(*console, tprint("Jump to step % / %.", target, editor.timeline.keys.count));
    editor_set_status(tprint("Jump to step %.", target));
}

editor_toggle_play :: () {
    if editor_busy() {
        editor_pause();
        editor_set_status("Paused");
    } else editor_seek(editor.timeline.keys.count, playing = true);
}

editor_step :: (direction: s64, repeat_while_held := false) {
    if !editor.open return;
    target := ifx editor.transport.playing then editor.timeline.playhead else editor.transport.target;
    editor_pause();
    editor_seek(target + direction);
    if repeat_while_held && editor.synchronized && !editor_save_prompt.active &&
       !editor.transport.held.scan && !editor.transport.time_held {
        editor.transport.held_step = direction;
        if direction < 0 editor.transport.undo_delay_ms = EDITOR_HELD_UNDO_DELAY;
    }
}

editor_release_step :: (direction: s64) {
    // Finish an accepted step (or a queued tap), without starting another on release.
    if editor.transport.held_step == direction editor.transport.held_step = 0;
}

editor_reset :: () {
    if !editor.open return;
    editor_pause();
    if editor.transport.held.scan || editor.transport.time_held return;
    error := timeline_load(*editor.reset_timeline, editor.record.solution);
    if error.count { editor_set_status(error, true); return; }
    editor.reset_requested = true;
    editor.focus_from_console = Win.GetForegroundWindow() == overlay.window;
    editor_view_cancel_drag();
    editor_set_status("Resetting the game and restoring the last saved solution...");
}

editor_finish_reset :: () {
    testing := editor.test_after_reset;
    if testing {
        // Test the current edits, keeping the saved snapshot and recording toggle intact.
        editor.timeline.playhead = 0;
        timeline_move_caret(*editor.timeline, 0);
    } else {
        array_free(editor.timeline.keys);
        editor.timeline = editor.reset_timeline;
    }
    editor.reset_timeline = .{};
    editor.reset_requested = false;
    editor.test_after_reset = false;
    editor.transport.target = ifx testing then editor.timeline.keys.count else 0;
    editor.transport.playing = testing;
    editor.transport.test_playback = testing;
    editor.transport.speed = ifx testing then .RABBIT else .NORMAL;
    editor.synchronized = true;
    editor_view_reset();
    if testing editor_set_status(tprint("Testing the current solution: % ms with fast time.", SEND_SUPERFAST_DELAY));
    else editor_set_status("Game reset. Last saved solution restored.");
}

editor_test_solution :: () {
    if !editor.open return;
    editor_pause();
    if editor.transport.held.scan || editor.transport.time_held return;
    if !editor.keymap.fast.scan { editor_set_status("No keyboard binding for HoldForFastTime.", true); return; }
    for symbol: editor.timeline.keys {
        key := game_key_for_symbol(*editor.keymap, symbol);
        if key.scan == editor.keymap.fast.scan && key.extended == editor.keymap.fast.extended {
            editor_set_status("The fast-time key is also a solution key. Change HoldForFastTime in User.keymap.", true);
            return;
        }
    }
    editor.reset_requested = true;
    editor.test_after_reset = true;
    editor.focus_from_console = Win.GetForegroundWindow() == overlay.window;
    editor_view_cancel_drag();
    editor_set_status("Resetting the game to test the current solution from the beginning...");
}

editor_export_solution :: () {
    if !editor.open return;
    text := timeline_serialize(*editor.timeline);
    defer free(text);
    error := clipboard_write_text(editor_window_handle(), text);
    if error.count { editor_set_status(error, true); return; }
    editor_set_status(tprint("Copied % solution steps to the clipboard.", editor.timeline.keys.count));
}

editor_set_playback_speed :: (speed: Editor_Playback_Speed) {
    if !editor.open || !editor.transport.playing return;
    if speed == .TURTLE {
        if !editor.keymap.slow.scan { editor_set_status("No keyboard binding for HoldForSlowTime.", true); return; }
        for i: editor.timeline.playhead..editor.timeline.keys.count-1 {
            key := game_key_for_symbol(*editor.keymap, editor.timeline.keys[i]);
            if key.scan == editor.keymap.slow.scan && key.extended == editor.keymap.slow.extended {
                editor_set_status("The slow-time key is also a solution key. Change HoldForSlowTime in User.keymap.", true);
                return;
            }
        }
    }
    editor.transport.speed = speed;
    label := ifx speed == .TURTLE then "-turtle" else "-fast";
    editor_set_status(tprint("Playing %: % ms per step.", label, editor_playback_delay(speed)));
}

editor_toggle_record :: () {
    editor_set_recording(!editor.recording);
}

editor_set_recording :: (recording: bool) -> bool {
    if !editor.open return false;
    if editor_save_prompt.active {
        editor_set_status("Finish or cancel the save confirmation before recording.", true);
        return false;
    }
    editor_pause();
    editor_view_cancel_drag();
    if editor.transport.held.scan || editor.transport.time_held return false;
    if recording && !editor.synchronized {
        editor_set_status("Reopen with edit <level_name> or edit solution before starting a new recording.", true);
        return false;
    }
    editor.recording = recording;
    if editor.recording {
        editor_focus_game();
        editor_set_status("Recording game keys. New steps are inserted before the remaining solution.");
    } else editor_set_status("Recording stopped.");
    return true;
}

editor_run_console_action :: (action: Console_Action) {
    if action != .EDITOR_RECORD && action != .EDITOR_PAUSE && action != .EDITOR_STOP && action != .EDITOR_SAVE &&
       action != .EDITOR_CLOSE return;
    if !editor.open {
        if action == .EDITOR_CLOSE console_write(*console, "The editor is already closed.");
        else console_write(*console, "Open a solution editor first: edit <level_name> or open editor.", .ERROR);
        return;
    }
    if action == .EDITOR_SAVE {
        editor_save();
        console_write(*console, "Confirm Save in the editor.");
        return;
    }
    if editor_save_prompt.active {
        console_write(*console, "Finish or cancel the save confirmation first.", .ERROR);
        return;
    }
    if action == .EDITOR_CLOSE {
        if editor_close() console_write(*console, "Editor closed.");
        return;
    }
    if action == .EDITOR_RECORD {
        editor_set_recording(true);
    } else if action == .EDITOR_STOP {
        if editor_set_recording(false) editor_set_status("Playback and recording stopped.");
    } else {
        editor_pause();
        editor_view_cancel_drag();
        if !editor.transport.held.scan && !editor.transport.time_held editor_set_status("Paused.");
    }
    console_write(*console, editor.status, ifx editor.status_error then .ERROR else .OUTPUT);
}

editor_on_game_reset :: (clear_executed := false) {
    if !editor.open return;
    editor_pause();
    if clear_executed timeline_clear_executed(*editor.timeline);
    editor.timeline.playhead = 0;
    timeline_move_caret(*editor.timeline, 0);
    editor.transport.target = 0;
    editor.synchronized = true;
    editor_view_reset();
    if clear_executed editor_set_status("Executed moves cleared. Recording continues.");
    else editor_set_status("Game reset. Timeline is back at the beginning.");
}

editor_save :: () {
    if editor.open editor_begin_save_prompt();
}

editor_close :: (discard := false, after: Editor_After_Save = .CLOSE, next_level: string = "", next_custom := false) -> bool {
    if !editor.open return true;
    editor_pause();
    if !discard && editor.timeline.dirty {
        editor_begin_save_prompt(after, next_level, next_custom);
        return false;
    }
    editor_clear_save_prompt();
    editor.open = false;
    editor.recording = false;
    editor_remove_keyboard_hook();
    if Win.GetForegroundWindow() == editor_window_handle() editor_focus_game();
    editor_window_hide();
    solution_record_free(*editor.record);
    array_free(editor.timeline.keys);
    editor.timeline = .{};
    return true;
}

editor_deinit :: () {
    editor_pause();
    editor_clear_save_prompt();
    editor.open = false;
    editor_remove_keyboard_hook();
    editor_window_destroy();
    solution_record_free(*editor.record);
    array_free(editor.timeline.keys);
    free(editor.status);
}

editor_on_game_key :: (vk: u32) {
    if !editor.open return;
    if vk == 0x1b { editor_pause(); return; }
    if vk == editor.keymap.restart.vk {
        editor_on_game_reset(clear_executed = editor.recording);
        return;
    }
    symbol := game_symbol_for_vk(*editor.keymap, vk);
    if !symbol && vk != editor.keymap.undo.vk && vk != editor.keymap.restart.vk return;
    editor_pause();
    editor_view_cancel_drag();
    if !editor.synchronized return;
    if vk == editor.keymap.undo.vk && timeline_apply_game_undo(*editor.timeline) {
        editor_view.recording_motion = false;
        editor.transport.target = editor.timeline.playhead;
        return;
    }
    if symbol && editor.recording && timeline_record(*editor.timeline, symbol) {
        editor_view.recording_motion = true;
        editor.transport.target = editor.timeline.playhead;
        return;
    }
    editor.synchronized = false;
    editor.recording = false;
    editor_set_status("An unrecorded move changed the game. Reopen with edit <level_name> or edit solution.", true);
}

editor_update :: (now: float64) {
    editor_process_window_events();
    if !editor.open return;
    if editor_input_overflowed() {
        editor_pause();
        editor.recording = false;
        editor.synchronized = false;
        editor_set_status("Recording input overflowed. Reopen with edit <level_name> or edit solution.", true);
    }
    editor_window_update();
    if !editor_game_valid() {
        editor_pause();
        editor.synchronized = false;
        editor.recording = false;
        return;
    }
    foreground := Win.GetForegroundWindow();
    from_console := foreground == overlay.window && editor.focus_from_console;
    if (!from_console && foreground != editor.game && foreground != editor_window_handle()) ||
       process_console_should_exit() || overlay.quit_requested {
        editor_view_cancel_drag();
        editor_pause();
        return;
    }
    if !editor_busy() return;
    if foreground != editor.game {
        if !editor.focus_requested {
            editor_focus_game();
            editor.focus_requested = true;
            editor.focus_deadline = now + 1;
        } else if now >= editor.focus_deadline {
            editor_pause();
            editor_set_status("Could not focus the game. Playback paused.", true);
        }
        return;
    }
    editor.focus_requested = false;
    editor.focus_from_console = false;
    if editor.transport.phase == .IDLE && !editor.transport.time_held {
        // Wait for the user's transport key and modifiers, not our injected accelerator.
        if (editor_physical_key_down(0x20) && !editor_window.speed_key_consumed[0x20]) ||
           editor_modifiers_down(ignore_speed_keys = true) return;
        if !editor.ready_at { editor.ready_at = now + 0.1; return; }
        if now < editor.ready_at return;
    }
    if editor.reset_requested {
        error := editor_transport_press(*editor.transport, editor.keymap.restart, RESET_DEFAULT_DELAY, now, editor_emit_key);
        if error.count { editor_pause(); editor_set_status(error, true); return; }
        editor_finish_reset();
        return;
    }
    testing := editor.transport.test_playback;
    error := editor_transport_tick(*editor.transport, *editor.timeline, *editor.keymap, now, editor_emit_key);
    if error.count {
        editor_pause();
        editor_set_status(error, true);
    } else if testing && !editor_busy() {
        editor_set_status(tprint("Test playback finished: % steps.", editor.timeline.playhead));
    }
}

#scope_file
#import "Basic";
#import "String";
Win :: #import "Windows";
