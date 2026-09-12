SUBTITLES_MAPPING_FILE :: "data/subtitles.json";

Subtitle_Level_Mapping :: struct {
    level_name: string;
    subtitle_names: [..] string;
}

Subtitles_Mapping :: struct {
    version: s64;
    levels: [..] Subtitle_Level_Mapping;
}

subtitles_mapping_find_level :: (mapping: *Subtitles_Mapping, name: string) -> *Subtitle_Level_Mapping {
    for *level: mapping.levels if equal_nocase(level.level_name, name) return level;
    return null;
}

subtitles_mapping_contains :: (level: *Subtitle_Level_Mapping, name: string) -> bool {
    for subtitle: level.subtitle_names if equal_nocase(subtitle, name) return true;
    return false;
}

subtitles_mapping_has_subtitle :: (mapping: *Subtitles_Mapping, name: string) -> bool {
    for *level: mapping.levels if subtitles_mapping_contains(level, name) return true;
    return false;
}

subtitles_mapping_load :: (mapping: *Subtitles_Mapping, filename := SUBTITLES_MAPPING_FILE) -> string {
    source, ok := read_entire_file(filename, log_errors = false);
    defer free(source);
    if !ok return tprint("Could not read %. Generate it with scripts/generate_subtitles.jai.", filename);
    return subtitles_mapping_parse(mapping, source, filename);
}

subtitles_mapping_parse :: (mapping: *Subtitles_Mapping, source: string, filename := SUBTITLES_MAPPING_FILE) -> string {
    success, next := Json.json_parse_string(source, Subtitles_Mapping);
    defer subtitles_mapping_free(*next);
    if !success return tprint("Could not parse subtitle mapping %.", filename);
    if next.version != 1 return tprint("Unsupported subtitle mapping version in % (expected 1).", filename);
    if !next.levels.count return tprint("No levels found in subtitle mapping %.", filename);
    for level: next.levels {
        if !subtitles_mapping_valid_name(level.level_name) return tprint("Invalid subtitle level name in %.", filename);
        for previous: 0..it_index-1 {
            if equal_nocase(next.levels[previous].level_name, level.level_name) {
                return tprint("Duplicate subtitle level % in %.", level.level_name, filename);
            }
        }
        for name: level.subtitle_names {
            if !subtitles_mapping_valid_name(name) return tprint("Invalid subtitle ID for % in %.", level.level_name, filename);
            for previous: 0..it_index-1 {
                if equal_nocase(level.subtitle_names[previous], name) {
                    return tprint("Duplicate subtitle ID % for % in %.", name, level.level_name, filename);
                }
            }
        }
    }
    subtitles_mapping_free(mapping);
    mapping.* = next;
    next = .{};
    return "";
}

subtitles_mapping_free :: (mapping: *Subtitles_Mapping) {
    for *level: mapping.levels {
        free(level.level_name);
        for name: level.subtitle_names free(name);
        array_free(level.subtitle_names);
    }
    array_free(mapping.levels);
    mapping.* = .{};
}

#scope_file
#import "Basic";
#import "File";
#import "String";
Json :: #import "Json";

subtitles_mapping_valid_name :: (name: string) -> bool {
    if !name.count return false;
    for c: name if c <= 32 || c == 127 return false;
    return true;
}
