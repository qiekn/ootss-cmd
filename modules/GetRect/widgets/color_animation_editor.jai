//
// To draw the Color Animation Editor on the screen, call color_animation_editor() like any other widget.
//
// Controls are not yet configurable or hinted at on the screen. Left-click and drag an existing keyframe
// to move it around. Left-click on the gradient bar, but off a keyframe, to create a new keyframe.
// Shift-click a keyframe to open the Color Picker to change the color. Right-click a keyframe to delete it.
//
// This editor gives you a way to paste out data using the UI, but you may want to get the data programatically
// (as we do in the Sokoban game).
//
// You can use get_keyframes() or set_keyframes() to, obviously, get or set the keyframes, which are the
// handles you graphically manipulate in the UI. These are the source data, which is relatively compact,
// that you could serialize out to represent the particular gradient being constructed. So if you put
// this widget in an editor, for example, you might have a button or key command that calls get_keyframes()
// and saves that data out somewhere.
//
// Because there are options to control how the gradient is interpolated, in order to reconstruct
// the gradient properly, you also need to know the correct values for the Interpolation struct
// that was active when the gradient was created. You can serialize this too, or maybe you just forced
// it to be constant so you know what it is.
//
// You can also generate samples of the gradient at the density you choose. This is more data -- it's just
// a big array of output colors -- so it's not a form you would want to edit either. But it's also very
// simple and easy for code to understand. If you want to make a texture or table of colors to control
// some animation, this may be a good way to do it (especially if on the GPU). Do this by calling
// generate_color_samples() -- the array you pass in as 'output_samples' should be pre-allocated to the
// size that you want. The samples will be filled in, with index 0 being t = 0 in the gradient, and
// count-1 being t=1 in the gradient.
//
// You do not need to start up the GUI in order to generate samples. That said, generate_color_samples
// is contained inside GetRect right now, so you would still need to import GetRect. Longer-term, maybe
// we should put it into a sub-library?
//
//


get_desired_aspect_ratio :: (theme: *Color_Animation_Editor_Theme) -> float {
    // There are no theme properties that modify the aspect ratio.
    return 4.69;
}

color_animation_editor :: (r: Rect, theme: *Color_Animation_Editor_Theme = null, identifier: s64 = 0, loc := #caller_location) -> (state: *Color_Animation_Editor_State) {
    if !theme  theme = *default_overall_theme.color_animation_editor_theme;

    ipad_x := floor(r.w * theme.horizontal_padding + .5);
    ipad_y := floor(r.w * theme.vertical_padding   + .5);

    top, non_top := cut_top(r, ipad_y);
    middle       := shrink_x(non_top, ipad_x);

    hash := get_hash(loc, identifier);
    state, created := find_or_create_state(Color_Animation_Editor_State, hash);
    defer stop_using_state(state);

    if created {
        set_interpolation(state, theme.default_interpolation);
        state.num_clipboard_samples = theme.default_num_clipboard_samples;

        set_keyframes(state, theme.default_keyframes);

        state.time_view_period = theme.default_time_view_period;
    }

    draw_procs.set_shader_for_color(true);

    // Draw the background.
    background := *theme.background;
    rounded_rectangle(r, background.shape, background.color, background.frame_color);


    draw_color_gradient_bar(middle, theme, state, ipad_y);

    state.theme = theme;  // This is so that the callbacks for popups can look through the user data pointer for 'state' to find the Color_Animation_Editor_Theme, Number_Input_Theme, etc.

    draw_color_picker(theme, state);

    if theme.draw_subwidgets_flags & .TIME_VIEW
        draw_time_view(theme, state);

    update_keyframe_color_due_to_open_color_picker(state);

    return state;
}

open_color_picker :: (theme: *Color_Animation_Editor_Theme, state: *Color_Animation_Editor_State, keyframe_index: int, bar_rect: Rect) {
    sub := *state.color_picker_subwindow_info;
    sub.open = true;
    sub.wants_a_raise = true;

    state.color_picker_keyframe_index = keyframe_index;

    key := *state.color_keyframes[keyframe_index];
    state.color_picker_editing_color_applied = key.color_rgb.xyz;

    if state.last_color_picker_state {
        set_original_and_current_color_rgb(state.last_color_picker_state, key.color_rgb.xyz);
    }


    if state.color_picker_subwindow_rect_initialized {
        // Just set the x and y to the new position.
        // Keep the w and h from the old rect, in case it was resized.

        w := sub.rect.w;
        h := sub.rect.h;

        x := key.pos_x - w * .5;
        y := bar_rect.y - h * 1.05;

        sub.rect.x = x;
        sub.rect.y = y;
    } else {
        state.color_picker_subwindow_rect_initialized = true;

        w := bar_rect.h * 3;
        h := (3.7/3) * w;
        x := key.pos_x - w * .5;
        y := bar_rect.y - h * 1.05;

        r := get_rect(x, y, w, h);
        sub.rect               = r;
        sub.fixed_aspect_ratio = r.w/r.h;
        sub.draw               = draw_callback_color_picker;
        sub.title_text         = "Color Picker";
        sub.user_data          = state;
    }
}

open_time_view :: (theme: *Color_Animation_Editor_Theme, state: *Color_Animation_Editor_State, bar_rect: Rect) {
    sub := *state.time_view_subwindow_info;
    sub.open = true;
    sub.wants_a_raise = true;

    if !state.time_view_subwindow_rect_initialized {
        state.time_view_subwindow_rect_initialized = true;

        w := bar_rect.h * 3;
        h := (3.7/3) * w;
        x := bar_rect.x + bar_rect.w*.5;
        y := bar_rect.y - h * 1.05;

        r := get_rect(x, y, w, h);
        sub.rect               = r;
        sub.fixed_aspect_ratio = r.w/r.h;
        sub.draw               = draw_callback_time_view;
        sub.title_text         = "Time View";
        sub.user_data          = state;
    }
}

update_keyframe_color_due_to_open_color_picker :: (state: *Color_Animation_Editor_State) {
    index := state.color_picker_keyframe_index;
    if index < 0  return;
    if index >= state.color_keyframes.count return;  // Should not happen, but let's be paranoid. Maybe should log an error here.

    sub := *state.color_picker_subwindow_info;
    if !sub.open return;

    if state.last_color_picker_state { // If the callback hasn't run yet, we won't have this...!
        key := *state.color_keyframes[index];
        key.color_rgb.xyz = state.last_color_picker_state.current_rgb_color;
    }
}

draw_color_picker :: (theme: *Color_Animation_Editor_Theme, state: *Color_Animation_Editor_State) {
    // Does not actually draw; creates a subwindow with a callback
    // that GetRect will call later to draw.
    sub := *state.color_picker_subwindow_info;
    if !sub.open return;

    subwindow_theme := *theme.color_picker_subwindow_theme;
    subwindow_state := add_subwindow(sub, subwindow_theme);
}

draw_callback_color_picker :: (state: *Subwindow_State, r: Rect, data: *void) {
    state := cast(*Color_Animation_Editor_State) data;

    applied, still_dragging, color_picker_state := color_picker(r, *state.color_picker_editing_color_applied, *state.theme.color_picker_theme);
    state.last_color_picker_state = color_picker_state;
}


draw_time_view :: (theme: *Color_Animation_Editor_Theme, state: *Color_Animation_Editor_State) {
    sub := *state.time_view_subwindow_info;
    if !sub.open return;

    subwindow_theme := *theme.time_view_subwindow_theme;
    subwindow_state := add_subwindow(sub, subwindow_theme);
}

find_index_of_t :: (sorted: [] *Augmented_Keyframe, t: float) -> (index: int) {
    // Seek forward to find the i0 of the t we want.
    index := -1;
    while index < sorted.count-1 {
        next_key := sorted[index+1];
        if t < next_key.t  break;

        index += 1;
    }

    return index;
}

draw_callback_time_view :: (state: *Subwindow_State, r: Rect, data: *void) {
    state := cast(*Color_Animation_Editor_State) data;

    if state.time_view_playing {
        state.time_view_current_time += current_dt;
    }

    period := state.time_view_period;
    t := cast(float) fmod_cycling(state.time_view_current_time / state.time_view_period, 1);
    Clamp(*t, 0, 1);


    interp := get_interpolation(state);
    sorted := get_sorted_keyframes(state);

    temp_colors := make_colors(sorted, interp.color_space,, temp);

    i0 := find_index_of_t(sorted, t);  // May return -1.
    color := interpolate_one_sample(i0, t, interp, sorted, temp_colors);
    color.w = 1;


    margin := r.w * 0.025;
    inner_w := r.w - 2 * margin;

    r_square: Rect;
    r_square.x = r.x + margin;
    r_square.w = inner_w;
    r_square.y = r.y + r.h - (inner_w + margin);
    r_square.h = inner_w;

    p0, p1, p2, p3 := get_quad(r_square);
    draw_procs.immediate_quad(p0, p1, p2, p3, color);


    controls := r;
    controls.h = r_square.y - r.y;
    controls = shrink(controls, margin);

    button_height := controls.h * .42;
    vpad := button_height * .2;
    remainder: Rect = ---;

    controls, remainder = cut_top(controls, button_height);

    top_left, top_right := cut_left(controls, controls.w*.5, controls.w*.025);

    // Play / Pause button:
    text := ifx state.time_view_playing then "Pause" else "Play";
    play_pause_pressed := button(top_left, text, *state.theme.button_theme);
    if play_pause_pressed {
        state.time_view_playing = !state.time_view_playing;
    }

    // Period control in seconds:
    label_rect, samples_input_rect := cut_left(top_right, .7*top_right.w);
    label(label_rect, "Seconds:", *state.theme.label_theme);
    inert_string := tprint("%", state.time_view_period);
    number_changed := number_input(samples_input_rect, inert_string, *state.time_view_period, .01, 100.0, *state.theme.number_input_theme);

    draw_procs.immediate_flush();
}

draw_color_gradient_bar :: (area: Rect, theme: *Color_Animation_Editor_Theme, state: *Color_Animation_Editor_State, top_margin: float) {
    button_height := (area.h - area.h * (.4/.8525)) * .24;
    vpad := button_height * .2;

    cut_height := area.h - top_margin-vpad;
    row_spacing := button_height + vpad;

    if theme.draw_subwidgets_flags != 0
        cut_height -= row_spacing;

    if (theme.draw_subwidgets_flags & .INTERPOLATION_CONTROLS || theme.draw_subwidgets_flags & .SAMPLING_CONTROLS)
        cut_height -= row_spacing;

    if (theme.draw_subwidgets_flags & .TIME_VIEW && theme.draw_subwidgets_flags & .INTERPOLATION_CONTROLS
        || theme.draw_subwidgets_flags & .SAMPLING_CONTROLS && theme.draw_subwidgets_flags & .COPY_TO_CLIPBOARD)
        cut_height -= row_spacing;

    bar_rect, controls_area := cut_top(area, cut_height);
    bar_height := bar_rect.h;

    alpha := 1.0;
    changed := my_color_slider(bar_rect, alpha, theme, state);

    // Split the controls_area into 3 columns:
    _junk: Rect = ---;
    _junk, controls_area = cut_top(controls_area, top_margin);
    controls_left, controls_mr := cut_left(controls_area, .33 * area.w);
    controls_middle, controls_right := cut_left(controls_mr, .5 * controls_mr.w);

    shrinkage := bar_height * .04;  // Margin around controls areas.
    controls_left   = shrink_x(controls_left,   shrinkage);
    controls_middle = shrink_x(controls_middle, shrinkage);
    controls_right  = shrink_x(controls_right,  shrinkage);

    _pad: Rect = ---;

    dropdown_theme := *theme.dropdown_theme;

    //
    // controls_left: Interpolation parameters.
    //
    {
        controls := controls_left;

        r, _remainder   := cut_top(controls, button_height);
        if theme.draw_subwidgets_flags & .INTERPOLATION_CONTROLS {
            _pad, controls   = cut_top(_remainder, vpad);

            color_space_rect, geometry_rect := cut_left(r, .5*r.w, shrinkage);

            dropdown(color_space_rect, COLOR_SPACE_NAMES, *state.interpolation_color_space_s32, dropdown_theme);
            dropdown(geometry_rect, INTERPOLATION_GEOMETRY_NAMES, *state.interpolation_geometry_s32, dropdown_theme);

            r, _remainder    = cut_top(controls, button_height);
            _pad, controls   = cut_top(_remainder, vpad);

            r_wrapping, r_gamma := cut_left(r, .5*r.w, shrinkage);

            checkbox_theme := *theme.checkbox_theme;
            wrapping_changed := base_checkbox(r_wrapping, "Wrapping", state.interpolation_wrapping, checkbox_theme);
            if wrapping_changed  state.interpolation_wrapping = !state.interpolation_wrapping;
        }

        if theme.draw_subwidgets_flags & .TIME_VIEW {
            r, _remainder    = cut_top(controls, button_height);
            _pad, controls   = cut_top(_remainder, vpad);
            time_view_pressed := button(r, "Time View", *theme.button_theme);
            if time_view_pressed {
                sub := *state.time_view_subwindow_info;

                if sub.open {
                    sub.open = false;
                } else {
                    open_time_view(theme, state, bar_rect);
                }
            }
        }
    }


    //
    // controls_right: Copying to Clipboard.
    //
    {
        controls := controls_right;
        r, _remainder   := cut_top(controls, button_height);
        output_type: Output_Type;
        if theme.draw_subwidgets_flags & .SAMPLING_CONTROLS {
            _pad, controls   = cut_top(_remainder, vpad);

            _, r_output_type := cut_left(r, r.w*.5);

            dropdown(r_output_type, OUTPUT_TYPE_NAMES, *state.output_type_s32, dropdown_theme);

            _samples_input_rect, _remainder0 := cut_top(controls, button_height);
            _pad, controls = cut_top(_remainder0, vpad);

            label_rect, samples_input_rect := cut_left(_samples_input_rect, _samples_input_rect.w * .6);

            output_type = cast(Output_Type) state.output_type_s32;

            if output_type == .RESAMPLED_ARRAY {
                label(label_rect, "Number of Samples", *theme.label_theme);
                inert_string := tprint("%", state.num_clipboard_samples);
                number_changed := number_input(samples_input_rect, inert_string, *state.num_clipboard_samples, 1, 0xff_ffff, *theme.number_input_theme);
            }
        }

        if theme.draw_subwidgets_flags & .COPY_TO_CLIPBOARD {
            output_button_rect, _remainder1 := cut_top(controls, button_height);
            _pad, controls = cut_top(_remainder1, vpad);

            output_button_theme := *theme.button_theme;
            font := output_button_theme.font;

            pressed := button(output_button_rect, "Copy to Clipboard", output_button_theme);
            if pressed {
                copy_output_to_clipboard(state, output_type);
            }
        }
    }
}


get_sorted_keyframes :: (state: *Color_Animation_Editor_State, index_to_ignore := -1) -> [] *Augmented_Keyframe {
    sorted: [..] *Augmented_Keyframe;
    sorted.allocator = temp;

    array_reserve(*sorted, state.color_keyframes.count);
    for * state.color_keyframes  if it_index != index_to_ignore  array_add(*sorted, it);

    quick_sort(sorted, x => x.t);

    return sorted;
}

// @Copypasta from color_picker.jai.
my_color_slider :: (rect: Rect, alpha: float, theme: *Color_Animation_Editor_Theme, state: *Color_Animation_Editor_State) -> (changed: bool) {
    update_keyframes(rect, theme, state);

    // input_color is hsv, rgb, or whatever we want to use for that particular slider.
    draw_procs.set_shader_for_color(true);

    NUM_SEGMENTS :: 36; // Divisible by 6 so that we hit the extrema of the H function.

    left_\arrow_tip: Vector3 = ---;
    right_arrow_tip: Vector3 = ---;
    arrow_color:     Vector4 = ---;

    changed := false;

    //
    // Pass 1: Fill out the colors.
    //

    num_samples := max(2, cast(s32) floor(rect.w + .5));  // One per pixel, bro!

    samples := *state.color_samples;
    array_resize(samples, num_samples);

    interpolation := get_interpolation(state);
    sorted := get_sorted_keyframes(state);
    generate_color_samples(sorted, interpolation, samples.*);

    //
    // Pass 2: Draw the colors.
    //
    last_p0, last_p1: Vector3 = ---;
    last_color: Vector4 = ---;

    assert(samples.count > 1);  // So we don't divide by zero.
    for i: 0..samples.count-1 {
        t := i / cast(float)(samples.count-1);

        p0 := Vector3.{rect.x + t * rect.w, rect.y, 0};
        p1 := Vector3.{rect.x + t * rect.w, rect.y + rect.h, 0};

        color := samples.*[i];
        color.w   = alpha;

        if i != 0 {
            draw_procs.immediate_triangle(last_p0, last_p1, p1, last_color, last_color, color);
            draw_procs.immediate_triangle(last_p0, p1,      p0, last_color, color,       color);
        }

        last_p0 = p0;
        last_p1 = p1;
        last_color = color;
    }

    draw_procs.immediate_flush();


    for * state.color_keyframes {
        draw_color_keyframe(it_index, rect, theme, state);
    }

    draw_procs.immediate_flush();

    focus := has_focus(rect);
    down  := focus && (mouse_button_left_state & .DOWN);

    // Don't disable dragging until after we draw ... so we get at least
    // one update if we do an intra-frame click.
    if state.dragging_in_strip {
        if !down {
            state.dragging_in_strip = false;
        }
    }

    return changed;
}

update_keyframes :: (rect: Rect, theme: *Color_Animation_Editor_Theme, state: *Color_Animation_Editor_State) {
    // @Cleanup: Move this to *before* render!

    status := get_status_flags(rect);
    activity_mask := cast(bool)(status & .OVER);

    // Find the closest keyframe to the mouse pointer.
    // Only do this if we are not dragging!
    if !state.dragging_in_strip {
        best_keyframe_index := -1;
        best_distance := FLOAT32_INFINITY;

        dist_max := theme.keyframe_width_relative_to_bar_height_nondragging * rect.h * theme.keyframe_selection_size_relative_to_visual_size;

        for * key: state.color_keyframes {
            x := rect.x + rect.w * key.t;
            key.pos_x = x;

            dist := abs(x - mouse_x_float);
            if (dist <= dist_max) && (dist < best_distance) {
                best_distance = dist;
                best_keyframe_index = it_index;
            }
        }

        for * key: state.color_keyframes {
            key.active = activity_mask && (it_index == best_keyframe_index);
        }

        // Now that we have updated positions, figure out if we are going to start dragging.
        // Also, add or remove keyframes. Note that dragging uses the keyframe index, so scrambling
        // the array would lead to bad results when dragging; but if not dragging, we can reorder
        // array elements and that's fine for now. (This is what we do when removing keyframes).
        // That said, for color pick stuff, we need to maintain the indices. See :MaintainingIndices.
        if status & .OVER {
            if mouse_button_left_state & .START {
                if best_keyframe_index >= 0 {
                    // If the user is holding down shift, open the color picker.
                    // Otherwise, start dragging that keyframe.
                    if ui_get_button_state(.SHIFT) {
                        open_color_picker(theme, state, best_keyframe_index, rect);
                    } else {
                        state.dragging_in_strip = true;
                        state.dragging_keyframe_index = best_keyframe_index;
                    }
                } else {
                    // Make a new keyframe.
                    key := array_add(*state.color_keyframes);
                    denom := ifx rect.w else 1;
                    t := (mouse_x - rect.x) / denom;
                    Clamp(*t, 0, 1);
                    key.t = t;

                    init_color_by_interpolation(state, state.color_keyframes.count-1);
                }
            } else if mouse_button_right_state & .START {
                if best_keyframe_index >= 0 && state.color_keyframes.count > 1 {
                    // Delete that keyframe.

                    //
                    // :MaintainingIndices
                    //

                    // If color picker was open to the current index, close it.
                    current := best_keyframe_index;
                    if state.color_picker_keyframe_index == current {
                        sub := *state.color_picker_subwindow_info;
                        sub.open = false;

                        state.color_picker_keyframe_index = -1;
                    }

                    // If color picker was open to the last index, remap it to current,
                    // because that is where the dude will now be in the array.
                    last := state.color_keyframes.count-1;
                    if state.color_picker_keyframe_index == last {
                        state.color_picker_keyframe_index = current;
                    }

                    array_unordered_remove_by_index(*state.color_keyframes, current);
                }
            }
        }
    }

    if state.dragging_in_strip { // We may have set state.dragging_in_strip above, and if so we want to respond with minimum latency, so don't combine this with the above 'if'!
        index := state.dragging_keyframe_index;
        if (index < state.color_keyframes.count) && rect.w {
            target_t := (mouse_x - rect.x) / rect.w;
            Clamp(*target_t, 0, 1);

            key := *state.color_keyframes[index];
            key.t = target_t;
            key.pos_x = rect.x + rect.w * target_t;
        }
    }

    sub := *state.color_picker_subwindow_info;

    // Update animating parameters for the keyframe thingies:
    for * key: state.color_keyframes {
        active_target := cast(float) key.active;
        move_toward(*key.active_t, active_target, state.cosmetic_dt, 5.0, 8.0);

        dragging_target := cast(float)(state.dragging_in_strip && state.dragging_keyframe_index == it_index);
        move_toward(*key.dragging_t, dragging_target, state.cosmetic_dt, 5.0, 8.0);

        color_picking_target := cast(float)(sub.open && state.color_picker_keyframe_index == it_index);
        move_toward(*key.color_picking_t, color_picking_target, state.cosmetic_dt, 5.0, 8.0);
    }
}

draw_color_keyframe :: (index: int, rect: Rect, theme: *Color_Animation_Editor_Theme, state: *Color_Animation_Editor_State) {
    key := *state.color_keyframes[index];

    if !rect.h return;

    t := key.t;
    Clamp(*t, 0, 1);

    dragging_t := key.dragging_t;

    dx_nondragging := rect.h * theme.keyframe_width_relative_to_bar_height_nondragging;

    scale := 1.0;
    scale = lerp(scale, theme.keyframe_scale_when_dragging,      key.dragging_t);
    scale = lerp(scale, theme.keyframe_scale_when_color_picking, key.color_picking_t);

    dx := dx_nondragging * scale;
    dy := dx;

    inset := dx * theme.keyframe_inset_ratio;

    inset_y0 := rect.y + inset;
    inset_y1 := rect.y + rect.h - inset;

    pa := v3(rect.x + t * rect.w, inset_y0, 0);
    pb := v3(rect.x + t * rect.w, inset_y1, 0);

    color := lerp(theme.keyframe_color_inactive, theme.keyframe_color_active, key.active_t);
    color  = lerp(color, theme.keyframe_color_picking, key.color_picking_t);

    // Foreground triangle:
    p0 := pa;
    p1 := p0 + v3(-dx*.5, -dy, 0);
    p2 := p1 + v3(dx, 0, 0);

    p3 := pb;
    p4 := p3 + v3(-dx*.5, dy, 0);
    p5 := p4 + v3(dx, 0, 0);

    // Background triangle:
    {
        backing := theme.keyframe_backing_ratio * dx;

        centroid_0 := (p0 + p1 + p2) / 3.0;
        centroid_3 := (p3 + p4 + p5) / 3.0;

        v0 := p0 - centroid_0;
        v1 := p1 - centroid_0;
        v2 := p2 - centroid_0;

        v3 := p3 - centroid_3;
        v4 := p4 - centroid_3;
        v5 := p5 - centroid_3;

        q0 := p0 + unit_vector(v0) * backing;
        q1 := p1 + unit_vector(v1) * backing;
        q2 := p2 + unit_vector(v2) * backing;

        q3 := p3 + unit_vector(v3) * backing;
        q4 := p4 + unit_vector(v4) * backing;
        q5 := p5 + unit_vector(v5) * backing;

        color := theme.keyframe_color_backing;
        draw_procs.immediate_triangle(q0, q1, q2, color, color, color);
        draw_procs.immediate_triangle(q3, q4, q5, color, color, color);
    }

    // Draw the foreground triangle.
    draw_procs.immediate_triangle(p0, p1, p2, color, color, color);
    draw_procs.immediate_triangle(p3, p4, p5, color, color, color);
}

copy_output_to_clipboard :: (state: *Color_Animation_Editor_State, output_type: Output_Type) {
    Clipboard :: #import "Clipboard";
    builder: String_Builder;

    if #complete output_type == {
      case .RESAMPLED_ARRAY;
        num_samples := state.num_clipboard_samples;
        samples: [..] Vector4;
        samples.allocator = temp;
        array_resize(*samples, num_samples);

        interpolation := get_interpolation(state);
        sorted := get_sorted_keyframes(state);
        generate_color_samples(sorted, interpolation, samples);

        append(*builder, "Vector4.[");
        for samples {
            print_to_builder(*builder, ".%, ", it);
        }

        append(*builder, "]");
      case .SOURCE_KEYFRAMES;
        append(*builder, "Color_Keyframe.[");
        for * state.color_keyframes {
            print_to_builder(*builder, ".{.%, %}, ", it.color_rgb, it.t);
        }

        append(*builder, "]");
    }

    text := builder_to_string(*builder);
    Clipboard.os_clipboard_set_text(text);
}

init_color_by_interpolation :: (state: *Color_Animation_Editor_State, keyframe_index: int) {
    key := *state.color_keyframes[keyframe_index];

    sorted := get_sorted_keyframes(state, keyframe_index);
    interp := get_interpolation(state);

    temp_colors := make_colors(sorted, interp.color_space,, temp);

    index := find_index_of_t(sorted, key.t);  // May return -1.
    key.color_rgb = interpolate_one_sample(index, key.t, interp, sorted, temp_colors);
}

get_interpolation :: (state: *Color_Animation_Editor_State) -> Interpolation {
    result: Interpolation;
    result.color_space = xx state.interpolation_color_space_s32;
    result.geometry    = xx state.interpolation_geometry\  _s32;

    result.wrapping    = state.interpolation_wrapping;

    return result;
}

set_interpolation :: (using state: *Color_Animation_Editor_State, interp: Interpolation) {
    interpolation_color_space_s32  = cast(s32) interp.color_space;
    interpolation_geometry_s32     = cast(s32) interp.geometry;
    interpolation_wrapping         = interp.wrapping;
}

set_keyframes :: (state: *Color_Animation_Editor_State, frames: [] Color_Keyframe) {
    array_reset(*state.color_keyframes);
    array_resize(*state.color_keyframes, frames.count);

    for frames  state.color_keyframes[it_index].base = it;
}

get_keyframes :: (state: *Color_Animation_Editor_State) -> [] Color_Keyframe { /* Temporary Storage; keyframes are returned sorted by 't'. */
    result: [..] Color_Keyframe;
    result.allocator = temp;

    array_resize(*result, state.color_keyframes.count, false);

    sorted := get_sorted_keyframes(state);
    for sorted  result[it_index] = it.base;

    return result;
}

Color_Animation_Editor_Theme :: struct {
    horizontal_padding  := .015;   // Relative to rect.w.
    vertical_padding    := .015;   // Relative to rect.w. (This is not a mistake.)

    keyframe_color_inactive := Vector4.{.35, .35, .35, 1};
    keyframe_color_active   := Vector4.{.94, .94, .94, 1};
    keyframe_color_picking  := Vector4.{.87, .87, .87, 1};
    keyframe_color_backing  := Vector4.{.05, .05, .05, 1};

    keyframe_width_relative_to_bar_height_nondragging := 0.10;
    keyframe_scale_when_dragging      := 1.5;
    keyframe_scale_when_color_picking := 1.3;

    keyframe_selection_size_relative_to_visual_size := 1.4;
    keyframe_inset_ratio   := 0.8;
    keyframe_backing_ratio := 0.24;

    background: Background_Theme;
    background.shape.roundedness_type     = .ABSOLUTE_FROM_GLOBAL;
    background.shape.frame_thickness_type = .ABSOLUTE_FROM_GLOBAL;
    background.shape.rounding_flags       = .SOUTH;

    background.color                      = Vector4.{.00, .10, .10, 1};


    color_picker_theme:           Color_Picker_Theme;
    color_picker_subwindow_theme: Subwindow_Theme;

    time_view_subwindow_theme:    Subwindow_Theme;
    time_view_subwindow_theme.region_background.frame_color  = .{0.28, 0.28, 0.28, 1.0};
    time_view_subwindow_theme.region_background.color        = .{0.05, 0.05, 0.05, 1.0};


    button_theme:                 Button_Theme;

    label_theme:                  Label_Theme;
    label_theme.alignment = .Right;

    number_input_theme:           Number_Input_Theme;
    dropdown_theme:               Dropdown_Theme;
    checkbox_theme:               Checkbox_Theme;


    default_interpolation := Interpolation.{.OKLAB, .HERMITE, false};
    default_num_clipboard_samples : s32 = 16;

    default_keyframes: []Color_Keyframe = .[.{.{0.926563, 0.832695, 0.841836, 1}, 0.505263}, .{.{0.828598, 0.029386, 0.579748, 1}, 0.997368}, .{.{1, 0.33835, 0, 1}, 0.003289}, ];

    default_time_view_period := 3.0;

    Draw_Subwidgets_Flags :: enum_flags u8 {
        INTERPOLATION_CONTROLS :: 0x01;
        TIME_VIEW ::              0x02;
        SAMPLING_CONTROLS ::      0x04;
        COPY_TO_CLIPBOARD  ::     0x08;
    }
    DRAW_ALL_SUBWIDGETS :: Draw_Subwidgets_Flags.INTERPOLATION_CONTROLS | .TIME_VIEW | .SAMPLING_CONTROLS | .COPY_TO_CLIPBOARD;
    draw_subwidgets_flags := DRAW_ALL_SUBWIDGETS;
}

Color_Animation_Editor_State :: struct #type_info_none {
    #as using widget: Active_Widget;

    ring_point     := Vector2.{1, 0};
    disc_point     := Vector2.{1, 0};

    dragging_in_strip:       bool;
    dragging_keyframe_index: int;

    color_picker_keyframe_index: int;
    color_picker_subwindow_info: Subwindow_Info;

    color_picker_subwindow_info.open = false;

    time_view_subwindow_info: Subwindow_Info;
    time_view_subwindow_info.open = false;

    color_picker_editing_color_applied: Vector3;  // Not really used currently. This is updated when the user clicks 'Apply'. For now we just read the color off every frame.

    color_picker_subwindow_rect_initialized := false;
    time_view\  _subwindow_rect_initialized := false;

    theme: *Color_Animation_Editor_Theme; // Ephemeral; used only when employing the color picker callback.

    last_color_picker_state: *Color_Picker_State;  // Used so that we update the color in the main loop...

    // Storage for temporary color samples used for rendering:
    color_samples: [..] Vector4;

    num_clipboard_samples: s32;  // How many samples we output when you Copy to Clipboard.

    interpolation_color_space_s32: s32;   // Edited by the dropdown.
    interpolation_geometry_s32:    s32;   // Edited by the dropdown.
    interpolation_wrapping :=      false; // Edited by the checkbox.

    output_type_s32: s32 = xx Output_Type.RESAMPLED_ARRAY; // Edited by the dropdown.

    time_view_period: float;
    time_view_playing := true;
    time_view_current_time: float64;

    // The actual long-term color data:
    color_keyframes: [..] Augmented_Keyframe;
}

#scope_file

Augmented_Keyframe :: struct {
    using base: Color_Keyframe;

    active:   bool;  // Is this the active keyframe, i.e. the one that the user's mouse pointer is over?
    active_t: float; // For color animation; interpolates up and down.

    dragging_t:      float;  // For color animation; interpolates up and down.
    color_picking_t: float;  // If the color picker is editing this guy, then 1, else 0.

    pos_x: float;  // X position in screen coordinates for this frame.
}

COLOR_SPACE_NAMES :: string.["RGB", "HSV", "Oklab"];
INTERPOLATION_GEOMETRY_NAMES :: string.["Linear", "Quadric", "Hermite"];
OUTPUT_TYPE_NAMES :: string.["Resampled Array", "Source Keyframes"];

Output_Type :: enum {
    RESAMPLED_ARRAY  :: 0;
    SOURCE_KEYFRAMES :: 1;
}

#import "Sort";


// Here is a stub just to test the polymorphic stuff here to maek sure it compiles.
// Would be nice to make the compiler do this automatically.
error_detection_stub :: () {
    array: [] *Color_Keyframe;

    generate_color_samples(array, .{}, .[]); // This calls interpolate_one_sample and make_temp_colors, so we don't need to call those here.
}
