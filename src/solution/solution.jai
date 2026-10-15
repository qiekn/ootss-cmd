Game_Position      :: [3] float;
SOLUTIONS_FILE     :: "data/solutions.json";
CUSTOM_INPUTS_FILE :: "data/custom_inputs.json";

Solution_Record :: struct {
    position: Game_Position; // Catalog metadata, never serialized with solutions.
    area:     string;
    name:     string;
    note:     string;
    solution: string;
}

Stored_Solution :: struct {
    name:     string;
    note:     string;
    solution: string;
}

Solutions_Database :: struct {
    entries:  [..] Solution_Record;
    imported: s64;
}

solution_position_equal :: (a: Game_Position, b: Game_Position) -> bool {
    for i: 0..2 if abs(a[i] - b[i]) > 0.01 return false;
    return true;
}

solution_find_position :: (db: *Solutions_Database, position: Game_Position) -> s64 {
    for entry: db.entries if solution_position_equal(entry.position, position) return it_index;
    return -1;
}

solution_find_name :: (db: *Solutions_Database, name: string, ignore_case := false) -> s64 {
    for entry: db.entries {
        if entry.name == name || (ignore_case && equal_nocase(entry.name, name)) return it_index;
    }
    return -1;
}

solution_name_valid :: (name: string) -> bool {
    if !name.count || name.count > 128 return false;
    for c: name {
        if c >= 128 || (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") ||
           (c >= #char "0" && c <= #char "9") || c == #char "_" || c == #char "-" || c == #char "." continue;
        return false;
    }
    return true;
}

// Parse transactionally. Old position/area fields are ignored; the catalog owns them.
// Validate key scripts only when selected, allowing unrelated unfinished records.
solutions_parse_json :: (db: *Solutions_Database, source: string, filename := SOLUTIONS_FILE) -> string {
    input := source;
    if begins_with(input, "\xef\xbb\xbf") input = slice(input, 3, input.count - 3);
    if !begins_with(trim(input), "[") return tprint("Expected a JSON array in %.", filename);
    success, records := Json.json_parse_string(input, [..] Stored_Solution);
    defer {
        for record: records {
            free(record.name);
            free(record.note);
            free(record.solution);
        }
        array_free(records);
    }
    if !success return tprint("Could not parse %. The file was left unchanged.", filename);
    next: Solutions_Database;
    defer solutions_free(*next);
    for record, index: records {
        if !solution_name_valid(record.name) return tprint("%: record % has an invalid or missing name.", filename, index + 1);
        if solution_find_name(*next, record.name, ignore_case = true) >= 0 {
            return tprint("%: duplicate solution name '%'.", filename, record.name);
        }
        array_add(*next.entries, .{name = copy_string(record.name), note = copy_string(record.note), solution = copy_string(record.solution)});
    }
    solutions_free(db);
    db.* = next;
    next = .{};
    return "";
}

solutions_load :: (db: *Solutions_Database, filename := SOLUTIONS_FILE, catalog_file := "") -> string {
    next: Solutions_Database;
    defer solutions_free(*next);
    if file_exists(filename) {
        source, success := read_entire_file(filename, log_errors = false);
        if !success return tprint("Could not read %.", filename);
        defer free(source);
        error := solutions_parse_json(*next, source, filename);
        if error.count return error;
    }
    if catalog_file.count && file_exists(catalog_file) {
        catalog: Solutions_Database;
        defer solutions_free(*catalog);
        error := level_catalog_load(*catalog, catalog_file);
        if error.count return error;
        for level: catalog.entries {
            index := solution_find_name(*next, level.name, ignore_case = true);
            if index < 0 {
                array_add(*next.entries, solution_record_copy(level));
                next.imported += 1;
            } else {
                next.entries[index].position = level.position;
                free(next.entries[index].area);
                next.entries[index].area = copy_string(level.area);
            }
        }
    }
    solutions_free(db);
    db.* = next;
    next = .{};
    return "";
}

// Caller owns the JSON. The temporary array borrows strings from db.
solutions_serialize_json :: (db: *Solutions_Database) -> (source: string, error: string) {
    records: [..] Stored_Solution;
    defer array_free(records);
    for entry, index: db.entries {
        if !solution_name_valid(entry.name) return "", "Cannot save an invalid solution name.";
        for previous: 0..index - 1 {
            if equal_nocase(db.entries[previous].name, entry.name) return "", tprint("Duplicate solution name '%'.", entry.name);
        }
        array_add(*records, .{name = entry.name, note = entry.note, solution = entry.solution});
    }
    return Json.json_write_string(records, indent_char = "  "), "";
}

solutions_write :: (db: *Solutions_Database, filename := SOLUTIONS_FILE) -> string {
    source, error := solutions_serialize_json(db);
    if error.count return error;
    defer free(source);
    temporary := tprint("%.tmp", filename);
    if !write_entire_file(temporary, source) return tprint("Could not write %.", temporary);
    if !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary, filename) {
        return tprint("Could not replace %. The previous file is intact; the new data is in %.", filename, temporary);
    }
    return "";
}

custom_inputs_load :: (db: *Solutions_Database, filename := CUSTOM_INPUTS_FILE) -> string {
    return solutions_load(db, filename);
}

solution_record_copy :: (source: Solution_Record) -> Solution_Record {
    result := source;
    result.area     = copy_string(source.area);
    result.name     = copy_string(source.name);
    result.note     = copy_string(source.note);
    result.solution = copy_string(source.solution);
    return result;
}

solution_record_free :: (entry: *Solution_Record) {
    free(entry.area);
    free(entry.name);
    free(entry.note);
    free(entry.solution);
    entry.* = .{};
}

solutions_free :: (db: *Solutions_Database) {
    for *entry: db.entries solution_record_free(entry);
    array_free(db.entries);
    db.* = .{};
}
