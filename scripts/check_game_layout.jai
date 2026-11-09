#!/usr/bin/env jai

// Isolated PE checks. Optional EXE arguments are read as data, never executed.
// jai -quiet scripts/check_game_layout.jai -import_dir ../modules - [game.exe ...]
#run {
    set_build_options_dc(.{do_output = false});
    check_signatures();
    check_camera_layout();
    check_switch_catalog();
    for filename: get_build_options().compile_time_command_line check_image(filename);
    print("PASS: % isolated scene/camera/switch checks; no game writes or input.\n", checks);
}

checks: s64;
check :: (condition: bool, message: string) {
    checks += 1;
    if !condition { compiler_report(message); assert(condition); }
}
put :: (bytes: [] u8, offset: s64, value: $T) {
    assert(offset >= 0 && offset <= bytes.count - size_of(T));
    (cast(*T)(bytes.data + offset)).* = value;
}
install :: (image: [] u8, at: s64, slot: s64, signature: [] u8) {
    for byte: signature image[at + it_index] = byte;
    put(image, at + 3, cast(s32)(slot - at - 7));
}
check_signatures :: () {
    image := NewArray(0x5000, u8);
    defer free(image.data);
    put(image, 0, cast(u16) 0x5a4d);
    put(image, 0x3c, cast(u32) 0x80);
    put(image, 0x80, cast(u32) 0x4550);
    put(image, 0x84, cast(u16) 0x8664);
    put(image, 0x86, cast(u16) 1);
    put(image, 0x94, cast(u16) 0xf0);
    put(image, 0x98, cast(u16) 0x20b);
    for byte: ".text" image[0x188 + it_index] = byte;
    put(image, 0x190, cast(u32) 0x200);
    put(image, 0x194, cast(u32) 0x1000);
    put(image, 0x1ac, cast(u32) 0x60000020);
    memory: App.Process_Memory = .{handle=Win.GetCurrentProcess(), module=.{base=cast(u64) image.data,size=cast(u64) image.count}};
    install(image, 0x1010, 0x3000, App.GAME_MANAGER_SIGNATURE);
    put(image, 0x3000, cast(u64)(image.data + 0x3100));
    for name: string.["mirror_21", "menu", "overworld"] {
        put(image, 0x3100, App.Game_Entity_List.{count = cast(u64) name.count, data = cast(u64)(image.data + 0x3200)});
        for byte: name image[0x3200 + it_index] = byte;
        scene: App.Game_Scene_Location;
        actual, error := App.game_read_scene_from(memory, location = *scene);
        defer free(actual);
        check(!error.count && actual == name, "Read a scene without requiring a Guy.");
        check(App.game_scene_location_current(memory, scene, actual), "Validate the exact scene snapshot.");
        if name != "overworld" {
            error, changed := App.game_write_position_to(memory, .[80, 74, 33], instant = true, required_scene = "overworld");
            check(!changed && error == "Return to the overworld before using switch.", "Reject small levels/menu before looking for a player or writing.");
        }
        image[0x3200] ^= 1;
        check(!App.game_scene_location_current(memory, scene, actual), "Reject in-place scene-name changes with the same manager.");
        image[0x3200] ^= 1;
    }
    for byte: App.GAME_MANAGER_SIGNATURE image[0x1010 + it_index] = 0;
    for signature: ([] u8).[App.GAME_MANAGER_SIGNATURE, App.GAME_MANAGER_RETAIL_SIGNATURE] {
        for slot_rva: s64.[0x3000, 0x700] {
            install(image, 0x1010, slot_rva, signature);
            locator: App.Game_Manager_Locator;
            slot, error := App.game_entity_manager_slot(memory, *locator);
            check(!error.count && slot == memory.module.base + cast(u64) slot_rva, "Decode signed RIP displacement for both builds.");
            check(locator.count == signature.count && App.game_manager_locator_current(memory, locator), "Retain every matched code byte.");
            for i: 0..signature.count-1 {
                image[0x1010+i] ^= 1;
                check(!App.game_manager_locator_current(memory, locator), "Any code change invalidates a cached locator.");
                image[0x1010+i] ^= 1;
            }
            for byte: signature image[0x1010+it_index] = 0;
        }
    }
    install(image, 0x1010, 0x3000, App.GAME_MANAGER_SIGNATURE);
    install(image, 0x1050, 0x3000, App.GAME_MANAGER_RETAIL_SIGNATURE);
    slot, error := App.game_entity_manager_slot(memory);
    check(error.count > 0 && !slot, "Reject simultaneous Demo and retail matches, even for the same slot.");
    image[0x1010] = 0;
    install(image, 0x1050, 0x5000, App.GAME_MANAGER_RETAIL_SIGNATURE);
    slot, error = App.game_entity_manager_slot(memory);
    check(error.count > 0 && !slot, "Reject an out-of-module retail slot.");
    install(image, 0x1050, 0x3000, App.GAME_MANAGER_RETAIL_SIGNATURE);
    image[0x1050+10] ^= 1;
    slot, error = App.game_entity_manager_slot(memory);
    check(error.count > 0 && !slot, "Reject changed retail camera-field evidence.");
    image[0x1050] = 0;
    install(image, 0x1200-15, 0x3000, App.GAME_MANAGER_RETAIL_SIGNATURE);
    slot, error = App.game_entity_manager_slot(memory);
    check(error.count > 0 && !slot, "Do not match a retail signature crossing the code-section end.");
}

check_camera_layout :: () {
    image := NewArray(0x5000, u8);
    defer free(image.data);
    put(image, 0, cast(u16) 0x5a4d);
    put(image, 0x3c, cast(u32) 0x80);
    put(image, 0x80, cast(u32) 0x4550);
    put(image, 0x84, cast(u16) 0x8664);
    put(image, 0x86, cast(u16) 2);
    put(image, 0x94, cast(u16) 0xf0);
    put(image, 0x98, cast(u16) 0x20b);
    for byte: ".text" image[0x188 + it_index] = byte;
    put(image, 0x190, cast(u32) 0x1000);
    put(image, 0x194, cast(u32) 0x1000);
    put(image, 0x1ac, cast(u32) 0x60000020);
    for byte: ".data" image[0x1b0 + it_index] = byte;
    put(image, 0x1b8, cast(u32) 0x1000);
    put(image, 0x1bc, cast(u32) 0x3000);
    put(image, 0x1d4, cast(u32) 0xc0000040);
    memory: App.Process_Memory = .{handle = Win.GetCurrentProcess(),
                                 module = .{base = cast(u64) image.data, size = cast(u64) image.count}};
    install(image, 0x1050, 0x3000, App.GAME_MANAGER_RETAIL_SIGNATURE);
    // Latest r12 update, with r15 as the loop index and rbx as the camera.
    for byte: u8.[
        0x49,0x8d,0xac,0x24,0x98,0x3d,0,0, 0x48,0x8b,0x05,0,0,0,0,
        0x48,0x85,0xc0, 0x0f,0x84,0,0,0,0, 0x48,0x83,0xf8,1, 0x0f,0x85,0,0,0,0]
        image[0x1100 + it_index] = byte;
    put(image, 0x110b, cast(s32)(0x3008 - 0x110f));
    put(image, 0x1114, cast(s32)(0x1300 - 0x1118));
    put(image, 0x111e, cast(s32)(0x1500 - 0x1122));
    for byte: u8.[
        0x50,0xc3,0xa8,1,0x0f,0x85,0,0,0,0, 0xf3,0x0f,0x10,0x1d,0,0,0,0,0xe9,0,0,0,0,
        0x4c,0x89,0x74,0x24,0x68, 0x49,0x83,0xbc,0x24,0x38,5,0,0,0, 0x0f,0x8e,0,0,0,0]
        image[0x1300 - 23 + it_index] = byte;
    for byte: u8.[
        0x49,0xff,0xc7, 0x4d,0x3b,0xbc,0x24,0x38,5,0,0, 0x0f,0x8d,0,0,0,0,
        0x49,0x8b,0x84,0x24,0x40,5,0,0, 0x4a,0x8b,0x1c,0xf8]
        image[0x1300 + 53 + it_index] = byte;
    for byte: u8.[
        0x41,0x0f,0x13,0x84,0x24,0x98,0x3d,0,0, 0xf3,0x41,0x0f,0x11,0x94,0x24,0xa0,0x3d,0,0,
        0x49,0x8b,0x04,0x24, 0x48,0x83,0xc0,0xfb, 0x48,0x83,0xf8,0x14, 0x0f,0x87,0,0,0,0]
        image[0x1500 - 19 + it_index] = byte;
    for byte: u8.[
        0x48,0x8d,0x90,0x98,0x3d,0,0, 0x0f,0xb6,0x0d,0,0,0,0, 0xc0,0xe9,4, 0x80,0xe1,1,
        0x4c,0x8b,0x05,0,0,0,0, 0xf2,0x41,0x0f,0x10,0x40,0x38,0x0f,0x5b,0xc0,
        0x0f,0x28,0xc8,0x0f,0xc6,0xc8,0x55,0xf3,0x0f,0x5e,0xc1,
        0x4c,0x8d,0x80,0xb0,0x3d,0,0, 0xf3,0x0f,0x10,0x88,0xc0,0x3d,0,0,
        0xf3,0x0f,0x10,0x98,0xc4,0x3d,0,0, 0xf3,0x0f,0x10,0x90,0xc8,0x3d,0,0]
        image[0x1700 - 47 + it_index] = byte;
    layout, error := App.game_camera_layout(memory);
    check(!error.count && layout.profile == "retail-r12-2026-10-31" && layout.position == 0x3d98 &&
          layout.orientation == 0x3db0 && layout.projection == 0x3dc0 && layout.cameras == 0x538 &&
          layout.mode == memory.module.base + 0x3008, "Decode the latest r12 camera layout from isolated instructions.");
    for evidence: layout.code for i: 0..evidence.count - 1 {
        at := evidence.address - memory.module.base + cast(u64) i;
        image[at] ^= 1;
        check(!App.game_camera_code_current(memory, layout), "Retain all branch, list, write and render evidence in a session.");
        image[at] ^= 1;
    }
    for at: s64.[0x1104, 0x1309, 0x133c, 0x134a, 0x14f2, 0x14fc, 0x16d4, 0x1703, 0x170b, 0x1713, 0x171b] {
        image[at] ^= 4;
        rejected, rejected_error := App.game_camera_layout(memory);
        check(rejected_error.count > 0, "Reject conflicts between update, loop, frozen writes, render and active-scene fields.");
        image[at] ^= 4;
    }
    for i: 0..33 image[0x1800 + i] = image[0x1100 + i];
    rejected, rejected_error := App.game_camera_layout(memory);
    check(rejected_error.count > 0, "Reject two camera mode gates.");
    for i: 0..33 image[0x1800 + i] = 0;
    // Each boundary ends one byte before a required evidence window completes.
    for end: u32.[0x1050 + 27, 0x1100 + 33, 0x1300 + 19, 0x1300 + 81, 0x1500 + 17, 0x1700 + 30] {
        put(image, 0x190, end - 0x1000);
        rejected, rejected_error = App.game_camera_layout(memory);
        check(rejected_error.count > 0, "Reject truncated camera evidence without reading beyond .text.");
    }
    put(image, 0x190, cast(u32) 0x1000);
    put(image, 0x1114, cast(s32)(0x2500 - 0x1118));
    rejected, rejected_error = App.game_camera_layout(memory);
    check(rejected_error.count > 0, "Reject an out-of-code normal branch destination.");
    put(image, 0x1114, cast(s32)(0x1300 - 0x1118));
    put(image, 0x110b, cast(s32)(0x1800 - 0x110f));
    rejected, rejected_error = App.game_camera_layout(memory);
    check(rejected_error.count > 0, "Reject a mode slot in executable code.");
    put(image, 0x110b, cast(s32)(0x3008 - 0x110f));
    layout, error = App.game_camera_layout(memory);
    check(!error.count, "Restoring the fixture restores the validated layout.");
}

check_image :: (filename: string) {
    bytes, success := read_entire_file(filename);
    check(success && bytes.count >= 0x100, "Read the supplied PE file.");
    defer free(bytes);
    pe := (cast(*u32)(bytes.data+0x3c)).*;
    check(pe <= bytes.count-0x108 && (cast(*u32)(bytes.data+pe)).* == 0x4550, "Validate PE header.");
    count    := (cast(*u16)(bytes.data+pe+6)).*;
    optional := (cast(*u16)(bytes.data+pe+20)).*;
    size     := (cast(*u32)(bytes.data+pe+24+56)).*;
    headers  := (cast(*u32)(bytes.data+pe+24+60)).*;
    check(size > 0 && size < 0x10000000 && headers <= bytes.count && headers <= size, "Bound the mapped image.");
    image := NewArray(size, u8);
    defer free(image.data);
    for i: 0..cast(s64) headers-1 image[i] = bytes[i];
    for i: 0..cast(s64) count-1 {
        at := cast(s64) pe+24+optional+i*40;
        check(at <= bytes.count-40, "Bound each section header.");
        rva      := (cast(*u32)(bytes.data+at+12)).*;
        raw_size := (cast(*u32)(bytes.data+at+16)).*;
        raw      := (cast(*u32)(bytes.data+at+20)).*;
        check(cast(u64) rva+raw_size <= size && cast(u64) raw+raw_size <= cast(u64) bytes.count, "Bound each mapped section.");
        for j: 0..cast(s64) raw_size-1 image[cast(s64) rva+j] = bytes[cast(s64) raw+j];
    }
    memory: App.Process_Memory = .{handle=Win.GetCurrentProcess(), module=.{base=cast(u64) image.data,size=size}};
    layout, error := App.game_camera_layout(memory);
    check(!error.count, tprint("Camera profile: %: %", filename, error));
    print("Verified %: manager RVA=0x%, camera position=0x%\n", filename,
          formatInt(layout.manager.slot-memory.module.base,base=16),formatInt(layout.position,base=16));
    for code: layout.code for i: 0..code.count-1 {
        at := code.address-memory.module.base+cast(u64) i;
        image[at] ^= 1;
        check(!App.game_camera_code_current(memory, layout), "Camera session rejects any changed evidence byte.");
        image[at] ^= 1;
    }
    check(App.game_camera_code_current(memory, layout), "Unmodified image retains its validated profile.");
    // A render field that disagrees with update/link evidence must never be used.
    at := layout.code[4].address-memory.module.base+cast(u64) layout.code[4].count-4;
    image[at] ^= 4;
    rejected, rejected_error := App.game_camera_layout(memory);
    check(rejected_error.count > 0, "Reject inconsistent render and update field offsets.");
}

switch_scene:       string;
switch_scene_reads: s64;

read_switch_scene :: () -> (string, string) {
    switch_scene_reads += 1;
    if !switch_scene.count return "", "Scene unavailable.";
    return copy_string(switch_scene), "";
}

check_switch_catalog :: () {
    directory := tprint("%/../.build", #filepath);
    check(make_directory_if_it_does_not_exist(directory, true), "Create the isolated fixture directory.");
    filename := tprint("%/switch-%.json", directory, Win.GetCurrentProcessId());
    defer file_delete(filename);
    record := "{\"name\":\"high_entry\",\"region\":\"intro_to_3d\",\"position\":[-12.5,74,33],\"entity_id\":42}";
    source := tprint("{\"source\":{\"package\":\"levels.package\",\"scene\":\"overworld\",\"sha256\":\"%\"},\"levels\":[%]}",
                     "ad584f4b038a59669314be8cecc022442c094e8500969889d1c885a656d116d8", record);
    database: App.Solutions_Database;
    defer App.solutions_free(*database);
    check(write_entire_file(filename, source), "Write a catalog fixture.");
    error := App.level_catalog_load(*database, filename);
    check(!error.count && database.entries.count == 1, "Load an entrance from the package catalog.");
    index, lookup_error := App.level_catalog_find(*database, "HIGH_ENTRY");
    check(!lookup_error.count && index == 0 && database.entries[0].position[2] == 33 &&
          database.entries[0].position[0] == -12.5, "Case-insensitive lookup preserves negative/fractional coordinates and height.");
    for mutation: string.["", "{}", replace(source, record, "")] {
        check(write_entire_file(filename, mutation), "Write a malformed fixture.");
        error = App.level_catalog_load(*database, filename);
        check(error.count > 0 && database.entries.count == 1 && database.entries[0].name == "high_entry",
              "Failed loads preserve the owned snapshot.");
    }
    for coordinate: string.["null", "[]", "[1,2]", "[1,2,3,4]", "[null,2,3]", "[\"1\",2,3]", "[1000000.01,2,3]", "[1e999,2,3]"] {
        check(write_entire_file(filename, replace(source, "[-12.5,74,33]", coordinate)), "Write invalid coordinates.");
        error = App.level_catalog_load(*database, filename);
        check(error.count > 0, "Reject missing, wrong-type, nonfinite and out-of-range coordinates.");
    }
    for pair: [2] string.[.["\"name\":\"high_entry\"", "\"name\":\"../bad\""],
                          .["\"region\":\"intro_to_3d\"", "\"region\":\"\""],
                          .["\"entity_id\":42", "\"entity_id\":-1"],
                          .["\"entity_id\":42", "\"entity_id\":42.5"],
                          .["\"entity_id\":42", "\"entity_id\":4294967296"],
                          .["\"scene\":\"overworld\"", "\"scene\":\"mirror_21\""]] {
        check(write_entire_file(filename, replace(source, pair[0], pair[1])), "Write invalid catalog metadata.");
        check(App.level_catalog_load(*database, filename).count > 0, "Reject invalid names, scene and IDs.");
    }
    second := replace(replace(record, "high_entry", "other_entry"), ":42", ":43");
    shared := replace(source, record, tprint("%,%", record, second));
    check(write_entire_file(filename, shared), "Write distinct names sharing one coordinate.");
    check(!App.level_catalog_load(*database, filename).count && database.entries.count == 2, "Keep distinct levels at shared coordinates.");
    check(write_entire_file(filename, replace(shared, "other_entry", "HIGH_ENTRY")), "Write two entrances for one name.");
    check(!App.level_catalog_load(*database, filename).count, "Retain multiple source entrances.");
    index, lookup_error = App.level_catalog_find(*database, "high_entry");
    check(index < 0 && lookup_error.count > 0, "Reject ambiguous destination names.");
    check(write_entire_file(filename, replace(shared, ":43", ":42")), "Write duplicate source IDs.");
    check(App.level_catalog_load(*database, filename).count > 0, "Reject duplicate source IDs.");
    check(write_entire_file(filename, source), "Restore the valid fixture.");
    for name: string.["overworld", "OVERWORLD", "mirror_21", "menu", ""] {
        state: App.Console_State;
        defer App.console_deinit(*state);
        switch_scene = name;
        App.console_execute_command(*state, "SwItCh HIGH_ENTRY");
        check(state.pending_action == .SWITCH_LEVEL, "Dispatch mixed-case switch.");
        App.console_prepare_switch(*state, filename, read_switch_scene);
        accepted := equal_nocase(name, "overworld");
        check(state.pending_position_change == accepted, "Only overworld queues teleport.");
        if accepted check(state.pending_position[2] == 33 && state.pending_position_take, "Queue full height and existing TakeOrDrop behavior.");
        check(!state.pending_send.count, "Preparation injects no keys.");
    }
    {
        alias_state: App.Console_State;
        defer App.console_deinit(*alias_state);
        check(!App.console_config_parse(*alias_state.config, "go = switch;").count, "Parse the user's go alias.");
        App.console_execute_command(*alias_state, "go HIGH_ENTRY");
        switch_scene = "overworld";
        App.console_prepare_switch(*alias_state, filename, read_switch_scene);
        check(alias_state.pending_position_change && alias_state.pending_position[2] == 33,
              "go <level> uses the same validated switch path.");
    }
    for arguments: string.["", "high_entry extra"] {
        state: App.Console_State;
        defer App.console_deinit(*state);
        App.command_switch(*state, arguments);
        check(state.pending_action == .NONE, "Reject invalid argument counts.");
    }
    state: App.Console_State;
    defer App.console_deinit(*state);
    switch_scene_reads = 0;
    App.command_switch(*state, "unknown");
    App.console_prepare_switch(*state, filename, read_switch_scene);
    check(!state.pending_position_change && !switch_scene_reads, "Unknown names do not access game memory.");
    App.console_set_input(*state, "switch hi");
    App.console_complete(*state, .["high_entry"], .["custom_only"], .[]);
    check(trim(App.console_input(*state)) == "switch high_entry", "Complete catalog entrances.");
    error = App.level_catalog_load(*database, tprint("%/../data/level_catelog.json", #filepath));
    check(!error.count && database.entries.count > 0, "Load the generated runtime catalog.");
    print("Runtime catalog: % validated entrances.\n", database.entries.count);
}

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
