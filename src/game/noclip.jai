Noclip_State :: struct {
    enabled: bool;
    game: Win.HWND;
    pid: u32;
    locator: Game_Manager_Locator;
    down, consumed, repeat: [4] bool;
    last_direction: s64;
    queue: [64] u8;
    queue_start, queue_count: s64;
    next_step_at: float64;
    overflow: bool;
}

noclip: Noclip_State;

noclip_direction_index :: (vk: u32) -> s64 {
    if vk == #char "W" return 0;
    if vk == #char "S" return 1;
    if vk == #char "A" return 2;
    if vk == #char "D" return 3;
    return -1;
}

noclip_clear_motion :: () {
    noclip.queue_start = 0;
    noclip.queue_count = 0;
    noclip.next_step_at = 0;
    noclip.overflow = false;
    for *held: noclip.repeat held.* = false;
    // Keep consumed/down until release, so a key held across focus loss cannot restart movement.
}

noclip_filter_key :: (vk: u32, down: bool, injected: bool, foreground: Win.HWND, modifiers := false) -> bool {
    if injected || !noclip.enabled return false;
    index := noclip_direction_index(vk);
    if index < 0 return false;
    was_down := noclip.down[index];
    noclip.down[index] = down;
    if !down {
        consumed := noclip.consumed[index];
        noclip.consumed[index] = false;
        noclip.repeat[index] = false;
        return consumed;
    }
    if was_down return noclip.consumed[index]; // Ignore Windows autorepeat; the update loop paces holds.
    if !noclip.game || foreground != noclip.game || modifiers || editor_save_prompt.active return false;
    noclip.consumed[index] = true;
    noclip.repeat[index] = true;
    noclip.last_direction = index;
    if noclip.queue_count < noclip.queue.count {
        offset := (noclip.queue_start + noclip.queue_count) % noclip.queue.count;
        noclip.queue[offset] = "UDLR"[index];
        noclip.queue_count += 1;
    } else noclip.overflow = true;
    // Hook ordering can vary when the editor opens. Physical movement still interrupts standalone playback.
    send_input_filter_keyboard(0x100, 0, foreground);
    return true;
}

noclip_next_direction :: (now: float64) -> u8 {
    direction: u8;
    if noclip.queue_count {
        direction = noclip.queue[noclip.queue_start];
        noclip.queue_start = (noclip.queue_start + 1) % noclip.queue.count;
        noclip.queue_count -= 1;
    } else {
        if now < noclip.next_step_at return 0;
        index := noclip.last_direction;
        if !noclip.repeat[index] {
            index = -1;
            for held: noclip.repeat if held { index = it_index; break; }
        }
        if index < 0 return 0;
        direction = "UDLR"[index];
    }
    noclip.next_step_at = now + cast(float64) DEFAULT_DELAY / 1000;
    return direction;
}

command_noclip :: (state: *Console_State, arguments: string) {
    requested: s32 = -1;
    if equal_nocase(arguments, "enable") requested = 1;
    else if equal_nocase(arguments, "disable") requested = 0;
    else if arguments.count { console_write(state, "Usage: noclip [enable|disable]", .ERROR); return; }
    if !console_position_command_ready(state) return;
    state.pending_noclip = requested;
    state.pending_action = .NOCLIP;
}

console_set_noclip :: (state: *Console_State) {
    enabled := ifx state.pending_noclip < 0 then !noclip.enabled else state.pending_noclip != 0;
    if enabled != noclip.enabled {
        if enabled {
            error := noclip_install_hook();
            if error.count { console_write(state, error, .ERROR); return; }
            noclip = .{};
            noclip.enabled = true;
            noclip.game = find_game_window();
            noclip.pid = process_window_pid(noclip.game);
            for vk: "WSAD" noclip.down[it_index] = Win.GetAsyncKeyState(cast(s32) vk) < 0;
        } else noclip_deinit();
    }
    console_write(state, ifx noclip.enabled then "Noclip enabled. W/S: Y +/-1; A/D: X +/-1; one step per input."
                                          else "Noclip disabled.");
}

noclip_update :: (state: *Console_State, now: float64) {
    if !noclip.enabled return;
    game := overlay.game;
    pid := process_window_pid(game);
    if game != noclip.game || pid != noclip.pid {
        noclip_clear_motion();
        noclip.game = game;
        noclip.pid = pid;
        noclip.locator = .{};
    }
    if !game || !pid || Win.GetForegroundWindow() != game || overlay.quit_requested || editor_save_prompt.active ||
       state.pending_position_change || state.pending_send.count || process_console_should_exit() {
        noclip_clear_motion();
        return;
    }
    if noclip.overflow {
        noclip_clear_motion();
        console_write(state, "Noclip input queue filled; release movement keys and try again.", .ERROR);
        return;
    }
    direction := noclip_next_direction(now);
    if !direction return;
    // Teleport one grid cell without injecting a native movement or blocking on a key cycle.
    if !console_change_game_position(state, game_direction_delta(direction), true, from_game = true,
                                     report_success = false) {
        noclip_clear_motion();
    }
}

noclip_deinit :: () {
    noclip_remove_hook();
    noclip = .{};
}

#scope_file
#import "Basic";
#import "String";
Win :: #import "Windows";
