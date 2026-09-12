game_subtitles_directory :: () -> string {
    // Follow the running game so both the demo and other Steam library locations work.
    executable := process_image_path(find_game_window());
    if executable.count {
        end: s64;
        for c: executable if c == #char "/" || c == #char "\\" end = it_index;
        path := tprint("%/data/strings/subtitles", slice(executable, 0, end));
        if game_directory_has_subtitles(path) return path;
    }
    for path: string.["data/strings/subtitles", GAME_SUBTITLES_DIRECTORY] {
        if game_directory_has_subtitles(path) return path;
    }
    return "";
}

#scope_file
#import "Basic";
#import "String";
#import "File";

game_directory_has_subtitles :: (path: string) -> bool {
    for name: string.["en.subtitles", "s-cn.subtitles", "ch.subtitles", "ch-subtitles"] {
        if file_exists(tprint("%/%", path, name)) return true;
    }
    return false;
}

GAME_SUBTITLES_DIRECTORY :: "E:/SteamLibrary/steamapps/common/Order of the Sinking Star Demo/data/strings/subtitles";
