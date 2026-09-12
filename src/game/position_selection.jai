Game_Selection_Layout :: struct {
    type: u64;
    entity_size: u32;
    status_offset: u64;
    active_mask: u16;
}

// Resolve selection through named Jai metadata. The observed ACTIVE=4 and +0x5c
// offset are evidence, not a fallback for an unrecognized game build.
game_selection_layout :: (memory: Process_Memory, type: u64)
        -> (layout: Game_Selection_Layout, error: string) {
    layout: Game_Selection_Layout;
    info: Game_Entity_Type;
    if !process_module_contains(memory.module, type, size_of(Game_Entity_Type)) ||
       !process_read_memory(memory.handle, type, *info, size_of(Game_Entity_Type)) || info.kind != 7 ||
       !game_metadata_name_matches(memory, info.name_length, info.name_data, "Guy") {
        return layout, "The game's character selection type could not be verified.";
    }
    entity, error := game_position_member(memory, type, "entity", "Entity");
    if error.count return layout, error;
    undo, undo_error := game_position_member(memory, entity.type, "undoable_data", "Undoable_Entity_Data");
    if undo_error.count return layout, undo_error;
    status, status_error := game_position_member(memory, undo.type, "status_flags", "Status_Flags", kind = 11, size = 2);
    if status_error.count return layout, status_error;
    if entity.offset != 0 || undo.offset != 0 || status.offset < 12 || cast(u64) status.offset + 2 > info.size {
        return layout, "The game's character selection layout is unsupported.";
    }
    for reserved: u64.[0xf0, 0x100, 0x108] {
        bytes := cast(u64)(ifx reserved == 0x100 then 4 else 8);
        if cast(u64) status.offset < reserved + bytes && reserved < cast(u64) status.offset + 2 {
            return layout, "The character selection field overlaps entity identity data.";
        }
    }
    internal_type: u64;
    internal: Game_Entity_Type;
    names, values: Game_Entity_List;
    is_signed: u8;
    enum_status: u16;
    // Status_Flags is declared as a plain enum in the verified demo. Its named
    // ACTIVE value defines the bit; enum_flags syntax is not a requirement.
    if !process_module_contains(memory.module, status.type, 74) ||
       !process_read_memory(memory.handle, status.type + 32, *internal_type, 8) ||
       !process_module_contains(memory.module, internal_type, 17) ||
       !process_read_memory(memory.handle, internal_type, *internal, 16) ||
       internal.kind != 0 || internal.size != 2 || internal.padding != 0 ||
       !process_read_memory(memory.handle, internal_type + 16, *is_signed, 1) || is_signed != 0 ||
       !process_read_memory(memory.handle, status.type + 40, *names, 16) ||
       !process_read_memory(memory.handle, status.type + 56, *values, 16) ||
       !process_read_memory(memory.handle, status.type + 72, *enum_status, 2) || enum_status != 0 ||
       !names.count || names.count > 128 || names.count != values.count ||
       !process_module_contains(memory.module, names.data, names.count * 16) ||
       !process_module_contains(memory.module, values.data, values.count * 8) {
        return layout, "The game's character selection flags could not be verified.";
    }
    matches: s64;
    mask: u64;
    for i: 0..cast(s64) names.count-1 {
        name: Game_Entity_List;
        if !process_read_memory(memory.handle, names.data + cast(u64) i * 16, *name, 16) {
            return layout, "Could not read the game's character selection flag names.";
        }
        if !game_metadata_name_matches(memory, name.count, name.data, "ACTIVE") continue;
        if !process_read_memory(memory.handle, values.data + cast(u64) i * 8, *mask, 8) ||
           !mask || mask > 0xffff || (mask & (mask - 1)) {
            return layout, "The game's ACTIVE flag is not a supported selection bit.";
        }
        matches += 1;
    }
    if matches != 1 return layout, "The game's ACTIVE selection flag is missing or ambiguous.";
    layout = .{type = type, entity_size = info.size, status_offset = cast(u64) status.offset, active_mask = cast(u16) mask};
    return layout, "";
}

game_position_precedes :: (a: Game_Position, b: Game_Position, a_id: u32 = 0, b_id: u32 = 0) -> bool {
    for i: 0..2 {
        if a[i] < b[i] return true;
        if a[i] > b[i] return false;
    }
    return a_id < b_id;
}

#scope_file
#import "Basic";
