CONSOLE_FONT_FILE             :: "Meslo-LG-Mono-Nerd-Regular.ttf";
CONSOLE_CHINESE_FONT_FILE     :: "NotoSansCJKsc-Regular.otf";
SUBTITLE_ENGLISH_FONT         :: "KarminaBold.otf";
SUBTITLE_ENGLISH_BUNDLED_FONT :: "Karmina-Bold.otf";
SUBTITLE_CHINESE_FONT         :: "SourceHanSerifCN-SemiBold.otf";

game_font_source :: (game_directory: string, game_name: string, bundled_name: string)
                    -> (directory: string, filename: string) {
    if game_directory.count && file_exists(tprint("%/%", game_directory, game_name)) {
        return game_directory, game_name;
    }
    return "data/fonts", bundled_name;
}

get_game_font_at_size :: (game_name: string, bundled_name: string, height: s64) -> *Simp.Dynamic_Font {
    directory, filename := game_font_source(game_data_directory("fonts"), game_name, bundled_name);
    font                := get_game_font_file(directory, filename, height);
    if !font && directory != "data/fonts" {
        font = get_game_font_file("data/fonts", bundled_name, height);
    }
    return font;
}

get_game_font_file :: (directory: string, filename: string, height: s64) -> *Simp.Dynamic_Font {
    absolute, okay := get_absolute_path(tprint("%/%", directory, filename));
    if !okay || !file_exists(absolute) return null;
    path_overwrite_separators(absolute, #char "/");
    // Simp.get_font_at_size ignores directory in its cache key. Keep a small
    // path-aware index over fonts owned by Simp instead of freeing shared fonts.
    for entry: game_font_cache {
        if entry.height == height && equal_nocase(entry.path, absolute) return entry.font;
    }
    font := Simp.load_font(directory, filename, height);
    if font array_add(*game_font_cache, .{copy_string(absolute), height, font});
    return font;
}

game_font_cache_deinit :: () {
    for entry: game_font_cache free(entry.path);
    array_free(game_font_cache);
}

console_reload_game_fonts :: (state: *Console_State) {
    if console_font_height > 0 {
        font := get_game_font_at_size(CONSOLE_CHINESE_FONT_FILE, CONSOLE_CHINESE_FONT_FILE, console_font_height);
        if font console_chinese_font = font;
        else console_config_message(state, "The new game_path has no console Chinese font; keeping the loaded font.", .ERROR);
    }
    if subtitles_view.english_font {
        error := subtitles_view_load_fonts(*subtitles_view, console_font_dpi, subtitles_game_height(),
                                            state.config.subtitle_font_size, force = true);
        if error.count console_config_message(state, tprint("% Keeping the loaded subtitle fonts.", error), .ERROR);
    }
    hud.info.font  = null;
    hud.toast.font = null;
    hud.next_frame = 0;
}

#scope_file

// Font resources are owned by Simp; only the copied keys and array are ours.
Game_Font_Cache_Entry :: struct { path: string; height: s64; font: *Simp.Dynamic_Font; }
game_font_cache: [..] Game_Font_Cache_Entry;
