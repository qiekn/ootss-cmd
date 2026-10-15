Time_Stop_State :: struct {
    phase:     enum { IDLE; STOPPING; STOPPED; RESUMING; };
    session:   Game_Speed_Session;
    game:      Win.HWND;
    pid:       u32;
    alternate: bool;
}
Time_Audio_Play :: #type (resume: bool, alternate: bool) -> string;
time_stop:        Time_Stop_State;
time_stop_random: Random.Random_State;
time_stop_seeded: bool;

time_stop_dialogue :: (resume: bool) -> string {
    return ifx resume then "Jotaro Kujo: “And time resumes.”" else "Jotaro Kujo: “Star Platinum: The World!”";
}

time_stop_speed_message :: (speed: float64) -> string {
    return tprint("Speed %x", formatFloat(speed, mode = .SHORTEST));
}

time_stop_begin :: (state: *Time_Stop_State, alternate: bool, play: Time_Audio_Play = time_audio_play, no_audio := false) -> string {
    if !no_audio {
        error := play(false, alternate);
        if error.count return error;
    }
    state.alternate = alternate;
    state.phase     = .STOPPING;
    if no_audio return time_stop_finish(state);
    hud_notify(time_stop_dialogue(false), 3);
    return "";
}

time_stop_finish :: (state: *Time_Stop_State) -> string {
    if state.phase != .STOPPING return "";
    error := game_speed_set(*state.session, 0);
    if !error.count {
        state.phase = .STOPPED;
        hud_notify(time_stop_speed_message(0), 3);
    }
    return error;
}

time_stop_resume :: (state: *Time_Stop_State, play: Time_Audio_Play = time_audio_play, no_audio := false) -> string {
    ignored, error := game_speed_read(*state.session);
    if error.count return error;
    if !no_audio {
        error = play(true, state.alternate);
        if error.count return error;
    }
    state.phase = .RESUMING; // Keep the owned speed unchanged until this audio finishes.
    if no_audio return time_stop_resume_finished(state);
    hud_notify(time_stop_dialogue(true), 3);
    return "";
}

time_stop_resume_finished :: (state: *Time_Stop_State) -> string {
    if state.phase != .RESUMING return "";
    speed, error := game_speed_read(*state.session);
    if error.count return error;
    if speed == state.session.last speed = state.session.original;
    error = game_speed_close(*state.session);
    if error.count return error;
    state.phase = .IDLE;
    hud_notify(time_stop_speed_message(speed), 3);
    return "";
}

time_stop_cancel :: () -> string {
    time_stop.phase = .IDLE;
    audio_error := time_audio_stop();
    error       := game_speed_close(*time_stop.session);
    return ifx error.count then error else audio_error;
}

time_stop_choose_alternate :: (probability: float64) -> bool {
    if probability <= 0 return false;
    if probability >= 1 return true;
    if !time_stop_seeded {
        now := current_time_monotonic();
        Random.random_seed(*time_stop_random, now.low);
        time_stop_seeded = true;
    }
    return Random.random_get_zero_to_one_open_new(*time_stop_random) < probability;
}

time_stop_toggle :: (game: Win.HWND, pid: u32) {
    if !game || game != find_game_window() || process_window_pid(game) != pid || Win.GetForegroundWindow() != game ||
       editor_save_prompt.active || editor_wait_edit.active return;
    if capture_active() || capture_speed.memory.handle {
        console_write(*console, "Pause map capture before stopping time.", .ERROR);
        return;
    }
    if editor.open {
        editor_pause();
        if editor.speed_override.memory.handle || editor.transport.held.scan || editor.transport.time_held return;
    }
    if time_stop.game != game || time_stop.pid != pid {
        error := time_stop_cancel();
        if error.count { console_write(*console, error, .ERROR); return; }
    }
    no_audio := console.config.time_stop_no_audio;
    if no_audio {
        error := time_audio_stop();
        if error.count { console_write(*console, error, .ERROR); return; }
    }
    if time_stop.phase == .STOPPING || time_stop.phase == .STOPPED {
        error := time_stop_resume(*time_stop, no_audio = no_audio);
        if error.count console_write(*console, error, .ERROR);
        return;
    }
    error: string;
    // Cancelling a pending resume keeps the original pre-stop snapshot and paused speed.
    if time_stop.phase != .RESUMING {
        error = time_stop_cancel();
        if error.count { console_write(*console, error, .ERROR); return; }
        error = game_speed_open(*time_stop.session, game);
        if error.count { console_write(*console, error, .ERROR); return; }
    }
    time_stop.game = game;
    time_stop.pid  = pid;
    alternate := time_stop_choose_alternate(console.config.time_stop_alt_probability);
    error = time_stop_begin(*time_stop, alternate, no_audio = no_audio);
    if error.count {
        console_write(*console, error, .ERROR);
        time_stop_cancel();
    }
}

time_stop_update :: () {
    if time_stop.phase == .IDLE return;
    valid       := time_stop.game == overlay.game && process_window_pid(time_stop.game) == time_stop.pid;
    foreground  := Win.GetForegroundWindow();
    interrupted := time_stop.phase == .STOPPING && foreground != time_stop.game &&
                   foreground != overlay.window && foreground != editor_window.handle;
    if !valid || interrupted || editor_save_prompt.active || capture_active() {
        error := time_stop_cancel();
        if error.count console_write(*console, error, .ERROR);
        return;
    }
    // Hot-reloading silent mode finishes a pending transition immediately and discards its audio.
    if console.config.time_stop_no_audio {
        error := time_audio_stop();
        if error.count { console_write(*console, error, .ERROR); return; }
    } else if !time_audio_finished() return;
    error: string;
    if time_stop.phase == .STOPPING error = time_stop_finish(*time_stop);
    else if time_stop.phase == .RESUMING error = time_stop_resume_finished(*time_stop);
    if error.count {
        console_write(*console, error, .ERROR);
        time_stop_cancel();
        return;
    }
    error = time_audio_stop();
    if error.count console_write(*console, error, .ERROR);
}

#scope_file
Random :: #import "Random";
