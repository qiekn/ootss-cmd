#!/usr/bin/env jai

// Read-only reflection probe: jai -quiet scripts/inspect_fog.jai -import_dir ../modules
#run {
    set_build_options_dc(.{do_output=false});
    error := inspect();
    if error.count compiler_report(error);
}

inspect :: () -> string {
    window := App.find_game_window();
    if !window return "Game window not found.";
    memory,error := App.process_open_memory(window,App.GAME_EXECUTABLE);
    if error.count return error;
    defer App.process_close_memory(*memory);
    if memory.module.size>128*1024*1024 return "Unexpected module size.";
    data := NewArray(cast(s64)memory.module.size,u8);
    defer free(data.data);
    // Unmapped PE padding stays zero; only readable module pages are examined.
    for page:0..(data.count+4095)/4096-1 {
        offset := page*4096;
        App.process_read_memory(memory.handle,memory.module.base+cast(u64)offset,data.data+offset,cast(u64)min(4096,data.count-offset));
    }
    print("Game PID %, base 0x%, module size 0x%\n",App.process_window_pid(window),hex(memory.module.base),hex(memory.module.size));
    scene: App.Game_Scene_Location;
    name,scene_error := App.game_read_scene_from(memory,location=*scene);
    defer free(name);
    print("Scene %, manager 0x%, error %\n",name,hex(scene.manager),scene_error);
    for needle:string.["volumetric_fog_%", "volumetric_fog_raymarch", "Fog_Voxelization_Params"] {
        for at:0..data.count-needle.count-1 {
            if data[at]!=needle[0] || data[at+needle.count]!=0 continue;
            matched := true;
            for c:needle if data[at+it_index]!=c { matched=false; break; }
            if !matched continue;
            print("string '%' RVA 0x%\n",needle,hex(at));
            for code:0..data.count-7 {
                if (data[code]!=0x48 && data[code]!=0x4c) || data[code+1]!=0x8d || (data[code+2]&0xc7)!=5 continue;
                target := code+7+(cast(*s32)(data.data+code+3)).*;
                if target==at print("  LEA reference RVA 0x%\n",hex(code));
            }
        }
    }
    for offset:0..(data.count-128)/8 {
        at   := offset*8;
        info := (cast(*App.Game_Entity_Type)(data.data+at)).*;
        if info.kind!=7 || !info.id || !info.size || info.size>64*1024*1024 continue;
        owner := local_name(memory.module,data,info.name_length,info.name_data);
        if !owner.count continue;
        members := (cast(*App.Game_Entity_List)(data.data+at+0x40)).*;
        if !members.count || members.count>4096 || !App.process_module_contains(memory.module,members.data,members.count*64) continue;
        for i:0..cast(s64)members.count-1 {
            member := (cast(*App.Game_Struct_Member)(data.data+cast(s64)(members.data-memory.module.base)+i*64)).*;
            field  := local_name(memory.module,data,member.name_count,member.name_data);
            if field!="fog_of_war_enabled" continue;
            if !App.process_module_contains(memory.module,member.type,32) continue;
            child      := (cast(*App.Game_Entity_Type)(data.data+cast(s64)(member.type-memory.module.base))).*;
            child_name := ifx child.kind==7 then local_name(memory.module,data,child.name_length,child.name_data) else "";
            print("type % @RVA 0x% size 0x%: % offset 0x%, flags %, kind %, size %, child %\n",owner,hex(at),hex(info.size),field,hex(member.offset),member.flags,child.kind,child.size,child_name);
        }
    }
    code, code_rva, code_error := App.process_read_module_code(memory);
    if code_error.count return code_error;
    defer free(code.data);
    scan_fog_flag_writes(code, code_rva);
    scan_fog_upload_sites(code, code_rva);
    return "";
}

print_hex :: (code: [] u8, offset: s64, count: s64) {
    for i: 0..count-1 {
        at := offset + i;
        if at < 0 || at >= code.count break;
        if i > 0 && i % 16 == 0 print("\n     ");
        print("% ", formatInt(code[at], base=16, minimum_digits=2));
    }
    print("\n");
}

scan_fog_flag_writes :: (code: [] u8, rva: u64) {
    print("flag stores preceded by minsd or followed by the parameter load:\n");
    for at: 0..code.count-15 {
        if code[at]!=0xc7 || code[at+1]!=0x84 || code[at+2]!=0x24 continue;
        if code[at+7]!=1 || code[at+8]!=0 || code[at+9]!=0 || code[at+10]!=0 continue;
        prefix   := at >= 4 && code[at-4]==0xf3 && code[at-3]==0x0f && code[at-2]==0x5d && code[at-1]==0xc1;
        follower := code[at+11]==0x48 && code[at+12]==0x8b && code[at+13]==0x94 && code[at+14]==0x24;
        if !prefix && !follower continue;
        stack := (cast(*u32)(code.data + at + 3)).*;
        print("  RVA 0x% stack=0x% minsd=% follower=%\n     ",
              hex(rva+cast(u64)at), hex(stack), prefix, follower);
        print_hex(code, max(at-12,0), 72);
    }
}

scan_fog_upload_sites :: (code: [] u8, rva: u64) {
    print("fog upload matches (complete fixed bytes):\n");
    total, shown: s64;
    for at: 0..code.count-47 {
        if code[at]!=0x48 || code[at+1]!=0x8d || code[at+2]!=0x84 || code[at+3]!=0x24 continue;
        if code[at+8]!=0x48 || code[at+9]!=0x89 || code[at+10]!=0x44 || code[at+11]!=0x24 || code[at+12]!=0x20 continue;
        if code[at+13]!=0xc6 || code[at+14]!=0x44 || code[at+15]!=0x24 || code[at+16]!=0x30 || code[at+17]!=0 continue;
        if code[at+18]!=0xc6 || code[at+19]!=0x44 || code[at+20]!=0x24 || code[at+21]!=0x28 || code[at+22]!=0 continue;
        if code[at+23]!=0x48 || code[at+24]!=0x8d || code[at+25]!=0x0d continue;
        if code[at+30]!=0x48 || code[at+31]!=0x8d || code[at+32]!=0x15 continue;
        if code[at+37]!=0x45 || code[at+38]!=0x31 || code[at+39]!=0xc0 continue;
        if code[at+40]!=0x41 || code[at+41]!=0xb9 || code[at+42]!=0xe0 || code[at+43]!=1 || code[at+44]!=0 || code[at+45]!=0 continue;
        if code[at+46]!=0xe8 continue;
        total += 1;
        if shown >= 20 continue;
        shown += 1;
        disp := (cast(*u32)(code.data + at + 4)).*;
        print("  RVA 0x% disp=0x%\n", hex(rva+cast(u64)at), hex(disp));
    }
    print("  upload matches: total=%, shown=%\n", total, shown);
}

local_name :: (module:App.Process_Module,data:[]u8,count:u64,address:u64) -> string {
    if !count || count>128 || !App.process_module_contains(module,address,count) return "";
    name: string=.{data=data.data+cast(s64)(address-module.base),count=cast(s64)count};
    for c:name if !((c>=#char "a" && c<=#char "z") || (c>=#char "A" && c<=#char "Z") ||
        (c>=#char "0" && c<=#char "9") || c==#char "_" || c==#char ".") return "";
    return name;
}
hex :: (value:$T)->string { return tprint("%",formatInt(value,base=16)); }
#import "Basic";
#import "Compiler";
#import "String";
App :: #import,file "../src/main.jai";
