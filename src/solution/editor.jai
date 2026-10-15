Solution_Editor :: struct {
    open:      bool;
    recording: bool;
    custom:    bool;
    synchronized := true; // Advisory only; manual game alignment never locks transport.
    game:               Win.HWND;
    game_pid:           u32;
    record:             Solution_Record;
    timeline:           Solution_Timeline;
    transport:          Editor_Transport;
    keymap:             Game_Keymap;
    status:             string;
    status_error:       bool;
    focus_requested:    bool;
    focus_from_console: bool;
    focus_deadline:     float64;
    ready_at:           float64;
    reset_requested:    bool;
    reset_timeline:     Solution_Timeline;
    speed_reader:       Playback_Speed_Reader;
    speed_override:     Game_Speed_Session;
    game_speed_value:   float64;
    game_speed_known:   bool;
}
editor: Solution_Editor;

editor_set_status :: (message: string, error := false) {
    free(editor.status);
    editor.status       = copy_string(message);
    editor.status_error = error;
    if error console_write(*console, message, .ERROR);
}

// Resolve and validate the requested record before touching an open editor.
editor_load_record :: (requested: string, custom_only := false, filename := SOLUTIONS_FILE,
                       custom_filename := CUSTOM_INPUTS_FILE, catalog_file := LEVEL_CATALOG_FILE,
                       read_scene: Game_Level_Query = game_read_scene)
                      -> (record: Solution_Record, custom: bool, temporary: bool, error: string) {
    temporary := !custom_only && equal_nocase(requested, "temp");
    if temporary return .{area = copy_string("none")}, true, true, "";
    name, error := game_resolve_level_name(requested, read_scene);
    defer free(name);
    if error.count return .{}, false, false, error;
    database: Solutions_Database;
    defer solutions_free(*database);
    custom := custom_only;
    if custom error = custom_inputs_load(*database, custom_filename);
    else error = solutions_load(*database, filename, catalog_file);
    if error.count return .{}, false, false, error;
    index := solution_find_name(*database, name, ignore_case = true);
    if index < 0 && requested.count && !custom {
        error = custom_inputs_load(*database, custom_filename);
        if error.count return .{}, false, false, error;
        index  = solution_find_name(*database, name, ignore_case = true);
        custom = true;
    }
    if index < 0 && !requested.count {
        // A real scene may have no overworld marker (for example, intro).
        // Its name still identifies a level record; Save remains explicit.
        return .{name = copy_string(name), area = copy_string("none")}, false, false, "";
    }
    if index < 0 return .{}, false, false, tprint("Unknown level or custom input: %", name);
    return solution_record_copy(database.entries[index]), custom, false, "";
}

editor_open_solution :: (level_name: string = "", custom_only := false) {
    game := find_game_window();
    if !game { console_write(*console, "Game not found: sinking_star.exe.", .ERROR); return; }
    record, custom, temporary, error := editor_load_record(level_name, custom_only);
    defer solution_record_free(*record);
    if error.count { console_write(*console, error, .ERROR); return; }
    same_record := !temporary && editor.custom == custom && equal_nocase(editor.record.name, record.name);
    if editor.open && editor.game == game &&
       editor.game_pid == game_window_pid(game) && same_record {
        overlay_hide();
        editor_set_minimized(false);
        editor_window_update();
        return;
    }
    timeline: Solution_Timeline;
    defer timeline_free(*timeline);
    error = timeline_load(*timeline, record.solution);
    if error.count {
        console_write(*console, error, .ERROR);
        return;
    }
    keymap:       Game_Keymap;
    keymap_ready: bool;
    error, keymap_ready = game_keymap_load(*keymap);
    if error.count console_write(*console, error, ifx keymap_ready then .INFO else .ERROR);
    if !keymap_ready return;
    // Validate the requested session before asking to save or discard the existing one.
    // Keep the resolved name across Save / Discard / Cancel, even if the game changes scene.
    next_level := ifx temporary then "temp" else record.name;
    if editor.open && !editor_close(after = .OPEN, next_level = next_level, next_custom = custom && !temporary) return;
    if !editor_window_create() || !editor_install_keyboard_hook() {
        console_write(*console, "Could not create the solution editor or install its input hook.", .ERROR);
        return;
    }
    editor.record             = record;
    record                    = .{};
    editor.timeline           = timeline;
    timeline                  = .{};
    editor.keymap             = keymap;
    editor.custom             = custom;
    editor.transport          = .{};
    editor.game               = game;
    editor.game_pid           = game_window_pid(game);
    editor.open               = true;
    editor.recording          = false;
    editor.synchronized       = true;
    editor.focus_requested    = false;
    editor.focus_from_console = false;
    editor.ready_at           = 0;
    editor_view.minimized     = false;
    editor.game_speed_known   = false;
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
    timeline_free(*editor.reset_timeline);
    editor.focus_requested    = false;
    editor.focus_from_console = false;
    editor.ready_at           = 0;
    if error.count editor_set_status(error, true);
    editor_view.wheeling = false;
    editor_restore_speed();
}

editor_restore_speed :: () -> bool {
    owned := editor.speed_override.memory.handle != null;
    base  := editor.speed_override.original;
    last  := editor.speed_override.last;
    observed:   float64;
    read_error: string;
    if owned observed, read_error = game_speed_read(*editor.speed_override);
    error := game_speed_close(*editor.speed_override);
    if error.count { editor_set_status(error, true); return false; }
    if owned {
        editor.game_speed_known = !read_error.count;
        editor.game_speed_value = ifx observed == last then base else observed;
    }
    if owned && editor.transport.clock.initialized {
        restored := ifx editor.game_speed_known then editor.game_speed_value else base;
        rate     := ifx editor_transport_reversing(*editor.transport, *editor.timeline) then 1 else restored;
        playback_clock_update(*editor.transport.clock, seconds_since_init(), rate);
    }
    return true;
}

editor_end_fast_scrub :: () {
    if !editor.transport.scrubbing return;
    editor.transport.scrub_rate = 1;
    editor_restore_speed();
}

editor_playback_game_rate :: () -> (rate: float64, error: string) {
    factor  := editor_transport_multiplier(*editor.transport, *editor.timeline);
    reverse := editor_transport_reversing(*editor.transport, *editor.timeline);
    if reverse || factor == 1 {
        if !editor_restore_speed() return 0, editor.status;
        rate, error := playback_speed_read(*editor.speed_reader, editor.game);
        editor.game_speed_known = !error.count;
        if !error.count editor.game_speed_value = rate;
        if reverse return 1, ""; // Keep undo timing independent of speed, even if the display query fails.
        return rate, error;
    }
    if capture_active() || capture_speed.memory.handle return 0, "Pause map capture before accelerated playback.";
    if !editor.speed_override.memory.handle {
        error := game_speed_open(*editor.speed_override, editor.game);
        if error.count return 0, error;
    }
    if !editor_game_valid() || Win.GetForegroundWindow() != editor.game return 0, "Game focus changed before adjusting playback speed.";
    base := editor.speed_override.original;
    if base <= 0 return 0, "Game speed is 0. Resume the game before playback.";
    // Scrubbing uses an absolute temporary game rate; playback multiplies the user's base.
    wanted := ifx editor.transport.scrubbing then factor else base * factor;
    error  := game_speed_set(*editor.speed_override, wanted);
    if error.count return 0, error;
    editor.game_speed_value = wanted;
    editor.game_speed_known = true;
    return ifx editor.transport.scrubbing then 1 else base, "";
}

editor_display_speed :: () -> string {
    if editor.transport.scrubbing || editor.transport.playing || editor_view.dragging || editor_view.wheeling {
        if !editor.game_speed_known return "...";
        return tprint("%x", formatFloat(editor.game_speed_value, mode = .SHORTEST));
    }
    return editor_playback_speed_name(editor_transport_speed(*editor.transport));
}

editor_busy :: () -> bool {
    return editor.reset_requested || editor_transport_busy(*editor.transport, *editor.timeline);
}

editor_seek :: (position: s64, playing := false, scrubbing := false, rabbit := false) {
    if !editor.open return;
    if editor_wait_edit.active return;
    if editor_save_prompt.active { editor_set_status("Finish or cancel the save confirmation before seeking."); return; }
    if playing && !editor_validate_playback_speed(ifx rabbit then .RABBIT else editor.transport.speed) return;
    if !editor_transport_busy(*editor.transport, *editor.timeline) editor.ready_at = 0;
    editor.transport.target = max(0, min(editor.timeline.keys.count, position));
    editor_timer_cancel();
    editor.transport.playing             = playing;
    editor.transport.rabbit              = playing && rabbit;
    editor.transport.scrubbing           = scrubbing;
    editor.transport.restart_before_seek = false;
    editor.transport.scrub_rate          = editor_playback_rate(.RABBIT);
    editor.transport.held_step           = 0;
    editor.transport.undo_delay_ms       = EDITOR_FORWARD_DELAY;
    editor_view.recording_motion         = false;
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
    if editor_save_prompt.active { console_write(*console, "Finish or cancel the save confirmation before jump.", .ERROR); return; }
    if editor_wait_edit.active && !editor_confirm_wait() return;
    restart := target < editor.timeline.playhead;
    if restart && !editor.keymap.restart.scan { console_write(*console, "No keyboard binding for restart.", .ERROR); return; }
    editor_pause();
    if editor.transport.held.scan || editor.transport.time_held || editor.speed_override.memory.handle return;
    editor_view_cancel_drag();
    if target == editor.timeline.playhead {
        editor_set_status(tprint("Already at step %.", target));
        console_write(*console, editor.status);
        return;
    }
    editor_seek(target, scrubbing = true);
    editor.transport.scrub_rate          = 16;
    editor.transport.restart_before_seek = restart;
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
    if repeat_while_held && !editor_save_prompt.active &&
       !editor.transport.held.scan && !editor.transport.time_held {
        editor.transport.held_step = direction;
        if direction < 0 editor.transport.undo_delay_ms = EDITOR_HELD_UNDO_DELAY;
    }
}

editor_reset :: () {
    if !editor.open return;
    editor_finish_wait_edit();
    editor_pause();
    if editor.transport.held.scan || editor.transport.time_held return;
    error := timeline_load(*editor.reset_timeline, editor.record.solution);
    if error.count { editor_set_status(error, true); return; }
    editor.reset_requested    = true;
    editor.focus_from_console = Win.GetForegroundWindow() == overlay.window;
    editor_view_cancel_drag();
    editor_set_status("Resetting the game and restoring the last saved solution...");
}

editor_finish_reset :: () {
    timeline_free(*editor.timeline);
    editor.timeline          = editor.reset_timeline;
    editor.reset_timeline    = .{};
    editor.reset_requested   = false;
    editor.transport.target  = 0;
    editor.transport.playing = false;
    editor.synchronized      = true;
    editor_view_reset();
    editor_set_status("Game reset. Last saved solution restored.");
}

editor_rabbit_play :: () {
    if !editor.open return;
    if editor_wait_edit.active return;
    if editor_save_prompt.active { editor_set_status("Finish or cancel the save confirmation before playback."); return; }
    if editor.transport.rabbit {
        editor_pause();
        if !editor.transport.held.scan && !editor.transport.time_held editor_set_status("Paused");
        return;
    }
    if !editor_validate_playback_speed(.RABBIT) return;
    editor_pause();
    if editor.transport.held.scan || editor.transport.time_held return;
    editor_view_cancel_drag();
    editor_seek(editor.timeline.keys.count, playing = true, rabbit = true);
    if editor.transport.playing editor_set_status(tprint("Playing at 4x from step %.", editor.timeline.playhead));
}

editor_export_solution :: () {
    if !editor.open return;
    text := timeline_serialize(*editor.timeline);
    defer free(text);
    error := clipboard_write_text(editor_window_handle(), text);
    if error.count { editor_set_status(error, true); return; }
    editor_set_status(tprint("Copied % solution steps to the clipboard.", editor.timeline.keys.count));
}

editor_validate_playback_speed :: (speed: Editor_Playback_Speed) -> bool {
    return cast(s64) speed >= 0 && cast(s64) speed <= cast(s64) Editor_Playback_Speed.RABBIT;
}

editor_set_playback_speed :: (speed: Editor_Playback_Speed) {
    if editor_wait_edit.active return;
    if !editor.open || editor_save_prompt.active || !editor_validate_playback_speed(speed) return;
    editor.transport.speed  = speed;
    editor.transport.rabbit = false;
    editor_set_status(tprint("Playback speed: %.", editor_playback_speed_name(speed)));
}

editor_adjust_playback_speed :: (faster: bool) {
    editor_set_playback_speed(editor_playback_speed_adjust(editor_transport_speed(*editor.transport), faster));
}

editor_toggle_record :: () {
    editor_set_recording(!editor.recording);
}

editor_set_recording :: (recording: bool) -> bool {
    if !recording editor_timer_cancel();
    if !editor.open return false;
    if editor_wait_edit.active return false;
    if editor_save_prompt.active {
        editor_set_status("Finish or cancel the save confirmation before recording.", true);
        return false;
    }
    editor_pause();
    editor_view_cancel_drag();
    if editor.transport.held.scan || editor.transport.time_held return false;
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
    editor_timer_cancel();
    if !editor.open return;
    editor_finish_wait_edit();
    editor_pause();
    if clear_executed timeline_clear_executed(*editor.timeline);
    editor.timeline.playhead = 0;
    timeline_move_caret(*editor.timeline, 0);
    editor.transport.target = 0;
    editor.synchronized     = true;
    editor_view_reset();
    if clear_executed editor_set_status("Executed moves cleared. Recording continues.");
    else editor_set_status("Game reset. Timeline is back at the beginning.");
}

editor_save :: () {
    if editor.open editor_begin_save_prompt();
}

editor_close :: (discard := false, after: Editor_After_Save = .CLOSE, next_level: string = "", next_custom := false) -> bool {
    if !editor.open return true;
    editor_finish_wait_edit();
    editor_pause();
    if editor.speed_override.memory.handle return false;
    if !discard && editor.timeline.dirty {
        editor_begin_save_prompt(after, next_level, next_custom);
        return false;
    }
    editor_clear_save_prompt();
    editor.open      = false;
    editor.recording = false;
    editor_remove_keyboard_hook();
    playback_speed_close(*editor.speed_reader);
    if Win.GetForegroundWindow() == editor_window_handle() editor_focus_game();
    editor_window_hide();
    solution_record_free(*editor.record);
    timeline_free(*editor.timeline);
    return true;
}

editor_deinit :: () {
    editor_timer_cancel();
    editor_finish_wait_edit();
    editor_pause();
    playback_speed_close(*editor.speed_reader);
    editor_clear_save_prompt();
    editor.open = false;
    editor_remove_keyboard_hook();
    editor_window_destroy();
    solution_record_free(*editor.record);
    timeline_free(*editor.timeline);
    free(editor.status);
}

editor_on_game_position_changed :: () {
    if !editor.open return;
    editor_pause();
    editor_view_cancel_drag();
    editor.recording    = false;
    editor.synchronized = false;
    editor_set_status("Position changed. Playback and recording paused; the timeline is ready to continue.");
}

editor_record_symbol :: (symbol: u8) {
    if !editor.open || !editor.recording || editor_save_prompt.active || editor_wait_edit.active return;
    if editor.timeline.keys.count >= SEND_KEY_LIMIT return;
    if editor_timer.phase != .OFF {
        clock, error := editor_timer_sample();
        if error.count { editor_timer_cancel(); editor_set_status(error, true); }
        else editor_timer_action(clock);
    }
    if !timeline_record(*editor.timeline, symbol) return;
    editor_view_cancel_drag();
    editor_view.recording_motion = true;
    editor.transport.target      = editor.timeline.playhead;
}

editor_on_game_key :: (vk: u32, shift := false) {
    if !editor.open return;
    if vk == 0x1b { editor_pause(); return; }
    if vk == editor.keymap.restart.vk {
        if editor.recording && shift {
            editor_pause();
            editor_record_symbol(#char "!");
            return;
        }
        editor_on_game_reset(clear_executed = editor.recording);
        return;
    }
    symbol := game_symbol_for_vk(*editor.keymap, vk);
    if !symbol && vk != editor.keymap.undo.vk && vk != editor.keymap.restart.vk return;
    if vk == editor.keymap.undo.vk {
        editor_timer_cancel();
        editor_pause();
        timeline_apply_game_undo(*editor.timeline);
        editor_view_reset();
        editor.transport.target = editor.timeline.playhead;
        return;
    }
    if symbol editor_record_symbol(symbol);
    // Manual navigation remains available with an open editor, including during
    // playback. It neither appends unrecorded steps nor locks later playback.
}

editor_update :: (now: float64) {
    editor_process_window_events();
    if editor_timer.phase != .OFF && (!editor.open || !editor.recording || editor_save_prompt.active ||
       editor_wait_edit.active || !editor_game_valid() || Win.GetForegroundWindow() != editor.game) editor_timer_cancel();
    if !editor.open return;
    if editor_view.wheeling && now - editor_view.wheel_last_time > 0.18 {
        editor_view.wheeling = false;
        editor_end_fast_scrub();
    }
    if editor_input_overflowed() {
        editor_pause();
        editor.recording    = false;
        editor.synchronized = false;
        editor_set_status("Recording input overflowed. Recording paused; review the timeline before continuing.", true);
    }
    editor_window_update();
    if !editor_game_valid() {
        editor_pause();
        editor.synchronized = false;
        editor.recording    = false;
        return;
    }
    foreground   := Win.GetForegroundWindow();
    from_console := foreground == overlay.window && editor.focus_from_console;
    if (!from_console && foreground != editor.game && foreground != editor_window_handle()) ||
       process_console_should_exit() || overlay.quit_requested {
        if !foreground && editor.focus_requested && now < editor.focus_deadline &&
           !process_console_should_exit() && !overlay.quit_requested return;
        editor_view_cancel_drag();
        editor_pause();
        return;
    }
    if !editor_busy() { editor_restore_speed(); return; }
    if foreground != editor.game {
        if !editor.focus_requested {
            editor_focus_game();
            editor.focus_requested = true;
            editor.focus_deadline  = now + 1;
        } else if now >= editor.focus_deadline {
            editor_pause();
            editor_set_status("Could not focus the game. Playback paused.", true);
        }
        return;
    }
    editor.focus_requested    = false;
    editor.focus_from_console = false;
    if overlay.visible overlay_hide(restore_game = false);
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
    game_rate, rate_error := editor_playback_game_rate();
    if rate_error.count {
        message := copy_string(rate_error);
        defer free(message);
        editor_pause();
        editor_set_status(message, true);
        return;
    }
    error := editor_transport_tick(*editor.transport, *editor.timeline, *editor.keymap, seconds_since_init(), editor_emit_key, game_rate);
    if error.count {
        editor_pause();
        editor_set_status(error, true);
    }
    if !editor_busy() editor_restore_speed();
}
