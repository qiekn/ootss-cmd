#run {
    set_build_options_dc(.{do_output=false});
    if build_windows_helper("ootss-cmd") {
        build_windows_helper("ootss-cmd", console_program = true);
    }
}

build_windows_helper :: (name: string, console_program := false) -> bool {
    icon := create_ico_file_from_bitmap_filename(tprint("%/data/images/icon.png", #filepath));
    defer free(icon);
    if !icon.count {
        compiler_report("Could not convert data/images/icon.png to a Windows icon.");
        return false;
    }

    workspace_name := ifx console_program then tprint("%-terminal", name) else name;
    workspace := compiler_create_workspace(workspace_name);
    if !workspace {
        log_error("The world is not ready yet!");
        return false;
    }

    if !workspace return false;
    options := get_build_options(workspace);
    options.output_type = .EXECUTABLE;
    options.output_executable_name = name;
    options.output_path = ifx console_program then tprint("%/.build", #filepath) else #filepath;
    import_paths := NewArray(options.import_path.count + 1, string);
    import_paths[0] = tprint("%/modules", #filepath);
    for path: options.import_path import_paths[it_index + 1] = path;
    options.import_path = import_paths;
    options.prevent_compile_time_calls_from_runtime = false;
    set_build_options(options, workspace);
    if !console_program Windows_Resources.disable_runtime_console(workspace);

    compiler_begin_intercept(workspace);
    add_build_file(tprint("%/src/main.jai", #filepath), workspace);
    executable: string;
    defer free(executable);
    succeeded := false;
    while true {
        message := compiler_wait_for_message();
        if message.kind == .PHASE {
            phase := cast(*Message_Phase) message;
            if phase.phase == .POST_WRITE_EXECUTABLE && !phase.executable_write_failed {
                executable = copy_string(tprint("%/%.exe", options.output_path, name));
            }
        }
        if message.kind == .COMPLETE {
            complete := cast(*Message_Complete) message;
            succeeded = complete.error_code == .NONE;
            break;
        }
    }
    compiler_end_intercept(workspace);
    if !succeeded || !executable.count return false;
    if !Windows_Resources.set_icon_by_data(executable, icon, resource_id = 2) {
        compiler_report(tprint("Could not embed the application icon in %.", executable));
        return false;
    }
    if console_program {
        // Windows shells prefer .com over .exe and wait for this console build.
        destination := tprint("%/%.com", #filepath, name);
        if !copy_file(executable, destination) {
            compiler_report(tprint("Could not write the terminal executable %. Close it before rebuilding.", destination));
            return false;
        }
    }
    return true;
}

#import "Basic";
#import "Compiler";
#import "File_Utilities";
Windows_Resources :: #import "Windows_Resources";
#import "Ico_File";
