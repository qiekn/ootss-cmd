#run {
    write_string("Hello, Jailor!\n\n");

    set_build_options_dc(.{do_output=false});
    build_windows_helper("ootss-cmd");
}

build_windows_helper :: (name: string) -> bool {
    icon := create_ico_file_from_bitmap_filename(tprint("%/data/images/icon.png", #filepath));
    defer free(icon);
    if !icon.count {
        compiler_report("Could not convert data/images/icon.png to a Windows icon.");
        return false;
    }

    workspace := compiler_create_workspace("Jail");
    if !workspace {
        log_error("The world is not ready yet!");
        return false;
    }

    // Inherit command-line settings, including optimization and module search paths.
    options := get_build_options();
    optimized := options.llvm_options.bitcode_optimization_setting > .O0;
    options.output_type = .EXECUTABLE;
    options.output_executable_name = name;
    options.output_path = ifx optimized then tprint("%/bin", #filepath) else #filepath;
    options.prevent_compile_time_calls_from_runtime = false;
    if !make_directory_if_it_does_not_exist(options.output_path) {
        compiler_report(tprint("Could not create output directory %.", options.output_path));
        return false;
    }
    set_build_options(options, workspace);

    Windows_Resources.disable_runtime_console(workspace);

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
    if optimized {
        destination := tprint("%/data", options.output_path);
        if !copy_helper_data(tprint("%/data", #filepath), destination) {
            compiler_report(tprint("Could not copy data to %.", destination));
            return false;
        }
        license_destination := tprint("%/LICENSE", options.output_path);
        if !copy_file(tprint("%/LICENSE", #filepath), license_destination) {
            compiler_report(tprint("Could not copy LICENSE to %.", license_destination));
            return false;
        }
    }
    return true;
}

copy_helper_data :: (source: string, destination: string) -> bool {
    Copy_Data :: struct { source, destination: string; success := true; }
    copy: Copy_Data = .{source = source, destination = destination};
    visitor :: (info: *File_Visit_Info, copy: *Copy_Data) {
        if !copy.success return;
        relative := slice(info.full_name, copy.source.count, info.full_name.count - copy.source.count);
        // Runtime saves belong to each installation. Rebuilding must not replace a player's bin/data/zork saves.
        if !info.is_directory && info.short_name.count >= 4 &&
           equal_nocase(slice(info.short_name, info.short_name.count - 4, 4), ".sav") {
            if equal_nocase(relative, tprint("/zork/%", info.short_name)) return;
        }
        target := tprint("%%", copy.destination, relative);
        if info.is_directory {
            copy.success = make_directory_if_it_does_not_exist(target);
            if !copy.success info.descend_into_directory = false;
        } else copy.success = copy_file(info.full_name, target);
    }
    if !make_directory_if_it_does_not_exist(destination) return false;
    visited := visit_files(source, true, *copy, visitor, visit_directories = true);
    return visited && copy.success;
}

#import "Basic";
#import "File";
#import "Compiler";
#import "File_Utilities";
#import "String";
Windows_Resources :: #import "Windows_Resources";
#import "Ico_File";
