#!/usr/bin/env jai

// This is a fishing program. (Catch levels which has no solution yet)
//
// Writes no_solution_levels.txt (one level name per line) to the project root.
//
// Usage: ./find_all_no_solution_levels.jai

#run {
    error := let_us_go_fishing();

    if error then compiler_report(error);
    set_build_options_dc(.{do_output = false});
}

let_us_go_fishing :: () -> string {
    catalog\ _file := "data/level_catelog.json";
    solutions_file := "data/solutions.json";

    // Put fish in our project root.
    output_file := "no_solution_levels.txt";
    if !set_working_directory(tprint("%/../..", #filepath)) {
        return "Could not select the project directory.";
    }

    // parse JSON with Jaison module.
    success: bool;
    success=, catalog   := Json.json_parse_file(catalog_file, Catalog);          assert(success);
    success=, solutions := Json.json_parse_file(solutions_file, [..] Solutioin); assert(success);

    fish: [..] string;
    count := 0;

    for level: catalog.levels {
        found := false;
        for solutions {
            if equal_nocase(it.name, level.name) {
                found = true;
                break;
            }
        }
        if found continue;

        count += 1;
        array_add(*fish, level.name);
    }

    builder: String_Builder;
    defer free_buffers(*builder);
    for name: fish {
        append(*builder, name);
        append(*builder, "\n");
    }
    if !write_entire_file(output_file, *builder) {
        return tprint("Hey, qiekn. You need to figure why we can't write file: %\n", output_file);
    }

    print("Wrote %: % of % levels have no solution.\n", output_file, fish.count, catalog.levels.count);
    if count {
        print("% solution entries are empty and count as fish.\n", count);
    }
    return "";
}

Catalog :: struct {
    levels: [..] Item;

    Item :: struct {
        name:   string;
        region: string;
    }
}

Solutioin :: struct {
    name:     string;
    solution: string;
}


#import "Basic";
#import "Compiler";
#import "File";
#import "String";
Json :: #import,dir "../../modules/Json";
