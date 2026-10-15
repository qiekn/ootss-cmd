LEVEL_CATALOG_FILE :: "data/level-catalog.json";

// Entrances are independent of saved solutions, custom inputs and user markers.
// Replace the owned snapshot only after validating the complete file.
level_catalog_load :: (db: *Solutions_Database, filename := LEVEL_CATALOG_FILE) -> string {
    source, read_ok := read_entire_file(filename, log_errors = false);
    if !read_ok return tprint("Could not read %. Generate it with scripts/generate_level_catalog.jai.", filename);
    defer free(source);
    success, catalog := Json.json_parse_string(source, Level_Catalog_File, ignore_unknown = false,
                                               float_handling = cast(Json.Special_Float_Handling) 0);
    defer {
        free(catalog.source.package);
        free(catalog.source.sha256);
        free(catalog.source.scene);
        for level: catalog.levels {
            free(level.name);
            free(level.region);
            for coordinate: level.position Json.json_free(coordinate);
            array_free(level.position);
            Json.json_free(level.entity_id);
        }
        array_free(catalog.levels);
    }
    if !success return tprint("Could not parse % as a level catalog.", filename);
    if catalog.source.package != "levels.package" || !equal_nocase(catalog.source.scene, "overworld") ||
       catalog.source.sha256.count != 64 return "The level catalog has invalid package/scene metadata.";
    for c: catalog.source.sha256 {
        if (c < #char "0" || c > #char "9") && (c < #char "a" || c > #char "f") &&
           (c < #char "A" || c > #char "F") return "The level catalog has an invalid SHA-256.";
    }
    if !catalog.levels.count return "The level catalog contains no entrances.";
    next: Solutions_Database;
    defer solutions_free(*next);
    for level, index: catalog.levels {
        if !level_catalog_name_valid(level.name) || !level_catalog_name_valid(level.region) ||
           !game_scene_is_level(level.name) || begins_with_nocase(level.name, "menu_") {
            return "A level entrance has an invalid or missing name/region.";
        }
        if level.position.count != 3 return tprint("Entrance '%' must contain exactly three coordinates.", level.name);
        position: Game_Position;
        for coordinate, axis: level.position {
            if coordinate.type != .NUMBER || !is_finite(coordinate.number) || abs(coordinate.number) > GAME_POSITION_LIMIT {
                return tprint("Invalid entrance coordinates for %.", level.name);
            }
            position[axis] = cast(float) coordinate.number;
        }
        if level.entity_id.type != .NUMBER return "Invalid or missing entrance entity ID.";
        entity_id := level.entity_id.number;
        if !is_finite(entity_id) || entity_id < 0 || entity_id > 0xffffffff ||
           entity_id != cast(float64) cast(u32) entity_id return "Invalid entrance entity ID.";
        for previous: 0..index - 1 {
            if catalog.levels[previous].entity_id.number == entity_id return "Duplicate entrance entity ID.";
        }
        array_add(*next.entries, .{name = copy_string(level.name), area = copy_string(level.region), position = position});
    }
    solutions_free(db);
    db.* = next;
    next = .{};
    return "";
}

// A name with multiple entrances is ambiguous; never choose an arbitrary position.
level_catalog_find :: (db: *Solutions_Database, name: string) -> (index: s64, error: string) {
    found: s64 = -1;
    for level, index: db.entries {
        if !equal_nocase(level.name, name) continue;
        if found >= 0 return -1, tprint("Level '%' has multiple overworld entrances.", name);
        found = index;
    }
    if found < 0 return -1, tprint("Unknown level entrance: %.", name);
    return found, "";
}

#scope_file

level_catalog_name_valid :: (name: string) -> bool {
    if !name.count || name.count > 128 || name == "." || name == ".." return false;
    for c: name {
        if (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") ||
           (c >= #char "0" && c <= #char "9") || c == #char "_" || c == #char "-" || c == #char "." continue;
        return false;
    }
    return true;
}

// Variable-length coordinates reject missing/truncated arrays before narrowing.
Level_Catalog_File :: struct {
    source: struct {
        package: string;
        sha256:  string;
        scene:   string;
    };
    levels: [..] struct {
        name:      string;
        region:    string;
        position:  [..] Json.JSON_Value;
        entity_id: Json.JSON_Value;
    };
}
