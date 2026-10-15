#!/usr/bin/env jai

// Simulate engine updates after teleport; use only this process's synthetic memory.
#run {
    set_build_options_dc(.{do_output = false});
    check_switch_handoff();
    check_view_movement();
    print("PASS: % switch handoff/selection checks; no game writes or input.\n", checks);
}

checks: s64;
check :: (condition: bool, message: string) {
    checks += 1;
    if !condition { compiler_report(message); assert(condition); }
}

put :: (bytes: [] u8, offset: s64, value: $T) {
    assert(offset >= 0 && offset + size_of(T) <= bytes.count);
    (cast(*T)(bytes.data + offset)).* = value;
}

Fixture_Entity :: struct {
    position:  App.Game_Position;
    sentinel:  u32 = 0xa55a5aa5;
    padding:   [0xe0] u8;
    manager:   u64;
    padding_2: [16] u8;
    type:      u64;
    remaining: [0x540] u8;
}
#assert(size_of(Fixture_Entity) == 0x650);

Fixture_Manager :: struct {
    padding: [0x370] u8;
    objects: App.Game_Entity_List;
    camera:  [0x400] u8;
}

Fixture :: struct {
    image:    [] u8;
    managers: [2] Fixture_Manager;
    entities: [6] Fixture_Entity;
    lists:    [2] [6] u64;
    memory:   App.Process_Memory;
}

fixture_signature :: (fixture: *Fixture, instruction: s64, slot: s64) {
    // A real x64 RIP-relative load followed by the current-level check.
    bytes := u8.[0x4c, 0x8b, 0x35, 0, 0, 0, 0, 0x49, 0x83, 0xbe, 0xa8, 0x0d, 0, 0, 2];
    for byte: bytes fixture.image[instruction + it_index] = byte;
    put(fixture.image, instruction + 3, cast(s32)(slot - instruction - 7));
}

fixture_init :: (fixture: *Fixture, image_size: s64 = 0x5000) {
    fixture.image = NewArray(image_size, u8);
    base := cast(u64) fixture.image.data;
    fixture.memory = .{handle = Win.GetCurrentProcess(), module = .{base = base, size = cast(u64) fixture.image.count}};
    // Minimal mapped PE32+ image, with a bounded executable .text section.
    put(fixture.image, 0, cast(u16) 0x5a4d);
    put(fixture.image, 0x3c, cast(u32) 0x80);
    put(fixture.image, 0x80, cast(u32) 0x4550);
    put(fixture.image, 0x84, cast(u16) 0x8664);
    put(fixture.image, 0x86, cast(u16) 1);
    put(fixture.image, 0x94, cast(u16) 0xf0);
    put(fixture.image, 0x98, cast(u16) 0x20b);
    for byte: ".text" fixture.image[0x188 + it_index] = byte;
    put(fixture.image, 0x190, cast(u32) 0x200);
    put(fixture.image, 0x194, cast(u32) 0x1000);
    put(fixture.image, 0x1ac, cast(u32) 0x60000020);
    fixture_signature(fixture, 0x1010, 0x2200);
    put(fixture.image, 0x2200, cast(u64) *fixture.managers[0]);
    put(fixture.image, 0x2300, cast(u64) *fixture.managers[1]);
    // Two different entity types, including a similarly prefixed non-player name.
    put(fixture.image, 0x3000, cast(u32) 7);
    put(fixture.image, 0x3008, cast(u32) 0x650);
    put(fixture.image, 0x3010, cast(u64) 3);
    put(fixture.image, 0x3018, base + 0x3200);
    for byte: "Guy" fixture.image[0x3200 + it_index] = byte;
    put(fixture.image, 0x3100, cast(u32) 7);
    put(fixture.image, 0x3108, cast(u32) 0x650);
    put(fixture.image, 0x3110, cast(u64) 6);
    put(fixture.image, 0x3118, base + 0x3210);
    for byte: "Guyish" fixture.image[0x3210 + it_index] = byte;
    fixture.entities[0].position = float.[80, 79, 0];
    fixture.entities[1].position = float.[124, 73, 0];
    fixture.entities[2].position = float.[6, 3, 0];
    for *entity: fixture.entities {
        entity.manager = cast(u64) *fixture.managers[ifx it_index == 1 then 1 else 0];
        entity.type    = base + cast(u64)(ifx it_index == 2 then 0x3100 else 0x3000);
        (cast(*u16)(cast(*u8) entity + 0x5c)).* = 4;
        (cast(*u32)(cast(*u8) entity + 0x100)).* = cast(u32)(100 + it_index);
    }
    // Background Guy and unreadable entries must not replace the active scene's Guy.
    fixture.lists[0] = u64.[0, 1, cast(u64) *fixture.entities[1], cast(u64) *fixture.entities[2], cast(u64) *fixture.entities[0], 0];
    fixture.lists[1] = u64.[cast(u64) *fixture.entities[1], 0, 0, 0, 0, 0];
    for *manager: fixture.managers manager.objects = .{count = 6, data = cast(u64) fixture.lists[it_index].data};
    fixture_position_metadata(fixture);
}

// Synthetic mapped PE/type metadata and full-size entities; never touch the game.
fixture_metadata_name :: (fixture: *Fixture, cursor: *s64, name: string) -> u64 {
    start := cursor.*;
    for byte: name fixture.image[start + it_index] = byte;
    cursor.* += name.count + 1;
    return fixture.memory.module.base + cast(u64) start;
}

fixture_metadata_type :: (fixture: *Fixture, cursor: *s64, rva: s64, name: string, size: u32,
                          members: s64 = 0, count: u64 = 0, kind: u32 = 7) {
    info: App.Game_Entity_Type = .{kind = kind, size = size, name_length = cast(u64) name.count,
                                  name_data = fixture_metadata_name(fixture, cursor, name)};
    put(fixture.image, rva, info);
    list: App.Game_Entity_List = .{count = count, data = fixture.memory.module.base + cast(u64) members};
    if kind == 7 put(fixture.image, rva + 0x40, list);
}

fixture_metadata_member :: (fixture: *Fixture, cursor: *s64, rva: s64, name: string, type_rva: u64, offset: s64) {
    member: App.Game_Struct_Member = .{name_count = cast(u64) name.count,
        name_data = fixture_metadata_name(fixture, cursor, name), type = fixture.memory.module.base + type_rva, offset = offset};
    put(fixture.image, rva, member);
}

fixture_position_metadata :: (fixture: *Fixture) {
    cursor: s64 = 0x4000;
    fixture_metadata_type(fixture, *cursor, 0x3000, "Guy", 0x650, 0x3400, 3);
    fixture_metadata_type(fixture, *cursor, 0x3300, "Entity", 0x338, 0x3500, 2);
    fixture_metadata_type(fixture, *cursor, 0x3600, "Undoable_Entity_Data", 0xb0, 0x3700, 3);
    fixture_metadata_type(fixture, *cursor, 0x3800, "Vector3", 12, 0x3900, 3);
    fixture_metadata_type(fixture, *cursor, 0x3a00, "float", 4, kind = 1);
    fixture_metadata_type(fixture, *cursor, 0x3b00, "Status_Flags", 2, kind = 11);
    fixture_metadata_type(fixture, *cursor, 0x3c00, "", 2, kind = 0);
    put(fixture.image, 0x3018, fixture.memory.module.base + 0x3200);
    put(fixture.image, 0x3b20, fixture.memory.module.base + 0x3c00);
    enum_names  := string.["DEAD", "FALLING", "ACTIVE", "ON_EXIT", "TRANSMUTING"];
    enum_values := u64.[1, 2, 4, 16, 32];
    put(fixture.image, 0x3b28, App.Game_Entity_List.{count = 5, data = fixture.memory.module.base + 0x3d00});
    put(fixture.image, 0x3b38, App.Game_Entity_List.{count = 5, data = fixture.memory.module.base + 0x3d80});
    // The real Status_Flags is a plain enum (enum_type_flags == 0).
    put(fixture.image, 0x3b4a, cast(u16) 0);
    for name: enum_names {
        put(fixture.image, 0x3d00 + it_index * 16,
            App.Game_Entity_List.{count = cast(u64) name.count, data = fixture_metadata_name(fixture, *cursor, name)});
        put(fixture.image, 0x3d80 + it_index * 8, enum_values[it_index]);
    }
    fixture_metadata_member(fixture, *cursor, 0x3400, "entity", 0x3300, 0);
    fixture_metadata_member(fixture, *cursor, 0x3440, "velocity", 0x3800, 0x338);
    fixture_metadata_member(fixture, *cursor, 0x3480, "pre_move_position", 0x3800, 0x350);
    fixture_metadata_member(fixture, *cursor, 0x3500, "undoable_data", 0x3600, 0);
    fixture_metadata_member(fixture, *cursor, 0x3540, "output_position", 0x3800, 0x1d8);
    fixture_metadata_member(fixture, *cursor, 0x3700, "position", 0x3800, 0);
    fixture_metadata_member(fixture, *cursor, 0x3740, "visual_position", 0x3800, 0xa0);
    fixture_metadata_member(fixture, *cursor, 0x3780, "status_flags", 0x3b00, 0x5c);
    for name: string.["x", "y", "z"] fixture_metadata_member(fixture, *cursor, 0x3900 + it_index * 64, name, 0x3a00, it_index * 4);
    scene := "overworld";
    (cast(*App.Game_Entity_List) *fixture.managers[0]).* = .{count = cast(u64) scene.count, data = cast(u64) scene.data};
}

Switch_Update :: enum { READY; MOVED; SCENE; ACTIVE; LIST; LIST_REALLOC; ID; OWNER; TYPE; CANCEL; HOLD_CANCEL; }
Switch_Test   :: struct {
    fixture:                     *Fixture;
    mode:                        Switch_Update;
    presses, releases, settling: s64;
}
switch_test: Switch_Test;

switch_emit :: (scan: u16, up: bool, extended: bool) -> (bool, string) {
    check(scan == 0x2f && !extended, "Send only the configured V key.");
    if up switch_test.releases += 1;
    else {
        check(switch_test.settling == 1, "Native settling completes before TakeOrDrop.");
        switch_test.presses += 1;
    }
    return true, "";
}

switch_wait :: (milliseconds: s32, target: Win.HWND, poll: () -> bool) -> string {
    check(target == cast(Win.HWND) 1, "Retain the original input target.");
    fixture := switch_test.fixture;
    if milliseconds == 100 {
        switch_test.settling += 1;
        // ON_EXIT changes while ACTIVE, entity identity and position stay intact.
        (cast(*u16)(cast(*u8) *fixture.entities[0] + 0x5c)).* = 4 | 16;
        if switch_test.mode == {
            case .MOVED; fixture.entities[0].position[1] += 1;
            case .SCENE;
                name := "mirror_1";
                (cast(*App.Game_Entity_List) *fixture.managers[0]).* = .{count = cast(u64) name.count, data = cast(u64) name.data};
            case .ACTIVE; (cast(*u16)(cast(*u8) *fixture.entities[0] + 0x5c)).* = 16;
            case .LIST; fixture.lists[0][5] = cast(u64) *fixture.entities[3];
            case .LIST_REALLOC;
                fixture.lists[1] = fixture.lists[0];
                fixture.managers[0].objects = .{count = 5, data = cast(u64) fixture.lists[1].data};
            case .ID; (cast(*u32)(cast(*u8) *fixture.entities[0] + 0x100)).* += 1;
            case .OWNER; fixture.entities[0].manager = cast(u64) *fixture.managers[1];
            case .TYPE; fixture.entities[0].type = fixture.entities[2].type;
            case .CANCEL; return "Cancelled during settling.";
        }
    }
    if milliseconds == 50 && switch_test.mode == .HOLD_CANCEL return "Cancelled during hold.";
    return "";
}

check_switch_handoff :: () {
    for mode: Switch_Update.[.READY, .MOVED, .SCENE, .ACTIVE, .LIST, .LIST_REALLOC, .ID, .OWNER, .TYPE, .CANCEL, .HOLD_CANCEL] {
        fixture: Fixture;
        fixture_init(*fixture);
        defer free(fixture.image.data);
        reader: App.Game_Position_Reader;
        defer App.game_position_reader_close(*reader);
        player:      App.Game_Player_Location;
        locator:     App.Game_Manager_Locator;
        destination: App.Game_Position = .[94, 68, 0];
        error, changed := App.game_write_position_to(fixture.memory, destination, instant = true, required_scene = "overworld",
                                                      written_player = *player, locator = *locator);
        check(!error.count && changed, "Validate and complete the position write before input.");
        check(!App.game_position_reader_init(*reader, fixture.memory).count, "Initialize an independent reader for selection checks.");
        check(App.game_position_reader_sample(*reader).valid, "Acquire a validated controlled set.");
        resolutions := reader.resolutions;
        version     := reader.selection_version;
        for flags: u16.[4 | 16, 4 | 2, 4 | 32, 4] {
            (cast(*u16)(cast(*u8) *fixture.entities[0] + 0x5c)).* = flags;
            sample := App.game_position_reader_sample(*reader, allow_resolve = false);
            check(sample.valid && sample.selection_version == version && reader.resolutions == resolutions,
                  "Non-ACTIVE status changes do not change selection or trigger a rescan.");
        }
        switch_test = .{fixture = *fixture, mode = mode};
        result := App.game_switch_take(fixture.memory, locator, player, destination, App.game_keymap_defaults().take,
                                       cast(Win.HWND) 1, 0, emit = switch_emit, wait = switch_wait);
        if mode == .READY || mode == .ACTIVE || mode == .LIST || mode == .LIST_REALLOC {
            check(result.success && result.sent_keys == 1 && switch_test.presses == 1 && switch_test.releases == 1,
                  "Native flags and unrelated world-list updates still permit exactly one V press/release.");
        } else if mode == .HOLD_CANCEL {
            check(!result.success && switch_test.presses == 1 && switch_test.releases == 1,
                  "Cancellation after keydown always releases V.");
        } else {
            check(!result.success && !result.sent_keys && !switch_test.presses && !switch_test.releases,
                  "Real target position/scene/identity changes and cancellation never send V.");
            if mode == .MOVED {
                check(contains(result.error, "(94, 68, 0)") && contains(result.error, "(94, 69, 0)"),
                      "A real position mismatch reports both target and actual coordinates.");
                check(fixture.entities[0].position[1] == 69, "A failed handoff never teleports again or rolls back.");
            }
        }
    }
}

check_view_movement :: () {
    fixture: Fixture;
    fixture_init(*fixture, 0x10000);
    defer free(fixture.image.data);
    base := fixture.memory.module.base;
    // Add writable PE data for the camera mode and reflected camera metadata.
    put(fixture.image, 0x86, cast(u16) 2);
    put(fixture.image, 0x1b8, cast(u32) 0xe000);
    put(fixture.image, 0x1bc, cast(u32) 0x2000);
    put(fixture.image, 0x1d4, cast(u32) 0xc0000040);
    locator: App.Game_Manager_Locator;
    slot, error := App.game_entity_manager_slot(fixture.memory, *locator);
    check(!error.count, "Resolve the synthetic camera/player scene.");
    layout: App.Game_Camera_Layout = .{manager = locator, mode = base + 0x2208,
        cameras = 0x538, position = 0x600, orientation = 0x618, projection = 0x628};
    for *code: layout.code {
        at := 0x1100 + it_index;
        fixture.image[at] = 0x90;
        code.address = base + cast(u64) at;
        code.count   = 1;
        code.bytes[0]    = 0x90;
    }
    cursor: s64 = 0x5800;
    fixture_metadata_type(*fixture, *cursor, 0x5000, "Camera_Control", 0x650, 0x5100, 4);
    fixture_metadata_member(*fixture, *cursor, 0x5100, "entity", 0x3300, 0);
    fixture_metadata_member(*fixture, *cursor, 0x5140, "fov_vertical", 0x3a00, 0x600);
    fixture_metadata_member(*fixture, *cursor, 0x5180, "z_near", 0x3a00, 0x604);
    fixture_metadata_member(*fixture, *cursor, 0x51c0, "z_far", 0x3a00, 0x608);
    // Entity contains the reflected Entity_Manager pointer used by camera validation.
    put(fixture.image, 0x3340, App.Game_Entity_List.{count = 3, data = base + 0x3500});
    fixture_metadata_member(*fixture, *cursor, 0x3580, "entity_manager", 0x5700, 0xf0);
    fixture_metadata_type(*fixture, *cursor, 0x5600, "Entity_Manager", cast(u32) size_of(Fixture_Manager));
    fixture_metadata_type(*fixture, *cursor, 0x5700, "", 8, kind = 4);
    put(fixture.image, 0x5710, base + 0x5600);
    fixture.entities[5].type = base + 0x5000;
    put(fixture.image, 0x5500, cast(u64) *fixture.entities[5]);
    manager_bytes: [] u8 = .{data = cast(*u8) *fixture.managers[0], count = size_of(Fixture_Manager)};
    put(manager_bytes, 0x538, App.Game_Entity_List.{count = 1, data = base + 0x5500});
    put(manager_bytes, 0x600, float.[50, 60, 30]);
    put(manager_bytes, 0x618, App.game_camera_orientation(PI64, -PI64 / 4));
    put(manager_bytes, 0x628, float.[1, 0.1, 1000]);
    // Two selected characters retain their relative spacing under a rotated view.
    fixture.entities[0].position = .[10, 20, 0];
    fixture.entities[3].position = .[12, 23, 0];
    fixture.lists[0][0] = cast(u64) *fixture.entities[3];
    snapshot: App.Game_Camera_Snapshot;
    snapshot, error = App.game_camera_snapshot(fixture.memory, layout);
    check(!error.count, "The synthetic current camera passes full metadata validation.");
    changed: bool;
    error, changed = App.game_write_position_to(fixture.memory, .[0, 1, 0], relative = true, instant = true,
                                                locator = *locator, view_relative = true, camera_layout = *layout);
    check(!error.count && changed, "View movement uses the same validated group writer.");
    check(fixture.entities[0].position[0] == 9 && fixture.entities[0].position[1] == 20,
          "Screen up in the rotated camera moves along world negative X.");
    check(fixture.entities[3].position[0] == 11 && fixture.entities[3].position[1] == 23,
          "View movement preserves spacing for every selected character.");
    // Centering uses the shared anchor, even when the camera begins far away.
    App.freecam.session = .{memory = fixture.memory, layout = layout, original = snapshot,
        position = snapshot.position, orientation = snapshot.orientation, owns_mode = true, settled = true};
    put(fixture.image, 0x2208, cast(s64) App.GAME_CAMERA_FROZEN_MODE);
    error, changed = App.freecam_center_topdown();
    check(!error.count && changed && App.freecam.session.position[0] == 9 && App.freecam.session.position[1] == 20 &&
          App.freecam.session.position[2] == 30, "Topdown centers above the actual selected anchor while retaining altitude.");
    error, changed = App.game_write_position_to(fixture.memory, .[1, 0, 0], relative = true, instant = true,
                                                locator = *locator, view_relative = true, camera_layout = *layout);
    check(!error.count && changed && fixture.entities[0].position[0] == 10,
          "Noclip-style movement still works while the native camera is frozen.");
    pose, pose_error := App.game_camera_read_session(*App.freecam.session);
    check(!pose_error.count && App.game_camera_pose_unchanged(*App.freecam.session, pose),
          "Moving the player leaves the locked camera untouched.");
    App.freecam = .{};
    put(manager_bytes, 0x618, float.[0, 0, 0, 0]);
    error, changed = App.game_write_position_to(fixture.memory, .[0, 1, 0], relative = true, instant = true,
                                                locator = *locator, view_relative = true, camera_layout = *layout);
    check(error.count > 0 && !changed && fixture.entities[0].position[0] == 10,
          "An invalid camera never falls back to guessed coordinates or partially moves a player.");
    error, changed = App.game_write_position_to(fixture.memory, .[0, 1, 0], relative = true, instant = true, locator = *locator);
    check(!error.count && changed && fixture.entities[0].position[1] == 21,
          "Explicit world offsets work independently of camera availability.");
    // A valid camera belonging to another manager must not direct these players.
    other_bytes: [] u8 = .{data = cast(*u8) *fixture.managers[1], count = size_of(Fixture_Manager)};
    for byte: manager_bytes other_bytes[it_index] = byte;
    put(other_bytes, 0x618, App.GAME_CAMERA_TOPDOWN);
    fixture.entities[5].manager = cast(u64) *fixture.managers[1];
    fixture_signature(*fixture, 0x1040, 0x2300);
    layout.manager.slot        = base + 0x2300;
    layout.manager.instruction = base + 0x1040;
    for i: 0..layout.manager.count-1 layout.manager.bytes[i] = fixture.image[0x1040 + i];
    snapshot, error = App.game_camera_snapshot(fixture.memory, layout);
    check(!error.count, "The other scene's synthetic camera is independently valid.");
    error, changed = App.game_write_position_to(fixture.memory, .[0, 1, 0], relative = true, instant = true,
                                                locator = *locator, view_relative = true, camera_layout = *layout);
    check(error.count > 0 && !changed && fixture.entities[0].position[1] == 21,
          "Camera and player scene mismatch rejects movement before any write.");
}

#import "Basic";
#import "Math";
#import "Compiler";
#import "String";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
