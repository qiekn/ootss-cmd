#!/usr/bin/env jai

// jai -quiet scripts/check_hud.jai -import_dir ../modules - [game-font-directory]
// Pixel checks use memory buffers; the optional window smoke test stays offscreen.
// No screenshots are viewed and no game memory or game input is written.
#run {
    set_build_options_dc(.{do_output = false});
    check_layout();
    check_config();
    check_text_newlines();
    check_config_application();
    check_custom_text();
    check_many_text_rows();
    check_level_only();
    check_alpha();
    args := get_build_options().compile_time_command_line;
    if args.count > 1 compiler_report("Expected an optional game font directory.");
    if args.count == 1 { check_font(args[0]); check_window(); }
    print("PASS: % HUD layout and alpha checks.\n", checks);
}

check_config :: () {
    config: App.Console_Config;
    defer App.console_config_free(*config);
    check(config.hud.enabled && config.hud.show_level_name && config.hud.show_position && config.hud.show_notifications,
          "Missing HUD settings preserve the existing enabled defaults.");
    sample: App.Game_Position_Sample = .{valid = true, position = .[2, 7, 0]};
    error := App.console_config_parse(*config, "HUD_SHOW_POSITION=FALSE; HUD_SHOW_LEVEL_NAME=TRUE;");
    check(!error.count && !config.hud.show_position && config.hud.rows[0].kind == .POSITION,
          "HUD keys and booleans are case-insensitive; declarations determine order.");
    check(!config.aliases.count, "HUD settings do not become command aliases.");
    check(App.hud_details("mirror_12", sample, config.hud) == "mirror_12" && App.hud_info_line_count(config.hud) == 1,
          "Disabling coordinates leaves exactly the level name without an empty row.");
    config.hud.show_position = true;
    check(App.hud_details("mirror_12", sample, config.hud) == "(2, 7, 0)\nmirror_12", "Reverse the configured top-to-bottom order.");
    config.hud.show_level_name = false;
    check(App.hud_details("mirror_12", sample, config.hud) == "(2, 7, 0)", "Coordinates can also be the only visible item.");
    check(App.hud_details("mirror_12", .{}, config.hud) == "Unavailable", "Missing coordinate data has only its visible placeholder.");
    config.hud.show_position = false;
    check(App.hud_details("mirror_12", sample, config.hud) == "" && !App.hud_info_line_count(config.hud), "Hide the entire information panel when both rows are disabled.");
    error = App.console_config_parse(*config, "hud_enabled=false; hud_show_notifications=false; hud_show_position=false;");
    check(!error.count && !config.hud.enabled && !config.hud.show_notifications, "Parse independent master and notification switches.");
    for invalid: string.[
        "hud_enabled=1;", "hud_show_level_name=yes;", "hud_show_position=off;", "hud_show_notifications=0;",
        "hud_show_position='';", "hud_text='unfinished;"
    ] {
        error = App.console_config_parse(*config, tprint("hud_enabled=true;\n%", invalid));
        check(error.count > 0 && contains(error, "Line 2"), "Reject malformed HUD values with their configuration line.");
        check(!config.hud.enabled && !config.hud.show_notifications && !config.hud.show_position,
              "Invalid HUD settings never partially replace the previous configuration.");
    }
    error = App.console_config_parse(*config, "hud_show_position=false; hud_show_level_name=true; HUD_SHOW_POSITION=TRUE;");
    check(!error.count && config.hud.show_position && App.hud_details("level", sample, config.hud) == "level\n(2, 7, 0)",
          "The last definition of a HUD setting supplies both its value and position.");
    error = App.console_config_parse(*config, "hud_show_position=true;");
    check(!error.count && App.hud_details("level", sample, config.hud) == "(2, 7, 0)\nlevel",
          "Omitted items retain defaults and follow explicit items.");
    assignments := string.[
        "hud_text='Custom'; hud_show_level_name=true; hud_show_position=true;",
        "hud_text='Custom'; hud_show_position=true; hud_show_level_name=true;",
        "hud_show_level_name=true; hud_text='Custom'; hud_show_position=true;",
        "hud_show_level_name=true; hud_show_position=true; hud_text='Custom';",
        "hud_show_position=true; hud_text='Custom'; hud_show_level_name=true;",
        "hud_show_position=true; hud_show_level_name=true; hud_text='Custom';"
    ];
    expected := string.["Custom\nlevel\n(2, 7, 0)", "Custom\n(2, 7, 0)\nlevel", "level\nCustom\n(2, 7, 0)",
                        "level\n(2, 7, 0)\nCustom", "(2, 7, 0)\nCustom\nlevel", "(2, 7, 0)\nlevel\nCustom"];
    for input: assignments {
        error = App.console_config_parse(*config, input);
        check(!error.count && !config.aliases.count && App.hud_info_line_count(config.hud) == 3 &&
              App.hud_details("level", sample, config.hud) == expected[it_index], "All three HUD rows follow file order.");
    }
    error = App.console_config_parse(*config, "HUD_TEXT='first'; hud_show_level_name=true; HUD_TEXT='Custom # text; 100%'; hud_show_position=false;");
    check(!error.count && App.hud_details("level", sample, config.hud) == "first\nlevel\nCustom # text; 100%",
          "Each custom text declaration adds a row in place; quoted punctuation stays literal.");
    error = App.console_config_parse(*config, "hud_text='replacement';\nhud_show_position=no;");
    check(error.count > 0 && App.hud_details("level", sample, config.hud) == "first\nlevel\nCustom # text; 100%",
          "Invalid replacement retains every owned custom text row and its ordering.");
    error = App.console_config_parse(*config, "hud_text=''; hud_show_position=false;");
    check(!error.count && App.hud_info_line_count(config.hud) == 2 &&
          App.hud_details("level", sample, config.hud) == "\nlevel", "Empty custom text preserves a leading blank row.");
    error = App.console_config_parse(*config, "hud_text='same'; hud_text=''; HUD_TEXT='same'; hud_show_level_name=false; hud_show_position=false;");
    check(!error.count && App.hud_details("level", sample, config.hud) == "same\n\nsame" && App.hud_info_line_count(config.hud) == 3,
          "Empty text separates custom rows without reintroducing disabled position or level rows.");
    error = App.console_config_parse(*config, "hud_show_position=false; hud_show_level_name=true; hud_text=''; hud_text='';");
    check(!error.count && App.hud_details("level", sample, config.hud) == "level\n\n" && App.hud_info_line_count(config.hud) == 3,
          "Consecutive trailing blanks retain their own rows.");
    error = App.console_config_parse(*config, "hud_show_position=false; hud_show_level_name=false; hud_text=''; hud_text='';");
    check(!error.count && App.hud_details("level", sample, config.hud) == "\n" && App.hud_info_line_count(config.hud) == 2,
          "An all-blank HUD keeps spacing without displaying unavailable position placeholders.");
    error = App.console_config_parse(*config, "hud_show_level_name=true; hud_text='first'; hud_show_position=true; hud_text='second'; hud_show_level_name=true;");
    check(!error.count && App.hud_details("level", sample, config.hud) == "first\n(2, 7, 0)\nsecond\nlevel",
          "A repeated built-in moves only its own row, preserving every custom row.");
    error = App.console_config_parse(*config, "");
    check(!error.count && config.hud.enabled && config.hud.show_position && config.hud.rows.count == 2 && config.hud.rows[0].kind == .LEVEL_NAME,
          "Removing HUD settings restores their defaults.");
    check(config.hud.hide_on_focus_loss, "Omitted focus settings preserve automatic HUD hiding.");
    error = App.console_config_parse(*config, "hud_hide_on_focus_loss=true; HUD_HIDE_ON_FOCUS_LOSS=FALSE;");
    check(!error.count && !config.hud.hide_on_focus_loss && !config.aliases.count,
          "The focus setting is case-insensitive, uses the last value and never becomes an alias.");
    for value: string.["1", "yes", "", "invalid"] {
        error = App.console_config_parse(*config, tprint("hud_text='changed';\nhud_hide_on_focus_loss=%;", value));
        check(error.count > 0 && contains(error, "Line 2") && !config.hud.hide_on_focus_loss && config.hud.rows.count == 2,
              "Invalid focus settings reject the whole file and preserve the previous HUD configuration.");
    }
    error = App.console_config_parse(*config, "");
    check(!error.count && config.hud.hide_on_focus_loss, "Removing the focus setting restores automatic hiding.");
}

check_text_newlines :: () {
    config: App.Console_Config;
    defer App.console_config_free(*config);
    hidden := "hud_show_level_name=false; hud_show_position=false; ";
    error := App.console_config_parse(*config, tprint("%hud_text=\"First\\nSecond\"; hud_text='Third\\n\\nFourth';", hidden));
    check(!error.count && App.hud_details("", .{}, config.hud) == "First\nSecond\nThird\n\nFourth" &&
          App.hud_info_line_count(config.hud) == 5, "Both quote styles decode newlines and count every displayed row.");
    error = App.console_config_parse(*config, tprint("%hud_text='\\nBody\\n';", hidden));
    check(!error.count && App.hud_details("", .{}, config.hud) == "\nBody\n" && App.hud_info_line_count(config.hud) == 3,
          "Leading and trailing escaped newlines preserve blank rows.");
    error = App.console_config_parse(*config, tprint("%hud_text='\\n\\n';", hidden));
    check(!error.count && App.hud_details("", .{}, config.hud) == "\n\n" && App.hud_info_line_count(config.hud) == 3,
          "Newline-only text retains every blank row.");
    error = App.console_config_parse(*config, tprint("%hud_text='First\\\\nSecond';", hidden));
    check(!error.count && App.hud_details("", .{}, config.hud) == "First\\nSecond" && App.hud_info_line_count(config.hud) == 1,
          "An escaped backslash keeps literal backslash-n instead of creating a line break.");
    error = App.console_config_parse(*config, tprint("%hud_text='First\\\\\\nSecond';", hidden));
    check(!error.count && App.hud_details("", .{}, config.hud) == "First\\\nSecond" && App.hud_info_line_count(config.hud) == 2,
          "A literal backslash and a following newline decode independently.");
    error = App.console_config_parse(*config, tprint("%hud_text='  First\\nSecond  '; game_path='C:\\new'; example='echo \\n';", hidden));
    check(!error.count && App.hud_details("", .{}, config.hud) == "  First\nSecond  ",
          "Quoted custom text preserves its whitespace.");
    check(config.game_path == "C:\\new" && config.aliases.count == 1 && config.aliases[0].command == "echo \\n",
          "HUD newline decoding leaves path and alias backslashes unchanged.");
    error = App.console_config_parse(*config, "hud_text='Changed\\ntext';\nhud_enabled=invalid;");
    check(error.count > 0 && contains(error, "Line 2") && App.hud_details("", .{}, config.hud) == "  First\nSecond  ",
          "A malformed replacement retains the previous multiline text and reports the physical file line.");
}

check_config_application :: () {
    App.hud_deinit();
    defer App.hud_deinit();
    state: App.Console_State;
    defer App.console_deinit(*state);
    settings: App.Hud_Config;
    App.hud.reader.objects = NewArray(2, u64);
    App.hud.reader.scratch = NewArray(2, u64);
    settings.show_position = false;
    App.hud_apply_config(settings);
    check(!App.hud.reader.objects.count && !App.hud.reader.scratch.count, "Disabling coordinates releases the old player-sampling buffers.");
    check(App.hud.next_sample == 0 && App.hud.next_frame == 0, "Changed HUD settings refresh on the next frame.");
    App.hud_notify("notification");
    check(App.hud.message == "notification", "Notifications remain available with only the level name enabled.");
    App.hud.toast.visible = true;
    settings.show_notifications = false;
    App.hud_apply_config(settings);
    check(!App.hud.toast.visible && !App.hud.message.count, "Disabling notifications hides and clears the current one immediately.");
    App.hud_notify("hidden");
    check(!App.hud.message.count, "Do not queue notifications while their switch is off.");
    settings.show_notifications = true;
    App.hud_apply_config(settings);
    check(!App.hud.message.count, "Re-enabling notifications does not resurrect an old message.");
    App.hud.info.visible = true;
    settings.show_level_name = false;
    App.hud_apply_config(settings);
    check(!App.hud.info.visible && !App.hud.details.count, "Disabling both information items removes their panel.");
    App.hud_notify("notification only");
    check(App.hud.message == "notification only", "Notifications work when the information panel is disabled.");
    App.command_hud(*state, "disable");
    settings.show_level_name = true;
    App.hud_apply_config(settings);
    check(!App.hud.enabled, "Changing item switches keeps a manual hud disable in effect.");
    settings.enabled = false;
    App.hud_apply_config(settings);
    settings.enabled = true;
    App.hud_apply_config(settings);
    check(App.hud.enabled, "Changing the persistent master switch explicitly sets the session switch.");
    App.command_hud(*state, "disable");
    App.hud_apply_config(settings);
    check(!App.hud.enabled, "Unrelated reloads do not override a manual HUD switch.");
    App.command_hud(*state, "enable");
    check(App.hud.enabled && !App.hud.settings.show_position, "Console hud enable retains configured item visibility.");
    settings.enabled = false;
    App.hud_apply_config(settings);
    App.hud_notify("master off");
    check(!App.hud.enabled && !App.hud.message.count, "The persistent master switch also blocks notifications.");
}

check_custom_text :: () {
    App.hud_deinit();
    defer App.hud_deinit();
    config: App.Console_Config;
    defer App.console_config_free(*config);
    error := App.console_config_parse(*config, "hud_text='Custom'; hud_text='Second'; hud_show_level_name=false; hud_show_position=false;");
    check(!error.count, "Parse standalone custom text.");
    App.hud_apply_config(config.hud);
    check(App.hud.settings.rows.data != config.hud.rows.data &&
          App.hud.settings.rows[0].text.data != config.hud.rows[0].text.data &&
          App.hud.settings.rows[1].text.data != config.hud.rows[1].text.data,
          "Applied HUD owns both the row array and a separate copy of every custom string.");
    config.hud.rows[0].text.data[0] = #char "X";
    config.hud.rows[1].text.data[0] = #char "X";
    App.console_config_free(*config);
    App.hud_sample(seconds_since_init());
    check(App.hud.details == "Custom\nSecond" && !App.hud.reader.memory.handle && !App.hud.reader.objects.count,
          "Custom text survives config release and displays without reading game memory.");
    error = App.console_config_parse(*config, "hud_text='Changed'; hud_show_level_name=false; hud_show_position=false;");
    check(!error.count, "Parse a text-only update.");
    App.hud_apply_config(config.hud);
    App.hud_sample(seconds_since_init());
    check(App.hud.details == "Changed", "Changing only custom text refreshes the sampled display.");
    App.hud.enabled = false;
    App.console_config_hud_item(*config.hud, .LEVEL_NAME);
    App.hud_apply_config(config.hud);
    check(!App.hud.enabled, "Reordering custom text does not override the session master switch.");
    error = App.console_config_parse(*config, "hud_show_level_name=false; hud_show_position=false;");
    check(!error.count, "Parse removal of custom text.");
    App.hud_apply_config(config.hud);
    check(!App.hud.details.count && !App.hud_info_line_count(App.hud.settings),
          "Deleting the final custom row removes the information panel.");
}

check_many_text_rows :: () {
    builder: String_Builder;
    defer free_buffers(*builder);
    for i: 1..80 print_to_builder(*builder, "hud_text='Line %';\n", i);
    append(*builder, "hud_show_level_name=false; hud_show_position=false;");
    source := builder_to_string(*builder);
    defer free(source);
    config: App.Console_Config;
    defer App.console_config_free(*config);
    error := App.console_config_parse(*config, source);
    check(!error.count && App.hud_info_line_count(config.hud) == 80, "Repeated text grows past the old fixed row count.");
    details := App.hud_details("", .{}, config.hud);
    check(begins_with(details, "Line 1\nLine 2\n") && ends_with(details, "Line 79\nLine 80"),
          "Long text lists preserve first-to-last order through array growth.");
    check(App.hud_info_panel_height(27, 10, 1000) == 318, "Panel height includes spacing for every text row.");
    check(App.hud_info_panel_height(27, 80, 1000) == 1000, "Large text lists keep their surface within the game client.");
    check(App.hud_info_panel_height(27, 0, 1000) == 0 && App.hud_info_panel_height(27, 80, 0) == 0,
          "No rows or no available height needs no information surface.");
}

check_level_only :: () {
    // A valid scene containing no Guy list: reading the level must not attempt
    // to resolve characters, their types, selection or position fields.
    memory := NewArray(0x1000, u8);
    defer free(memory.data);
    base := cast(u64) memory.data;
    memory[0x40] = 0x90;
    (cast(*u64)(memory.data + 0x80)).* = base + 0x200;
    name := "mirror_12";
    header := cast(*App.Game_Entity_List)(memory.data + 0x200);
    header.* = .{count = cast(u64) name.count, data = base + 0x300};
    for c: name memory[0x300 + it_index] = c;
    state: App.Hud_State;
    defer App.game_position_reader_close(*state.reader);
    state.settings.show_position = false;
    state.reader.memory = .{handle = Win.GetCurrentProcess(), module = .{base = base, size = cast(u64) memory.count}};
    state.reader.locator = .{slot = base + 0x80, instruction = base + 0x40, count = 1};
    state.reader.locator.bytes[0] = 0x90;
    state.reader.error = "position reader untouched";
    details, error := App.hud_read_details(*state, 1);
    check(!error.count && details == name, "Show the scene name without any player entities.");
    check(state.reader.error == "position reader untouched" && !state.reader.resolutions && !state.reader.scratch.count,
          "Level-only HUD never calls the position sampler.");
    free(details);
    header.data = 0;
    details, error = App.hud_read_details(*state, 2);
    check(error.count > 0 && details == "Unavailable", "Invalid scene data never reuses a stale level name.");
    free(details);
    state.settings.show_level_name = false;
    details, error = App.hud_read_details(*state, 3);
    check(!error.count && !details.count && state.reader.error == "position reader untouched", "With both items disabled, even invalid scene memory is never read.");
    free(details);
    state.settings.show_position = true;
    details, error = App.hud_read_details(*state, 4);
    check(!error.count && details == "Unavailable" && state.reader.error != "position reader untouched",
          "Position-only mode queries characters without requiring a level-name read.");
    free(details);
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
#import "String";
App :: #import,file "../src/main.jai";
Simp :: #import "Simp";
Win :: #import "Windows";
