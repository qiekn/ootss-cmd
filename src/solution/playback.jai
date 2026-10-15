// Nominal 1x time. Re-sampling a multiplier preserves already elapsed progress.
Playback_Clock :: struct {
    value, wall_time: float64;
    rate:             float64 = 1;
    initialized:      bool;
}

playback_clock_time :: (clock: *Playback_Clock, now: float64) -> float64 {
    if !clock.initialized return now;
    return clock.value + max(cast(float64) 0, now - clock.wall_time) * clock.rate;
}

playback_clock_update :: (clock: *Playback_Clock, now: float64, rate: float64) -> float64 {
    clock.value       = playback_clock_time(clock, now);
    clock.wall_time   = now;
    clock.rate        = rate;
    clock.initialized = true;
    return clock.value;
}

Playback_Speed_Reader :: struct {
    session: Game_Speed_Session;
    game:    Win.HWND;
    pid:     u32;
}

playback_speed_close :: (reader: *Playback_Speed_Reader) {
    game_speed_close(*reader.session); // Always read-only; owns no game changes.
    reader.* = .{};
}

playback_speed_read :: (reader: *Playback_Speed_Reader, game: Win.HWND) -> (rate: float64, error: string) {
    pid := process_window_pid(game);
    if !game || !pid return 0, "The playback game is no longer available.";
    if reader.session.memory.handle && (reader.game != game || reader.pid != pid ||
       process_memory_has_exited(reader.session.memory)) playback_speed_close(reader);
    if !reader.session.memory.handle {
        error := game_speed_open(*reader.session, game, writable = false);
        if error.count return 0, error;
        reader.game = game;
        reader.pid  = pid;
    }
    value, error := game_speed_read(*reader.session);
    if error.count { playback_speed_close(reader); return 0, error; }
    if value <= 0 return 0, "Game speed is 0. Resume the game before playback.";
    return value, "";
}
