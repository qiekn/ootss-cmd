#!/usr/bin/env jai

// Read-only diagnostics; no game input or writes.
// jai -quiet scripts/inspect_game_layout.jai -import_dir ../modules - [--discover]
#run {
    set_build_options_dc(.{do_output = false});
    error := inspect();
    if error.count compiler_report(error);
}

inspect :: () -> string {
    window := App.find_game_window();
    if !window return "Game window not found.";
    print("Game: %\n", App.process_image_path(window));
    memory, error := App.process_open_memory(window, App.GAME_EXECUTABLE);
    if error.count return error;
    defer App.process_close_memory(*memory);
    code, rva, code_error := App.process_read_module_code(memory);
    if code_error.count return code_error;
    defer free(code.data);
    print("Module size=0x%, text RVA=0x%, bytes=%\n", hex(memory.module.size), hex(rva), code.count);
    args := get_build_options().compile_time_command_line;
    if args.count > 1 || (args.count == 1 && args[0] != "--discover") return "Expected no arguments or --discover.";
    discover := args.count == 1;
    if discover inspect_roots(memory, code, rva);
    scene, scene_error := App.game_read_scene_from(memory);
    defer free(scene);
    print("Production scene: % %\n", scene, scene_error);
    position, position_error := App.game_read_position_from(memory);
    print("Production position: % %\n", position, position_error);
    reader: App.Game_Position_Reader;
    defer App.game_position_reader_close(*reader);
    reader_error := App.game_position_reader_init(*reader, memory);
    if !reader_error.count {
        sample := App.game_position_reader_sample(*reader);
        if sample.valid {
            fields, fields_error := App.game_position_layout(memory, sample.player);
            print("Controlled=%, position fields=%, error=%\n", sample.controlled_count, fields.offsets, fields_error);
        }
    }
    layout, layout_error := App.game_camera_layout(memory);
    print("Production camera: %\n", layout_error);
    if !layout_error.count {
        print("Camera profile=%, fields: position=0x%, orientation=0x%, projection=0x%, list=0x%, mode RVA=0x%\n",
              layout.profile,hex(layout.position), hex(layout.orientation), hex(layout.projection), hex(layout.cameras), hex(layout.mode-memory.module.base));
        snapshot, snapshot_error := App.game_camera_snapshot(memory, layout);
        print("Camera position=%, mode=%, error=%\n", snapshot.position, snapshot.mode, snapshot_error);
    }
    fog,fog_error := Fog.fog_inspect(window);
    print("Production fog: % %\n",fog,fog_error);
    catalog: App.Subtitles_Catalog;
    defer App.subtitles_catalog_free(*catalog);
    subtitle_error := App.subtitles_catalog_load(*catalog, App.game_subtitles_directory(),
                                               mapping_file = tprint("%/../data/subtitles.json", #filepath));
    print("Subtitles: English sections=%, Chinese sections=%, error=%\n",
          catalog.english.sections.count, catalog.chinese.sections.count, subtitle_error);
    if !scene_error.count && !subtitle_error.count {
        blocks: [..] App.Subtitle_Block;
        defer array_free(blocks);
        found := App.subtitles_select(*catalog, scene, *blocks);
        print("Current-level subtitles: level=%, found=%, blocks=%\n", scene, found, blocks.count);
    }
    return "";
}

hex :: (value: $T) -> string { return tprint("%", formatInt(value, base=16)); }

inspect_roots :: (memory: App.Process_Memory, code: [] u8, code_rva: u64) {
    dos: [64] u8;
    assert(App.process_read_memory(memory.handle, memory.module.base, *dos, dos.count));
    pe := memory.module.base + (cast(*u32)(dos.data + 0x3c)).*;
    header: [24] u8;
    assert(App.process_read_memory(memory.handle, pe, *header, header.count));
    count    := (cast(*u16)(header.data + 6)).*;
    optional := (cast(*u16)(header.data + 20)).*;
    for section_index: 0..cast(s64) count-1 {
        section: [40] u8;
        assert(App.process_read_memory(memory.handle, pe + 24 + optional + cast(u64) section_index * 40, *section, 40));
        flags := (cast(*u32)(section.data + 36)).*;
        if (flags & 0xe0000000) != 0xc0000000 continue;
        size := (cast(*u32)(section.data + 8)).*;
        rva  := (cast(*u32)(section.data + 12)).*;
        if !size || size > 64*1024*1024 || !App.process_module_contains(memory.module, memory.module.base+rva, size) continue;
        data := NewArray(size, u8);
        defer free(data.data);
        if !App.process_read_memory(memory.handle, memory.module.base + rva, data.data, size) continue;
        for offset: 0..cast(s64) size / 8-1 {
            root := (cast(*u64)(data.data + offset * 8)).*;
            if root < 0x100000000 || root & 7 || !App.process_memory_range_valid(root, 0x380) ||
               App.process_module_contains(memory.module, root, 1) continue;
            name:  [2] u64;
            bytes: [128] u8;
            if !App.process_read_memory(memory.handle, root, *name, 16) || !name[0] || name[0] > 128 ||
               !App.process_read_memory(memory.handle, name[1], *bytes, name[0]) continue;
            valid := true;
            for i: 0..cast(s64) name[0]-1 {
                c := bytes[i];
                if !(c >= #char "a" && c <= #char "z") && !(c >= #char "0" && c <= #char "9") && c != #char "_" valid = false;
            }
            if !valid continue;
            list: [2] u64;
            if !App.process_read_memory(memory.handle, root + 0x370, *list, 16) || !list[0] || list[0] > 20000 ||
               !App.process_memory_range_valid(list[1], list[0] * 8) continue;
            slot := cast(u64) rva + cast(u64) offset * 8;
            print("Root candidate slot=0x%, scene=%, objects=%\n", hex(slot), string.{data=bytes.data,count=cast(s64) name[0]}, list[0]);
            refs: s64;
            for i: 0..code.count-7 {
                if (code[i] != 0x48 && code[i] != 0x4c) || code[i+1] != 0x8b || (code[i+2] & 0xc7) != 5 continue;
                target := cast(s64) code_rva + i + 7 + (cast(*s32)(code.data + i + 3)).*;
                if target != cast(s64) slot continue;
                refs += 1;
                if refs > 60 continue;
                print("  Reference RVA=0x%: ", hex(code_rva + cast(u64) i));
                for j: 0..31 if i+j < code.count print("% ", formatInt(code[i+j], base=16, minimum_digits=2));
                print("\n");
            }
            print("  Total references: %\n", refs);
        }
    }
}

#import "Basic";
#import "Compiler";
App :: #import,file "../src/main.jai";
Fog :: #import,file "../src/game/fog_memory.jai";
