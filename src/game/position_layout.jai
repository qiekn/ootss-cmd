Game_Position_Field :: enum { LOGICAL; VISUAL; OUTPUT; PRE_MOVE; VELOCITY; }
Game_Position_Layout :: struct { offsets: [5] u64; }
Game_Position_Target :: struct {
    player: Game_Player_Location;
    layout: Game_Position_Layout;
    before, destination: Game_Position;
}
Game_Struct_Member :: struct {
    name_count, name_data, type: u64;
    offset: s64;
    flags, padding: u32;
    notes_count, notes_data: u64;
    constant_offset: s64;
}
#assert(size_of(Game_Struct_Member) == 64);

game_metadata_name_matches :: (memory: Process_Memory, count: u64, data: u64, name: string) -> bool {
    if count != cast(u64) name.count || count > 128 || !process_module_contains(memory.module, data, count) return false;
    bytes: [128] u8;
    if !process_read_memory(memory.handle, data, *bytes, count) return false;
    for byte: name if bytes[it_index] != byte return false;
    return true;
}

// Member names and types come from the game's own Jai reflection data. Historical
// offsets are evidence in the memory skill, never an unverified teleport fallback.
game_position_member :: (memory: Process_Memory, owner: u64, name: string, child_name: string,
                         kind: u32 = 7, size: u32 = 0) -> (member: Game_Struct_Member, error: string) {
    missing := tprint("This game version's position field '%' could not be verified.", name);
    info: Game_Entity_Type;
    members: Game_Entity_List;
    if !process_module_contains(memory.module, owner, 0x50) ||
       !process_read_memory(memory.handle, owner, *info, size_of(Game_Entity_Type)) || info.kind != 7 ||
       !process_read_memory(memory.handle, owner + 0x40, *members, size_of(Game_Entity_List)) ||
       !members.count || members.count > 256 ||
       !process_module_contains(memory.module, members.data, members.count * size_of(Game_Struct_Member)) return .{}, missing;
    found: Game_Struct_Member;
    matches: s64;
    for i: 0..cast(s64) members.count-1 {
        candidate: Game_Struct_Member;
        if !process_read_memory(memory.handle, members.data + cast(u64) i * size_of(Game_Struct_Member),
                                 *candidate, size_of(Game_Struct_Member)) return .{}, missing;
        if !game_metadata_name_matches(memory, candidate.name_count, candidate.name_data, name) continue;
        if candidate.flags & 1 || candidate.offset < 0 || cast(u64) candidate.offset >= info.size return .{}, missing;
        child: Game_Entity_Type;
        if !process_module_contains(memory.module, candidate.type, size_of(Game_Entity_Type)) ||
           !process_read_memory(memory.handle, candidate.type, *child, size_of(Game_Entity_Type)) ||
           child.kind != kind || (size && child.size != size) ||
           cast(u64) candidate.offset + child.size > info.size return .{}, missing;
        if child_name.count && !game_metadata_name_matches(memory, child.name_length, child.name_data, child_name) return .{}, missing;
        matches += 1;
        found = candidate;
    }
    if matches != 1 return .{}, missing;
    return found, "";
}

game_position_layout :: (memory: Process_Memory, player: Game_Player_Location) -> (layout: Game_Position_Layout, error: string) {
    layout: Game_Position_Layout;
    guy: u64;
    if !process_read_memory(memory.handle, player.entity + 0x108, *guy, 8) return layout, "Could not read the player's type.";
    entity, error := game_position_member(memory, guy, "entity", "Entity");
    if error.count return layout, error;
    undo, undo_error := game_position_member(memory, entity.type, "undoable_data", "Undoable_Entity_Data");
    if undo_error.count return layout, undo_error;
    names := string.["position", "visual_position", "output_position", "pre_move_position", "velocity"];
    vector_type: u64;
    for name: names {
        owner := ifx it_index < 2 then undo.type else ifx it_index == 2 then entity.type else guy;
        base := ifx it_index < 2 then entity.offset + undo.offset else ifx it_index == 2 then entity.offset else 0;
        member, field_error := game_position_member(memory, owner, name, "Vector3", size = 12);
        if field_error.count return layout, field_error;
        if it_index == 0 {
            vector_type = member.type;
            for axis: string.["x", "y", "z"] {
                scalar, scalar_error := game_position_member(memory, member.type, axis, "", kind = 1, size = 4);
                if scalar_error.count return layout, scalar_error;
                if scalar.offset != it_index * 4 return layout, "The game's Vector3 layout is unsupported.";
            }
        } else if member.type != vector_type return layout, "The game's position fields use incompatible Vector3 types.";
        layout.offsets[it_index] = cast(u64)(base + member.offset);
    }
    if layout.offsets[0] != 0 return layout, "The game's logical position layout is unsupported.";
    for offset: layout.offsets {
        if !process_memory_range_valid(player.entity + offset, 12) return layout, "The game's position field is out of range.";
        // The same offsets used to identify the player must never be write targets.
        for reserved: u64.[0xf0, 0x100, 0x108] {
            bytes := cast(u64)(ifx reserved == 0x100 then 4 else 8);
            if offset < reserved + bytes && reserved < offset + 12 return layout, "A position field overlaps player identity data.";
        }
        for other: 0..it_index-1 if offset < layout.offsets[other] + 12 && layout.offsets[other] < offset + 12 {
            return layout, "The game's position fields overlap unexpectedly.";
        }
    }
    return layout, "";
}

game_player_scene_name :: (memory: Process_Memory, player: Game_Player_Location) -> (name: string, error: string) {
    value, after: Game_Entity_List; // Jai string: count, data.
    if !process_read_memory(memory.handle, player.manager, *value, size_of(Game_Entity_List)) ||
       !value.count || value.count > 128 || !process_memory_range_valid(value.data, value.count) return "", "Current scene name is unavailable.";
    name := alloc_string(cast(s64) value.count);
    if !process_read_memory(memory.handle, value.data, name.data, value.count) ||
       !game_player_location_current(memory, player) ||
       !process_read_memory(memory.handle, player.manager, *after, size_of(Game_Entity_List)) ||
       after.count != value.count || after.data != value.data {
        free(name);
        return "", "The scene changed while reading its name.";
    }
    return name, "";
}

game_position_writer_current :: (reader: *Game_Position_Reader, original: Game_Position_Sample) -> bool {
    current := game_position_reader_sample(reader, allow_resolve = false);
    // Moving one member can temporarily change which member is leftmost. The
    // fixed controlled set, not the changing spatial anchor, authorizes this write.
    return game_position_sample_same_group(current, original);
}

game_commit_positions :: (reader: *Game_Position_Reader, original: Game_Position_Sample,
                          targets: [] Game_Position_Target, instant: bool) -> (error: string, changed: bool) {
    memory := reader.memory;
    if !original.valid || !targets.count || targets.count != original.controlled_count ||
       !game_position_writer_current(reader, original) {
        return "The controlled characters changed. Nothing was written.", false;
    }
    field_count := ifx instant then 5 else 1;
    // Preflight every destination and every field before the first write. A bad
    // field on the final mirror copy must not leave earlier copies teleported.
    for target: targets {
        if !game_position_valid(target.destination) return "A character destination is invalid. Nothing was written.", false;
        for i: 0..field_count-1 {
            before: Game_Position;
            if !process_read_memory(memory.handle, target.player.entity + target.layout.offsets[i], *before, 12) ||
               !game_position_valid(before) return "Could not validate all controlled position fields. Nothing was written.", false;
            if i == 0 for axis: 0..2 if before[axis] != target.before[axis] {
                return "A controlled character moved during preparation. Nothing was written; try again.", false;
            }
        }
    }
    order := s64.[4, 3, 0, 1, 2];
    zero: Game_Position;
    changed := false;
    for target: targets {
        before: Game_Position;
        if !process_read_memory(memory.handle, target.player.entity, *before, 12) {
            return "Could not recheck a character before teleport. No further characters were written.", changed;
        }
        for axis: 0..2 if before[axis] != target.before[axis] {
            return "A character moved during teleport. No further characters were written.", changed;
        }
        // This is a sequence of field writes, not an atomic transaction. On any
        // failure, report possible changes and stop without rolling old state back.
        for field: 0..field_count-1 {
            if !game_position_writer_current(reader, original) {
                return "The controlled characters changed during teleport. No further fields were written.", changed;
            }
            index := ifx instant then order[field] else 0;
            value := ifx index == 4 then zero else target.destination;
            success, written := process_write_memory(memory.handle, target.player.entity + target.layout.offsets[index], *value, 12);
            changed = changed || written > 0;
            if !success return tprint("Could not finish teleport (% of 12 bytes; Windows error %).", written, Win.GetLastError()), changed;
        }
    }
    for target: targets {
        for i: 0..field_count-1 {
            current: Game_Position;
            if !process_read_memory(memory.handle, target.player.entity + target.layout.offsets[i], *current, 12) {
                return "Teleport was written, but a character's position fields could not be read back.", changed;
            }
            expected := ifx i == 4 then zero else target.destination;
            for axis: 0..2 if current[axis] != expected[axis] {
                return "The game changed position during teleport. Stop moving and try again.", changed;
            }
        }
    }
    if !game_position_writer_current(reader, original) {
        return "Teleport was written, but the controlled characters changed before verification.", changed;
    }
    return "", changed;
}

#scope_file
#import "Basic";
Win :: #import "Windows";
