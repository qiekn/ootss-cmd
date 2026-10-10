#!/usr/bin/env jai

// Read-only exploration of native clock and projection controls.
#run {
    set_build_options_dc(.{do_output=false});
    error := inspect();
    if error.count compiler_report(error);
}

inspect :: () -> string {
    window       := App.find_game_window();
    memory,error := App.process_open_memory(window,App.GAME_EXECUTABLE);
    if error.count return error;
    defer App.process_close_memory(*memory);
    data,rva,data_error := App.process_read_module_section(memory,".rdata\0\0",0x40000000);
    defer free(data.data);
    if data_error.count return data_error;
    code,code_rva,code_error := App.process_read_module_code(memory);
    defer free(code.data);
    if code_error.count return code_error;
    print("PID %, module base 0x%\n",App.process_window_pid(window),hex(memory.module.base));
    layout,layout_error := App.game_camera_layout(memory);
    if !layout_error.count {
        pose,pose_error := App.game_camera_snapshot(memory,layout);
        print("Current camera position %, orientation %, FOV/near/far %, mode %, error %\n",
              pose.position,pose.orientation,pose.projection,pose.mode,pose_error);
        if !pose_error.count for i:0..cast(s64)pose.list.count-1 {
            entity := pose.entities[i];
            values: [4] float;
            if entity.size>=0x380 && App.process_read_memory(memory.handle,entity.address+0x370,*values,16)
                print("Camera id %, address 0x%, fields 370-37c %\n",entity.id,hex(entity.address),values);
        }
    } else print("Camera: %\n",layout_error);
    for needle:string.["ToggleLocalAreaMap","test_time_rate","time_rate_up","time_rate_down"] {
        for at:0..data.count-needle.count {
            if data[at]!=needle[0] || memcmp(data.data+at,needle.data,needle.count)!=0 continue;
            target := cast(s64)rva+at;
            print("String '%' RVA 0x%\n",needle,hex(target));
            for i:0..code.count-7 {
                if (code[i]!=0x48 && code[i]!=0x4c) || code[i+1]!=0x8d || (code[i+2]&0xc7)!=5 continue;
                destination := cast(s64)code_rva+i+7+(cast(*s32)(code.data+i+3)).*;
                if destination==target print("  LEA RVA 0x%\n",hex(code_rva+cast(u64)i));
            }
        }
    }
    for i:0..(data.count-0x50)/8 {
        auto_release_temp();
        info := (cast(*App.Game_Entity_Type)(data.data+i*8)).*;
        if info.kind!=7 || !info.size || info.size>0x100000 continue;
        owner   := read_name(memory,info.name_length,info.name_data);
        primary := owner=="Entity_Manager" || owner=="Settings" || owner=="Camera_Control" || contains(owner,"Time") || contains(owner,"Clock");
        members := (cast(*App.Game_Entity_List)(data.data+i*8+0x40)).*;
        if !members.count || members.count>4096 || !App.process_module_contains(memory.module,members.data,members.count*64) continue;
        if primary print("Type % size 0x% RVA 0x%\n",owner,hex(info.size),hex(rva+cast(u64)i*8));
        for j:0..cast(s64)members.count-1 {
            member: App.Game_Struct_Member;
            if !App.process_read_memory(memory.handle,members.data+cast(u64)j*64,*member,64) continue;
            field := read_name(memory,member.name_count,member.name_data);
            if !primary && field!="editor_dt_multiplier" && field!="time_passage_rate" && field!="speed_scale" continue;
            if owner!="Camera_Control" && !contains(field,"time") && !contains(field,"dt") && !contains(field,"ortho") &&
               !contains(field,"projection") && !contains(field,"fov") && !contains(field,"speed") continue;
            child: App.Game_Entity_Type;
            if !App.process_module_contains(memory.module,member.type,32) ||
               !App.process_read_memory(memory.handle,member.type,*child,32) continue;
            print("  %.% offset 0x%, kind %, size %, flags %\n",owner,field,hex(member.offset),child.kind,child.size,member.flags);
        }
    }
    return "";
}

// Temporary names are consumed before the next loop's storage is reclaimed.
read_name :: (memory:App.Process_Memory,count:u64,address:u64) -> string {
    if !count || count>128 || !App.process_module_contains(memory.module,address,count) return "";
    bytes := NewArray(cast(s64)count,u8,,temp);
    if !App.process_read_memory(memory.handle,address,bytes.data,count) return "";
    return .{data=bytes.data,count=bytes.count};
}
hex :: (value:$T)->string { return tprint("%",formatInt(value,base=16)); }
#import "Basic";
#import "Compiler";
#import "String";
App :: #import,file "../src/main.jai";
