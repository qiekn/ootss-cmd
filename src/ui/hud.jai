// Size is the number of font rows that fit vertically in the game client.
HUD_INFO_SIZE :: 40;
HUD_NOTICE_SIZE :: 30;  // which means, max lines of window_height, e.g. 10 means 10 lines full the window height. less is bigger

Hud_Panel :: struct {
    window: Win.HWND;
    surface: Overlay_Image_Surface;
    mask: [] u8;
    font: *Simp.Dynamic_Font;
    text: string;
    font_height, available_width: s32;
    x, y: s32;
    opacity: u8;
    visible: bool;
}

Hud_State :: struct {
    enabled: bool = true;
    info, toast: Hud_Panel;
    message, details: string;
    expires, next_frame, next_sample, retry_at, next_resolve: float64;
    reader: Game_Position_Reader;
    pid: u32;
    suppressed: bool;
}
hud: Hud_State;

hud_font_height :: (window_height: s32, size: s32) -> s32 {
    if size <= 0 return 1;
    return max(cast(s32) 1, window_height / size);
}

hud_notify :: (message: string, duration: float64 = 1.0) {
    if !hud.enabled return;
    free(hud.message);
    hud.message = copy_string(message);
    hud.expires = seconds_since_init() + duration;
}

command_hud :: (state: *Console_State, arguments: string) {
    argument := trim(arguments);
    enabled := !hud.enabled;
    if equal_nocase(argument, "enable") enabled = true;
    else if equal_nocase(argument, "disable") enabled = false;
    else if argument.count { console_write(state, "Usage: hud [enable|disable]", .ERROR); return; }
    hud.enabled = enabled;
    hud.next_sample = 0;
    hud.next_frame = 0;
    hud.retry_at = 0;
    hud.next_resolve = 0;
    if !enabled {
        hud_hide();
        free(hud.message); hud.message = "";
        game_position_reader_close(*hud.reader);
    }
    console_write(state, ifx enabled then "HUD enabled." else "HUD disabled.");
}

hud_details :: (name: string, sample: Game_Position_Sample) -> string {
    return tprint("%\n%", ifx name.count then name else "Unavailable",
        ifx sample.valid then game_position_text(sample.position) else "Unavailable");
}

hud_sample :: (now: float64) {
    if now < hud.next_sample return;
    hud.next_sample = now + 0.2;
    pid := process_window_pid(overlay.game);
    if pid != hud.pid {
        game_position_reader_close(*hud.reader);
        hud.pid = pid;
        hud.retry_at = 0;
        hud.next_resolve = 0;
        hud.info.font = null;
        hud.toast.font = null;
    }
    if !hud.reader.memory.handle && pid && now >= hud.retry_at {
        hud.retry_at = now + 2;
        game_position_reader_open(*hud.reader, overlay.game);
    }
    name: string;
    defer free(name);
    sample: Game_Position_Sample;
    if hud.reader.memory.handle {
        scene: Game_Scene_Location;
        error: string;
        // This reader is independent of editor recording/playback. Only checked
        // code evidence is reused; scene and controlled selection stay fresh.
        name, error = game_read_scene_from(hud.reader.memory, *hud.reader.locator, *scene);
        if !error.count {
            sample = game_position_reader_sample(*hud.reader, allow_resolve = now >= hud.next_resolve);
            if !sample.valid && now >= hud.next_resolve hud.next_resolve = now + 1;
            else if sample.valid hud.next_resolve = 0;
            if sample.valid && sample.player.manager != scene.manager sample.valid = false;
            if !game_scene_location_current(hud.reader.memory, scene, name) {
                free(name); name = ""; sample.valid = false;
            }
        } else {
            game_position_reader_close(*hud.reader);
            hud.retry_at = now + 2;
        }
    }
    free(hud.details);
    hud.details = copy_string(hud_details(name, sample));
}

// Copy FreeType's cached grayscale coverage instead of blending onto black and
// discarding black by color key. This does not render or read back a GL window.
hud_raster_line :: (mask: [] u8, width: s32, height: s32, font: *Simp.Dynamic_Font,
                    text: string, x: s64, baseline: s64) {
    Simp.prepare_text(font, text);
    pen := x;
    for glyph: font.temporary_glyphs {
        if glyph.page {
            atlas := glyph.page.bitmap_data;
            left := pen + glyph.offset_x;
            top := baseline - glyph.ascent;
            for gy: 0..cast(s64) glyph.height-1 {
                y := top + gy;
                if y < 0 || y >= height continue;
                for gx: 0..cast(s64) glyph.width-1 {
                    dx := left + gx;
                    if dx < 0 || dx >= width continue;
                    // The atlas is bottom-up; the DIB is top-down.
                    source := ((cast(s64) glyph.y0 + glyph.height - 1 - gy) * atlas.width + glyph.x0 + gx) * 4;
                    coverage := cast(u32) atlas.data[source + 3];
                    target := *mask[y * width + dx];
                    target.* = cast(u8)(coverage + (target.* * (255 - coverage) + 127) / 255);
                }
            }
        }
        pen += glyph.advance;
    }
}

// White premultiplied BGRA with a low-opacity, blurred shadow. Antialiased edge
// pixels stay translucent and white, without an opaque black fringe or outline.
hud_compose_pixels :: (mask: [] u8, pixels: *u8, width: s32, height: s32, radius: s32) {
    assert(mask.count == cast(s64) width * height);
    for y: 0..height-1 for x: 0..width-1 {
        shadow: u32;
        for sy: -1..1 for sx: -1..1 {
            px := x - radius + sx * radius;
            py := y - radius + sy * radius;
            if px < 0 || py < 0 || px >= width || py >= height continue;
            weight := (ifx sx == 0 then 2 else 1) * (ifx sy == 0 then 2 else 1);
            shadow += cast(u32)(mask[py * width + px] * weight);
        }
        shadow = (shadow + 32) / 64; // Gaussian kernel /16, then 25% opacity.
        alpha := cast(u32) mask[y * width + x];
        pixel := pixels + (y * width + x) * 4;
        pixel[0] = cast(u8) alpha;
        pixel[1] = cast(u8) alpha;
        pixel[2] = cast(u8) alpha;
        pixel[3] = cast(u8)(alpha + (shadow * (255 - alpha) + 127) / 255);
    }
}

hud_draw_panel :: (panel: *Hud_Panel, x: s32, y: s32, width: s32, height: s32,
                   text: string, font_height: s32, centered: bool, opacity: u8) {
    if width <= 0 || height <= 0 || !hud_panel_create(panel) return;
    font_changed := !panel.font || panel.font_height != font_height;
    if font_changed {
        panel.font = get_game_font_at_size(SUBTITLE_ENGLISH_FONT, SUBTITLE_ENGLISH_BUNDLED_FONT, font_height);
        panel.font_height = font_height;
    }
    if !panel.font { hud_panel_hide(panel); return; }
    redraw := font_changed || panel.text != text || panel.available_width != width || panel.surface.height != height;
    if redraw {
        font := panel.font;
        lines := split(text, #char "\n");
        defer array_free(lines);
        padding := max(cast(s32) 4, font_height / 6);
        render_width := width;
        if !centered {
            measured: s64;
            for line: lines measured = max(measured, Simp.prepare_text(font, line));
            render_width = cast(s32) min(cast(s64) width, measured + 2*padding);
        }
        if !overlay_image_surface_resize(*panel.surface, render_width, height) return;
        count := cast(s64) render_width * height;
        if panel.mask.count != count { free(panel.mask.data); panel.mask = NewArray(count, u8); }
        memset(panel.mask.data, 0, count);
        for line: lines {
            left := ifx centered then (render_width-Simp.prepare_text(font, line))/2 else cast(s64) padding;
            baseline := padding + font.max_ascender + it_index * (font_height + padding);
            hud_raster_line(panel.mask, render_width, height, font, line, left, baseline);
        }
        hud_compose_pixels(panel.mask, panel.surface.pixels, render_width, height, max(cast(s32) 1, font_height / 50));
    }
    if redraw || !panel.visible || panel.x != x || panel.y != y || panel.opacity != opacity {
        if !hud_panel_present(panel, x, y, opacity) return;
    }
    if redraw { free(panel.text); panel.text = copy_string(text); panel.available_width = width; }
}

hud_update :: (now: float64) {
    foreground := Win.GetForegroundWindow();
    if !hud.enabled || hud.suppressed || overlay.visible || !overlay.game || HudIsIconic(overlay.game) ||
       (foreground != overlay.game && foreground != editor_window.handle) {
        hud_hide();
        return;
    }
    if now < hud.next_frame return;
    hud.next_frame = now + 1.0/30;
    hud_sample(now);
    bounds: Win.RECT;
    origin: Win.POINT;
    if !Win.GetClientRect(overlay.game, *bounds) || !Win.ClientToScreen(overlay.game, *origin) return;
    info_height := hud_font_height(bounds.bottom, HUD_INFO_SIZE);
    notice_height := hud_font_height(bounds.bottom, HUD_NOTICE_SIZE);
    margin := max(cast(s32) 8, bounds.bottom / 60);
    hud_draw_panel(*hud.info, origin.x + margin, origin.y + margin, bounds.right - 2*margin,
                   info_height*3, hud.details, info_height, false, 255);
    if hud.message.count && now < hud.expires {
        alpha := cast(u8)(255*clamp((hud.expires-now)/0.3, 0.0, 1.0));
        hud_draw_panel(*hud.toast, origin.x + margin, origin.y + bounds.bottom*30/100,
                       bounds.right - 2*margin, notice_height*2, hud.message, notice_height, true, alpha);
    } else hud_panel_hide(*hud.toast);
}

hud_deinit :: () {
    hud_hide();
    for panel: *Hud_Panel.[*hud.info, *hud.toast] {
        if panel.window Win.DestroyWindow(panel.window);
        overlay_image_surface_free(*panel.surface);
        free(panel.mask.data);
        free(panel.text);
    }
    game_position_reader_close(*hud.reader);
    free(hud.message);
    free(hud.details);
    hud = .{};
}

#scope_file
#import "Basic";
#import "String";
#import "Math";
#import "System";
Win :: #import "Windows";
Simp :: #import "Simp";
