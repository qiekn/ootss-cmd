#import "Basic";
#import "String";
#import "System";
#import "Math";
#import "Windows_Utf8";

Simp  :: #import "Simp";
Input :: #import "Input";
Win   :: #import "Windows";

#load "platform/windows/clipboard.jai";
#load "platform/windows/input.jai";
#load "platform/windows/console.jai";
#load "platform/windows/process.jai";
#load "platform/windows/game_paths.jai";
#load "platform/windows/subtitles.jai";
#load "platform/windows/overlay.jai";
#load "platform/windows/image.jai";
#load "platform/windows/tray.jai";
#load "platform/windows/send_monitor.jai";
#load "platform/windows/shortcuts.jai";
#load "platform/windows/noclip.jai";
#load "platform/windows/freecam.jai";
#load "platform/windows/editor.jai";
#load "platform/windows/zork.jai";

#load "game/commands.jai";
#load "game/keymap.jai";
#load "game/memory.jai";
#load "game/camera_layout.jai";
#load "game/camera.jai";
#load "game/freecam.jai";
#load "game/level.jai";
#load "game/position_reader.jai";
#load "game/position_selection.jai";
#load "game/position_layout.jai";
#load "game/position_markers.jai";
#load "game/position_commands.jai";
#load "game/noclip.jai";
#load "game/shortcuts.jai";
#load "game/state.jai";
#load "game/subtitle_mapping.jai";
#load "game/subtitles.jai";

#load "solution/solution.jai";
#load "solution/timeline.jai";
#load "solution/transport.jai";
#load "solution/editor.jai";
#load "solution/editor_save.jai";
#load "solution/editor_view.jai";

#load "ui/console.jai";
#load "ui/fonts.jai";
#load "ui/console_view.jai";
#load "ui/subtitles_view.jai";

console: Console_State;
pending_high_surrogate: u32;

main :: () {
    defer process_console_deinit();
    if !process_console_init() {
        print("Could not install the command-line Ctrl+C handler (Windows error %).\n", Win.GetLastError());
        return;
    }

    overlay_enable_dpi_awareness();
    set_working_directory(path_strip_filename(get_path_of_running_executable()));
    if !overlay_create() {
        show_error("Unable to create the transparent console window.");
        return;
    }
    defer overlay_destroy();
    defer console_deinit(*console);
    defer shortcuts_deinit();
    defer noclip_deinit();
    defer freecam_deinit();
    defer zork_deinit();
    if !tray_init(overlay.window) {
        show_error("Unable to create the system tray icon.");
        return;
    }
    defer tray_deinit();

    timer_started := Win.timeBeginPeriod(1) == 0;
    defer if timer_started Win.timeEndPeriod(1);

    Simp.prepare_window(overlay.window, wanted_msaa = 0);
    Simp.set_render_target(overlay.window, .LEFT_HANDED);
    render_dc := Win.wglGetCurrentDC();
    config_error := console_config_load(*console.config);
    if !console_load_fonts() return;
    defer console_images_deinit();
    defer subtitles_view_free(*subtitles_view);
    defer editor_deinit();
    if process_console_should_exit() return;

    shortcut_error := shortcuts_install();
    if config_error.count console_write(*console, config_error, .ERROR);
    else if shortcut_error.count console_write(*console, shortcut_error, .ERROR);
    else console_startup_presentation(*console);
    draw_console();
    Win.SwapBuffers(render_dc);
    if overlay.game overlay_show();

    next_game_check := seconds_since_init() + 0.5;
    next_editor_frame: float64;
    while true {
        if process_console_should_exit() overlay.quit_requested = true;
        if overlay.quit_requested {
            overlay.quit_requested = false;
            process_console_acknowledge_exit();
            if editor_request_program_exit() break;
        }
        Input.update_window_events();
        // A tray menu may block, so process it only after playback has released its held key.
        tray_process_requests();

        if overlay.toggle_requested || overlay.show_requested || overlay.quick_requested {
            show := overlay.show_requested || overlay.quick_requested || !overlay.visible;
            mode := ifx overlay.quick_requested && !overlay.show_requested then Console_Mode.MINI else overlay.full_mode;
            overlay.opening_punctuation = (overlay.show_requested || overlay.quick_requested) &&
                                          Win.GetAsyncKeyState(Win.VK_OEM_1) < 0;
            overlay.toggle_requested = false;
            overlay.show_requested = false;
            overlay.quick_requested = false;
            pending_high_surrogate = 0;
            if show overlay_show(mode);
            else overlay_hide();
        }

        now := seconds_since_init();
        if now >= next_game_check {
            tray_update();
            overlay_update_game();
            next_game_check = now + 0.5;
        }
        overlay_update_focus();
        overlay_update_hotkey();
        if Win.GetForegroundWindow() != overlay.window pending_high_surrogate = 0;
        zork_update(*console);

        for event: Input.events_this_frame {
            if event.type == .QUIT overlay.quit_requested = true;
            if !overlay.visible || Win.GetForegroundWindow() != overlay.window continue;
            if event.type == .TEXT_INPUT {
                console_text_input(event.utf32);
            } else if event.type == .KEYBOARD && event.key_pressed {
                console_key_input(event);
            } else if event.type == .MOUSE_WHEEL {
                if overlay.mode == .MINI continue;
                if console.show_subtitles {
                    ticks := cast(float64) event.wheel_delta / max(1, event.typical_wheel_delta);
                    subtitles_view_scroll(-ticks * 3 * subtitles_view.line_height);
                } else {
                    if event.wheel_delta > 0 console.scroll += 3;
                    if event.wheel_delta < 0 console.scroll = max(0, console.scroll - 3);
                }
            }
        }

        shortcuts_update();

        if console.pending_action == .HIDE overlay_hide();
        if console.pending_action == .EXIT overlay.quit_requested = true;
        if console.pending_action == .SHOW_POSITION {
            position, error := game_read_position();
            if error.count console_write(*console, error, .ERROR);
            else console_write(*console, game_position_text(position));
        }
        if console.pending_action == .SHOW_LEVEL console_show_current_level(*console);
        if console.pending_action == .SHOW_SUBTITLES console_open_subtitles(*console);
        if console.pending_action == .SET_POSITION console.pending_position_change = true;
        if console.pending_action == .SWITCH_LEVEL console_prepare_switch(*console);
        console_run_marker_action(*console);
        if console.pending_action == .NOCLIP console_set_noclip(*console);
        if console.pending_action == .FREECAM console.pending_freecam_change = true;
        if console.pending_action == .CONSOLE_MODE overlay_set_mode(console.pending_mode);
        if console.pending_action == .EDIT_SOLUTION editor_open_solution(console.pending_edit_level, console.pending_edit_custom);
        if console.pending_action == .PLAY_SOLUTION console_play_saved_solution(*console);
        if console.pending_action == .JUMP editor_jump_solution(console.pending_jump_step);
        if console.pending_action == .ZORK_START zork_start(*console);
        if console.pending_action == .ZORK_INPUT zork_send_input(*console);
        if console.pending_action == .ZORK_BACK zork_back(*console);
        editor_run_console_action(console.pending_action);
        console.pending_action = .NONE;
        free(console.pending_zork_input);
        console.pending_zork_input = "";
        free(console.pending_play.source);
        console.pending_play = .{};
        free(console.pending_edit_level);
        console.pending_edit_level = "";
        console.pending_edit_custom = false;
        free(console.pending_subtitle_level);
        console.pending_subtitle_level = "";
        console.pending_subtitle_comments = false;
        console.pending_subtitle_hide_speakers = false;
        console.pending_subtitle_language = .BOTH;
        free(console.pending_marker_name);
        free(console.pending_marker_new_name);
        console.pending_marker_name = "";
        console.pending_marker_new_name = "";
        console.pending_marker_current = false;
        free(console.pending_switch_level);
        console.pending_switch_level = "";
        noclip_update(*console, now);
        editor_update(now);
        if editor.open && console.pending_reset editor_pause();
        if editor.open && console.pending_send.count && !console.pending_reset {
            console_write(*console, "Use the editor controls, or close it with Exit before send/play/do/undo.", .ERROR);
            free(console.pending_send);
            console.pending_send = "";
            console.pending_send_hold_ms = DEFAULT_HOLD;
            console.pending_send_interval_ms = DEFUALT_INTERVAL;
            console.pending_send_time_mode = .NORMAL;
            console.pending_send_interruptible = false;
        }
        reset_requested := console.pending_reset;
        sent_keys := console_run_pending_send(*console);
        if reset_requested && sent_keys > 0 editor_on_game_reset();
        console_run_pending_position(*console);
        console_run_pending_freecam(*console);
        freecam_update(*console, seconds_since_init());
        if !console.pending_send.count && !console.pending_position_change && !console.pending_freecam_change console.submission = .{};
        zork_update(*console);
        overlay_present_output(*console);

        if overlay.visible && overlay_update_bounds() {
            Simp.set_render_target(overlay.window, .LEFT_HANDED);
            Simp.update_window(overlay.window);
            if !console_load_fonts() break;
            draw_console();
            // Reuse the context's DC: Simp.swap_buffers calls GetDC on every frame,
            // which would leak common DCs on our window class without CS_OWNDC.
            Win.SwapBuffers(render_dc);
        }

        if editor_window.visible && now >= next_editor_frame {
            draw_solution_editor();
            next_editor_frame = now + 1.0 / 60;
        }

        busy := editor.open && (editor.recording || editor_busy() || editor_view.dragging);
        sleep_milliseconds(cast(s32) ifx busy then 1 else ifx freecam.enabled then 8
                           else ifx overlay.visible || editor_window.visible then 16 else 32);
        reset_temporary_storage();
    }
}

console_key_input :: (event: Input.Event) {
    if (event.ctrl_pressed && event.key_code == #char "V") ||
       (event.shift_pressed && event.key_code == .INSERT) {
        if !event.repeat console_paste_from_clipboard(*console, overlay.window);
        return;
    }
    if event.ctrl_pressed {
        if console.show_subtitles && (event.key_code == .HOME || event.key_code == .END) {
            subtitles_view.scroll = ifx event.key_code == .HOME then 0.0 else subtitles_view.max_scroll;
            return;
        }
        if event.key_code == #char "C" || event.key_code == #char "D" {
            overlay_hide();
            return;
        }
        if event.key_code == #char "Q" {
            overlay.quit_requested = true;
            return;
        }
        if event.key_code == #char "W" {
            console_delete_previous_word(*console);
            return;
        }
        if event.key_code == .DELETE {
            console_delete_next_word(*console);
            return;
        }
        if event.key_code == #char "U" {
            console_clear_before_cursor(*console);
            return;
        }
    }
    if event.alt_pressed && event.key_code == .F4 {
        overlay.quit_requested = true;
        return;
    }
    if event.key_code == {
        case .ESCAPE;      overlay_hide();
        case .ENTER;       if !event.repeat console_submit_window();
        case .TAB;         if !event.repeat && !event.ctrl_pressed && !event.alt_pressed console_tab_complete(event.shift_pressed);
        case .BACKSPACE;   console_backspace(*console);
        case .DELETE;      console_delete(*console);
        case .ARROW_LEFT;  console.cursor = console_previous_character(*console);
        case .ARROW_RIGHT; console.cursor = console_next_character(*console);
        case .HOME;        console.cursor = 0;
        case .END;         console.cursor = console.input.count;
        case .ARROW_UP;    console_history(*console, -1);
        case .ARROW_DOWN;  console_history(*console, 1);
        case .PAGE_UP;
            if console.show_subtitles subtitles_view_scroll(-cast(float64) max(subtitles_view.line_height, subtitles_view.viewport_height - subtitles_view.line_height));
            else console.scroll += 10;
        case .PAGE_DOWN;
            if console.show_subtitles subtitles_view_scroll(cast(float64) max(subtitles_view.line_height, subtitles_view.viewport_height - subtitles_view.line_height));
            else console.scroll = max(0, console.scroll - 10);
    }
}

console_tab_complete :: (backwards: bool) {
    levels, customs, subtitle_levels, marker_names: [..] string;
    defer array_free(levels);
    defer array_free(customs);
    defer array_free(subtitle_levels);
    defer array_free(marker_names);
    markers: Position_Markers;
    defer position_markers_free(*markers);
    database, custom_database: Solutions_Database;
    defer solutions_free(*database);
    defer solutions_free(*custom_database);
    catalog: Subtitles_Catalog;
    defer subtitles_catalog_free(*catalog);
    if !console_completion_is_current(*console) {
        kind := console_completion_context(*console);
        if kind == .MARKER_NAME {
            error := position_markers_load(*markers);
            if !error.count for entry: markers.entries array_add(*marker_names, entry.name);
        }
        if kind == .EDIT || kind == .PLAY {
            error := solutions_load(*database, marker_file = ifx kind == .PLAY then "" else "data/marker.json", answer_file = "");
            if !error.count for entry: database.entries array_add(*levels, entry.name);
        }
        if kind == .SWITCH {
            error := level_catalog_load(*database);
            if !error.count for entry: database.entries array_add(*levels, entry.name);
        }
        if kind == .EDIT || kind == .CUSTOM || kind == .PLAY {
            error := custom_inputs_load(*custom_database);
            if !error.count for entry: custom_database.entries array_add(*customs, entry.name);
        }
        if kind == .SUBTITLES {
            directory := game_subtitles_directory();
            if directory.count {
                language: Console_Subtitle_Language;
                input, alias_error := console_expand_aliases(*console, console_input(*console));
                defer free(input);
                position: s64;
                while position < input.count {
                    option := console_subtitle_language_option(console_next_argument(input, *position));
                    if option != .BOTH language = option;
                }
                error := subtitles_catalog_load(*catalog, directory, load_english = language != .CHINESE, load_chinese = language != .ENGLISH, mapping_file = SUBTITLES_MAPPING_FILE);
                if !error.count subtitles_collect_names(*catalog, *subtitle_levels);
            }
        }
    }
    console_complete(*console, levels, customs, subtitle_levels, backwards, marker_names);
}

console_text_input :: (character: u32) {
    // Input's Windows WM_CHAR events contain UTF-16 code units, including surrogate pairs.
    if character >= 0xd800 && character <= 0xdbff {
        pending_high_surrogate = character;
        return;
    }
    if character >= 0xdc00 && character <= 0xdfff {
        if !pending_high_surrogate return;
        character = 0x10000 + ((pending_high_surrogate - 0xd800) << 10) + character - 0xdc00;
    }
    pending_high_surrogate = 0;
    console_insert_character(*console, character);
}

show_error :: (message: string) {
    Win.MessageBoxW(null, utf8_to_wide(message,, temp), utf8_to_wide("OOTSS Console",, temp), Win.MB_ICONERROR);
}
