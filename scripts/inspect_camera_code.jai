#!/usr/bin/env jai

// Read-only camera evidence scan; no game input or writes.
// jai -quiet scripts/inspect_camera_code.jai -import_dir ../modules - [--gate|--render|--link]
#run {
    set_build_options_dc(.{do_output = false});
    error := inspect();
    if error.count compiler_report(error);
}

hex :: (value: $T) -> string { return tprint("%", formatInt(value, base=16)); }

matches :: (code: [] u8, pattern: [] s16) -> (offsets: [..] s64) {
    offsets: [..] s64;
    if !pattern.count || pattern.count > code.count return offsets;
    for i: 0..code.count - pattern.count {
        ok := true;
        for byte: pattern if byte >= 0 && code[i + it_index] != byte { ok = false; break; }
        if ok array_add(*offsets, i);
    }
    return offsets;
}

dump :: (code: [] u8, at: s64, count: s64, rva: u64) {
    print("  RVA=0x%:", hex(rva + cast(u64) at));
    for i: 0..count-1 {
        if i % 16 == 0 print("\n   ");
        print(" %", formatInt(code[at + i], base=16, minimum_digits=2));
    }
    print("\n");
}

inspect :: () -> string {
    window := App.find_game_window();
    if !window return "Game window not found.";
    memory, error := App.process_open_memory(window, App.GAME_EXECUTABLE);
    if error.count return error;
    defer App.process_close_memory(*memory);
    code, rva, code_error := App.process_read_module_code(memory);
    if code_error.count return code_error;
    defer free(code.data);
    print("Module base=0x%, size=0x%, text RVA=0x%, bytes=%\n",
          hex(memory.module.base), hex(memory.module.size), hex(rva), code.count);
    locator: App.Game_Manager_Locator;
    slot, slot_error := App.game_entity_manager_slot(memory, *locator);
    if slot_error.count print("Scene slot: %\n", slot_error);
    else print("Scene slot RVA=0x%\n", hex(slot - memory.module.base));

    gates := matches(code, s16.[0x49,0x8d,0xad,-1,-1,-1,-1, 0x48,0x8b,0x05,-1,-1,-1,-1,
                                0x48,0x85,0xc0, 0x0f,0x84,-1,-1,-1,-1, 0x48,0x83,0xf8,1,
                                0x0f,0x85,-1,-1,-1,-1]);
    print("\n== r13 mode gate (%): \n", gates.count);
    for at: gates {
        dump(code, at, 33, rva);
        position := (cast(*u32)(code.data + at + 3)).*;
        mode     := cast(s64) at + 14 + (cast(*s32)(code.data + at + 10)).*;
        normal   := at + 23 + cast(s64)(cast(*s32)(code.data + at + 19)).*;
        frozen   := at + 33 + cast(s64)(cast(*s32)(code.data + at + 29)).*;
        print("  position=0x%, mode RVA=0x%, normal RVA=0x%, frozen RVA=0x%\n",
              hex(position), hex(rva + cast(u64) mode), hex(rva + cast(u64) normal), hex(rva + cast(u64) frozen));
        if normal > 0 && normal < code.count {
            print("  -- normal-40 .. normal+120\n");
            dump(code, normal - 40, 160, rva);
        }
        if frozen > 0 && frozen < code.count {
            print("  -- frozen-40 .. frozen+64\n");
            dump(code, frozen - 40, 104, rva);
        }
    }
    renders := matches(code, s16.[0x4c,0x8d,0x80,-1,-1,-1,-1, 0xf3,0x0f,0x10,0x88,-1,-1,-1,-1]);
    print("\n== render lea r8 / movss xmm1 (%): \n", renders.count);
    for at: renders {
        dump(code, at - 60, 120, rva);
    }
    links := matches(code, s16.[0x4c,0x8b,0x2d,-1,-1,-1,-1, 0x49,0x8d,0x95,-1,-1,-1,-1,
                                    0x4d,0x8d,0x85,-1,-1,-1,-1, 0x31,0xc9,0xe8,-1,-1,-1,-1]);
    print("\n== link (%): \n", links.count);
    for at: links dump(code, at, 28, rva);
    return "";
}

#import "Basic";
#import "Compiler";
App :: #import,file "../src/main.jai";
