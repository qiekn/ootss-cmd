// The active manager begins with its level resource name (a Jai string).
// Resolve it from the checked current-scene signature, independently of Guy
// entities and coordinates: a level may contain several controlled characters.
Game_Level_Query :: #type () -> (name: string, error: string);

Game_Scene_Location :: struct {
    locator: Game_Manager_Locator;
    manager: u64;
    name: Game_Entity_List; // Remote Jai string: count, data.
}

game_read_scene :: () -> (name: string, error: string) {
    window := find_game_window();
    if !window return "", "Game not found: sinking_star.exe.";
    memory, error := process_open_memory(window, GAME_EXECUTABLE);
    if error.count return "", error;
    defer process_close_memory(*memory);
    name: string;
    name, error = game_read_scene_from(memory);
    return name, error;
}

// The caller owns the returned name. No manager or player address is cached.
game_read_scene_from :: (memory: Process_Memory) -> (name: string, error: string) {
    scene: Game_Scene_Location;
    slot, error := game_entity_manager_slot(memory, *scene.locator);
    if error.count return "", error;
    if !process_read_memory(memory.handle, slot, *scene.manager, 8) || !scene.manager {
        return "", "Current level is unavailable. Wait until the game has loaded a scene.";
    }
    if !process_read_memory(memory.handle, scene.manager, *scene.name, size_of(Game_Entity_List)) ||
       !scene.name.count || scene.name.count > 128 || !process_memory_range_valid(scene.name.data, scene.name.count) {
        return "", "The current scene has an unreadable or unsupported level name.";
    }
    name := alloc_string(cast(s64) scene.name.count);
    if !process_read_memory(memory.handle, scene.name.data, name.data, scene.name.count) || !game_scene_name_valid(name) {
        free(name);
        return "", "Could not read a valid level resource name from the current scene.";
    }
    if !game_scene_location_current(memory, scene, name) {
        free(name);
        return "", "The current scene changed while reading its name. Try again.";
    }
    return name, "";
}

game_scene_location_current :: (memory: Process_Memory, scene: Game_Scene_Location, name: string) -> bool {
    manager: u64;
    header: Game_Entity_List;
    bytes: [128] u8;
    if name.count <= 0 || name.count > bytes.count || cast(u64) name.count != scene.name.count ||
       !game_manager_locator_current(memory, scene.locator) ||
       !process_read_memory(memory.handle, scene.locator.slot, *manager, 8) || manager != scene.manager ||
       !process_read_memory(memory.handle, manager, *header, size_of(Game_Entity_List)) ||
       header.count != scene.name.count || header.data != scene.name.data ||
       !process_read_memory(memory.handle, header.data, *bytes, header.count) return false;
    for c: name if bytes[it_index] != c return false;
    // Check the root and string header again after copying the payload.
    return game_manager_locator_current(memory, scene.locator) &&
           process_read_memory(memory.handle, scene.locator.slot, *manager, 8) && manager == scene.manager &&
           process_read_memory(memory.handle, manager, *header, size_of(Game_Entity_List)) &&
           header.count == scene.name.count && header.data == scene.name.data;
}

game_scene_is_level :: (name: string) -> bool {
    if !game_scene_name_valid(name) return false;
    for scene: string.["overworld", "menu", "menu_demo_startup", "ingame_particles", "ingame_glyphs"] {
        if equal_nocase(name, scene) return false;
    }
    return true;
}

// Explicit names never access game memory; all callers own the returned string.
game_resolve_level_name :: (requested: string, read_scene: Game_Level_Query = game_read_scene)
                           -> (name: string, error: string) {
    if requested.count return copy_string(requested), "";
    name, error := read_scene();
    if error.count { free(name); return "", error; }
    if equal_nocase(name, "overworld") {
        free(name);
        return "", "Currently in Overworld. Enter a small level or specify a level name.";
    }
    if !game_scene_is_level(name) {
        free(name);
        return "", "The current scene is not a playable level. Enter a level or specify its name.";
    }
    return name, "";
}

#scope_file
#import "Basic";
#import "String";

game_scene_name_valid :: (name: string) -> bool {
    if !name.count || name.count > 128 || name == "." || name == ".." return false;
    for c: name {
        if (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") ||
           (c >= #char "0" && c <= #char "9") || c == #char "_" || c == #char "-" || c == #char "." continue;
        return false;
    }
    return true;
}
