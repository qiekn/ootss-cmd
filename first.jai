#import "Compiler";

build :: () {
    w := compiler_create_workspace("Jailor");
    if !w {
        write_string("The world is not ready for Jai!\n");
        return;
    }

    write_string("Hello, Jailor!\n\n");

    options := get_build_options(w);
    options.output_executable_name = "trainer";
    set_build_options(options, w);

    add_build_file("./src/main.jai", w);
    set_build_options_dc(.{do_output=false});
}

#run build();
