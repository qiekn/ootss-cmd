#!/usr/bin/env jai

// Import .refs/wikiactcs/solutions.txt (produced by the wiki's convert.jai) into
// data/solutions.json.
//   - Same-named entries: the wiki solution overwrites the stored solution;
//     the existing note is kept.
//   - Entries that only exist in the JSON are left untouched.
//   - Wiki-only levels are appended.
#run {
    set_build_options_dc(.{do_output = false});
    message := import_wiki_solutions();
    if message.count print("%\n", message);
}

WIKI_SOLUTIONS_FILE :: ".refs/wikiactcs/solutions.txt";

import_wiki_solutions :: () -> string {
    // Compile-time code runs with the script's own directory as the working
    // directory; switch to the project root so the relative data paths resolve.
    project_root := tprint("%/..", #filepath);
    if !set_working_directory(project_root) return tprint("Could not change into the project directory %.", project_root);

    text, ok := read_entire_file(WIKI_SOLUTIONS_FILE);
    if !ok return tprint("Could not read %.", WIKI_SOLUTIONS_FILE);
    defer free(text);

    db: App.Solutions_Database;
    defer App.solutions_free(*db);
    error := App.solutions_load(*db);
    if error.count return tprint("Could not load %: %", App.SOLUTIONS_FILE, error);

    replaced := 0;
    added    := 0;
    invalid  := 0;
    for raw_line: split(text, "\n") {
        line := trim(raw_line);
        if line.count == 0 continue;
        found, name, solution := split_from_left(line, #char ":");
        if !found {
            invalid += 1;
            continue;
        }
        name     = trim(name);
        solution = trim(solution);
        if !name.count || !solution.count {
            invalid += 1;
            continue;
        }
        index := App.solution_find_name(*db, name, ignore_case = true);
        if index >= 0 {
            print("replaced: %", db.entries[index].name);
            if db.entries[index].note.count print(" (kept note: %)", db.entries[index].note);
            print("\n");
            free(db.entries[index].solution);
            db.entries[index].solution = copy_string(solution);
            replaced += 1;
        } else {
            array_add(*db.entries, .{name = copy_string(name), note = "", solution = copy_string(solution)});
            added += 1;
        }
    }

    error = App.solutions_write(*db);
    if error.count return tprint("Could not write %: %", App.SOLUTIONS_FILE, error);

    // Reload once to prove the written file parses back cleanly.
    check: App.Solutions_Database;
    defer App.solutions_free(*check);
    error = App.solutions_load(*check);
    if error.count return tprint("Wrote % but it failed to reload: %", App.SOLUTIONS_FILE, error);

    return tprint("Imported wiki solutions: % replaced, % added, % invalid lines; % entries now in %.",
                  replaced, added, invalid, check.entries.count, App.SOLUTIONS_FILE);
}

#import "Basic";
#import "Compiler";
#import "File";
#import "String";
App :: #import,file "../src/main.jai";
