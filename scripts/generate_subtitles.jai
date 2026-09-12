#!/usr/bin/env jai

// Run directly: jai scripts/generate_subtitles.jai - <game-data> [--check] [-o <file>]
#run {
    set_build_options_dc(.{do_output = false});
    error := run(get_build_options().compile_time_command_line);
    if error.count compiler_report(error);
}

// ----------------------------------------------------------------------------: Generator

// Validated Simple_Package v1 reader and subtitle mapping generator.
// Returned reports borrow their input buffers; allocate a generation in one Pool.

#assert OS == .WINDOWS;

Package_Entry :: struct {
    name: string;
    key: string;
    size: u64;
    offset: u64;
    order: s64;
}

Package :: struct {
    data: string;
    entries: [..] Package_Entry;
}

Subtitle_ID :: struct {
    name: string;
    key: string;
    variants: [..] string;
    used: bool;
}

Subtitle_Source :: struct {
    file: string;
    sha256: string;
}

Mapping_Source :: struct {
    package := "levels.package";
    package_sha256: string;
    subtitles: [..] Subtitle_Source;
}

Level_Mapping :: struct {
    level_name: string;
    subtitle_names: [..] string;
    key: string; @JsonIgnore
}

Mapping :: struct {
    version: s64 = 1;
    source: Mapping_Source;
    levels: [..] Level_Mapping;
    unmapped_subtitle_names: [..] string;
}

Options :: struct {
    game_data: string;
    output: string;
    check: bool;
    help: bool;
}

parse_package :: (data: string) -> Package, string {
    package: Package = .{data = data};
    if data.count < 64 return package, "Truncated package header.";
    if slice(data, 0, 4) != "simp" || read_le(data, 4, 4) != 1 || read_le(data, 8, 4) != 0 {
        return package, "Unsupported package header (expected Simple_Package v1 with flags = 0).";
    }
    size := cast(u64) data.count;
    toc := read_le(data, 16, 8);
    if toc < 64 || toc > size - 64 return package, "Package table of contents is out of bounds.";
    if slice(data, cast(s64) toc, 4) != "toc!" return package, "Missing package toc! signature.";
    count := read_le(data, toc + 8, 8);
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
        entry.size = read_le(data, cursor, 8);
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

parse_subtitle_ids :: (source: string, filename: string) -> [..] Subtitle_ID, string {
    result: [..] Subtitle_ID;
    if !valid_utf8(source) return result, tprint("Invalid UTF-8 in %.", filename);
    text := source;
    if begins_with(text, "\xef\xbb\xbf") text = advance(text, 3);
    position: s64;
    line_number: s64;
    while position < text.count {
        start := position;
        end := text.count;
        while position < text.count {
            code, bytes := character_utf8_to_utf32(text.data + position, text.count - position, true);
            position += bytes;
            if is_line_break(code) {
                end = position - bytes;
                if code == 13 && position < text.count && text[position] == 10 position += 1;
                break;
            }
        }
        line_number += 1;
        line := trim_unicode(slice(text, start, end - start));
        if !line.count || line[0] != #char ":" continue;
        cursor: s64 = 1;
        if cursor < line.count && line[cursor] == #char ":" cursor += 1;
        header_error := tprint("%:%: invalid subtitle header", filename, line_number);
        if cursor == line.count || (line[cursor] != #char " " && line[cursor] != #char "\t") {
            return result, header_error;
        }
        while cursor < line.count && (line[cursor] == #char " " || line[cursor] == #char "\t") cursor += 1;
        name := advance(line, cursor);
        if !name.count || has_whitespace(name) return result, header_error;
        key := casefold(name);
        for previous: result {
            if previous.key == key return result, tprint("%:%: duplicate subtitle ID %", filename, line_number, name);
        }
        array_add(*result, .{name = name, key = key});
    }
    if !result.count return result, tprint("No subtitle IDs found in %.", filename);
    return result, "";
}

generate_mapping :: (game_data: string) -> Mapping, string {
    report: Mapping;
    package_path := tprint("%/levels.package", game_data);
    data, ok := read_entire_file(package_path, log_errors = false);
    if !ok return report, tprint("Could not read %.", package_path);
    package, error := parse_package(data);
    if error.count return report, error;

    directory := tprint("%/strings/subtitles", game_data);
    paths: [..] string;
    if is_file(tprint("%/en.subtitles", directory)) array_add(*paths, "en.subtitles");
    for filename: string.["s-cn.subtitles", "ch.subtitles", "ch-subtitles"] {
        if is_file(tprint("%/%", directory, filename)) {
            array_add(*paths, filename);
            break;
        }
    }
    if !paths.count return report, tprint("No English or simplified Chinese subtitle files found in %.", directory);

    ids: [..] Subtitle_ID;
    for filename: paths {
        path := tprint("%/%", directory, filename);
        source, read_ok := read_entire_file(path, log_errors = false);
        if !read_ok return report, tprint("Could not read %.", path);
        parsed, parse_error := parse_subtitle_ids(source, path);
        if parse_error.count return report, parse_error;
        for id: parsed {
            index: s64 = -1;
            for existing: ids if existing.key == id.key { index = it_index; break; }
            if index < 0 {
                index = ids.count;
                array_add(*ids, id);
            }
            found := false;
            for variant: ids[index].variants if variant == id.name { found = true; break; }
            if !found array_add(*ids[index].variants, id.name);
        }
        hash, hash_error := sha256(source);
        if hash_error.count return report, hash_error;
        array_add(*report.source.subtitles, .{file = filename, sha256 = hash});
    }

    for entry: package.entries {
        path := replace(entry.name, "\\", "/");
        filename := path_filename(path);
        if !ends_with_nocase(filename, ".entities") || filename == ".entities" continue;
        name := slice(filename, 0, filename.count - 9);
        if !name.count || has_whitespace(name, reject_controls = true) {
            return report, tprint("Invalid level name in %.", entry.name);
        }
        key := casefold(name);
        for previous: report.levels {
            if previous.key == key return report, tprint("Ambiguous level name: %", name);
        }
        entity := slice(data, cast(s64) entry.offset, cast(s64) entry.size);
        if !begins_with(entity, "enty") return report, tprint("Unexpected entity header in %.", entry.name);
        Reference :: struct { index: s64; offset: s64; }
        references: [..] Reference;
        for *id: ids {
            offset: s64 = -1;
            for variant: id.variants {
                found := find_reference(entity, variant);
                if found >= 0 && (offset < 0 || found < offset) offset = found;
            }
            if offset >= 0 {
                array_add(*references, .{index = it_index, offset = offset});
                id.used = true;
            }
        }
        // This is stable file-reference order, not a playback timeline.
        quick_sort(references, (a, b) => a.offset - b.offset);
        level: Level_Mapping = .{level_name = name, key = key};
        for reference: references array_add(*level.subtitle_names, ids[reference.index].name);
        array_add(*report.levels, level);
    }
    if !report.levels.count return report, "No .entities levels found in levels.package.";
    quick_sort(report.levels, (a, b) => compare(a.key, b.key));
    quick_sort(ids, (a, b) => compare(a.key, b.key));
    for id: ids if !id.used array_add(*report.unmapped_subtitle_names, id.name);
    report.source.package_sha256, error = sha256(data);
    return report, error;
}

serialize_mapping :: (report: Mapping) -> string {
    json := Json.json_write_string(report, indent_char = "  ");
    builder: String_Builder;
    in_string := false;
    escaped := false;
    // Json pretty-prints empty arrays on multiple lines; keep the existing [] spelling.
    for i: 0..json.count - 1 {
        if in_string {
            append(*builder, json[i]);
            if escaped escaped = false;
            else if json[i] == #char "\\" escaped = true;
            else if json[i] == #char "\"" in_string = false;
            continue;
        }
        if json[i] == #char "\"" in_string = true;
        if json[i] == #char "[" {
            end := i + 1;
            while end < json.count && (json[end] == #char " " || json[end] == #char "\n") end += 1;
            if end < json.count && json[end] == #char "]" {
                append(*builder, "[]");
                i = end;
                continue;
            }
        }
        append(*builder, json[i]);
    }
    append(*builder, "\n");
    return builder_to_string(*builder);
}

write_mapping :: (path: string, source: string,
                  replace_file := atomic_file_replace_or_just_rename_if_destination_file_does_not_exist) -> string {
    directory := path_strip_filename(path);
    if !directory.count directory = ".";
    if !make_directory_if_it_does_not_exist(directory, recursive = true) return tprint("Could not create output directory %.", directory);
    temporary: string;
    file: File;
    // CREATE_NEW reserves a sibling without truncating a concurrent writer's temporary file.
    for attempt: 0..999 {
        candidate := tprint("%.%.%.tmp", path, Win.GetCurrentProcessId(), attempt);
        handle := Win.CreateFileW(utf8_to_wide(candidate,, temp), Win.GENERIC_WRITE, 0, null, Win.CREATE_NEW);
        if handle != Win.INVALID_HANDLE_VALUE {
            temporary = candidate;
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

parse_options :: (arguments: [] string) -> Options, string {
    options: Options;
    default_output, resolved := get_absolute_path(tprint("%/../data/subtitles.json", #filepath));
    if !resolved return options, "Could not resolve the default output path.";
    options.output = default_output;
    positional_only := false;
    for i: 0..arguments.count - 1 {
        arg := arguments[i];
        if !positional_only {
            if arg == "--" { positional_only = true; continue; }
            if arg == "-h" || arg == "--help" { options.help = true; return options, ""; }
            if arg == "--check" { options.check = true; continue; }
            if arg == "-o" || arg == "--output" {
                i += 1;
                if i == arguments.count || !arguments[i].count || begins_with(arguments[i], "-") {
                    return options, tprint("% requires an output filename.", arg);
                }
                options.output = arguments[i];
                continue;
            }
            if begins_with(arg, "--output=") {
                options.output = advance(arg, 9);
                if !options.output.count return options, "--output requires an output filename.";
                continue;
            }
            if begins_with(arg, "-o") && arg.count > 2 { options.output = advance(arg, 2); continue; }
            if begins_with(arg, "-") return options, tprint("Unknown option: %", arg);
        }
        if options.game_data.count return options, tprint("Unexpected argument: %", arg);
        options.game_data = arg;
    }
    if !options.game_data.count return options, "Usage: jai scripts/generate_subtitles.jai - <game-data> [-o <file>] [--check]";
    return options, "";
}

run :: (arguments: [] string, quiet := false) -> string {
    pool: Pool;
    set_allocators(*pool);
    defer release(*pool);
    previous_allocator := context.allocator;
    context.allocator = .{pool_allocator_proc, *pool};
    defer context.allocator = previous_allocator;

    options, error := parse_options(arguments);
    if error.count return error;
    if options.help {
        if !quiet write_string(HELP);
        return "";
    }
    report, generation_error := generate_mapping(options.game_data);
    if generation_error.count return generation_error;
    source := serialize_mapping(report);
    previous, exists := read_entire_file(options.output, log_errors = false);
    matches := exists && previous == source;
    if options.check {
        if !matches return tprint("% is missing or outdated; rerun without --check.", options.output);
    } else if !matches {
        error = write_mapping(options.output, source);
        if error.count return error;
    }
    mapped: s64;
    relations: s64;
    for level: report.levels {
        if level.subtitle_names.count mapped += 1;
        relations += level.subtitle_names.count;
    }
    if !quiet {
        action := ifx options.check then "Verified" else "Generated";
        print("% %: %/% levels with references, % relations, % subtitle IDs without a confirmed level.\n",
              action, options.output, mapped, report.levels.count, relations, report.unmapped_subtitle_names.count);
    }
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
    hex := alloc_string(64);
    digits := "0123456789abcdef";
    for byte, i: digest {
        hex[i * 2] = digits[byte >> 4];
        hex[i * 2 + 1] = digits[byte & 15];
    }
    return hex, "";
}

#scope_file

compare_package_entries :: (a: Package_Entry, b: Package_Entry) -> s64 {
    if a.offset == b.offset return a.order - b.order;
    return ifx a.offset < b.offset then -1 else 1;
}

#import "Basic";
#import "File";
#import "File_Utilities";
#import "Pool";
#import "Sort";
#import "String";
#import "Unicode";
#import "Windows_Utf8";
#import "Compiler";

Json :: #import,dir "../modules/Json";
Win :: #import "Windows";

HELP :: #string END
Generate data/subtitles.json from Simple_Package v1 and exact subtitle references.

Usage: jai scripts/generate_subtitles.jai - <game-data> [options]

  game-data       Game data directory containing levels.package.
  -o, --output    Output JSON (defaults to this project's data/subtitles.json).
  --check         Verify existing JSON without rewriting it.
  -h, --help      Show this help.

Reads English and simplified Chinese subtitle IDs without extracting or modifying
game files. Reference order is not a playback timeline. Runs in #run; no executable
is generated. Requires Windows 10 1703 or later (system SHA-256 and Unicode APIs).
END

is_file :: (path: string) -> bool {
    directory, ok := is_directory(path);
    return ok && !directory;
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

is_whitespace :: (code: u32) -> bool {
    return (code >= 9 && code <= 13) || (code >= 0x1c && code <= 0x20) || code == 0x85 || code == 0xa0 ||
           code == 0x1680 || (code >= 0x2000 && code <= 0x200a) || code == 0x2028 || code == 0x2029 ||
           code == 0x202f || code == 0x205f || code == 0x3000;
}

is_line_break :: (code: u32) -> bool {
    return (code >= 10 && code <= 13) || (code >= 0x1c && code <= 0x1e) ||
           code == 0x85 || code == 0x2028 || code == 0x2029;
}

has_whitespace :: (source: string, reject_controls := false) -> bool {
    for :utf8_iter source if is_whitespace(it) || (reject_controls && it < 32) return true;
    return false;
}

trim_unicode :: (source: string) -> string {
    first := source.count;
    last: s64;
    position: s64;
    while position < source.count {
        code, count := character_utf8_to_utf32(source.data + position, source.count - position, true);
        if !is_whitespace(code) {
            first = min(first, position);
            last = position + count;
        }
        position += count;
    }
    if last < first return "";
    return slice(source, first, last - first);
}

casefold :: (source: string) -> string {
    ascii := true;
    for byte: source if byte >= 128 { ascii = false; break; }
    if ascii return to_lower_copy(source);
    // Windows' built-in ICU preserves full case folding, including expansions such as sharp S.
    wide := utf8_to_wide(source,, temp);
    count: s32;
    for :utf8_iter source {
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

find_reference :: (data: string, name: string) -> s64 {
    if data.count < name.count + 8 return -1;
    cursor: s64 = 8;
    last := data.count - name.count;
    while cursor <= last {
        // Use the CRT's bounded byte search so #run does not scan every byte for every ID in the VM.
        found := memchr(data.data + cursor, name[0], cast(u64)(last - cursor + 1));
        if !found return -1;
        position := found - data.data;
        length: u64;
        memcpy(*length, found - 8, 8);
        // The supported Windows targets are little-endian; memcpy permits unaligned prefixes.
        if length == cast(u64) name.count && slice(data, position, name.count) == name return position - 8;
        cursor = position + 1;
    }
    return -1;
}

bcrypt :: #system_library "bcrypt";
BCryptOpenAlgorithmProvider :: (handle: **void, algorithm: *u16, implementation: *u16, flags: u32) -> s32 #foreign bcrypt;
BCryptCloseAlgorithmProvider :: (handle: *void, flags: u32) -> s32 #foreign bcrypt;
BCryptCreateHash :: (provider: *void, hash: **void, object: *u8, object_size: u32, secret: *u8, secret_size: u32, flags: u32) -> s32 #foreign bcrypt;
BCryptHashData :: (hash: *void, data: *u8, count: u32, flags: u32) -> s32 #foreign bcrypt;
BCryptFinishHash :: (hash: *void, digest: *u8, count: u32, flags: u32) -> s32 #foreign bcrypt;
BCryptDestroyHash :: (hash: *void) -> s32 #foreign bcrypt;

icu :: #system_library "icu";
u_strFoldCase :: (destination: *u16, capacity: s32, source: *u16, length: s32, options: u32, status: *s32) -> s32 #foreign icu;
crt :: #system_library "msvcrt";
memchr :: (data: *u8, value: s32, count: u64) -> *u8 #foreign crt;
