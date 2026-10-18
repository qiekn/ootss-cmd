#import "Clipboard"; // Maybe only import this if someone actually uses Text_Input?

// :Nicer usings on state.
// :Nicer note about if !state return;

my_draw_text :: (font: *Font, x: s64, y: s64, text: string, color: Vector4, effects: Font_Effects = 0) {
    assert(font != null);  // Any substitution with the default font must have been done by the caller.
    draw_procs.prepare_text(font, text, effects);
    draw_procs.draw_prepared_text(font, x, y, color, effects);
}

clamp_insert_point :: (state: *Text_Input_State) {
    if !state return;
    Clamp(*state.insert_point, 0, state.text.count);
}

Text_Input_Action :: enum_flags u8 {
    ACTIVATE   :: 0x1;
    DEACTIVATE :: 0x2;
}

Text_Result_Action :: enum_flags u32 {
    ENTERED       :: 0x1;
    ESCAPED       :: 0x2;
    TEXT_MODIFIED :: 0x4;
}

set_last_inert_text :: (state: *Text_Input_State, text: string) {
    // Normally you do not call this manually, but some higher-level widgets
    // like Slider draw the inert text themselves, so it doesn't get set normally.
    // This is a way for them to make up for that.

    if state.last_inert_text == text return;
    free(state.last_inert_text);
    state.last_inert_text = copy_string(text);
}

text_input :: (_r: Rect, inert_text: string, theme: *Text_Input_Theme, identifier: s64 = 0, loc := #caller_location, input_action : Text_Input_Action = 0, auto_complete: Auto_Complete = .{}) -> (result_action: Text_Result_Action, new_string: string, state: *Text_Input_State) {
    r := _r;
    hash  := get_hash(loc, identifier);

    state, created := find_or_create_state(Text_Input_State, hash);
    defer stop_using_state(state);
    if !state.text.data  state.text.data = state.input_buffer.data;

    set_last_inert_text(state, inert_text);

    // If we have buffered events, check those.
    if state.buffered_events {
        for state.buffered_events handle_event(state, it);
        state.buffered_events.count = 0;
    }

    if state.do_active_widget_deactivate_all {
        active_widget_deactivate_all(state);
        state.do_active_widget_deactivate_all = false;
    }

    if !state.active && input_action & .ACTIVATE { // :Nicer
        activate(state);
    } else if state.active && (state.disabled || (input_action & .DEACTIVATE)) {
        active_widget_remove(state);
    }

    font := theme.font;
    if !font  font = get_default_font_at_size(r.h *.65);

    status := get_status_flags(r);

    body_rect := r;
    state.rect = body_rect;

    result_action := state.pending_result_actions;
    state.pending_result_actions = 0;

    if state.active {
        text_input_theme := theme.*;
        if !text_input_theme.font  text_input_theme.font = font;

        if state.auto_complete.proc != auto_complete.proc || state.auto_complete.data != auto_complete.data {
            reset_auto_complete(state);
            state.auto_complete = auto_complete;
        }

        draw(state, body_rect, *text_input_theme, identifier, loc);

        if result_action & .ENTERED {
            if theme.deactivate_on_enter {
                active_widget_remove(state); // This will call the deactivate_proc, which sets active to false.
            }
            
            text := state.text;
            return result_action, text, state;
        }

        return result_action, "", state;
    } else {
        draw_text_input_background(r, theme, state);

        to_draw := ifx state.text else inert_text;
        label(r, to_draw, *theme.label_theme);
    }

    return result_action, "", state;
}


text_input_serial_events :: (widget: *Active_Widget, events: [] Event) {
    state := cast(*Text_Input_State) active_widget;
    array_add(*state.buffered_events, ..events);
}

handle_event :: (state: *Text_Input_State, event: Event) {
    if state.disabled return;

    if text_input_check_for_activation(state, event) {
        activate(state);
    }

    if event.type == .TEXT_INPUT {
        utf8_text := character_utf32_to_utf8(event.utf32);
        defer free(utf8_text);

        insert_text(state, utf8_text);
    } else if event.type == .KEYBOARD {
        state.last_keypress_time = current_time;

        key := event.key_code;
        using Key_Code;

        if event.key_pressed {
            if event.ctrl_pressed {
                if key == {
                    case xx #char "A"; select_all(state);
                    case INSERT;       copy_selection_to_clipboard(state, false);
                    case xx #char "C"; copy_selection_to_clipboard(state, false);
                    case xx #char "X"; copy_selection_to_clipboard(state, true);
                    case xx #char "V"; insert_clipboard_at_cursor(state);

                    case ARROW_LEFT;   move_cursor_left\_by_word(state, event.shift_pressed); return; // A 'return' so that we don't hit the ARROW_LEFT handling below. A little messy.
                    case ARROW_RIGHT;  move_cursor_right_by_word(state, event.shift_pressed); return; // Ibid.
                }
            }

            if event.shift_pressed {
                if key == {
                    case DELETE;       copy_selection_to_clipboard(state, true);
                    case INSERT;       insert_clipboard_at_cursor(state);
                }
            }

            if key == {
                case ARROW_LEFT;   move_cursor_left         (state, event.shift_pressed);
                case ARROW_RIGHT;  move_cursor_right        (state, event.shift_pressed);
                case HOME;         move_cursor_to_beginning (state, event.shift_pressed);
                case END;          move_cursor_to_end       (state, event.shift_pressed);

                case ARROW_DOWN;   navigate_history_forward (state);
                case ARROW_UP;     navigate_history_backward(state);

                case BACKSPACE;    backspace_from_cursor(state);
                case DELETE;       delete_from_cursor   (state);

                case ENTER;        press_enter(state, event.shift_pressed);
                case TAB;          press_tab  (state, event.shift_pressed);

                case ESCAPE;       press_escape(state);

                case MOUSE_BUTTON_LEFT;
                status := get_status_flags(state.rect);
                if status & .OVER {
                    // We don't have 'theme' available, so multiclick handling is deferred
                    // until later. (Is that a bad idea?)
                    state.current_click_time = current_time;  // Handle a multiclick next time we draw.

                    start_selecting(state);
                }
            }
        } else {  // !pressed
            if key == MOUSE_BUTTON_LEFT {
                state.cursor_tracking_mouse = false;
            }
        }
    }
}

text_input_check_for_activation :: (widget: *Active_Widget, event: Event) -> bool {
    // We could speed this up by having check_for_activation do an array of events,
    // and return the index of the activating event, but this doesn't handle
    // multiple reactivations per frame...

    state := cast(*Text_Input_State)widget;

    if event.type != .KEYBOARD              return false;
    if !event.key_pressed                   return false;
    if event.key_code != .MOUSE_BUTTON_LEFT return false;

    if state.disabled return false;

    status := get_status_flags(state.rect, widget_if_querying_outside_of_render_time=state);
    if !(status & .OVER) {
        return false;
    }

    return true;
}

refresh_input_from_history :: (using state: *Text_Input_State) {
    if !state return;

    Clamp(*command_history_index, 0, command_history.count);

    if command_history_index == command_history.count {
        set_input(state, state.last_saved_input);
    } else {
        set_input(state, command_history[command_history_index]);
    }
}

set_input :: (using state: *Text_Input_State, _s: string) {
    if !state return;

    s := _s;
    if s.count >= input_buffer.count  s.count = input_buffer.count;

    memcpy(input_buffer.data, s.data, s.count);
    text.count   = s.count;
    insert_point = s.count;
    pending_result_actions |= .TEXT_MODIFIED;

    update_auto_complete(state);

    deselect(*state.selection);
}

activate :: (using state: *Text_Input_State) {
    active = true;

    active_widget_add(state);

    base.status |= .PRESSED;    // Animate the button state.
    base.action_duration   = 0;
    base.action_duration_2 = 0;

    if !state.text  set_text(state, state.last_inert_text);
}

start_selecting :: (using state: *Text_Input_State) {
    if !state return;

    deselect(*selection);
    cursor_tracking_mouse = true;

    // @Robustness: We do not have access to the hash for the widget here,
    // because that is only available in draw (because it depends on the source
    // code location!) We could save the last hash or something ... but, absent
    // that, we cannot do any computations here about the deadzone. So we set
    // a boolean that says to do this stuff in the draw routine. (We would prefer
    // to set that boolean on the state struct if we could get it.)

    // In general, this shows the weird duality between the drawing part of this widget,
    // which is IMGUI-like, and the input and storage parts, which aren't.
    // Maybe we should go IMGUI with the whole thing, in which case the user would
    // pass us a state struct holding the memory, insert point etc each frame?
    // We'll see how this goes, structurally...

    did_initial_mouse_click_so_check_for_deadzone_change = true;
}

get_result :: (using state: *Text_Input_State) -> string {
    if !state return "";
    return text;
}

reset :: (using state: *Text_Input_State) {
    if !state return;

    deselect(*selection);

    pending_result_actions = 0;
    cursor_tracking_mouse  = false;
    last_displayed_text_x  = FLOAT32_INFINITY;
    text.count = 0;
}

draw_text_input_background :: (r: Rect, theme: *Text_Input_Theme, state: *Text_Input_State, active := false, changed := false) {
    // So that we can factor this out and use it from other things that don't want to instantiate
    // a text input yet, e.g. Number_Entry.

    // @Temporary @Hack? Update_production_value_button only uses button_theme
    // for press_duration... for now.

    // We could consider just using the Button_Theme... or making a duck copy macro!

    button := *theme.button_theme;

    //
    // We piggy-back on update_production_value_button for some factors, but,
    // we interpolate 'active' on our own.
    //
    if active {
        state.active_t = move_toward(state.active_t, 1, button.down_fade_in_speed);
    } else {
        state.active_t = move_toward(state.active_t, 0, button.down_fade_out_speed);
    }

    status := get_status_flags(r);
    update_production_value_button(r, changed, *state.base, status, button);

    active_factor := state.active_t;

    surface_color, frame_color, frame_thickness := get_colors_and_thickness_for_button(button, *state.base);
    if surface_color.w {
        draw_procs.set_shader_for_color(true);
        rounded_rectangle(r, button.rectangle_shape, surface_color, frame_color, frame_thickness_override=frame_thickness);
    }
}

draw :: (using state: *Text_Input_State, r: Rect, theme: *Text_Input_Theme = null, identifier: s64 = 0, loc := #caller_location) {
    if !state return;
    if !theme  theme = *default_overall_theme.text_input_theme;

    clamp_insert_point(state);

    x0 := cast(s32) r.x;
    y0 := cast(s32) r.y;
    x1 := cast(s32)(r.x + r.w);
    y1 := cast(s32)(r.y + r.h);


    font := theme.font;
    if !font  font = get_default_font_at_size(r.h*.65);

    xpad := em(theme.alignment_pad_ems, font);

    push_scissor(r);
    defer pop_scissor();

    status := get_status_flags(r);
    changed := cast(bool)(status & .PRESSED);

    draw_text_input_background(r, theme, state, state.active, changed);
    effect :: 0;

    active_factor := state.active_t;

    text_color       := lerp(theme.text_color, theme.text_color_over,    state.base.over_factor);
    text_color        = lerp(text_color,       theme.text_color_pressed, active_factor);

    text_width := draw_procs.prepare_text(font, state.text, effect);

    // If autocompletion available, take it into account:
    if match_array {
        auto_complete_text := match_array[match_selection];
        text_width = draw_procs.prepare_text(font, auto_complete_text, effect);
    }

    vert := theme.text_baseline_vertical_position;
    if vert == FLOAT32_INFINITY {
        vert = default_text_baseline(font, r.h);
    } else {
        vert *= r.h;
    }

    text_x := x0 + xpad;

    text_y := y0 + vert;

    if theme.alignment == {
      case .Center;
        text_x = (x1 + x0) * .5 - text_width * .5;
      case .Right;
        text_x = x1 - xpad - text_width;
      case .Left;
        text_x = x0 + xpad;
    }

    if !state.active state.camera_initted = false;
    if !state.camera_initted {
        state.camera_initted = true;
        state.camera_x = -(text_x - x0);
    }

    width_up_to_insert: s64;
    if state.active {
        if state.current_click_time >= 0 {
            // Consider double/triple clicks.
            if theme.multiclick_delay_max >= 0 {
                if state.current_click_time - state.last_click_time <= theme.multiclick_delay_max {
                    state.num_consecutive_clicks += 1;
                } else {
                    state.num_consecutive_clicks = 1;
                }

                state.last_click_time = state.current_click_time;

                // If we are clicking, but the mouse is moving, don't count that as double-clicks.

                state.click_position = .{mouse_x_float, mouse_y_float};  // @Robustness: What about resolution change? :ResolutionChange
                if state.num_consecutive_clicks == 1 {
                    state.last_click_position = state.click_position;
                } else {
                    break_distance := em(theme.distance_to_break_multiclick, font);
                    if distance(state.last_click_position, state.click_position) >= break_distance {
                        state.num_consecutive_clicks = 1;
                    }
                }
            }

            state.current_click_time = -1;

            point := get_insert_point_for_cursor(state, font, state.text, text_x, mouse_x, effect);
            update_multiclick_selection(state, point);
        }

        // Dragging code is next. Don't do dragging if we are multiclicking, which is why
        // we check num_consecutive_clicks < 2.
        if state.num_consecutive_clicks < 2 {

            // Extra check to make sure we aren't dragging after the user releases the mouse button
            if state.cursor_tracking_mouse && !mouse_button_left_state
                state.cursor_tracking_mouse = false;

            if state.cursor_tracking_mouse {
                // Update the insert point based on mouse drag;
                // do this before any other logic involving the insert point,
                // and before drawing the cursor!

                // If we are already tracking, just track, even if we move outside the window.
                state.last_keypress_time = current_time;

                // get_insert_point_for_cursor will re-generate all the glyphs; we could think
                // about re-using them at draw time, but, maybe text_x changes after this,
                // so, it is not guaranteed that we could. (But we could offset them by some
                // horizontal amount... hmm.)
                state.insert_point = get_insert_point_for_cursor(state, font, state.text, text_x, mouse_x, effect);

                if state.selection.active {
                    state.selection.end_character   = state.insert_point;
                } else {
                    // We were not already dragging the selection, so initialize it to the insert point.
                    state.selection.start_character = state.insert_point;
                    state.selection.end_character   = state.insert_point;
                    state.selection.active = true;
                }
            } else {
                selection_was_modified(*state.selection);  // Just sanity-check when mouse motion ends.
            }
        }

        // Find the x coordinate of the insert point.
        //
        // This is kind of expensive!!! And a waste if cursor_tracking_mouse because we just
        // computed this coordinate in get_insert_point_for_cursor, and we are doing it again here.
        // However, maybe we aren't tracking the mouse, maybe the font is changing every frame or
        // the Text_Input is moving. So we just compute the value. It's slow and icky. @Speed.

        s_up_to_insert := state.text;
        s_up_to_insert.count = state.insert_point;
        width_up_to_insert = draw_procs.prepare_text(font, s_up_to_insert, effect);

        margin := em(theme.text_insert_margin, font);
        Clamp(*margin, 0, 0.49 * r.w);

        alignment_pad := em(theme.alignment_pad_ems, font);
        Clamp(*alignment_pad, 0, 0.49 * r.w);

        insert_x := (x0 - state.camera_x) + width_up_to_insert;
        deadzone_x0 := x0 + margin;
        deadzone_x1 := x1 - margin;

        //
        // :DeadzoneMotion
        //
        // Suppose the user is moving the cursor around, inside text that is wider than
        // the rect used to draw this Text_Input, so that only a portion of the text can
        // be seen at one time. We want to have some margin around the cursor, so that you
        // can see past it on the right or left. That's what theme.text_insert_margin
        // is for.
        //
        // However, what happens if the user clicks to set the insert point such that it is
        // inside this margin? We don't want to move the text to put the insert point into
        // the margin, because that is disorienting to the user, and it results in other bad
        // feedback, like selecting a potentially large region of the text because it moved
        // under the cursor. So, when clicking inside these margins, we shrink the margins
        // so that the cursor is now in the deadzone. Assuming the margin is still nonzero,
        // you still get a bit of context on the side as you scroll; if the cursor scrolls
        // back toward the middle, so that the margin can grow, we grow it. When the margin
        // is restored to its original desired size, we are back to normal.
        //
        if state.did_initial_mouse_click_so_check_for_deadzone_change {
            state.did_initial_mouse_click_so_check_for_deadzone_change = false;

            // @Robustness: We are not checking the mouse_x of the actual click point!
            if (insert_x < deadzone_x0) || (insert_x > deadzone_x1) {
                state.shrunken_deadzone_margin = 0;  // Dummy value >= 0 to kick us into shrink mode. Updated below.
            }
        }

        if state.shrunken_deadzone_margin >= 0 {
            // If the shrunken margin got bigger, so that it approaches the preferred margin again,
            // let it get bigger. If it meets or exceeds the size of the preferred margin,
            // disable shrinking.
            if insert_x < deadzone_x0 {
                new_margin := insert_x - x0;
                state.shrunken_deadzone_margin = max(state.shrunken_deadzone_margin, new_margin);
            } else if insert_x > deadzone_x1 {
                new_margin := x1 - insert_x;
                state.shrunken_deadzone_margin = max(state.shrunken_deadzone_margin, new_margin);
            }

            if state.shrunken_deadzone_margin >= margin {
                // No need to shrink the margin any more. And turn off shrink mode.
                state.shrunken_deadzone_margin = -1;  // -1 means disable shrink mode.
            } else {
                // Recompute the margin and deadzone.
                deadzone_x0 = x0 + state.shrunken_deadzone_margin;
                deadzone_x1 = x1 - state.shrunken_deadzone_margin;
            }
        }

        dx := 0.0;
        if insert_x < deadzone_x0 {
            dx = deadzone_x0 - insert_x;
        } else if insert_x > deadzone_x1 {
            dx = deadzone_x1 - insert_x;
        }

        state.camera_x -= dx;

        left_limit  := -alignment_pad;
        right_limit := text_width + alignment_pad - (x1 - x0);
        if theme.alignment == .Left {
            if right_limit < left_limit  right_limit = left_limit;
        } else if theme.alignment == .Right {
            if left_limit > right_limit  left_limit  = right_limit;
        } else if theme.alignment == .Center {
            if right_limit < left_limit {
                mid := (left_limit + right_limit) * .5;
                left_limit = mid;
                right_limit = mid;
            }
        }

        Clamp(*state.camera_x, left_limit, right_limit);
        text_x = x0 - state.camera_x;
        state.last_displayed_text_x = text_x;
    }

    //
    // @Speed: We don't necessarily reuse prepared text here currently, because it's
    // just confusing what is going on with all the autocomplete stuff. But it's possible
    // we could raise the efficiency here.       -jblow, 1 June 2021.
    //
    if state.active {
        // Draw the selection if it is active.
        if nonempty(state.selection) {
            sx0, sx1 := get_selection_endpoints(font, text, effect, text_x, selection.start_character, selection.end_character);

            sy0 := cast(float) y0;
            sy1 := cast(float) y1;

            p0 := Vector2.{sx0, sy0};
            p1 := Vector2.{sx1, sy0};
            p2 := Vector2.{sx1, sy1};
            p3 := Vector2.{sx0, sy1};

            draw_procs.set_shader_for_color(true);
            draw_procs.immediate_quad(p0, p1, p2, p3, theme.selection_color);
            draw_procs.immediate_flush();
        }

        // Draw auto complete hints:
        if match_array {
            auto_complete_text  := match_array[match_selection];
            auto_complete_color := theme.text_color_autocomplete;
            if tab_pressed {
                center := 0.5;
                stride := 0.24;

                theta := 9 * (current_time - completion_change_time);

                // If we are in the first TAU/4, fake up our stride so that
                // we are brighter for longer.

                if theta < TAU * .25 {
                    stride *= 6;
                }

                w := cast(float)(cos(theta) * stride + center);
                Clamp(*w, 0, 1);

                auto_complete_color.w = w;
            }

            my_draw_text(font, xx text_x, xx text_y, auto_complete_text, auto_complete_color, effect);
        }
    }

    if longest_match >= 0 && longest_match < state.text.count {
        failed_color := theme.text_color_autocomplete_failed;

        my_draw_text(font, xx text_x, xx text_y, state.text, failed_color, effect);

        match_text := slice(state.text, 0, longest_match);
        my_draw_text(font, xx text_x, xx text_y, match_text, text_color, effect);
    } else {
        my_draw_text(font, xx text_x, xx text_y, state.text, text_color, effect);
    }

    // Don't draw cursor if not active.
    if !state.active return;

    cursor_color := get_cursor_color(state, theme, text_color);

    // Draw the cursor.
    // s_up_to_insert @Cutnpaste from above.
    {
        // We computed 'width_up_to_insert' above if active, which we are if we got here.
        cursor_x := text_x + width_up_to_insert;

        // Do not draw wide cursor over auto completion hint.
        max_text_count := state.text.count;
        if match_array max_text_count = match_array[match_selection].count;

        cw := max(1.0, em(theme.cursor_width_outside_text, font));
        if state.insert_point < max_text_count {
            cw = max(1.0, em(theme.cursor_width_inside_text, font));
            cursor_x -= cw * .5;
        }

        draw_procs.set_shader_for_color(true);
        {
            x0 := cursor_x;
            x1 := x0 + cw;
            y0, y1 := get_y_range(font, text_y);

            y0 = y1 - font.character_height;

            p0 := Vector2.{x0, y0};
            p1 := Vector2.{x1, y0};
            p2 := Vector2.{x1, y1};
            p3 := Vector2.{x0, y1};

            draw_procs.immediate_quad(p0, p1, p2, p3, cursor_color);
            draw_procs.immediate_flush();
        }
    }
}

#scope_file

update_multiclick_selection :: (using state: *Text_Input_State, point: int) {
    if !text.count return;

    if state.num_consecutive_clicks < 2 {
        // Do nothing.
    } else if state.num_consecutive_clicks == 2 {
        selection.start_character = point;
        selection.end_character   = point + 1;

        // @Speed: 'expand' is written to take a function that applies to each byte.
        // For very long texts, if we have speed concerns, we should not do it this way,
        // but for now it's fine.
        expand :: (should_expand: (u8) -> bool) #expand {
            if should_expand(text[selection.start_character]) while selection.start_character > 0 {
                if !should_expand(text[selection.start_character-1]) break;
                selection.start_character -= 1;
            }

            if should_expand(text[selection.end_character-1]) while selection.end_character < text.count {
                if !should_expand(text[selection.end_character]) break;
                selection.end_character += 1;
            }
        }

        is_separator :: (c: u8) -> bool { return is_print(c) && !is_space(c) && !is_alnum(c); }
        // Ensure selection is in bounds.
        if selection.start_character >= text.count selection.start_character = text.count-1;
        if selection.end_character   >  text.count selection.end_character   = text.count;

        // Depending on the start charcter, we expand alphanumerics, spaces or separators.
        if      is_space    (text[selection.start_character]) expand(is_space);
        else if is_separator(text[selection.start_character]) expand(is_separator);
        else                                                  expand(is_alnum);

        // @Polish
        // Some editors will select nearby text if it's a small range of spaces
        // (because maybe you just missed the text), or select the spaces if it's a big
        // range. We could think about that.

        // @Polish
        // In a right-to-left language, you'd put it on the left?

        selection.active = true;

        selection_was_modified(*selection);  // May set active back to false if the selection is empty.
        if selection.active state.insert_point = selection.end_character;  // Put the insertion cursor at the end of the selected region.

    } else {
        // Triple click, or more.
        select_all(state);
        if selection.active state.insert_point = 0;  // Put the insertion cursor at the beginning of the line.
    }
}

get_cursor_color :: (state: *Text_Input_State, theme: *Text_Input_Theme, non_white: Vector4) -> Vector4 {
    white := theme.cursor_color;

    t := cos((current_time - state.last_keypress_time) * 3);
    t *= t;

    color := lerp(non_white, white, cast(float32)t);
    return color;

    // return make_vector4(1, 1, 1, 1);
}

get_selection_indices :: (using state: *Text_Input_State) -> (start: int, end: int) {
    // Maybe we should just have a canonical version of
    // these stored on 'selection'.
    start := selection.start_character;
    Clamp(*start, 0, state.text.count);

    end   := selection.end_character;
    Clamp(*end, 0, state.text.count);

	if end < start {
	    swap(*start, *end);
	}

    return start, end;
}

get_selection :: (using state: *Text_Input_State) -> string /* Temporary Storage */ {
    if !selection.active return "";

    start, end := get_selection_indices(state);

    _result: string;
    _result.data = text.data + start;
    _result.count = end - start;
    result := copy_temporary_string(_result);

    return result;
}

replace_selection :: (state: *Text_Input_State, s: string) {
    if !state return;

    start, end := get_selection_indices(state);

    pre  := state.text;
    pre.count = start;

    post := state.text;
    advance(*post, end);

    // There is an extra copy here; we allocate via Temporary_Storage
    // then set_input copies it into the input_buffer. We could
    // just copy these straight into the input buffer.
    new_text := join(pre, s, post,, allocator=temp);
    set_input(state, new_text);

    if !s.count {
        state.insert_point = start;
        state.selection.active = false;
    } else {
        state.selection.start_character = start;
        state.selection.end_character   = start + s.count;
    }
}


nonempty :: (selection: Selection) -> bool {
    result := selection.active && (selection.start_character != selection.end_character);
    return result;
}

#scope_export

sanitize :: (s: string) -> string {
    pieces := break_into_lines(s, " ");

    return join(..pieces);
}

seek_left_one_utf8_character :: (s: string, _point: int) -> int {
    point := _point - 1;
    while point > 0 {
        c := s[point];
        if (192 & c) != 128  return point;
        point -= 1;
    }

    return 0;
}

// Word seeks courtesy of Farzher. Licensed under the MIT license.
// Note: These routines jump to the end of the current word going right (or the beginning going left),
// which is the behavior adopted by some programs. But the older Windows standard (and maybe on Linux too,
// since Linux just copies Windows about these things) is to jump to the beginning of the next word
// to the right, similarly to the left. [You can see this using Notepad]. And there are rules about
// punctuation that are weird. If we want more than one behavior, we could specify which the user wants
// via the Text_Input_Theme.       -jblow, 29 May 2022.

// Note that we are not doing any of the funny Unicode space characters. We just care about ASCII spaces
// for now.

// We could factor these two functions together with an indicator of which direction to go.
// Right now it's not quite worth it (??) but may become so if they get even a little bigger.
seek_left_one_word :: (s: string, point: int) -> int {
    point -= 1;
    if point < 0  return 0;

    stop_on_next_space := !is_space(s[point]);

    while point > 0 {
        c := s[point];
        if !stop_on_next_space && !is_space(c) stop_on_next_space = true;
        if  stop_on_next_space &&  is_space(c) return point+1;
        point -= 1;
    }

    return 0;
}

seek_right_one_word :: (s: string, point: int) -> int {
    if point >= s.count  return s.count;

    stop_on_next_space := !is_space(s[point]);

    while point < s.count {
        c := s[point];
        if !stop_on_next_space && !is_space(c)  stop_on_next_space = true;
        if  stop_on_next_space &&  is_space(c)  return point;
        point += 1;
    }

    return s.count;
}


get_y_range :: (font: *Font, text_y: float) -> (y0: float, y1: float) {
    assert(font != null);

    FONT_CURSOR_EXTRA_HEIGHT :: 0.1;  // @Hardcode @Cleanup
    y0 := text_y + font.typical_descender;
    y1 := y0 + font.typical_ascender + FONT_CURSOR_EXTRA_HEIGHT * font.character_height;

    y1 += 1;  // To include the top pixel, rather than limit just before the top pixel.

    padding := (y1 - y0) / 8;

    // We tend to need more extra padding on the top than bottom, since most letters don't have descenders.
    y0 -= padding;
    y1 += padding * 2;

    return y0, y1;
}


Selection :: struct {
    start_line       := -1;
    start_character  : int;

    end_line         := -1;
    end_character    : int;

    active := false;
}

deselect :: (using selection: *Selection) {
    active = false;
}

selection_was_modified :: (using selection: *Selection) {
    if active && (start_character == end_character) {
        // If a short-distance click or drag, or the selection becomes empty
        // for some other reason, deactivate it.
        active = false;
    }
}

/*
make_forward_selection :: (old: Selection) -> Selection {
    swap := false;
    if old.start_line > old.end_line {
        swap = true;
    } else if old.start_line == old.end_line {
        if old.start_character > old.end_character {
            swap = true;
        }
    }

    if !swap return old;

    result := old;
    swap(*result.start_line, *result.end_line);
    swap(*result.start_character, *result.end_character);

    return result;
}
*/


// Autocomplete stuff:

//
// To add auto-complete to a Text_Input, implement a function of type Auto_Complete.proc and
// pass it to text_input(). The 'longest_match_length' return value is used by the Text_Input to
// color the text to show how much of what you typed is correct; thus it must represent
// the longest substring match even if that match is not complete (and thus 'results' is empty).
//
Auto_Complete :: struct {
    proc: (str: string, data: *void) -> (results: [] string, longest_match_length: int);
    data: *void;
}

#scope_file

reset_auto_complete :: (using state: *Text_Input_State) {
    if !state return;

    array_reset(*match_array);    // Avoid leaking. @@ Ideally this should happen automatically in the assignment. Assignment could even avoid reallocating memory.

    if auto_complete.proc {
        if text {
            match_array, longest_match = state.auto_complete.proc(text, auto_complete.data);
        }

        get_match_length :: (match_array: []string, n: int) -> int {
            if match_array.count == 0 return 0;
            if match_array.count == 1 return match_array[0].count;

            n -= 1;
            while true {
                n += 1;

                if n == match_array[0].count break;
                c := match_array[0][n];

                // All the matches in match_array have the same from 0 to n-1;
                all_match := true;

                for cmd:match_array {
                    if n >= cmd.count || cmd[n] != c {
                        all_match = false;
                        break;  // @@ Does jai support labeled breaks?
                    }
                }

                if !all_match break;
            }

            return n;
        }
        match_length = get_match_length(match_array, text.count);
        match_selection = 0;

        // If our text is an exact match for array[0], then one of the completions
        // is our exact string ... but don't use that as the first completion, since
        // we want to give the user some visual information that other completions
        // exist. So just rotate our selection to the next one.
        if (match_array.count > 1) && (text == match_array[0]) 
            match_selection += 1;
    }
}

// Update matches while trying to preserve the current selection.
update_auto_complete :: (using state: *Text_Input_State) {
    if !state return;

    tab_pressed = false;

    if match_array {
        // Try to preserve previous selection.
        last_match := match_array[match_selection];

        reset_auto_complete(state);

        // Restore previous selection.
        for match_array {
            if it == last_match match_selection = it_index;
        }
    } else {
        // There was no selection, just autocomplete.
        reset_auto_complete(state);
    }
}

// Tab autocompletes up to match_length.
advance_auto_complete :: (using state: *Text_Input_State, reverse: bool) {
    if !state return;

    if match_array {
        new_text := slice(match_array[match_selection], 0, match_length);
        if text != new_text {
            set_input(state, new_text);
        } else {
            if reverse {
                match_selection -= 1;
                if match_selection < 0 then match_selection = match_array.count - 1;
            } else {
                match_selection += 1;
                if match_selection >= match_array.count then match_selection = 0;
            }
        }
    }
}

// Accept the currently selected match. Returns false if there's nothing to accept, or already accepted.
accept_auto_complete :: (using state: *Text_Input_State) -> bool {
    if !match_array return false;
    if match_array[match_selection] == text return false;

    set_input(state, match_array[match_selection]);
    return true;
}

#scope_export

break_into_lines :: (s: string, between_lines_string := "") -> [] string {
    pieces: [..] string;
    pieces.allocator = temporary_allocator;

    cursor := 0;
    for i: 0..s.count-1 {
        if (s[i] == 10) || (s[i] == 13) {
            to_add: string;
            to_add.data  = s.data + cursor;
            to_add.count = i - cursor;

            if to_add {
                array_add(*pieces, to_add);
                if between_lines_string array_add(*pieces, between_lines_string);
            }

            cursor = i + 1;
        }
    }

    to_add: string;
    to_add.data  = s.data + cursor;
    to_add.count = s.count - cursor;

    if to_add array_add(*pieces, to_add);

    return pieces;
}


get_selection_endpoints :: (font: *Font, text: string, effect: Font_Effects, text_x: float, start_character: int, end_character: int) -> (x0: float, x1: float) {
    sx0, sx1: float;
    s_up_to_start := text;
    s_up_to_start.count = start_character;

    s_up_to_end := text;
    s_up_to_end.count = end_character;

    start_width := draw_procs.prepare_text(font, s_up_to_start, effect);
    end_width   := draw_procs.prepare_text(font, s_up_to_end,   effect);

    sx0 = text_x + start_width;
    sx1 = text_x + end_width;

    return sx0, sx1;
}

get_insert_point_for_cursor :: (state: *Text_Input_State, font: *Font, text: string, current_frame_text_x: float, cursor_x: int, effect: Font_Effects, glyphs_prepped := false) -> int {
    //
    // We need to figure out where in the text the user clicked. We used to do this
    // after rendering the text, so we knew for sure where it was. But this is a little
    // more laggy with regard to where the cursor appears (one frame late!), and
    // it was not helpful with regard to the new deadzone code. :DeadzoneMotion.
    // Now we do this before drawing; we need to know where the text was last frame,
    // though @Robustness, we aren't quite recomputing that here if the user-level code
    // is drawing this text input at different coordinates than it was drawn last frame.
    // (Maybe we should save the positions of all glyphs!)
    //
    // The important thing to note is, if the widget is moving, the user clicked
    // a place that was correct *last* frame, which is why we are using last_text_x
    // rather than a fully updated text_x for this frame.

    //
    // Anyway, we need to recompute the positions of all glyphs based on last_text_x,
    // which is why we use it here. Frame-to-frame feedback is slightly scary, but
    // it makes sense in this case, because hey, this is what the user clicked on.
    //

    //
    // Possibly (probably?) it's not worth all this complication and feedback risk,
    // and we should just use the current_frame_text_x always.
    //
    x := state.last_displayed_text_x;
    if x == FLOAT32_INFINITY  x = current_frame_text_x;

    if !glyphs_prepped {
        draw_procs.prepare_text(font, text, effect);
    }

    best_byte_offset := -1;
    best_dist := FLOAT32_MAX;

    for glyph, index: font.temporary_glyphs {
        dist := abs(cursor_x - x);
        if dist < best_dist  {
            best_dist = xx dist;
            byte_offset := font.temporary_glyphs_byte_offsets[index];
            assert(byte_offset >= 0);
            best_byte_offset = byte_offset;
        }

        // Once dist goes past the minimum and starts increasing,
        // we could early-out, but we are not doing that yet.

        x += xx glyph.advance;
    }

    // Allow ourselves to click beyond the last character.
    dist := abs(cursor_x - x);
    if dist < best_dist  best_byte_offset = text.count;

    return best_byte_offset;
}

//
// We have broken out all the text editing routines into separately-callable
// stuff so that you can call them from your own code without having to go through
// the UI to do so:
//


clear_text :: (using state: *Text_Input_State) {
    text.data = input_buffer.data;
    text.count = 0;
    insert_point = 0;
}

set_text :: (state: *Text_Input_State, s: string, replace_pre_modification_text := true) {
    clear_text(state);
    append_text(state, s);

    if replace_pre_modification_text {
        free(state.pre_modification_text);
        state.pre_modification_text = copy_string(s);
    }
}

append_text :: (using state: *Text_Input_State, s: string) {
    bytes_available := input_buffer.count - text.count;
    to_copy := min(bytes_available, s.count);

    memcpy(input_buffer.data + text.count, s.data, to_copy);
    text.count += to_copy;
    insert_point += to_copy;  // @Hack: Assume insert_point is at the end. If we want this to be more robust, we could just insert at the point here as we do when pasting.

    update_auto_complete(state);
}


insert_text :: (using state: *Text_Input_State, s: string) -> bool {
    if !state {
        log_error("insert_text() was called on a Text_Input_State that was null, so this widget probably has not yet been drawn. Use the inert_text parameter to text_input() instead.\n");
        return false;
    }

    // Clear the selection (thus making more space) *before* asking whether we have enough space.
    if nonempty(selection) {
        replace_selection(state, "");
    }

    // If there's not enough room, none of the text is inserted. Usually called one character at a time by the text in put handler.
    if text.count + s.count > input_buffer.count return false;  // Not enough room!

    clamp_insert_point(state);

    if insert_point < text.count {
        // Copy right-to-left so that we don't wipe out our own text
        // for small inserts.
        i := text.count;
        while i > insert_point {
            input_buffer[i] = input_buffer[i-s.count];
            i -= 1;
        }
    }

    memcpy(input_buffer.data + insert_point, s.data, s.count);

    text.count   += s.count;
    insert_point += s.count;
    update_auto_complete(state);

    state.pending_result_actions |= .TEXT_MODIFIED;

    return true;
}

select_all :: (using state: *Text_Input_State) {
    if !state return;

    selection.active          = true;
    selection.start_character = 0;
    selection.end_character   = text.count;

    selection_was_modified(*selection);
}

copy_selection_to_clipboard :: (using state: *Text_Input_State, cut := false) {
    if nonempty(selection) {
        sel := get_selection(state);  // This does not make new memory.
        os_clipboard_set_text(sel);
        if cut  replace_selection(state, "");
    }
}

insert_clipboard_at_cursor :: (using state: *Text_Input_State) {
    if !state return;

    // @Cleanup: We should do it like Braid / Witness and
    // pass a 'v' and accompanying flags, and do whatever
    // we need to do to massage the Windows input to be
    // in this form.
    unsanitized_paste_text := os_clipboard_get_text();
    defer free(unsanitized_paste_text);

    paste_text := sanitize(unsanitized_paste_text);
    defer free(paste_text);

    if !paste_text return; // The clipboard might contain a file or actually be empty.

    // We don't want to wipe the selected characters until we
    // confirm that the paste text can fit into the input buffer.
    selection_count := 0;
    if nonempty(selection) {
        start, end := get_selection_indices(state);
        selection_count = end - start;
    }

    if text.count + paste_text.count - selection_count <= input_buffer.count {
        if selection_count > 0 {
            replace_selection(state, "");
        }

        pre := text;
        pre.count = insert_point;

        post: string;
        post.data  = text.data  + insert_point;
        post.count = text.count - insert_point;

        combined := join(pre, paste_text, post);
        defer free(combined);

        set_input(state, combined);

        insert_point = pre.count + paste_text.count;
    }
}

move_cursor_left :: (using state: *Text_Input_State, want_selection := false) {
    if !state return;

    reset_or_begin_selection(state, want_selection);

    prev_point := seek_left_one_utf8_character(state.text, state.insert_point);
    state.insert_point = prev_point;
    clamp_insert_point(state);

    update_selection_after_cursor_movement(state);
}

move_cursor_right :: (state: *Text_Input_State, want_selection := false) {
    if !state return;

    reset_or_begin_selection(state, want_selection);

    if state.insert_point < state.text.count {
        nbytes := 1 + trailingBytesForUTF8[state.text[state.insert_point]];
        state.insert_point += nbytes;
        clamp_insert_point(state);
    }

    update_selection_after_cursor_movement(state);
}

move_cursor_left_by_word :: (using state: *Text_Input_State, want_selection := false) {
    if !state return;

    reset_or_begin_selection(state, want_selection);
    insert_point = seek_left_one_word(text, insert_point);
    update_selection_after_cursor_movement(state);
}

move_cursor_right_by_word :: (using state: *Text_Input_State, want_selection := false) {
    if !state return;

    reset_or_begin_selection(state, want_selection);
    insert_point = seek_right_one_word(text, insert_point);
    update_selection_after_cursor_movement(state);
}

move_cursor_to_beginning :: (state: *Text_Input_State, want_selection := false) {
    if !state return;

    reset_or_begin_selection(state, want_selection);
    state.insert_point = 0;
    update_selection_after_cursor_movement(state);
}

move_cursor_to_end :: (state: *Text_Input_State, want_selection := false) {
    if !state return;

    reset_or_begin_selection(state, want_selection);
    state.insert_point = state.text.count;
    update_selection_after_cursor_movement(state);
}


navigate_history_backward :: (using state: *Text_Input_State) {
    if !state return;

    // @Incomplete: Handle autocomplete navigation?
    selection.active = false;

    if command_history_index == command_history.count {
        if last_saved_input  free(last_saved_input);
        last_saved_input = copy_string(text);
    }

    command_history_index -= 1;
    refresh_input_from_history(state);
}

navigate_history_forward :: (using state: *Text_Input_State) {
    if !state return;

    selection.active = false;

    if command_history_index < command_history.count {
        // Only do this if we're not at the end, because
        // we only save your input text when you leave
        // the last line.
        command_history_index += 1;
        refresh_input_from_history(state);
    }
}

backspace_from_cursor :: (using state: *Text_Input_State) {
    if !state return;

    if nonempty(selection) {
        replace_selection(state, "");
        pending_result_actions |= .TEXT_MODIFIED;
    } else if (insert_point <= text.count) && (insert_point >= 1) {
        prev_point := seek_left_one_utf8_character(text, insert_point);
        nbytes := insert_point - prev_point;
        for i: prev_point..text.count-1-nbytes {
            text[i] = text[i+nbytes];
        }

        insert_point -= nbytes;
        text.count   -= nbytes;
        update_auto_complete(state);
        pending_result_actions |= .TEXT_MODIFIED;
    }
}

delete_from_cursor :: (using state: *Text_Input_State) {
    if !state return;

    if nonempty(selection) {
        replace_selection(state, "");
        pending_result_actions |= .TEXT_MODIFIED;
    } else if insert_point < text.count {
        nbytes := 1 + trailingBytesForUTF8[text[insert_point]];
        for i: insert_point..text.count-nbytes-1 {
            text[i] = text[i+nbytes];
        }

        text.count -= nbytes;
        update_auto_complete(state);
        pending_result_actions |= .TEXT_MODIFIED;
    }
}

press_enter :: (using state: *Text_Input_State, shift_pressed := false) {
    if !state return;

    handled := false;
    if tab_pressed {
        handled = accept_auto_complete(state);
    }

    pending_result_actions |= .ENTERED;

    // shift_plus_enter_was_pressed = shift_pressed;


    // If we would duplicate the last entry in the command history, just skip it,
    // since we don't want to spam with identical commands. We could make this configurable.

    should_add := true;
    if text && command_history && (text == peek(command_history)) should_add = false;
    if !text  should_add = false;
    
    if should_add {
        copy := copy_string(text);
        array_add(*command_history, copy);  // Don't add blank lines.
    }

    command_history_index = command_history.count;  // Always jump to the end, for now. We could make this configurable.
    
    free(pre_modification_text);
    pre_modification_text = copy_string(text);
}

press_tab :: (using state: *Text_Input_State, shift_pressed := false) {
    completion_change_time = current_time;

    if !tab_pressed {
        tab_pressed = true;
    } else {
        advance_auto_complete(state, reverse=shift_pressed);
        tab_pressed = true;  // This must happen after advance_auto_complete since that resets it indirectly.
    }
}

press_escape :: (using state: *Text_Input_State) {
    set_text(state, state.pre_modification_text, replace_pre_modification_text=false);
    active_widget_remove(state);
    state.pending_result_actions |= .ESCAPED;
}

text_input_deactivate :: (widget: *Active_Widget) { // This is a non-user-level routine, so it is different from 'deactivate', even though they both do the same almost-nothing right now.
    state := cast(*Text_Input_State) widget;

    // if disable_deactivate_text_input_hook return;

    state.active                 = false;
    state.cursor_tracking_mouse  = false;
    state.pending_result_actions = 0;
}

#scope_file

// disable_deactivate_text_input_hook := false;

reset_or_begin_selection :: (using state: *Text_Input_State, do_begin: bool) {
    if !state return;

    if do_begin {
        if !selection.active {
            selection.active          = true;
            selection.start_character = state.insert_point;
            selection.end_character   = state.insert_point;
        }
    } else {
        selection.active = false;
    }
}

update_selection_after_cursor_movement :: (using state: *Text_Input_State) {
    if !state return;

    if selection.active {
        selection.end_character = state.insert_point;
    }

    selection_was_modified(*selection); // If dragging, we only want to reset for empty selection when dragging is done.
}

#scope_export

Text_Input_Theme :: struct {
    // @Incomplete: label_theme.effects not yet used when drawing.

    // A Button_Theme is used for general background and frame coloring.
    // The "down" state of the theme is used when the Text_Input is active.
    using button_theme: Button_Theme;
    alignment = .Left;
    button_theme.surface_color        = Vector4.{.07, .07, .20, 1.0};
    button_theme.surface_color_over   = Vector4.{.12, .12, .99, 1.0};
    button_theme.surface_color_down   = Vector4.{.66, .10, .40, 1.0};
    button_theme.surface_color_flash  = Vector4.{.60, .77, .62, 1.0};

    button_theme.frame_color          = Vector4.{.10, .25, .40, 1.0};
    button_theme.frame_color_over     = Vector4.{.15, .45, .75, 1.0};
    button_theme.frame_color_down     = Vector4.{.45, .75, .95, 1.0};
    button_theme.frame_color_flash    = Vector4.{.85, .85, .99, 1.0};



    text_color               = Vector4.{.30, .65, .65, 1.0};  // Inherited from button_theme.label_theme.

    text_color_over          = Vector4.{.99, .70, .70, 1.0};
    text_color_pressed       = Vector4.{.55, .99, .99, 1.0};

    text_color_autocomplete        := Vector4.{.30, .99, .30, 0.9};
    text_color_autocomplete_failed := Vector4.{.99, .55, .55, 0.9};

    selection_color         := Vector4.{.15, .69, .85, 1.0};

    cursor_color            := Vector4.{1.0, 1.0, 1.0, 1.0};

    text_insert_margin         := 4.7;  // How much you want to be able to see when typing near the edge of a text in put, in ems. The resulting pixel value is clamped at 49% of the width of the rect at render time (otherwise it would be ill-defined where you want the insert point to be, unless we had two different margins).

    cursor_width_inside_text   := 0.11;  // In ems.
    cursor_width_outside_text  := .55;   // In ems.

    maintain_text_after_escape := false;
    deactivate_on_enter        := true;

    multiclick_delay_max         := 0.5;   // In seconds. Set this to a negative number to disable multiclicking.
    distance_to_break_multiclick := 0.8;   // In ems. If you move the mouse more than this between clicks, it doesn't count as a multiclick.
}

Text_Input_State :: struct #type_info_none {
    #as using widget: Active_Widget;

    widget.deactivate_proc           = text_input_deactivate;
    widget.serial_events_proc        = text_input_serial_events;
    widget.check_for_activation_proc = text_input_check_for_activation;

    base: Button_State;  // Not all of these members are used.

    rect: Rect;  // We use this on the next frame when dispatching input, in a way that may be 1-frame-delayed. @Cleanup.

    camera_initted  := false;
    camera_x        := 0.0;
    active_t        := 0.0;

    active         := false;  // If false, we draw as a label. If true, we actually run the text input code.
    disabled       := false;  // The user may set this at any time to disable the input.

    shrunken_deadzone_margin := -1.0;     // -1 means disabled.
    last_displayed_text_x    := FLOAT32_INFINITY;  // Infinity means not yet initted (-1 might be a valid draw position!)
    last_keypress_time: float64;

    last_inert_text := "";

    // For tracking double/triple clicks:
    last_click_time       : float64;
    current_click_time    : float64 = -1;
    num_consecutive_clicks : s32;

    last_click_position: Vector2;
    click_position:      Vector2;

    // Text and dragging stuff:
    insert_point := 0;
    cursor_tracking_mouse := false;

    did_initial_mouse_click_so_check_for_deadzone_change := false;

    pending_result_actions: Text_Result_Action;

    last_saved_input: string;
    pre_modification_text: string;  // What to revert back to when you press Escape. Should this be combined with last_saved_input?

    command_history: [..] string;
    command_history_index := 0;


    selection: Selection;
    buffered_events: [..] Event;

    text: string;

    MAX_BUFFER_SIZE :: 8000;
    input_buffer: [MAX_BUFFER_SIZE] u8;

    // Auto-completion stuff below:

    auto_complete : Auto_Complete;

    tab_pressed := false;
    completion_change_time: float64;

    match_array     : [] string;
    match_length    : int;
    match_selection : int;
    longest_match   : int = -1;

    // Revisit these:
    do_active_widget_deactivate_all := false;  // @Hack while we figure out how to structure this stuff.
}
