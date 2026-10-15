#!/usr/bin/env jai

// Merge adjacent wait tokens without expanding or reformatting other commands.
// jai -quiet scripts/merge_solution_waits.jai -import_dir ../modules - [data-directory]
#run {
    set_build_options_dc(.{do_output = false});
    if !set_working_directory(tprint("%/..", #filepath)) compiler_report("Could not select the project directory.");
    arguments := get_build_options().compile_time_command_line;
    if arguments.count > 1 compiler_report("Usage: merge_solution_waits.jai - [data-directory]");
    else {
        check_merge();
        directory := ifx arguments.count then arguments[0] else "data";
        for name: string.["solutions.json", "custom_inputs.json"] {
            error := merge_file(tprint("%/%", directory, name));
            if error.count { compiler_report(error); break; }
        }
    }
}

merge :: (source: string) -> (text: string, error: string) {
    checked, error := App.expand_send(source);
    defer free(checked);
    if error.count return "", error;
    builder: String_Builder;
    defer free_buffers(*builder);
    position: s64;
    while position < source.count {
        if source[position] != #char "_" { append(*builder, source[position]); position += 1; continue; }
        start := position;
        while position < source.count && source[position] == #char "_" {
            position += 1;
            duration, token_error := App.send_wait_token(source, *position);
            if token_error.count return "", token_error;
            while position < source.count && source[position] >= #char "0" && source[position] <= #char "9" position += 1;
        }
        fragment := slice(source, start, position - start);
        waits: [..] s32;
        defer array_free(waits);
        keys, wait_error := App.expand_send(fragment, waits = *waits);
        defer free(keys);
        if wait_error.count return "", wait_error;
        total: s64;
        for duration: waits total += duration;
        if total > 0x7fffffff return "", "A merged wait exceeds the supported duration.";
        if waits.count > 1 append(*builder, tprint("_%_", App.send_wait_seconds_text(cast(s32) total)));
        else append(*builder, fragment);
    }
    return builder_to_string(*builder), "";
}

merge_file :: (filename: string) -> string {
    if !file_exists(filename) return "";
    database: App.Solutions_Database;
    defer App.solutions_free(*database);
    error := App.solutions_load(*database, filename);
    if error.count return error;
    changed: s64;
    for *entry: database.entries {
        normalized, normalize_error := upgrade_wait_format(entry.solution);
        defer free(normalized);
        if normalize_error.count return tprint("% (%): %", filename, entry.name, normalize_error);
        merged, merge_error := merge(normalized);
        defer free(merged);
        if merge_error.count return tprint("% (%): %", filename, entry.name, merge_error);
        if merged == entry.solution continue;
        free(entry.solution);
        entry.solution = copy_string(merged);
        changed += 1;
    }
    if changed {
        error = App.solutions_write(*database, filename);
        if error.count return error;
    }
    print("Merged waits in % records: %.\n", changed, filename);
    return "";
}

// Convert the earlier angle-bracket spelling only in key sequences, never in comments.
upgrade_wait_format :: (source: string) -> (text: string, error: string) {
    builder: String_Builder;
    defer free_buffers(*builder);
    position: s64;
    while position < source.count {
        if source[position] != #char "_" || position + 1 == source.count || source[position + 1] != #char "<" {
            append(*builder, source[position]);
            position += 1;
            continue;
        }
        first   := position + 2;
        closing := first;
        while closing < source.count && source[closing] != #char ">" closing += 1;
        if closing + 1 >= source.count || source[closing + 1] != #char "_" return "", "Unclosed legacy timed wait.";
        duration, error := App.send_parse_wait_seconds(slice(source, first, closing - first));
        if error.count return "", error;
        append(*builder, tprint("_%_", App.send_wait_seconds_text(duration)));
        position = closing + 2;
    }
    return builder_to_string(*builder), "";
}

check_merge :: () {
    sources  := string.["R____U", "R___3U", "R_3.5____U", "(R____U)3 2", "R2XL4XL6U", "R_3.5_U"];
    expected := string.["R_1_U", "R_1.25_U", "R_4.25_U", "(R_1_U)3 2", "R2XL4XL6U", "R_3.5_U"];
    for source: sources {
        result, error := merge(source);
        defer free(result);
        if error.count || result != expected[it_index] compiler_report(tprint("Wait merge failed for %.", source));
        again, again_error := merge(result);
        defer free(again);
        if again_error.count || again != result compiler_report("Wait merge is not idempotent.");
    }
}

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
