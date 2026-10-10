fog_session: Fog.Fog_Session;
fog_game:    Win.HWND;
fog_pid:     u32;

command_unfog :: (state: *Console_State, arguments: string) {
    console_queue_fog(state, arguments, false);
}

command_fog :: (state: *Console_State, arguments: string) {
    console_queue_fog(state, arguments, true);
}

console_queue_fog :: (state: *Console_State, arguments: string, enabled: bool) {
    if arguments.count {
        console_write(state, ifx enabled then "Usage: fog" else "Usage: unfog", .ERROR);
        return;
    }
    if !console_position_command_ready(state) return;
    state.pending_fog_change  = true;
    state.pending_fog_enabled = enabled;
}

console_run_pending_fog :: (state: *Console_State) {
    if !state.pending_fog_change return;
    ready, waiting := console_submission_ready(state, sends_input=false);
    if waiting return;
    state.pending_fog_change = false;
    if !ready || editor_save_prompt.active {
        console_write(state, "Fog command cancelled before starting.", .ERROR);
        return;
    }
    game := find_game_window();
    pid  := process_window_pid(game);
    if !game || !console_submission_target_matches(state.submission, game, pid) {
        console_write(state, "Fog command cancelled: the game changed.", .ERROR);
        return;
    }
    if fog_session.memory.handle && (game != fog_game || pid != fog_pid || Fog.fog_session_exited(*fog_session)) {
        error := Fog.fog_session_close(*fog_session);
        if error.count { console_write(state, error, .ERROR); return; }
    }
    if !fog_session.memory.handle {
        error := Fog.fog_session_open(*fog_session, game);
        if error.count { console_write(state, error, .ERROR); return; }
        fog_game = game;
        fog_pid  = pid;
    }
    error: string;
    if state.pending_fog_enabled {
        error = Fog.fog_session_write(*fog_session, 1);
        if !error.count error = Fog.fog_session_close(*fog_session);
    } else error = Fog.fog_session_disable(*fog_session);
    if error.count { console_write(state, error, .ERROR); return; }
    message := ifx state.pending_fog_enabled then "Exploration fog enabled." else "Exploration fog disabled (temporary).";
    console_write(state, message);
    hud_notify(message);
}

fog_deinit :: () {
    error := Fog.fog_session_close(*fog_session);
    if error.count print("Fog restoration failed: %\n", error);
}

#scope_file
Fog :: #import,file "fog_memory.jai";
