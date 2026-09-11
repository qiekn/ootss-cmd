Console_Line_Kind :: enum { INFO; COMMAND; OUTPUT; ERROR; }
Console_Action :: enum { NONE; HIDE; EXIT; }
CONSOLE_INPUT_LIMIT :: 1024;
UNDO_DEFAULT_DELAY :: 10;
UNDO_FAST_DELAY :: 1;

Console_Line :: struct {
    text: string;
    kind: Console_Line_Kind;
}

Console_State :: struct {
    lines: [..] Console_Line;
    input: [..] u8;
    cursor: s64;
    history: [..] string;
    history_cursor: s64;
    draft: string;
    scroll: s64;
    pending_send: string;
    pending_send_hold_ms: s32 = DEFAULT_HOLD;
    pending_send_interval_ms: s32 = DEFUALT_INTERVAL;
    pending_action: Console_Action;
}

Console_Command :: struct {
    name: string;
    run: (console: *Console_State, arguments: string);
}

// @TODO maybe do some metaprogramming here
CONSOLE_COMMANDS :: Console_Command.[
    .{"ls",           command_ls},
    .{"echo",         command_echo},
    .{"print",        command_print},
    .{"help",         command_help},
    .{"clear",        command_clear},
    .{"cl",           command_clear},
    .{"send",         command_send},
    .{"send_alt",     command_send_alt},
    .{"undo",         command_undo},
    .{"z",            command_undo},
    .{"q",            command_hide},
    .{"quit",         command_hide},
    .{"exit",         command_exit},
    .{"terminate",    command_exit},
    .{"xyzzy",        command_xyzzy},
    .{"hello sailor", command_hello_sailor}
];

command_send :: (console: *Console_State, arguments: string) {
    console_queue_send(console, arguments, alternate = false);
}

command_send_alt :: (console: *Console_State, arguments: string) {
    console_queue_send(console, arguments, alternate = true);
}

command_undo :: (console: *Console_State, arguments: string) {
    count := "1";
    has_count := false;
    fast := false;
    delay_ms: s32 = -1;
    position: s64;
    while position < arguments.count {
        argument := console_next_argument(arguments, *position);
        if !argument.count break;
        if equal_nocase(argument, "-fast") {
            fast = true;
            continue;
        }
        if equal_nocase(argument, "-delay") {
            if delay_ms >= 0 {
                console_write(console, "Specify -delay only once.", .ERROR);
                return;
            }
            value := console_next_argument(arguments, *position);
            error: string;
            delay_ms, error = console_parse_delay(value);
            if error.count {
                console_write(console, error, .ERROR);
                return;
            }
            continue;
        }
        if has_count {
            console_write(console, "Specify only one undo count (example: undo 100 or z100).", .ERROR);
            return;
        }
        for c: argument {
            if c < #char "0" || c > #char "9" {
                console_write(console, "Usage: undo [count] [-fast] [-delay <ms>] (alias: z[count] or z [count]).", .ERROR);
                return;
            }
        }
        count = argument;
        has_count = true;
    }

    if delay_ms < 0 delay_ms = cast(s32) ifx fast then UNDO_FAST_DELAY else UNDO_DEFAULT_DELAY;
    console_queue_send(console, tprint("z%", count), alternate = false, default_delay_ms = delay_ms);
}

console_queue_send :: (console: *Console_State, commands: string, alternate: bool,
                       default_delay_ms: s32 = DEFAULT_DELAY) {
    source: [..] u8;
    defer array_free(source);
    position: s64;
    delay_ms: s32 = -1;
    while position < commands.count {
        argument := console_next_argument(commands, *position);
        if !argument.count break;
        if equal_nocase(argument, "--udlr") {
            alternate = true;
            continue;
        }
        if equal_nocase(argument, "-delay") {
            if delay_ms >= 0 {
                console_write(console, "Specify -delay only once.", .ERROR);
                return;
            }
            value := console_next_argument(commands, *position);
            error: string;
            delay_ms, error = console_parse_delay(value);
            if error.count {
                console_write(console, error, .ERROR);
                return;
            }
            continue;
        }

        // Removing options must not join a literal digit token to a preceding letter.
        if source.count array_add(*source, #char " ");
        for c: argument array_add(*source, c);
    }

    expanded, error := expand_send(.{data = source.data, count = source.count}, alternate);
    defer free(expanded);
    if error.count {
        console_write(console, error, .ERROR);
        return;
    }
    if !expanded.count {
        usage := ifx alternate then "Usage: send_alt [-delay <ms>] <moves> (example: -delay 10 R3 2 U)"
                               else "Usage: send [-delay <ms>] <keys> (example: -delay 10 w3 2 d)";
        console_write(console, usage, .ERROR);
        return;
    }
    if console.pending_send.count {
        console_write(console, "A send command is already waiting to run.", .ERROR);
        return;
    }

    // The input buffer is cleared after dispatch. The main loop owns this queued copy.
    console.pending_send = copy_string(expanded);
    if delay_ms < 0 delay_ms = default_delay_ms;
    console.pending_send_hold_ms = cast(s32) max(1, delay_ms / 2);
    console.pending_send_interval_ms = delay_ms - console.pending_send_hold_ms;
}

command_ls :: (console: *Console_State, arguments: string) {
    console_write(console, "ls command is here.");
}

command_echo :: (console: *Console_State, arguments: string) {
    console_write(console, "echo command is here.");
}

command_print :: (console: *Console_State, arguments: string) {
    console_write(console, "print command is here.");
}

command_help :: (console: *Console_State, arguments: string) {
    console_write(console, "help command is here.");
}

command_clear :: (console: *Console_State, arguments: string) {
    for line: console.lines free(line.text);
    console.lines.count = 0;
    console.scroll = 0;
}

command_hide :: (console: *Console_State, arguments: string) {
    console.pending_action = .HIDE;
}

command_exit :: (console: *Console_State, arguments: string) {
    console.pending_action = .EXIT;
}

command_xyzzy :: (console: *Console_State, arguments: string) {
    console_write(console, "Nothing happens here.");
}

command_hello_sailor :: (console: *Console_State, arguments: string) {
    console_write(console, "Nothing happens here.");
}

console_write :: (console: *Console_State, text: string, kind: Console_Line_Kind = .OUTPUT) {
    if console.lines.count == 256 {
        free(console.lines[0].text);
        array_ordered_remove_by_index(*console.lines, 0);
    }
    array_add(*console.lines, .{copy_string(text), kind});
    console.scroll = 0;
}

console_input :: (console: *Console_State) -> string {
    return .{data = console.input.data, count = console.input.count};
}

console_submit :: (console: *Console_State) {
    line := trim(console_input(console));
    if !line.count {
        console_set_input(console, "");
        return;
    }

    console_write(console, tprint("$ %", line), .COMMAND);
    if console.history.count == 64 {
        free(console.history[0]);
        array_ordered_remove_by_index(*console.history, 0);
    }
    array_add(*console.history, copy_string(line));

    found := false;
    for command: CONSOLE_COMMANDS {
        // Match complete names without case sensitivity, including "hello sailor".
        // Only z allows a count attached to its name, as in z100.
        length := command.name.count;
        if line.count < length || !equal_nocase(slice(line, 0, length), command.name) continue;
        if line.count > length && !console_word_separator(line[length]) {
            if command.name != "z" || line[length] < #char "0" || line[length] > #char "9" continue;
        }
        arguments := trim(slice(line, length, line.count - length));
        command.run(console, arguments);
        found = true;
        break;
    }
    if !found {
        split: s64;
        while split < line.count && line[split] != #char " " && line[split] != #char "\t" split += 1;
        console_write(console, tprint("Unknown command: %", slice(line, 0, split)), .ERROR);
    }

    console_set_input(console, "");
    free(console.draft);
    console.draft = "";
    console.history_cursor = console.history.count;
}

console_set_input :: (console: *Console_State, text: string) {
    console.input.count = 0;
    for c: text {
        if console.input.count == CONSOLE_INPUT_LIMIT break;
        array_add(*console.input, c);
    }
    console.cursor = console.input.count;
}

console_insert_character :: (console: *Console_State, character: u32) {
    if character < 32 || character == 127 || character > 0x10ffff return;
    if character >= 0xd800 && character <= 0xdfff return;

    bytes: [4] u8;
    encoded: string = .{data = bytes.data, count = 4};
    Unicode.character_utf32_to_utf8(character, *encoded);
    if console.input.count + encoded.count > CONSOLE_INPUT_LIMIT return;
    for byte: encoded {
        array_insert_at(*console.input, byte, console.cursor);
        console.cursor += 1;
    }
    console.history_cursor = console.history.count;
    console.scroll = 0;
}

console_paste_text :: (console: *Console_State, text: string) {
    pasted: [..] u8;
    defer array_free(pasted);
    previous_cr := false;
    for c: text {
        if c == #char "\n" && previous_cr {
            previous_cr = false;
            continue;
        }
        previous_cr = c == #char "\r";
        byte := c;
        if c == #char "\r" || c == #char "\n" || c == #char "\t" byte = #char " ";
        if byte < 32 || byte == 127 continue;
        if console.input.count + pasted.count == CONSOLE_INPUT_LIMIT {
            console_write(console, tprint("Input is limited to % bytes. Paste was not inserted.", CONSOLE_INPUT_LIMIT), .ERROR);
            return;
        }
        array_add(*pasted, byte);
    }
    if !pasted.count return;

    for byte: pasted {
        array_insert_at(*console.input, byte, console.cursor);
        console.cursor += 1;
    }
    console.history_cursor = console.history.count;
    console.scroll = 0;
}

console_previous_character :: (console: *Console_State) -> s64 {
    position := max(0, console.cursor - 1);
    while position > 0 && (console.input[position] & 0xc0) == 0x80 position -= 1;
    return position;
}

console_next_character :: (console: *Console_State) -> s64 {
    position := min(console.input.count, console.cursor + 1);
    while position < console.input.count && (console.input[position] & 0xc0) == 0x80 position += 1;
    return position;
}

console_backspace :: (console: *Console_State) {
    if console.cursor == 0 return;
    start := console_previous_character(console);
    console_erase_range(console, start, console.cursor);
}

console_delete :: (console: *Console_State) {
    if console.cursor == console.input.count return;
    console_erase_range(console, console.cursor, console_next_character(console));
}

console_delete_previous_word :: (console: *Console_State) {
    start := console.cursor;
    while start > 0 && console_word_separator(console.input[start - 1]) start -= 1;
    while start > 0 && !console_word_separator(console.input[start - 1]) start -= 1;
    console_erase_range(console, start, console.cursor);
}

console_delete_next_word :: (console: *Console_State) {
    end := console.cursor;
    while end < console.input.count && console_word_separator(console.input[end]) end += 1;
    while end < console.input.count && !console_word_separator(console.input[end]) end += 1;
    console_erase_range(console, console.cursor, end);
}

console_clear_before_cursor :: (console: *Console_State) {
    console_erase_range(console, 0, console.cursor);
}

console_history :: (console: *Console_State, direction: s64) {
    if !console.history.count return;
    if console.history_cursor == console.history.count {
        free(console.draft);
        console.draft = copy_string(console_input(console));
    }
    console.history_cursor = max(0, min(console.history.count, console.history_cursor + direction));
    if console.history_cursor == console.history.count {
        console_set_input(console, console.draft);
    } else {
        console_set_input(console, console.history[console.history_cursor]);
    }
}

console_deinit :: (console: *Console_State) {
    for line: console.lines free(line.text);
    for command: console.history free(command);
    free(console.draft);
    free(console.pending_send);
    array_free(console.lines);
    array_free(console.input);
    array_free(console.history);
}

#scope_file
#import "Basic";
#import "String";
Unicode :: #import "Unicode";

console_next_argument :: (arguments: string, position: *s64) -> string {
    while position.* < arguments.count && console_word_separator(arguments[position.*]) position.* += 1;
    start := position.*;
    while position.* < arguments.count && !console_word_separator(arguments[position.*]) position.* += 1;
    return slice(arguments, start, position.* - start);
}

console_parse_delay :: (value: string) -> (delay_ms: s32, error: string) {
    digits := value;
    if digits.count >= 2 && equal_nocase(slice(digits, digits.count - 2, 2), "ms") {
        digits = slice(digits, 0, digits.count - 2);
    }
    if !digits.count return 0, "Usage: -delay <milliseconds> (example: -delay 10ms).";

    milliseconds: s32;
    for c: digits {
        if c < #char "0" || c > #char "9" {
            return 0, "Delay must be a positive integer in milliseconds (example: -delay 10ms).";
        }
        digit := cast(s32)(c - #char "0");
        if milliseconds > (0x7fff_ffff - digit) / 10 {
            return 0, "Delay exceeds 2147483647 milliseconds.";
        }
        milliseconds = milliseconds * 10 + digit;
    }
    if milliseconds == 0 return 0, "Delay must be greater than zero.";
    return milliseconds, "";
}

console_erase_range :: (console: *Console_State, start: s64, end: s64) {
    if start == end return;
    count := end - start;
    for i: end..console.input.count-1 console.input[i - count] = console.input[i];
    console.input.count -= count;
    console.cursor = start;
    console.history_cursor = console.history.count;
}

// Word boundaries are whitespace or buffer ends, so deletion preserves complete UTF-8 characters.
console_word_separator :: (c: u8) -> bool {
    return c == #char " " || c == #char "\t" || c == #char "\r" || c == #char "\n";
}
