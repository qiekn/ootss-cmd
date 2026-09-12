SUBTITLE_ENGLISH_FONT :: "Karmina-Bold.otf";
SUBTITLE_CHINESE_FONT :: "SourceHanSerifCN-SemiBold.otf";
SUBTITLE_CONTENT_WIDTH_PERCENT :: 80;
SUBTITLE_FONT_REFERENCE_WIDTH :: 1920;
SUBTITLE_FONT_REFERENCE_HEIGHT :: 36;

Subtitle_Draw_Text :: struct {
    text: string;
    font: *Simp.Dynamic_Font;
    color: u32;
    x, baseline, clip_left, clip_right: s32;
}

Subtitles_View :: struct {
    catalog: Subtitles_Catalog;
    blocks: [..] Subtitle_Block;
    comments: bool;
    hide_speakers: bool;
    language: Console_Subtitle_Language;
    text: [..] Subtitle_Draw_Text;
    english_font, chinese_font, small_font, small_chinese_font: *Simp.Dynamic_Font;
    dpi, content_left, layout_width, content_height, viewport_height: s32;
    font_height, line_height, small_line_height: s32;
    scroll, max_scroll: float64;
}

subtitles_view: Subtitles_View;

console_open_subtitles :: (console: *Console_State) {
    next: Subtitles_View;
    defer subtitles_view_free(*next);
    level := console.pending_subtitle_level;
    database: Solutions_Database;
    defer solutions_free(*database);
    if !level.count {
        position, error := game_read_position();
        if error.count {
            console_write(console, error, .ERROR);
            console_write(console, "Use show subtitles <level_name>, for example: show subtitles mirror_6.", .INFO);
            return;
        }
        error = solutions_load(*database, answer_file = "");
        if error.count { console_write(console, error, .ERROR); return; }
        index := solution_find_position(*database, position);
        if index < 0 {
            console_write(console, tprint("No level matches position %. Use show subtitles <level_name>.",
                                         game_position_text(position)), .ERROR);
            return;
        }
        level = database.entries[index].name;
    }
    directory := game_subtitles_directory();
    if !directory.count {
        console_write(console, "Could not find data/strings/subtitles in the game installation.", .ERROR);
        return;
    }
    next.language = console.pending_subtitle_language;
    error := subtitles_catalog_load(*next.catalog, directory,
                                    load_english = next.language != .CHINESE, load_chinese = next.language != .ENGLISH);
    if error.count { console_write(console, error, .ERROR); return; }
    if !subtitles_select(*next.catalog, level, *next.blocks) {
        console_write(console, tprint("No subtitles found for %. Use Tab to complete a subtitle level name.", level), .ERROR);
        return;
    }
    next.comments = console.pending_subtitle_comments;
    next.hide_speakers = console.pending_subtitle_hide_speakers;
    error = subtitles_view_load_fonts(*next, console_font_dpi, overlay.bounds.right - overlay.bounds.left);
    if error.count { console_write(console, error, .ERROR); return; }

    subtitles_view_free(*subtitles_view);
    subtitles_view = next;
    next = .{};
    command_clear(console, "");
    console.show_subtitles = true;
    console.reveal_output = true;
}

subtitles_view_load_fonts :: (view: *Subtitles_View, dpi: s32, window_width: s32) -> string {
    // Render dimensions already include DPI scaling; do not scale their contribution twice.
    height := max(max(1, 18 * dpi / 96),
                  cast(s64) max(1, window_width) * SUBTITLE_FONT_REFERENCE_HEIGHT / SUBTITLE_FONT_REFERENCE_WIDTH);
    if view.dpi == dpi && view.font_height == height && view.english_font return "";
    small := max(1, height * 13 / 24);
    view.english_font = Simp.get_font_at_size("data/fonts", SUBTITLE_ENGLISH_FONT, height);
    view.chinese_font = Simp.get_font_at_size("data/fonts", SUBTITLE_CHINESE_FONT, height);
    view.small_font = Simp.get_font_at_size("data/fonts", CONSOLE_FONT_FILE, small);
    view.small_chinese_font = Simp.get_font_at_size("data/fonts", SUBTITLE_CHINESE_FONT, small);
    if !view.english_font || !view.chinese_font || !view.small_font || !view.small_chinese_font {
        return tprint("Could not load subtitle fonts from data/fonts: %, %, %.",
                      SUBTITLE_ENGLISH_FONT, SUBTITLE_CHINESE_FONT, CONSOLE_FONT_FILE);
    }
    view.font_height = cast(s32) height;
    view.line_height = cast(s32) max(1, height * 34 / 24);
    view.small_line_height = cast(s32) max(1, small * 20 / 13);
    view.dpi = dpi;
    view.layout_width = 0;
    return "";
}

subtitles_view_scroll :: (pixels: float64) {
    subtitles_view.scroll = clamp(subtitles_view.scroll + pixels, 0.0, subtitles_view.max_scroll);
}

subtitles_view_set_viewport :: (view: *Subtitles_View, height: s32) {
    view.viewport_height = cast(s32) max(0, height);
    view.max_scroll = cast(float64) max(0, view.content_height - view.viewport_height);
    view.scroll = clamp(view.scroll, 0.0, view.max_scroll);
}

subtitles_view_resize :: (view: *Subtitles_View, window_width: s32, viewport_height: s32, dpi: s32) -> string {
    error := subtitles_view_load_fonts(view, dpi, window_width);
    if error.count return error;
    width := cast(s32) max(1, cast(s64) max(1, window_width) * SUBTITLE_CONTENT_WIDTH_PERCENT / 100);
    view.content_left = cast(s32)((max(1, window_width) - width) / 2);
    at_bottom := view.max_scroll > 0 && view.scroll == view.max_scroll;
    if view.layout_width != width {
        previous_height := view.content_height;
        subtitles_view_layout(view, width);
        if previous_height > 0 view.scroll *= cast(float64) view.content_height / previous_height;
    }
    subtitles_view_set_viewport(view, viewport_height);
    if at_bottom view.scroll = view.max_scroll;
    return "";
}

draw_subtitles :: (console: *Console_State, window_width: s32, top: s32, bottom: s32) {
    if window_width <= 0 || bottom <= top return;
    view := *subtitles_view;
    error := subtitles_view_resize(view, window_width, bottom - top, console_font_dpi);
    if error.count { console_write(console, error, .ERROR); return; }
    left := view.content_left;
    offset := cast(s32) view.scroll;
    for line: view.text {
        baseline := top + line.baseline - offset;
        if baseline + view.line_height < top || baseline - view.line_height >= bottom continue;
        Simp.set_scissor(left + line.clip_left, top, left + line.clip_right, bottom);
        Simp.draw_text(line.font, left + line.x, baseline, line.text, console_color(line.color), .NO_KERNING);
    }
    Simp.set_scissor(0, top, window_width, bottom);
    if view.max_scroll > 0 && view.viewport_height > 0 {
        track := min(cast(s64) window_width, max(2, 3 * view.dpi / 96));
        thumb := min(view.viewport_height, max(16 * view.dpi / 96,
                     view.viewport_height * view.viewport_height / view.content_height));
        y := top + cast(s32)(cast(float64)(view.viewport_height - thumb) * view.scroll / view.max_scroll);
        Simp.set_shader_for_color();
        Simp.immediate_quad(cast(float)(window_width - track), cast(float) top, cast(float) window_width, cast(float) bottom,
                            console_color(Naysayer.line_fg));
        Simp.immediate_quad(cast(float)(window_width - track), cast(float) y, cast(float) window_width, cast(float)(y + thumb),
                            console_color(Naysayer.punctuation));
    }
    Simp.clear_scissor();
}

subtitles_view_layout :: (view: *Subtitles_View, width: s32) {
    view.text.count = 0;
    gap := cast(s32) min(max(1, 32 * view.font_height / 24), width / 4);
    column := cast(s32) max(1, (width - gap) / 2);
    right := column + gap;
    small := view.small_line_height;
    y: s32;
    for block: view.blocks {
        if block.section.count {
            y += 18 * view.font_height / 24;
            y = subtitles_layout_line(view, block.section, view.small_font, view.small_chinese_font,
                                      0, y, width, Naysayer.keyword, small);
            y += 8 * view.font_height / 24;
            continue;
        }
        if view.language == .ENGLISH {
            if block.english.count y = subtitles_layout_cues(view, block.english, view.english_font, view.chinese_font,
                                                             0, y, width, "");
        } else if view.language == .CHINESE {
            if block.chinese.count y = subtitles_layout_cues(view, block.chinese, view.chinese_font, view.english_font,
                                                             0, y, width, "");
        } else {
            en := subtitles_layout_cues(view, block.english, view.english_font, view.chinese_font,
                                        0, y, column, "(No English subtitle)");
            zh := subtitles_layout_cues(view, block.chinese, view.chinese_font, view.english_font,
                                        right, y, column, "(No Chinese subtitle)");
            y = max(en, zh);
        }
    }
    view.content_height = y + 12 * view.font_height / 24;
    view.layout_width = width;
}

subtitles_view_free :: (view: *Subtitles_View) {
    array_free(view.text);
    array_free(view.blocks);
    subtitles_catalog_free(*view.catalog);
    view.* = .{};
}

#scope_file
#import "Basic";
#import "String";
#import "Math";
Unicode :: #import "Unicode";
FreeType :: #import "freetype";
Simp :: #import "Simp";

subtitles_layout_cues :: (view: *Subtitles_View, cues: [] Subtitle_Cue,
                          font: *Simp.Dynamic_Font, fallback: *Simp.Dynamic_Font,
                          x: s32, y: s32, width: s32, missing: string) -> s32 {
    if !cues.count {
        return subtitles_layout_line(view, missing, view.small_font, view.small_chinese_font,
                                      x, y, width, Naysayer.dimmed_variable, view.small_line_height);
    }
    for cue: cues {
        visible := false;
        for line: cue.lines if line.text.count && (!line.comment || view.comments) { visible = true; break; }
        if !visible continue;
        if !view.hide_speakers {
            y = subtitles_layout_line(view, cue.speaker, view.small_font, view.small_chinese_font,
                                      x, y, width, SUBTITLE_SPEAKER_COLOR, view.small_line_height);
        }
        for line: cue.lines {
            if line.comment {
                if view.comments y = subtitles_layout_line(view, line.text, view.small_font, view.small_chinese_font,
                                                           x, y, width, SUBTITLE_COMMENT_COLOR, view.small_line_height);
            } else {
                y = subtitles_layout_line(view, line.text, font, fallback, x, y, width, Naysayer.white, view.line_height);
            }
        }
        y += 12 * view.font_height / 24;
    }
    return y;
}

subtitles_character_font :: (primary: *Simp.Dynamic_Font, fallback: *Simp.Dynamic_Font, character: u32) -> *Simp.Dynamic_Font {
    if FreeType.FT_Get_Char_Index(primary.private1, character) return primary;
    if FreeType.FT_Get_Char_Index(fallback.private1, character) return fallback;
    return primary;
}

subtitles_layout_line :: (view: *Subtitles_View, text: string,
                          font: *Simp.Dynamic_Font, fallback: *Simp.Dynamic_Font,
                          x: s32, y: s32, width: s32, color: u32, line_height: s32) -> s32 {
    if !text.count return y + line_height;
    start: s64;
    while start < text.count {
        position := start;
        last_break: s64 = -1;
        used: s64;
        while position < text.count {
            character, bytes := Unicode.character_utf8_to_utf32(text.data + position, text.count - position);
            bytes = max(1, bytes);
            selected := subtitles_character_font(font, fallback, character);
            advance := Simp.prepare_text(selected, slice(text, position, bytes), .NO_KERNING);
            if position > start && used + advance > width {
                if last_break > start position = last_break;
                break;
            }
            used += advance;
            position += bytes;
            if character == #char " " || character == #char "\t" || character >= 0x2e80 last_break = position;
        }
        end := position;
        while end > start && (text[end - 1] == #char " " || text[end - 1] == #char "\t") end -= 1;
        subtitles_layout_runs(view, slice(text, start, end - start), font, fallback,
                               x, y + cast(s32) font.character_height, width, color);
        y += line_height;
        start = position;
        while start < text.count && (text[start] == #char " " || text[start] == #char "\t") start += 1;
    }
    return y;
}

subtitles_layout_runs :: (view: *Subtitles_View, text: string,
                          primary: *Simp.Dynamic_Font, fallback: *Simp.Dynamic_Font,
                          x: s32, baseline: s32, width: s32, color: u32) {
    first := view.text.count;
    start: s64;
    offset: s32;
    while start < text.count {
        character, bytes := Unicode.character_utf8_to_utf32(text.data + start, text.count - start);
        font := subtitles_character_font(primary, fallback, character);
        end := start + max(1, bytes);
        while end < text.count {
            character, bytes = Unicode.character_utf8_to_utf32(text.data + end, text.count - end);
            if subtitles_character_font(primary, fallback, character) != font break;
            end += max(1, bytes);
        }
        run := slice(text, start, end - start);
        array_add(*view.text, .{run, font, color, x + offset, baseline, x, x + width});
        offset += cast(s32) Simp.prepare_text(font, run, .NO_KERNING);
        start = end;
    }
    if view.language != .BOTH {
        shift := cast(s32) max(0, (width - offset) / 2);
        for index: first..view.text.count-1 view.text[index].x += shift;
    }
}
