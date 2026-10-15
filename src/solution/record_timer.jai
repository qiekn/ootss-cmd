Editor_Record_Timer :: struct {
    phase:    enum { OFF; ARMED; RUNNING; };
    session:  Game_Speed_Session; // Read-only; the accumulated game clock includes speed changes.
    started:  float64;
    boundary: s64;
}
editor_timer: Editor_Record_Timer;

editor_timer_cancel :: () {
    game_speed_close(*editor_timer.session);
    editor_timer = .{};
}

editor_timer_toggle :: () {
    if !editor.open || !editor.recording || editor_save_prompt.active || editor_wait_edit.active return;
    if editor_timer.phase != .OFF {
        editor_timer_cancel();
        editor_set_status("Wait timer cancelled.");
        return;
    }
    editor_pause();
    if editor.transport.held.scan || editor.transport.time_held || editor.speed_override.memory.handle return;
    error := game_speed_open(*editor_timer.session, editor.game, writable = false);
    if error.count { editor_set_status(error, true); return; }
    editor_timer.phase = .ARMED;
    editor_set_status("Wait timer armed: next action starts, following action finishes. T cancels.");
}

editor_timer_wait_ms :: (started: float64, ended: float64) -> (duration: s32, error: string) {
    if !is_finite(started) || !is_finite(ended) || started < 0 || ended < started return 0, "Game clock changed; wait timer cancelled.";
    // Playback already spends 250 game milliseconds on the first key cycle.
    elapsed := (ended - started) * 1000 - DEFAULT_DELAY;
    if elapsed > 2147483647 return 0, "Measured wait exceeds the supported duration.";
    return cast(s32) max(cast(float64) 0, floor(elapsed + 0.5)), "";
}

editor_timer_sample :: () -> (clock: float64, error: string) {
    ignored, error := game_speed_read(*editor_timer.session);
    if error.count return 0, error;
    clock: float64;
    if !process_read_memory(editor_timer.session.memory.handle, editor_timer.session.layout.clock, *clock, 8) ||
       !is_finite(clock) || clock < 0 return 0, "Could not read the game's recording clock.";
    return clock, "";
}

// Called before inserting each recorded action, outside the keyboard hook.
editor_timer_action :: (clock: float64) {
    if editor_timer.phase == .ARMED {
        editor_timer.phase    = .RUNNING;
        editor_timer.started  = clock;
        editor_timer.boundary = editor.timeline.playhead + 1;
        editor_set_status("Wait timer running in game time; next action finishes it.");
        return;
    }
    if editor_timer.phase != .RUNNING return;
    if editor.timeline.playhead != editor_timer.boundary {
        editor_timer_cancel();
        editor_set_status("Timeline changed; wait timer cancelled.");
        return;
    }
    duration, error := editor_timer_wait_ms(editor_timer.started, clock);
    editor_timer_cancel();
    if error.count { editor_set_status(error, true); return; }
    if duration > 0 {
        if editor.timeline.keys.count > SEND_KEY_LIMIT - 2 {
            editor_set_status("No room for a measured wait and the next action.", true);
            return;
        }
        timeline_record(*editor.timeline, #char "_");
        timeline_set_wait(*editor.timeline, editor.timeline.playhead - 1, duration);
    }
    editor_set_status(tprint("Recorded wait: % game seconds (key cycle excluded).", send_wait_seconds_text(duration)));
}
