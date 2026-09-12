ZORK_DIRECTORY :: "data/zork";
ZORK_DEFAULT_SAVE :: "zork1.sav";

Zork_Process :: struct {
    process, job, input, output: Win.HANDLE;
    incoming: [..] u8;
    input_kind: Zork_Input_Kind;
    filename: string;
}

zork: Zork_Process;

zork_start :: (console: *Console_State, directory := ZORK_DIRECTORY) {
    zork_update(console);
    if zork.process {
        console.zork_mode = true;
        console.zork_input_kind = zork.input_kind;
        zork_prepare_console(console);
        console_write(console, "Zork resumed. /back returns to the console; /help shows the controls.", .INFO);
        zork_show_file_prompt(console);
        return;
    }

    if !file_exists(tprint("%/dfrotz.exe", directory)) || !file_exists(tprint("%/zork1.z3", directory)) {
        console_write(console, "Zork needs dfrotz.exe and zork1.z3 in data/zork/ next to ootss-cmd.exe.", .ERROR);
        return;
    }
    path_buffer: [32768] u16;
    path_length := Win.GetFullPathNameW(utf8_to_wide(directory,, temp), path_buffer.count, path_buffer.data, null);
    if !path_length || path_length >= path_buffer.count {
        console_write(console, "Could not resolve the data/zork/ directory.", .ERROR);
        return;
    }
    absolute := wide_to_utf8(path_buffer.data, cast(s32) path_length,, temp);
    executable := tprint("%/dfrotz.exe", absolute);

    initialized := false;
    defer if !initialized zork_deinit();
    attributes: Win.SECURITY_ATTRIBUTES;
    attributes.nLength = size_of(Win.SECURITY_ATTRIBUTES);
    attributes.bInheritHandle = 1;
    child_input, child_output: Win.HANDLE;
    defer {
        if child_input Win.CloseHandle(child_input);
        if child_output Win.CloseHandle(child_output);
    }
    if !Win.CreatePipe(*child_input, *zork.input, *attributes, 4096) ||
       !Win.CreatePipe(*zork.output, *child_output, *attributes, 65536) ||
       !Win.SetHandleInformation(zork.input, Win.HANDLE_FLAG_INHERIT, 0) ||
       !Win.SetHandleInformation(zork.output, Win.HANDLE_FLAG_INHERIT, 0) {
        console_write(console, tprint("Could not create Zork's input/output pipes (Windows error %).", Win.GetLastError()), .ERROR);
        return;
    }

    zork.job = Win.CreateJobObjectA(null, null);
    limits: Win.JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
    limits.BasicLimitInformation.LimitFlags = Win.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if !zork.job || !Win.SetInformationJobObject(zork.job, .ExtendedLimitInformation, *limits, size_of(type_of(limits))) {
        console_write(console, tprint("Could not manage the Zork process (Windows error %).", Win.GetLastError()), .ERROR);
        return;
    }

    startup: Win.STARTUPINFOW;
    startup.cb = size_of(Win.STARTUPINFOW);
    startup.dwFlags = Win.STARTF_USESTDHANDLES;
    startup.hStdInput = child_input;
    startup.hStdOutput = child_output;
    startup.hStdError = child_output;
    process: Win.PROCESS_INFORMATION;
    // The overlay owns scrolling and the prompt. Hide the repeated status row and disable MORE pauses.
    command := tprint("\"%\" -p -w 240 -h 999 -R ch1 -R mp0 zork1.z3", executable);
    if !Win.CreateProcessW(utf8_to_wide(executable,, temp), utf8_to_wide(command,, temp), null, null, 1,
                           Win.CREATE_NO_WINDOW | Win.CREATE_SUSPENDED, null, path_buffer.data, *startup, *process) {
        console_write(console, tprint("Could not start dfrotz.exe (Windows error %).", Win.GetLastError()), .ERROR);
        return;
    }
    zork.process = process.hProcess;
    defer Win.CloseHandle(process.hThread);
    // Assign the suspended child before it runs, so even an unexpected helper exit cannot orphan it.
    if !Win.AssignProcessToJobObject(zork.job, zork.process) || Win.ResumeThread(process.hThread) == -1 {
        console_write(console, tprint("Could not start the managed Zork session (Windows error %).", Win.GetLastError()), .ERROR);
        Win.TerminateProcess(zork.process, 1);
        return;
    }
    initialized = true;
    zork.filename = copy_string(ZORK_DEFAULT_SAVE);
    console.zork_mode = true;
    console.zork_input_kind = .BUSY;
    zork_prepare_console(console);
    console_write(console, "ZORK: /back returns to the console; /help shows controls.", .INFO);
}

zork_prepare_console :: (console: *Console_State) {
    command_clear(console, "");
    console.reveal_output = true;
}

zork_back :: (console: *Console_State) {
    console.zork_mode = false;
    command_clear(console, "");
    console_write(console, "Back at the helper. Type zork to resume your game.", .INFO);
}

zork_send_input :: (console: *Console_State) {
    if !zork.process || !console.zork_mode || zork.input_kind == .BUSY return;
    original := console.pending_zork_input;
    line := original;
    if zork.input_kind == .FILENAME {
        error: string;
        line, error = zork_save_filename(line, zork.filename);
        if error.count {
            zork_reject_input(console, error);
            return;
        }
    } else if zork.input_kind == .OVERWRITE {
        if equal_nocase(line, "y") || equal_nocase(line, "yes") line = "y";
        else if equal_nocase(line, "n") || equal_nocase(line, "no") line = "n";
        else {
            zork_reject_input(console, "Overwrite this save? Enter y or n.");
            return;
        }
    }
    encoded, error := zork_encode_input(line);
    if error.count || (zork.input_kind == .FILENAME && encoded.count > 240) {
        if !error.count error = "The save filename is too long (maximum 240 bytes in the Windows text encoding).";
        zork_reject_input(console, error);
        return;
    }
    if zork.input_kind == .LINE {
        // Treat typed backslashes literally instead of exposing dfrotz's screen/control escape sequences.
        escaped: [..] u8;
        defer array_free(escaped);
        for c: encoded {
            array_add(*escaped, c);
            if c == #char "\\" array_add(*escaped, c);
        }
        encoded = tprint("%", string.{escaped.count, escaped.data});
    }
    payload := tprint("%\n", encoded);
    written: u32;
    if !Win.WriteFile(zork.input, payload.data, cast(u32) payload.count, *written, null) || written != payload.count {
        console_write(console, tprint("Could not send input to Zork (Windows error %).", Win.GetLastError()), .ERROR);
        console.zork_mode = false;
        console.zork_input_kind = .BUSY;
        zork_deinit();
        return;
    }
    if zork.input_kind == .FILENAME {
        filename := copy_string(line);
        free(zork.filename);
        zork.filename = filename;
    }
    zork.input_kind = .BUSY;
    console.zork_input_kind = .BUSY;
}

zork_reject_input :: (console: *Console_State, error: string) {
    console_write(console, error, .ERROR);
    // Retain a rejected filename for correction without discarding a newer draft typed after Enter.
    if !console.input.count console_set_input(console, console.pending_zork_input);
    console.zork_input_kind = zork.input_kind;
}

zork_update :: (console: *Console_State) {
    if !zork.process return;
    // Peek before ReadFile, and bound each frame's work. Waiting for input must never block the UI thread.
    budget: u32 = 65536;
    while budget > 0 {
        available: u32;
        if !Win.PeekNamedPipe(zork.output, null, 0, null, *available, null) {
            error := Win.GetLastError();
            if error != 109 { // ERROR_BROKEN_PIPE is normal at interpreter exit.
                console_write(console, tprint("Could not read Zork output (Windows error %).", error), .ERROR);
                console.zork_mode = false;
                console.zork_input_kind = .BUSY;
                zork_deinit();
                return;
            }
            break;
        }
        if !available break;
        buffer: [4096] u8;
        received: u32;
        if !Win.ReadFile(zork.output, buffer.data, min(available, min(budget, cast(u32) buffer.count)), *received) || !received break;
        budget -= received;
        for i: 0..received-1 array_add(*zork.incoming, buffer[i]);
        zork_parse_output(console);
        if zork.incoming.count > 65536 {
            console_write(console, "Zork produced an oversized incomplete output line. The session was closed.", .ERROR);
            console.zork_mode = false;
            console.zork_input_kind = .BUSY;
            zork_deinit();
            return;
        }
    }
    if Win.WaitForSingleObject(zork.process, 0) != Win.WAIT_TIMEOUT {
        // If the final output exceeded this frame's budget, drain it on subsequent frames before closing.
        if !budget return;
        if zork.incoming.count zork_write_output(console, .{zork.incoming.count, zork.incoming.data});
        code: u32;
        Win.GetExitCodeProcess(zork.process, *code);
        console.zork_mode = false;
        console.zork_input_kind = .BUSY;
        if code console_write(console, tprint("Zork exited with code %. Type zork to start again.", code), .ERROR);
        else console_write(console, "Zork ended. Back at the console; type zork to play again.", .INFO);
        zork_deinit();
    }
}

zork_parse_output :: (console: *Console_State) {
    while zork.incoming.count {
        text: string = .{zork.incoming.count, zork.incoming.data};
        if begins_with(text, "Please enter a filename [") {
            // This old Windows dfrotz build prints uninitialized bytes in its initial default filename.
            // Consume the entire native prompt and always send our own explicit, validated default.
            end := zork_find_text(text, "]: ");
            if end < 0 return;
            zork_consume_output(end + 3);
            zork.input_kind = .FILENAME;
            console.zork_input_kind = .FILENAME;
            zork_show_file_prompt(console);
            continue;
        }
        if begins_with(text, "Overwrite existing file? ") {
            zork_consume_output("Overwrite existing file? ".count);
            zork.input_kind = .OVERWRITE;
            console.zork_input_kind = .OVERWRITE;
            zork_show_file_prompt(console);
            continue;
        }
        newline := zork_find_text(text, "\n");
        if newline >= 0 {
            zork_write_output(console, slice(text, 0, newline));
            zork_consume_output(newline + 1);
            continue;
        }
        if text[text.count - 1] == #char ">" {
            if text.count > 1 zork_write_output(console, slice(text, 0, text.count - 1));
            zork.incoming.count = 0;
            zork.input_kind = .LINE;
            console.zork_input_kind = .LINE;
        }
        return;
    }
}

zork_show_file_prompt :: (console: *Console_State) {
    if zork.input_kind == .FILENAME {
        console_write(console, tprint("Save filename in data/zork/ [%]:", zork.filename), .INFO, wrap = true);
    } else if zork.input_kind == .OVERWRITE {
        console_write(console, tprint("Overwrite data/zork/%? (y/n)", zork.filename), .INFO, wrap = true);
    }
}

zork_write_output :: (console: *Console_State, raw: string) {
    line := raw;
    if line.count && line[line.count - 1] == #char "\r" line = slice(line, 0, line.count - 1);
    if line == "Compression mode SPANS, hiding top 1 lines" || line == "More prompts OFF" return;
    text := zork_decode_output(line);
    console_write(console, text, wrap = true);
}

zork_consume_output :: (count: s64) {
    for i: count..zork.incoming.count-1 zork.incoming[i - count] = zork.incoming[i];
    zork.incoming.count -= count;
}

zork_find_text :: (text: string, needle: string) -> s64 {
    if text.count < needle.count return -1;
    for i: 0..text.count-needle.count {
        if slice(text, i, needle.count) == needle return i;
    }
    return -1;
}

zork_encode_input :: (text: string) -> (encoded: string, error: string) {
    if !text.count return "", "";
    wide, ok, wide_bytes := utf8_to_wide(text,, temp);
    if !ok return "", "Could not encode the Zork input.";
    count := Win.WideCharToMultiByte(0, 0, wide, wide_bytes / 2, null, 0, null, null);
    if count <= 0 return "", "Could not encode the Zork input.";
    buffer := cast(*u8) alloc(count);
    defer free(buffer);
    if !Win.WideCharToMultiByte(0, 0, wide, wide_bytes / 2, buffer, count, null, null) {
        return "", "Could not encode the Zork input.";
    }
    result: string = .{count, buffer};
    if zork_decode_output(result) != text {
        return "", "This dfrotz build cannot represent that text in the Windows encoding. Use an English save name.";
    }
    return tprint("%", result), "";
}

zork_decode_output :: (text: string) -> string {
    if !text.count return "";
    count := Win.MultiByteToWideChar(0, 0, text.data, cast(s32) text.count, null, 0);
    if count <= 0 return "[Could not decode Zork output]";
    wide := cast(*u16) alloc(count * size_of(u16));
    defer free(wide);
    if !Win.MultiByteToWideChar(0, 0, text.data, cast(s32) text.count, wide, count) return "[Could not decode Zork output]";
    return wide_to_utf8(wide, count,, temp);
}

zork_deinit :: () {
    if zork.input Win.CloseHandle(zork.input);
    if zork.output Win.CloseHandle(zork.output);
    if zork.job Win.CloseHandle(zork.job);
    if zork.process {
        Win.WaitForSingleObject(zork.process, 100);
        Win.CloseHandle(zork.process);
    }
    array_free(zork.incoming);
    free(zork.filename);
    zork = .{};
}

#scope_file
#import "Basic";
#import "String";
#import "Math";
#import "File_Utilities";
#import "Windows_Utf8";
Win :: #import "Windows";
