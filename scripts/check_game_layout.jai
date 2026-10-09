#!/usr/bin/env jai

// Isolated PE checks. Optional EXE arguments are read as data, never executed.
// jai -quiet scripts/check_game_layout.jai -import_dir ../modules - [game.exe ...]
#run {
    set_build_options_dc(.{do_output = false});
    check_signatures();
    for filename: get_build_options().compile_time_command_line check_image(filename);
    print("PASS: % isolated scene/camera layout checks; no game writes or input.\n", checks);
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

check_image :: (filename: string) {
    bytes, success := read_entire_file(filename);
    check(success && bytes.count >= 0x100, "Read the supplied PE file.");
    defer free(bytes);
    pe := (cast(*u32)(bytes.data+0x3c)).*;
    check(pe <= bytes.count-0x108 && (cast(*u32)(bytes.data+pe)).* == 0x4550, "Validate PE header.");
    count := (cast(*u16)(bytes.data+pe+6)).*;
    optional := (cast(*u16)(bytes.data+pe+20)).*;
    size := (cast(*u32)(bytes.data+pe+24+56)).*;
    headers := (cast(*u32)(bytes.data+pe+24+60)).*;
    check(size > 0 && size < 0x10000000 && headers <= bytes.count && headers <= size, "Bound the mapped image.");
    image := NewArray(size, u8);
    defer free(image.data);
    for i: 0..cast(s64) headers-1 image[i] = bytes[i];
    for i: 0..cast(s64) count-1 {
        at := cast(s64) pe+24+optional+i*40;
        check(at <= bytes.count-40, "Bound each section header.");
        rva := (cast(*u32)(bytes.data+at+12)).*;
        raw_size := (cast(*u32)(bytes.data+at+16)).*;
        raw := (cast(*u32)(bytes.data+at+20)).*;
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

#import "Basic";
#import "Compiler";
#import "File";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
