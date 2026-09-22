#run {
    write_string("Hello, Jailor!\n\n");

    set_build_options_dc(.{do_output=false});
    build("ootss-cmd");
}

build :: (name: string) -> bool {
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

    // Copy EXE
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

    // Copy Data
    if optimized copy_data(options.output_path);
    return true;
}

copy_data :: (output_path: string) #expand {
    source := tprint("%/data", #filepath);
    destination := tprint("%/data", output_path);
    Copy_Data :: struct {
        source : string;
        destination : string;
        success := true;
    }
    copy: Copy_Data = .{source = source, destination = destination};
    visitor :: (info: *File_Visit_Info, copy: *Copy_Data) {
        if !copy.success return;
        relative := slice(info.full_name, copy.source.count, info.full_name.count - copy.source.count);
        // Only bundle Meslo; the other fonts are loaded from the game.
        if begins_with(relative, "/fonts/") && !equal_nocase(relative, "/fonts/Meslo-LG-Mono-Nerd-Regular.ttf") {
            if info.is_directory info.descend_into_directory = false;
            return;
        }
        // Runtime saves belong to each installation. Rebuilding must not replace a player's bin/data/zork saves.
        if !info.is_directory && info.short_name.count >= 4 &&
           equal_nocase(slice(info.short_name, info.short_name.count - 4, 4), ".sav") {
           if equal_nocase(relative, tprint("/zork/%", info.short_name)) return;
        }
        target := tprint("%%", copy.destination, relative);
        if !info.is_directory {
            runtime_data := equal_nocase(relative, "/markers.json")          ||
                            equal_nocase(relative, "/position_markers.json") ||
                            equal_nocase(relative, "/solutions.json")        ||
                            equal_nocase(relative, "/custom_inputs.json");
            if runtime_data && file_exists(target) return;
            // Leave an older installation's markers available for its own migration.
            if equal_nocase(relative, "/markers.json") && file_exists(tprint("%/position_markers.json", copy.destination)) return;
            if equal_nocase(relative, "/position_markers.json") && file_exists(tprint("%/markers.json", copy.destination)) return;
        }
        if info.is_directory {
            copy.success = make_directory_if_it_does_not_exist(target);
            if !copy.success info.descend_into_directory = false;
        } else copy.success = copy_file(info.full_name, target);
    }
    if !make_directory_if_it_does_not_exist(destination) ||
       !visit_files(source, true, *copy, visitor, visit_directories = true) || !copy.success {
        compiler_report(tprint("Could not copy data to %.", destination));
        `return false;
    }
    license_destination := tprint("%/LICENSE", output_path);
    if !copy_file(tprint("%/LICENSE", #filepath), license_destination) {
        compiler_report(tprint("Could not copy LICENSE to %.", license_destination));
        `return false;
    }
    // config.rc lives next to the executable.
    // Keep an installation's edited copy; copy the default only when absent.
    config_destination := tprint("%/config.rc", output_path);
    if !file_exists(config_destination) && !copy_file(tprint("%/config.rc", #filepath), config_destination) {
        compiler_report(tprint("Could not copy config.rc to %.", config_destination));
        `return false;
    }
}

#import "Basic";
#import "File";
#import "Compiler";
#import "File_Utilities";
#import "String";
Windows_Resources :: #import "Windows_Resources";
#import "Ico_File";
