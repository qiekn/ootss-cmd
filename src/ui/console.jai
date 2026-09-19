#load "console_completion.jai";
#load "config.jai";
#load "console_zork.jai";
#load "console_text.jai";

Console_Line_Kind :: enum {
    INFO;
    COMMAND;
    OUTPUT;
    ERROR;
    ICON;
}

Console_Action :: enum {
    NONE; HIDE; EXIT; SHOW_POSITION; SHOW_LEVEL; SET_POSITION; SHOW_SUBTITLES; EDIT_SOLUTION; PLAY_SOLUTION; JUMP; CONSOLE_MODE; // Normal
    MARK_POSITION; LIST_MARKERS; REMOVE_MARKER; RENAME_MARKER; BACK_POSITION; RESET_MARKERS; NOCLIP; FREECAM; SWITCH_LEVEL;
    EDITOR_RECORD; EDITOR_PAUSE; EDITOR_STOP; EDITOR_SAVE; EDITOR_CLOSE;                 // Solution Editor
    ZORK_START; ZORK_INPUT; ZORK_BACK;                                                                 // Zork
}

Console_Mode :: enum { NORMAL; FULL; SMALL; MINI; }
Console_Picture :: enum { NONE; CAPTAIN; PIRATE; CAPTAIN_PIRATE; }

CONSOLE_INPUT_LIMIT    :: 1024;
CONSOLE_OUTPUT_LIMIT   :: 2048;
CONSOLE_BLOW_NAMES     :: string.["alien", "mirror", "wave"]; // jblow memes

UNDO_DEFAULT_\  DELAY  :: 10;
UNDO_FAST_\     DELAY  :: 1; // @TODO maybe 1ms doesn't work QwQ.
RESET_DEFAULT_\ DELAY  :: 75;

Send_Time_Mode :: enum { NORMAL; FAST; SLOW; }
Console_Subtitle_Language :: enum { BOTH; ENGLISH; CHINESE; }

Console_Send_Arguments :: struct {
    source: string;
    delay_ms: s32;
    alternate: bool;
    time_mode: Send_Time_Mode;
}

Console_Line :: struct {
    text: string;
    kind: Console_Line_Kind;
    wrap: bool;
}

Console_State :: struct {
    config: Console_Config;
    temporary_aliases: [..] Console_Alias;
    lines: [..] Console_Line;
    input: [..] u8;
    cursor: s64;
    history: [..] string;
    history_cursor: s64;
    draft: string;
    scroll: s64;
    scroll_to_line: s64 = -1;
    reveal_output: bool;
    show_subtitles: bool;
    completion: Console_Completion;
    show_blow: bool;
    picture: Console_Picture;
    restart_blow: bool;
    blow_index: s64;
    next_blow_index: s64;
    pending_send: string;
    submission: Console_Submission;
    pending_send_hold_ms: s32 = DEFAULT_HOLD;
    pending_send_interval_ms: s32 = DEFUALT_INTERVAL;
    pending_send_time_mode: Send_Time_Mode;
    pending_send_interruptible: bool;
    pending_reset: bool;
    pending_action: Console_Action;
    pending_mode: Console_Mode;
    pending_play: Console_Send_Arguments;
    pending_subtitle_level: string;
    pending_subtitle_comments: bool;
    pending_subtitle_hide_speakers: bool;
    pending_subtitle_language: Console_Subtitle_Language;
    pending_edit_level: string;
    pending_edit_custom: bool;
    pending_jump_step: s64;
    pending_position: Game_Position;
    pending_position_relative: bool;
    pending_position_take: bool;
    pending_position_change: bool;
    pending_switch_level: string;
    pending_marker_name: string;
    pending_marker_new_name: string;
    pending_marker_current: bool;
    pending_noclip: s32 = -1;
    pending_freecam: s32 = -1;
    pending_freecam_change: bool;
    pending_freecam_pan: bool;
    zork_mode: bool;
    zork_input_kind: Zork_Input_Kind;
    pending_zork_input: string;
}

Console_Command :: struct {
    name: string;
    run: (console: *Console_State, arguments: string);
    hidden := false;
}

// @TODO maybe do some metaprogramming here
CONSOLE_COMMANDS :: Console_Command.[
    .{name = "ls",            run = command_ls               },
    .{name = "echo",          run = command_echo             },
    .{name = "print",         run = command_print            },
    .{name = "help",          run = command_help             },
    .{name = "clear",         run = command_clear            },
    .{name = "cl",            run = command_clear            },
    .{name = "blow",          run = command_blow             },
    .{name = "about",         run = command_about            },
    .{name = "license",       run = command_license          },
    .{name = "send",          run = command_send             },
    .{name = "send_alt",      run = command_send_alt         },
    .{name = "play",          run = command_play             },
    .{name = "do",            run = command_play             },
    .{name = "undo",          run = command_undo             },
    .{name = "z",             run = command_undo             },
    .{name = "reset",         run = command_reset_or_markers },
    .{name = "r",             run = command_reset            },
    .{name = "show",          run = command_show             },
    .{name = "set",           run = command_set              },
    .{name = "move",          run = command_move             },
    .{name = "move_xy",       run = command_move_xy          },
    .{name = "mark",          run = command_mark             },
    .{name = "list",          run = command_list_markers     },
    .{name = "remove",        run = command_remove_markers   },
    .{name = "add",           run = command_add_markers      },
    .{name = "rename",        run = command_rename_marker    },
    .{name = "back",          run = command_back             },
    .{name = "tp",            run = command_back             },
    .{name = "alias",         run = command_alias            },
    .{name = "unalias",       run = command_unalias          },
    .{name = "switch",        run = command_switch           },
    .{name = "noclip",        run = command_noclip           },
    .{name = "freecam",       run = command_freecam          },
    .{name = "open",          run = command_open             },
    .{name = "close",         run = command_close            },
    .{name = "edit",          run = command_edit             },
    .{name = "jump",          run = command_jump             },
    .{name = "j",             run = command_jump             },
    .{name = "record",        run = command_record           },
    .{name = "pause",         run = command_pause            },
    .{name = "stop",          run = command_stop             },
    .{name = "save",          run = command_save             },
    .{name = "toggle",        run = command_toggle           },
    .{name = "q",             run = command_hide             },
    .{name = "quit",          run = command_hide             },
    .{name = "exit",          run = command_exit             },
    .{name = "terminate",     run = command_exit             },
    .{name = "xyzzy",         run = command_xyzzy            },
    .{name = "hello sailor",  run = command_hello_sailor     },
    .{name = "zork",          run = command_zork,         hidden = true},
    // Match the combined picture commands before their single-word prefixes.
    .{name = "captain and pirate", run = command_captain_pirate, hidden = true},
    .{name = "pirate and captain", run = command_captain_pirate, hidden = true},
    .{name = "captain",            run = command_captain,        hidden = true},
    .{name = "pirate",             run = command_pirate,         hidden = true},
    .{name = "blow, try it!",      run = command_blow_try_it,    hidden = true},
];

command_record :: (console: *Console_State, arguments: string) {
    console_queue_editor_action(console, arguments, .EDITOR_RECORD, "record");
}

command_pause :: (console: *Console_State, arguments: string) {
    console_queue_editor_action(console, arguments, .EDITOR_PAUSE, "pause");
}

command_stop :: (console: *Console_State, arguments: string) {
    console_queue_editor_action(console, arguments, .EDITOR_STOP, "stop");
}

command_save :: (console: *Console_State, arguments: string) {
    console_queue_editor_action(console, arguments, .EDITOR_SAVE, "save");
}

console_queue_editor_action :: (console: *Console_State, arguments: string, action: Console_Action, name: string) {
    if arguments.count { console_write(console, tprint("Usage: % (requires an open editor)", name), .ERROR); return; }
    console.pending_action = action;
}

command_send :: (console: *Console_State, arguments: string) {
    console_queue_send(console, arguments, alternate = false);
}

command_send_alt :: (console: *Console_State, arguments: string) {
    console_queue_send(console, arguments, alternate = true);
}

command_play :: (console: *Console_State, arguments: string) {
    request, error := console_parse_send_arguments(arguments, alternate = true);
    defer free(request.source);
    if error.count { console_write(console, error, .ERROR); return; }
    position: s64;
    name := console_next_argument(request.source, *position);
    if console_next_argument(request.source, *position).count {
        console_write(console, "Usage: play|do [name] [-fast|-superfast|-rabbit|-slow|-superslow|-turtle] [-delay <ms>]", .ERROR);
        return;
    }
    if console.pending_send.count || console.pending_position_change || console.pending_freecam_change ||
       console.pending_action == .FREECAM || console.pending_action == .SET_POSITION ||
       console.pending_action == .BACK_POSITION || console.pending_action == .SWITCH_LEVEL || console.pending_action == .PLAY_SOLUTION {
        console_write(console, "A playback command is already waiting to run.", .ERROR);
        return;
    }
    free(console.pending_play.source);
    console.pending_play = request;
    request.source = "";
    console.pending_action = .PLAY_SOLUTION;
}

command_toggle :: (console: *Console_State, arguments: string) {
    name := trim(arguments);
    mode: Console_Mode;
    if equal_nocase(name, "full") mode = .FULL;
    else if equal_nocase(name, "small") mode = .SMALL;
    else if equal_nocase(name, "normal") mode = .NORMAL;
    else if equal_nocase(name, "mini") mode = .MINI;
    else {
        console_write(console, "Usage: toggle full|small|normal|mini", .ERROR);
        return;
    }
    console.pending_mode = mode;
    console.pending_action = .CONSOLE_MODE;
}

command_reset :: (console: *Console_State, arguments: string) {
    if arguments.count { console_write(console, "Usage: reset (alias: r)", .ERROR); return; }
    if console.pending_send.count {
        console_write(console, "A send command is already waiting to run.", .ERROR);
        return;
    }
    console_queue_send(console, "r", alternate = false, default_delay_ms = RESET_DEFAULT_DELAY,
                       interrupt_on_input = false);
    console.pending_reset = console.pending_send.count != 0;
}

command_show :: (console: *Console_State, arguments: string) {
    position: s64;
    subject := console_next_argument(arguments, *position);
    rest := trim(slice(arguments, position, arguments.count - position));
    if equal_nocase(subject, "position") && !rest.count console.pending_action = .SHOW_POSITION;
    else if equal_nocase(subject, "level") && !rest.count console.pending_action = .SHOW_LEVEL;
    else if equal_nocase(subject, "subtitles") command_show_subtitles(console, rest);
    else console_write(console,
                       "Usage: show level, show position, or show subtitles [level_name] [-comment] [-en|-cn|-sc] [-no_character|-nosayer]", .ERROR);
}

command_set :: (console: *Console_State, arguments: string) {
    cursor: s64;
    subject := console_next_argument(arguments, *cursor);
    if !equal_nocase(subject, "position") {
        console_write(console, "Usage: set position <x> <y> <z>", .ERROR);
        return;
    }
    console_queue_position_request(console, slice(arguments, cursor, arguments.count - cursor), "xyz", 3, false,
                                   "set position <x> <y> <z>");
}

console_subtitle_language_option :: (argument: string) -> Console_Subtitle_Language {
    if equal_nocase(argument, "-en") return .ENGLISH;
    if equal_nocase(argument, "-cn") || equal_nocase(argument, "-sc") return .CHINESE;
    return .BOTH;
}

console_subtitle_hide_speakers_option :: (argument: string) -> bool {
    return equal_nocase(argument, "-no_character") || equal_nocase(argument, "-nosayer");
}

command_show_subtitles :: (console: *Console_State, arguments: string) {
    position: s64;
    level: string;
    comments, hide_speakers: bool;
    language: Console_Subtitle_Language;
    while position < arguments.count {
        argument := console_next_argument(arguments, *position);
        if !argument.count break;
        selected := console_subtitle_language_option(argument);
        if selected != .BOTH {
            if language != .BOTH && language != selected {
                console_write(console, "Choose one subtitle language: -en or -cn/-sc.", .ERROR);
                return;
            }
            language = selected;
        } else if equal_nocase(argument, "-comment") {
            if comments { console_write(console, "Specify -comment only once.", .ERROR); return; }
            comments = true;
        } else if console_subtitle_hide_speakers_option(argument) {
            if hide_speakers { console_write(console, "Specify -no_character/-nosayer only once.", .ERROR); return; }
            hide_speakers = true;
        } else if argument[0] == #char "-" || level.count {
            console_write(console, "Usage: show subtitles [level_name] [-comment] [-en|-cn|-sc] [-no_character|-nosayer]", .ERROR);
            return;
        } else level = argument;
    }
    free(console.pending_subtitle_level);
    console.pending_subtitle_level = copy_string(level);
    console.pending_subtitle_comments = comments;
    console.pending_subtitle_hide_speakers = hide_speakers;
    console.pending_subtitle_language = language;
    console.pending_action = .SHOW_SUBTITLES;
}

command_open :: (console: *Console_State, arguments: string) {
    if !equal_nocase(trim(arguments), "editor") {
        console_write(console, "Usage: open editor.", .ERROR);
        return;
    }
    free(console.pending_edit_level);
    console.pending_edit_level = copy_string("temp");
    console.pending_edit_custom = false;
    console.pending_action = .EDIT_SOLUTION;
}

command_close :: (console: *Console_State, arguments: string) {
    if !equal_nocase(trim(arguments), "editor") {
        console_write(console, "Usage: close editor.", .ERROR);
        return;
    }
    console.pending_action = .EDITOR_CLOSE;
}

command_edit :: (console: *Console_State, arguments: string) {
    position: s64;
    level := console_next_argument(arguments, *position);
    extra := console_next_argument(arguments, *position);
    custom := equal_nocase(level, "custom") && extra.count > 0;
    if equal_nocase(level, "custom") && !extra.count {
        console_write(console, "Usage: edit custom <name>, or open editor for a new input.", .ERROR);
        return;
    }
    if custom {
        level = extra;
        extra = console_next_argument(arguments, *position);
    }
    if extra.count {
        console_write(console, "Usage: edit [level_name], or edit custom <name>. Bare edit uses the current level; open editor creates a new input.", .ERROR);
        return;
    }
    if !custom && equal_nocase(level, "temp") {
        console_write(console, "Use open editor to create a new temporary input.", .ERROR);
        return;
    }
    free(console.pending_edit_level);
    console.pending_edit_level = ifx !custom && equal_nocase(level, "solution") then "" else copy_string(level);
    console.pending_edit_custom = custom;
    console.pending_action = .EDIT_SOLUTION;
}

command_jump :: (console: *Console_State, arguments: string) {
    position: s64;
    value := console_next_argument(arguments, *position);
    extra := console_next_argument(arguments, *position);
    if !value.count || extra.count {
        console_write(console, "Usage: jump <step> or jump $ (alias: j).", .ERROR);
        return;
    }
    target: s64 = -1;
    if value != "$" {
        target = 0;
        for c: value {
            if c < #char "0" || c > #char "9" {
                console_write(console, "Jump needs a nonnegative step number or $ for the end.", .ERROR);
                return;
            }
            digit := cast(s64)(c - #char "0");
            if target > (SEND_KEY_LIMIT - digit) / 10 {
                console_write(console, tprint("Jump cannot exceed % steps.", SEND_KEY_LIMIT), .ERROR);
                return;
            }
            target = target * 10 + digit;
        }
    }
    console.pending_jump_step = target;
    console.pending_action = .JUMP;
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
    console_queue_send(console, tprint("z%", count), alternate = false, default_delay_ms = delay_ms,
                       interrupt_on_input = false);
}

console_send_speed_option :: (argument: string) -> bool {
    for option: string.["-fast", "-superfast", "-rabbit", "-slow", "-superslow", "-turtle"] {
        if equal_nocase(argument, option) return true;
    }
    return false;
}

console_parse_send_arguments :: (commands: string, alternate: bool, default_delay_ms: s32 = DEFAULT_DELAY)
                                 -> (request: Console_Send_Arguments, error: string) {
    source: [..] u8;
    defer array_free(source);
    position: s64;
    delay_ms: s32 = -1;
    has_speed := false;
    time_mode: Send_Time_Mode;
    while position < commands.count {
        argument := console_next_argument(commands, *position);
        if !argument.count break;
        if equal_nocase(argument, "-rabbit") argument = "-superfast";
        if equal_nocase(argument, "-turtle") argument = "-superslow";
        if equal_nocase(argument, "-fast") || equal_nocase(argument, "-superfast") ||
           equal_nocase(argument, "-slow") || equal_nocase(argument, "-superslow") {
            if has_speed {
                return .{}, "Choose only one speed: -fast, -superfast/-rabbit, -slow, or -superslow/-turtle.";
            }
            has_speed = true;
            if equal_nocase(argument, "-fast") default_delay_ms = SEND_FAST_DELAY;
            if equal_nocase(argument, "-slow") default_delay_ms = SEND_SLOW_DELAY;
            if equal_nocase(argument, "-superfast") {
                default_delay_ms = SEND_SUPERFAST_DELAY;
                time_mode = .FAST;
            }
            if equal_nocase(argument, "-superslow") {
                default_delay_ms = SEND_SUPERSLOW_DELAY;
                time_mode = .SLOW;
            }
            continue;
        }
        if equal_nocase(argument, "--udlr") {
            alternate = true;
            continue;
        }
        if equal_nocase(argument, "-delay") {
            if delay_ms >= 0 {
                return .{}, "Specify -delay only once.";
            }
            value := console_next_argument(commands, *position);
            error: string;
            delay_ms, error = console_parse_delay(value);
            if error.count {
                return .{}, error;
            }
            continue;
        }
        if argument[0] == #char "-" return .{}, tprint("Unknown send option: %", argument);

        // Removing options must not join a literal digit token to a preceding letter.
        if source.count array_add(*source, #char " ");
        for c: argument array_add(*source, c);
    }

    if delay_ms < 0 delay_ms = default_delay_ms;
    return .{source = copy_string(.{data = source.data, count = source.count}),
             delay_ms = delay_ms, alternate = alternate, time_mode = time_mode}, "";
}

console_queue_send :: (console: *Console_State, commands: string, alternate: bool,
                       default_delay_ms: s32 = DEFAULT_DELAY, interrupt_on_input := true) {
    request, error := console_parse_send_arguments(commands, alternate, default_delay_ms);
    defer free(request.source);
    if error.count { console_write(console, error, .ERROR); return; }
    console_queue_send_source(console, request.source, request, interrupt_on_input);
}

console_queue_send_source :: (console: *Console_State, source: string, request: Console_Send_Arguments,
                              interrupt_on_input := true) {
    expanded, error := expand_send(source, request.alternate);
    defer free(expanded);
    if error.count {
        console_write(console, error, .ERROR);
        return;
    }
    if !expanded.count {
        usage := ifx request.alternate then "Usage: send_alt [-fast|-superfast|-rabbit|-slow|-superslow|-turtle] [-delay <ms>] <moves>"
                               else "Usage: send [-fast|-superfast|-rabbit|-slow|-superslow|-turtle] [-delay <ms>] <keys>";
        console_write(console, usage, .ERROR);
        return;
    }
    if console.pending_send.count || console.pending_position_change || console.pending_freecam_change ||
       console.pending_action == .FREECAM || console.pending_action == .SET_POSITION ||
       console.pending_action == .BACK_POSITION || console.pending_action == .SWITCH_LEVEL {
        console_write(console, "A send command is already waiting to run.", .ERROR);
        return;
    }

    // The input buffer is cleared after dispatch. The main loop owns this queued copy.
    console.pending_send = copy_string(expanded);
    console.pending_reset = false;
    console.pending_send_hold_ms = send_hold_for_delay(request.delay_ms);
    console.pending_send_interval_ms = request.delay_ms - console.pending_send_hold_ms;
    console.pending_send_time_mode = request.time_mode;
    console.pending_send_interruptible = interrupt_on_input;
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
    lines := string.[
       "Available Console Commands:",
       "",
tprint("send <keys>              Send literal keys; R stays R. Default: % ms.", DEFAULT_DELAY),
       "                         Example: send w3 2 dd",
       "send_alt <moves>         Map U/D/L/R to W/S/A/D; C sends C.",
       "                         Example: send_alt R3U2C -rabbit",
       "play, do [name]          Play saved input; omitted name uses the current level.",
       "                         Example: play -rabbit  or  do mirror_1 -fast",
tprint("undo [count], z[count]   Undo moves (default: 1). % ms; -fast: % ms.", UNDO_DEFAULT_DELAY, UNDO_FAST_DELAY),
       "                         Example: undo 100 -fast  or  z100 -delay 10",
       "reset, r                 Restart the game; rewind the current timeline.",
       "edit [level_name]        Edit a solution; omitted name uses the current level.",
       "open editor              Open a temporary input; choose its name on Save.",
       "close editor             Close the editor; confirm unsaved changes.",
       "edit custom <name>       Open a saved input from data/custom_inputs.json.",
       "jump <step>, jump $      Seek the open editor to a step, or to the end.",
       "                         Forward: superfast (75 ms); backward: undo (10 ms).",
       "                         Alias: j 13, j 0, j $",
       "record                   Start recording in the open editor.",
       "pause                    Pause editor playback; keep recording armed.",
       "stop                     Stop editor playback and recording; keep the playhead.",
       "save                     Open the editor's save confirmation.",
       "                         record / pause / stop / save require an open editor.",
       "edit solution            Alias for edit (the current level).",
       "show level               Show the current level name, or Overworld.",
       "show position            Show the current controlled group's anchor (x, y, z).",
       "                         Anchor: actual character ordered by X, then Y, then Z.",
       "set position <x> <y> <z> Place the anchor at XYZ; translate its controlled group.",
       "                         Copies keep their spacing; unselected characters stay put.",
       "                         Example: set position 80 79 0",
       "move <dx> <dy> [dz]      Move all controlled characters; omitted dz keeps Z.",
       "move_xy <dx> <dy>        Teleport by X/Y offsets, keeping Z.",
       "move -x <value>          Teleport by a signed X offset.",
       "move -y <value>          Teleport by a signed Y offset.",
       "move -z <value>          Teleport by a signed Z offset.",
       "                         move -x / move -y with zero do nothing.",
       "                         Example: move -x -2  or  move -z 1",
       "mark [name] [x y z]      Save a position; omitted coordinates use the anchor.",
       "                         Omitted name uses a-z, wrapping after z and overwriting a.",
       "                         Example: mark home  or  mark 80 79 0",
       "                         Markers are saved in data/markers.json (name and position).",
       "add markers <x> <y> <z>  Save to the next a-z register, like mark x y z.",
       "list markers            List saved marker names and positions.",
       "remove markers <name>   Remove a saved position.",
       "rename <name> <new_name> Rename a marker; keep its coordinates.",
       "back, tp <name>         Place the controlled group's anchor at a saved marker.",
       "alias [name=command]    List aliases, or define a temporary alias.",
       "                         Example: alias tp=back  or  alias home=\"back a\"",
       "unalias <name>          Remove a temporary alias; restore the configured default.",
       "switch <level_name>     Teleport to an overworld entrance, then use TakeOrDrop.",
       "                         Uses User.keymap (default V). Example: switch mirror_21",
       "reset marker registers  Clear a-z and start at a; keep custom marker names.",
       "noclip [enable|disable]  Toggle, enable or disable W/S/A/D position movement.",
       "                         W/S: Y +/-1; A/D: X +/-1; one grid step per input.",
       "freecam [enable|disable] Toggle the free camera; disable restores the view.",
       "                         W/S/A/D/Q/E fly along the view; the mouse turns the view.",
       "freecam -pan             Pan with a fixed view: W/S/A/D up/down/left/right; Q/E raise/lower.",
       "                         Both modes: hold Shift to move faster or Ctrl to move slower.",
       "show subtitles [name]    Read English / Chinese dialogue for a level (default: current).",
       "                         Example: show subtitles mirror_21 -comment",
       "                         -en: centered English; -cn / -sc: centered Chinese.",
       "                         -no_character / -nosayer hides speaker names.",
       "                         -comment includes notes; wheel / Page Up / Page Down scroll.",
       "clear, cl                Clear console output; keep command history.",
       "toggle <mode>            Resize the console: full, small, normal, or mini.",
       "                         full: 100%; small: 30%; normal: 70%; mini: quick input.",
       "blow                     Clear output; cycle alien -> mirror -> wave.",
       "blow <name>              Play alien, mirror, or wave without advancing the cycle.",
       "                         Example: blow alien",
       "about                    Show the icon, author, and GitHub repository.",
       "license                  Show the LICENSE file next to the executable.",
       "help                     Show this help.",
       "q, quit                  Hide the console and return to the game.",
       "exit, terminate          Close the console. (It kills ootss-cmd.exe)",
       "ls, echo, print          Print each command's placeholder message.",
       "",
       "Options for send, send_alt, play, and do:",
       "",
       "-delay <ms>              Set the complete per-key cycle in milliseconds.",
tprint("-fast                    Use a % ms cycle.", SEND_FAST_DELAY),
tprint("-slow                    Use a % ms cycle.", SEND_SLOW_DELAY),
tprint("-superfast, -rabbit      Use % ms and hold the game's fast-time key.", SEND_SUPERFAST_DELAY),
tprint("-superslow, -turtle      Use % ms and hold the game's slow-time key.", SEND_SUPERSLOW_DELAY),
       "",
       "Choose one speed preset. -delay overrides its interval;",
       "Any player input will interrupt send, send_alt, play, and do.",
       "w3: repeats w three times;",
       "w 3 s: move up and change to character 3, then move down",
       "(ad)3 repeats a group: adadad.",
       "_ wait",
tprint("Keys are held for up to % ms; short cycles shorten the hold to leave a release gap.", DEFAULT_HOLD),
       "Command names and options are case-insensitive.",
       "",
tprint("Configuration (% relative to the executable directory; loaded at startup):", CONSOLE_CONFIG_FILE),
       "",
       "game_path=\"...\";        Game directory containing sinking_star.exe; empty uses the running game.",
       "show_startup_blow=false; Hide the startup wave; blow remains available.",
       "freecam_speed=12;        Free-camera speed in world units per second.",
       "freecam_sensitivity=0.1; Mouse look in degrees per mouse count.",
       "freecam_shift_multiplier=4;   Speed scale while holding Shift.",
       "freecam_ctrl_multiplier=0.25; Speed scale while holding Ctrl.",
       "tp=back;                Define a persistent alias with forwarded arguments.",
       "custom_command=\"back home\";  Define an alias containing arguments.",
       "nmap m=\"move -z 1\";     Run a game shortcut; pass the original key through.",
       "map <key>=\"command\";   Same passthrough behavior as nmap.",
       "noremap w=\"move -y 1\";  Run a shortcut and consume its original press/release.",
       "                         Keys: letters, digits, F1-F24, , . - / \\ [ ], Space, Enter, arrows, Home/End...",
       "                         Modifiers: Ctrl+Alt+Shift+Win (optional; exact match).",
       "                         Game focus only; one command per press. Aliases work here too.",
       "",
       "Keyboard Shortcuts:",
       "",
       ":                        Open the console from the game.",
       ";                        Open quick command input at the bottom left.",
       "Enter (quick input)     Submit and close; show subtitles opens the full console.",
       "Ctrl+C / Ctrl+D / Esc    Hide the console.",
       "Ctrl+V / Shift+Insert    Paste at the cursor.",
       "Ctrl+W / Ctrl+Delete     Delete the previous / next word.",
       "Ctrl+U                   Delete text before the cursor.",
       "Tab / Shift+Tab          Complete commands, level/marker names; cycle matches.",
       "Ctrl+Home / Ctrl+End     Subtitles: go to the beginning / end.",
       "Space                    Editor: toggle play / pause, including when bound to fast time.",
       "Esc                      Editor: pause and return input to the game.",
       "N                        Editor: toggle compact / full view.",
       "[ / ]                    Editor: undo / step.",
       "J / K / L                Editor: faster / play-pause / slower (five speed levels).",
       "                         superfast / fast / normal / slow / superslow: 75/175/250/500/750 ms.",
       "Fast-time / Slow-time    Other configured keys switch editor playback to -fast / -turtle.",
       "W/A/S/D or arrows        Editor: insert movement at the text cursor.",
       "B or _                   Editor: insert a wait cell at the text cursor.",
       "Ctrl+Left / Ctrl+Right   Editor: move the text cursor; add Shift to select.",
       "Ctrl+A                   Editor: select Executed or Future, according to the text cursor.",
       "Backspace / Delete      Editor: delete selected steps, including Executed; no game undo.",
       "Timeline link button    Toggle game input while dragging or using the wheel.",
       "                         Off: reposition the playhead only; Play resumes from there.",
       "Ctrl+S                   Editor: save the solution.",
       "Ctrl+C                   Editor: copy the complete current solution.",
       "Page Up / Page Down      Scroll console output. Mouse wheel also scrolls."
    ];
    for line: lines console_write(console, line);
    // Show the beginning of this help block, including when older output fills the scrollback.
    console.scroll_to_line = max(0, console.lines.count - lines.count);
}

command_clear :: (console: *Console_State, arguments: string) {
    console.reveal_output = false;
    console.picture = .NONE;
    console.show_subtitles = false;
    console.show_blow = false;
    console.restart_blow = false;
    for line: console.lines free(line.text);
    console.lines.count = 0;
    console.scroll = 0;
    console.scroll_to_line = -1;
}

command_blow :: (console: *Console_State, arguments: string) {
    name := trim(arguments);
    index := console.next_blow_index;
    if name.count {
        index = -1;
        for candidate: CONSOLE_BLOW_NAMES {
            if equal_nocase(name, candidate) { index = it_index; break; }
        }
        if index < 0 {
            console_write(console, "Usage: blow [alien|mirror|wave]", .ERROR);
            return;
        }
    }
    command_clear(console, "");
    console.blow_index = index;
    // Explicit choices (including the startup wave) do not consume the next automatic choice.
    if !name.count console.next_blow_index = (index + 1) % CONSOLE_BLOW_NAMES.count;
    console.show_blow = true;
    console.restart_blow = true;
    console.reveal_output = true;
}

command_about :: (console: *Console_State, arguments: string) {
    if arguments.count { console_write(console, "Usage: about", .ERROR); return; }
    console_write(console, "", .ICON);
    console_write(console, "ootss-cmd");
    console_write(console, "Author: qiekn");
    console_write(console, "Core: Powered by jai & blowave (use command: blow, try it!)");
    console_write(console, "GitHub: https://github.com/qiekn/ootss-cmd");
    console_write(console, "License: type license to view.");
    console.scroll_to_line = max(0, console.lines.count - 6);
}

command_license :: (console: *Console_State, arguments: string) {
    if arguments.count { console_write(console, "Usage: license", .ERROR); return; }
    source, success := read_entire_file("LICENSE", log_errors = false);
    if !success {
        console_write(console, "Unable to read LICENSE next to ootss-cmd.exe.", .ERROR);
        return;
    }
    defer free(source);
    lines := split(source, #char "\n");
    defer array_free(lines);
    for line: lines {
        // Retain indentation and blank lines, stripping only Windows line endings.
        text := line;
        if text.count && text[text.count - 1] == #char "\r" text = slice(text, 0, text.count - 1);
        console_write(console, text);
    }
    console.scroll_to_line = max(0, console.lines.count - lines.count);
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

command_zork :: (console: *Console_State, arguments: string) {
    if arguments.count { console_write(console, "Usage: zork", .ERROR); return; }
    console.pending_action = .ZORK_START;
}

command_captain :: (console: *Console_State, arguments: string) {
    console_show_picture(console, arguments, .CAPTAIN, "captain");
}

command_pirate :: (console: *Console_State, arguments: string) {
    console_show_picture(console, arguments, .PIRATE, "pirate");
}

command_captain_pirate :: (console: *Console_State, arguments: string) {
    console_show_picture(console, arguments, .CAPTAIN_PIRATE, "captain and pirate");
}

console_show_picture :: (console: *Console_State, arguments: string, picture: Console_Picture, name: string) {
    if arguments.count { console_write(console, tprint("Usage: %", name), .ERROR); return; }
    command_clear(console, "");
    console.picture = picture;
    console.reveal_output = true;
}

command_blow_try_it :: (console: *Console_State, arguments: string) {
    console_write(console, "Oops.. You should type `blow` instead of `blow, try it!`. We can't use magic to force blow to \"try it!\".");
}

command_hello_sailor :: (console: *Console_State, arguments: string) {
    console_write(console, "Nothing happens here.");
}

console_write :: (console: *Console_State, text: string, kind: Console_Line_Kind = .OUTPUT, wrap := false) {
    console.show_subtitles = false;
    if kind != .COMMAND {
        console.reveal_output = true;
    }
    if console.lines.count == CONSOLE_OUTPUT_LIMIT {
        free(console.lines[0].text);
        array_ordered_remove_by_index(*console.lines, 0);
    }
    array_add(*console.lines, .{copy_string(text), kind, wrap || console.zork_mode});
    console.scroll = 0;
    console.scroll_to_line = -1;
}

console_input :: (console: *Console_State) -> string {
    return .{data = console.input.data, count = console.input.count};
}

console_submit :: (console: *Console_State) {
    console_completion_reset(*console.completion);
    line := trim(console_input(console));
    if console.zork_mode {
        console_submit_zork(console, line);
        return;
    }
    if !line.count {
        console_set_input(console, "");
        return;
    }
    console_execute_command(console, line, remember = true);
    console_finish_input(console);
}

// Shared helper dispatch. Shortcuts leave the console's draft, caret, completion and history untouched.
console_execute_command :: (console: *Console_State, source: string, remember := false) {
    line := trim(source);
    if !line.count return;
    previous_blow := console.show_blow;
    previous_restart := console.restart_blow;
    previous_picture := console.picture;
    previous_subtitles := console.show_subtitles;
    previous_scroll := console.scroll;
    previous_scroll_to_line := console.scroll_to_line;
    console.show_blow = false;
    console.restart_blow = false;
    console.reveal_output = false;
    console.picture = .NONE;
    console_write(console, tprint("$ %", line), .COMMAND);
    if remember console_remember_input(console, line);

    expanded, alias_error := console_expand_aliases(console, line);
    defer free(expanded);
    if alias_error.count {
        console_write(console, alias_error, .ERROR);
        return;
    }
    line = expanded;

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
        if command.name == "toggle" && console.pending_action == .CONSOLE_MODE {
            // Resizing preserves the current presentation, including images and subtitle scroll.
            console.show_blow = previous_blow;
            console.restart_blow = previous_restart;
            console.picture = previous_picture;
            console.show_subtitles = previous_subtitles;
            console.scroll = previous_scroll;
            console.scroll_to_line = previous_scroll_to_line;
        }
        found = true;
        break;
    }
    if !found {
        split: s64;
        while split < line.count && line[split] != #char " " && line[split] != #char "\t" split += 1;
        console_write(console, tprint("Unknown command: %", slice(line, 0, split)), .ERROR);
    }
}

console_remember_input :: (console: *Console_State, line: string) {
    if !line.count return;
    if console.history.count == 64 {
        free(console.history[0]);
        array_ordered_remove_by_index(*console.history, 0);
    }
    array_add(*console.history, copy_string(line));
}

console_finish_input :: (console: *Console_State) {
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
    console_config_free(*console.config);
    console_aliases_free(*console.temporary_aliases);
    console_completion_reset(*console.completion);
    for line: console.lines free(line.text);
    for command: console.history free(command);
    free(console.draft);
    free(console.pending_send);
    free(console.pending_switch_level);
    free(console.pending_play.source);
    free(console.pending_edit_level);
    free(console.pending_subtitle_level);
    free(console.pending_zork_input);
    free(console.pending_marker_name);
    free(console.pending_marker_new_name);
    array_free(console.lines);
    array_free(console.input);
    array_free(console.history);
}

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

#scope_file
#import "Basic";
#import "File";
#import "String";
#import "Math";
Unicode :: #import "Unicode";
