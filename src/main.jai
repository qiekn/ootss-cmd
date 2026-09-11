#import "Basic";
#import "String";
#import "System";
#import "Math";
#import "Windows_Utf8";

Simp :: #import "Simp";
Input :: #import "Input";
Win :: #import "Windows";

#load "console.jai";
#load "win/clipboard_windows.jai";
#load "keyboard.jai";
#load "game_commands.jai";
#load "win/process_console_windows.jai";
#load "console_view.jai";
#load "win/overlay_windows.jai";
#load "win/tray_windows.jai";

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
    if !console_load_fonts() return;
    if process_console_should_exit() return;

    console_write(*console, "Console ready.", .INFO);
    console_write(*console, "Commands: send, send_alt, clear/cl, ls, echo, print, help, xyzzy, hello sailor", .INFO);
    console_write(*console, "Hide: q/quit   Exit: exit/terminate", .INFO);
    if !overlay.global_hotkey_registered {
        console_write(*console, "Ctrl+` is already in use. Use ` while the game is active.", .ERROR);
    }
    draw_console();
    Win.SwapBuffers(render_dc);
    if overlay.game overlay_show();

    next_game_check := seconds_since_init() + 0.5;
    while !overlay.quit_requested {
        if process_console_should_exit() break;
        Input.update_window_events();
        // A tray menu may block, so process it only after playback has released its held key.
        tray_process_requests();

        if overlay.toggle_requested || overlay.show_requested {
            show := overlay.show_requested || !overlay.visible;
            overlay.toggle_requested = false;
            overlay.show_requested = false;
            pending_high_surrogate = 0;
            if show overlay_show();
            else overlay_hide();
        }

        if overlay.visible && Win.GetForegroundWindow() != overlay.window {
            // Alt-Tab or clicking the game closes the console without taking focus back.
            overlay_hide(restore_game = false);
            pending_high_surrogate = 0;
        }

        now := seconds_since_init();
        if now >= next_game_check {
            tray_update();
            overlay_update_game();
            next_game_check = now + 0.5;
        }
        overlay_update_hotkey();

        for event: Input.events_this_frame {
            if event.type == .QUIT overlay.quit_requested = true;
            if !overlay.visible continue;
            if event.type == .TEXT_INPUT {
                console_text_input(event.utf32);
            } else if event.type == .KEYBOARD && event.key_pressed {
                console_key_input(event);
            } else if event.type == .MOUSE_WHEEL {
                if event.wheel_delta > 0 console.scroll += 3;
                if event.wheel_delta < 0 console.scroll = max(0, console.scroll - 3);
            }
        }

        if console.pending_action == .HIDE overlay_hide();
        if console.pending_action == .EXIT overlay.quit_requested = true;
        console.pending_action = .NONE;
        console_run_pending_send(*console);

        if overlay.visible && overlay_update_bounds() {
            Simp.update_window(overlay.window);
            if !console_load_fonts() break;
            draw_console();
            // Reuse the context's DC: Simp.swap_buffers calls GetDC on every frame,
            // which would leak common DCs on our window class without CS_OWNDC.
            Win.SwapBuffers(render_dc);
        }

        sleep_milliseconds(cast(s32) ifx overlay.visible then 16 else 32);
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
        case .ENTER;       if !event.repeat console_submit(*console);
        case .BACKSPACE;   console_backspace(*console);
        case .DELETE;      console_delete(*console);
        case .ARROW_LEFT;  console.cursor = console_previous_character(*console);
        case .ARROW_RIGHT; console.cursor = console_next_character(*console);
        case .HOME;        console.cursor = 0;
        case .END;         console.cursor = console.input.count;
        case .ARROW_UP;    console_history(*console, -1);
        case .ARROW_DOWN;  console_history(*console, 1);
        case .PAGE_UP;     console.scroll += 10;
        case .PAGE_DOWN;   console.scroll = max(0, console.scroll - 10);
    }
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
