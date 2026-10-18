// This is a version of a radio_button where you pass a pointer to an enum, as well as which enum member
// this checkbox represents. But text is still manually indicated.
radio_button :: (r: Rect, text: string, current_value: *$Enum, button_value: Enum, theme: *Checkbox_Theme = null, identifier: s64 = 0, loc := #caller_location) -> changed: bool, checkbox_state: Checkbox_State {
    selected := (current_value.* == button_value);

    changed, checkbox_state := base_checkbox(r, text, selected, theme, identifier, loc);
    if changed {
        current_value.* = button_value;
        return true, checkbox_state;
    }

    return false, checkbox_state;
}

// In this version of radio_button, we generate the text from the enum name. For when you want to be
// extra lazy.
radio_button :: (r: Rect, current_value: *$Enum, button_value: Enum, theme: *Checkbox_Theme = null, identifier: s64 = 0, loc := #caller_location) -> changed: bool, checkbox_state: Checkbox_State {
    text := tprint("%", button_value);  // We make a copy so that we can iterate and make underscores into spaces.
    for 0..text.count-1 {
        if text[it] == #char "_"  text[it] = #char " ";  // Convert underscores to spaces!
    }

    changed, checkbox_state := radio_button(r, text, current_value, button_value, theme, identifier, loc);
    return changed, checkbox_state;
}


// Similar to what we just did, but these are for enum_flags.
// First, the one with the explicit string:
checkbox_flags :: (r: Rect, text: string, current_value: *$Enum, button_value: Enum, theme: *Checkbox_Theme = null, identifier: s64 = 0, loc := #caller_location) -> changed: bool, checkbox_state: Checkbox_State {
    selected := cast(bool)(current_value.* & button_value);
    changed, checkbox_state := base_checkbox(r, text, selected, theme, identifier, loc);
    if changed {
        current_value.* ^= button_value;
        return true, checkbox_state;
    }

    return false, checkbox_state;
}

// Here is a checkbox_flags with lazy string generation:
checkbox_flags :: (r: Rect, current_value: *$Enum, button_value: Enum, theme: *Checkbox_Theme = null, identifier: s64 = 0, loc := #caller_location) -> changed: bool, checkbox_state: Checkbox_State {
    text := tprint("%", button_value);  // We make a copy so that we can iterate and make underscores into spaces.
    for 0..text.count-1 {
        if text[it] == #char "_"  text[it] = #char " ";
    }

    changed, checkbox_state := checkbox_flags(r, text, current_value, button_value, theme, identifier, loc);
    return changed, checkbox_state;
}

base_checkbox :: (_r: Rect, text: string, selected: bool, theme: *Checkbox_Theme = null, identifier: s64 = 0, loc := #caller_location) -> changed: bool, checkbox_state: Checkbox_State {
    r := _r;

    hash  := get_hash(loc, identifier);
    state := find_or_create_state(Checkbox_State, hash);
    defer stop_using_state(state);

    if !theme  theme = *default_overall_theme.checkbox_theme;

    label_theme := theme.label_theme;
    font := label_theme.font;
    if !font {
        font = get_default_font_at_size(r.h*.65);
        label_theme.font = font;
    }

    text_width, text_height := text_size(font, text);
    box_size := text_height - 1;
    if box_size > r.h  box_size = r.h;  // So that we don't get too big when putting these in a row. (text height is often misreported as being too high!)

    w := r.w;
    h := r.h;

    status := get_status_flags(r);
    box_x := r.x;
    box_y := r.y + floor((h - box_size + 1) / 2);

    vibration := 0.0;
    {
        // Compute vibration if we have recently been perturbed.
        d := state.base.action_duration_2;
        if d >= 0 {
            theta := TAU * 3 * d;
            ct := sin(theta);

            damp := 1 - d/2.3;
            Clamp(*damp, 0, 1);
            damp *= damp;
            if damp == 0  state.base.action_duration_2 = -1;

            vibration = box_size * ct * .05 * damp;
        }
    }

    button_theme := theme.button_theme;  // Copy this so we can change colors due to being selected.
    button := *button_theme;

    {
        // Update selected_t and modify button and text colors for the selected item.
        target := ifx selected then 1.0 else 0.0;

        denom := button.press_duration;
        if !denom denom = 1;
        rate   := ifx selected then 1.0/denom else 1.0;

        dt := current_dt;
        state.selected_t = move_toward(state.selected_t, target, dt * rate);  // Actually, let this be slow, so that the color change due to being pressed dominates the experience.

        button.surface_color = lerp(button.surface_color, theme.button_color_selected, state.selected_t);
        button.text_color       = lerp(button.text_color, theme.text_color_selected,   state.selected_t);
    }

    //
    // The bitmap part:
    //

    b := box_size + vibration;
    center_x := box_x + box_size * .5;
    center_y := box_y + box_size * .5;

    image: *Texture;
    if theme.is_radio_button {
        image = ifx selected then map_radiobox_full else map_radiobox_empty;
    } else {
        image = ifx selected then map_checkbox_full else map_checkbox_empty;
    }

    image_rect := get_rect(center_x-b*.5, center_y-b*.5, b, b);

    changed := cast(bool)(status & .PRESSED);
    update_production_value_button(image_rect, changed, *state.base, status, button);

    if changed {
        active_widget_deactivate_all();
    }

    image_color := lerp(button.surface_color, button.surface_color_over,  state.base.over_factor);
    image_color  = lerp(image_color,          button.surface_color_down,  state.base.down_effect_t);
    image_color  = lerp(image_color,          button.surface_color_flash, state.base.pressed_factor);

    draw_procs.set_shader_for_images(image);
    {
        p0, p1, p2, p3 := get_quad(image_rect);
        draw_procs.immediate_quad(p0, p1, p2, p3, image_color);
        draw_procs.immediate_flush();
    }


    // If we are going from unselected to selected, then make selected_t be at least as high as pressed_factor,
    // so that by the time we reach the

    //
    // The text part:
    //
    r.x += box_size;
    r.w -= box_size;

    text_color := lerp(button.text_color, button.text_color_over,    state.base.over_factor);
    text_color  = lerp(text_color,        button.text_color_pressed, state.base.pressed_factor);
    label_theme.text_color = text_color;

    label(r, text, *label_theme);  // @Speed: Text was already prepped, we could tell that somehow.

    return changed, state;
}



Checkbox_Theme :: struct {
    using button_theme: Button_Theme;

    // Button_Theme's surface_color, etc are used for the checkbox bitmap.
    surface_color         = .{.55, .55, .55, 1.0};
    surface_color_over    = .{.80, .80, .80, 1.0};
    surface_color_flash   = .{.90, .70, .90, 1.0};
    surface_color_down    = .{.90, .70, .90, 1.0};  // When held down.

    text_color               = .{.55, .55, .55, 1.0};
    text_color_over          = .{.80, .80, .80, 1.0};
    text_color_pressed       = .{.90, .70, .90, 1.0};

    // There aren't separate 'over' and 'pressed' colors when selected,
    // though maybe we should add those?
    button_color_selected   := Vector4.{.90, .90, .90, 1.0};
    text_color_selected     := Vector4.{.90, .60, .90, 1.0};

    is_radio_button := false;

    alignment         = .Left;  // Alignment for the text.
    alignment_pad_ems = 0.2;    // Spacing between checkbox and text.
}

Checkbox_State :: struct #type_info_none {
    #as using widget: Active_Widget;

    base: Button_State;
    selected_t := 0.0;
}

