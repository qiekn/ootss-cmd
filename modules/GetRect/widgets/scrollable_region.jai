begin_scrollable_region :: (r: Rect, theme: *Scrollable_Region_Theme = null, identifier: s64 = 0, loc := #caller_location) -> (state: *Scrollable_Region_State, inside: Rect) {
    if !theme  theme = *default_overall_theme.scrollable_region_theme;

    rth := render_target_height;

    margin_x := floor(theme.horizontal_margin_size * rth + .5);
    margin_y := floor(theme.vertical_margin_size   * rth + .5);

    if !(theme.margin_flags & .Horizontal)  margin_x = 0;
    if !(theme.margin_flags & .Vertical)    margin_y = 0;

    scrollbar_size := floor(theme.scrollbar_size * rth + .5);
    is_vertical := !(theme.direction & .HORIZONTAL); // @TODO Eventually we should support both at once, but for now it's one or the other.

    bar_rect, content_area: Rect = ---;
    if is_vertical
        bar_rect, content_area = cut_right(r, scrollbar_size);
    else
        bar_rect, content_area = cut_bottom(r, scrollbar_size);

    inside := content_area;
    inside.x += margin_x;
    inside.w -= margin_x*2;
    inside.y += margin_y;
    inside.h -= margin_y*2;

    // Draw the background quad.
    draw_procs.set_shader_for_color(true);
    rounded_rectangle(content_area, theme.region_background.shape, theme.region_background.color, theme.region_background.frame_color);

    push_scissor(inside);

    hash  := get_hash(loc, identifier);
    state := find_or_create_state(Scrollable_Region_State, hash);
    defer stop_using_state(state);

    state.theme      = theme.*;
    state.outer_rect = r;
    state.inner_rect = inside;
    state.bar_rect   = bar_rect;

    return state, inside;
}

end_scrollable_region :: (state: *Scrollable_Region_State, max_x: float, min_y: float, scroll_value: *float) {
    theme := *state.theme;
    is_vertical := !(theme.direction & .HORIZONTAL); // @TODO Eventually we should support both at once, but for now it's one or the other.

    pop_scissor();

    inner := state.inner_rect;
    bar   := state.bar_rect;
    status_r   := get_status_flags(inner, ignore=.LEFT_CLICK|.TOOLTIP);
    status_bar := get_status_flags(bar, ignore=.TOOLTIP);

    scroll_content_size := ifx is_vertical
                           then max(inner.y + inner.h + scroll_value.* - min_y, inner.h)
                           else max(max_x - (inner.x - scroll_value.*), inner.w);
    if scroll_content_size <= 0.0  return;
    max_scroll_value := scroll_content_size - ifx is_vertical inner.h else inner.w;

    bar_size := ifx is_vertical then bar.w else bar.h;
    b := floor(bar_size * theme.nib_margin + .5);
    min_nib_size := bar_size * theme.minimum_nib_size;

    // @Incomplete: Control whether bar draws with a style flag.
    draw_bar := true; // bar.w > 2*b && bar.h > 2*b;
    if draw_bar {
        background_color := theme.scrollbar_background.color;
        draw_procs.set_shader_for_color(true);

        trench_rect := bar;
        // trench_rect := get_rect(bar.x + b, bar.y + b, bar.w - 2*b, bar.h - 2*b);
        {
            rounded_rectangle(bar, theme.scrollbar_background.shape, background_color, theme.scrollbar_background.frame_color); // :FrameColor

            // p0, p1, p2, p3 = get_quad(trench_rect);
            // draw_procs.immediate_quad(p0, p1, p2, p3, whiten(trench_color, 0.1));
        }

        nib_rect: Rect = ---;
        nib_size: float = ---;
        if is_vertical {
            nib_size = min(max(trench_rect.h * (inner.h / scroll_content_size), min_nib_size), trench_rect.h);
            scroll_percent := 0.0;
            if max_scroll_value > 0.0  scroll_percent = scroll_value.* / max_scroll_value;
            nib_top := lerp(trench_rect.y + trench_rect.h, trench_rect.y + nib_size, scroll_percent);

            nib_rect = get_rect(trench_rect.x + b, nib_top - nib_size, trench_rect.w - 2*b, nib_size);
        } else {
            nib_size = min(max(trench_rect.w * (inner.w / scroll_content_size), min_nib_size), trench_rect.w);
            scroll_percent := 0.0;
            if max_scroll_value > 0.0  scroll_percent = scroll_value.* / max_scroll_value;
            nib_left := lerp(trench_rect.x, trench_rect.x + trench_rect.w - nib_size, scroll_percent);

            nib_rect = get_rect(nib_left, trench_rect.y + b, nib_size, trench_rect.h - 2*b);
        }
        nib_status := get_status_flags(nib_rect, ignore=.TOOLTIP);

        changed := cast(bool)(nib_status & .PRESSED);
        if changed {
            active_widget_deactivate_all();
        }

        if state.dragging  nib_status |= Status_Flags.OVER | .DOWN; // Even if we go outside the rect, while dragging, have it stay in OVER state.

        start_using_state(*state.nib_state); // We do this so that the scrollbar nib animates its colors.

        update_production_value_button(nib_rect, changed, *state.nib_state, nib_status, *theme.scrollbar_nib_theme);

        nib_surface_color, nib_frame_color, nib_frame_thickness := get_colors_and_thickness_for_button(*theme.scrollbar_nib_theme, *state.nib_state);

        trench_status := get_status_flags(trench_rect, ignore=.TOOLTIP);

        teleporting := false;
        if (nib_status & .OVER) && (mouse_button_left_state & .START) {
            state.dragging    = true;
            state.teleporting = false;
            active_widget_add(state, true);
        } else if (trench_status & .OVER) && (mouse_button_left_state & .START) {
            state.teleporting = true;
            state.dragging    = false;
            active_widget_remove(state);
        }

        if !(mouse_button_left_state & .DOWN) {
            state.dragging    = false;
            state.teleporting = false;
            active_widget_remove(state);
        }

       if is_vertical {
            if nib_size < trench_rect.h {
                if state.teleporting {
                    // Jump the scroll nib to the cursor.
                    p := (trench_rect.y + trench_rect.h - mouse_y_float - nib_size * 0.5) / (trench_rect.h - nib_size);
                    scroll_value.* = lerp(0.0, max_scroll_value, p);
                }

                if state.dragging {
                    // Drag the scroll nib.
                    scroll_value.* -= mouse_delta_y_float * max_scroll_value / (trench_rect.h - nib_size);
                }
            }
        } else {
            if nib_size < trench_rect.w {
                if state.teleporting {
                    // Jump the scroll nib to the cursor.
                    p := 1.0 - (trench_rect.x + trench_rect.w - mouse_x_float - nib_size * 0.5) / (trench_rect.w - nib_size);
                    scroll_value.* = lerp(0.0, max_scroll_value, p);
                }

                if state.dragging {
                    // Drag the scroll nib.
                    scroll_value.* += mouse_delta_x_float * max_scroll_value / (trench_rect.w - nib_size);
                }
            }
        }

        {
            rounded_rectangle(nib_rect, theme.scrollbar_nib_theme.rectangle_shape, nib_surface_color, nib_frame_color, frame_thickness_override=nib_frame_thickness); // :FrameColor
        }

        draw_procs.immediate_flush();

        stop_using_state(*state.nib_state);
    }

    mouse_wheel_horizontal_only := shift_key_state & .DOWN != 0; // So user can hold shift to only scroll horizontal regions (useful when regions are nested).

    if ((status_r & .OVER) || (draw_bar && (status_bar & .OVER))) && mouse_delta_z && last_mouse_wheel_frame != current_getrect_frame && (!is_vertical || !mouse_wheel_horizontal_only) {
        // Scroll with the mouse wheel.
        dz := mouse_delta_z * (theme.mouse_wheel_increment * render_target_height);
        scroll_value.* -= dz;

        // @TODO There's really no situation where a scrollwheel input should be acted on by more than one widget, so GetRect should have a mechanism to control
        //       which overlapped widget gets the scrollwheel, and make sure only that widget does.
        //       Here we make sure only the inner scrollable region uses the scrollwheel, but that does not account for e.g. multiline_text_inputs.
        last_mouse_wheel_frame = current_getrect_frame;
    }

    Clamp(scroll_value, 0.0, max_scroll_value);
}

Scrollable_Region_Flags :: enum_flags u8 {
    VERTICAL :: 1;
    HORIZONTAL :: 2;
}

Scrollable_Region_Theme :: struct {
    direction := Scrollable_Region_Flags.VERTICAL;

    horizontal_margin_size := 0.005;   // Relative to render target height.
    vertical_margin_size   := 0.005;   // Relative to render target height. It's intentional that this is width and not height, because by default youwant the sizes of the two margins to be controllable relative to each other, not messed up by random aspect ratio changes.

    margin_flags := Margin.Horizontal | .Vertical;

    scrollbar_size := 0.03;            // Relative to render target height. This indicates the width for a vertical scrollbar, or height for a horizontal scrollbar.

    minimum_nib_size := 1.0;           // Relative to scrollbar size. 1.0 means it will not get shorter than the breadth of the scrollbar.
    nib_margin := 0.10;                // Margin between trench and nib, relative to scrollbar size.

    scrollbar_nib_theme: Button_Theme;
    scrollbar_nib_theme.surface_color                    = Vector4.{.55, .05, .55, 1};
    scrollbar_nib_theme.surface_color_over               = Vector4.{.70, .05, .70, 1};
    scrollbar_nib_theme.surface_color_flash = Vector4.{.90, .50, .90, 1};
    scrollbar_nib_theme.surface_color_down               = Vector4.{.85, .15, .85, 1};
    scrollbar_nib_theme.rectangle_shape.frame_thickness_type = .RELATIVE_TO_WIDTH;
    scrollbar_nib_theme.rectangle_shape.roundedness_type     = .RELATIVE_TO_WIDTH;
    scrollbar_nib_theme.rectangle_shape.roundedness          = .24;
    scrollbar_nib_theme.enable_variable_frame_thickness = true;
    scrollbar_nib_theme.frame_thickness_over = .1;
    scrollbar_nib_theme.frame_thickness_down = .12;
    scrollbar_nib_theme.frame_thickness_flash = .15;
    scrollbar_nib_theme.frame_color                    = Vector4.{.65, .25, .65, 1};
    scrollbar_nib_theme.frame_color_over               = Vector4.{.72, .45, .72, 1};
    scrollbar_nib_theme.frame_color_flash = Vector4.{.99, .90, .99, 1};
    scrollbar_nib_theme.frame_color_down               = Vector4.{.88, .60, .88, 1};

    region_background: Background_Theme;
    region_background.shape.rounding_flags       = Rectangle_Shape.Rounding_Flags.NORTHWEST | .SOUTHWEST;
    region_background.shape.frame_thickness_type = .ABSOLUTE_FROM_GLOBAL;
    region_background.shape.roundedness_type     = .RELATIVE_TO_WIDTH;
    region_background.shape.roundedness          = .06; // Scrollable regions are bound to be pretty wide, so default this to a kinda small value
    region_background.frame_color                = Vector4.{0.35, 0.28, 0.40, 1.0};
    region_background.color                      = Vector4.{0.08, 0.013, 0.10, 1.0};

    scrollbar_background: Background_Theme;
    scrollbar_background.shape.rounding_flags       = Rectangle_Shape.Rounding_Flags.NORTHEAST | .SOUTHEAST;
    scrollbar_background.shape.frame_thickness_type = .ABSOLUTE_FROM_GLOBAL;
    scrollbar_background.shape.roundedness_type     = .RELATIVE_TO_WIDTH;
    scrollbar_background.frame_color                = Vector4.{0.30, 0.22, 0.34, 1.0};
    scrollbar_background.color                      = Vector4.{0.17, 0.015, 0.20, 1.0};

    mouse_wheel_increment := 0.0004;  // Distance to scroll per tick of the mouse wheel, relative to render target height.
}

Scrollable_Region_State :: struct #type_info_none {
    #as using widget: Active_Widget;

    nib_state:  Button_State;

    outer_rect: Rect;
    inner_rect: Rect;
    bar_rect:   Rect;

    dragging    := false;
    teleporting := false;

    theme: Scrollable_Region_Theme;  // Here so the user doesn't have to manually re-pass this to end_scrollable_region.
}

#scope_file

last_mouse_wheel_frame: u64;
