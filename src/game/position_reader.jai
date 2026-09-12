// A read-only session. Every sample rechecks selection, even when the scene and
// entity list are unchanged (C / number-key selection does not replace entities).
Game_Position_Sample :: struct {
    valid: bool;
    position: Game_Position;
    player: Game_Player_Location;
    entity_id: u32;
    controlled_count: s64;
    selection_version: u64;
}

Game_Position_Guy :: struct {
    entity: u64;
    selection: Game_Selection_Layout;
    entity_id, observed_id: u32;
    status, observed_status: u16;
    position: Game_Position;
}

Game_Position_Reader :: struct {
    memory: Process_Memory;
    owns_memory: bool;
    locator: Game_Manager_Locator;
    player: Game_Player_Location;
    objects, scratch: [] u64;
    guys: [] Game_Position_Guy;
    guy_count: s64;
    selection_initialized: bool;
    selection_version: u64;
    resolutions: u64;
    error: string;
}

game_position_reader_close :: (reader: *Game_Position_Reader) {
    if reader.owns_memory process_close_memory(*reader.memory);
    free(reader.objects.data);
    free(reader.scratch.data);
    free(reader.guys.data);
    reader.* = .{};
}

game_position_reader_init :: (reader: *Game_Position_Reader, memory: Process_Memory) -> string {
    game_position_reader_close(reader);
    reader.memory = memory;
    slot, error := game_entity_manager_slot(memory, *reader.locator);
    return error;
}

game_position_reader_open :: (reader: *Game_Position_Reader, window: Win.HWND) -> string {
    memory, error := process_open_memory(window, GAME_EXECUTABLE);
    if error.count return error;
    error = game_position_reader_init(reader, memory);
    reader.owns_memory = true;
    if error.count game_position_reader_close(reader);
    return error;
}

game_position_sample_same_player :: (a: Game_Position_Sample, b: Game_Position_Sample) -> bool {
    return game_position_sample_same_group(a, b) && a.entity_id == b.entity_id && a.player.entity == b.player.entity;
}

game_position_sample_same_group :: (a: Game_Position_Sample, b: Game_Position_Sample) -> bool {
    return a.valid && b.valid && a.selection_version == b.selection_version &&
           a.controlled_count == b.controlled_count && a.player.slot == b.player.slot && a.player.manager == b.player.manager;
}

game_position_reader_resolve :: (reader: *Game_Position_Reader, manager: u64, objects: Game_Entity_List) -> bool {
    reader.player = .{};
    reader.selection_initialized = false;
    reader.selection_version += 1;
    reader.resolutions += 1;
    reader.guy_count = 0;
    if reader.guys.count != reader.scratch.count {
        free(reader.guys.data);
        reader.guys = NewArray(reader.scratch.count, Game_Position_Guy);
    }
    memory := reader.memory;
    for entity: reader.scratch {
        if !game_entity_is_player(memory, entity, manager) continue;
        duplicate := false;
        for i: 0..reader.guy_count-1 if reader.guys[i].entity == entity { duplicate = true; break; }
        if duplicate continue;
        type: u64;
        if !process_read_memory(memory.handle, entity + 0x108, *type, 8) return false;
        selection: Game_Selection_Layout;
        for i: 0..reader.guy_count-1 if reader.guys[i].selection.type == type {
            selection = reader.guys[i].selection;
            break;
        }
        if !selection.type {
            error: string;
            selection, error = game_selection_layout(memory, type);
            if error.count { reader.error = error; return false; }
        }
        if !process_memory_range_valid(entity, cast(u64) selection.entity_size) return false;
        for i: 0..reader.guy_count-1 {
            other := reader.guys[i];
            if entity < other.entity + other.selection.entity_size && other.entity < entity + selection.entity_size {
                reader.error = "The game's character entities overlap unexpectedly.";
                return false;
            }
        }
        reader.guys[reader.guy_count] = .{entity = entity, selection = selection};
        reader.guy_count += 1;
    }
    if !reader.guy_count { reader.error = "No Guy player entity was found in the current level."; return false; }
    reader.player = .{slot = reader.locator.slot, manager = manager, objects = objects};
    if reader.objects.count != reader.scratch.count {
        free(reader.objects.data);
        reader.objects = NewArray(reader.scratch.count, u64);
    }
    for entity: reader.scratch reader.objects[it_index] = entity;
    return true;
}

// allow_resolve=false never opens a process, scans code, allocates or searches
// entity types. It rejects changes to the original scene, identities or selection.
game_position_reader_sample :: (reader: *Game_Position_Reader, allow_resolve := true) -> Game_Position_Sample {
    result: Game_Position_Sample;
    reader.error = "Could not validate the current character selection. Try again.";
    memory := reader.memory;
    if !memory.handle || !game_manager_locator_current(memory, reader.locator) return result;
    manager: u64;
    objects: Game_Entity_List;
    if !process_read_memory(memory.handle, reader.locator.slot, *manager, 8) || !manager ||
       !process_memory_range_valid(manager, 0x380) ||
       !process_read_memory(memory.handle, manager + 0x370, *objects, size_of(Game_Entity_List)) ||
       !objects.count || objects.count > 20000 || !process_memory_range_valid(objects.data, objects.count * 8) return result;
    if cast(u64) reader.scratch.count != objects.count {
        if !allow_resolve return result;
        free(reader.scratch.data);
        reader.scratch = NewArray(cast(s64) objects.count, u64);
    }
    if !process_read_memory(memory.handle, objects.data, reader.scratch.data, objects.count * 8) return result;
    unchanged := reader.player.manager == manager && reader.player.objects.count == objects.count &&
                 reader.player.objects.data == objects.data && reader.objects.count == reader.scratch.count;
    if unchanged for entity: reader.scratch if entity != reader.objects[it_index] { unchanged = false; break; }
    if !unchanged {
        if !allow_resolve return result;
        if !game_position_reader_resolve(reader, manager, objects) return result;
    }
    anchor: s64 = -1;
    selection_changed := false;
    for i: 0..reader.guy_count-1 {
        guy := *reader.guys[i];
        type: u64;
        if !game_entity_is_player(memory, guy.entity, manager) ||
           !process_read_memory(memory.handle, guy.entity + 0x108, *type, 8) || type != guy.selection.type ||
           !process_read_memory(memory.handle, guy.entity + 0x100, *guy.observed_id, 4) ||
           !process_read_memory(memory.handle, guy.entity + guy.selection.status_offset, *guy.observed_status, 2) {
            if allow_resolve reader.player = .{};
            return result;
        }
        if reader.selection_initialized && (guy.observed_id != guy.entity_id || guy.observed_status != guy.status) {
            if !allow_resolve return result;
            selection_changed = true;
        }
        if !(guy.observed_status & guy.selection.active_mask) continue;
        if !process_read_memory(memory.handle, guy.entity, *guy.position, size_of(Game_Position)) ||
           !game_position_valid(guy.position) return result;
        result.controlled_count += 1;
        if anchor < 0 || game_position_precedes(guy.position, reader.guys[anchor].position,
                                                guy.observed_id, reader.guys[anchor].observed_id) anchor = i;
    }
    // Recheck the complete entity list and every Guy's selection. A switch halfway
    // through sampling must not combine the old and new controlled groups.
    after_manager: u64;
    after_objects: Game_Entity_List;
    if !process_read_memory(memory.handle, reader.locator.slot, *after_manager, 8) || after_manager != manager ||
       !process_read_memory(memory.handle, manager + 0x370, *after_objects, size_of(Game_Entity_List)) ||
       after_objects.count != objects.count || after_objects.data != objects.data ||
       !process_read_memory(memory.handle, objects.data, reader.scratch.data, objects.count * 8) return result;
    for entity: reader.scratch if entity != reader.objects[it_index] return result;
    for i: 0..reader.guy_count-1 {
        guy := *reader.guys[i];
        owner, type: u64;
        id: u32;
        status: u16;
        if !process_read_memory(memory.handle, guy.entity + 0xf0, *owner, 8) || owner != manager ||
           !process_read_memory(memory.handle, guy.entity + 0x108, *type, 8) || type != guy.selection.type ||
           !process_read_memory(memory.handle, guy.entity + 0x100, *id, 4) || id != guy.observed_id ||
           !process_read_memory(memory.handle, guy.entity + guy.selection.status_offset, *status, 2) ||
           status != guy.observed_status return result;
    }
    if !game_manager_locator_current(memory, reader.locator) ||
       !process_read_memory(memory.handle, reader.locator.slot, *after_manager, 8) || after_manager != manager return result;
    if selection_changed reader.selection_version += 1;
    for i: 0..reader.guy_count-1 {
        reader.guys[i].entity_id = reader.guys[i].observed_id;
        reader.guys[i].status = reader.guys[i].observed_status;
    }
    reader.selection_initialized = true;
    if anchor < 0 { reader.error = "No currently controlled character was found in this scene."; return result; }
    guy := reader.guys[anchor];
    reader.player.entity = guy.entity;
    reader.player.entity_id = guy.entity_id;
    result.player = reader.player;
    result.entity_id = guy.entity_id;
    result.position = guy.position;
    result.selection_version = reader.selection_version;
    result.valid = true;
    reader.error = "";
    return result;
}

#scope_file
#import "Basic";
Win :: #import "Windows";
