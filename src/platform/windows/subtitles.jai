game_subtitles_directory :: (game_directory: string) -> string {
    if game_directory.count && game_directory_has_subtitles(game_directory) return game_directory;
    if game_directory_has_subtitles("data/strings/subtitles") return "data/strings/subtitles";
    return "";
}

game_subtitles_directory :: () -> string {
    return game_subtitles_directory(game_data_directory("strings/subtitles"));
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
