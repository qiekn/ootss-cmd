CONSOLE_CONFIG_FILE :: "data/config.rc";
CONSOLE_ALIAS_DEPTH :: 16;

Console_Alias :: struct { name, command: string; }
Console_Config :: struct {
    show_startup_blow := true;
    game_path: string;
    freecam_speed: float64 = 12;             // World units per second.
    freecam_sensitivity: float64 = 0.1;      // Degrees of view rotation per mouse count.
    freecam_shift_multiplier: float64 = 4;   // Speed scale while Shift is held.
    freecam_ctrl_multiplier: float64 = 0.25; // Speed scale while Ctrl is held.
    aliases: [..] Console_Alias;
    shortcuts: [..] Command_Shortcut;
}

console_alias_find :: (aliases: [] Console_Alias, name: string) -> s64 {
    for alias: aliases if equal_nocase(alias.name, name) return it_index;
    return -1;
}

console_aliases_free :: (aliases: *[..] Console_Alias) {
    for alias: aliases.* { free(alias.name); free(alias.command); }
    array_free(aliases.*);
}

console_config_free :: (config: *Console_Config) {
    free(config.game_path);
    console_aliases_free(*config.aliases);
    shortcuts_free_bindings(*config.shortcuts);
    config.* = .{};
}

console_alias_name_valid :: (name: string) -> bool {
    if !name.count || name.count > 128 || equal_nocase(name, "alias") || equal_nocase(name, "unalias") return false;
    for c: name {
        if c >= 0x80 || (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") ||
           (c >= #char "0" && c <= #char "9") || c == #char "_" || c == #char "-" || c == #char "." continue;
        return false;
    }
    return true;
}

console_alias_store :: (aliases: *[..] Console_Alias, name: string, command: string) {
    index := console_alias_find(aliases.*, name);
    if index >= 0 {
        free(aliases.*[index].command);
        aliases.*[index].command = copy_string(command);
    } else array_add(aliases, .{name = copy_string(name), command = copy_string(command)});
}

console_config_value :: (input: string, allow_empty := false) -> (value: string, error: string) {
    source := trim(input);
    if !source.count return "", "Expected a nonempty value after '='.";
    quote := source[0];
    if quote != #char "\"" && quote != #char "'" {
        for c: source if c == #char ";" || c == #char "#" || c == #char "\"" || c == #char "'" {
            return "", "Quote values containing ';', '#', or quotes.";
        }
        return copy_string(source), "";
    }
    bytes: [..] u8;
    defer array_free(bytes);
    cursor: s64 = 1;
    closed := false;
    while cursor < source.count {
        c := source[cursor];
        cursor += 1;
        if c == quote { closed = true; break; }
        if c == #char "\\" && cursor < source.count && (source[cursor] == quote || source[cursor] == #char "\\") {
            c = source[cursor];
            cursor += 1;
        }
        array_add(*bytes, c);
    }
    if !closed || trim(slice(source, cursor, source.count - cursor)).count {
        return "", "Expected a closing quote at the end of the value.";
    }
    value := trim(string.{data = bytes.data, count = bytes.count});
    if !value.count && !allow_empty return "", "A configuration value cannot be empty.";
    return copy_string(value), "";
}

console_parse_assignment :: (input: string, allow_empty := false) -> (name: string, command: string, error: string) {
    source := trim(input);
    if source.count && source[source.count - 1] == #char ";" source = trim(slice(source, 0, source.count - 1));
    split: s64;
    while split < source.count && source[split] != #char "=" split += 1;
    if split == source.count return "", "", "Expected name=command (example: tp=back).";
    name := trim(slice(source, 0, split));
    if !name.count return "", "", "Expected a name before '='.";
    command, error := console_config_value(slice(source, split + 1, source.count - split - 1), allow_empty);
    if !error.count && command.count > CONSOLE_INPUT_LIMIT {
        free(command);
        return "", "", "The command exceeds the console input limit.";
    }
    return name, command, error;
}

console_parse_alias_assignment :: (input: string) -> (name: string, command: string, error: string) {
    name, command, error := console_parse_assignment(input);
    if !error.count && !console_alias_name_valid(name) {
        free(command);
        return "", "", "Invalid alias name; alias and unalias are reserved.";
    }
    return name, command, error;
}

console_config_number :: (name: string, text: string, target: *float64, maximum: float64) -> string {
    value, success, remainder := string_to_float64(text);
    if !success || remainder.count || !is_finite(value) || value <= 0 || value > maximum {
        return tprint("% must be a positive number no greater than %.", name, maximum);
    }
    target.* = value;
    return "";
}

console_config_assignment :: (config: *Console_Config, input: string) -> string {
    source := trim(input);
    if !source.count return "";
    cursor: s64;
    first := console_next_argument(source, *cursor);
    rest := trim(slice(source, cursor, source.count - cursor));
    if (equal_nocase(first, "map") || equal_nocase(first, "nmap") || equal_nocase(first, "noremap")) && rest.count && rest[0] != #char "=" {
        return shortcut_config_assignment(config, rest, consume = equal_nocase(first, "noremap"));
    }
    if equal_nocase(first, "alias") source = trim(slice(source, cursor, source.count - cursor));
    name, command, error := console_parse_assignment(source, allow_empty = true);
    defer free(command);
    if error.count return error;
    if !console_alias_name_valid(name) return "Invalid alias name; alias and unalias are reserved.";
    if equal_nocase(name, "game_path") {
        free(config.game_path);
        config.game_path = copy_string(command);
        return "";
    }
    if !command.count return "A configuration value cannot be empty.";
    if equal_nocase(name, "freecam_speed") return console_config_number("freecam_speed", command, *config.freecam_speed, 100000);
    if equal_nocase(name, "freecam_sensitivity") return console_config_number("freecam_sensitivity", command, *config.freecam_sensitivity, 100);
    if equal_nocase(name, "freecam_shift_multiplier") return console_config_number("freecam_shift_multiplier", command, *config.freecam_shift_multiplier, 1000);
    if equal_nocase(name, "freecam_ctrl_multiplier") return console_config_number("freecam_ctrl_multiplier", command, *config.freecam_ctrl_multiplier, 1000);
    if equal_nocase(name, "show_startup_blow") {
        if equal_nocase(command, "true") config.show_startup_blow = true;
        else if equal_nocase(command, "false") config.show_startup_blow = false;
        else return "show_startup_blow must be true or false.";
    } else console_alias_store(*config.aliases, name, command);
    return "";
}

console_config_parse :: (config: *Console_Config, input: string) -> string {
    source := input;
    if source.count > 65536 return "Configuration exceeds 64 KiB.";
    if source.count >= 3 && source[0] == 0xef && source[1] == 0xbb && source[2] == 0xbf source = slice(source, 3, source.count - 3);
    parsed: Console_Config;
    defer console_config_free(*parsed);
    statement: [..] u8;
    defer array_free(statement);
    quote: u8;
    escaped, comment: bool;
    line: s64 = 1;
    // Newlines and unquoted semicolons terminate assignments. Nothing is executed while loading.
    for i: 0..source.count {
        c := ifx i == source.count then #char "\n" else source[i];
        if c == #char "\n" || (!quote && !comment && c == #char ";") {
            if quote return tprint("Line %: a configuration value has an unclosed quote.", line);
            text := string.{data = statement.data, count = statement.count};
            error := console_config_assignment(*parsed, text);
            if error.count return tprint("Line %: %", line, error);
            statement.count = 0;
            if c == #char "\n" { line += 1; comment = false; }
            continue;
        }
        if comment continue;
        if quote {
            if escaped escaped = false;
            else if c == #char "\\" escaped = true;
            else if c == quote quote = 0;
        } else {
            if c == #char "#" { comment = true; continue; }
            if c == #char "\"" || c == #char "'" quote = c;
        }
        if c == 0 return tprint("Line %: unexpected NUL byte.", line);
        array_add(*statement, c);
    }
    // A malformed file must not partially replace the current configuration.
    console_config_free(config);
    config.* = parsed;
    parsed = .{};
    return "";
}

console_config_load :: (config: *Console_Config, filename := CONSOLE_CONFIG_FILE) -> string {
    if !file_exists(filename) { console_config_free(config); return ""; }
    source, okay := read_entire_file(filename);
    defer free(source);
    if !okay return tprint("Could not read %.", filename);
    error := console_config_parse(config, source);
    return ifx error.count then tprint("%: %", filename, error) else "";
}

console_startup_presentation :: (state: *Console_State) {
    if state.config.show_startup_blow command_blow(state, "wave");
}

console_alias_lookup :: (state: *Console_State, name: string) -> *Console_Alias {
    index := console_alias_find(state.temporary_aliases, name);
    if index >= 0 return *state.temporary_aliases[index];
    index = console_alias_find(state.config.aliases, name);
    if index >= 0 return *state.config.aliases[index];
    return null;
}

console_expand_aliases :: (state: *Console_State, source: string) -> (expanded: string, error: string) {
    expanded := copy_string(trim(source));
    visited: [CONSOLE_ALIAS_DEPTH] string;
    for depth: 0..visited.count {
        cursor: s64;
        name := console_next_argument(expanded, *cursor);
        alias := console_alias_lookup(state, name);
        if !alias return expanded, "";
        for previous: 0..depth-1 if equal_nocase(visited[previous], name) {
            error := tprint("Alias cycle involving '%'. No command was run.", name);
            free(expanded);
            return "", error;
        }
        if depth == visited.count {
            free(expanded);
            return "", "Alias expansion is too deep. No command was run.";
        }
        visited[depth] = alias.name;
        arguments := trim(slice(expanded, cursor, expanded.count - cursor));
        next := ifx arguments.count then tprint("% %", alias.command, arguments) else alias.command;
        if next.count > CONSOLE_INPUT_LIMIT {
            free(expanded);
            return "", "Alias expansion exceeds the console input limit. No command was run.";
        }
        next = copy_string(next);
        free(expanded);
        expanded = next;
    }
    return expanded, "";
}

command_alias :: (state: *Console_State, arguments: string) {
    if !arguments.count {
        count: s64;
        for alias: state.config.aliases {
            if console_alias_find(state.temporary_aliases, alias.name) >= 0 continue;
            console_write(state, tprint("% = % (%)", alias.name, alias.command, CONSOLE_CONFIG_FILE));
            count += 1;
        }
        for alias: state.temporary_aliases {
            console_write(state, tprint("% = % (temporary)", alias.name, alias.command));
            count += 1;
        }
        if !count console_write(state, "No configured or temporary aliases. Built-in: tp = back.");
        return;
    }
    name, command, error := console_parse_alias_assignment(arguments);
    defer free(command);
    if error.count { console_write(state, error, .ERROR); return; }
    console_alias_store(*state.temporary_aliases, name, command);
    console_write(state, tprint("Temporary alias: % = %", name, command));
}

command_unalias :: (state: *Console_State, arguments: string) {
    cursor: s64;
    name := console_next_argument(arguments, *cursor);
    if !name.count || console_next_argument(arguments, *cursor).count {
        console_write(state, "Usage: unalias <name>", .ERROR);
        return;
    }
    index := console_alias_find(state.temporary_aliases, name);
    if index < 0 { console_write(state, tprint("No temporary alias named '%'.", name), .ERROR); return; }
    alias := state.temporary_aliases[index];
    free(alias.name);
    free(alias.command);
    array_ordered_remove_by_index(*state.temporary_aliases, index);
    console_write(state, tprint("Removed temporary alias: %", name));
}

#scope_file
#import "Basic";
#import "Math";
#import "String";
#import "File";
#import "File_Utilities";
