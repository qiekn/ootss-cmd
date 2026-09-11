console_run_pending_send :: (console: *Console_State) {
    if !console.pending_send.count return;

    can_start := overlay.visible && !overlay.quit_requested && Win.GetForegroundWindow() == overlay.window;
    if can_start {
        // Keep focus here until the submitting key and modifiers have been released.
        for key: s32.[Win.VK_RETURN, Win.VK_SHIFT, Win.VK_CONTROL, Win.VK_MENU, Win.VK_LWIN, Win.VK_RWIN] {
            if Win.GetAsyncKeyState(key) < 0 return;
        }
    }

    commands := console.pending_send;
    hold_ms := console.pending_send_hold_ms;
    interval_ms := console.pending_send_interval_ms;
    console.pending_send = "";
    console.pending_send_hold_ms = DEFAULT_HOLD;
    console.pending_send_interval_ms = DEFUALT_INTERVAL;
    defer free(commands);
    if !can_start {
        console_write(console, "Send cancelled before starting.", .ERROR);
        return;
    }

    game := find_game_window();
    if !game {
        console_write(console, tprint("Game not found: %", GAME_EXECUTABLE), .ERROR);
        return;
    }
    if !overlay_focus_game_for_input(game, poll = console_poll_send) {
        cancelled := overlay.toggle_requested || overlay.show_requested || overlay.quit_requested || tray_has_request();
        message := ifx cancelled then "Send cancelled before starting." else "Could not focus the game. No keys were sent.";
        console_write(console, message, .ERROR);
        return;
    }

    // Give the game a short moment to process activation before its first key press.
    sleep_milliseconds(100);
    result := send_sequence(commands, hold_ms, interval_ms, target_window = game, poll = console_poll_send);
    if result.success {
        console_write(console, tprint("Sent % keys.", result.sent_keys));
    } else {
        key_count := validate_send(commands);
        console_write(console, tprint("% Sent %/% keys.", result.error, result.sent_keys, key_count), .ERROR);
    }
}

#scope_file

#import "Basic";
Win :: #import "Windows";
Input :: #import "Input";

console_poll_send :: () -> bool {
    // Called outside the main event iteration because this refreshes events_this_frame.
    if process_console_should_exit() overlay.quit_requested = true;
    Input.update_window_events();
    for event: Input.events_this_frame {
        if event.type == .QUIT overlay.quit_requested = true;
    }
    overlay_update_hotkey();
    return !overlay.toggle_requested && !overlay.show_requested && !overlay.quit_requested && !tray_has_request();
}
