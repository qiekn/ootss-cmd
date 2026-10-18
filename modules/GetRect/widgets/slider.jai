slider :: (_r: Rect, value: *$T, min_value: T, max_value: T, spinbox_step: T, theme: *Slider_Theme, prefix := "", suffix := "", identifier: s64 = 0, loc := #caller_location) -> changed: bool, entered: bool {
    // The entered return value is for when the user does some kind of definitive "I am done editing" action, like pressing enter on the
    // text input or releasing the slider.

    #assert (T == float) || (T == float64) || is_integer_type(T);

    hash  := get_hash(loc, identifier);
    state, created := find_or_create_state(Slider_State, hash);
    defer stop_using_state(state);

    if created set_initial_value(state, value.*);
    state.value_type = type_info(T);

    text: string;
    if !state.inputting_text {
        #if (T == float64) || (T == float32) {
            if theme.format_text_float  text = theme.format_text_float(prefix, suffix, value.*, theme, state, .DISPLAY);
        } else {
            if theme.format_text_int    text = theme.format_text_int(prefix, suffix, xx,no_check value.*, theme, state, .DISPLAY);
        }
    }

    font := theme.foreground.font;
    if !font  font = get_default_font_at_size(_r.h *.65);

    text_width, text_height := text_size(font, text);

    body_rect := _r;  // We will probably cut the spinbox off here later...!
    status := get_status_flags(body_rect);

    text_input_state: *Text_Input_State;

    if theme.text_editable {
        // Let's do it when the user clicks anywhere in the slider, not just the text.

        focus := has_focus(body_rect);
        down  := focus && (mouse_button_left_state & .DOWN);

        input_state := find_or_create_state(Text_Input_State, hash, false);
        assert(input_state != null);

        if (status & .OVER) && (mouse_button_right_state & .START) && !state.inputting_text { // @Incomplete: || ui.mouse_button_left_double_click) {
            // Do something here about focus. For now we require the user to handle it.ui.force_focus = true;
            // focus = true;
            state.inputting_text = true;

            // @Copypasta from the other text formatting site, but with full_precision_for_editing true:
            text: string;
            #if (T == float64) || (T == float32) {
                if theme.format_text_float  text = theme.format_text_float(prefix, suffix, value.*, theme, state, .EDITING);
            } else {
                if theme.format_text_int    text = theme.format_text_int(prefix, suffix, value.*, theme, state, .EDITING);
            }

            set_text(input_state, text);
            set_last_inert_text(input_state, text);
            activate(input_state);
        }

        // :Nicer remove inputting_text?
        if state.inputting_text {
            if (!input_state.active) || !focus  state.inputting_text = false;
        }

        if state.inputting_text {
            text_input_theme := theme.text_input_theme;
            if !text_input_theme.font  text_input_theme.font = font;

            actions := text_input(body_rect, "", *text_input_theme, identifier, loc);  // :Nicer use inert_text to simplify this?

            if actions & .ENTERED {
                state.inputting_text = false;
                text := input_state.text;

                #if (T == float64) || (T == float32) {
                    success, result := slider_parse_text_float_default(text, theme, state);
                } else {
                    success, result := slider_parse_text_int_default(text, theme, state);
                }

                if success {
                    set_and_maybe_clamp(result, value, min_value, max_value, theme.clamp_text_input_low, theme.clamp_text_input_high);
                    return changed=true, entered=true;
                }
            } else if actions & .ESCAPED {
                state.inputting_text = false;
            } else if !input_state.active {  // If the user presses scape on all. :Nicer?
                state.inputting_text = false;
            }

            return changed=false, entered=false;
        }
    }

    changed, entered: bool;

    if theme.use_spinboxes {
        spinbox_rect: Rect = ---;
        spinbox_rect, body_rect = cut_right(body_rect, 2 * theme.spinbox_button_width * body_rect.h);

        // Since we changed body_rect, re-get the status.
        status = get_status_flags(body_rect);

        button_theme := theme.spinbox_theme;

        up_rect, down_rect := cut_right(spinbox_rect, spinbox_rect.w * .5);

        result := value.*;
        button_theme.rectangle_shape.rounding_flags = Rectangle_Shape.Rounding_Flags.NORTHWEST | .SOUTHWEST;
        pressed_down, state_down := button(down_rect, "", *button_theme, xx,no_check hash);  // Use current location.
        button_theme.rectangle_shape.rounding_flags = Rectangle_Shape.Rounding_Flags.NORTHEAST | .SOUTHEAST;
        pressed_up, state_up     := button(up_rect,   "", *button_theme, xx,no_check hash);  // Use current location.

        triangle_margin := up_rect.w * 0.1;

        draw_procs.set_shader_for_color(true);

        {
            p0, p1, p2, p3 := get_quad(down_rect);
            p4 := to_vec3(lerp(p0, p3, .5));
            p4.x += triangle_margin;
            p5 := to_vec3(p1);
            p5.x -= triangle_margin;
            p5.y += triangle_margin;
            p6 := to_vec3(p2);
            p6.x -= triangle_margin;
            p6.y -= triangle_margin;

            draw_arrow(state_down, p4, p5, p6, *button_theme);
        }
        {
            p0, p1, p2, p3 := get_quad(up_rect);
            p4 := to_vec3(lerp(p1, p2, .5));
            p4.x -= triangle_margin;
            p5 := to_vec3(p0);
            p5.x += triangle_margin;
            p5.y += triangle_margin;
            p6 := to_vec3(p3);
            p6.x += triangle_margin;
            p6.y -= triangle_margin;

            draw_arrow(state_up, p4, p5, p6, *button_theme);
        }


        if pressed_up    result += spinbox_step;
        if pressed_down  result -= spinbox_step;

        if pressed_up || pressed_down {
            entered = true;
            set_and_maybe_clamp(result, value, min_value, max_value, theme.clamp_text_input_low, theme.clamp_text_input_high);
            status |= .DOWN;
        }
    }

    started_sliding := false;
    if status & .PRESSED /* @Incomplete && !ui.slider_input_mode*/ {
        // Started dragging. We can do some visual thing here...

        // Anything else could have changed this value, so, when we start sliding, set the initial value
        // so that we know how clamping should behave.
        set_initial_value(state, value.*);
        started_sliding = true;
        status |= .DOWN;
    }

    dt := current_dt;

    sliding_t_target := 0.0;
    value_denom := max_value - min_value;
    if !value_denom  value_denom = 1;
    t := (cast(float)(value.* - min_value)) / value_denom;

    Clamp(*t, 0, 1);
    
    if state.sliding {
        if !(mouse_button_left_state & .DOWN) {
            state.sliding = false;
            entered = true;
            changed = true;
            active_widget_remove(state);
        }
    } else {
        if status & .PRESSED {
            state.sliding = true;
            state.sliding_is_relative = theme.sliding_is_relative;  // Can become relative later by pressing shift.
            state.accumulated_delta_for_int_slider = 0;
            active_widget_add(state, true);
        }
    }

    surface_margin := body_rect.h * min(theme.surface_margin, .49);
    surface_margin = floor(surface_margin + .5);

    state.surface_margin_this_frame_in_pixels = surface_margin;

    slowing_t_target := 0.0;
    if state.sliding {
        status |= .DOWN;
        sliding_t_target = 1;

        relative_slide_factor := theme.relative_slide_factor;

        shift_state := ui_get_button_state(.SHIFT);
        if !theme.sliding_becomes_relative_by_pressing_shift  shift_state = 0;  // Just disable shift.

        if shift_state & .DOWN {
            // @Responsiveness: slowing_t will be 0 on the first slowing frame, which is generally bad for feeling reactive.
            relative_slide_factor  = theme.relative_slide_factor_modified;
            state.sliding_is_relative = true;

            slowing_t_target = 1;
        }

        denom := body_rect.w - 2*surface_margin;
        if !denom denom = 1;

        if state.sliding_is_relative {
            // Relative slider motion.
            //
            // The deal with allowing you to stay outside if you start outside is, hey, if you
            // typed a manual value into the thing that is outside the range because you need it to be,
            // well, it is a bummer if the slider kills that value as soon as you drag it a little.
            // So we give you the option to continue unclamped.
            //

            initial := get_initial_value(state, T);
            started_inside := (initial >= min_value) && (initial <= max_value);

            delta := mouse_delta_x_float * relative_slide_factor;
            #if (T == float64) || (T == float32) {
                t += delta / denom;

                if started_inside || theme.do_clamp_if_we_are_relative_dragging_but_started_outside_the_clamp_range {
                    Clamp(*t, 0, 1);
                }

                value.* = lerp(min_value, max_value, t);
            } else {
                // For integer types:
                // Accumulate delta until we get enough for an integer value, then subtract it off.
                quantum := (1.0 / value_denom) * denom;
                state.accumulated_delta_for_int_slider += delta;

                if state.accumulated_delta_for_int_slider <= -quantum {
                    state.accumulated_delta_for_int_slider += quantum;
                    value.* -= 1;
                } else if state.accumulated_delta_for_int_slider >= quantum {
                    state.accumulated_delta_for_int_slider -= quantum;
                    value.* += 1;
                }

                if started_inside || theme.do_clamp_if_we_are_relative_dragging_but_started_outside_the_clamp_range {
                    Clamp(value, min_value, max_value);
                }
            }
        } else {
            // Absolute motion.

            t = (mouse_x_float - body_rect.x - 1) / denom;
            t = saturate(t);

            #if (T == float64) || (T == float32) {
                value.* = lerp(min_value, max_value, t);
            } else {
                // Integer types.
                // If you give us min_value and max_value that are out of range, we will just truncate.
                value.* = cast(T)(0.5 + lerp(cast(float)min_value, cast(float)max_value, t));
                value_denom := max_value - min_value;
                if !value_denom  value_denom = 1;
                t = cast(float)(value.* - min_value) / value_denom;
            }
        }
    }

    // We already placed the rect ... we don't want to widen the placement,
    // as that would move other widgets. But, we want to enlarge the whole bar
    // in-place.
    if state.slowing_t {
        dy := em(.25, font) * state.slowing_t;
        body_rect.y -= dy;
        body_rect.h += 2*dy;
    }

    state.sliding_t = move_toward(state.sliding_t, sliding_t_target, dt * 5);  // @Theme

    if slowing_t_target {
        state.slowing_t = move_toward(state.slowing_t, slowing_t_target, dt * 4.5);  // @Theme
    } else {
        state.slowing_t = move_toward(state.slowing_t, slowing_t_target, dt * 15);  // @Theme
    }

    if state.sliding  status |= .OVER;

    state.changed_this_frame = changed;
    update_production_value_button(body_rect, changed, *state.background, status,    *theme.background);

    sliding_t := state.sliding_t;

    state.current_slide_setting = t;

    if theme.draw_background  theme.draw_background(body_rect, theme, state);

    //
    // Compute the surface rect.
    //

    qrect := body_rect;
    qrect.y += surface_margin;
    qrect.h -= 2*surface_margin;
    if theme.surface_style == {
      case .EXTEND_FROM_LEFT;
        qrect.x += surface_margin;
        qrect.w = (body_rect.w - 2*surface_margin) * cast(float) t;

        if qrect.w < 1  qrect.w = 1;  // Leave a tiny glimmer of a bar there.
      case .NUB;
        thickness := get_float_parameter(body_rect, theme.nub_thickness_type, theme.nub_thickness, global_slider_nub_thickness_in_pixels);
        mid_x_relative := (body_rect.w - 2*surface_margin - thickness) * cast(float) t;
        mid_x := body_rect.x + thickness * .5 + surface_margin + mid_x_relative;
        qrect.x = mid_x - thickness * .5;
        qrect.w = thickness;
    }

    //
    // Invoke the foreground draw routine.
    //
    if theme.draw_foreground
        theme.draw_foreground(body_rect, qrect, theme, state);

    draw_procs.immediate_flush();
    label_from_prepared_text(body_rect, font, *theme.foreground.label_theme);

    return changed=xx(status & .DOWN), entered=entered;
}

set_initial_value :: (state: *Slider_State, value: $T) {
    #assert(T == float64) || (T == float32) || is_integer_type(T);  // @Incomplete: We will want to support all int types.
    #if T == float64  state.initial_value_float64 = value;
    #if T == float32  state.initial_value_float32 = value;
    else { (cast(*T) *state.initial_value_int).* = value; } // Integer type.
}

get_initial_value :: (state: *Slider_State, $T: Type) -> T {
    #assert(T == float64) || (T == float32) || is_integer_type(T);  // @Incomplete: We will want to support all int types.
    #if T == float64  return state.initial_value_float64;
    else #if T == float32  return state.initial_value_float32;
    else return (cast(*T) *state.initial_value_int).*; // Integer type.

    assert(false);
    return 0;
}


set_and_maybe_clamp :: (new_value: $ValueType, pointer: *$T, min_value: T, max_value: T, clamp_low: bool, clamp_high: bool) {
    is_int :: #run is_integer_type(T);
    #if is_int {
        // Clamping the input value to T's range, if necessary.
        // Somewhat redundant with theme.clamp*, except, those options might be disabled!

        t_value := clamp_to_another_integer_type(new_value, T);
    } else {
        t_value := cast(T) new_value;  // float64 to float32, maybe.
    }

    if clamp_low   t_value = max(min_value, t_value);
    if clamp_high  t_value = min(max_value, t_value);

    pointer.* = t_value;
}


to_vec3 :: (v2: Vector2) -> Vector3 {
    result: Vector3;
    result.xy = v2;

    return result;
}

draw_arrow :: (state: *Button_State, p4: Vector3, p5: Vector3, p6: Vector3, theme: *Button_Theme) {
    ARROW_INTERPOLATION_AMOUNT :: .14;
    s := state.action_duration * 2;
    Clamp(*s, 0, 1);
    t := -4*s*s + 4*s;

    // f(x) = ax**2 + b*x
    // f(0) = 0
    // f(1) = 0  ; a = -b
    // f(.5) = 1 ; a * .25 + b*.5 = 1  a*.25 - a*.5 = 1 ; -.25a = 1; a = -4; b = +4

    // f(x) = -4x**2 + 4x
    new_p5 := lerp(p5, p6, t * ARROW_INTERPOLATION_AMOUNT);
    new_p6 := lerp(p6, p5, t * ARROW_INTERPOLATION_AMOUNT);

    color := lerp(theme.text_color, theme.text_color_over, state.over_effect_t);
    color = lerp(color, theme.text_color_pressed, t);

    ca := color;
    cb := color;  // Could put a gradient on the triangle if we want...!
    draw_procs.immediate_triangle(p4, new_p5, new_p6, ca, cb, cb);
}

//
// Default slider draw procs:
//

slider_draw_background_default :: (r: Rect, theme: *Slider_Theme, state: *Slider_State) {
    draw_procs.set_shader_for_color(true);
    bg_color, bg_frame_color, bg_frame_thickness := get_colors_and_thickness_for_button(*theme.background, *state.background);
    if bg_color.w || bg_frame_color.w {
        rounded_rectangle(r, theme.foreground.rectangle_shape, bg_color, bg_frame_color, bg_frame_thickness);
    }
}

slider_draw_foreground_default :: (r_background: Rect, r_foreground: Rect, theme: *Slider_Theme, state: *Slider_State) {
    //
    // Update:
    //

    r := r_foreground;
    t := state.current_slide_setting;

    // Check whether the cursor is over the interior nub,
    // and so forth.
    status := get_status_flags(r);
    if state.sliding  status |= .OVER;

    changed := state.changed_this_frame;
    update_production_value_button(r, changed, *state.foreground, status, *theme.foreground);

    //
    // Draw:
    //

    draw_procs.set_shader_for_color(true);
    fg_color, fg_frame_color, fg_frame_thickness := get_colors_and_thickness_for_button(*theme.foreground, *state.foreground);

    if fg_color.w || fg_frame_color.w {
        rounded_rectangle(r, theme.background.rectangle_shape, fg_color, fg_frame_color, fg_frame_thickness);
    }
}

Slider_Format_Text_Mode :: enum u8 {
    DISPLAY :: 0;
    EDITING :: 1;
}

slider_format_text_float_default :: (prefix: string, suffix: string, value: float64, theme: *Slider_Theme, state: *Slider_State, mode: Slider_Format_Text_Mode) -> string {
    if mode == .EDITING return tprint("%", value);

    text := tprint("%1%2%3", prefix, formatFloat(value, trailing_width=theme.decimals, zero_removal=.NO), suffix);
    return text;
}

slider_format_text_int_default :: (prefix: string, suffix: string, value: s64, theme: *Slider_Theme, state: *Slider_State, mode: Slider_Format_Text_Mode) -> string {
    if mode == .EDITING return tprint("%", value);

    text := tprint("%1%2%3", prefix, value, suffix);
    return text;
}

slider_parse_text_float_default :: (text: string, theme: *Slider_Theme, state: *Slider_State) -> (success: bool, value: float64) {
    result, success := string_to_float(text);
    return success, result;
}

slider_parse_text_int_default :: (text: string, theme: *Slider_Theme, state: *Slider_State) -> (success: bool, value: s64) {
    result, success := string_to_int(text);
    return success, result;
}


Slider_Theme :: struct {
    // The 'down' state of the button themes is used when sliding.
    foreground: Button_Theme;
    foreground.surface_color         = .{0.0, 0.50, 0.35, 1.0};
    foreground.surface_color_over    = .{0.0, 0.60, 0.40, 1.0};
    foreground.surface_color_flash   = .{.03, 0.80, 0.30, 1.0};
    foreground.surface_color_down    = .{.30, 0.60, 0.40, 1.0};

    foreground.frame_color           = .{0.2, 0.70, 0.55, 1.0};
    foreground.frame_color_over      = .{0.2, 0.80, 0.60, 1.0};
    foreground.frame_color_flash     = .{.23, 0.95, 0.50, 1.0};
    foreground.frame_color_down      = .{.50, 0.80, 0.60, 1.0};

    foreground.alignment         = .Center;  // Alignment for the text.
    foreground.alignment_pad_ems = .5;

    // If sliding a float, how many digits of precision to display after the decimal.
    // This is used by the default string format routine only. If you substitute
    // your own, this is ignored.
    decimals: s32 = 2;

    background: Button_Theme;
    background.surface_color          = .{0.0, 0.1, 0.00, 1.0};
    background.surface_color_over     = .{0.0, 0.2, 0.00, 1.0};
    background.surface_color_flash    = .{0.0, 0.2, 0.10, 1.0};
    background.surface_color_down     = .{0.0, 0.2, 0.15, 1.0};

    background.frame_color            = .{0.2, 0.3, 0.20, 1.0};
    background.frame_color_over       = .{0.2, 0.4, 0.20, 1.0};
    background.frame_color_flash      = .{0.2, 0.4, 0.30, 1.0};
    background.frame_color_down       = .{0.2, 0.4, 0.35, 1.0};

    surface_margin   := .15;      // As a fraction of the rect height.

    text_editable    := true;     // Right-click or left-double-click to edit, if this is set.  @Incomplete: double-click not yet handled.
    clamp_text_input_low  := true;
    clamp_text_input_high := true;

    sliding_is_relative   := false;  // If false, the slider goes to the mouse pointer's position on the screen. If true, you change it via mouse motion.
    sliding_becomes_relative_by_pressing_shift := true;  // Has no meaning if sliding_is_relative == true. But if we start in non-relative mode, we can become relative by pressing shift. This also changes the slide factor from default to modified.

    relative_slide_factor          := 0.7;    // The number of pixels by which the slider value will change, relative to the number of pixels of mouse motion.
    relative_slide_factor_modified := 0.2;    // Slide factor when the user is holding the shift key.

    do_clamp_if_we_are_relative_dragging_but_started_outside_the_clamp_range := false;  // By default you can type a value beyond the official min/max, and still be able to drag out in that range. Set to true if you want to clamp on any drag action.  See also clamp_text_input_*.

    text_input_theme: Text_Input_Theme;  // If you decide to edit the slider. Note, this has a separate alignment_pad_ems, etc, so you may wish to keep these in sync with the slider's sliding-mode display, or, you may not.

    use_spinboxes        := true;
    spinbox_button_width := 1.0;      // As a fraction of the slider rect's height. 1.0 means each spinbox button will be square, and 2*height will be cut from the main rect to make space for the spinbox.

    surface_style: enum u8 {
        // This controls what kind of thing in the foreground actively represents the
        // current slider value. This just computes the rect; you can change what that
        // rect looks like via the draw functions.
        EXTEND_FROM_LEFT :: 0;   // Bar starts at the left and goes to the right.
        NUB              :: 1;   // A nub like in the Scrollbar. If this is set, nub_thickness_type and nub_thickness are used.
    }

    // nub_thickness* are only used if surface_style == .NUB ...
    nub_thickness_type := Size_Computation.RELATIVE_TO_HEIGHT;
    nub_thickness      := 1.2;

    spinbox_theme:      Button_Theme;

    spinbox_theme.text_color         = .{ .1, .42, .42, 1 };
    spinbox_theme.text_color_over    = .{ .4, .70, .70, 1 };
    spinbox_theme.text_color_pressed = .{ .5, .99, .99, 1 };

    spinbox_theme.frame_color            = .{0.2, 0.25, 0.40, 1};
    spinbox_theme.frame_color_over       = .{0.2, 0.30, 0.50, 1};
    spinbox_theme.frame_color_flash      = .{0.2, 0.35, 0.60, 1};
    spinbox_theme.frame_color_down       = .{0.2, 0.55, 0.5,  1};

    // Callbacks you can set to control the rendering of various parts of the slider. If you set these to null, nothing will be drawn:
    draw_background := slider_draw_background_default;
    draw_foreground := slider_draw_foreground_default;

    // format_text_float always takes a float64 as an argument;
    // if the slider operates on float32, it gets cast to float64.
    // Similarly with format_text_int; we cast to s64. We do this
    // cast with a ,no_check so that, if you really want u64,
    // you can cast it back. Yay.
    format_text_float := slider_format_text_float_default;
    format_text_int   := slider_format_text_int_default;

    parse_text_float := slider_parse_text_float_default;
    parse_text_int   := slider_parse_text_int_default;
}

Slider_State :: struct #type_info_none {
    #as using widget: Active_Widget;

    background: Button_State;
    foreground: Button_State;

    // Initial value is used so that we don't clamp it in the case of a relative drag.
    union {
        initial_value_float32: float32;
        initial_value_float64: float64;
        initial_value_int:     int;
    };

    sliding_t: float;
    slowing_t: float;

    accumulated_delta_for_int_slider := 0.0;

    sliding             := false;
    sliding_is_relative := false;
    inputting_text      := false;

    value_type: *Type_Info;
    current_slide_setting: float;   // From 0 to 1; use this in your draw routine.
    surface_margin_this_frame_in_pixels: float;  // Can use this in the draw routine.
    changed_this_frame: bool;       // Did the user do some activating thing?
}

