#!/usr/bin/env jai

// jai -quiet scripts/capture_map.jai -import_dir ../modules - plan <directory> xmin ymin xmax ymax z [options]
#run {
    set_build_options_dc(.{do_output=false});
    set_working_directory(tprint("%/..",#filepath));
    error := run(get_build_options().compile_time_command_line);
    if error.count compiler_report(error);
}

run :: (args: [] string) -> string {
    if !args.count || args[0]=="help" {
        print("capture_map plan <directory> xmin ymin xmax ymax z [--ground 0 --overlap .3 --settle-ms 500 --scene overworld]\n");
        print("capture_map start <directory> | status <directory> | pause | resume | cancel\n");
        return "";
    }
    if args[0]=="plan" {
        if args.count<7 || args.count%2!=1 return "Expected directory, five coordinates, then option/value pairs.";
        plan: Capture_Plan = .{scene="overworld"};
        values: [5] float64;
        for i: 0..4 {
            v,ok,rest:=string_to_float64(args[i+2]);
            if !ok || rest.count return "Invalid coordinate.";
            values[i]=v;
        }
        plan.xmin=values[0]; plan.ymin=values[1]; plan.xmax=values[2]; plan.ymax=values[3]; plan.z=values[4];
        i:s64=7;
        while i<args.count {
            defer i+=2;
            if args[i]=="--scene" { plan.scene=args[i+1]; continue; }
            v,ok,rest:=string_to_float64(args[i+1]);
            if !ok || rest.count || !is_finite(v) return "Invalid option value.";
            if args[i]=="--ground" plan.ground=v;
            else if args[i]=="--overlap" plan.overlap=v;
            else if args[i]=="--settle-ms" {
                if v<100 || v>10000 || floor(v)!=v return "Settle time must be an integer from 100 to 10000.";
                plan.settle_ms=cast(s32)v;
            } else return tprint("Unknown option: %",args[i]);
        }
        error:=capture_validate_plan(plan);
        if error.count return error;
        directory:=absolute_path(args[1]);
        if !directory.count return "Could not resolve capture directory.";
        filename:=tprint("%/plan.json",directory);
        if file_exists(filename) || file_exists(tprint("%/manifest.json",directory)) return "A plan or capture already exists; choose a new directory.";
        if !make_directory_if_it_does_not_exist(directory,true) return "Could not create capture directory.";
        error=capture_atomic_json(filename,plan);
        if !error.count print("Plan saved: %\nStart it, then focus the unobscured game.\n",filename);
        return error;
    }
    if args[0]=="status" && args.count==2 {
        directory:=absolute_path(args[1]);
        if !directory.count return "Could not resolve capture directory.";
        data,ok:=read_entire_file(tprint("%/status.json",directory));
        defer free(data);
        if !ok return "No status file yet; check the helper console for a rejected request.";
        print("%\n",data); return "";
    }
    request:string;
    if args[0]=="start" && args.count==2 {
        directory:=absolute_path(args[1]);
        if !directory.count || !file_exists(tprint("%/plan.json",directory)) return "Capture plan not found.";
        request=tprint("start %/plan.json",directory);
    }
    else if args.count==1 && (args[0]=="pause" || args[0]=="resume" || args[0]=="cancel") request=args[0];
    else return "Invalid arguments. Run with 'help' for usage.";
    window:=FindWindowW(utf8_to_wide("OOTSS Helper Console",,temp),null);
    if !window return "Start ootss-cmd.exe before sending a capture request.";
    packet: Copy_Data = .{id=0x4f4f5443,count=cast(u32)request.count,data=request.data};
    reply:u64;
    if !SendMessageTimeoutW(window,0x004a,0,cast(s64)*packet,2,2000,*reply) || reply!=1 return "The helper did not accept the request.";
    print("Request queued. Check capture status or the helper console for the result.\n");
    return "";
}

absolute_path :: (path:string) -> string {
    buffer:[32768]u16;
    count:=GetFullPathNameW(utf8_to_wide(path,,temp),buffer.count,buffer.data,null);
    if !count || count>=buffer.count return "";
    result,ok:=wide_to_utf8(buffer.data,cast(s32)count);
    return result;
}

#load "../src/game/capture_plan.jai";
#import "Basic";
#import "Compiler";
#import "String";
#import "Math";
#import "File";
#import "System";
#import "Windows_Utf8";
Win :: #import "Windows";
Copy_Data :: struct { id:u64; count:u32; data:*u8; }
user32 :: #library,system "user32";
kernel32 :: #library,system "kernel32";
FindWindowW :: (class_name:*u16,title:*u16)->Win.HWND #foreign user32;
SendMessageTimeoutW :: (window:Win.HWND,message:u32,wparam:u64,lparam:s64,flags:u32,timeout:u32,result:*u64)->s64 #foreign user32;
GetFullPathNameW :: (path:*u16,size:u32,buffer:*u16,last:**u16)->u32 #foreign kernel32;
