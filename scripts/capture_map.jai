#!/usr/bin/env jai

// Edit these settings, then run ./scripts/capture_map.jai from MSYS2.
// Paths are relative to the project root. Each run replaces this capture.
Capture_Settings :: struct {
    directory: string = "map/capture-world";
    output: string = "map/map.png";
    disable_fog: bool = true;  // Temporarily hide exploration fog; restore the previous state afterward.
    png_max_side: s64 = 16384; // Resize the final mosaic only    ; retain full-resolution low-altitude frames.
    plan: Capture_Plan = .{
        // Retail Level_Entry bounds plus at least 10 world units of padding.
        xmin=-40, ymin=-20,
        xmax=180, ymax=170,
        z=80,
        ground=0,
        overlap=0.3,
        settle_ms=200,
        scene="overworld",
    };
}

#run {
    set_build_options_dc(.{do_output=false});
    set_working_directory(tprint("%/..",#filepath));
    error := run(get_build_options().compile_time_command_line);
    if error.count compiler_report(error);
}

run :: (args: [] string) -> string {
    if !args.count {
        settings:Capture_Settings;
        return run_plan(settings.directory,settings.plan,true,settings.output,settings.disable_fog,settings.png_max_side);
    }
    if args[0]=="help" {
        print("./scripts/capture_map.jai\n  Capture using Capture_Settings at the top of this script; replace map/map.png when complete.\n");
        print("capture_map plan <directory> xmin ymin xmax ymax z [--ground 0 --overlap .3 --settle-ms 500 --scene overworld]\n");
        print("capture_map run <directory> xmin ymin xmax ymax z [same options] [--output map/map.png]\n");
        print("  run replaces the plan and previous frames, waits, then atomically replaces the PNG.\n");
        print("capture_map start <directory> | status <directory> | pause | resume | cancel\n");
        return "";
    }
    if args[0]=="plan" || args[0]=="run" {
        if args.count<7 || args.count%2!=1 return "Expected directory, five coordinates, then option/value pairs.";
        fresh:=args[0]=="run";
        output:="map/map.png";
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
            if args[i]=="--output" && fresh { output=args[i+1]; continue; }
            v,ok,rest:=string_to_float64(args[i+1]);
            if !ok || rest.count || !is_finite(v) return "Invalid option value.";
            if args[i]=="--ground" plan.ground=v;
            else if args[i]=="--overlap" plan.overlap=v;
            else if args[i]=="--settle-ms" {
                if v<100 || v>10000 || floor(v)!=v return "Settle time must be an integer from 100 to 10000.";
                plan.settle_ms=cast(s32)v;
            } else return tprint("Unknown option: %",args[i]);
        }
        return run_plan(args[1],plan,fresh,output);
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
    error,window:=send_request(request);
    if error.count return error;
    print("Request queued. Check capture status or the helper console for the result.\n");
    return "";
}

run_plan :: (path:string,settings:Capture_Plan,fresh:bool,output:string,disable_fog:=false,png_max_side:s64=0) -> string {
    plan:=settings;
    error:=capture_validate_plan(plan);
    if error.count return error;
    if png_max_side != 0 && (png_max_side < 64 || png_max_side > 16384) return "PNG maximum side must be 64-16384, or 0 for native resolution.";
    if !path.count return "Expected a capture directory.";
    directory:=absolute_path(path);
    defer free(directory);
    if !directory.count return "Could not resolve capture directory.";
    filename:=tprint("%/plan.json",directory);
    if !fresh && (file_exists(filename) || file_exists(tprint("%/manifest.json",directory))) return "A plan or capture already exists; run the script without arguments to replace it, or use 'start' to resume it.";
    if fresh && !output.count return "Expected a PNG output filename.";
    if !make_directory_if_it_does_not_exist(directory,true) return "Could not create capture directory.";
    // The OS releases this exclusive lock even if the script is interrupted.
    lock:=Win.CreateFileW(utf8_to_wide(tprint("%/run.lock",directory),,temp),Win.GENERIC_READ | Win.GENERIC_WRITE,
                         0,null,Win.OPEN_ALWAYS);
    if lock==Win.INVALID_HANDLE_VALUE return "Capture directory is locked by another script, or is not writable.";
    defer Win.CloseHandle(lock);
    if fresh {
        stamp:Win.FILETIME;
        Win.GetSystemTimeAsFileTime(*stamp);
        plan.run_id=stamp.QuadPart;
    }
    error=capture_atomic_json(filename,plan);
    if error.count return error;
    if !fresh {
        print("Plan saved: %\nStart it, then focus the unobscured game.\n",filename);
        return "";
    }
    if !process_console_init() return "Could not register capture cancellation cleanup.";
    defer process_console_deinit();
    fog: Fog.Fog_Session;
    defer {
        restore_error := Fog.fog_session_close(*fog);
        if restore_error.count compiler_report(tprint("Fog restoration failed: %",restore_error));
        else if disable_fog print("Previous fog state restored and verified.\n");
    }
    if disable_fog {
        game := Process.process_find_window("sinking_star.exe","Default Window Class","Order of the Sinking Star");
        if !game return "Game window not found.";
        error = Fog.fog_session_open(*fog,game);
        if error.count return error;
        if process_console_should_exit() return "Capture cancelled before starting.";
        error = Fog.fog_session_disable(*fog);
        if error.count return error;
        print("Exploration fog disabled for capture.\n");
    }
    if process_console_should_exit() return "Capture cancelled before starting.";
    window:Win.HWND;
    error,window=send_request(tprint("restart %",filename),CAPTURE_RUN_COPYDATA_ID);
    if error.count return error;
    print("Fresh capture queued. Focus the unobscured game and release the keys.\n");
    wait_error:=wait_for_capture(directory,plan.run_id,window);
    defer free(wait_error);
    if wait_error.count return tprint("%",wait_error);
    error = Fog.fog_session_close(*fog);
    if error.count return error;
    return map_export_png(directory,output,plan.run_id,png_max_side);
}

send_request :: (request:string,id:u64=CAPTURE_COPYDATA_ID) -> (error:string,window:Win.HWND) {
    window:=FindWindowW(utf8_to_wide("OOTSS Helper Console",,temp),null);
    if !window return "Start ootss-cmd.exe before sending a capture request.",null;
    packet:Copy_Data=.{id=id,count=cast(u32)request.count,data=request.data};
    reply:u64;
    if !SendMessageTimeoutW(window,0x004a,0,cast(s64)*packet,2,2000,*reply) || reply!=1 {
        if id==CAPTURE_RUN_COPYDATA_ID return "Fresh capture request rejected. Rebuild/restart ootss-cmd.exe; also check for an already queued request.",null;
        return "The helper did not accept the request.",null;
    }
    return "",window;
}

// Return owned errors so per-poll temporary storage and parsed JSON can be freed.
wait_for_capture :: (directory:string,run_id:u64,window:Win.HWND) -> string {
    started:=seconds_since_init();
    received:=false;
    last_state,last_message:string;
    last_completed:s64=-1;
    defer free(last_state); defer free(last_message);
    while true {
        auto_release_temp();
        if process_console_should_exit() {
            cancel_error, target := send_request("cancel");
            return sprint("Capture interrupted. % Previous map PNG retained.",cancel_error);
        }
        if FindWindowW(utf8_to_wide("OOTSS Helper Console",,temp),null)!=window
            return copy_string("The helper closed or changed; the previous map PNG was retained.");
        bytes,read_ok:=read_entire_file(tprint("%/status.json",directory));
        defer free(bytes);
        ok,status:=Json.json_parse_string(bytes,Capture_Status);
        defer free(status.state); defer free(status.message);
        if ok && status.run_id==run_id {
            received=true;
            if status.state!=last_state || status.message!=last_message || status.completed!=last_completed {
                print("%: % (% / %)\n",status.state,status.message,status.completed,status.total);
                if status.state=="PAUSED" print("Resolve the cause, then use 'capture resume' in the helper and return to the game.\n");
                free(last_state); last_state=copy_string(status.state);
                free(last_message); last_message=copy_string(status.message);
                last_completed=status.completed;
            }
            if status.state=="DONE" return "";
            if status.state=="ERROR" || status.state=="IDLE" return sprint("Capture stopped: %. Previous map PNG retained.",status.message);
        } else if received && ok && status.run_id!=run_id return copy_string("Capture was replaced by another run; previous map PNG retained.");
        if !received && seconds_since_init()-started>10 return copy_string("No status for this run within 10 seconds. Check the helper console; previous map PNG retained.");
        sleep_milliseconds(250);
    }
    return "";
}

absolute_path :: (path:string) -> string {
    buffer:[32768]u16;
    count:=GetFullPathNameW(utf8_to_wide(path,,temp),buffer.count,buffer.data,null);
    if !count || count>=buffer.count return "";
    result,ok:=wide_to_utf8(buffer.data,cast(s32)count);
    return result;
}

Copy_Data :: struct {
    id : u64;
    count : u32;
    data : *u8;
}

#load "../src/game/capture_plan.jai";
#load "map_tiles.jai";
#load "../src/platform/windows/console.jai";

#import "Basic";
#import "Compiler";
#import "String";
#import "Math";
#import "File";
#import "System";
#import "Windows_Utf8";

Win :: #import "Windows";
Json :: #import,dir "../modules/Json";
Fog :: #import,file "../src/game/fog_memory.jai";
Process :: #import,file "../src/platform/windows/process.jai";

user32   :: #library,system "user32";
kernel32 :: #library,system "kernel32";

FindWindowW :: (class_name:*u16,title:*u16)->Win.HWND #foreign user32;
SendMessageTimeoutW :: (window:Win.HWND,message:u32,wparam:u64,lparam:s64,flags:u32,timeout:u32,result:*u64)->s64 #foreign user32;
GetFullPathNameW :: (path:*u16,size:u32,buffer:*u16,last:**u16)->u32 #foreign kernel32;
