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
    error: string;
}

SEND_KEY_LIMIT :: 65536;

// Returns owned, fully expanded key presses. Parse before removing whitespace:
// w3 means www, while w 3 means the W key followed by the digit 3.
// (ad)3 repeats the whole group; groups may nest and contain letter repeats.
expand_send :: (commands: string, alternate := false) -> (expanded: string, error: string) {
    keys: [..] u8;
    defer array_free(keys);
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
            for i: 0..extra-1 array_add(*keys, keys[first + i % length]);
            continue;
        }
        if c >= #char "A" && c <= #char "Z" c += #char "a" - #char "A";
        letter := c >= #char "a" && c <= #char "z";
        wait := c == #char "_";
        if !letter && !wait && (c < #char "0" || c > #char "9") {
            return "", "Use letters, repeat groups, _ waits, digit keys, or whitespace (example: w3 (ad)3 _2 2).";
        }

        count: s64 = 1;
        if letter || wait {
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
        for 0..count-1 array_add(*keys, key);
    }
    if groups.count return "", "Unmatched '(' in the send sequence.";
    return copy_string(.{data = keys.data, count = keys.count}), "";
}

expand_udlr :: (commands: string) -> (expanded: string, error: string) {
    expanded, error := expand_send(commands, alternate = true);
    return expanded, error;
}

validate_send :: (commands: string) -> (key_count: s64, error: string) {
    key_count: s64;
    for c: commands {
        if is_separator(c) continue;
        if c != #char "_" && !scan_code_for_char(c) {
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

// Receives literal key presses, already expanded by the caller. Do not parse these again:
// a digit next to a letter here may have come from a whitespace-separated character selection.
// A specified target must stay in the foreground. poll lets the caller process cancellation events.
send_sequence :: (commands: string, hold_ms: s32 = DEFAULT_HOLD, interval_ms: s32 = DEFUALT_INTERVAL,
                  target_window: Windows.HWND = null, poll: () -> bool = null,
                  modifier_scan: u16 = 0, modifier_extended := false) -> Send_Result {
    result: Send_Result;
    if hold_ms <= 0 || interval_ms < 0 {
        result.error = "hold_ms must be positive and interval_ms must be nonnegative.";
        return result;
    }

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

    result = send_sequence_keys(commands, hold_ms, interval_ms, target, poll);
    if modifier_scan {
        released, error := send_scan_code(modifier_scan, key_up = true, extended = modifier_extended);
        if !released {
            send_scan_code(modifier_scan, key_up = true, extended = modifier_extended);
            result.success = false;
            result.error = error;
        }
    }
    return result;
}

#scope_file

#import "Basic";
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
                       target: Windows.HWND, poll: () -> bool) -> Send_Result {
    result: Send_Result;

    for c: commands {
        if is_separator(c) continue;
        result.error = send_abort_reason(target, poll);
        if result.error.count return result;

        if c == #char "_" {
            result.error = send_wait(hold_ms, target, poll);
            if !result.error.count result.error = send_wait(interval_ms, target, poll);
            if result.error.count return result;
            continue;
        }

        scan := scan_code_for_char(c);
        pressed, press_error := send_scan_code(scan);
        if !pressed {
            result.error = press_error;
            return result;
        }
        result.sent_keys += 1;

        // Cancellation during a hold must still release the key before returning.
        hold_error := send_wait(hold_ms, target, poll);
        released, release_error := send_scan_code(scan, key_up = true);
        if !released {
            send_scan_code(scan, key_up = true); // Best effort if releasing the key failed.
            result.error = release_error;
            return result;
        }
        result.error = hold_error;
        if result.error.count return result;

        // The released interval lets games distinguish consecutive presses of the same key.
        result.error = send_wait(interval_ms, target, poll);
        if result.error.count return result;
    }

    result.success = true;
    return result;
}

send_with_mode :: (commands: string, alternate: bool, hold_ms: s32, interval_ms: s32) -> bool {
    expanded, error := expand_send(commands, alternate);
    defer free(expanded);
    if error.count {
        print("%\n", error);
        return false;
    }
    result := send_sequence(expanded, hold_ms, interval_ms);
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
    input.type = INPUT_KEYBOARD;
    input.keyboard.scan = scan;
    input.keyboard.flags = KEYEVENTF_SCANCODE;
    if extended input.keyboard.flags |= 0x0001;
    if key_up input.keyboard.flags |= KEYEVENTF_KEYUP;

    sent := SendInput(1, *input, cast(s32) size_of(Win_Input));
    if sent != 1 {
        return false, tprint("SendInput failed (Windows error %). Check the game's permissions.", Windows.GetLastError());
    }
    return true, "";
}

// -----------------------------------------------------------------------------: Win32 ABI

INPUT_KEYBOARD     :: 1;
KEYEVENTF_KEYUP    :: 0x0002;
KEYEVENTF_SCANCODE :: 0x0008;

Win_Mouse_Input :: struct {
    dx: s32;
    dy: s32;
    mouse_data: u32;
    flags: u32;
    time: u32;
    extra_info: u64;
}

Win_Keyboard_Input :: struct {
    vk: u16;
    scan: u16;
    flags: u32;
    time: u32;
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
        mouse: Win_Mouse_Input;
        keyboard: Win_Keyboard_Input;
        hardware: Win_Hardware_Input;
    }
}

// SendInput requires the full INPUT union, including the larger mouse member.
#assert(OS == .WINDOWS);
#assert(size_of(*void) == 8);
#assert(size_of(Win_Keyboard_Input) == 24);
#assert(size_of(Win_Input) == 40);

user32 :: #library,system "user32";
SendInput :: (count: u32, inputs: *Win_Input, input_size: s32) -> u32 #foreign user32;
