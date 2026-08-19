#import "Compiler";

build :: () {
    write_string("Hello, Jailor!\n\n");

    w := compiler_create_workspace("Jail");
    if !w {
        write_string("The world is not ready for Jai!\n");
        return;
    }

    options := get_build_options(w);
    options.output_executable_name = "ootss-helper";
    set_build_options(options, w);

    add_build_file("./src/main.jai", w);
    set_build_options_dc(.{do_output=false});
}

#run build();
