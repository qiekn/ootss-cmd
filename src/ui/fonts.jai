CONSOLE_FONT_FILE :: "Meslo-LG-Mono-Nerd-Regular.ttf";
CONSOLE_CHINESE_FONT_FILE :: "NotoSansCJKsc-Regular.otf";
SUBTITLE_ENGLISH_FONT :: "KarminaBold.otf";
SUBTITLE_ENGLISH_BUNDLED_FONT :: "Karmina-Bold.otf";
SUBTITLE_CHINESE_FONT :: "SourceHanSerifCN-SemiBold.otf";

game_font_source :: (game_directory: string, game_name: string, bundled_name: string)
                    -> (directory: string, filename: string) {
    if game_directory.count && file_exists(tprint("%/%", game_directory, game_name)) {
        return game_directory, game_name;
    }
    return "data/fonts", bundled_name;
}

get_game_font_at_size :: (game_name: string, bundled_name: string, height: s64) -> *Simp.Dynamic_Font {
    directory, filename := game_font_source(game_data_directory("fonts"), game_name, bundled_name);
    font := Simp.get_font_at_size(directory, filename, height);
    if !font && directory != "data/fonts" {
        font = Simp.get_font_at_size("data/fonts", bundled_name, height);
    }
    return font;
}

#scope_file
#import "Basic";
#import "File_Utilities";
