Editor_Emit_Key :: #type (key: Game_Key, key_up: bool) -> string;
Editor_Playback_Speed :: enum { NORMAL; FAST; RABBIT; TURTLE; }
EDITOR_FORWARD_DELAY :: 250;
EDITOR_SCRUB_DELAY :: 75;
EDITOR_SCRUB_UNDO_DELAY :: 10;
EDITOR_HELD_UNDO_DELAY :: 125;
Editor_Transport :: struct {
    playing: bool;
    test_playback: bool;
    speed: Editor_Playback_Speed;
    scrubbing: bool;
    held_step: s64;
    target: s64;
    phase: enum { IDLE; HOLD; GAP; WAIT; };
    deadline: float64;
    held: Game_Key;
    time_held: bool;
    time_key: Game_Key;
    gap_ms: s32;
    forward_delay_ms: s32 = EDITOR_FORWARD_DELAY;
    undo_delay_ms: s32 = EDITOR_FORWARD_DELAY;
}

editor_transport_busy :: (transport: *Editor_Transport, timeline: *Solution_Timeline) -> bool {
    return transport.playing || transport.held_step != 0 || transport.target != timeline.playhead || transport.phase != .IDLE ||
           transport.held.scan != 0 || transport.time_held;
}

editor_transport_stop :: (transport: *Editor_Transport, timeline: *Solution_Timeline, emit: Editor_Emit_Key) -> string {
    transport.playing = false;
    transport.test_playback = false;
    transport.speed = .NORMAL;
    transport.scrubbing = false;
    transport.held_step = 0;
    transport.target = timeline.playhead;
    transport.phase = .IDLE;
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

editor_playback_delay :: (speed: Editor_Playback_Speed, normal_delay: s32 = EDITOR_FORWARD_DELAY) -> s32 {
    if speed == {
        case .FAST;   return SEND_FAST_DELAY;
        case .RABBIT; return SEND_SUPERFAST_DELAY;
        case .TURTLE; return SEND_SUPERSLOW_DELAY;
    }
    return normal_delay;
}

editor_playback_time_key :: (map: *Game_Keymap, speed: Editor_Playback_Speed) -> Game_Key {
    if speed == .RABBIT return map.fast;
    if speed == .TURTLE return map.slow;
    return .{};
}

editor_transport_tick :: (transport: *Editor_Transport, timeline: *Solution_Timeline, map: *Game_Keymap,
                          now: float64, emit: Editor_Emit_Key) -> string {
    if transport.phase == .WAIT {
        if now < transport.deadline return "";
        timeline_advance(timeline, 1);
        transport.phase = .IDLE;
    }
    if transport.phase == .HOLD {
        if now < transport.deadline return "";
        error := emit(transport.held, true);
        if error.count return error;
        transport.held = .{};
        transport.phase = .GAP;
        transport.deadline = now + cast(float64) transport.gap_ms / 1000;
    }
    if transport.phase == .GAP {
        if now < transport.deadline return "";
        transport.phase = .IDLE;
    }
    if transport.playing transport.target = timeline.keys.count;
    // Extend held J/L by one cell only after the previous complete key cycle.
    if transport.held_step != 0 transport.target = timeline.playhead + transport.held_step;
    transport.target = max(0, min(timeline.keys.count, transport.target));
    if transport.target == timeline.playhead {
        return editor_transport_stop(transport, timeline, emit);
    }

    forward := transport.target > timeline.playhead;
    time_key: Game_Key;
    if forward time_key = editor_playback_time_key(map, ifx transport.scrubbing then .RABBIT else transport.speed);
    if transport.time_held && (time_key.scan != transport.time_key.scan || time_key.extended != transport.time_key.extended) {
        error := emit(transport.time_key, true);
        if error.count return error;
        transport.time_held = false;
    }
    if time_key.scan && !transport.time_held {
        error := emit(time_key, false);
        if error.count return error;
        transport.time_key = time_key;
        transport.time_held = true;
    }
    if !forward {
        // Character switches and waits do not enter the game's undo history. Cross these cells
        // without sending Z, which would otherwise undo an earlier game action.
        while timeline.playhead > transport.target &&
              !timeline_key_is_undoable(timeline.keys[timeline.playhead - 1]) {
            timeline_advance(timeline, -1);
        }
        if transport.target == timeline.playhead {
            if transport.held_step != 0 {
                // Empty undo cells still take one selected undo interval while holding L.
                transport.phase = .GAP;
                transport.deadline = now + cast(float64) transport.undo_delay_ms / 1000;
                return "";
            }
            return editor_transport_stop(transport, timeline, emit);
        }
    }
    delay_ms := ifx forward then (ifx transport.scrubbing then EDITOR_SCRUB_DELAY else
                                 editor_playback_delay(transport.speed, transport.forward_delay_ms))
                           else (ifx transport.scrubbing then EDITOR_SCRUB_UNDO_DELAY else transport.undo_delay_ms);
    if forward && timeline.keys[timeline.playhead] == #char "_" {
        transport.phase = .WAIT;
        transport.deadline = now + cast(float64) delay_ms / 1000;
        return "";
    }
    key := ifx forward then game_key_for_symbol(map, timeline.keys[timeline.playhead]) else map.undo;
    error := editor_transport_press(transport, key, cast(s32) delay_ms, now, emit);
    if error.count return error;
    // Once key-down succeeds this step belongs to the game, including when pause follows immediately.
    timeline_advance(timeline, ifx forward then 1 else -1);
    return "";
}

// Reset uses the same press/release lifecycle without counting R as a solution step.
editor_transport_press :: (transport: *Editor_Transport, key: Game_Key, delay_ms: s32,
                           now: float64, emit: Editor_Emit_Key) -> string {
    if transport.held.scan || transport.phase != .IDLE return "A previous key is still being released.";
    if !key.scan return "No keyboard binding for this action.";
    error := emit(key, false);
    if error.count return error;
    transport.held = key;
    hold_ms := send_hold_for_delay(delay_ms);
    transport.gap_ms = delay_ms - cast(s32) hold_ms;
    transport.phase = .HOLD;
    transport.deadline = now + cast(float64) hold_ms / 1000;
    return "";
}

#scope_file
#import "Basic";
