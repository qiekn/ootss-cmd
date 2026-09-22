#load "console_theme.jai";
#load "console_images.jai";

console_font:       *Simp.Dynamic_Font;
console_small_font: *Simp.Dynamic_Font;
console_chinese_font: *Simp.Dynamic_Font;
console_font_height: s32;
console_font_dpi:    s32;

console_load_fonts :: () -> bool {
    dpi := overlay_dpi();
    if dpi == console_font_dpi return true;
    console_font_height = 20 * dpi / 96;
    console_font       = Simp.get_font_at_size("data/fonts", CONSOLE_FONT_FILE, console_font_height);
    console_small_font = Simp.get_font_at_size("data/fonts", CONSOLE_FONT_FILE, 13 * dpi / 96);
    if !console_font || !console_small_font {
        show_error(tprint("Unable to load data/fonts/% next to ootss-cmd.exe.", CONSOLE_FONT_FILE));
        return false;
    }
    console_chinese_font = get_game_font_at_size(CONSOLE_CHINESE_FONT_FILE, CONSOLE_CHINESE_FONT_FILE, console_font_height);
    if !console_chinese_font {
        show_error(tprint("Unable to load % from the game or data/fonts beside ootss-cmd.exe. (You need to open OotSS before this application)", CONSOLE_CHINESE_FONT_FILE));
        return false;
    }
    console_font_dpi = dpi;
    return true;
}

draw_console :: () {
    // Layout uses the visible client area, excluding full mode's clipped OpenGL guard column.
    width, height := overlay_content_dimensions();
    if overlay.mode == .MINI {
        overlay_image_hide();
        background := console_color(Naysayer.background);
        Simp.clear_scissor();
        Simp.clear_render_target(background.x, background.y, background.z, 1);
        console_draw_input(width, 0, height, QUICK_COMMAND_MARGIN * console_font_dpi / 96);
        Simp.immediate_flush();
        return;
    }
    scale := cast(float) console_font_dpi / 96;
    margin := cast(s32)(28 * scale);
    input_top    := height - cast(s32)(84 * scale);
    input_bottom := height - cast(s32)(28 * scale);
    line_height  := console_font_height + cast(s32)(10 * scale);

    background := console_color(Naysayer.background);
    primary    := console_color(Naysayer.text);

    Simp.clear_scissor();
    Simp.clear_render_target(background.x, background.y, background.z, 1);
    if console.picture != .NONE console_prepare_picture(*console);
    else console_prepare_blow(*console, seconds_since_init());

    // Output remains above the fixed input line; old output is bounded and scrollable.
    output_top := margin;
    output_bottom := input_top - cast(s32)(14 * scale);
    if console.show_subtitles {
        draw_subtitles(*console, width, output_top, output_bottom);
    } else {
        visible_lines := max(0, (output_bottom - output_top) / line_height);
        columns := max(1, cast(s64)((width - 2 * margin) / max(1, Simp.prepare_text(console_font, "M"))));
        total_rows := console_output_rows(*console, console.lines.count, columns);
        if console.scroll_to_line >= 0 {
            first_row := console_output_rows(*console, console.scroll_to_line, columns);
            console.scroll = max(0, total_rows - visible_lines - first_row);
            console.scroll_to_line = -1;
        }
        console.scroll = max(0, min(console.scroll, max(0, total_rows - visible_lines)));
        first := max(0, total_rows - visible_lines - console.scroll);
        last := min(total_rows, first + visible_lines);
        Simp.set_scissor(margin, output_top, width - margin, output_bottom);
        if console.show_blow console_draw_blow(0, 0, width, input_top);
        if console.picture != .NONE console_draw_picture(0, 0, width, input_top);
        row: s64;
        for line: console.lines {
            rows := console_line_rows(line, columns);
            line_row := row;
            row += rows;
            if row <= first || line_row >= last continue;
            y := output_top + cast(s32)(line_row - first) * line_height;
            if line.kind == .ICON {
                console_draw_icon(margin, y, width - margin, y + cast(s32) rows * line_height, scale);
                continue;
            }
            color := primary;
            if line.kind == .INFO    color = console_color(Naysayer.comment);
            if line.kind == .COMMAND color = console_color(Naysayer.keyword);
            if line.kind == .ERROR   color = console_color(Naysayer.error);
            if line.wrap && line.text.count {
                position: s64;
                while position < line.text.count {
                    text := console_wrapped_row(line.text, *position, columns);
                    if y + line_height > output_top && y < output_bottom {
                        console_draw_output_text(margin, y + console_font_height, text, color);
                    }
                    y += line_height;
                }
            } else console_draw_output_text(margin, y + console_font_height, line.text, color);
        }
        Simp.clear_scissor();
    }

    console_draw_input(width, input_top, input_bottom, margin);

    footer_y := height - cast(s32)(13 * scale);
    console_rect(0, height - cast(s32)(28 * scale), width, height, console_color(Naysayer.lualine_bg));
    footer_color := console_color(Naysayer.lualine_fg);
    hint := "ENTER run   TAB complete   UP/DOWN history   ESC hide   CTRL+Q quit";
    if console.zork_mode {
        hint = "ZORK   clear / cl   save / restore   /back helper   /help controls   ESC hide";
        if console.zork_input_kind == .FILENAME hint = "ZORK   Save filename in data/zork/   ENTER accepts default   /back helper";
        if console.zork_input_kind == .OVERWRITE hint = "ZORK   Overwrite save: Y / N then ENTER   /back helper";
        if console.zork_input_kind == .BUSY hint = "ZORK   Waiting for the game...   /back helper   ESC hide";
    } else if console.show_subtitles {
        percent := ifx subtitles_view.max_scroll > 0 then cast(s32)(100 * subtitles_view.scroll / subtitles_view.max_scroll) else 100;
        hint = tprint("Subtitles: %/100   WHEEL / PGUP / PGDN scroll   CTRL+HOME/END start/end", percent);
    } else if console.scroll > 0 hint = tprint("Scrollback: % lines above latest   /   PAGE DOWN to return", console.scroll);
    if console_completion_is_current(*console) {
        hint = tprint("TAB next / SHIFT+TAB previous   % matches   ENTER run", console.completion.matches.count);
    }
    Simp.draw_text(console_small_font, margin, footer_y, hint, footer_color);
    if width > cast(s32)(1120 * scale) {
        toggle_hint := ": console   ; quick   ` toggle";
        hint_width := Simp.prepare_text(console_small_font, toggle_hint);
        if Simp.prepare_text(console_small_font, hint) + hint_width + 3 * margin < width {
            Simp.draw_text(console_small_font, width - margin - hint_width, footer_y, toggle_hint, footer_color);
        }
    }
    Simp.immediate_flush();
}

console_draw_input :: (width: s32, input_top: s32, input_bottom: s32, margin: s32) {
    scale := cast(float) console_font_dpi / 96;
    console_rect(0, input_top, width, input_bottom, console_color(Naysayer.highlight));
    baseline := input_top + (input_bottom - input_top + console_font_height) / 2 - cast(s32)(3 * scale);
    Simp.draw_text(console_font, margin, baseline, "$", console_color(Naysayer.punctuation));
    input_left := margin + cast(s32)(28 * scale);
    input_right := width - margin;
    if input_right <= input_left return;
    text := console_input(*console);
    caret_width := Simp.prepare_text(console_font, slice(text, 0, console.cursor));
    horizontal_scroll := max(0, caret_width - (input_right - input_left - 8));
    Simp.set_scissor(input_left, input_top + 1, input_right, input_bottom);
    if text.count {
        Simp.draw_text(console_font, input_left - horizontal_scroll, baseline, text, console_color(Naysayer.text));
    } else {
        placeholder := ifx console.zork_mode then "Type a Zork command..." else "Type a command...";
        if console.zork_mode && console.zork_input_kind == .FILENAME placeholder = "Save name, or Enter for default...";
        if console.zork_mode && console.zork_input_kind == .OVERWRITE placeholder = "y / n";
        Simp.draw_text(console_font, input_left, baseline, placeholder, console_color(Naysayer.dimmed_variable));
    }
    if (cast(s64)(seconds_since_init() * 2) % 2) == 0 {
        x := input_left + caret_width - horizontal_scroll;
        console_rect(cast(s32) x, baseline - console_font_height, cast(s32) x + 2, baseline + 3, console_color(Naysayer.white));
    }
    Simp.clear_scissor();
}

console_font_for_character :: (character: u32) -> *Simp.Dynamic_Font {
    if character < 128 || FT.FT_Get_Char_Index(console_font.private1, character) return console_font;
    if FT.FT_Get_Char_Index(console_chinese_font.private1, character) return console_chinese_font;
    return console_font;
}

console_draw_output_text :: (x: s64, y: s64, text: string, color: Vector4) {
    // Draw consecutive characters from the same font together, sharing a baseline.
    font := console_font;
    start: s64;
    cursor: s64;
    draw_x := x;
    while cursor < text.count {
        character, bytes := Unicode.character_utf8_to_utf32(text.data + cursor, text.count - cursor);
        next_font := console_font_for_character(character);
        if next_font != font {
            if cursor > start {
                draw_x += Simp.draw_text(font, draw_x, y, slice(text, start, cursor - start), color);
            }
            font = next_font;
            start = cursor;
        }
        cursor += max(1, bytes);
    }
    if cursor > start Simp.draw_text(font, draw_x, y, slice(text, start, cursor - start), color);
}

console_line_rows :: (line: Console_Line, columns: s64 = 0) -> s64 {
    if line.kind == .ICON return CONSOLE_ICON_ROWS;
    if !line.wrap || columns <= 0 || !line.text.count return 1;
    position, rows: s64;
    while position < line.text.count {
        console_wrapped_row(line.text, *position, columns);
        rows += 1;
    }
    return rows;
}

console_output_rows :: (console: *Console_State, end: s64, columns: s64 = 0) -> s64 {
    rows: s64;
    for index: 0..min(end, console.lines.count)-1 rows += console_line_rows(console.lines[index], columns);
    return rows;
}

#scope_file

#import "Basic";
#import "Math";
#import "String";
Simp :: #import "Simp";
FT :: #import "freetype";
Unicode :: #import "Unicode";

console_rect :: (x0: s32, y0: s32, x1: s32, y1: s32, color: Vector4) {
    Simp.set_shader_for_color();
    Simp.immediate_quad(cast(float) x0, cast(float) y0, cast(float) x1, cast(float) y1, color);
}
