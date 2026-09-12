Console_Completion_Kind :: enum {
    NONE; COMMAND; SHOW; SET; EDITOR; EDIT; CUSTOM; PLAY; PLAY_OPTION; SUBTITLES; SUBTITLE_OPTION; BLOW; TOGGLE;
    MARKERS; MARKER_NAME; RESET; REGISTERS; NOCLIP; MOVE_AXIS; SWITCH; TEMP_ALIAS;
}

Console_Completion :: struct {
    matches: [..] string;
    before, after, expected: string;
    cursor: s64;
    index: s64 = -1;
}

console_completion_context :: (console: *Console_State) -> (kind: Console_Completion_Kind, start: s64, end: s64) {
    if console.zork_mode return .NONE, 0, 0;
    text  := console_input(console);
    start := console.cursor;
    end   := console.cursor;

    while start > 0        && !console_word_separator(text[start - 1]) start -= 1;
    while end < text.count && !console_word_separator(text[end])       end   += 1;

    before := slice(text, 0, start);
    expanded, alias_error := console_expand_aliases(console, before);
    defer free(expanded);
    if alias_error.count return .NONE, start, end;
    before = expanded;
    position: s64;
    command := console_next_argument(before, *position);
    subject := console_next_argument(before, *position);
    if !command.count return .COMMAND, start, end;
    if equal_nocase(command, "unalias") && !subject.count return .TEMP_ALIAS, start, end;
    if equal_nocase(command, "hello") && !subject.count {
        first: s64;
        while first < text.count && console_word_separator(text[first]) first += 1;
        return .COMMAND, first, end;
    }
    if equal_nocase(command, "show") {
        if !subject.count return .SHOW, start, end;
        if !equal_nocase(subject, "subtitles") return .NONE, start, end;
        while position < before.count {
            argument := console_next_argument(before, *position);
            if argument.count && !equal_nocase(argument, "-comment") && !console_subtitle_hide_speakers_option(argument) &&
               console_subtitle_language_option(argument) == .BOTH {
                return .SUBTITLE_OPTION, start, end;
            }
        }
        return .SUBTITLES, start, end;
    }
    if equal_nocase(command, "set") && !subject.count return .SET, start, end;
    if equal_nocase(command, "move") && !subject.count return .MOVE_AXIS, start, end;
    if equal_nocase(command, "switch") && !subject.count return .SWITCH, start, end;
    if equal_nocase(command, "list") || equal_nocase(command, "add") || equal_nocase(command, "remove") {
        if !subject.count return .MARKERS, start, end;
        if equal_nocase(command, "remove") && equal_nocase(subject, "markers") &&
           !console_next_argument(before, *position).count return .MARKER_NAME, start, end;
    }
    if (equal_nocase(command, "mark") || equal_nocase(command, "back") || equal_nocase(command, "tp") || equal_nocase(command, "rename")) &&
       !subject.count return .MARKER_NAME, start, end;
    if equal_nocase(command, "reset") {
        if !subject.count return .RESET, start, end;
        if equal_nocase(subject, "marker") && !console_next_argument(before, *position).count return .REGISTERS, start, end;
    }
    if equal_nocase(command, "noclip") && !subject.count return .NOCLIP, start, end;
    if (equal_nocase(command, "open") || equal_nocase(command, "close")) && !subject.count return .EDITOR, start, end;
    if equal_nocase(command, "edit") {
        if !subject.count return .EDIT, start, end;
        if equal_nocase(subject, "custom") && !console_next_argument(before, *position).count return .CUSTOM, start, end;
    }
    if equal_nocase(command, "play") || equal_nocase(command, "do") {
        position = 0;
        console_next_argument(before, *position);
        has_name := false;
        while position < before.count {
            argument := console_next_argument(before, *position);
            if !argument.count break;
            if equal_nocase(argument, "-delay") {
                if !console_next_argument(before, *position).count return .NONE, start, end;
            } else if !console_send_speed_option(argument) && !equal_nocase(argument, "--udlr") {
                has_name = true;
            }
        }
        return ifx has_name then .PLAY_OPTION else .PLAY, start, end;
    }
    if equal_nocase(command, "blow")   && !subject.count return .BLOW,   start, end;
    if equal_nocase(command, "toggle") && !subject.count return .TOGGLE, start, end;
    return .NONE, start, end;
}

console_completion_is_current :: (console: *Console_State) -> bool {
    state := *console.completion;
    return state.matches.count > 1 && state.cursor == console.cursor && state.expected == console_input(console);
}

console_complete :: (console: *Console_State, levels: [] string, customs: [] string,
                     subtitle_levels: [] string, backwards := false, markers: [] string = .[]) {
    state := *console.completion;
    if console_completion_is_current(console) {
        if state.index < 0
            state.index = ifx backwards then state.matches.count - 1 else 0;
        else
            state.index = (state.index + (ifx backwards then -1 else 1) + state.matches.count) % state.matches.count;
        console_completion_apply(console, state.matches[state.index], false);
        return;
    }
    console_completion_reset(state);
    kind, start, end := console_completion_context(console);
    if kind == .NONE return;
    input := console_input(console);
    prefix := slice(input, start, console.cursor - start);
    if kind == {
        case .COMMAND;
            for command: CONSOLE_COMMANDS {
                if !command.hidden console_completion_add(state, prefix, command.name);
            }
            for alias: console.config.aliases console_completion_add(state, prefix, alias.name);
            for alias: console.temporary_aliases console_completion_add(state, prefix, alias.name);
        case .TEMP_ALIAS;
            for alias: console.temporary_aliases console_completion_add(state, prefix, alias.name);
        case .SHOW;
            for name: string.["level", "position", "subtitles"] console_completion_add(state, prefix, name);
        case .SET;
            console_completion_add(state, prefix, "position");
        case .MOVE_AXIS;
            for name: string.["-x", "-y", "-z"] console_completion_add(state, prefix, name);
        case .SWITCH;
            for name: levels console_completion_add(state, prefix, name);
        case .MARKERS;
            console_completion_add(state, prefix, "markers");
        case .MARKER_NAME;
            for name: markers console_completion_add(state, prefix, name);
        case .RESET;
            console_completion_add(state, prefix, "marker");
        case .REGISTERS;
            console_completion_add(state, prefix, "registers");
        case .NOCLIP;
            for name: string.["enable", "disable"] console_completion_add(state, prefix, name);
        case .EDITOR;
            console_completion_add(state, prefix, "editor");
        case .EDIT;
            for name: string.["solution", "custom"] console_completion_add(state, prefix, name);
            for name: levels console_completion_add(state, prefix, name);
            for name: customs console_completion_add(state, prefix, name);
        case .CUSTOM;
            for name: customs console_completion_add(state, prefix, name);
        case .PLAY; #through;
        case .PLAY_OPTION;
            if kind == .PLAY {
                for name: levels console_completion_add(state, prefix, name);
                for name: customs console_completion_add(state, prefix, name);
            }
            rest, alias_error := console_expand_aliases(console, tprint("% %", slice(input, 0, start), slice(input, end, input.count - end)));
            defer free(rest);
            if alias_error.count return;
            position: s64;
            speed_present, delay_present: bool;
            while position < rest.count {
                argument := console_next_argument(rest, *position);
                if console_send_speed_option(argument) speed_present = true;
                if equal_nocase(argument, "-delay") delay_present = true;
            }
            if !speed_present {
                for option: string.["-fast", "-superfast", "-rabbit", "-slow", "-superslow", "-turtle"] {
                    console_completion_add(state, prefix, option);
                }
            }
            if !delay_present console_completion_add(state, prefix, "-delay");
        case .SUBTITLES; #through;
        case .SUBTITLE_OPTION;
            if kind == .SUBTITLES for name: subtitle_levels console_completion_add(state, prefix, name);
            // Check both sides of the cursor before suggesting another option.
            rest, alias_error := console_expand_aliases(console, tprint("% %", slice(input, 0, start), slice(input, end, input.count - end)));
            defer free(rest);
            if alias_error.count return;
            position: s64;
            comment_present, language_present, no_character_present: bool;
            while position < rest.count {
                argument := console_next_argument(rest, *position);
                if equal_nocase(argument, "-comment") comment_present = true;
                if console_subtitle_hide_speakers_option(argument) no_character_present = true;
                if console_subtitle_language_option(argument) != .BOTH language_present = true;
            }
            if !comment_present console_completion_add(state, prefix, "-comment");
            if !no_character_present {
                for option: string.["-no_character", "-nosayer"] console_completion_add(state, prefix, option);
            }
            if !language_present {
                for option: string.["-en", "-cn", "-sc"] console_completion_add(state, prefix, option);
            }
        case .BLOW;
            for name: CONSOLE_BLOW_NAMES console_completion_add(state, prefix, name);
        case .TOGGLE;
            for name: string.["full", "small", "normal", "mini"] console_completion_add(state, prefix, name);
    }
    if !state.matches.count return;
    state.before = copy_string(slice(input, 0, start));
    state.after = copy_string(slice(input, end, input.count - end));
    if state.matches.count == 1 {
        console_completion_apply(console, state.matches[0], true);
        console_completion_reset(state);
        return;
    }
    common := state.matches[0].count;
    for match: state.matches {
        common = min(common, match.count);
        length: s64;
        while length < common && equal_nocase(slice(match, length, 1), slice(state.matches[0], length, 1)) length += 1;
        common = length;
    }
    while common > 0 && common < state.matches[0].count && (state.matches[0][common] & 0xc0) == 0x80 common -= 1;
    if !backwards && common > prefix.count {
        console_completion_apply(console, slice(state.matches[0], 0, common), false);
    } else {
        state.index = ifx backwards then state.matches.count - 1 else 0;
        console_completion_apply(console, state.matches[state.index], false);
    }
}

console_completion_reset :: (state: *Console_Completion) {
    for match: state.matches free(match);
    array_free(state.matches);
    free(state.before);
    free(state.after);
    free(state.expected);
    state.* = .{};
}

#scope_file
#import "Basic";
#import "String";

console_completion_add :: (state: *Console_Completion, prefix: string, name: string) {
    if name.count < prefix.count || !equal_nocase(slice(name, 0, prefix.count), prefix) return;
    for match: state.matches if equal_nocase(match, name) return;
    array_add(*state.matches, copy_string(name));
}

console_completion_apply :: (console: *Console_State, match: string, add_space: bool) {
    state := *console.completion;
    space := ifx add_space && !state.after.count then " " else "";
    text := tprint("%%%%", state.before, match, space, state.after);
    if text.count > CONSOLE_INPUT_LIMIT {
        console_write(console, "Completion would exceed the input limit.", .ERROR);
        console_completion_reset(state);
        return;
    }
    console_set_input(console, text);
    console.cursor = state.before.count + match.count + space.count;
    console.history_cursor = console.history.count;
    free(state.expected);
    state.expected = copy_string(console_input(console));
    state.cursor = console.cursor;
}
