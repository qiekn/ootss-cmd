// GPT generates this file at 2026-09-11 06:13

DEFAULT_\         DELAY :: 250; // milliseconds
SEND_FAST_\       DELAY :: 175;
SEND_SLOW_\       DELAY :: 500;
SEND_SUPERFAST_\  DELAY :: 75;
SEND_SUPERSLOW_\  DELAY :: 750;
DEFAULT_HOLD     :: 50;
DEFUALT_INTERVAL :: DEFAULT_DELAY - DEFAULT_HOLD;

send_hold_for_delay :: (delay_ms: s32) -> s32 {
    // Keep the preferred 50 ms hold, shortening it for cycles too small to leave a release gap.
    return cast(s32) min(DEFAULT_HOLD, max(1, delay_ms / 2));
}

// Return nominal milliseconds; sub-millisecond cycles may have no released gap.
send_scaled_hold :: (cycle_ms: float64, rate: float64) -> float64 {
    hold := min(cast(float64) DEFAULT_HOLD, max(cast(float64) 1, floor(cycle_ms / rate / 2)));
    return min(cycle_ms, hold * rate);
}

// Suffixes repeat letters or parenthesized groups; whitespace separates literal digit keys.
// Uppercase letters do not hold Shift.
send :: (commands: string, hold_ms: s32 = DEFAULT_HOLD, interval_ms: s32 = DEFUALT_INTERVAL) -> bool {
    return send_with_mode(commands, false, hold_ms, interval_ms);
}

send_alt :: (commands: string, hold_ms: s32 = DEFAULT_HOLD, interval_ms: s32 = DEFUALT_INTERVAL) -> bool {
    return send_with_mode(commands, true, hold_ms, interval_ms);
}

Send_Result :: struct {
    success := false;
    sent_keys: s64;
    error:     string;
}

Send_Timing :: struct {
    reader:         Playback_Speed_Reader;
    clock:          Playback_Clock;
    automatic_hold: bool;
}

send_wait_duration :: (milliseconds: s32, cycle_ms: float64) -> float64 {
    return cast(float64) milliseconds * cycle_ms / DEFAULT_DELAY;
}

send_timed_wait :: (milliseconds: float64, target: Windows.HWND, poll: () -> bool,
                    timing: *Send_Timing) -> string {
    rate, error := playback_speed_read(*timing.reader, target);
    if error.count return error;
    now      := playback_clock_update(*timing.clock, seconds_since_init(), rate);
    deadline := now + milliseconds / 1000;
    while true {
        error = send_abort_reason(target, poll);
        if error.count return error;
        rate, error = playback_speed_read(*timing.reader, target);
        if error.count return error;
        now = playback_clock_update(*timing.clock, seconds_since_init(), rate);
        if now >= deadline return "";
        // Clamp before narrowing: tiny positive game rates can imply very long waits.
        remaining := (deadline - now) * 1000 / rate;
        sleep_milliseconds(cast(s32) max(cast(float64) 1, min(cast(float64) 10, remaining)));
    }
    return "";
}

send_cycle_wait :: (milliseconds: float64, target: Windows.HWND, poll: () -> bool,
                    wait:   (milliseconds: s32, target: Windows.HWND, poll: () -> bool) -> string,
                    timing: *Send_Timing) -> string {
    if timing return send_timed_wait(milliseconds, target, poll, timing);
    return wait(cast(s32) milliseconds, target, poll);
}

SEND_KEY_LIMIT :: 65536;

// Returns owned, fully expanded key presses. Parse before removing whitespace:
// w3 means www, while w 3 means the W key followed by the digit 3.
// (ad)3 repeats the whole group; groups may nest and contain letter repeats.
expand_send :: (commands: string, alternate := false, waits: *[..] s32 = null) -> (expanded: string, error: string) {
    keys: [..] u8;
    defer array_free(keys);
    durations: [..] s32;
    defer array_free(durations);
    groups: [..] s64;
    defer array_free(groups);
    position: s64;
    while position < commands.count {
        c := commands[position];
        position += 1;
        if is_separator(c) continue;
        if c == #char "(" {
            array_add(*groups, keys.count);
            continue;
        }
        if c == #char ")" {
            if !groups.count return "", "Unmatched ')' in the send sequence.";
            first := groups[groups.count - 1];
            groups.count -= 1;
            length := keys.count - first;
            if !length return "", "Repeat groups cannot be empty (example: (ad)3).";
            count, error := send_repeat_count(commands, *position);
            if error.count return "", error;
            if count - 1 > (SEND_KEY_LIMIT - keys.count) / length {
                return "", tprint("Expanded sequence exceeds % keys.", SEND_KEY_LIMIT);
            }
            extra := length * (count - 1);
            // Refer to the original group by index: appending can reallocate keys.data.
            for i: 0..extra-1 {
                array_add(*keys, keys[first + i % length]);
                array_add(*durations, durations[first + i % length]);
            }
            continue;
        }
        if c >= #char "A" && c <= #char "Z" c += #char "a" - #char "A";
        letter   := c >= #char "a" && c <= #char "z";
        restart  := c == #char "!";
        wait     := c == #char "_";
        duration := cast(s32)(ifx wait then DEFAULT_DELAY else 0);
        if wait {
            error: string;
            duration, error = send_wait_token(commands, *position);
            if error.count return "", error;
        }
        if !letter && !wait && !restart && (c < #char "0" || c > #char "9") {
            return "", "Use letters, repeat groups, _ waits, digit keys, or whitespace (example: w3 (ad)3 _2 2).";
        }

        count: s64 = 1;
        if letter || wait || restart {
            error: string;
            count, error = send_repeat_count(commands, *position);
            if error.count return "", error;
        }
        if count > SEND_KEY_LIMIT - keys.count {
            return "", tprint("Expanded sequence exceeds % keys.", SEND_KEY_LIMIT);
        }

        key := c;
        if alternate {
            if c == #char "u" key = #char "w";
            if c == #char "d" key = #char "s";
            if c == #char "l" key = #char "a";
            if c == #char "r" key = #char "d";
        }
        for 0..count-1 {
            array_add(*keys, key);
            array_add(*durations, duration);
        }
    }
    if groups.count return "", "Unmatched '(' in the send sequence.";
    if waits {
        array_free(waits.*);
        waits.* = durations;
        empty: [..] s32;
        durations = empty;
    }
    return copy_string(.{data = keys.data, count = keys.count}), "";
}

// Position starts immediately after the opening underscore. A closing underscore
// makes a timed wait; a bare integer suffix retains legacy _3 repetition.
send_wait_token :: (commands: string, position: *s64) -> (milliseconds: s32, error: string) {
    first := position.*;
    if first == commands.count return DEFAULT_DELAY, "";
    if commands[first] == #char "<" return 0, "A timed wait must use _seconds_ (example: _3.5_).";
    if !contains("0123456789.+-", commands[first]) return DEFAULT_DELAY, "";
    closing := first;
    integer := true;
    while closing < commands.count && contains("0123456789.eE+-", commands[closing]) {
        if commands[closing] < #char "0" || commands[closing] > #char "9" integer = false;
        closing += 1;
    }
    if closing > first && closing < commands.count && commands[closing] == #char "_" {
        milliseconds, error := send_parse_wait_seconds(slice(commands, first, closing - first));
        if error.count return 0, error;
        position.* = closing + 1;
        return milliseconds, "";
    }
    if !integer {
        return 0, "A timed wait must use _seconds_ (example: _3.5_).";
    }
    return DEFAULT_DELAY, "";
}

send_parse_wait_seconds :: (source: string) -> (milliseconds: s32, error: string) {
    seconds, success, remaining := string_to_float64(source);
    if !source.count || !success || remaining.count || !is_finite(seconds) || seconds < 0.001 || seconds > 2147483.647 {
        return 0, "Wait time must be between 0.001 and 2147483.647 seconds.";
    }
    return cast(s32) floor(seconds * 1000 + 0.5), "";
}

send_wait_seconds_text :: (milliseconds: s32) -> string {
    return tprint("%", formatFloat(cast(float64) milliseconds / 1000, mode = .SHORTEST));
}

expand_udlr :: (commands: string) -> (expanded: string, error: string) {
    expanded, error := expand_send(commands, alternate = true);
    return expanded, error;
}

validate_send :: (commands: string) -> (key_count: s64, error: string) {
    key_count: s64;
    for c: commands {
        if is_separator(c) continue;
        if c != #char "_" && c != #char "!" && !scan_code_for_char(c) {
            return 0, tprint("Unsupported command byte %. Use a-z, 0-9, _ waits, or whitespace.", c);
        }
        key_count += 1;
    }
    return key_count, "";
}

// Single nonblocking event for the editor's frame-driven transport.
send_key_event :: (scan: u16, key_up := false, extended := false) -> (success: bool, error: string) {
    success, error := send_scan_code(scan, key_up, extended);
    return success, error;
}

// Allow activation/settling waits to share playback's focus and cancellation checks.
send_wait_for_input :: (milliseconds: s32, target: Windows.HWND, poll: () -> bool = null) -> string {
    return send_wait(milliseconds, target, poll);
}

// A complete press/release cycle also supports rebound and extended game keys.
send_key_cycle :: (scan: u16, extended := false, hold_ms: s32 = DEFAULT_HOLD, interval_ms: s32 = DEFUALT_INTERVAL,
                   target_window: Windows.HWND = null, poll: () -> bool = null,
                   emit:          (scan: u16, key_up: bool, extended: bool) -> (bool, string) = send_key_event,
                   wait:          (milliseconds: s32, target: Windows.HWND, poll: () -> bool) -> string = null,
                   after_release: (data: *void) -> string = null, release_data: *void = null,
                   timing:        *Send_Timing = null) -> Send_Result {
    result: Send_Result;
    if !wait wait = send_wait;
    if !scan || hold_ms <= 0 || interval_ms < 0 {
        result.error = "A valid scan code, positive hold and nonnegative interval are required.";
        return result;
    }
    target := ifx target_window then target_window else Windows.GetForegroundWindow();
    if !target { result.error = "No foreground window."; return result; }
    result.error = send_cycle_wait(0, target, poll, wait, timing);
    if result.error.count return result;
    hold_duration     := cast(float64) hold_ms;
    interval_duration := cast(float64) interval_ms;
    if timing && timing.automatic_hold {
        cycle := cast(float64) hold_ms + interval_ms;
        hold_duration     = send_scaled_hold(cycle, timing.clock.rate);
        interval_duration = cycle - hold_duration;
    }
    pressed, press_error := emit(scan, false, extended);
    if !pressed { result.error = press_error; return result; }
    result.sent_keys = 1;
    hold_error              := send_cycle_wait(hold_duration, target, poll, wait, timing);
    released, release_error := emit(scan, true, extended);
    if !released {
        emit(scan, true, extended); // Retry the release even if focus was lost during the hold.
        result.error = release_error;
        return result;
    }
    result.error = hold_error;
    if result.error.count return result;
    if after_release {
        result.error = send_cycle_wait(0, target, poll, wait, timing);
        if result.error.count return result;
        result.error = after_release(release_data);
        if result.error.count return result;
    }
    result.error   = send_cycle_wait(interval_duration, target, poll, wait, timing);
    result.success = !result.error.count;
    return result;
}

// Receives literal key presses, already expanded by the caller. Do not parse these again:
// a digit next to a letter here may have come from a whitespace-separated character selection.
// A specified target must stay in the foreground. poll lets the caller process cancellation events.
send_sequence :: (commands: string, hold_ms: s32 = DEFAULT_HOLD, interval_ms: s32 = DEFUALT_INTERVAL,
                  target_window: Windows.HWND = null, poll: () -> bool = null,
                  modifier_scan: u16 = 0, modifier_extended := false, waits: [] s32 = .[], adapt_speed := false,
                  automatic_hold := false) -> Send_Result {
    result: Send_Result;
    if hold_ms <= 0 || interval_ms < 0 {
        result.error = "hold_ms must be positive and interval_ms must be nonnegative.";
        return result;
    }
    if waits.count && waits.count != commands.count { result.error = "Wait durations do not match the sequence."; return result; }
    for duration: waits if duration < 0 { result.error = "Invalid wait duration."; return result; }

    // Validate everything before sending any input, so a typo cannot play half a sequence.
    key_count, error := validate_send(commands);
    if error.count {
        result.error = error;
        return result;
    }
    if key_count == 0 {
        result.success = true;
        return result;
    }

    target := ifx target_window then target_window else Windows.GetForegroundWindow();
    if !target {
        result.error = "No foreground window.";
        return result;
    }

    timing: Send_Timing = .{automatic_hold = automatic_hold};
    defer playback_speed_close(*timing.reader);
    timing_pointer: *Send_Timing;
    if adapt_speed {
        rate, error := playback_speed_read(*timing.reader, target);
        if error.count { result.error = error; return result; }
        playback_clock_update(*timing.clock, seconds_since_init(), rate);
        timing_pointer = *timing;
    }
    if modifier_scan {
        for c: commands {
            if scan_code_for_char(c) == modifier_scan && !modifier_extended {
                result.error = "The time modifier is also a sequence key. Choose another speed or change its game binding.";
                return result;
            }
        }
        result.error = send_abort_reason(target, poll);
        if result.error.count return result;
        pressed, error := send_scan_code(modifier_scan, extended = modifier_extended);
        if !pressed { result.error = error; return result; }
    }

    result = send_sequence_keys(commands, hold_ms, interval_ms, target, poll, waits, timing_pointer);
    if modifier_scan {
        released, error := send_scan_code(modifier_scan, key_up = true, extended = modifier_extended);
        if !released {
            send_scan_code(modifier_scan, key_up = true, extended = modifier_extended);
            result.success = false;
            result.error   = error;
        }
    }
    return result;
}

#scope_file

Windows :: #import "Windows";

send_repeat_count :: (commands: string, position: *s64) -> (count: s64, error: string) {
    if position.* >= commands.count || commands[position.*] < #char "0" || commands[position.*] > #char "9" {
        return 1, "";
    }
    count: s64;
    while position.* < commands.count && commands[position.*] >= #char "0" && commands[position.*] <= #char "9" {
        digit := cast(s64)(commands[position.*] - #char "0");
        if count > (SEND_KEY_LIMIT - digit) / 10 {
            return 0, tprint("Expanded sequence exceeds % keys.", SEND_KEY_LIMIT);
        }
        count = count * 10 + digit;
        position.* += 1;
    }
    if count == 0 return 0, "Repeat counts must be positive (examples: w3, (ad)3).";
    return count, "";
}

send_sequence_keys :: (commands: string, hold_ms: s32, interval_ms: s32,
                       target: Windows.HWND, poll: () -> bool, waits: [] s32, timing: *Send_Timing) -> Send_Result {
    result: Send_Result;

    restart: Game_Key;
    if contains(commands, #char "!") {
        map:   Game_Keymap;
        ready: bool;
        result.error, ready = game_keymap_load(*map, only_action = "Restart");
        if !ready return result;
        if !map.restart.scan { result.error = "No keyboard binding for restart."; return result; }
        result.error = "";
        restart      = map.restart;
    }
    for c: commands {
        if is_separator(c) continue;
        result.error = send_abort_reason(target, poll);
        if result.error.count return result;

        if c == #char "_" {
            duration := ifx waits.count && waits[it_index] > 0 then waits[it_index] else DEFAULT_DELAY;
            if timing {
                scaled := send_wait_duration(duration, cast(float64) hold_ms + interval_ms);
                result.error = send_timed_wait(scaled, target, poll, timing);
            } else result.error = send_wait(duration, target, poll);
            if result.error.count return result;
            continue;
        }

        key   := ifx c == #char "!" then restart else Game_Key.{scan = scan_code_for_char(c)};
        cycle := send_key_cycle(key.scan, extended = key.extended, hold_ms = hold_ms, interval_ms = interval_ms,
                                target_window = target, poll = poll, timing = timing);
        result.sent_keys += cycle.sent_keys;
        if !cycle.success { result.error = cycle.error; return result; }
    }

    result.success = true;
    return result;
}

send_with_mode :: (commands: string, alternate: bool, hold_ms: s32, interval_ms: s32) -> bool {
    waits: [..] s32;
    defer array_free(waits);
    expanded, error := expand_send(commands, alternate, *waits);
    defer free(expanded);
    if error.count {
        print("%\n", error);
        return false;
    }
    result := send_sequence(expanded, hold_ms, interval_ms, waits = waits, adapt_speed = true);
    if !result.success print("%\n", result.error);
    return result.success;
}

send_abort_reason :: (target: Windows.HWND, poll: () -> bool) -> string {
    if poll && !poll() return "Send cancelled.";
    if Windows.GetAsyncKeyState(Windows.VK_ESCAPE) < 0 return "Stopped by Esc.";
    if Windows.GetForegroundWindow() != target return "Target window lost focus.";
    return "";
}

send_wait :: (milliseconds: s32, target: Windows.HWND, poll: () -> bool) -> string {
    deadline := seconds_since_init() + cast(float64) milliseconds / 1000;
    while true {
        error := send_abort_reason(target, poll);
        if error.count return error;
        remaining := deadline - seconds_since_init();
        if remaining <= 0 break;
        wait_ms := cast(s32)(remaining * 1000);
        sleep_milliseconds(cast(s32) max(1, min(wait_ms, 10)));
    }
    return "";
}

is_separator :: (c: u8) -> bool {
    return c == #char " " || c == #char "\t" || c == #char "\r" || c == #char "\n";
}

scan_code_for_char :: (c: u8) -> u16 {
    if c >= #char "A" && c <= #char "Z" {
        c += #char "a" - #char "A";
    }

    // PC keyboard Set 1 scan codes, in alphabetical order (a-z).
    letter_scans :: u16.[
        0x1e, 0x30, 0x2e, 0x20, 0x12, 0x21, 0x22, 0x23, 0x17,
        0x24, 0x25, 0x26, 0x32, 0x31, 0x18, 0x19, 0x10, 0x13,
        0x1f, 0x14, 0x16, 0x2f, 0x11, 0x2d, 0x15, 0x2c
    ];
    if c >= #char "a" && c <= #char "z" {
        return letter_scans[c - #char "a"];
    }

    // Number row, not the numeric keypad: 1-9 are 0x02-0x0a; 0 is 0x0b.
    if c >= #char "1" && c <= #char "9" return cast(u16)(c - #char "1" + 0x02);
    if c == #char "0" return 0x0b;
    return 0;
}

send_scan_code :: (scan: u16, key_up := false, extended := false) -> (success: bool, error: string) {
    input: Win_Input;
    input.type           = INPUT_KEYBOARD;
    input.keyboard.scan  = scan;
    input.keyboard.flags = KEYEVENTF_SCANCODE;
    if extended input.keyboard.flags |= 0x0001;
    if key_up input.keyboard.flags |= KEYEVENTF_KEYUP;

    sent := SendInput(1, *input, cast(s32) size_of(Win_Input));
    if sent != 1 {
        return false, tprint("SendInput failed (Windows error %). Check the game's permissions.", Windows.GetLastError());
    }
    return true, "";
}

// ----------------------------------------------------------------------------: Win32 ABI

INPUT_KEYBOARD     :: 1;
KEYEVENTF_KEYUP    :: 0x0002;
KEYEVENTF_SCANCODE :: 0x0008;

Win_Mouse_Input :: struct {
    dx:         s32;
    dy:         s32;
    mouse_data: u32;
    flags:      u32;
    time:       u32;
    extra_info: u64;
}

Win_Keyboard_Input :: struct {
    vk:         u16;
    scan:       u16;
    flags:      u32;
    time:       u32;
    extra_info: u64;
}

Win_Hardware_Input :: struct {
    message: u32;
    param_l: u16;
    param_h: u16;
}

Win_Input :: struct {
    type: u32;
    union {
        mouse:    Win_Mouse_Input;
        keyboard: Win_Keyboard_Input;
        hardware: Win_Hardware_Input;
    }
}

// SendInput requires the full INPUT union, including the larger mouse member.
#assert(OS == .WINDOWS);
#assert(size_of(*void) == 8);
#assert(size_of(Win_Keyboard_Input) == 24);
#assert(size_of(Win_Input) == 40);

user32    :: #library,system "user32";
SendInput :: (count: u32, inputs: *Win_Input, input_size: s32) -> u32 #foreign user32;
