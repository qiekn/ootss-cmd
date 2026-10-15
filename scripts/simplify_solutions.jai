#!/usr/bin/env jai

// Rewrite old solution JSON with only name/note/solution, retaining a byte-for-byte backup.
#run {
    set_build_options_dc(.{do_output = false});
    if !set_working_directory(tprint("%/..", #filepath)) compiler_report("Could not select the project directory.");
    arguments := get_build_options().compile_time_command_line;
    if arguments.count > 1 compiler_report("Usage: simplify_solutions.jai - [data-directory]");
    else {
        directory := ifx arguments.count then arguments[0] else "data";
        for name: string.["solutions.json", "custom_inputs.json"] {
            error := simplify_file(tprint("%/%", directory, name));
            if error.count { compiler_report(error); break; }
        }
    }
}

simplify_file :: (filename: string) -> string {
    if !file_exists(filename) return "";
    original, read_ok := read_entire_file(filename);
    if !read_ok return tprint("Could not read %.", filename);
    defer free(original);
    database: App.Solutions_Database;
    defer App.solutions_free(*database);
    error := App.solutions_parse_json(*database, original, filename);
    if error.count return error;
    source, serialize_error := App.solutions_serialize_json(*database);
    defer free(source);
    if serialize_error.count return serialize_error;
    if source == original { print("Already simplified: %.\n", filename); return ""; }
    backup_directory := tprint("%/../.build/solution-backups-%", #filepath, Win.GetCurrentProcessId());
    if !make_directory_if_it_does_not_exist(backup_directory) return "Could not create backup directory.";
    backup_name := copy_string(filename);
    defer free(backup_name);
    for *c: backup_name if c.* == #char "/" || c.* == #char "\\" || c.* == #char ":" c.* = #char "_";
    backup := tprint("%/%", backup_directory, backup_name);
    if file_exists(backup) return tprint("Backup already exists: %. Move it before simplifying again.", backup);
    if !write_entire_file(backup, original) return tprint("Could not create backup %.", backup);
    error = App.solutions_write(*database, filename);
    if error.count return error;
    print("Simplified % records: %. Backup: %.\n", database.entries.count, filename, backup);
    return "";
}

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
