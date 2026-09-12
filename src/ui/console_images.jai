CONSOLE_BLOW_FILE :: "data/images/blow-wave.gif";
CONSOLE_BLOW_COLOR_WEIGHT :: 153; // Mix 60% image color with the theme before opaque presentation.
CONSOLE_BLOW_SEAM_PIXELS :: 4; // Feather this many source pixels on each side of the mirror seam.
CONSOLE_BLOW_PADDING :: 24;
CONSOLE_BLOW_CAPTION :: "Powered by blowave & jai";
CONSOLE_BLOW_CAPTION_HEIGHT :: 10;
CONSOLE_BLOW_CAPTION_PADDING :: 8;

CONSOLE_ICON_FILE :: "data/images/icon.png";
CONSOLE_ICON_ROWS :: 5;

CONSOLE_PICTURE_FILES :: string.["data/images/captain.jpg", "data/images/pirate.jpg", "data/images/captain-pirate-jl.png"];

Console_Blow_Effect :: enum { ALIEN; MIRROR; WAVE; } // Same order as CONSOLE_BLOW_NAMES.

Console_Gif :: struct {
    pixels: *u8;
    delays: *s32;
    width, height, frame_count: s32;
    duration_ms: s64;
    started_at: float64;
    frame: s32 = -1;
    effect: Console_Blow_Effect = .WAVE;
    opaque_pixels: [] u8;
    frame_changed: bool;
}

console_blow: Console_Gif;
console_blow_caption_font: *Simp.Dynamic_Font;
console_icon: Simp.Texture;
console_icon_attempted: bool;
console_icon_loaded: bool;

Console_Still_Image :: struct {
    pixels: *u8;
    width, height: s32;
    has_alpha: bool;
}
console_pictures: [CONSOLE_PICTURE_FILES.count] Console_Still_Image;

console_picture_load :: (picture: *Console_Still_Image, path: string) -> bool {
    if picture.pixels return true;
    source, success := read_entire_file(path, log_errors = false);
    if !success return false;
    defer free(source);
    if !source.count || source.count > 0x7fff_ffff return false;
    channels: s32;
    picture.pixels = Stb.stbi_load_from_memory(source.data, cast(s32) source.count,
                                               *picture.width, *picture.height, *channels, 4);
    if !picture.pixels return false;
    console_picture_premultiply(picture);
    return true;
}

console_picture_premultiply :: (picture: *Console_Still_Image) {
    picture.has_alpha = false;
    // Layered windows use premultiplied BGRA. Opaque pixels keep their original colors.
    for index: 0..cast(s64) picture.width * picture.height - 1 {
        pixel := picture.pixels + index * 4;
        alpha := cast(u32) pixel[3];
        if alpha < 255 picture.has_alpha = true;
        red := pixel[0];
        pixel[0] = cast(u8)((cast(u32) pixel[2] * alpha + 127) / 255);
        pixel[1] = cast(u8)((cast(u32) pixel[1] * alpha + 127) / 255);
        pixel[2] = cast(u8)((cast(u32) red * alpha + 127) / 255);
    }
}

console_prepare_picture :: (console: *Console_State) {
    if console.picture == .NONE return;
    index := cast(s64) console.picture - 1;
    if !console_picture_load(*console_pictures[index], CONSOLE_PICTURE_FILES[index]) {
        console.picture = .NONE;
        overlay_image_hide();
        console_write(console, tprint("Unable to load % next to ootss-cmd.exe.", CONSOLE_PICTURE_FILES[index]), .ERROR);
    }
}

console_draw_picture :: (left: s32, top: s32, right: s32, bottom: s32) {
    if console.picture == .NONE return;
    picture := *console_pictures[cast(s64) console.picture - 1];
    padding := cast(s32)(CONSOLE_BLOW_PADDING * cast(float) console_font_dpi / 96);
    placement := overlay_image_fit(picture.width, picture.height, left, top, right, bottom, padding);
    if !overlay_image_show(picture.pixels, picture.width, picture.height, placement, false, per_pixel_alpha = picture.has_alpha) {
        console.picture = .NONE;
        console_write(*console, "Unable to create or position the image display.", .ERROR);
    }
}

console_picture_deinit :: (picture: *Console_Still_Image) {
    if picture.pixels Stb.stbi_image_free(picture.pixels);
    picture.* = .{};
}

console_gif_load :: (gif: *Console_Gif, path: string) -> bool {
    source, success := read_entire_file(path, log_errors = false);
    if !success return false;
    defer free(source);
    if !source.count || source.count > 0x7fff_ffff return false;

    channels: s32;
    gif.pixels = Stb.stbi_load_gif_from_memory(source.data, cast(s32) source.count, *gif.delays,
        *gif.width, *gif.height, *gif.frame_count, *channels, 4);
    if !gif.pixels {
        // stb frees partial allocations on failure, including the delay buffer.
        gif.delays = null;
        console_gif_deinit(gif);
        return false;
    }
    if !gif.delays || gif.width <= 0 || gif.height <= 0 || gif.frame_count <= 0 {
        console_gif_deinit(gif);
        return false;
    }
    for index: 0..gif.frame_count-1 {
        // GIFs can omit the delay; keep those frames visible without a zero-duration loop.
        if gif.delays[index] <= 0 gif.delays[index] = 100;
        gif.duration_ms += gif.delays[index];
    }
    gif.opaque_pixels = NewArray(cast(s64) gif.width * gif.height * 4, u8);
    return true;
}

console_gif_frame_at :: (gif: *Console_Gif, now: float64) -> s32 {
    if !gif.frame_count || !gif.duration_ms return 0;
    elapsed := max(0, cast(s64)((now - gif.started_at) * 1000)) % gif.duration_ms;
    for index: 0..gif.frame_count-1 {
        if elapsed < gif.delays[index] return cast(s32) index;
        elapsed -= gif.delays[index];
    }
    return 0;
}

console_load_blow :: () -> bool {
    // All effects share wave's original pixels and timing; switching effects never decodes another GIF.
    if console_blow.pixels return true;
    return console_gif_load(*console_blow, CONSOLE_BLOW_FILE);
}

console_prepare_blow :: (console: *Console_State, now: float64) {
    if !console.show_blow || console.show_subtitles {
        overlay_image_hide();
        return;
    }
    gif := *console_blow;
    if !console_load_blow() {
        console.show_blow = false;
        console.restart_blow = false;
        console_write(console, tprint("Unable to load % next to ootss-cmd.exe.", CONSOLE_BLOW_FILE), .ERROR);
        return;
    }
    if console.restart_blow {
        gif.started_at = now;
        console.restart_blow = false;
    }

    frame := console_gif_frame_at(gif, now);
    effect := cast(Console_Blow_Effect) console.blow_index;
    if frame == gif.frame && effect == gif.effect return;
    console_gif_blend_frame(gif, frame, effect);
    console_gif_draw_caption(gif);
}

console_gif_blend_frame :: (gif: *Console_Gif, frame: s32, effect: Console_Blow_Effect = .WAVE) {
    frame_bytes := cast(s64) gif.width * gif.height * 4;
    source := gif.pixels + frame_bytes * frame;
    background := u32.[Naysayer.background & 0xff, (Naysayer.background >> 8) & 0xff,
                      (Naysayer.background >> 16) & 0xff];
    // GDI takes BGRA, while stb supplies RGBA. Transparent GIF pixels become solid theme background.
    for y: 0..gif.height - 1 {
        row := source + y * gif.width * 4;
        for x: 0..gif.width - 1 {
            source_x := x;
            // Alien keeps the left half; mirror keeps the right. Reflect the retained half across the center.
            if effect == .ALIEN source_x = min(x, gif.width - 1 - x);
            if effect == .MIRROR source_x = max(x, gif.width - 1 - x);
            seam_weight: u32;
            distance := abs(2 * x - (gif.width - 1));
            if effect != .WAVE && distance < 2 * CONSOLE_BLOW_SEAM_PIXELS {
                // Smoothly crossfade the original and reflected pixels near the fold. Both sides use
                // identical weights, preserving symmetry without the hard center stripe.
                t := 1.0 - cast(float) distance / (2 * CONSOLE_BLOW_SEAM_PIXELS);
                seam_weight = cast(u32)(128 * t * t * (3 - 2 * t) + 0.5);
            }
            pixel := row + source_x * 4;
            reflected := row + (gif.width - 1 - source_x) * 4;
            output := gif.opaque_pixels.data + (y * gif.width + x) * 4;
            alpha := (cast(u32) pixel[3] * CONSOLE_BLOW_COLOR_WEIGHT + 127) / 255;
            inverse := 255 - alpha;
            reflected_alpha := (cast(u32) reflected[3] * CONSOLE_BLOW_COLOR_WEIGHT + 127) / 255;
            for channel: 0..2 {
                value := (cast(u32) pixel[2 - channel] * alpha + background[channel] * inverse + 127) / 255;
                if seam_weight {
                    other := (cast(u32) reflected[2 - channel] * reflected_alpha +
                              background[channel] * (255 - reflected_alpha) + 127) / 255;
                    value = (value * (256 - seam_weight) + other * seam_weight + 128) / 256;
                }
                output[channel] = cast(u8) value;
            }
            output[3] = 255;
        }
    }
    gif.frame = frame;
    gif.effect = effect;
    gif.frame_changed = true;
}

console_gif_draw_caption :: (gif: *Console_Gif) {
    if !console_blow_caption_font {
        console_blow_caption_font = Simp.get_font_at_size("data/fonts", CONSOLE_FONT_FILE, CONSOLE_BLOW_CAPTION_HEIGHT);
    }
    font := console_blow_caption_font;
    if !font return;
    width := Simp.prepare_text(font, CONSOLE_BLOW_CAPTION, .NO_KERNING);
    descent: s64;
    for glyph: font.temporary_glyphs descent = max(descent, cast(s64) glyph.height - glyph.ascent);
    baseline := gif.height - CONSOLE_BLOW_CAPTION_PADDING - descent - 1;

    // Composite Meslo's cached glyph masks into the opaque frame, including a one-pixel shadow.
    // The caption then scales with the image at the same integer zoom, without a separate window or font system.
    for pass: 0..1 {
        offset := ifx pass == 0 then 1 else 0;
        color := ifx pass == 0 then Naysayer.background else Naysayer.text;
        cursor := (gif.width - width) / 2;
        for glyph: font.temporary_glyphs {
            if glyph.page && glyph.width && glyph.height {
                bitmap := glyph.page.bitmap_data;
                for y: 0..glyph.height - 1 {
                    output_y := baseline - glyph.ascent + y + offset;
                    if output_y < 0 || output_y >= gif.height continue;
                    // Simp's atlas stores glyph rows bottom-up; the GIF buffer is top-down.
                    source_y := cast(s64) glyph.y0 + glyph.height - 1 - y;
                    for x: 0..glyph.width - 1 {
                        output_x := cursor + glyph.offset_x + x + offset;
                        if output_x < 0 || output_x >= gif.width continue;
                        source := (source_y * bitmap.width + glyph.x0 + x) * 4;
                        alpha: u32 = bitmap.data[source + 3];
                        if !alpha continue;
                        output := gif.opaque_pixels.data + (output_y * gif.width + output_x) * 4;
                        for channel: 0..2 {
                            component := (color >> (channel * 8)) & 0xff;
                            output[channel] = cast(u8)((component * alpha + cast(u32) output[channel] * (255 - alpha) + 127) / 255);
                        }
                    }
                }
            }
            cursor += glyph.advance;
        }
    }
}

console_draw_blow :: (left: s32, top: s32, right: s32, bottom: s32) {
    gif := *console_blow;
    padding := cast(s32)(CONSOLE_BLOW_PADDING * cast(float) console_font_dpi / 96);
    placement := overlay_image_fit_integer(gif.width, gif.height, left, top, right, bottom, padding);
    if !overlay_image_show(gif.opaque_pixels.data, gif.width, gif.height, placement, gif.frame_changed) {
        console.show_blow = false;
        console.restart_blow = false;
        console_write(*console, "Unable to create or position the GIF display.", .ERROR);
    }
    gif.frame_changed = false;
}

console_draw_icon :: (left: s32, top: s32, right: s32, bottom: s32, scale: float) {
    if !console_icon_attempted {
        console_icon_attempted = true;
        Simp.immediate_flush();
        console_icon_loaded = Simp.texture_load_from_file(*console_icon, CONSOLE_ICON_FILE);
    }
    if !console_icon_loaded {
        Simp.draw_text(console_small_font, left, top + console_font_height,
            "Unable to load data/images/icon.png.", console_color(Naysayer.error));
        return;
    }
    image_scale := 128 * scale / cast(float) max(console_icon.width, console_icon.height);
    console_draw_image(*console_icon, left, top, right, bottom, image_scale);
}

console_draw_image :: (texture: *Simp.Texture, left: s32, top: s32, right: s32, bottom: s32,
                       wanted_scale: float, centered := false, fit_height := true,
                       color := Vector4.{1, 1, 1, 1}) {
    if right <= left || bottom <= top return;
    scale := min(wanted_scale, cast(float)(right - left) / texture.width);
    if fit_height scale = min(scale, cast(float)(bottom - top) / texture.height);
    width := cast(s32)(texture.width * scale);
    height := cast(s32)(texture.height * scale);
    x := ifx centered then left + (right - left - width) / 2 else left;
    y := ifx centered then top + (bottom - top - height) / 2 else top;
    Simp.set_shader_for_images(texture);
    Simp.immediate_quad(cast(float) x, cast(float) y, cast(float)(x + width), cast(float)(y + height), color);
}

console_gif_deinit :: (gif: *Console_Gif) {
    if gif == *console_blow overlay_image_hide();
    free(gif.opaque_pixels.data);
    if gif.pixels Stb.stbi_image_free(gif.pixels);
    if gif.delays Stb.stbi_image_free(gif.delays);
    gif.* = .{};
}

console_images_deinit :: () {
    overlay_image_destroy();
    for *picture: console_pictures console_picture_deinit(picture);
    console_gif_deinit(*console_blow);
    console_blow_caption_font = null;
    if console_icon_loaded Simp.texture_destroy(*console_icon);
    console_icon_loaded = false;
    console_icon_attempted = false;
}

#scope_file
#import "Basic";
#import "File";
#import "Math";
Simp :: #import "Simp";
Stb :: #import "stb_image";
