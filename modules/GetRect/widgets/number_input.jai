// 
// Number_Input has many similarities with slider, and we could think about combining them...
//
number_input :: (_r: Rect, text: string, value: *$T, min_value: T, max_value: T, theme: *Number_Input_Theme, identifier: s64 = 0, loc := #caller_location, parse_proc: (string) -> (T, bool) = null) -> bool {
    r := _r;
    hash  := get_hash(loc, identifier);
    state, created := find_or_create_state(Number_Input_State, hash);
    defer stop_using_state(state);

    font := theme.font;
    if !font  font = get_default_font_at_size(r.h *.65);

    if !state.inputting_text {
        draw_text_input_background(r, *theme.text_input_theme, *state.text_input_state);
    }
    
    status := get_status_flags(r);

    input_state: *Text_Input_State;
    if (status & .OVER) && (mouse_button_left_state & .START) && !state.inputting_text {
        state.inputting_text = true;
        active_widget_deactivate_all(state);  // Activating a new widget will automatically deactivate the old widget, *but* if that old widget was using the common Text_Input and so are we, we end up deactivating that input... after we activate it here. This ended up being pretty confusing because we don't know what the Text_Input's State is sometimes, so the easiest solution was just to deactivate before grabbing the input.  -jblow, 10 May 2022.
        
        input_state = find_or_create_state(Text_Input_State, hash, false);

        set_text(input_state, text);
        activate(input_state);
        start_selecting(input_state);  // When the input is already active and rendering, it will handle a left-press and do this itself. But we are bringing it from nothing, so it didn't get that event dispatch!
    }

    // :Nicer harmonize with slider input...
    // :Nicer remove inputting_text
    
    // @Copypasta from Slider. @Cleanup!!
    body_rect := r;
    focus := has_focus(body_rect);
    if state.inputting_text && !input_state {  // 'input_state' will already not be null if we just started typing.
        input_state = find_or_create_state(Text_Input_State, hash, false);
    }

    // :Nicer use inert_text to simplify this?
    
    if state.inputting_text {
        text_input_theme := theme.text_input_theme;
        if !text_input_theme.font  text_input_theme.font = font;
        
        action, new_string, input_state := text_input(body_rect, "", *text_input_theme, identifier, loc);
        if action & .ENTERED {
            state.inputting_text = false;

            text := input_state.text;

            // The @Copypasta below looks dumb, but the issue is, string_to_int just returns int,
            // which will generate an error if we make result of type T. Maybe we should call a
            // different routine instead that does the clamping-to-type part of set_and_maybe_clamp... !
            if parse_proc {
                result, success := parse_proc(text);
                if success {
                    set_and_maybe_clamp(result, value, min_value, max_value, theme.clamp_low, theme.clamp_high);
                    return true;
                }
            } else {
                #if (T == float64) || (T == float32) {
                    result, success := string_to_float(text);
                    if success {
                        set_and_maybe_clamp(result, value, min_value, max_value, theme.clamp_low, theme.clamp_high);
                        return true;
                    }
                } else {
                    result, success := string_to_int(text);
                    if success {
                        set_and_maybe_clamp(result, value, min_value, max_value, theme.clamp_low, theme.clamp_high);
                        return true;
                    }
                }
            }            
        } else if action & .ESCAPED {
            state.inputting_text = false;
        } else if !input_state.active {  // If the user presses scape on all. :Nicer?
            state.inputting_text = false;
        }
        
        return false;
    } else {
        label(r, text, *theme.label_theme);
    }
    
    return false;
}

Number_Input_Theme :: struct {
    using text_input_theme: Text_Input_Theme;
    text_input_theme.cursor_width_outside_text = .11;   // In ems. Matches the default inside_text value, so it looks the same. That way we don't spend a bunch of cursor space at the end of narrow text inputs, where it usually will be.
    text_input_theme.alignment_pad_ems = .2;
    text_input_theme.button_theme.surface_color = .{.08*.7, .208*.7, .236*.7, 1.0};

    // Some of this is a lot like what's on Slider, and we could
    // think about merging things or whatevs.

    // Some other things are a lot like what's on Button_Theme,
    // and in fact our state struct currently uses Button's
    // to do action durations etc.

    clamp_low  := true;
    clamp_high := true;
}

Number_Input_State :: struct #type_info_none {
    #as using widget: Active_Widget;
    widget.widget_type = #this;
    
    text_input_state: Text_Input_State; // So that we can do the same hover/etc stuff, without a text input existing for this yet.

    inputting_text := false;
}
