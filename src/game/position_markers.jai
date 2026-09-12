POSITION_MARKERS_FILE :: "data/markers.json";
LEGACY_POSITION_MARKERS_FILE :: "data/position_markers.json";
POSITION_MARKER_REGISTERS :: "abcdefghijklmnopqrstuvwxyz";

Position_Marker :: struct {
    name: string;
    // A missing position in a hand-edited JSON file must fail validation, not become (0, 0, 0).
    position: Game_Position = .[1_000_001, 1_000_001, 1_000_001];
}

Position_Markers :: struct {
    next_register: s64;
    entries: [..] Position_Marker;
}

position_marker_name_valid :: (name: string) -> bool {
    if !name.count || name.count > 128 return false;
    for c: name {
        if c >= 0x80 || (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") ||
           (c >= #char "0" && c <= #char "9") || c == #char "_" || c == #char "-" || c == #char "." continue;
        return false;
    }
    return true;
}

position_marker_is_register :: (name: string) -> bool {
    return name.count == 1 && ((name[0] >= #char "a" && name[0] <= #char "z") ||
                               (name[0] >= #char "A" && name[0] <= #char "Z"));
}

position_marker_find :: (markers: *Position_Markers, name: string) -> s64 {
    for entry: markers.entries if equal_nocase(entry.name, name) return it_index;
    return -1;
}

position_markers_free :: (markers: *Position_Markers) {
    for entry: markers.entries free(entry.name);
    array_free(markers.entries);
    markers.* = .{};
}

position_markers_validate :: (markers: *Position_Markers) -> string {
    if markers.next_register < 0 || markers.next_register >= POSITION_MARKER_REGISTERS.count {
        return "The next marker register must be between 0 (a) and 25 (z).";
    }
    for entry: markers.entries {
        if !position_marker_name_valid(entry.name) return "A position marker has an invalid or missing name.";
        if !game_position_valid(entry.position) return tprint("Marker '%' has invalid or missing coordinates.", entry.name);
        if position_marker_find(markers, entry.name) != it_index return tprint("Duplicate position marker: %.", entry.name);
    }
    return "";
}

position_markers_load :: (markers: *Position_Markers, filename := POSITION_MARKERS_FILE,
                          legacy_filename: string = "") -> string {
    position_markers_free(markers);
    source := filename;
    if !file_exists(source) {
        legacy := legacy_filename;
        if !legacy.count && filename == POSITION_MARKERS_FILE legacy = LEGACY_POSITION_MARKERS_FILE;
        if !legacy.count || !file_exists(legacy) return "";
        source = legacy;
    }
    success, loaded := Json.json_parse_file(source, Position_Markers_File);
    defer {
        for entry: loaded.entries free(entry.name);
        array_free(loaded.entries);
    }
    if !success return tprint("Could not parse %. The file was left unchanged.", source);
    markers.next_register = loaded.next_register;
    for entry: loaded.entries {
        position: Game_Position;
        for coordinate: entry.position {
            if !is_finite(coordinate) || abs(coordinate) > GAME_POSITION_LIMIT {
                return tprint("Marker '%' has invalid or missing coordinates.", entry.name);
            }
            position[it_index] = cast(float) coordinate;
        }
        array_add(*markers.entries, .{name = copy_string(entry.name), position = position});
    }
    error := position_markers_validate(markers);
    if !error.count && source != filename error = position_markers_write(markers, filename);
    return error;
}

position_markers_write :: (markers: *Position_Markers, filename := POSITION_MARKERS_FILE) -> string {
    error := position_markers_validate(markers);
    if error.count return error;
    temporary := tprint("%.tmp", filename);
    if !Json.json_write_file(temporary, markers.*, indent_char = "  ") return tprint("Could not write %.", temporary);
    if !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary, filename) {
        return tprint("Could not replace %. The previous file is intact; the new data is in %.", filename, temporary);
    }
    return "";
}

position_marker_put :: (markers: *Position_Markers, position: Game_Position, name := "") -> string {
    chosen := name;
    if !chosen.count chosen = slice(POSITION_MARKER_REGISTERS, markers.next_register, 1);
    index := position_marker_find(markers, chosen);
    if index < 0 {
        array_add(*markers.entries, .{name = copy_string(chosen), position = position});
        index = markers.entries.count - 1;
    } else markers.entries[index].position = position;
    if !name.count markers.next_register = (markers.next_register + 1) % POSITION_MARKER_REGISTERS.count;
    return markers.entries[index].name;
}

position_marker_remove :: (markers: *Position_Markers, name: string) -> string {
    index := position_marker_find(markers, name);
    if index < 0 return tprint("Unknown position marker: %.", name);
    free(markers.entries[index].name);
    array_ordered_remove_by_index(*markers.entries, index);
    return "";
}

position_marker_rename :: (markers: *Position_Markers, name: string, new_name: string) -> string {
    index := position_marker_find(markers, name);
    if index < 0 return tprint("Unknown position marker: %.", name);
    if !position_marker_name_valid(new_name) return "Marker names must use letters, digits, Unicode, _, - or . (up to 128 bytes).";
    collision := position_marker_find(markers, new_name);
    if collision >= 0 && collision != index return tprint("Position marker '%' already exists.", new_name);
    replacement := copy_string(new_name);
    free(markers.entries[index].name);
    markers.entries[index].name = replacement;
    return "";
}

position_marker_registers_reset :: (markers: *Position_Markers) {
    index: s64;
    while index < markers.entries.count {
        if position_marker_is_register(markers.entries[index].name) {
            free(markers.entries[index].name);
            array_ordered_remove_by_index(*markers.entries, index);
        } else index += 1;
    }
    markers.next_register = 0;
}

#scope_file
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Math";
Json :: #import "Json";

// Validate persisted numbers before narrowing, just like console coordinate arguments.
Position_Markers_File :: struct {
    next_register: s64;
    entries: [..] struct {
        name: string;
        position: [3] float64 = .[1_000_001, 1_000_001, 1_000_001];
    };
}
