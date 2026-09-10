// GPT generates this file at 2026-09-11 06:13


// Each character is a separate key press in the foreground window.
// Spaces, tabs, and line breaks are separators; uppercase letters do not hold Shift.
send :: (commands: string, hold_ms: s32 = 50, interval_ms: s32 = 150) -> bool {
    if hold_ms <= 0 || interval_ms < 0 {
        print("send: hold_ms must be positive and interval_ms must be nonnegative.\n");
        return false;
    }

    // Validate everything before sending any input, so a typo cannot play half a sequence.
    key_count := 0;
    for c: commands {
        if is_separator(c) continue;
        if !scan_code_for_char(c) {
            print("send: unsupported command byte %. Use a-z, 0-9, or whitespace.\n", c);
            return false;
        }
        key_count += 1;
    }
    if key_count == 0 return true;

    target := Windows.GetForegroundWindow();
    if !target {
        print("send: no foreground window.\n");
        return false;
    }

    for c: commands {
        if is_separator(c) continue;

        if Windows.GetAsyncKeyState(Windows.VK_ESCAPE) < 0 {
            print("send: stopped by Esc.\n");
            return false;
        }
        if Windows.GetForegroundWindow() != target {
            print("send: stopped because the foreground window changed.\n");
            return false;
        }

        scan := scan_code_for_char(c);
        if !send_scan_code(scan) return false;

        // Always release this key before checking cancellation or sending the next key.
        sleep_milliseconds(hold_ms);
        if !send_scan_code(scan, key_up = true) {
            send_scan_code(scan, key_up = true); // Best effort if releasing the key failed.
            return false;
        }

        // The released interval lets games distinguish consecutive presses of the same key.
        if interval_ms > 0 sleep_milliseconds(interval_ms);
    }

    return true;
}

#scope_file

#import "Basic";
Windows :: #import "Windows";

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

send_scan_code :: (scan: u16, key_up := false) -> bool {
    input: Win_Input;
    input.type = INPUT_KEYBOARD;
    input.keyboard.scan = scan;
    input.keyboard.flags = KEYEVENTF_SCANCODE;
    if key_up input.keyboard.flags |= KEYEVENTF_KEYUP;

    sent := SendInput(1, *input, cast(s32) size_of(Win_Input));
    if sent != 1 {
        error := Windows.GetLastError();
        print("SendInput failed (Windows error %). Check the game's permissions and input support.\n", error);
        return false;
    }
    return true;
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
