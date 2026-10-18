dropdown :: (r: Rect, choices: [] string, current_value_pointer: *s32, theme: *Dropdown_Theme = null, identifier: s64 = 0, z: s32 = 100, loc := #caller_location) -> changed: bool, Dropdown_State {
    if !theme  theme = *default_overall_theme.dropdown_theme;

    original_value := current_value_pointer.*;

    // r just describes the Rect for the top of the dropdown.
    // The individual elements below are sized according to theme.button_theme.

    // Draw the background behind the primary choice.

    label_current_value := theme.theme_for_current_value.label_theme;

    // Let's avoid an ABC in case the user passes us a dirty value.
    current_string := "";
    current_value := current_value_pointer.*;
    if (current_value >= 0) && (current_value < choices.count) {
        current_string = choices[current_value];
    }

    hash   := get_hash(loc, identifier);
    state  := find_or_create_state(Dropdown_State, hash);
    defer {
        stop_using_state(state);
        state.last_getrect_frame -= 1;  // @Hack because we don't have a separate state rect for the popup. @Incomplete!
    }


    // Carve off the dropdown indicator from the rest of the button.
    indicator_width := theme.dropdown_indicator_aspect_ratio * r.h;
    r_right, r_left := cut_right(r, indicator_width);

    // @Incomplete: This button hack means the button will update twice as fast, so we need to fix that.
    current := theme.theme_for_current_value;
    current.rectangle_shape.rounding_flags = Rectangle_Shape.Rounding_Flags.NORTHWEST | .SOUTHWEST;

    pressed, current_value_state := button(r_left, current_string, *current, identifier, loc);
    current.rectangle_shape.rounding_flags = Rectangle_Shape.Rounding_Flags.NORTHEAST | .SOUTHEAST;
    state.status = current_value_state.status;

    other_pressed: bool;
    {
        disable_the_duplicate_widget_error = true;   // So that we can do the duplicate button thing below and not generate complaints.
        defer disable_the_duplicate_widget_error = false;  // So that we can do the duplicate button thing below and not generate complaints.
        other_pressed=, other_state := button(r_right, "", *current, identifier, loc);  // Same identifier and loc so they press simultaneously.
        state.status |= other_state.status;
    }


    if pressed || other_pressed {
        state.open = !state.open;
        if state.open active_widget_add   (state);
        else          active_widget_remove(state);
    }


    triangle_margin := r_right.w * 0.1;

    //
    // Update open_t for drawing arrows, etc.
    //

    dt := current_dt;
    if state.open {
        state.open_t = move_toward(state.open_t, 1, dt * theme.arrow_flip_up_rate);
    } else {
        state.open_t = move_toward(state.open_t, 0, dt * theme.arrow_flip_down_rate);
    }

    //
    // Draw the dropdown arrow.
    //
    draw_procs.set_shader_for_color(true);
    {
        p0, p1, p2, p3 := get_quad(r_right);
        p4 := to_vec3(lerp(p0, p1, .5));
        p4.y += triangle_margin;
        p5 := to_vec3(p2);
        p5.x -= triangle_margin;
        p5.y -= triangle_margin;
        p6 := to_vec3(p3);
        p6.x += triangle_margin;
        p6.y -= triangle_margin;

        p5 = lerp(p5, p4, .6);
        p6 = lerp(p6, p4, .6);

        k := 2.3*triangle_margin;
        p4.y += k;
        p5.y += k;
        p6.y += k;

        if state.open_t {
            theta := cast(float)(state.open_t * TAU * .25);
            barycenter := (p4 + p5 + p6) * (1 / 3.0);

            p4 -= barycenter;
            p5 -= barycenter;
            p6 -= barycenter;

            p4.xy = rotate(p4.xy, theta);
            p5.xy = rotate(p5.xy, theta);
            p6.xy = rotate(p6.xy, theta);

            p4 += barycenter;
            p5 += barycenter;
            p6 += barycenter;
        }


        draw_arrow(current_value_state, p4, p5, p6, *theme.theme_for_current_value);
    }


    if state.open {
        state.base_rect             = r;
        state.choices               = choices;
        state.theme                 = theme.*;
        state.hash                  = hash;
        state.loc                   = loc;
        state.z                     = z;
        state.current_value_pointer = current_value_pointer;
        state.current_value_state   = current_value_state;
    }

    add_popup(draw_dropdown_popup, state, state.z);
    // draw_dropdown_popup(state);
    return current_value_pointer.* != original_value, state;
}

draw_dropdown_popup :: (_state: *void) {
    state := cast(*Dropdown_State) _state;
    if !state.open return;

    start_using_state(state);
    defer stop_using_state(state);

    r := state.base_rect;

    occluder_start(state, r);

    theme                 := state.theme;
    current_value_pointer := state.current_value_pointer;
    choices               := state.choices;

    choice_theme := *theme.theme_for_each_choice;
    label_each_choice := choice_theme.label_theme;

    current_value := current_value_pointer.*;

    // For now, assume the choices are the same height as the current value display.
    s := r;
    s.y -= r.h;

    top_y    := s.y;
    bottom_y := s.y;

    pick_choice := -1;
    if state.open {
        for choices {
            sub_hash := get_hash(#location(), it_index);
            choice_hash := combine_hashes(state.hash, sub_hash);

            t := choice_theme;
            if (cast(s32) it_index) == current_value  t = *theme.theme_for_current_choice;

            pressed, _, released := button(s, it, t, xx,no_check choice_hash, state.loc);
            bottom_y = s.y;
            s.y -= s.h;

            if released {
                pick_choice = it_index;
            }
        }

        if pick_choice >= 0 {
            state.open = false;
            current_value_pointer.* = cast(s32) pick_choice;
            update_action_durations(state.current_value_state, *theme.theme_for_current_value, true, 0);
        }
    }

    s.h = top_y - bottom_y;
    s.y = bottom_y;   // Undo the y motion from the final choice.
    occluded := bound(r, s);
    occluder_finish(state, occluded);
}


dropdown_deactivate :: (widget: *Active_Widget) {
    state := cast(*Dropdown_State) widget;
    if !state.open return;

    state.open = false;
}


Dropdown_Theme :: struct {
    theme_for_current_value:  Button_Theme;
    theme_for_each_choice:    Button_Theme;
    theme_for_current_choice: Button_Theme;  // When drawing the current value in the choice list.

    theme_for_current_value.surface_color        = .{.3, .07, .05, 1};
    theme_for_current_value.surface_color_over   = .{.4, .1, .15, 1};
    theme_for_current_value.surface_color_flash  = .{.75, .75, .55, 1};
    theme_for_current_value.surface_color_down   = .{.4, .4, .25, 1};

    theme_for_current_value.frame\  _color       = .{.6, .37, .35, 1};
    theme_for_current_value.frame\  _color_over  = .{.7, .4, .45, 1};
    theme_for_current_value.frame\  _color_flash = .{.95, .95, .85, 1};
    theme_for_current_value.frame\  _color_down  = .{.7, .7, .55, 1};

    theme_for_current_choice.surface_color       = .{.8, .2, .05, 1};
    theme_for_current_choice.surface_color_over  = .{.9, .3, .15, 1};
    theme_for_current_choice.surface_color_flash = .{.95, .75, .55, 1};
    theme_for_current_choice.surface_color_down  = .{.99, .4, .25, 1};

    theme_for_current_choice.frame\ _color       = .{.9, .5, .35, 1};
    theme_for_current_choice.frame\ _color_over  = .{.95, .6, .45, 1};
    theme_for_current_choice.frame\ _color_flash = .{.99, .95, .85, 1};
    theme_for_current_choice.frame\ _color_down  = .{.99, .7, .55, 1};

    theme_for_each\  _choice.surface_color       = .{.15, .05, .05, 1};
    theme_for_each\  _choice.surface_color_over  = .{.25, .12, .12, 1};
    theme_for_each\  _choice.surface_color_flash = .{.65, .55, .35, 1};
    theme_for_each\  _choice.surface_color_down  = .{.40, .20, .10, 1};

    theme_for_each\  _choice.frame\ _color       = .{.35, .20, .20, 1};
    theme_for_each\  _choice.frame\ _color_over  = .{.45, .25, .25, 1};
    theme_for_each\  _choice.frame\ _color_flash = .{.95, .85, .85, 1};
    theme_for_each\  _choice.frame\ _color_down  = .{.70, .50, .35, 1};

    dropdown_indicator_aspect_ratio := 1.0;  // This is for the little arrow showing it's a dropdown box. 1.0 means it's square, with width equal to r.h.

    arrow_flip_up_rate   := 2.5;
    arrow_flip_down_rate := 3.9;
}

Dropdown_State :: struct #type_info_none {
    #as using widget: Active_Widget;
    widget.deactivate_proc = dropdown_deactivate;

    open := false;
    open_t := 0.0;
    status : Status_Flags;

    hash:      u64;
    base_rect: Rect;
    choices:   [] string;
    theme:     Dropdown_Theme = ---;
    loc:       Source_Code_Location;
    z:         s32;

    current_value_pointer: *s32;
    current_value_state:   *Button_State;
}


