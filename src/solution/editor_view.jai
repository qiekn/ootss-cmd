EDITOR_BUTTON_COUNT :: 10;
EDITOR_RESET_BUTTON :: 4;
EDITOR_RABBIT_BUTTON :: 5;
EDITOR_EXPORT_BUTTON :: 6;
EDITOR_MINIMIZE_BUTTON :: 7;
EDITOR_SAVE_BUTTON :: 8;
EDITOR_EXIT_BUTTON :: 9;
EDITOR_INPUT_HINT :: "W/A/S/D or arrows: move; C/X/F/V and digits: actions; B or _: wait.";

// Nerd Font glyphs: Font Awesome controls/arrows and the Material Design swap icon.
// https://www.nerdfonts.com/cheat-sheet
Editor_Icon :: struct {
    RECORD    :: "󰑋"; // 
    STOP      :: "";
    UNDO      :: ""; //  
    STEP      :: ""; // 
    PLAY      :: "";
    PAUSE     :: "";
    SAVE      :: "";
    RESET     :: ""; // 
    RABBIT    :: "󰤇"; // nf-md-rabbit (U+F0907)
    CLIPBOARD :: ""; // nf-fa-clipboard (U+F0EA)
    MINIMIZE  :: ""; // nf-fa-minimize (U+EF3E)
    MAXIMIZA  :: "";
    EDIT      :: ""; // nf-fa-edit (U+F044)
    EXIT      :: "⏻"; // 
    KEYBOARD  :: "";
    UP :: ""; DOWN :: ""; LEFT :: ""; RIGHT :: "";
    SWAP :: "󰣁";
    SLEEP :: "󰒲";
    FUNCTION :: ""; // 󰊕
}


Editor_View :: struct {
    font, small_font: *Simp.Dynamic_Font;
    font_dpi: s32;
    minimized: bool;
    cell_width: float = 36;
    compact_cell_width: float = 28;
    mouse_down, dragging, strip_down: bool;
    down_x: s32;
    origin_head: s64;
    origin_view_head, display_head, drag_head: float;
    wheeling: bool;
    wheel_head: float;
    wheel_last_time: float64;
    recording_motion: bool;
    animation_time: float64 = -1;
    button_down: s64 = -1;
}
editor_view: Editor_View;

editor_scale :: () -> float { return cast(float) editor_window.dpi / 96; }
editor_pitch :: () -> float {
    width := ifx editor_view.minimized then editor_view.compact_cell_width else editor_view.cell_width;
    return width * editor_scale();
}

editor_toggle_minimized :: () {
    if editor_save_prompt.active return;
    editor_set_minimized(!editor_view.minimized);
}

editor_set_minimized :: (minimized: bool) {
    if !editor.open || editor_view.minimized == minimized return;
    editor_view_cancel_drag();
    editor_view.minimized = minimized;
    if minimized && Win.GetForegroundWindow() == editor_window.handle editor_focus_game();
    editor_window_update();
}

editor_view_cancel_drag :: () {
    was_dragging := editor_view.dragging;
    editor_view.mouse_down = false;
    editor_view.dragging = false;
    editor_view.strip_down = false;
    editor_view.button_down = -1;
    if was_dragging editor_window_set_drag_cursor(false);
}

editor_view_reset :: () {
    editor_view_cancel_drag();
    editor_view.wheeling = false;
    editor_view.recording_motion = false;
    editor_view.display_head = cast(float) editor.timeline.playhead;
    editor_view.drag_head = editor_view.display_head;
    editor_view.animation_time = -1;
}

editor_view_tick :: (now: float64) {
    if editor_view.animation_time < 0 { editor_view.animation_time = now; return; }
    elapsed := max(0.0, min(0.1, cast(float)(now - editor_view.animation_time)));
    editor_view.animation_time = now;
    wanted := cast(float) editor.timeline.playhead;
    if editor_view.dragging && editor_view.mouse_down wanted = editor_view.drag_head;
    else if editor_view.wheeling {
        if now - editor_view.wheel_last_time > 0.18 && !editor_busy() editor_view.wheeling = false;
        else wanted = editor_view.wheel_head;
    }
    else if editor.transport.scrubbing wanted = cast(float) editor.transport.target;
    // Keep visual motion continuous; only the real transport advances the executed boundary.
    blend := cast(float)(elapsed / (0.045 + elapsed));
    editor_view.display_head += (wanted - editor_view.display_head) * blend;
    if abs(wanted - editor_view.display_head) * editor_pitch() < 0.05 editor_view.display_head = wanted;
    if editor_view.display_head == cast(float) editor.timeline.playhead editor_view.recording_motion = false;
}

editor_future_head :: () -> float {
    // Recording increments both future indices and the playhead. Their difference stays fixed.
    if editor_view.recording_motion return cast(float) editor.timeline.playhead;
    return editor_view.display_head;
}

editor_wheel :: (delta: s32, now: float64) {
    if !delta return;
    if !editor_view.wheeling {
        editor_pause();
        editor_view_cancel_drag();
        editor_view.wheel_head = cast(float) editor.timeline.playhead;
        editor_view.wheeling = true;
    }
    editor_view.wheel_last_time = now;
    // Keep partial wheel deltas and the requested destination, even while the game catches up.
    editor_view.wheel_head = max(0.0, min(cast(float) editor.timeline.keys.count,
                                         editor_view.wheel_head - cast(float) delta / 120.0));
    target := cast(s64) floor(editor_view.wheel_head + 0.5);
    if target != editor.transport.target editor_seek(target, scrubbing = true);
}

editor_layout :: () -> (strip: RectUI.Rect, controls: RectUI.Rect) {
    width := cast(float)(editor_window.bounds.right - editor_window.bounds.left);
    scale := editor_scale();
    if editor_view.minimized {
        return RectUI.get_rect(52 * scale, 32 * scale, max(0.0, width - 104 * scale), 40 * scale),
               RectUI.get_rect(width - 44 * scale, 32 * scale, 32 * scale, 40 * scale);
    }
    return RectUI.get_rect(16 * scale, 68 * scale, width - 32 * scale, 78 * scale),
           RectUI.get_rect(20 * scale, 166 * scale, width - 40 * scale, 36 * scale);
}

editor_button_rect :: (index: s64) -> RectUI.Rect {
    strip, controls := editor_layout();
    if editor_view.minimized {
        if index == 0 return RectUI.get_rect(8 * editor_scale(), strip.y, controls.w, strip.h);
        return controls;
    }
    gap := 8 * editor_scale();
    width := min(44 * editor_scale(), (controls.w - gap * (EDITOR_BUTTON_COUNT - 1)) / EDITOR_BUTTON_COUNT);
    total := width * EDITOR_BUTTON_COUNT + gap * (EDITOR_BUTTON_COUNT - 1);
    return RectUI.get_rect(controls.x + (controls.w - total) / 2 + cast(float) index * (width + gap),
                           controls.y, width, controls.h);
}

editor_button_icon :: (index: s64) -> string {
    icons := string.[ifx editor.recording then Editor_Icon.STOP else Editor_Icon.RECORD,
                     Editor_Icon.UNDO, Editor_Icon.STEP,
                     ifx editor.transport.playing then Editor_Icon.PAUSE else Editor_Icon.PLAY,
                     Editor_Icon.RESET, Editor_Icon.RABBIT, Editor_Icon.CLIPBOARD,
                     ifx editor_view.minimized then Editor_Icon.EDIT else Editor_Icon.MINIMIZE,
                     Editor_Icon.SAVE, Editor_Icon.EXIT];
    return icons[index];
}

editor_timeline_icon :: (key: u8) -> string {
    if key == {
        case #char "U"; return Editor_Icon.UP;
        case #char "D"; return Editor_Icon.DOWN;
        case #char "L"; return Editor_Icon.LEFT;
        case #char "R"; return Editor_Icon.RIGHT;
        case #char "C"; return Editor_Icon.SWAP;
        case #char "X"; return Editor_Icon.FUNCTION;
        case #char "_"; return Editor_Icon.SLEEP;
    }
    return "";
}

editor_button_action :: (index: s64) {
    if index == {
        case 0; editor_toggle_record();
        case 1; editor_step(-1);
        case 2; editor_step(1);
        case 3; editor_toggle_play();
        case EDITOR_RESET_BUTTON; editor_reset();
        case EDITOR_RABBIT_BUTTON; editor_test_solution();
        case EDITOR_EXPORT_BUTTON; editor_export_solution();
        case EDITOR_MINIMIZE_BUTTON; editor_toggle_minimized();
        case EDITOR_SAVE_BUTTON; editor_save();
        case EDITOR_EXIT_BUTTON; editor_close();
    }
}

editor_can_edit :: () -> bool {
    return !editor_busy() && !editor_view.wheeling && !editor_save_prompt.active;
}

editor_paste :: () {
    if !editor_can_edit() { editor_set_status("Pause playback before editing."); return; }
    source, error := clipboard_read_text(editor_window.handle);
    defer free(source);
    if error.count { editor_set_status(error, true); return; }
    keys, parse_error := timeline_parse(source);
    defer free(keys);
    if parse_error.count { editor_set_status(parse_error, true); return; }
    error = timeline_insert(*editor.timeline, keys);
    if error.count editor_set_status(error, true);
}

editor_handle_event :: (event: Editor_Event) {
    if editor_save_prompt.active { editor_save_prompt_event(event); return; }
    strip, controls := editor_layout();
    if event.kind == .DOWN {
        editor_view.mouse_down = true;
        editor_view.dragging = false;
        editor_view.down_x = event.x;
        editor_view.button_down = -1;
        for i: 0..EDITOR_BUTTON_COUNT-1 {
            if editor_view.minimized && i != 0 && i != EDITOR_MINIMIZE_BUTTON continue;
            if editor_hit(editor_button_rect(i), event.x, event.y) editor_view.button_down = i;
        }
        editor_view.strip_down = editor_hit(strip, event.x, event.y);
        if editor_view.strip_down {
            editor_pause();
            editor_view.origin_head = editor.timeline.playhead;
            editor_view.origin_view_head = editor_view.display_head;
            editor_view.drag_head = editor_view.display_head;
        }
    } else if event.kind == .MOVE && editor_view.mouse_down && editor_view.strip_down {
        delta := event.x - editor_view.down_x;
        if cast(float) abs(delta) > 6 * editor_scale() editor_view.dragging = true;
        if editor_view.dragging {
            editor_window_set_drag_cursor(true);
            editor_view.drag_head = max(0.0, min(cast(float) editor.timeline.keys.count,
                                               editor_view.origin_view_head - cast(float) delta / editor_pitch()));
            steps := cast(s64)(cast(float) delta / editor_pitch());
            target := max(0, min(editor.timeline.keys.count, editor_view.origin_head - steps));
            if target != editor.transport.target editor_seek(target, scrubbing = true);
        }
    } else if event.kind == .UP {
        if editor_view.mouse_down {
            if editor_view.button_down >= 0 && editor_hit(editor_button_rect(editor_view.button_down), event.x, event.y) {
                editor_button_action(editor_view.button_down);
            } else if editor_view.strip_down && !editor_view.dragging {
                center := strip.x + strip.w / 2;
                index := cast(s64) floor(editor_future_head() + (cast(float) event.x - center) / editor_pitch() + 0.5);
                timeline_move_caret(*editor.timeline, index, event.shift);
                editor_focus_text();
            }
        }
        editor_view_cancel_drag();
    } else if event.kind == .CANCEL {
        if editor_view.mouse_down && editor_view.dragging editor_pause();
        editor_view_cancel_drag();
    } else if event.kind == .WHEEL {
        if event.ctrl {
            width := ifx editor_view.minimized then *editor_view.compact_cell_width else *editor_view.cell_width;
            width.* = max(20.0, min(64.0, width.* + cast(float) event.y / 30.0));
        } else editor_wheel(event.y, seconds_since_init());
    } else if event.kind == .KEY {
        editor_key_input(event);
    } else if event.kind == .TEXT && event.key > 32 && !event.ctrl && !event.alt {
        if event.key < 128 && contains("[]JjKkLlNn", cast(u8) event.key) return;
        if !editor_can_edit() { editor_set_status("Pause playback before editing."); return; }
        if event.key > 127 { editor_set_status(EDITOR_INPUT_HINT); return; }
        key := cast(u8) event.key;
        if key >= #char "a" && key <= #char "z" key -= #char "a" - #char "A";
        if !contains("WASDCXFV0123456789B_", key) { editor_set_status(EDITOR_INPUT_HINT); return; }
        // Typing uses the game's movement layout; pasted and saved scripts still use UDLR.
        if key == #char "W" key = #char "U";
        else if key == #char "S" key = #char "D";
        else if key == #char "A" key = #char "L";
        else if key == #char "D" key = #char "R";
        else if key == #char "B" key = #char "_";
        error := timeline_insert(*editor.timeline, .{data = *key, count = 1});
        if error.count editor_set_status(error, true);
    }
}

editor_key_input :: (event: Editor_Event) {
    if event.key == 0x1b { editor_pause(); editor_focus_game(); return; }
    if event.key == 0x20 { if !event.repeat editor_toggle_play(); return; }
    if event.key == #char "K" && !event.ctrl && !event.alt && !event.shift {
        if !event.repeat editor_toggle_play();
        return;
    }
    if event.key == #char "N" && !event.ctrl && !event.alt && !event.shift {
        if !event.repeat editor_toggle_minimized();
        return;
    }
    direction := editor_step_key_direction(event.key);
    if !event.ctrl && !event.alt && !event.shift && direction != 0 {
        if !event.repeat editor_step(direction, repeat_while_held = editor_step_key_repeats(event.key));
        return;
    }
    if event.ctrl && event.key == #char "Q" { overlay.quit_requested = true; return; }
    if event.ctrl && event.key == #char "S" { if !event.repeat editor_save(); return; }
    if event.ctrl && event.key == #char "C" { if !event.repeat editor_export_solution(); return; }
    if event.alt && event.key == 0x73 { editor_close(); return; }
    if (event.ctrl && event.key == #char "V") || (event.shift && event.key == 0x2d) {
        if !event.repeat editor_paste();
        return;
    }
    if !editor_can_edit() return;
    if event.ctrl && event.key == #char "A" {
        timeline_move_caret(*editor.timeline, editor.timeline.playhead);
        timeline_move_caret(*editor.timeline, editor.timeline.keys.count, select = true);
        return;
    }
    if !event.ctrl && !event.alt && event.key >= 0x25 && event.key <= 0x28 {
        directions := "LURD"; // VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN.
        key := directions[event.key - 0x25];
        error := timeline_insert(*editor.timeline, .{data = *key, count = 1});
        if error.count editor_set_status(error, true);
        return;
    }
    if event.key == {
        case 0x25; if event.ctrl timeline_move_caret(*editor.timeline, editor.timeline.caret - 1, event.shift);
        case 0x27; if event.ctrl timeline_move_caret(*editor.timeline, editor.timeline.caret + 1, event.shift);
        case 0x24; timeline_move_caret(*editor.timeline, editor.timeline.playhead, event.shift);
        case 0x23; timeline_move_caret(*editor.timeline, editor.timeline.keys.count, event.shift);
        case 8;    timeline_delete(*editor.timeline, backwards = true);
        case 0x2e; timeline_delete(*editor.timeline);
    }
}

draw_solution_editor :: () {
    if !editor_window.visible return;
    editor_view_tick(seconds_since_init());
    Simp.set_render_target(editor_window.handle, .LEFT_HANDED);
    Simp.update_window(editor_window.handle);
    width, height := Simp.get_render_dimensions(editor_window.handle);
    scale := editor_scale();
    if editor_view.font_dpi != editor_window.dpi {
        editor_view.font = Simp.get_font_at_size("data/fonts", CONSOLE_FONT_FILE, cast(s32)(21 * scale));
        editor_view.small_font = Simp.get_font_at_size("data/fonts", CONSOLE_FONT_FILE, cast(s32)(13 * scale));
        editor_view.font_dpi = editor_window.dpi;
    }
    if !editor_view.font || !editor_view.small_font return;
    background := console_color(Naysayer.background);
    Simp.clear_scissor();
    Simp.clear_render_target(background.x, background.y, background.z, 1);
    primary := console_color(Naysayer.text);
    muted := console_color(Naysayer.dimmed_variable);
    accent := console_color(Naysayer.punctuation);
    if editor_save_prompt.active {
        editor_draw_save_prompt(cast(float) width);
        Simp.immediate_flush();
        Win.SwapBuffers(editor_window.dc);
        return;
    }
    if editor_view.minimized {
        editor_draw_preview(cast(float) width);
        Simp.immediate_flush();
        Win.SwapBuffers(editor_window.dc);
        return;
    }
    strip, controls := editor_layout();
    center := strip.x + strip.w / 2;
    header := tprint("% / %  %", editor.record.area, editor_record_title(), ifx editor.timeline.dirty then "*" else "");
    editor_draw_text(editor_view.small_font, 20 * scale, 24 * scale, header, primary);
    position := game_position_text(editor.record.position);
    position_width := editor_text_width(editor_view.small_font, position);
    editor_draw_text(editor_view.small_font, cast(float) width - 20 * scale - position_width, 24 * scale, position, muted);
    editor_draw_text(editor_view.small_font, strip.x, 54 * scale, "EXECUTED", muted);
    editor_draw_text(editor_view.small_font, center + 10 * scale, 54 * scale, "FUTURE", accent);
    progress := tprint("% / %", editor.timeline.playhead, editor.timeline.keys.count);
    progress_width := editor_text_width(editor_view.small_font, progress);
    editor_draw_text(editor_view.small_font, strip.x + strip.w - progress_width, 54 * scale, progress, primary);

    editor_draw_timeline(strip);

    mouse: Win.POINT;
    Win.GetCursorPos(*mouse);
    Win.ScreenToClient(editor_window.handle, *mouse);
    labels := string.[ifx editor.recording then "Stop Recording" else "Record", "Undo", "Step",
                      ifx editor.transport.playing then "Pause" else "Play", "Reset: restore last saved solution",
                      "Rabbit: reset and test current solution at 75 ms with fast time", "Export: copy the complete solution",
                      "Minimize (N)", "Save", "Exit"];
    hovered: s64 = -1;
    for label: labels {
        r := editor_button_rect(it_index);
        hover := editor_hit(r, mouse.x, mouse.y);
        if hover hovered = it_index;
        editor_draw_button(it_index, hover);
    }
    Simp.set_scissor(20, 0, width - 20, height);
    status := ifx hovered >= 0 then labels[hovered] else editor.status;
    editor_draw_text(editor_view.small_font, 20 * scale, 221 * scale, status,
                   ifx hovered < 0 && editor.status_error then console_color(Naysayer.warning) else muted);
    editor_draw_text(editor_view.small_font, 20 * scale, 240 * scale,
                   tprint("% SPACE   % Esc   % [/.   % ]/,   % B/_   % Ctrl+C   % Ctrl+S   % N   % :",
                          Editor_Icon.PLAY, Editor_Icon.PAUSE, Editor_Icon.UNDO, Editor_Icon.STEP,
                          Editor_Icon.SLEEP, Editor_Icon.CLIPBOARD, Editor_Icon.SAVE, Editor_Icon.MINIMIZE,
                          Editor_Icon.KEYBOARD), muted);
    Simp.clear_scissor();
    Simp.immediate_flush();
    Win.SwapBuffers(editor_window.dc);
}

editor_draw_timeline :: (strip: RectUI.Rect) {
    scale := editor_scale();
    compact := editor_view.minimized;
    pitch := editor_pitch();
    center := strip.x + strip.w / 2;
    primary := console_color(Naysayer.text);
    muted := console_color(Naysayer.dimmed_variable);
    accent := console_color(Naysayer.punctuation);
    editor_draw_rect(strip, console_color(Naysayer.highlight));
    editor_draw_timeline_cells(strip, editor_view.display_head, past = true);
    editor_draw_timeline_cells(strip, editor_future_head(), past = false);
    Simp.set_scissor(cast(s32) strip.x, cast(s32) strip.y, cast(s32)(strip.x + strip.w), cast(s32)(strip.y + strip.h + 16 * scale));
    editor_draw_rect(RectUI.get_rect(center - scale, strip.y - 2 * scale, 2 * scale, strip.h + 6 * scale), accent);
    if Win.GetForegroundWindow() == editor_window.handle && (cast(s64)(seconds_since_init() * 2) % 2) == 0 {
        x := center + (cast(float) editor.timeline.caret - editor_future_head()) * pitch;
        editor_draw_rect(RectUI.get_rect(x, strip.y + (ifx compact then 4 else 20) * scale,
                                         2 * scale, (ifx compact then 32 else 46) * scale), console_color(Naysayer.white));
    }
    Simp.clear_scissor();
}

editor_draw_timeline_cells :: (strip: RectUI.Rect, head: float, past: bool) {
    scale := editor_scale();
    compact := editor_view.minimized;
    pitch := editor_pitch();
    center := strip.x + strip.w / 2;
    right := ifx past && editor_view.recording_motion then center else strip.x + strip.w;
    Simp.set_scissor(cast(s32) strip.x, cast(s32) strip.y, cast(s32) right, cast(s32)(strip.y + strip.h + 16 * scale));
    // Each side has its own visible range, so a burst of recording cannot push the future offscreen.
    first := max(ifx past then 0 else editor.timeline.playhead, cast(s64) floor(head - strip.w / (2 * pitch)) - 1);
    last := min(ifx past then editor.timeline.playhead else editor.timeline.keys.count,
                cast(s64) floor(head + strip.w / (2 * pitch)) + 2);
    primary := console_color(Naysayer.text);
    muted := console_color(Naysayer.dimmed_variable);
    selected_first, selected_last := timeline_selection(*editor.timeline);
    for i: first..last-1 {
        x := center + (cast(float) i - head) * pitch;
        cell := RectUI.get_rect(x + 3 * scale, strip.y + (ifx compact then 4 else 21) * scale,
                               pitch - 6 * scale, (ifx compact then 32 else 43) * scale);
        color := ifx past then console_color(Naysayer.background) else console_color(Naysayer.selection);
        if i >= selected_first && i < selected_last color = console_color(Naysayer.line_fg);
        editor_draw_rect(cell, color);
        key := editor.timeline.keys[i];
        text: string = .{data = *key, count = 1};
        icon := editor_timeline_icon(key);
        if icon.count text = icon;
        text_width := editor_text_width(editor_view.font, text);
        editor_draw_text(editor_view.font, cell.x + (cell.w - text_width) / 2, cell.y + (ifx compact then 24 else 29) * scale, text,
                       ifx past then muted else primary);
        if !compact {
            number := tprint("%", i + 1);
            number_width := editor_text_width(editor_view.small_font, number);
            editor_draw_text(editor_view.small_font, x + (pitch - number_width) / 2, strip.y + 14 * scale, number, muted);
        }
    }
    Simp.clear_scissor();
}

editor_draw_button :: (index: s64, hover: bool) {
    r := editor_button_rect(index);
    active := (index == 0 && editor.recording) || (index == 3 && editor.transport.playing) ||
              (index == EDITOR_RESET_BUTTON && editor.reset_requested && !editor.test_after_reset) ||
              (index == EDITOR_RABBIT_BUTTON && (editor.test_after_reset || editor.transport.test_playback));
    color := ifx active || hover then console_color(Naysayer.line_fg) else console_color(Naysayer.selection);
    editor_draw_rect(r, color);
    icon := editor_button_icon(index);
    text_width := editor_text_width(editor_view.font, icon);
    editor_draw_text(editor_view.font, r.x + (r.w - text_width) / 2, r.y + (r.h + 14 * editor_scale()) / 2,
                   icon, ifx active then console_color(Naysayer.punctuation) else console_color(Naysayer.text));
}

editor_draw_preview :: (width: float) {
    scale := editor_scale();
    primary := console_color(Naysayer.text);
    muted := console_color(Naysayer.dimmed_variable);
    strip, controls := editor_layout();
    mouse: Win.POINT;
    Win.GetCursorPos(*mouse);
    Win.ScreenToClient(editor_window.handle, *mouse);
    hover := editor_hit(controls, mouse.x, mouse.y);
    record_hover := editor_hit(editor_button_rect(0), mouse.x, mouse.y);
    progress := tprint("% / %", editor.timeline.playhead, editor.timeline.keys.count);
    progress_x := width - 12 * scale - editor_text_width(editor_view.small_font, progress);
    Simp.set_scissor(cast(s32)(12 * scale), 0, cast(s32)(progress_x - 12 * scale), cast(s32)(28 * scale));
    title := ifx hover then "Edit (N)" else ifx record_hover then (ifx editor.recording then "Stop Recording" else "Record")
             else tprint("% / % %", editor.record.area, editor_record_title(), ifx editor.timeline.dirty then "*" else "");
    editor_draw_text(editor_view.small_font, 12 * scale, 20 * scale, title,
                     ifx !editor.synchronized then console_color(Naysayer.warning) else primary);
    Simp.clear_scissor();
    editor_draw_text(editor_view.small_font, progress_x, 20 * scale, progress, muted);
    editor_draw_timeline(strip);
    editor_draw_button(0, record_hover);
    editor_draw_button(EDITOR_MINIMIZE_BUTTON, hover);
}

editor_record_title :: () -> string {
    return ifx editor.record.name.count then editor.record.name else "temp";
}

editor_save_name_rect :: () -> RectUI.Rect {
    strip, controls := editor_layout();
    return RectUI.get_rect(controls.x, 65 * editor_scale(), controls.w, 42 * editor_scale());
}

editor_save_button_rect :: (index: s64) -> RectUI.Rect {
    strip, controls := editor_layout();
    count := ifx editor_save_prompt.after == .NONE then 2 else 3;
    gap := 12 * editor_scale();
    width := min(132 * editor_scale(), (controls.w - gap * (count - 1)) / count);
    total := width * count + gap * (count - 1);
    return RectUI.get_rect(controls.x + (controls.w - total) / 2 + cast(float) index * (width + gap),
                           controls.y, width, controls.h);
}

editor_save_prompt_event :: (event: Editor_Event) {
    if event.kind == .KEY { editor_save_prompt_key(event); return; }
    if event.kind == .TEXT && !event.ctrl && !event.alt { editor_save_prompt_text(event.key); return; }
    if event.kind == .DOWN {
        editor_save_prompt.button_down = -1;
        count := ifx editor_save_prompt.after == .NONE then 2 else 3;
        for i: 0..count-1 {
            if editor_hit(editor_save_button_rect(i), event.x, event.y) editor_save_prompt.button_down = i;
        }
        if editor.custom && editor_hit(editor_save_name_rect(), event.x, event.y) {
            editor_save_prompt.name.cursor = editor_save_prompt.name.input.count;
            editor_save_prompt.select_all = false;
        }
        editor_focus_text();
    } else if event.kind == .UP {
        index := editor_save_prompt.button_down;
        editor_save_prompt.button_down = -1;
        if index >= 0 && editor_hit(editor_save_button_rect(index), event.x, event.y) editor_save_prompt_action(index);
    } else if event.kind == .CANCEL editor_save_prompt.button_down = -1;
}

editor_draw_save_prompt :: (width: float) {
    scale := editor_scale();
    font := editor_view.small_font;
    primary := console_color(Naysayer.text);
    muted := console_color(Naysayer.dimmed_variable);
    title := ifx editor_save_prompt.after != .NONE then "Unsaved changes" else
             ifx editor.custom then "Save custom input" else "Save solution";
    editor_draw_text(font, 20 * scale, 29 * scale, title, primary);
    target := ifx editor.custom then CUSTOM_INPUTS_FILE else SOLUTIONS_FILE;
    editor_draw_text(font, 20 * scale, 52 * scale,
                     tprint("% steps  /  %", editor.timeline.keys.count, target), muted);
    field := editor_save_name_rect();
    editor_draw_rect(field, ifx editor_save_prompt.select_all then console_color(Naysayer.line_fg) else console_color(Naysayer.selection));
    text := console_input(*editor_save_prompt.name);
    prefix := slice(text, 0, editor_save_prompt.name.cursor);
    caret_width := editor_text_width(font, prefix);
    baseline := field.y + (field.h + cast(float)(font.typical_ascender + font.typical_descender)) / 2;
    offset := max(0.0, caret_width - field.w + 24 * scale);
    Simp.set_scissor(cast(s32)(field.x + 8 * scale), cast(s32) field.y,
                     cast(s32)(field.x + field.w - 8 * scale), cast(s32)(field.y + field.h));
    if text.count editor_draw_text(font, field.x + 10 * scale - offset, baseline, text, primary);
    else editor_draw_text(font, field.x + 10 * scale, baseline, "Name (for example: my_test)", muted);
    if editor.custom && Win.GetForegroundWindow() == editor_window_handle() && (cast(s64)(seconds_since_init() * 2) % 2) == 0 {
        editor_draw_rect(RectUI.get_rect(field.x + 10 * scale + caret_width - offset,
                                         baseline - cast(float) font.typical_ascender - 2 * scale,
                                         2 * scale, cast(float)(font.typical_ascender - font.typical_descender) + 4 * scale),
                         console_color(Naysayer.white));
    }
    Simp.set_scissor(cast(s32)(20 * scale), cast(s32)(110 * scale), cast(s32)(width - 20 * scale), cast(s32)(160 * scale));
    editor_draw_text(font, 20 * scale, 133 * scale, editor_save_prompt.message,
                     ifx editor_save_prompt.error then console_color(Naysayer.warning) else muted);
    Simp.clear_scissor();
    count := ifx editor_save_prompt.after == .NONE then 2 else 3;
    mouse: Win.POINT;
    Win.GetCursorPos(*mouse);
    Win.ScreenToClient(editor_window_handle(), *mouse);
    for i: 0..count-1 {
        r := editor_save_button_rect(i);
        hover := editor_hit(r, mouse.x, mouse.y);
        editor_draw_rect(r, ifx hover then console_color(Naysayer.line_fg) else console_color(Naysayer.selection));
        label := ifx i == 0 then (ifx editor_save_prompt.overwrite then "Overwrite" else "Save")
                 else ifx i == 1 && count == 3 then "Discard" else "Cancel";
        text_width := editor_text_width(font, label);
        button_baseline := r.y + (r.h + cast(float)(font.typical_ascender + font.typical_descender)) / 2;
        editor_draw_text(font, r.x + (r.w - text_width) / 2, button_baseline, label,
                         ifx i == 0 then console_color(Naysayer.punctuation) else primary);
    }
    editor_draw_text(font, 20 * scale, 232 * scale,
                     "Enter: confirm save    Esc: cancel    Ctrl+V: paste name", muted);
}

#scope_file
#import "Basic";
#import "Math";
#import "String";
Simp :: #import "Simp";
RectUI :: #import "GetRect";
Win :: #import "Windows";

editor_draw_rect :: (r: RectUI.Rect, color: Vector4) {
    Simp.set_shader_for_color();
    Simp.immediate_quad(r.x, r.y, r.x + r.w, r.y + r.h, color);
}

editor_hit :: (r: RectUI.Rect, x: s32, y: s32) -> bool {
    return RectUI.is_inside(cast(float) x, cast(float) y, r);
}

editor_text_width :: (font: *Simp.Dynamic_Font, text: string) -> float {
    return cast(float) Simp.prepare_text(font, text);
}

editor_draw_text :: (font: *Simp.Dynamic_Font, x: float, y: float, text: string, color: Vector4) {
    Simp.draw_text(font, cast(s64) x, cast(s64) y, text, color);
}
