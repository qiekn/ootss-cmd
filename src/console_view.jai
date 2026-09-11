#load "console_theme.jai";

CONSOLE_FONT_FILE :: "Meslo-LG-Mono-Regular.ttf";

console_font:       *Simp.Dynamic_Font;
console_small_font: *Simp.Dynamic_Font;
console_font_height: s32;
console_font_dpi:    s32;

console_load_fonts :: () -> bool {
    dpi := overlay_dpi();
    if dpi == console_font_dpi return true;
    console_font_height = 20 * dpi / 96;
    console_font       = Simp.get_font_at_size("data/fonts", CONSOLE_FONT_FILE, console_font_height);
    console_small_font = Simp.get_font_at_size("data/fonts", CONSOLE_FONT_FILE, 13 * dpi / 96);
    if !console_font || !console_small_font {
        show_error(tprint("Unable to load fonts/% next to ootss-helper.exe.", CONSOLE_FONT_FILE));
        return false;
    }
    console_font_dpi = dpi;
    return true;
}

draw_console :: () {
    width, height := Simp.get_render_dimensions(overlay.window);
    scale := cast(float) console_font_dpi / 96;
    margin := cast(s32)(28 * scale);
    input_top    := height - cast(s32)(84 * scale);
    input_bottom := height - cast(s32)(28 * scale);
    status_top   := height - cast(s32)(28 * scale);
    line_height  := console_font_height + cast(s32)(10 * scale);

    background := console_color(Naysayer.background);
    panel      := console_color(Naysayer.highlight);
    accent     := console_color(Naysayer.punctuation);
    primary    := console_color(Naysayer.text);
    muted      := console_color(Naysayer.dimmed_variable);
    border     := console_color(Naysayer.line_fg);

    Simp.clear_scissor();
    Simp.clear_render_target(background.x, background.y, background.z, 1);

    // Output remains above the fixed input line; old output is bounded and scrollable.
    output_top := margin;
    output_bottom := input_top - cast(s32)(14 * scale);
    visible_lines := max(0, (output_bottom - output_top) / line_height);
    console.scroll = max(0, min(console.scroll, max(0, console.lines.count - visible_lines)));
    first := max(0, console.lines.count - visible_lines - console.scroll);
    last := min(console.lines.count, first + visible_lines);
    Simp.set_scissor(margin, output_top, width - margin, output_bottom);
    y := output_top + console_font_height;
    for index: first..last-1 {
        line := console.lines[index];
        color := primary;
        if line.kind == .INFO    color = console_color(Naysayer.comment);
        if line.kind == .COMMAND color = console_color(Naysayer.keyword);
        if line.kind == .ERROR   color = console_color(Naysayer.error);
        Simp.draw_text(console_font, margin, y, line.text, color);
        y += line_height;
    }
    Simp.clear_scissor();

    console_rect(0, input_top, width, input_bottom, panel);
    // console_rect(margin - 12, input_top, width - margin + 12, input_top + 1, border);
    baseline := input_top + (input_bottom - input_top + console_font_height) / 2 - cast(s32)(3 * scale);
    Simp.draw_text(console_font, margin, baseline, "$", accent);

    input_left := margin + cast(s32)(28 * scale);
    input_right := width - margin;
    text := console_input(*console);
    caret_width := Simp.prepare_text(console_font, slice(text, 0, console.cursor));
    horizontal_scroll := max(0, caret_width - (input_right - input_left - 8));
    Simp.set_scissor(input_left, input_top + 1, input_right, input_bottom);
    if text.count {
        Simp.draw_text(console_font, input_left - horizontal_scroll, baseline, text, primary);
    } else {
        Simp.draw_text(console_font, input_left, baseline, "Type a command...", muted);
    }
    if (cast(s64)(seconds_since_init() * 2) % 2) == 0 {
        x := input_left + caret_width - horizontal_scroll;
        console_rect(cast(s32) x, baseline - console_font_height, cast(s32) x + 2, baseline + 3, console_color(Naysayer.white));
    }
    Simp.clear_scissor();

    footer_y := height - cast(s32)(13 * scale);
    console_rect(0, height - cast(s32)(28 * scale), width, height, console_color(Naysayer.lualine_bg));
    footer_color := console_color(Naysayer.lualine_fg);
    hint := "ENTER run   UP/DOWN history   ESC hide   CTRL+Q quit";
    if console.scroll > 0 hint = tprint("Scrollback: % lines above latest   /   PAGE DOWN to return", console.scroll);
    Simp.draw_text(console_small_font, margin, footer_y, hint, footer_color);
    if width > cast(s32)(1120 * scale) {
        toggle_hint := ": open   ` toggle   CTRL+` anywhere";
        hint_width := Simp.prepare_text(console_small_font, toggle_hint);
        Simp.draw_text(console_small_font, width - margin - hint_width, footer_y, toggle_hint, footer_color);
    }
    Simp.immediate_flush();
}

#scope_file

#import "Basic";
#import "Math";
#import "String";
Simp :: #import "Simp";

console_rect :: (x0: s32, y0: s32, x1: s32, y1: s32, color: Vector4) {
    Simp.set_shader_for_color();
    Simp.immediate_quad(cast(float) x0, cast(float) y0, cast(float) x1, cast(float) y1, color);
}
