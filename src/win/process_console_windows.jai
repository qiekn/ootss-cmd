process_console_init :: () -> bool {
    atomic_store(*process_console_interrupted, false);
    process_console_registered = false;
    process_console_attached = false;
    process_id: u32;
    // A GUI executable does not inherit its launcher's console automatically.
    // Explorer has no console to attach to; never allocate a new one on that path.
    if !GetConsoleProcessList(*process_id, 1) {
        if !AttachConsole(ATTACH_PARENT_PROCESS) return true;
        process_console_attached = true;
    }
    // A launcher can pass down the flag that ignores Ctrl+C. Opt back in.
    SetConsoleCtrlHandler(null, 0);
    process_console_registered = SetConsoleCtrlHandler(process_console_control_handler, 1) != 0;
    return process_console_registered;
}

process_console_deinit :: () {
    if process_console_registered SetConsoleCtrlHandler(process_console_control_handler, 0);
    process_console_registered = false;
    if process_console_attached FreeConsole();
    process_console_attached = false;
}

process_console_should_exit :: () -> bool {
    return atomic_load(*process_console_interrupted);
}

#scope_file

process_console_interrupted: bool;
process_console_registered: bool;
process_console_attached: bool;

process_console_control_handler :: (control_type: u32) -> s32 #c_call {
    if control_type != CTRL_C_EVENT && control_type != CTRL_BREAK_EVENT return 0;
    // Windows calls this on its own thread. Let the main thread release input and clean up.
    atomic_store(*process_console_interrupted, true);
    return 1;
}

CTRL_C_EVENT :: 0;
CTRL_BREAK_EVENT :: 1;
ATTACH_PARENT_PROCESS: u32 : 0xffffffff;
kernel32 :: #library,system "kernel32";
SetConsoleCtrlHandler :: (handler: (control_type: u32) -> s32 #c_call, add: s32) -> s32 #foreign kernel32;
GetConsoleProcessList :: (process_ids: *u32, capacity: u32) -> u32 #foreign kernel32;
AttachConsole :: (process_id: u32) -> s32 #foreign kernel32;
FreeConsole :: () -> s32 #foreign kernel32;
