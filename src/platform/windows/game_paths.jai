game_data_directory :: (relative: string, configured_path: string, executable_path: string) -> string {
    directory := configured_path;
    if !directory.count directory = path_strip_filename(executable_path);
    while directory.count && (directory[directory.count - 1] == #char "/" ||
                              directory[directory.count - 1] == #char "\\") directory.count -= 1;
    if !directory.count return "";
    return tprint("%/data/%", directory, relative);
}

game_data_directory :: (relative: string) -> string {
    executable: string;
    if !console.config.game_path.count executable = process_image_path(find_game_window());
    return game_data_directory(relative, console.config.game_path, executable);
}

#scope_file
#import "Basic";
#import "String";
