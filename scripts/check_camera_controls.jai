#!/usr/bin/env jai

// Camera/input state and geometry checks; no game writes, hooks or input injection.
#run {
    set_build_options_dc(.{do_output = false});
    check_lock();
    check_commands();
    check_ground_directions();
    check_topdown();
    print("PASS: % camera lock/view movement checks; no game writes or input.\n", checks);
}

checks: s64;
check :: (condition: bool, message: string) {
    checks += 1;
    if !condition { compiler_report(message); assert(condition); }
}

check_position :: (actual: App.Game_Position, expected: App.Game_Position, message: string) {
    for i: 0..2 check(abs(actual[i] - expected[i]) < 0.00001, message);
}

check_lock :: () {
    game := cast(Win.HWND) 1;
    App.freecam = .{enabled = true, game = game, mode = .PAN};
    defer App.freecam = .{};
    App.freecam.session = .{owns_mode = true, settled = true, position = .[4, 5, 20], orientation = App.GAME_CAMERA_TOPDOWN};
    check(App.freecam_filter_key(#char "W", true, false, game), "Freecam owns a fresh movement press.");
    App.noclip.queue_count = 2;
    check(!App.freecam_set_locked(true).count, "Lock an existing session.");
    check(App.freecam.locked && App.freecam.enabled && App.freecam.session.owns_mode, "Lock keeps ownership of the frozen camera.");
    check(!App.freecam.moving[0] && !App.freecam.tapped[0] && !App.noclip.queue_count, "Lock drops pending camera and noclip motion.");
    check_position(App.freecam.session.position, .[4, 5, 20], "Lock preserves position.");
    check(App.freecam_filter_key(#char "W", true, false, game), "A previously consumed held key stays consumed until release.");
    check(App.freecam_filter_key(#char "W", false, false, game), "Lock still consumes the matching old keyup.");
    for key: "WSADQE" {
        check(!App.freecam_filter_key(key, true, false, game), "Fresh locked-camera keys reach the player.");
        check(!App.freecam_filter_key(key, false, false, game), "Player keyups pass through too.");
    }
    check(!App.freecam_set_locked(true).count, "Repeated lock is idempotent.");
    check(!App.freecam_set_locked(false).count && !App.freecam.locked, "Unlock resumes the previous freecam mode.");
    check(App.freecam.mode == .PAN && App.freecam.session.settled, "Unlock preserves the mode and settled pose.");
    check(App.freecam_filter_key(#char "D", true, false, game), "Fresh presses move the camera after unlock.");
    check(App.freecam_filter_key(#char "D", false, false, game), "Unlocked key release remains paired.");
    check(!App.freecam_filter_key(#char "A", true, true, game), "Injected keys never become camera motion.");
    check(!App.freecam_filter_key(#char "S", true, false, cast(Win.HWND) 2), "Unrelated focus never becomes camera motion.");
    App.freecam.stopping = true;
    check(App.freecam_set_locked(true).count > 0, "Cleanup cannot be interrupted by relocking.");
    App.noclip = .{};
}

check_commands :: () {
    state: App.Console_State;
    defer App.console_deinit(*state);
    App.freecam = .{};
    defer App.freecam = .{};
    for command: string.["lock", "unlock"] {
        App.console_execute_command(*state, command);
        check(state.pending_action == .NONE && !App.freecam.enabled, "Lock commands cannot enable freecam implicitly.");
    }
    check(App.freecam_set_locked(true).count > 0 && App.freecam_set_locked(false).count > 0,
          "Execution also rejects lock and unlock if freecam stopped after submission.");
    App.freecam.enabled  = true;
    App.freecam.stopping = true;
    App.command_lock(*state, "");
    check(state.pending_action == .NONE, "Cleanup blocks new lock requests.");
    App.freecam.stopping = false;
    for command: string.["lock", "UNLOCK"] {
        state.pending_action = .NONE;
        App.console_execute_command(*state, command);
        check(state.pending_action == .FREECAM, "Lock commands queue through the validated submission path.");
        check(state.pending_camera_lock == (ifx command == "lock" then App.Camera_Lock_Action.LOCK else .UNLOCK), "Lock and unlock remain distinct.");
    }
    for command: string.["camera lock", "camera unlock", "lock extra", "unlock lock"] {
        state.pending_action = .NONE;
        App.console_execute_command(*state, command);
        check(state.pending_action == .NONE, "Invalid camera commands never queue a mutation.");
    }
    state.pending_action          = .NONE;
    App.editor_save_prompt.active = true;
    App.command_lock(*state, "");
    check(state.pending_action == .NONE, "Save confirmation blocks camera changes.");
    App.editor_save_prompt.active = false;
    App.capture.phase             = .MOVE;
    App.command_lock(*state, "");
    check(state.pending_action == .NONE, "Capture owns camera controls exclusively.");
    App.capture.phase         = .IDLE;
    state.pending_camera_lock = .LOCK;
    App.command_freecam(*state, "-topdown");
    check(state.pending_camera_lock == .NONE, "A later freecam command cannot inherit a canceled lock.");
    state.pending_action      = .NONE;
    state.pending_camera_lock = .LOCK;
    App.command_set(*state, "camera 1 2 3");
    check(state.pending_camera_lock == .NONE, "An absolute camera write cannot inherit a canceled lock.");
    for command: string.["move -view 1 -2 3", "MOVE -VIEW 1 -2 3"] {
        state.pending_action = .NONE;
        App.console_execute_command(*state, command);
        check(state.pending_action == .SET_POSITION && state.pending_position_relative && state.pending_position_view, "Queue view-relative offsets case-insensitively.");
        check_position(state.pending_position, .[1, -2, 3], "View command retains signed offsets until execution.");
    }
    for command: string.["move -view", "move -view 1", "move -view 1 nan", "move -view 1 2 3 4", "move -view -x 1", "move -view 1e10 0"] {
        state.pending_action = .NONE;
        App.console_execute_command(*state, command);
        check(state.pending_action == .NONE, "Invalid view offsets do not queue movement.");
    }
    for command: string.["move -x 2", "move 2 0", "move_xy 2 0", "set position 2 0 0"] {
        state.pending_action = .NONE;
        App.console_execute_command(*state, command);
        check(state.pending_action == .SET_POSITION && !state.pending_position_view, "World coordinates clear the preceding view-relative flag.");
    }
    for text: string.["lo", "unlo", "move -vi"] {
        App.console_set_input(*state, text);
        App.console_complete(*state, .[], .[], .[]);
        expected := ifx text == "lo" then "lock " else ifx text == "unlo" then "unlock " else "move -view ";
        check(App.console_input(*state) == expected, "Complete camera actions and the view option.");
    }
}

check_ground_directions :: () {
    // Quarter-turn views, including steep overhead and horizontal views, keep
    // a one-unit movement on the nearest screen-aligned world grid axis.
    for turn: 0..3 {
        yaw    := PI64 / 2 + cast(float64) turn * PI64 / 2;
        rights := App.Game_Position.[.[1, 0, 0], .[0, 1, 0], .[-1, 0, 0], .[0, -1, 0]];
        ups    := App.Game_Position.[.[0, 1, 0], .[-1, 0, 0], .[0, -1, 0], .[1, 0, 0]];
        for pitch: float64.[-PI64 / 2, -PI64 / 4, 0] {
            q            := App.game_camera_orientation(yaw, pitch);
            right, error := App.game_camera_ground_move(q, .[1, 0, 0], grid = true);
            check(!error.count, "Valid ground right.");
            check_position(right, rights[turn], "Screen right tracks quarter-turn views.");
            up: App.Game_Position;
            up, error = App.game_camera_ground_move(q, .[0, 1, 0], grid = true);
            check(!error.count, "Valid ground up.");
            check_position(up, ups[turn], "Screen up tracks quarter-turn views, including exact topdown.");
            opposite, opposite_error := App.game_camera_ground_move(q, .[-1, -1, 2.5], grid = true);
            check(!opposite_error.count, "Combined signed movement.");
            check_position(opposite, .[-right[0] - up[0], -right[1] - up[1], 2.5], "Opposite directions stay opposite and Z stays world vertical.");
        }
    }
    for yaw_offset: float64.[-0.2, 0, 0.2] {
        q            := App.game_camera_orientation(PI64 / 2 + yaw_offset, -PI64 / 4);
        delta, error := App.game_camera_ground_move(q, .[0, 1, 0], grid = true);
        check(!error.count, "Small view rotations are supported.");
        check_position(delta, .[0, 1, 0], "Small rotations never introduce fractional grid coordinates.");
    }
    delta, error := App.game_camera_ground_move(.[0, 0, 0, 0], .[1, 0, 0], grid = true);
    check(error.count > 0, "Reject invalid quaternion instead of guessing directions.");
    delta, error = App.game_camera_ground_move(App.GAME_CAMERA_TOPDOWN, .[1000001, 0, 0], grid = true);
    check(error.count > 0, "Reject out-of-range offsets.");
    q := float.[cast(float) sqrt(0.5), 0, 0, cast(float) sqrt(0.5)];
    delta, error = App.game_camera_ground_move(q, .[1, 0, 0], grid = true);
    check(error.count > 0, "A vertical screen-right projection is ambiguous and must fail.");
    delta, error = App.game_camera_ground_move(App.GAME_CAMERA_TOPDOWN, .[0, 0, 0], grid = true);
    check(!error.count, "Zero offsets are valid.");
    check_position(delta, .[0, 0, 0], "Zero offsets stay zero.");
    changed: bool;
    error, changed = App.game_write_position_to(.{}, .[1, 0, 0], view_relative = true);
    check(error.count > 0 && !changed, "View-relative absolute writes fail before opening or reading any memory.");
    error, changed = App.game_write_position_to(.{}, .[1, 0, 0], relative = true, view_relative = true);
    check(error.count > 0 && !changed, "Unavailable process memory never falls back to guessed world movement.");
}

check_topdown :: () {
    position, error := App.game_camera_topdown_position(.[90, -40, 30], .[2.25, -3.5, 5]);
    check(!error.count, "Center a valid overhead camera.");
    check_position(position, .[2.25, -3.5, 30], "Topdown centers X/Y on the player and preserves existing height.");
    position, error = App.game_camera_topdown_position(.[1, 2, -100], .[4, 5, 0]);
    check(!error.count, "A below-ground starting camera is supported.");
    check_position(position, .[4, 5, 10], "Low cameras get ten world units of clearance.");
    position, error = App.game_camera_topdown_position(.[4, 5, 10], .[4, 5, 0]);
    check(!error.count, "Repeated centering is valid.");
    check_position(position, .[4, 5, 10], "Repeated topdown does not keep raising the camera.");
    position, error = App.game_camera_topdown_position(.[0, 0, 999999], .[0, 0, 999999]);
    check(error.count > 0, "Reject a topdown pose beyond the coordinate limit.");
    position, error = App.game_camera_topdown_position(.[1000001, 0, 20], .[0, 0, 0]);
    check(error.count > 0, "Reject invalid initial camera coordinates.");
}

#import "Basic";
#import "Compiler";
#import "Math";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
