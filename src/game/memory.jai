GAME_POSITION_LIMIT :: 1_000_000.0;

game_position_valid :: (position: Game_Position) -> bool {
    for coordinate: position if !is_finite(coordinate) || abs(coordinate) > GAME_POSITION_LIMIT return false;
    return true;
}

game_read_position :: () -> (position: Game_Position, error: string) {
    position: Game_Position;
    window := find_game_window();
    if !window return position, "Game not found: sinking_star.exe.";
    memory, error := process_open_memory(window, GAME_EXECUTABLE);
    if error.count return position, error;
    defer process_close_memory(*memory);
    position, error = game_read_position_from(memory);
    return position, error;
}

game_write_position :: (position: Game_Position) -> (error: string, changed: bool) {
    if !game_position_valid(position) return "Coordinates must be finite numbers between -1000000 and 1000000.", false;
    window := find_game_window();
    if !window return "Game not found: sinking_star.exe.", false;
    memory, error := process_open_memory(window, GAME_EXECUTABLE, writable = true);
    if error.count return error, false;
    defer process_close_memory(*memory);
    changed: bool;
    error, changed = game_write_position_to(memory, position, instant = true);
    return error, changed;
}

game_read_position_from :: (memory: Process_Memory) -> (position: Game_Position, error: string) {
    position: Game_Position;
    reader: Game_Position_Reader;
    defer game_position_reader_close(*reader);
    error := game_position_reader_init(*reader, memory);
    if error.count return position, error;
    sample := game_position_reader_sample(*reader);
    if !sample.valid return position, reader.error;
    return sample.position, "";
}

game_write_position_to :: (memory: Process_Memory, requested: Game_Position, relative := false,
                          written_position: *Game_Position = null, written_player: *Game_Player_Location = null,
                          expected_player: *Game_Player_Location = null, expected_position: *Game_Position = null,
                          instant := false, required_scene: string = "", locator: *Game_Manager_Locator = null)
                          -> (error: string, changed: bool) {
    if !game_position_valid(requested) return "Coordinates must be finite numbers between -1000000 and 1000000.", false;
    resolved: Game_Manager_Locator;
    error: string;
    if locator && game_manager_locator_current(memory, locator.*) resolved = locator.*;
    else {
        slot: u64;
        slot, error = game_entity_manager_slot(memory, *resolved);
        if error.count return error, false;
        if locator locator.* = resolved;
    }
    reader: Game_Position_Reader;
    defer game_position_reader_close(*reader);
    reader.memory = memory;
    reader.locator = resolved;
    sample := game_position_reader_sample(*reader);
    if !sample.valid return tprint("% Nothing was written.", reader.error), false;
    if expected_player && !game_player_location_equal(sample.player, expected_player.*) {
        return "The current player changed. Nothing was written; try again.", false;
    }
    if expected_position {
        for i: 0..2 if sample.position[i] != expected_position.*[i] {
            return "The position changed before correction. Nothing was written.", false;
        }
    }
    if required_scene.count {
        scene, scene_error := game_player_scene_name(memory, sample.player);
        defer free(scene);
        if scene_error.count return scene_error, false;
        if scene != required_scene return "Return to the overworld before using switch.", false;
    }
    // Freeze the whole selected set before writing. Absolute placement translates
    // it relative to the actual lexicographically first controlled character.
    delta: [3] float64;
    for i: 0..2 delta[i] = ifx relative then cast(float64) requested[i]
                          else cast(float64) requested[i] - cast(float64) sample.position[i];
    targets := NewArray(sample.controlled_count, Game_Position_Target);
    defer free(targets.data);
    target_index: s64;
    anchor_destination: Game_Position;
    for i: 0..reader.guy_count-1 {
        guy := reader.guys[i];
        if !(guy.status & guy.selection.active_mask) continue;
        target := *targets[target_index];
        target.player = sample.player;
        target.player.entity = guy.entity;
        target.player.entity_id = guy.entity_id;
        target.before = guy.position;
        for axis: 0..2 {
            coordinate := cast(float64) guy.position[axis] + delta[axis];
            if !is_finite(coordinate) || abs(coordinate) > GAME_POSITION_LIMIT {
                return "Every controlled character's destination must be between -1000000 and 1000000. Nothing was written.", false;
            }
            target.destination[axis] = cast(float) coordinate;
        }
        if guy.entity == sample.player.entity {
            if !relative target.destination = requested;
            anchor_destination = target.destination;
        }
        if instant {
            target.layout, error = game_position_layout(memory, target.player);
            if error.count return error, false;
            for offset: target.layout.offsets if offset < guy.selection.status_offset + 2 &&
                                                   guy.selection.status_offset < offset + 12 {
                return "A position field overlaps character selection state. Nothing was written.", false;
            }
        }
        target_index += 1;
    }
    changed: bool;
    error, changed = game_commit_positions(*reader, sample, targets, instant);
    if error.count {
        if changed error = tprint("% Controlled characters may have been partially moved.", error);
        return error, changed;
    }
    if written_position written_position.* = anchor_destination;
    if written_player written_player.* = sample.player;
    return "", changed;
}

game_position_text :: (position: Game_Position) -> string {
    return tprint("(%, %, %)", formatFloat(position[0], mode = .SHORTEST),
                  formatFloat(position[1], mode = .SHORTEST), formatFloat(position[2], mode = .SHORTEST));
}

// SinkingStarHero's entity-list path: manager + 0x370/0x378, entity type + 0x108,
// Guy coordinates + 0/+4/+8. Its old manager RVA does not match the installed demo.
// Find the active manager through a RIP-relative load in the level-entry code:
//   mov r14, [rip + disp32]; cmp qword [r14 + 0xda8], 2
// This excludes retained overworld / background-scene managers that also contain a Guy.
GAME_MANAGER_SIGNATURE :: u8.[0x4c, 0x8b, 0x35, 0, 0, 0, 0, 0x49, 0x83, 0xbe, 0xa8, 0x0d, 0, 0, 2];

Game_Manager_Locator :: struct {
    slot, instruction: u64;
    bytes: [19] u8;
    count: s64;
}

game_manager_locator_current :: (memory: Process_Memory, locator: Game_Manager_Locator) -> bool {
    bytes: [19] u8;
    if locator.count <= 0 || locator.count > bytes.count ||
       !process_module_contains(memory.module, locator.slot, 8) ||
       !process_module_contains(memory.module, locator.instruction, cast(u64) locator.count) ||
       !process_read_memory(memory.handle, locator.instruction, *bytes, cast(u64) locator.count) return false;
    for i: 0..locator.count-1 if bytes[i] != locator.bytes[i] return false;
    return true;
}

game_entity_manager_slot :: (memory: Process_Memory, locator: *Game_Manager_Locator = null) -> (slot: u64, error: string) {
    code, code_rva, error := process_read_module_code(memory);
    if error.count return 0, error;
    defer free(code.data);
    rva, instruction: u64;
    matches: s64;
    if code.count >= GAME_MANAGER_SIGNATURE.count for i: 0..code.count - GAME_MANAGER_SIGNATURE.count {
        if code[i] != GAME_MANAGER_SIGNATURE[0] continue;
        if !game_manager_signature_matches(.{data = code.data + i, count = GAME_MANAGER_SIGNATURE.count}) continue;
        matches += 1;
        if matches > 1 return 0, "The game's current-level signature is ambiguous. Position access was stopped.";
        displacement := (cast(*s32)(code.data + i + 3)).*;
        target := cast(s64) code_rva + i + 7 + displacement;
        if target < 0 || cast(u64) target > memory.module.size || memory.module.size - cast(u64) target < 8 {
            return 0, "The game's current-level signature points outside its module.";
        }
        rva = cast(u64) target;
        instruction = cast(u64) i;
    }
    if matches == 1 {
        if locator {
            locator.* = .{slot = memory.module.base + rva, instruction = memory.module.base + code_rva + instruction,
                          count = GAME_MANAGER_SIGNATURE.count};
            for i: 0..locator.count-1 locator.bytes[i] = code[instruction + cast(u64) i];
        }
        return memory.module.base + rva, "";
    }

    // Compatibility with the reference trainer's build, only after its original code is verified.
    original: [19] u8;
    if process_module_contains(memory.module, memory.module.base + 0x2af0cc, original.count) &&
       process_read_memory(memory.handle, memory.module.base + 0x2af0cc, *original, original.count) &&
       process_module_contains(memory.module, memory.module.base + 0x9acb50, 8) {
        expected := u8.[0x80, 0x7c, 0x24, 0x60, 0, 0x75, 0x51, 0x80, 0x7c, 0x24, 0x76, 0, 0x74, 0x4a, 0x45, 0x84, 0xf6, 0x74, 0x2c];
        same := true;
        for byte: expected if byte != original[it_index] same = false;
        if same {
            if locator locator.* = .{slot = memory.module.base + 0x9acb50, instruction = memory.module.base + 0x2af0cc,
                                     bytes = original, count = original.count};
            return memory.module.base + 0x9acb50, "";
        }
    }
    return 0, "This game version's player-position layout was not recognized.";
}

game_manager_signature_matches :: (bytes: [] u8) -> bool {
    if bytes.count != GAME_MANAGER_SIGNATURE.count return false;
    for expected: GAME_MANAGER_SIGNATURE {
        if it_index >= 3 && it_index < 7 continue; // Signed RIP displacement, not opcode bytes.
        if bytes[it_index] != expected return false;
    }
    return true;
}

Game_Entity_List :: struct { count, data: u64; }
Game_Player_Location :: struct {
    slot, manager, entity: u64;
    objects: Game_Entity_List;
    entity_id: u32;
}

game_find_player :: (memory: Process_Memory, slot: u64) -> (player: Game_Player_Location, error: string) {
    reader: Game_Position_Reader;
    defer game_position_reader_close(*reader);
    error := game_position_reader_init(*reader, memory);
    if error.count return .{}, error;
    if reader.locator.slot != slot return .{}, "The current scene locator changed. Try again.";
    sample := game_position_reader_sample(*reader);
    if !sample.valid return .{}, reader.error;
    return sample.player, "";
}

game_entity_is_player :: (memory: Process_Memory, entity: u64, manager: u64) -> bool {
    if !process_memory_range_valid(entity, 0x110) return false;
    type_address, owner: u64;
    if !process_read_memory(memory.handle, entity + 0xf0, *owner, 8) || owner != manager ||
       !process_read_memory(memory.handle, entity + 0x108, *type_address, 8) ||
       !process_module_contains(memory.module, type_address, size_of(Game_Entity_Type)) return false;
    info: Game_Entity_Type;
    if !process_read_memory(memory.handle, type_address, *info, size_of(Game_Entity_Type)) ||
       info.kind != 7 || info.size < 0x110 || info.name_length != 3 ||
       !process_module_contains(memory.module, info.name_data, 3) return false;
    name: [3] u8;
    return process_read_memory(memory.handle, info.name_data, *name, name.count) &&
           name[0] == #char "G" && name[1] == #char "u" && name[2] == #char "y";
}

game_player_location_equal :: (current: Game_Player_Location, previous: Game_Player_Location) -> bool {
    return current.slot == previous.slot && current.manager == previous.manager && current.entity == previous.entity &&
           current.entity_id == previous.entity_id && current.objects.count == previous.objects.count &&
           current.objects.data == previous.objects.data;
}

game_player_location_current :: (memory: Process_Memory, previous: Game_Player_Location) -> bool {
    current, error := game_find_player(memory, previous.slot);
    return !error.count && game_player_location_equal(current, previous);
}

Game_Entity_Type :: struct {
    kind, id, size, padding: u32;
    name_length, name_data: u64;
}
#assert(size_of(Game_Entity_Type) == 32);
#assert(size_of(Game_Position) == 12);

#scope_file
#import "Basic";
#import "Math";
#import "String";
Win :: #import "Windows";
