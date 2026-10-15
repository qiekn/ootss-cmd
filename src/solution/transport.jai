Editor_Emit_Key       :: #type (key: Game_Key, key_up: bool) -> string;
Editor_Playback_Speed :: enum { TURTLE; SLOW; NORMAL; FAST; DOUBLE; TRIPLE; RABBIT; }

EDITOR_FORWARD_DELAY    :: 250;
EDITOR_SCRUB_UNDO_DELAY :: 10;
EDITOR_HELD_UNDO_DELAY  :: 125;

Editor_Transport :: struct {
    playing:             bool;
    speed:               Editor_Playback_Speed = .NORMAL;
    rabbit:              bool; // Temporary button mode; never overwrites the selected playback speed.
    scrubbing:           bool;
    restart_before_seek: bool;
    reversing:           bool; // Direction of the current complete key cycle.
    held_step:           s64;
    target:              s64;
    phase:               enum { IDLE; HOLD; GAP; WAIT; };
    deadline:            float64;
    clock:               Playback_Clock;
    wait_duration:       float64;
    scrub_rate:          float64 = 4;
    held:                Game_Key;
    time_held:           bool;
    time_key:            Game_Key;
    gap_ms:              float64;
    forward_delay_ms:    s32 = EDITOR_FORWARD_DELAY;
    undo_delay_ms:       s32 = EDITOR_FORWARD_DELAY;
}

editor_transport_busy :: (transport: *Editor_Transport, timeline: *Solution_Timeline) -> bool {
    return transport.playing || transport.restart_before_seek || transport.held_step != 0 || transport.target != timeline.playhead || transport.phase != .IDLE ||
           transport.held.scan != 0 || transport.time_held;
}

editor_transport_stop :: (transport: *Editor_Transport, timeline: *Solution_Timeline, emit: Editor_Emit_Key) -> string {
    transport.playing             = false;
    transport.rabbit              = false;
    transport.scrubbing           = false;
    transport.restart_before_seek = false;
    transport.reversing           = false;
    transport.held_step           = 0;
    transport.target              = timeline.playhead;
    transport.phase               = .IDLE;
    transport.clock               = .{};
    error: string;
    if transport.held.scan {
        error = emit(transport.held, true);
        if error.count error = emit(transport.held, true); // Retry a failed release, like send_sequence.
        if !error.count transport.held = .{};
    }
    if transport.time_held {
        time_error := emit(transport.time_key, true);
        if time_error.count time_error = emit(transport.time_key, true);
        if !time_error.count transport.time_held = false;
        if !error.count error = time_error;
    }
    return error;
}

editor_transport_speed :: (transport: *Editor_Transport) -> Editor_Playback_Speed {
    return ifx transport.rabbit then .RABBIT else transport.speed;
}

editor_playback_rate :: (speed: Editor_Playback_Speed) -> float64 {
    if speed == {
        case .TURTLE; return 0.25;
        case .SLOW;   return 0.5;
        case .FAST;   return 1.5;
        case .DOUBLE; return 2;
        case .TRIPLE; return 3;
        case .RABBIT; return 4;
    }
    return 1;
}

editor_playback_delay :: (speed: Editor_Playback_Speed, normal_delay: s32 = EDITOR_FORWARD_DELAY) -> float64 {
    return normal_delay / editor_playback_rate(speed);
}

editor_playback_speed_name :: (speed: Editor_Playback_Speed) -> string {
    if speed == {
        case .TURTLE; return "0.25x";
        case .SLOW;   return "0.5x";
        case .FAST;   return "1.5x";
        case .DOUBLE; return "2x";
        case .TRIPLE; return "3x";
        case .RABBIT; return "4x";
    }
    return "1x";
}

editor_playback_speed_adjust :: (speed: Editor_Playback_Speed, faster: bool) -> Editor_Playback_Speed {
    speeds := Editor_Playback_Speed.[.TURTLE, .SLOW, .NORMAL, .FAST, .DOUBLE, .TRIPLE, .RABBIT];
    for current: speeds if current == speed return speeds[max(0, min(speeds.count - 1, it_index + (ifx faster then 1 else -1)))];
    return .NORMAL;
}

editor_transport_reversing :: (transport: *Editor_Transport, timeline: *Solution_Timeline) -> bool {
    if transport.restart_before_seek return false;
    if transport.phase == .HOLD || transport.phase == .GAP return transport.reversing;
    return !transport.playing && transport.target < timeline.playhead;
}

editor_transport_multiplier :: (transport: *Editor_Transport, timeline: *Solution_Timeline) -> float64 {
    if editor_transport_reversing(transport, timeline) return 1;
    if transport.playing return editor_playback_rate(editor_transport_speed(transport));
    if transport.scrubbing && (transport.restart_before_seek || transport.target > timeline.playhead || transport.phase != .IDLE) return transport.scrub_rate;
    return 1;
}

editor_transport_tick :: (transport: *Editor_Transport, timeline: *Solution_Timeline, map: *Game_Keymap,
                          wall_now: float64, emit: Editor_Emit_Key, game_rate: float64 = 1) -> string {
    if !is_finite(game_rate) || game_rate <= 0 return "Game speed must be positive before playback.";
    rate := game_rate * editor_transport_multiplier(transport, timeline);
    now  := playback_clock_update(*transport.clock, wall_now, rate);
    if transport.phase == .WAIT {
        if now < transport.deadline return "";
        timeline_advance(timeline, 1);
        transport.phase = .IDLE;
    }
    if transport.phase == .HOLD {
        if now < transport.deadline return "";
        error := emit(transport.held, true);
        if error.count return error;
        transport.held     = .{};
        transport.phase    = .GAP;
        transport.deadline = now + cast(float64) transport.gap_ms / 1000;
    }
    if transport.phase == .GAP {
        if now < transport.deadline return "";
        transport.phase = .IDLE;
        next_target := ifx transport.playing then timeline.keys.count else
                       (ifx transport.held_step != 0 then timeline.playhead + transport.held_step else transport.target);
        // Let the runtime restore/apply game speed before a changed direction sends a key.
        if next_target != timeline.playhead && (next_target < timeline.playhead) != transport.reversing return "";
    }
    if transport.playing transport.target = timeline.keys.count;
    // Extend an explicitly held step only after the previous complete key cycle.
    if transport.held_step != 0 transport.target = timeline.playhead + transport.held_step;
    transport.target = max(0, min(timeline.keys.count, transport.target));
    if transport.restart_before_seek {
        error := editor_transport_press(transport, map.restart, EDITOR_FORWARD_DELAY, now, emit);
        if error.count return error;
        transport.restart_before_seek = false;
        transport.reversing           = false;
        // Restart the game without replacing the edited solution or its saved snapshot.
        timeline.playhead = 0;
        return "";
    }
    if transport.target == timeline.playhead {
        return editor_transport_stop(transport, timeline, emit);
    }

    forward := transport.target > timeline.playhead;
    transport.reversing = !forward;
    if !forward {
        // Character switches and waits do not enter the game's undo history. Cross these cells
        // without sending Z, which would otherwise undo an earlier game action.
        while timeline.playhead > transport.target &&
              !timeline_key_is_undoable(timeline.keys[timeline.playhead - 1]) {
            if timeline.keys[timeline.playhead - 1] == #char "!" return "Use jump to replay across a recorded restart.";
            timeline_advance(timeline, -1);
        }
        if transport.target == timeline.playhead {
            if transport.held_step != 0 {
                // Empty undo cells still take the selected interval during held repetition.
                transport.phase    = .GAP;
                transport.deadline = now + cast(float64) transport.undo_delay_ms / 1000;
                return "";
            }
            return editor_transport_stop(transport, timeline, emit);
        }
    }
    delay_ms := ifx forward then transport.forward_delay_ms
                            else (ifx transport.scrubbing then EDITOR_SCRUB_UNDO_DELAY else transport.undo_delay_ms);
    if forward && timeline.keys[timeline.playhead] == #char "_" {
        transport.phase         = .WAIT;
        transport.wait_duration = cast(float64) timeline_wait_ms(timeline, timeline.playhead) / 1000;
        transport.deadline      = now + transport.wait_duration;
        return "";
    }
    key   := ifx forward then game_key_for_symbol(map, timeline.keys[timeline.playhead]) else map.undo;
    error := editor_transport_press(transport, key, cast(s32) delay_ms, now, emit);
    if error.count return error;
    // Once key-down succeeds this step belongs to the game, including when pause follows immediately.
    timeline_advance(timeline, ifx forward then 1 else -1);
    return "";
}

// Reset uses the same press/release lifecycle without counting R as a solution step.
editor_transport_press :: (transport: *Editor_Transport, key: Game_Key, delay_ms: s32, now: float64, emit: Editor_Emit_Key) -> string {
    if transport.held.scan || transport.phase != .IDLE return "A previous key is still being released.";
    if !key.scan return "No keyboard binding for this action.";
    error := emit(key, false);
    if error.count return error;
    transport.held = key;
    hold_ms := send_scaled_hold(cast(float64) delay_ms, transport.clock.rate);
    transport.gap_ms   = delay_ms - hold_ms;
    transport.phase    = .HOLD;
    transport.deadline = now + cast(float64) hold_ms / 1000;
    return "";
}
