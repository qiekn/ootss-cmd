#!/usr/bin/env jai

#run {
    set_build_options_dc(.{do_output = false});
    error := run(get_build_options().compile_time_command_line);
    if error.count compiler_report(error);
}

run :: (arguments: [] string) -> string {
    if !set_working_directory(tprint("%/..", #filepath)) return "Could not select the project directory.";
    pool: Pool;
    set_allocators(*pool);
    defer release(*pool);
    previous_allocator := context.allocator;
    context.allocator = .{pool_allocator_proc, *pool};
    defer context.allocator = previous_allocator;
    input: string;
    output    := tprint("%/../data/level_catelog.json", #filepath);
    check     := false;
    self_test := false;
    for i: 0..arguments.count - 1 {
        arg := arguments[i];
        if arg == "--help" || arg == "-h" {
            print("Usage: jai -quiet scripts/generate_level_catalog.jai - <levels.package> [-o <json>] [--check] [--self-test]\n");
            return "";
        }
        if arg == "--self-test" { self_test = true; continue; }
        if arg == "--check" { check = true; continue; }
        if arg == "-o" {
            i += 1;
            if i >= arguments.count || !arguments[i].count || begins_with(arguments[i], "-") return "-o requires a filename.";
            output = arguments[i];
            continue;
        }
        if begins_with(arg, "-") return tprint("Unknown option: %", arg);
        if input.count return "Expected one levels.package filename.";
        input = arg;
    }
    if self_test {
        check_catalog();
        print("Level catalog boundary checks passed.\n");
        if !input.count && !check return "";
    }
    if !input.count return "Expected levels.package filename; use --help for usage.";
    input_path, input_ok   := get_absolute_path(input);
    output_path, output_ok := get_absolute_path(output);
    if !input_ok || !output_ok return "Could not resolve input/output paths.";
    if equal_nocase(input_path, output_path) return "Output must not replace the input package.";
    data, ok := read_entire_file(input, log_errors = false);
    if !ok return tprint("Could not read %.", input);
    catalog, error := generate_level_catalog(data);
    if error.count return error;
    source := serialize_level_catalog(catalog);
    error = check_catalog_round_trip(catalog, source);
    if error.count return error;
    previous, exists := read_entire_file(output, log_errors = false);
    if check {
        if !exists || previous != source return tprint("% is missing or outdated.", output);
    } else if !exists || previous != source {
        error = write_mapping(output, source);
        if error.count return error;
    }
    print("% %: % entrance records with name, region, position and entity_id.\n",
          ifx check then "Verified" else "Generated", output, catalog.levels.count);
    return "";
}


// ----------------------------------------------------------------------------: Catalog

// Offline catalog: all strings and arrays are allocated in the generation Pool.
Level_Entrance :: struct {
    entity_id: u32;
    position:  [3] float64;
}

Catalog_Resource :: struct {
    name:      string;
    areas:     [..] string;
    available: bool;
    entrances: [..] Level_Entrance;
}

Catalog_Resources :: struct {
    levels: [..] Catalog_Resource;
}

Catalog_Level :: struct {
    name:      string;
    region:    string;
    position:  [3] float64;
    entity_id: u32;
}

Level_Catalog :: struct {
    source: struct {
        package: string = "levels.package";
        sha256:  string;
        scene:   string = "overworld";
    };
    levels: [..] Catalog_Level;
}

catalog_name_valid :: (name: string) -> bool {
    if !name.count || name.count > 128 || name == "." || name == ".." return false;
    for byte: name {
        if (byte >= #char "a" && byte <= #char "z") || (byte >= #char "A" && byte <= #char "Z") ||
           (byte >= #char "0" && byte <= #char "9") || byte == #char "_" || byte == #char "-" || byte == #char "." continue;
        return false;
    }
    return true;
}

catalog_level :: (catalog: *Catalog_Resources, name: string) -> *Catalog_Resource {
    for *level: catalog.levels if equal_nocase(level.name, name) return level;
    level := array_add(*catalog.levels);
    level.name = name;
    return level;
}

catalog_add_set :: (catalog: *Catalog_Resources, source: string, area: string) -> string {
    if !valid_utf8(source) return "Invalid UTF-8 in level set.";
    text := source;
    if begins_with(text, "\xef\xbb\xbf") text = advance(text, 3);
    header := false;
    line_number: s64;
    for raw_line: split(text, #char "\n") {
        line_number += 1;
        line    := raw_line;
        comment := find_index_from_left(line, "#");
        if comment >= 0 line = slice(line, 0, comment);
        line = trim(line);
        if !line.count continue;
        if !header {
            if line != "[1]" return tprint("Line %: expected level-set version [1].", line_number);
            header = true;
            continue;
        }
        if line[0] == #char "*" continue; // Choice/glyph directives are not level names.
        if !catalog_name_valid(line) return tprint("Line %: invalid level name '%'.", line_number, line);
        level := catalog_level(catalog, line);
        if begins_with_nocase(area, "draft_") || begins_with_nocase(area, "drafts_") || equal_nocase(area, "design_illustrations") continue;
        found := false;
        for previous: level.areas if equal_nocase(previous, area) { found = true; break; }
        if !found array_add(*level.areas, area);
    }
    if !header return "Empty level set.";
    return "";
}

// Parse member boundaries, never search arbitrary payload bytes for a field tag.
// Supported Entity v25 / Level_Entry v25 layout is documented in level-catelog.md.
parse_level_entrance :: (diff: string) -> string, Level_Entrance, string {
    entrance: Level_Entrance;
    cursor:   u64;
    size := cast(u64) diff.count;
    previous: s64 = -1;
    while cursor < size {
        if size - cursor < 2 return "", entrance, "Truncated member index.";
        member := read_le(diff, cursor, 2);
        cursor += 2;
        if cast(s64) member <= previous return "", entrance, "Unordered or duplicate member index.";
        previous = cast(s64) member;
        if member == 0xb || member == 0x1f || member == 0x1000 {
            // Strings store old length + old bytes, then new length + new bytes.
            for value_index: 0..1 {
                if size - cursor < 8 return "", entrance, "Truncated string length.";
                length := read_le(diff, cursor, 8);
                cursor += 8;
                if length > size - cursor return "", entrance, "String exceeds entity record.";
                value := slice(diff, cast(s64) cursor, cast(s64) length);
                cursor += length;
                if member == 0x1000 && value_index == 1 {
                    if !catalog_name_valid(value) return "", entrance, "Invalid Level_Entry target name.";
                    if cursor >= size || diff[cast(s64) cursor] != 0xfd return "", entrance, "Missing target member delimiter.";
                    return value, entrance, "";
                }
            }
        } else if member == 0x20 {
            // The base mesh-material override array has an empty default and u64 entries.
            if size - cursor < 16 || read_le(diff, cursor, 8) != 0 return "", entrance, "Unsupported material array default.";
            count := read_le(diff, cursor + 8, 8);
            cursor += 16;
            if count > (size - cursor) / 8 return "", entrance, "Material array exceeds entity record.";
            cursor += count * 8;
        } else {
            width: u64;
            if member <= 9 || (member >= 0xc && member <= 0x1e) || (member >= 0x21 && member <= 0x23) width = 8;
            else if member == 0xa width = 16;
            else return "", entrance, tprint("Unsupported base member 0x%.", formatInt(member, base=16));
            if size - cursor < width return "", entrance, "Truncated base member value.";
            if member <= 2 || (member >= 0x21 && member <= 0x23) {
                if read_le(diff, cursor, 4) != 0 return "", entrance, "Unsupported coordinate default.";
                bits := cast(u32) read_le(diff, cursor + 4, 4);
                value: float32;
                memcpy(*value, *bits, 4);
                if !is_finite(value) || abs(value) > 1000000 return "", entrance, "Invalid entrance coordinate.";
                if member <= 2 entrance.position[cast(s64) member] = cast(float64) value;
                else if entrance.position[cast(s64) member - 0x21] != cast(float64) value {
                    return "", entrance, "Entrance position copies disagree.";
                }
            }
            cursor += width;
        }
        if cursor >= size || diff[cast(s64) cursor] != 0xfd return "", entrance, "Missing member delimiter.";
        cursor += 1;
    }
    return "", entrance, "Missing Level_Entry target name.";
}

generate_level_catalog :: (data: string) -> Level_Catalog, string {
    catalog:   Level_Catalog;
    resources: Catalog_Resources;
    package, error := parse_package(data);
    if error.count return catalog, error;
    overworld: string;
    for entry: package.entries {
        path := replace(entry.name, "\\", "/");
        file := path_filename(path);
        if ends_with_nocase(file, ".entities") {
            name := slice(file, 0, file.count - 9);
            if !catalog_name_valid(name) return catalog, tprint("Invalid resource name: %", file);
            level := catalog_level(*resources, name);
            if level.available return catalog, tprint("Duplicate level resource: %", name);
            level.name      = name;
            level.available = true;
            if equal_nocase(name, "overworld") overworld = slice(data, cast(s64) entry.offset, cast(s64) entry.size);
        }
        if ends_with_nocase(file, ".level_set") {
            area := slice(file, 0, file.count - 10);
            if !catalog_name_valid(area) return catalog, tprint("Invalid level set name: %", file);
            error = catalog_add_set(*resources, slice(data, cast(s64) entry.offset, cast(s64) entry.size), area);
            if error.count return catalog, tprint("%: %", entry.name, error);
        }
    }
    if !overworld.count return catalog, "Missing overworld.entities.";
    entities, entity_error := parse_entities(overworld);
    if entity_error.count return catalog, entity_error;
    if read_le(overworld, 6, 8) != 25 return catalog, "Unsupported Entity base version (expected 25).";
    count: s64;
    for record: entities.records {
        type := entities.types[record.type_index];
        if type.name != "Level_Entry" continue;
        if type.version != 25 return catalog, "Unsupported Level_Entry version (expected 25).";
        name, entrance, entry_error := parse_level_entrance(record.diff);
        if entry_error.count return catalog, tprint("Level_Entry %: %", record.id, entry_error);
        entrance.entity_id = record.id;
        for existing: resources.levels {
            for previous: existing.entrances {
                if previous.entity_id == record.id return catalog, tprint("Duplicate entrance entity ID: %", record.id);
            }
        }
        level := catalog_level(*resources, name);
        array_add(*level.entrances, entrance);
        count += 1;
    }
    if !count return catalog, "No Level_Entry records found.";
    // Filter after parsing so excluded records still receive full validation.
    for resource: resources.levels {
        if !resource.available || begins_with_nocase(resource.name, "menu_") || !resource.entrances.count continue;
        if resource.areas.count != 1 return catalog, tprint("Expected one region for %, found %.", resource.name, resource.areas.count);
        for entrance: resource.entrances {
            array_add(*catalog.levels, .{name = resource.name, region = resource.areas[0], position = entrance.position, entity_id = entrance.entity_id});
        }
    }
    quick_sort(catalog.levels, (a: Catalog_Level, b: Catalog_Level) -> s64 {
        order := compare(casefold(a.name), casefold(b.name));
        if order return order;
        return cast(s64) a.entity_id - cast(s64) b.entity_id;
    });
    catalog.source.sha256, error = sha256(data);
    return catalog, error;
}

serialize_level_catalog :: (catalog: Level_Catalog) -> string {
    builder: String_Builder;
    defer free_buffers(*builder);
    print_to_builder(*builder, "{\n  \"source\": %,\n  \"levels\": [",
                     replace(Json.json_write_string(catalog.source, indent_char = "  "), "\n", "\n  "));
    for level, index: catalog.levels {
        if index append(*builder, ",");
        print_to_builder(*builder, "\n    {\n      \"name\": %,\n      \"region\": %,\n      \"position\": [",
                         Json.json_write_string(level.name), Json.json_write_string(level.region));
        for coordinate, k: level.position {
            if k append(*builder, ", ");
            // Plain integers stay readable; fractional values must round-trip exactly.
            if coordinate == cast(float64) cast(s64) coordinate print_to_builder(*builder, "%", cast(s64) coordinate);
            else print_to_builder(*builder, "%", formatFloat(coordinate, trailing_width = 17, mode = .SCIENTIFIC, zero_removal = .NO));
        }
        print_to_builder(*builder, "],\n      \"entity_id\": %\n    }", level.entity_id);
    }
    append(*builder, "\n  ]\n}\n");
    return builder_to_string(*builder);
}


// ----------------------------------------------------------------------------: Entity records

// Views borrow the package buffer; arrays belong to the caller's allocator.
Entity_Type :: struct {
    name:    string;
    version: u64;
}

Entity_Record :: struct {
    id:         u32;
    type_index: u16;
    diff:       string;
}

Entity_File :: struct {
    types:   [..] Entity_Type;
    records: [..] Entity_Record;
}

parse_entities :: (data: string) -> Entity_File, string {
    result: Entity_File;
    if data.count < 26 || slice(data, 0, 4) != "enty" || read_le(data, 4, 2) != 7 {
        return result, "Expected an enty version 7 entity file.";
    }
    type_count := read_le(data, 14, 8);
    cursor: u64 = 22;
    size := cast(u64) data.count;
    if !type_count || type_count > 65536 || type_count > (size - cursor - 4) / 17 {
        return result, "Invalid entity type count.";
    }
    for 0..cast(s64) type_count - 1 {
        if size - cursor < 8 return result, "Truncated entity type.";
        length := read_le(data, cursor, 8);
        cursor += 8;
        if !length || length > 256 || size - cursor < 8 || length > size - cursor - 8 {
            return result, "Invalid entity type name length.";
        }
        name := slice(data, cast(s64) cursor, cast(s64) length);
        cursor += length;
        if !valid_utf8(name) || contains(name, cast(u8) 0) return result, "Invalid entity type name.";
        version := read_le(data, cursor, 8);
        cursor += 8;
        array_add(*result.types, .{name = name, version = version});
    }
    if size - cursor < 4 return result, "Missing entity record count.";
    count := read_le(data, cursor, 4);
    cursor += 4;
    if count > (size - cursor) / 10 return result, "Invalid entity record count.";
    for 0..cast(s64) count - 1 {
        if size - cursor < 10 return result, "Truncated entity record.";
        record: Entity_Record;
        record.id         = cast(u32) read_le(data, cursor, 4);
        record.type_index = cast(u16) read_le(data, cursor + 4, 2);
        length := read_le(data, cursor + 6, 4);
        cursor += 10;
        if record.type_index >= result.types.count || length > size - cursor {
            return result, "Invalid entity record type or size.";
        }
        record.diff = slice(data, cast(s64) cursor, cast(s64) length);
        cursor += length;
        array_add(*result.records, record);
    }
    if cursor != size return result, "Unexpected bytes after entity records.";
    return result, "";
}


// ----------------------------------------------------------------------------: Package I/O

// Shared, validated package I/O lives here so offline generators use one reader.
Package_Entry :: struct {
    name:   string;
    key:    string;
    size:   u64;
    offset: u64;
    order:  s64;
}

Package :: struct {
    data:    string;
    entries: [..] Package_Entry;
}


parse_package :: (data: string) -> Package, string {
    package: Package = .{data = data};
    if data.count < 64 return package, "Truncated package header.";
    if slice(data, 0, 4) != "simp" || read_le(data, 4, 4) != 1 || read_le(data, 8, 4) != 0 {
        return package, "Unsupported package header (expected Simple_Package v1 with flags = 0).";
    }
    size := cast(u64) data.count;
    toc  := read_le(data, 16, 8);
    if toc < 64 || toc > size - 64 return package, "Package table of contents is out of bounds.";
    if slice(data, cast(s64) toc, 4) != "toc!" return package, "Missing package toc! signature.";
    count  := read_le(data, toc + 8, 8);
    cursor := toc + 64;
    if count > (size - cursor) / 21 return package, "Invalid package entry count.";

    for 0..cast(s64) count - 1 {
        if size - cursor < 4 return package, "Truncated package entry.";
        length := read_le(data, cursor, 4);
        cursor += 4;
        if !length || length + 17 > size - cursor return package, "Invalid package entry name length.";
        name := slice(data, cast(s64) cursor, cast(s64) length);
        cursor += length;
        if contains(name, cast(u8) 0) || data[cast(s64) cursor] != 0 {
            return package, "Invalid package entry name terminator.";
        }
        if !valid_utf8(name) return package, "Invalid UTF-8 in package entry name.";
        cursor += 1;
        entry: Package_Entry = .{name = name, key = casefold(name), order = it};
        entry.size   = read_le(data, cursor, 8);
        entry.offset = read_le(data, cursor + 8, 8);
        cursor += 16;
        if entry.offset < 64 || entry.offset > toc || entry.size > toc - entry.offset {
            return package, tprint("Package entry is out of bounds: %", name);
        }
        for previous: package.entries {
            if previous.key == entry.key return package, tprint("Duplicate package entry name: %", name);
        }
        array_add(*package.entries, entry);
    }
    if cursor != size return package, "Unexpected bytes after package table of contents.";

    ordered: [..] Package_Entry;
    for entry: package.entries array_add(*ordered, entry);
    quick_sort(ordered, compare_package_entries);
    previous_end: u64 = 64;
    for entry: ordered {
        if entry.offset < previous_end return package, tprint("Overlapping package entry: %", entry.name);
        previous_end = entry.offset + entry.size;
    }
    return package, "";
}


write_mapping :: (path: string, source: string,
                  replace_file := atomic_file_replace_or_just_rename_if_destination_file_does_not_exist) -> string {
    directory := path_strip_filename(path);
    if !directory.count directory = ".";
    if !make_directory_if_it_does_not_exist(directory, recursive = true) return tprint("Could not create output directory %.", directory);
    temporary: string;
    file:      File;
    // CREATE_NEW reserves a sibling without truncating a concurrent writer's temporary file.
    for attempt: 0..999 {
        candidate := tprint("%.%.%.tmp", path, Win.GetCurrentProcessId(), attempt);
        handle    := Win.CreateFileW(utf8_to_wide(candidate,, temp), Win.GENERIC_WRITE, 0, null, Win.CREATE_NEW);
        if handle != Win.INVALID_HANDLE_VALUE {
            temporary   = candidate;
            file.handle = handle;
            break;
        }
        code := Win.GetLastError();
        if code != 80 && code != Win.ERROR_ALREADY_EXISTS { // ERROR_FILE_EXISTS is absent from Jai's bindings.
            return tprint("Could not create temporary output for % (Windows error %).", path, code);
        }
    }
    if !temporary.count return tprint("Could not reserve temporary output for %.", path);
    defer file_delete(temporary);
    {
        defer file_close(*file);
        if !file_write(*file, source) || !file_flush(file) return tprint("Could not write and flush %.", temporary);
    }
    if !replace_file(temporary, path) return tprint("Could not replace %.", path);
    return "";
}


read_le :: (data: string, offset: u64, count: s64) -> u64 {
    result: u64;
    for 0..count - 1 result |= (cast(u64) data[cast(s64) offset + it]) << (8 * it);
    return result;
}

sha256 :: (source: string) -> string, string {
    provider: *void;
    if BCryptOpenAlgorithmProvider(*provider, utf8_to_wide("SHA256",, temp), null, 0) < 0 {
        return "", "Could not open the Windows SHA-256 provider.";
    }
    defer BCryptCloseAlgorithmProvider(provider, 0);
    hash: *void;
    if BCryptCreateHash(provider, *hash, null, 0, null, 0, 0) < 0 return "", "Could not create a SHA-256 hash.";
    defer BCryptDestroyHash(hash);
    offset: s64;
    while offset < source.count {
        count := cast(u32) min(source.count - offset, 1024 * 1024);
        if BCryptHashData(hash, source.data + offset, count, 0) < 0 return "", "Could not hash input data.";
        offset += count;
    }
    digest: [32] u8;
    if BCryptFinishHash(hash, digest.data, 32, 0) < 0 return "", "Could not finish SHA-256.";
    hex    := alloc_string(64);
    digits := "0123456789abcdef";
    for byte, i: digest {
        hex[i * 2] = digits[byte >> 4];
        hex[i * 2 + 1] = digits[byte & 15];
    }
    return hex, "";
}


compare_package_entries :: (a: Package_Entry, b: Package_Entry) -> s64 {
    if a.offset == b.offset return a.order - b.order;
    return ifx a.offset < b.offset then -1 else 1;
}


valid_utf8 :: (source: string) -> bool {
    position: s64;
    while position < source.count {
        byte := source[position];
        if byte >= 0x80 && (byte < 0xc2 || byte > 0xf4) return false;
        code, count, result := character_utf8_to_utf32(source.data + position, source.count - position, true);
        if result != .CONVERSION_OK return false;
        position += count;
    }
    return true;
}


casefold :: (source: string) -> string {
    ascii := true;
    for byte: source if byte >= 128 { ascii = false; break; }
    if ascii return to_lower_copy(source);
    // Windows' built-in ICU preserves full case folding, including expansions such as sharp S.
    wide := utf8_to_wide(source,, temp);
    count: s32;
    for:   utf8_iter source {
        if it > 0xffff count += 2;
        else count += 1;
    }
    status: s32;
    needed := u_strFoldCase(null, 0, wide, count, 0, *status);
    assert(status == 15 || status <= 0, "ICU case-fold sizing failed: %", status);
    status = 0;
    folded := NewArray(needed + 1, u16);
    length := u_strFoldCase(folded.data, cast(s32) folded.count, wide, count, 0, *status);
    assert(status <= 0, "ICU case folding failed: %", status);
    return wide_to_utf8(folded.data, length);
}


bcrypt                       :: #system_library "bcrypt";
BCryptOpenAlgorithmProvider  :: (handle: **void, algorithm: *u16, implementation: *u16, flags: u32) -> s32 #foreign bcrypt;
BCryptCloseAlgorithmProvider :: (handle: *void, flags: u32) -> s32 #foreign bcrypt;
BCryptCreateHash             :: (provider: *void, hash: **void, object: *u8, object_size: u32, secret: *u8, secret_size: u32, flags: u32) -> s32 #foreign bcrypt;
BCryptHashData               :: (hash: *void, data: *u8, count: u32, flags: u32) -> s32 #foreign bcrypt;
BCryptFinishHash             :: (hash: *void, digest: *u8, count: u32, flags: u32) -> s32 #foreign bcrypt;
BCryptDestroyHash            :: (hash: *void) -> s32 #foreign bcrypt;

icu           :: #system_library "icu";
u_strFoldCase :: (destination: *u16, capacity: s32, source: *u16, length: s32, options: u32, status: *s32) -> s32 #foreign icu;

// ----------------------------------------------------------------------------: Checks

check_catalog_round_trip :: (catalog: Level_Catalog, source: string) -> string {
    parsed, restored := Json.json_parse_string(source, Level_Catalog, ignore_unknown = false);
    if !parsed || restored.levels.count != catalog.levels.count return "Could not verify serialized level catalog.";
    for level, i: catalog.levels {
        other := restored.levels[i];
        if level.name != other.name || level.region != other.region || level.entity_id != other.entity_id {
            return "Serialized level catalog changed an entrance.";
        }
        for coordinate, k: level.position {
            if coordinate != other.position[k] return tprint("Serialized coordinate lost precision for %.", level.name);
        }
    }
    return "";
}

check_catalog :: () {
    catalog: Catalog_Resources;
    error := catalog_add_set(*catalog, "\xef\xbb\xbf[1] # version\r\r\n# hidden\n*glyphs heroes stones\nheroes1_1 # actual\n*choice\nHEROES1_1\n", "heroes1");
    assert(!error.count && catalog.levels.count == 1 && catalog.levels[0].areas.count == 1);
    error = catalog_add_set(*catalog, "[1]\nheroes1_1\n", "drafts_story");
    assert(!error.count && catalog.levels[0].areas.count == 1);
    error = catalog_add_set(*catalog, "[1]\nheroes1_1\n", "draft_test");
    assert(!error.count && catalog.levels[0].areas.count == 1);
    error = catalog_add_set(*catalog, "[1]\nheroes1_1\n", "second_area");
    assert(!error.count && catalog.levels[0].areas.count == 2);
    for text: string.["", "[2]\na", "[1]\nname with spaces", "[1]\n../bad", "[1]\n\xff"] {
        invalid: Catalog_Resources;
        assert(catalog_add_set(*invalid, text, "test").count > 0);
    }

    builder: String_Builder;
    append_coordinate(*builder, 0, -12.5);
    append_coordinate(*builder, 2, 27);
    append_coordinate(*builder, 0x21, -12.5);
    append_coordinate(*builder, 0x23, 27);
    append_target(*builder, "heroes1_1");
    diff                        := builder_to_string(*builder);
    name, entrance, parse_error := parse_level_entrance(diff);
    assert(!parse_error.count && name == "heroes1_1");
    assert(entrance.position[0] == -12.5 && entrance.position[1] == 0 && entrance.position[2] == 27);
    for length: 0..diff.count - 1 {
        n, e, failure := parse_level_entrance(slice(diff, 0, length));
        assert(failure.count > 0, "Accepted truncated diff at %", length);
    }
    for bits: u32.[0x7fc00000, 0x7f800000, 0xff800000, 0x4b800000] {
        bad := copy_string(diff);
        memcpy(bad.data + 6, *bits, 4);
        n, e, failure := parse_level_entrance(bad);
        assert(failure.count > 0);
    }
    mismatch: String_Builder;
    append_coordinate(*mismatch, 0, 1);
    append_coordinate(*mismatch, 0x21, 2);
    append_target(*mismatch, "name");
    n, e, failure := parse_level_entrance(builder_to_string(*mismatch));
    assert(failure.count > 0);
    duplicate: String_Builder;
    append_coordinate(*duplicate, 0, 1);
    append_coordinate(*duplicate, 0, 1);
    append_target(*duplicate, "name");
    n, e, failure = parse_level_entrance(builder_to_string(*duplicate));
    assert(failure.count > 0);
    // A fake field marker in a string is payload, never a coordinate or target.
    payload: String_Builder;
    put_le(*payload, 0xb, 2);
    put_le(*payload, 0, 8);
    put_le(*payload, 3, 8);
    append(*payload, "\xfd\x00\x10");
    put_le(*payload, 0xfd, 1);
    append_target(*payload, "valid");
    n, e, failure = parse_level_entrance(builder_to_string(*payload));
    assert(!failure.count && n == "valid" && e.position[0] == 0);

    entity: String_Builder;
    append(*entity, "enty");
    put_le(*entity, 7, 2);
    put_le(*entity, 25, 8);
    put_le(*entity, 1, 8);
    put_le(*entity, 11, 8);
    append(*entity, "Level_Entry");
    put_le(*entity, 25, 8);
    put_le(*entity, 1, 4);
    put_le(*entity, 42, 4);
    put_le(*entity, 0, 2);
    put_le(*entity, cast(u64) diff.count, 4);
    append(*entity, diff);
    entities             := builder_to_string(*entity);
    parsed, entity_error := parse_entities(entities);
    assert(!entity_error.count && parsed.records.count == 1 && parsed.records[0].id == 42);
    for length: 0..entities.count - 1 {
        result, truncated_error := parse_entities(slice(entities, 0, length));
        assert(truncated_error.count > 0, "Accepted truncated entity file at %", length);
    }
    bad := copy_string(entities);
    bad[4] = 8;
    result, version_error := parse_entities(bad);
    assert(version_error.count > 0);
    // Invalid packages fail before any entity parsing or output write.
    for source: string.["", "simp", entities] {
        package, package_error := parse_package(source);
        assert(package_error.count > 0);
    }
}

put_le :: (builder: *String_Builder, value: u64, width: s64) {
    for 0..width - 1 append(builder, cast(u8)((value >> (it * 8)) & 255));
}

append_coordinate :: (builder: *String_Builder, member: u64, value: float32) {
    put_le(builder, member, 2);
    put_le(builder, 0, 4);
    bits: u32;
    memcpy(*bits, *value, 4);
    put_le(builder, bits, 4);
    put_le(builder, 0xfd, 1);
}

append_target :: (builder: *String_Builder, name: string) {
    put_le(builder, 0x1000, 2);
    put_le(builder, 0, 8);
    put_le(builder, cast(u64) name.count, 8);
    append(builder, name);
    put_le(builder, 0xfd, 1);
}


#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Pool";
#import "String";
#import "Math";
#import "Sort";
#import "Unicode";
#import "Windows_Utf8";
Win  :: #import "Windows";
Json :: #import,dir "../modules/Json";
