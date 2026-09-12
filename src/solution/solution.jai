Game_Position :: [3] float;
SOLUTIONS_FILE :: "data/solutions.json";
CUSTOM_INPUTS_FILE :: "data/custom_inputs.json";

Solution_Record :: struct {
    position: Game_Position;
    area: string;
    name: string;
    note: string;
    solution: string;
}

Solutions_Database :: struct {
    entries: [..] Solution_Record;
    imported: s64;
    prefilled: s64;
    unmatched_answers: s64;
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

solutions_load :: (db: *Solutions_Database, filename := SOLUTIONS_FILE,
                   marker_file := "data/marker.json", answer_file := "data/solutions.txt") -> string {
    solutions_free(db);
    if file_exists(filename) {
        success, records := Json.json_parse_file(filename, [..] Solution_Record);
        db.entries = records;
        if !success return tprint("Could not parse %. The file was left unchanged.", filename);
        for entry: db.entries {
            if !entry.name.count return "A saved solution is missing its name.";
            for coordinate: entry.position {
                bits := (cast(*u32) *coordinate).*;
                if (bits & 0x7f800000) == 0x7f800000 return "A saved solution has an invalid position.";
            }
        }
    }

    answers: [] string;
    answer_text: string;
    if answer_file.count && file_exists(answer_file) {
        success: bool;
        answer_text, success = read_entire_file(answer_file);
        if !success return tprint("Could not read %.", answer_file);
        answers = split(answer_text, #char "\n");
    }
    defer free(answers.data);
    defer free(answer_text);

    if marker_file.count && file_exists(marker_file) {
        success, markers := Json.json_parse_file(marker_file, Marker_Collection);
        defer markers_free(*markers);
        if !success || markers.type != "FeatureCollection" return tprint("Could not parse % as a FeatureCollection.", marker_file);
        for feature: markers.features {
            if feature.properties.type != "level" || feature.geometry.type != "Point" continue;
            if feature.geometry.coordinates.count < 2 || !feature.properties.name.count {
                return "A level marker is missing its coordinates or name.";
            }
            if solution_find_name(db, feature.properties.name) >= 0 continue;
            entry: Solution_Record;
            entry.position = .[feature.geometry.coordinates[0], feature.geometry.coordinates[1], 0];
            if solution_find_position(db, entry.position) >= 0 continue;
            entry.name = copy_string(feature.properties.name);
            entry.area = copy_string(feature.properties.area);
            for line: answers {
                colon := find_index_from_left(line, ":");
                if colon < 0 continue;
                if trim(slice(line, 0, colon)) != entry.name continue;
                source := trim(slice(line, colon + 1, line.count - colon - 1));
                keys, error := timeline_parse(source);
                free(keys);
                if error.count {
                    solution_record_free(*entry);
                    return tprint("Invalid prefilled solution for %: %", feature.properties.name, error);
                }
                entry.solution = copy_string(source);
                if source.count db.prefilled += 1;
                break;
            }
            array_add(*db.entries, entry);
            db.imported += 1;
        }
    }
    for line: answers {
        colon := find_index_from_left(line, ":");
        if colon < 0 continue;
        name := trim(slice(line, 0, colon));
        if name.count && solution_find_name(db, name) < 0 db.unmatched_answers += 1;
    }
    return "";
}

solutions_write :: (db: *Solutions_Database, filename := SOLUTIONS_FILE) -> string {
    // Write and close a sibling file first; a failed save must not truncate the user's solutions.
    temporary := tprint("%.tmp", filename);
    if !Json.json_write_file(temporary, db.entries, indent_char = "  ") return tprint("Could not write %.", temporary);
    if !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary, filename) {
        return tprint("Could not replace %. The previous file is intact; the new data is in %.", filename, temporary);
    }
    return "";
}

custom_inputs_load :: (db: *Solutions_Database, filename := CUSTOM_INPUTS_FILE) -> string {
    // Custom inputs share the record format but never import levels or match their [0, 0, 0] position.
    return solutions_load(db, filename, marker_file = "", answer_file = "");
}

solution_record_copy :: (source: Solution_Record) -> Solution_Record {
    result := source;
    result.area = copy_string(source.area);
    result.name = copy_string(source.name);
    result.note = copy_string(source.note);
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

#scope_file
#import "Basic";
#import "Math";
#import "String";
#import "File";
#import "File_Utilities";
Json :: #import "Json";

Marker_Collection :: struct {
    type: string;
    features: [..] struct {
        geometry: struct { type: string; coordinates: [..] float; };
        properties: struct { type: string; area: string; name: string; };
    };
}

markers_free :: (markers: *Marker_Collection) {
    free(markers.type);
    for *feature: markers.features {
        free(feature.geometry.type);
        array_free(feature.geometry.coordinates);
        free(feature.properties.type);
        free(feature.properties.area);
        free(feature.properties.name);
    }
    array_free(markers.features);
}
