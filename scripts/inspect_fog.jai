#!/usr/bin/env jai

// Read-only reflection probe: jai -quiet scripts/inspect_fog.jai -import_dir ../modules
#run {
    set_build_options_dc(.{do_output=false});
    error:=inspect();
    if error.count compiler_report(error);
}

inspect :: () -> string {
    window:=App.find_game_window();
    if !window return "Game window not found.";
    memory,error:=App.process_open_memory(window,App.GAME_EXECUTABLE);
    if error.count return error;
    defer App.process_close_memory(*memory);
    if memory.module.size>128*1024*1024 return "Unexpected module size.";
    data:=NewArray(cast(s64)memory.module.size,u8);
    defer free(data.data);
    // Unmapped PE padding stays zero; only readable module pages are examined.
    for page:0..(data.count+4095)/4096-1 {
        offset:=page*4096;
        App.process_read_memory(memory.handle,memory.module.base+cast(u64)offset,data.data+offset,cast(u64)min(4096,data.count-offset));
    }
    print("Game PID %, base 0x%, module size 0x%\n",App.process_window_pid(window),hex(memory.module.base),hex(memory.module.size));
    scene:App.Game_Scene_Location;
    name,scene_error:=App.game_read_scene_from(memory,location=*scene);
    defer free(name);
    print("Scene %, manager 0x%, error %\n",name,hex(scene.manager),scene_error);
    for needle:string.["volumetric_fog_%", "volumetric_fog_raymarch", "Fog_Voxelization_Params"] {
        for at:0..data.count-needle.count-1 {
            if data[at]!=needle[0] || data[at+needle.count]!=0 continue;
            matched:=true;
            for c:needle if data[at+it_index]!=c { matched=false; break; }
            if !matched continue;
            print("string '%' RVA 0x%\n",needle,hex(at));
            for code:0..data.count-7 {
                if (data[code]!=0x48 && data[code]!=0x4c) || data[code+1]!=0x8d || (data[code+2]&0xc7)!=5 continue;
                target:=code+7+(cast(*s32)(data.data+code+3)).*;
                if target==at print("  LEA reference RVA 0x%\n",hex(code));
            }
        }
    }
    for offset:0..(data.count-128)/8 {
        at:=offset*8;
        info:=(cast(*App.Game_Entity_Type)(data.data+at)).*;
        if info.kind!=7 || !info.id || !info.size || info.size>64*1024*1024 continue;
        owner:=local_name(memory.module,data,info.name_length,info.name_data);
        if !owner.count continue;
        members:=(cast(*App.Game_Entity_List)(data.data+at+0x40)).*;
        if !members.count || members.count>4096 || !App.process_module_contains(memory.module,members.data,members.count*64) continue;
        for i:0..cast(s64)members.count-1 {
            member:=(cast(*App.Game_Struct_Member)(data.data+cast(s64)(members.data-memory.module.base)+i*64)).*;
            field:=local_name(memory.module,data,member.name_count,member.name_data);
            if field!="fog_of_war_enabled" continue;
            if !App.process_module_contains(memory.module,member.type,32) continue;
            child:=(cast(*App.Game_Entity_Type)(data.data+cast(s64)(member.type-memory.module.base))).*;
            child_name:=ifx child.kind==7 then local_name(memory.module,data,child.name_length,child.name_data) else "";
            print("type % @RVA 0x% size 0x%: % offset 0x%, flags %, kind %, size %, child %\n",owner,hex(at),hex(info.size),field,hex(member.offset),member.flags,child.kind,child.size,child_name);
        }
    }
    return "";
}

local_name :: (module:App.Process_Module,data:[]u8,count:u64,address:u64) -> string {
    if !count || count>128 || !App.process_module_contains(module,address,count) return "";
    name:string=.{data=data.data+cast(s64)(address-module.base),count=cast(s64)count};
    for c:name if !((c>=#char "a" && c<=#char "z") || (c>=#char "A" && c<=#char "Z") ||
        (c>=#char "0" && c<=#char "9") || c==#char "_" || c==#char ".") return "";
    return name;
}
hex :: (value:$T)->string { return tprint("%",formatInt(value,base=16)); }
#import "Basic";
#import "Compiler";
#import "String";
App :: #import,file "../src/main.jai";
