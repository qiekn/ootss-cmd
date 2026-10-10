Freecam_Mode  :: enum { MOUSE; PAN; TOPDOWN; }
Freecam_Speed :: enum { NORMAL; FAST; SLOW; }

FREECAM_MOUSE_HINT   :: "Okay, now you can fly. [Fly Guide] W/S/A/D/Q/E, Hold Shift to speed up, Ctrl to slow down. other options: -pan -topdown";
FREECAM_PAN_HINT     :: "Fixed orientation, WSAD to North/South/West/East";
FREECAM_TOPDOWN_HINT :: "Fixed topdown, WSAD to North/South/West/East";

freecam_mode_name :: (mode: Freecam_Mode) -> string {
    if mode == .TOPDOWN return "Top-down";
    if mode == .PAN return "Pan";
    return "Free";
}

freecam_hint :: (mode: Freecam_Mode) -> string {
    if mode == .TOPDOWN return FREECAM_TOPDOWN_HINT;
    if mode == .PAN return FREECAM_PAN_HINT;
    return FREECAM_MOUSE_HINT;
}

Freecam_State :: struct {
    enabled, stopping, reported_cleanup_error, looking: bool;
    mode:                                               Freecam_Mode;
    game:                                               Win.HWND;
    pid:                                                u32;
    session:                                            Game_Camera_Session;
    down, consumed, moving, tapped:                     [6] bool;
    yaw, pitch:                                         float64; // Mouse-look angles in radians; every turn rebuilds the orientation from them.
    ready_at, last_frame, retry_at:                     float64;
}

freecam: Freecam_State;

freecam_key_index :: (vk: u32) -> s64 {
    for key: "WSADQE" if vk == key return it_index;
    return -1;
}

freecam_clear_motion :: () {
    for *key: freecam.moving key.* = false;
    for *key: freecam.tapped key.* = false;
    freecam.last_frame = 0;
    freecam.looking    = false;
    freecam_unlock_cursor();
    // Retain down/consumed until release, even after disabling the mode.
}

freecam_filter_key :: (vk: u32, down: bool, injected: bool, foreground: Win.HWND, modifiers := false) -> bool {
    if injected return false;
    index := freecam_key_index(vk);
    if index < 0 return false;
    was_down := freecam.down[index];
    freecam.down[index] = down;
    if !down {
        consumed := freecam.consumed[index];
        freecam.consumed[index] = false;
        freecam.moving[index] = false;
        return consumed;
    }
    if was_down return freecam.consumed[index];
    if !freecam.enabled || !freecam.game || foreground != freecam.game || editor_save_prompt.active return false;
    freecam.consumed[index] = true;
    if capture.owns_camera { capture.pause_requested = true; return true; }
    // Configured shortcuts have already had priority. Shift and Ctrl only scale
    // the speed; Alt and Win chords are consumed without moving, so modified
    // movement keys never leak into character movement while freecam owns them.
    if !modifiers {
        freecam.moving[index] = true;
        freecam.tapped[index] = true;
    }
    send_input_filter_keyboard(0x100, 0, foreground);
    return true;
}

freecam_frame_delta :: (now: float64, speed: float64) -> Game_Position {
    elapsed := ifx freecam.last_frame > 0 then now - freecam.last_frame else 1.0 / 120;
    freecam.last_frame = now;
    if elapsed <= 0 return float.[0, 0, 0];
    elapsed = min(elapsed, 0.05); // A blocked UI or a focus handoff must not cause a large jump.
    axes: [6] float;
    for i: 0..5 if freecam.moving[i] || freecam.tapped[i] axes[i] = 1;
    for *key: freecam.tapped key.* = false; // A tap between frames still contributes once.
    distance := cast(float)(elapsed * speed);
    // Axes follow "WSADQE". Every mode uses Q down and E up.
    if freecam.mode != .MOUSE return game_camera_pan(axes[3] - axes[2], axes[0] - axes[1], axes[5] - axes[4], distance);
    return game_camera_movement(freecam.session.orientation, axes[0] - axes[1], axes[3] - axes[2], axes[5] - axes[4], distance);
}

// Mouse counts turn the view: right turns right and down looks down. Pitch stops
// short of the poles and yaw wraps, so the rebuilt orientation never rolls.
freecam_frame_turn :: (dx: s64, dy: s64, degrees_per_count: float64) -> [4] float {
    if !dx && !dy return freecam.session.orientation;
    step := degrees_per_count * PI64 / 180;
    freecam.yaw   = fmod_cycling(freecam.yaw - (cast(float64) dx) * step + PI64, 2 * PI64) - PI64;
    freecam.pitch = clamp(freecam.pitch - (cast(float64) dy) * step, -GAME_CAMERA_PITCH_LIMIT, GAME_CAMERA_PITCH_LIMIT);
    return game_camera_orientation(freecam.yaw, freecam.pitch);
}

freecam_speed :: (state: *Console_State) -> float64 {
    modifier := freecam_speed_modifier();
    if modifier == .SLOW return state.config.freecam_speed * state.config.freecam_ctrl_multiplier;
    if modifier == .FAST return state.config.freecam_speed * state.config.freecam_shift_multiplier;
    return state.config.freecam_speed;
}

command_freecam :: (state: *Console_State, arguments: string) {
    if capture_active() { console_write(state, "Pause or cancel capture before changing the camera.", .ERROR); return; }
    requested:              s32 = -1;
    pan, topdown, explicit: bool;
    cursor:                 s64;
    while true {
        argument := console_next_argument(arguments, *cursor);
        if !argument.count break;
        if equal_nocase(argument, "-pan") && !pan && !topdown {
            pan = true;
        } else if equal_nocase(argument, "-topdown") && !pan && !topdown {
            topdown = true;
        } else if (equal_nocase(argument, "enable") || equal_nocase(argument, "disable")) && !explicit {
            explicit = true;
            if equal_nocase(argument, "enable") requested = 1;
            else requested = 0;
        } else {
            console_write(state, "Usage: freecam [enable|disable] [-pan|-topdown]", .ERROR);
            return;
        }
    }
    if requested == 0 && (pan || topdown) { console_write(state, "freecam disable does not take a view option.", .ERROR); return; }
    if !console_position_command_ready(state) return;
    if editor_save_prompt.active {
        console_write(state, "Finish or cancel the save confirmation before changing camera mode.", .ERROR);
        return;
    }
    state.pending_freecam         = requested;
    state.pending_freecam_pan     = pan;
    state.pending_freecam_topdown = topdown;
    state.pending_camera_write    = false;
    state.pending_action          = .FREECAM;
}

freecam_finish_stop :: (state: *Console_State) {
    if !freecam.stopping return;
    if process_memory_has_exited(freecam.session.memory) freecam.session.owns_mode = false;
    error := game_camera_end(*freecam.session);
    if error.count && !freecam.reported_cleanup_error {
        console_write(state, error, .ERROR);
        freecam.reported_cleanup_error = true;
    }
    if freecam.session.owns_mode return;
    process_close_memory(*freecam.session.memory);
    freecam.session  = .{};
    freecam.stopping = false;
    freecam.game     = null;
    freecam.pid      = 0;
    hud_notify("Freecam disabled");
}

freecam_stop :: (state: *Console_State) {
    freecam.enabled  = false;
    freecam.stopping = true;
    freecam_clear_motion();
    freecam_remove_mouse();
    freecam_finish_stop(state);
}

freecam_switch_mode :: (state: *Console_State, mode: Freecam_Mode) {
    if mode == .TOPDOWN && freecam.session.settled {
        error, changed := game_camera_move(*freecam.session, .[0,0,0], GAME_CAMERA_TOPDOWN);
        if error.count { console_write(state, error, .ERROR); freecam_stop(state); return; }
    }
    if mode == .MOUSE {
        error := freecam_install_mouse(overlay.window);
        if error.count { console_write(state, error, .ERROR); return; }
    } else freecam_remove_mouse();
    freecam.mode               = mode;
    freecam.yaw, freecam.pitch = game_camera_angles(freecam.session.orientation);
    freecam_clear_motion(); // Releases the parked cursor; movement resumes with a fresh press.
    console_write(state, tprint("Freecam mode changed. %", freecam_hint(mode)));
    hud_notify(tprint("Freecam: %", freecam_mode_name(mode)));
}

console_run_pending_freecam :: (state: *Console_State) {
    if !state.pending_freecam_change return;
    ready, waiting := console_submission_ready(state, sends_input = false);
    if waiting return;
    if ready && state.pending_camera_write && freecam.enabled && !freecam.session.settled return;
    state.pending_freecam_change = false;
    if !ready || editor_save_prompt.active {
        state.pending_camera_write = false;
        console_write(state, "Camera mode change cancelled before starting.", .ERROR);
        return;
    }
    if capture_active() { state.pending_camera_write = false; console_write(state, "Pause capture before changing the camera.", .ERROR); return; }
    if state.pending_camera_write {
        state.pending_camera_write = false;
        if !freecam.enabled { console_write(state, "Enable freecam before setting its position.", .ERROR); return; }
        if !console_submission_target_matches(state.submission, freecam.game, freecam.pid) {
            console_write(state, "Camera move cancelled: the target game changed.", .ERROR); return;
        }
        freecam_clear_motion();
        error, changed := game_camera_set_position(*freecam.session, state.pending_camera_position);
        if error.count { console_write(state, error, .ERROR); return; }
        console_write(state, tprint("Camera: %", game_position_text(freecam.session.position)));
        hud_notify("Camera position set");
        return;
    }
    mode := ifx state.pending_freecam_topdown then Freecam_Mode.TOPDOWN else ifx state.pending_freecam_pan then Freecam_Mode.PAN else Freecam_Mode.MOUSE;
    // Bare freecam toggles off from either mode; freecam -pan toggles off only from pan mode.
    if state.pending_freecam == 0 || (state.pending_freecam < 0 && freecam.enabled &&
       (mode == .MOUSE || (mode == .PAN && freecam.mode == .PAN))) {
        freecam_stop(state);
        if !freecam.stopping console_write(state, "Freecam disabled.");
        return;
    }
    if freecam.stopping { console_write(state, "Wait for the previous camera session to finish restoring.", .ERROR); return; }
    if freecam.enabled {
        if mode == freecam.mode { console_write(state, "Freecam is already enabled."); return; }
        freecam_switch_mode(state, mode);
        return;
    }
    game := find_game_window();
    pid  := process_window_pid(game);
    if !game || !pid || !console_submission_target_matches(state.submission, game, pid) {
        console_write(state, "Freecam cancelled: the target game changed or is unavailable.", .ERROR);
        return;
    }
    error := freecam_start(game, mode);
    if error.count console_write(state, error, .ERROR);
    else console_write(state, tprint("Freecam enabled. %", freecam_hint(mode)));
}

freecam_start :: (game: Win.HWND, mode: Freecam_Mode) -> string {
    if freecam.enabled || freecam.stopping return "A free-camera session is already active.";
    pid := process_window_pid(game);
    if !game || !pid return "Game unavailable.";
    hook_error := freecam_install_hook();
    if hook_error.count return hook_error;
    memory, error := process_open_memory(game, GAME_EXECUTABLE, writable = true);
    if error.count return error;
    if process_window_pid(game) != pid {
        process_close_memory(*memory);
        return "Freecam cancelled: the game process changed.";
    }
    freecam.session                = .{};
    freecam.reported_cleanup_error = false;
    error                          = game_camera_begin(*freecam.session, memory);
    if error.count {
        // begin can fail after the mode was written. Always release it.
        freecam.session.memory = memory;
        freecam_stop(*console);
        return error;
    }
    if mode == .MOUSE {
        mouse_error := freecam_install_mouse(overlay.window);
        if mouse_error.count {
            freecam_stop(*console);
            return mouse_error;
        }
    }
    freecam.mode     = mode;
    freecam.game     = game;
    freecam.pid      = pid;
    freecam.enabled  = true;
    freecam.ready_at = seconds_since_init() + 0.08;
    freecam_clear_motion();
    for vk: "WSADQE" freecam.down[it_index] = Win.GetAsyncKeyState(cast(s32) vk) < 0;
    noclip_clear_motion();
    if editor.open {
        editor_pause();
        editor.recording = false;
    }
    return "";
}

freecam_update :: (state: *Console_State, now: float64) {
    if freecam.stopping {
        if now >= freecam.retry_at {
            freecam_finish_stop(state);
            freecam.retry_at = now + 0.5;
        }
        return;
    }
    if !freecam.enabled return;
    foreground := Win.GetForegroundWindow();
    if !freecam.game || process_window_pid(freecam.game) != freecam.pid ||
       overlay.game != freecam.game || overlay.quit_requested || process_console_should_exit() ||
       (foreground != freecam.game && foreground != overlay.window && foreground != editor_window.handle) {
        freecam_stop(state);
        return;
    }
    if !game_camera_identity_current(freecam.session.memory, freecam.session.layout, freecam.session.original) {
        console_write(state, "Freecam stopped because the scene or camera changed.");
        freecam_stop(state);
        return;
    }
    if !freecam.session.settled {
        if now < freecam.ready_at return;
        error := game_camera_settle(*freecam.session);
        if error.count { console_write(state, error, .ERROR); freecam_stop(state); return; }
        if freecam.mode == .TOPDOWN {
            top_error, changed := game_camera_move(*freecam.session, .[0,0,0], GAME_CAMERA_TOPDOWN);
            if top_error.count { console_write(state, top_error, .ERROR); freecam_stop(state); return; }
        }
        freecam.yaw, freecam.pitch = game_camera_angles(freecam.session.orientation);
        hud_notify(tprint("Freecam enabled: %", freecam_mode_name(freecam.mode)));
    }
    if capture.owns_camera || foreground != freecam.game || editor_save_prompt.active || state.pending_send.count || state.pending_position_change {
        freecam_clear_motion();
        return;
    }
    // Held directions come only from the hook's down/consumed tracking. Windows
    // never records a press that a low-level hook blocked, so GetAsyncKeyState
    // cannot gate them; the global hook still sees the release without focus,
    // and losing focus above already cleared motion until a fresh press.
    dx, dy: s64;
    if freecam.mode == .MOUSE {
        // Mouse motion arrives through raw input, independent of the parked cursor.
        dx = Input.mouse_delta_x;
        dy = Input.mouse_delta_y;
        if !freecam.looking {
            freecam.looking = true;
            dx              = 0; // Motion collected before the cursor was parked was ordinary pointing.
            dy              = 0;
        }
        freecam_lock_cursor(freecam.game);
    }
    orientation    := freecam_frame_turn(dx, dy, state.config.freecam_sensitivity);
    delta          := freecam_frame_delta(now, freecam_speed(state));
    error, changed := game_camera_move(*freecam.session, delta, orientation);
    if error.count { console_write(state, error, .ERROR); freecam_stop(state); }
}

freecam_deinit :: () {
    freecam_stop(*console);
    freecam_remove_hook();
    process_close_memory(*freecam.session.memory);
    freecam = .{};
}

console_show_camera :: (state: *Console_State) {
    snapshot, error := game_camera_read();
    if error.count { console_write(state, error, .ERROR); return; }
    yaw, pitch := game_camera_angles(snapshot.orientation);
    console_write(state, tprint("Camera XYZ: % (absolute world coordinates)", game_position_text(snapshot.position)));
    console_write(state, tprint("View: %; yaw: %; pitch: %; vertical FOV: % degrees",
        ifx freecam.enabled then freecam_mode_name(freecam.mode) else "Game",
        yaw*180/PI64, pitch*180/PI64, snapshot.projection[0]*180/PI64));
}
