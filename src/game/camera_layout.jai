// The manager has no reflected camera members in the supported game build.
// Decode their offsets from the native camera update and rendering instructions;
// keep the complete matched bytes so an active session can detect code changes.
Game_Camera_Code :: struct {
    address: u64;
    bytes: [96] u8;
    count: s64;
}

Game_Camera_Layout :: struct {
    manager: Game_Manager_Locator;
    mode: u64;
    position, orientation, projection, cameras: u64;
    code: [6] Game_Camera_Code;
}

Game_Camera_Entity :: struct {
    address, type: u64;
    id, size: u32;
}

Game_Camera_Snapshot :: struct {
    scene: Game_Scene_Location;
    name: [128] u8;
    list: Game_Entity_List;
    entities: [64] Game_Camera_Entity;
    position: Game_Position;
    orientation: [4] float;
    projection: [3] float; // Vertical FOV in radians, near plane, far plane.
    mode: s64;
}

game_camera_code_matches :: (code: [] u8, offset: s64, pattern: [] s16) -> bool {
    if offset < 0 || pattern.count > code.count || offset > code.count - pattern.count return false;
    for byte: pattern if byte >= 0 && code[offset + it_index] != byte return false;
    return true;
}

game_camera_find_code :: (code: [] u8, pattern: [] s16) -> s64 {
    found: s64 = -1;
    if pattern.count > code.count return -1;
    for i: 0..code.count - pattern.count {
        if !game_camera_code_matches(code, i, pattern) continue;
        if found >= 0 return -1; // Ambiguous signatures are unsupported too.
        found = i;
    }
    return found;
}

game_camera_save_code :: (check: *Game_Camera_Code, code: [] u8, base: u64, offset: s64, count: s64) -> bool {
    if offset < 0 || count <= 0 || count > check.bytes.count || offset > code.count - count return false;
    check.address = base + cast(u64) offset;
    check.count = count;
    for i: 0..count-1 check.bytes[i] = code[offset + i];
    return true;
}

game_camera_code_current :: (memory: Process_Memory, layout: Game_Camera_Layout) -> bool {
    if !game_manager_locator_current(memory, layout.manager) ||
       !process_module_writable_data(memory, layout.mode, 8) return false;
    for check: layout.code {
        current: [96] u8;
        if check.count <= 0 || check.count > current.count ||
           !process_module_contains(memory.module, check.address, cast(u64) check.count) ||
           !process_read_memory(memory.handle, check.address, *current, cast(u64) check.count) return false;
        for i: 0..check.count-1 if current[i] != check.bytes[i] return false;
    }
    return true;
}

game_camera_layout :: (memory: Process_Memory) -> (layout: Game_Camera_Layout, error: string) {
    layout: Game_Camera_Layout;
    unsupported :: "This game version's free-camera layout could not be verified.";
    slot, manager_error := game_entity_manager_slot(memory, *layout.manager);
    if manager_error.count return layout, manager_error;
    code, rva, error := process_read_module_code(memory);
    if error.count return layout, error;
    defer free(code.data);
    base := memory.module.base + rva;

    // Native mode 0 follows the level, 1 reads the game's debug-camera input.
    // A nonzero mode other than 1 skips both pose writers (we use 2).
    gate := game_camera_find_code(code, s16.[
        0x4c,0x8d,0xb3,-1,-1,-1,-1, 0x48,0x8b,0x05,-1,-1,-1,-1,
        0x48,0x85,0xc0, 0x0f,0x84,-1,-1,-1,-1, 0x48,0x83,0xf8,0x01, 0x0f,0x85,-1,-1,-1,-1]);
    render := game_camera_find_code(code, s16.[
        0x4d,0x8d,0x81,-1,-1,-1,-1, 0xf3,0x41,0x0f,0x10,0x89,-1,-1,-1,-1,
        0xf3,0x41,0x0f,0x10,0x99,-1,-1,-1,-1, 0xf3,0x41,0x0f,0x10,0x91,-1,-1,-1,-1]);
    link := game_camera_find_code(code, s16.[
        0x48,0x8b,0x1d,-1,-1,-1,-1, 0x48,0x8d,0xbb,-1,-1,-1,-1,
        0x4c,0x8d,0x83,-1,-1,-1,-1, 0x31,0xc9,0x48,0x89,0xfa,0xe8,-1,-1,-1,-1]);
    if gate < 0 || render < 45 || link < 0 return layout, unsupported;
    normal := gate + 23 + cast(s64)(cast(*s32)(code.data + gate + 19)).*;
    frozen := gate + 33 + cast(s64)(cast(*s32)(code.data + gate + 29)).*;
    if !game_camera_code_matches(code, normal, s16.[0x48,0x8b,0x83,-1,-1,-1,-1,0x48,0x85,0xc0,0x0f,0x8e,-1,-1,-1,-1]) ||
       !game_camera_code_matches(code, normal + 62, s16.[0x48,0x8b,0x8b,-1,-1,-1,-1,0x4a,0x8b,0x34,0xe1]) ||
       !game_camera_code_matches(code, normal - 23, s16.[
           0x4c,0x8d,0xb3,-1,-1,-1,-1,0x48,0x8b,0x05,-1,-1,-1,-1,0x48,0x85,0xc0,0x0f,0x85,-1,-1,-1,-1]) ||
       !game_camera_code_matches(code, frozen, s16.[
           0xf3,0x0f,0x10,0xbb,-1,-1,-1,-1,0xf3,0x0f,0x10,0x83,-1,-1,-1,-1,0xf3,0x0f,0x5c,0xbb,-1,-1,-1,-1]) ||
       !game_camera_code_matches(code, render - 45, s16.[
           0x49,0x8d,0x91,-1,-1,-1,-1,0x0f,0xb6,0x05,-1,-1,-1,-1,0xc0,0xe8,0x04,0x24,0x01,
           0x48,0x8b,0x0d,-1,-1,-1,-1,0xf2,0x0f,0x10,0x41,0x38,0x0f,0x5b,0xc0,
           0x0f,0x28,0xc8,0x0f,0xc6,0xc8,0x55,0xf3,0x0f,0x5e,0xc1]) return layout, unsupported;

    layout.position = (cast(*u32)(code.data + gate + 3)).*;
    layout.orientation = (cast(*u32)(code.data + render + 3)).*;
    layout.projection = (cast(*u32)(code.data + render + 12)).*;
    layout.cameras = (cast(*u32)(code.data + normal + 3)).*;
    mode := cast(s64) base + gate + 14 + (cast(*s32)(code.data + gate + 10)).*;
    if mode <= 0 return layout, unsupported;
    layout.mode = cast(u64) mode;
    // Cross-check the alternate update path, the frozen branch's destination,
    // the render arguments, and a separate reference from the active scene.
    if layout.position < 0x380 || layout.position > 0x100000 ||
       layout.orientation != layout.position + 24 || layout.projection != layout.orientation + 16 ||
       layout.cameras < 0x380 || layout.cameras + 16 > layout.position ||
       (cast(*u32)(code.data + normal + 65)).* != layout.cameras + 8 ||
       (cast(*u32)(code.data + normal - 20)).* != layout.position ||
       cast(s64) base + normal - 9 + (cast(*s32)(code.data + normal - 13)).* != mode ||
       normal + (cast(*s32)(code.data + normal - 4)).* != gate + 23 ||
       (cast(*u32)(code.data + frozen + 4)).* != layout.position + 8 ||
       (cast(*u32)(code.data + frozen + 12)).* != layout.projection ||
       (cast(*u32)(code.data + render - 42)).* != layout.position ||
       (cast(*u32)(code.data + render + 21)).* != layout.projection + 4 ||
       (cast(*u32)(code.data + render + 30)).* != layout.projection + 8 ||
       cast(s64) base + link + 7 + (cast(*s32)(code.data + link + 3)).* != cast(s64) slot ||
       (cast(*u32)(code.data + link + 10)).* != layout.position ||
       (cast(*u32)(code.data + link + 17)).* != layout.orientation ||
       !process_module_contains(memory.module, layout.mode, 8) || layout.mode == slot return layout, unsupported;

    if !game_camera_save_code(*layout.code[0], code, base, gate, 33) ||
       !game_camera_save_code(*layout.code[1], code, base, normal - 23, 23) ||
       !game_camera_save_code(*layout.code[2], code, base, normal, 73) ||
       !game_camera_save_code(*layout.code[3], code, base, frozen, 24) ||
       !game_camera_save_code(*layout.code[4], code, base, render - 45, 79) ||
       !game_camera_save_code(*layout.code[5], code, base, link, 31) ||
       !game_camera_code_current(memory, layout) return layout, unsupported;
    return layout, "";
}

game_camera_type_valid :: (memory: Process_Memory, type: u64, layout: Game_Camera_Layout) -> bool {
    entity, error := game_position_member(memory, type, "entity", "Entity");
    if error.count || entity.offset != 0 return false;
    owner, owner_error := game_position_member(memory, entity.type, "entity_manager", "", kind = 4, size = 8);
    if owner_error.count || owner.offset != 0xf0 return false;
    manager_type: u64;
    info: Game_Entity_Type;
    if !process_read_memory(memory.handle, owner.type + 16, *manager_type, 8) ||
       !process_module_contains(memory.module, manager_type, size_of(Game_Entity_Type)) ||
       !process_read_memory(memory.handle, manager_type, *info, size_of(Game_Entity_Type)) || info.kind != 7 ||
       !game_metadata_name_matches(memory, info.name_length, info.name_data, "Entity_Manager") ||
       layout.projection + 12 > info.size || info.size > 0x100000 return false;
    undo, undo_error := game_position_member(memory, entity.type, "undoable_data", "Undoable_Entity_Data");
    if undo_error.count || undo.offset != 0 return false;
    position, position_error := game_position_member(memory, undo.type, "position", "Vector3", size = 12);
    if position_error.count || position.offset != 0 return false;
    for axis: string.["x", "y", "z"] {
        scalar, scalar_error := game_position_member(memory, position.type, axis, "", kind = 1, size = 4);
        if scalar_error.count || scalar.offset != it_index * 4 return false;
    }
    for name: string.["fov_vertical", "z_near", "z_far"] {
        member, member_error := game_position_member(memory, type, name, "", kind = 1, size = 4);
        if member_error.count return false;
    }
    return true;
}

game_camera_pose_valid :: (snapshot: Game_Camera_Snapshot) -> bool {
    if !game_position_valid(snapshot.position) return false;
    norm: float64;
    for value: snapshot.orientation {
        if !is_finite(value) return false;
        norm += cast(float64) value * value;
    }
    if abs(norm - 1) > 0.002 return false;
    for value: snapshot.projection if !is_finite(value) return false;
    return snapshot.projection[0] > 0.01 && snapshot.projection[0] < 3.13 &&
           snapshot.projection[1] > 0 && snapshot.projection[2] > snapshot.projection[1] &&
           snapshot.projection[2] <= GAME_POSITION_LIMIT;
}

game_camera_identity_current :: (memory: Process_Memory, layout: Game_Camera_Layout,
                                 snapshot: Game_Camera_Snapshot) -> bool {
    name: string = .{data = snapshot.name.data, count = cast(s64) snapshot.scene.name.count};
    if !game_camera_code_current(memory, layout) || !game_scene_location_current(memory, snapshot.scene, name) ||
       snapshot.list.count == 0 || snapshot.list.count > snapshot.entities.count return false;
    list: Game_Entity_List;
    pointers: [64] u64;
    if !process_read_memory(memory.handle, snapshot.scene.manager + layout.cameras, *list, 16) ||
       list.count != snapshot.list.count || list.data != snapshot.list.data ||
       !process_read_memory(memory.handle, list.data, *pointers, list.count * 8) return false;
    for i: 0..cast(s64) list.count-1 {
        entity := snapshot.entities[i];
        owner, type: u64;
        id: u32;
        info: Game_Entity_Type;
        if pointers[i] != entity.address ||
           !process_read_memory(memory.handle, entity.address + 0xf0, *owner, 8) || owner != snapshot.scene.manager ||
           !process_read_memory(memory.handle, entity.address + 0x100, *id, 4) || id != entity.id ||
           !process_read_memory(memory.handle, entity.address + 0x108, *type, 8) || type != entity.type ||
           !process_module_contains(memory.module, type, size_of(Game_Entity_Type)) ||
           !process_read_memory(memory.handle, type, *info, size_of(Game_Entity_Type)) ||
           info.kind != 7 || info.size != entity.size ||
           !game_metadata_name_matches(memory, info.name_length, info.name_data, "Camera_Control") return false;
    }
    return game_scene_location_current(memory, snapshot.scene, name);
}

game_camera_snapshot :: (memory: Process_Memory, layout: Game_Camera_Layout)
                        -> (snapshot: Game_Camera_Snapshot, error: string) {
    snapshot: Game_Camera_Snapshot;
    invalid :: "The current scene's camera could not be validated.";
    snapshot.scene.locator = layout.manager;
    if !game_camera_code_current(memory, layout) ||
       !process_read_memory(memory.handle, layout.manager.slot, *snapshot.scene.manager, 8) ||
       !process_memory_range_valid(snapshot.scene.manager, layout.projection + 12) ||
       !process_read_memory(memory.handle, snapshot.scene.manager, *snapshot.scene.name, 16) ||
       !snapshot.scene.name.count || snapshot.scene.name.count > snapshot.name.count ||
       !process_read_memory(memory.handle, snapshot.scene.name.data, *snapshot.name, snapshot.scene.name.count) return snapshot, invalid;
    name: string = .{data = snapshot.name.data, count = cast(s64) snapshot.scene.name.count};
    if !equal_nocase(name, "overworld") && !game_scene_is_level(name) return snapshot, "Enter the overworld or a level before enabling freecam.";
    if !process_read_memory(memory.handle, snapshot.scene.manager + layout.cameras, *snapshot.list, 16) ||
       !snapshot.list.count || snapshot.list.count > snapshot.entities.count return snapshot, invalid;
    pointers: [64] u64;
    if !process_read_memory(memory.handle, snapshot.list.data, *pointers, snapshot.list.count * 8) return snapshot, invalid;
    for i: 0..cast(s64) snapshot.list.count-1 {
        entity := *snapshot.entities[i];
        entity.address = pointers[i];
        owner: u64;
        info: Game_Entity_Type;
        if !process_memory_range_valid(entity.address, 0x110) ||
           !process_read_memory(memory.handle, entity.address + 0xf0, *owner, 8) || owner != snapshot.scene.manager ||
           !process_read_memory(memory.handle, entity.address + 0x100, *entity.id, 4) || !entity.id ||
           !process_read_memory(memory.handle, entity.address + 0x108, *entity.type, 8) ||
           !process_module_contains(memory.module, entity.type, size_of(Game_Entity_Type)) ||
           !process_read_memory(memory.handle, entity.type, *info, size_of(Game_Entity_Type)) ||
           info.kind != 7 || info.size < 0x110 || info.size > 0x100000 ||
           !game_metadata_name_matches(memory, info.name_length, info.name_data, "Camera_Control") return snapshot, invalid;
        entity.size = info.size;
        known_type := false;
        for previous: 0..i-1 {
            if snapshot.entities[previous].address == entity.address return snapshot, invalid;
            if snapshot.entities[previous].type == entity.type known_type = true;
        }
        if !known_type && !game_camera_type_valid(memory, entity.type, layout) return snapshot, invalid;
    }
    if !process_read_memory(memory.handle, snapshot.scene.manager + layout.position, *snapshot.position, 12) ||
       !process_read_memory(memory.handle, snapshot.scene.manager + layout.orientation, *snapshot.orientation, 16) ||
       !process_read_memory(memory.handle, snapshot.scene.manager + layout.projection, *snapshot.projection, 12) ||
       !process_read_memory(memory.handle, layout.mode, *snapshot.mode, 8) || !game_camera_pose_valid(snapshot) ||
       !game_camera_identity_current(memory, layout, snapshot) return snapshot, invalid;
    return snapshot, "";
}

#scope_file
#import "Basic";
#import "Math";
#import "String";
