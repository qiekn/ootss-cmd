#!/usr/bin/env jai

// jai -quiet scripts/check_hud.jai -import_dir ../modules - [game-font-directory]
// Pixel checks use memory buffers; the optional window smoke test stays offscreen.
// No screenshots are viewed and no game memory or game input is written.
#run {
    set_build_options_dc(.{do_output = false});
    check_layout();
    check_alpha();
    args := get_build_options().compile_time_command_line;
    if args.count > 1 compiler_report("Expected an optional game font directory.");
    if args.count == 1 { check_font(args[0]); check_window(); }
    print("PASS: % HUD layout and alpha checks.\n", checks);
}

check_window :: () {
    before := Win.GetForegroundWindow();
    dc := Win.wglGetCurrentDC();
    panel: App.Hud_Panel;
    defer {
        App.hud_panel_hide(*panel);
        if panel.window Win.DestroyWindow(panel.window);
        App.overlay_image_surface_free(*panel.surface);
        free(panel.mask.data);
        free(panel.text);
    }
    App.hud_draw_panel(*panel, -32000, -32000, 600, 81, "overworld\n(80, 81, 0)", 27, false, 255);
    check(panel.visible && panel.surface.pixels != null, "Present a premultiplied HUD offscreen without a GL drawable.");
    check(panel.surface.width < 600, "Information surface is limited to its text width.");
    panel.surface.pixels[0] = 1;
    App.hud_draw_panel(*panel, -32000, -32000, 600, 81, "overworld\n(80, 81, 0)", 27, false, 255);
    check(panel.surface.pixels[0] == 1, "Unchanged HUD pixels are cached.");
    App.hud_draw_panel(*panel, -32000, -32000, 600, 81, "overworld\n(80, 81, 0)", 27, false, 128);
    check(panel.surface.pixels[0] == 1 && panel.opacity == 128, "Opacity changes do not rasterize the font again.");
    check(Win.GetForegroundWindow() == before && Win.wglGetCurrentDC() == dc, "HUD presentation changes neither input focus nor GL context.");
}

checks: s64;
check :: (condition: bool, message: string) {
    checks += 1;
    if !condition { compiler_report(message); assert(condition); }
}

check_layout :: () {
    check(App.hud_font_height(720, 10) == 72, "Notice size is rows per screen, not pixels.");
    check(App.hud_font_height(1080, App.HUD_NOTICE_SIZE) == 36, "1080p notices use height / 30.");
    check(App.hud_font_height(2160, App.HUD_NOTICE_SIZE) == 72, "2160p notices use the same height / 30 rule.");
    check(App.hud_font_height(1080, App.HUD_INFO_SIZE) == 27, "Info uses the same height/size rule.");
    sample: App.Game_Position_Sample = .{valid = true, position = .[2, 7, 0], controlled_count = 3};
    check(App.hud_details("mirror_12", sample) == "mirror_12\n(2, 7, 0)", "HUD displays exactly the level and shared controlled-group anchor.");
    check(App.hud_details("overworld", .{}) == "overworld\nUnavailable", "A missing player never reuses stale coordinates.");
    App.overlay.visible = true;
    defer App.overlay.visible = false;
    App.hud.info.visible = true;
    App.hud.toast.visible = true;
    App.hud_update(1);
    check(!App.hud.info.visible && !App.hud.toast.visible, "Opening either console mode hides both HUD panels.");
    state: App.Console_State;
    defer App.console_deinit(*state);
    App.command_hud(*state, "DISABLE");
    check(!App.hud.enabled, "HUD disable is case-insensitive.");
    App.command_hud(*state, "enable extra");
    check(!App.hud.enabled, "Invalid HUD options do not change the state.");
    App.command_hud(*state, "");
    check(App.hud.enabled, "Bare HUD toggles on.");
    App.command_hud(*state, "ENABLE");
    check(App.hud.enabled, "Explicit enable is idempotent.");
    App.console_set_input(*state, "hud dis");
    App.console_complete(*state, .[], .[], .[]);
    check(App.console_input(*state) == "hud disable ", "HUD options have completion.");
}

check_alpha :: () {
    mask: [81] u8;
    pixels: [324] u8;
    App.hud_compose_pixels(mask, pixels.data, 9, 9, 1);
    empty := true;
    for value: pixels if value empty = false;
    check(empty, "Empty pixels remain fully transparent.");
    mask[4*9+4] = 128;
    App.hud_compose_pixels(mask, pixels.data, 9, 9, 1);
    edge := pixels.data + (4*9+4)*4;
    check(edge[0] == 128 && edge[1] == 128 && edge[2] == 128 && edge[3] >= 128 && edge[3] < 150,
          "Antialiased white pixels keep coverage instead of becoming opaque grey.");
    shadow := pixels.data + (5*9+5)*4;
    check(shadow[0] == 0 && shadow[3] > 0 && shadow[3] <= 64, "Shadow is soft and low-opacity.");
    mask[4*9+4] = 255;
    App.hud_compose_pixels(mask, pixels.data, 9, 9, 1);
    check(edge[0] == 255 && edge[3] == 255, "Solid text stays white.");
    valid := true;
    for i: 0..80 for c: 0..2 if pixels[i*4+c] > pixels[i*4+3] valid = false;
    check(valid, "All channels obey Windows premultiplied-alpha requirements.");
}

check_font :: (directory: string) {
    for size: s32.[27, 36] {
        font := Simp.get_font_at_size(directory, "KarminaBold.otf", size);
        check(font != null, "Load the game's Karmina Bold font without a GL drawable.");
        width: s32 = 1920;
        height := size*2;
        mask := NewArray(width*height, u8);
        pixels := NewArray(width*height*4, u8);
        defer free(mask.data); defer free(pixels.data);
        App.hud_raster_line(mask, width, height, font, "Freecam enabled", 8, size);
        App.hud_compose_pixels(mask, pixels.data, width, height, max(cast(s32) 1, size/50));
        covered, partial: s64;
        valid := true;
        for alpha: mask {
            if alpha covered += 1;
            if alpha > 0 && alpha < 255 partial += 1;
        }
        for i: 0..mask.count-1 for c: 0..2 if pixels[i*4+c] > pixels[i*4+3] valid = false;
        check(covered > 100 && partial > 20, "Raster contains real antialiased glyph coverage.");
        check(valid, "Real Karmina glyphs preserve premultiplied alpha.");
        print("Karmina % px: % covered pixels, % antialiased pixels; no GL drawable.\n", size, covered, partial);
    }
}

#import "Basic";
#import "Compiler";
#import "System";
App :: #import,file "../src/main.jai";
Simp :: #import "Simp";
Win :: #import "Windows";
