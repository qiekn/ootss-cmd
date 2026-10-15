#!/usr/bin/env jai

// In-memory timelines, invalid game handles and mock keys only; no game input or writes.
#run {
    set_build_options_dc(.{do_output = false});
    check_undo();
    check_record_restart();
    check_timer();
    check_focus_and_jump();
    print("PASS: % editor action checks; no game input or writes.\n", checks);
}

checks: s64;
check :: (ok: bool, message: string) {
    checks += 1;
    if !ok { compiler_report(message); assert(ok); }
}

check_undo :: () {
    timeline: App.Solution_Timeline;
    defer App.timeline_free(*timeline);
    check(!App.timeline_load(*timeline, "UUUC 2 _1.25_LL_3.5_").count, "Load undo with switches, waits and future.");
    timeline.playhead = 6;
    timeline.caret    = 9;
    timeline.anchor   = 7;
    check(App.timeline_apply_game_undo(*timeline) && timeline.playhead == 2 && timeline.keys.count == 5,
          "Physical Undo erases the action and trailing switches/waits instead of moving them into Future.");
    text := App.timeline_serialize(*timeline);
    defer free(text);
    check(text == "UULL_3.5_" && timeline.wait_ms[4] == 3500 && timeline.dirty, "Future steps and exact wait durations survive deletion.");
    check(timeline.caret == 5 && timeline.anchor == 3, "Future selection stays attached to its cells.");
    check(App.timeline_apply_game_undo(*timeline) && App.timeline_apply_game_undo(*timeline) && !App.timeline_apply_game_undo(*timeline),
          "Repeated Undo reaches zero safely and leaves the future intact.");
    for source: string.["", "C 2 _3.5_"] {
        App.timeline_load(*timeline, source);
        timeline.playhead = timeline.keys.count;
        check(!App.timeline_apply_game_undo(*timeline) && !timeline.dirty, "Empty or switch-only histories have no action to erase.");
    }
    App.timeline_load(*timeline, "U!R");
    timeline.playhead = 3;
    check(App.timeline_apply_game_undo(*timeline) && !App.timeline_apply_game_undo(*timeline) && timeline.keys.count == 2,
          "Physical Undo never crosses a recorded restart into obsolete game history.");
    App.editor = .{open = true, recording = true, keymap = App.game_keymap_defaults()};
    defer {
        App.timeline_free(*App.editor.timeline);
        free(App.editor.status);
        App.editor      = .{};
        App.editor_view = .{};
    }
    App.timeline_load(*App.editor.timeline, "UUULL");
    App.editor.timeline.playhead = 3;
    App.editor.transport         = .{playing = true, target = 5};
    App.editor_view.display_head = 3;
    App.editor_on_game_key(App.editor.keymap.undo.vk);
    check(App.editor.timeline.keys.count == 4 && App.editor.timeline.playhead == 2 && App.editor.transport.target == 2 &&
          !App.editor_busy() && App.editor.recording && App.editor_view.display_head == 2,
          "Z pauses playback, retains recording and snaps the shortened timeline without scrolling erased cells right.");
}

check_record_restart :: () {
    App.editor        = .{open = true, recording = true, game = cast(Win.HWND) -101, keymap = App.game_keymap_defaults()};
    App.editor_window = .{handle = cast(Win.HWND) -102};
    defer {
        App.timeline_free(*App.editor.timeline);
        free(App.editor.status);
        App.editor        = .{};
        App.editor_window = .{};
    }
    check(App.editor.transport.speed == .NORMAL, "New editors default to 1x.");
    check(App.editor_validate_playback_speed(.RABBIT), "Rabbit is a valid playback preset.");
    for compact: bool.[false, true] {
        App.editor_view.minimized = compact;
        App.timeline_load(*App.editor.timeline, "ULL");
        App.editor.timeline.playhead = 1;
        App.editor_filter_key(0xa0, true, false, App.editor.game);
        App.editor_filter_key(App.editor.keymap.restart.vk, true, false, App.editor.game);
        App.editor_filter_key(0xa0, false, false, App.editor.game);
        App.editor_process_window_events();
        text := App.timeline_serialize(*App.editor.timeline);
        defer free(text);
        check(text == "U!LL" && App.editor.timeline.playhead == 2 && App.editor.recording,
              "Shift state is captured with R; recording adds a restart without clearing the prefix or future.");
        App.editor_filter_key(App.editor.keymap.restart.vk, true, false, App.editor.game);
        check(!App.editor_window.event_count, "Holding Shift+R does not add duplicate reset cells.");
        App.editor_filter_key(App.editor.keymap.restart.vk, false, false, App.editor.game);
        check(App.editor_timeline_icon(#char "!") == "R" && App.game_key_for_symbol(*App.editor.keymap, #char "!").scan == App.editor.keymap.restart.scan,
              "Reset has an R label and replays the configured Restart key, independently of right arrows.");
        App.editor_on_game_key(App.editor.keymap.restart.vk);
        check(App.editor.timeline.keys.count == 2 && !App.editor.timeline.playhead, "Plain R retains its original clear-executed recording behavior.");
        App.editor_scrub_to(1);
        check(App.editor.transport.scrub_rate == 4, "Mouse scrub uses absolute Rabbit 4x.");
        App.editor_pause();
    }
    App.editor_view = .{};
    for alternate: bool.[false, true] {
        keys, error := App.expand_send("!R", alternate);
        defer free(keys);
        check(!error.count && keys == (ifx alternate then "!d" else "!r"), "Standalone parsing preserves reset while mapping direction R normally.");
    }
}

check_timer :: () {
    App.editor        = .{open = true, recording = true, game = cast(Win.HWND) -101, keymap = App.game_keymap_defaults()};
    App.editor_window = .{handle = cast(Win.HWND) -102};
    defer {
        App.editor_timer_cancel();
        App.timeline_free(*App.editor.timeline);
        free(App.editor.status);
        App.editor        = .{};
        App.editor_window = .{};
    }
    check(App.editor_filter_key(#char "T", true, false, App.editor.game) && App.editor_window.events[0].kind == .TIMER,
          "Recording T queues the timer outside the keyboard hook.");
    App.editor_window.event_count = 0;
    check(App.editor_filter_key(#char "T", true, false, App.editor.game) && !App.editor_window.event_count,
          "Holding T cannot repeatedly arm or cancel the timer.");
    App.editor_filter_key(#char "T", false, false, App.editor.game);
    check(!App.editor_filter_key(#char "T", true, true, App.editor.game) && !App.editor_window.event_count, "Injected T cannot arm recording.");
    App.timeline_load(*App.editor.timeline, "LL_3.5_");
    App.editor_timer.phase = .ARMED;
    check(!App.editor_filter_key(App.editor.keymap.fast.vk, true, false, App.editor.game) && !App.editor_window.event_count,
          "The physical fast-time key reaches the game while a measured recording is armed.");
    App.editor_filter_key(App.editor.keymap.fast.vk, false, false, App.editor.game);
    check(!App.editor_filter_key(App.editor.keymap.slow.vk, true, false, App.editor.game) && !App.editor_window.event_count,
          "The physical slow-time key reaches the game without stopping a measured recording.");
    App.editor_filter_key(App.editor.keymap.slow.vk, false, false, App.editor.game);
    App.editor_timer_action(10);
    App.timeline_record(*App.editor.timeline, #char "U");
    check(App.editor_timer.phase == .RUNNING && App.editor_timer.started == 10, "The first action, not T, starts the clock.");
    // One second at 1x, half a second at 4x and one second at 0.5x = 3.5 game seconds.
    App.editor_timer_action(13.5);
    App.timeline_record(*App.editor.timeline, #char "R");
    text := App.timeline_serialize(*App.editor.timeline);
    defer free(text);
    check(text == "U_3.25_RLL_3.5_" && App.editor.timeline.playhead == 3 && App.editor_timer.phase == .OFF,
          "Insert measured game time between the two actions, excluding the existing 250ms key cycle and preserving Future.");
    for elapsed: float64.[0, 0.1, 0.25] {
        duration, error := App.editor_timer_wait_ms(0, elapsed);
        check(!error.count && !duration, "Fast successive actions never produce negative or zero-length wait cells.");
    }
    for ended: float64.[9, 1.0e30] {
        duration, error := App.editor_timer_wait_ms(10, ended);
        check(error.count > 0, "Reject clock resets and oversized measured waits.");
    }
    App.editor_timer = .{phase = .RUNNING, started = 10, boundary = 99};
    before := App.editor.timeline.keys.count;
    App.editor_timer_action(11);
    check(App.editor_timer.phase == .OFF && App.editor.timeline.keys.count == before, "Intervening timeline changes cancel the timer without adding a wait.");
}

wait_for_release  :: (state: *App.Console_State, sends_input: bool) -> (bool, bool) { return false, true; }
cancel_submission :: (state: *App.Console_State, sends_input: bool) -> (bool, bool) { return false, false; }

check_focus_and_jump :: () {
    state: App.Console_State;
    defer App.console_deinit(*state);
    state.pending_jump      = true;
    state.pending_jump_step = 10;
    state.submission        = .{quick = true, game = cast(Win.HWND) -101, pid = 123};
    App.console_run_pending_jump(*state, wait_for_release);
    check(state.pending_jump && state.submission.pid == 123, "Jump remains queued across Enter release and quick-console focus handoff.");
    App.console_run_pending_jump(*state, cancel_submission);
    check(!state.pending_jump, "An unrelated focus change cancels queued jump without sending input.");
    App.overlay.game                    = Win.GetDesktopWindow();
    App.hud.settings.hide_on_focus_loss = true;
    App.hud.info.visible                = true;
    App.hud.toast.visible               = true;
    App.hud.next_frame                  = 10;
    App.hud_update_for_focus(1, cast(Win.HWND) -101);
    check(!App.hud.info.visible && App.hud.toast.visible, "Focus loss hides only information; an existing notification stays visible.");
    App.hud.settings.hide_on_focus_loss = false;
    App.hud.info.visible                = true;
    App.hud_update_for_focus(1, cast(Win.HWND) -101);
    check(App.hud.info.visible && App.hud.toast.visible, "Disabling focus hiding retains both panels.");
    App.overlay.visible = true;
    App.hud_update_for_focus(1, cast(Win.HWND) -101);
    check(!App.hud.info.visible && !App.hud.toast.visible, "Opening the console still hides both panels.");
    App.overlay = .{};
    App.hud     = .{};
}

#import "Basic";
#import "Compiler";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
