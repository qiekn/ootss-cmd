#!/usr/bin/env jai

// Explicit live test: disable exploration fog for 120 seconds, then restore it.
#run {
    set_build_options_dc(.{do_output=false});
    args := get_build_options().compile_time_command_line;
    if args.count == 1 && args[0] == "--live" {
        error := live_test();
        if error.count compiler_report(error);
    } else print("Live fog test: jai -quiet scripts/test_fog.jai - --live\n");
}

live_test :: () -> string {
    if !process_console_init() return "Could not register Ctrl+C cleanup.";
    defer process_console_deinit();
    window := Process.process_find_window("sinking_star.exe", "Default Window Class", "Order of the Sinking Star");
    if !window return "Game window not found.";
    session: Fog.Fog_Session;
    error := Fog.fog_session_open(*session, window);
    if error.count return error;
    defer {
        restore_error := Fog.fog_session_close(*session);
        if restore_error.count print("RESTORE FAILED: %\n", restore_error);
        else print("Fog restored; original instruction verified.\n");
    }
    error = Fog.fog_session_disable(*session);
    if error.count return error;
    print("Fog disabled, PID %. Look at the game now; restoring in 120 seconds.\n", Process.process_window_pid(window));
    until := seconds_since_init() + 120;
    while seconds_since_init() < until && !process_console_should_exit() && !Fog.fog_session_exited(*session)
        sleep_milliseconds(100);
    return "";
}

#load "../src/platform/windows/console.jai";
#import "Basic";
#import "Compiler";
Win :: #import "Windows";
Fog :: #import,file "../src/game/fog_memory.jai";
Process :: #import,file "../src/platform/windows/process.jai";
