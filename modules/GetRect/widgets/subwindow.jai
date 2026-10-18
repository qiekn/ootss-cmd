// @Incomplete stuff:
//
// A way to know when inputs are not handled.
//
// Draw fringe.
//
// Deallocate Subwindows if they go cold for some amount of time; remove from subwindows array.
//
// Ability to set a subregion that constrains the subwindows.
// (What about PROPORTIONAL windows, do they stop growing etc?)
// Flag determining whether subwindows are wholly contained in the subregion, or whether they have some minimum containment of the draggable title area.
// Make it so the user doesn't have to worry about the lifetime of title_text. For now, it must live until after draw_popups is called.


// 'info' is a *Subwindow_Info that must remain valid and untouched until after draw_popups() is called, including all members such as the title_text.
add_subwindow :: (info: *Subwindow_Info, theme: *Subwindow_Theme = null, identifier: s64 = 0, loc := #caller_location, z: s32 = 0) -> (state: *Subwindow_State) {
    hash  := get_hash(loc, identifier);
    state, created := find_or_create_state(Subwindow_State, hash, start_using=false);  // We don't want to start using the state, because the order in which this happens determines occlusion ... but we will render in a different order than the order in which add_subwindow() is called. So we only want to start using the state when we actually draw.

    if created array_add(*subwindows, state);

    if !theme  theme = *default_overall_theme.subwindow_theme;
    state.theme = theme.*;

    state.hash = hash;
    state.info = info;

    state.wants_draw = true;

    if info.wants_a_raise {
        state.wants_a_raise = true;
        info.wants_a_raise = false;
    }

    return state;
}


draw_subwindow :: (state: *Subwindow_State) {
    start_using_state(state);
    current_subwindow = state;
    defer {
        stop_using_state(state);
        current_subwindow = null;
    }

    info  := state.info;
    theme := *state.theme;

    full_rect := info.rect;

    occluder_start(state, full_rect);

    title_bar_height := get_title_bar_height(theme);

    r := info.rect;
    if (state.render_target_width != render_target_width) || (state.render_target_height != render_target_height) {
        if info.fixed_aspect_ratio > 0 {
            // For now we resize the new rect based on the old one...
            old_title_bar_height := get_title_bar_height(theme, state.render_target_height);
            remainder, old_client_rect := cut_top(r, old_title_bar_height);
            aspect := info.fixed_aspect_ratio;
            new_client_rect := rescale(old_client_rect, state.render_target_width, state.render_target_height);

            new_client_rect.h = new_client_rect.w / aspect;  // For now width is always authoritative, which might not be that useful or good in some cases...
            new_client_rect.h += title_bar_height;
            r = new_client_rect;
        } else {
            r = rescale(info.rect, state.render_target_width, state.render_target_height);
        }

        if state.dragging {
            state.dragging_offset = rescale(state.dragging_offset, render_target_width, render_target_height);
            state.dragging_start  = rescale(state.dragging_start,  render_target_width, render_target_height);
            state.dragging_last   = rescale(state.dragging_last,   render_target_width, render_target_height);
        }

        state.render_target_width  = render_target_width;
        state.render_target_height = render_target_height;

        full_rect = r;
    }

    if state.dragging {
        if active_widget != state             state.dragging = 0;
        if !(mouse_button_left_state & .DOWN) state.dragging = 0;

        if state.dragging {
            update_dragging(state, *full_rect);
            r = full_rect; // @Cleanup: Probably should not have both of these variables.
        }

        else active_widget_remove(state);
    }

    title_bar_rect, content_area := cut_top(full_rect, title_bar_height);
    state.title_bar_rect = title_bar_rect;

    if content_area.h < 0  content_area.h = 0;

    state.content_rect = content_area;

    frame_pixels := 0.0;
    // Draw the background quad.
    // For now, we match the roundedness to that of the title bar.
    // (This will help us do fringe that matches + makes sense, too).
    if content_area.h >= 0 {  // We may end up in the negative if we get weird input parameters...!
        b := *theme.title_bar.rectangle_shape;
        radius_pixels := get_roundedness_for_rect(title_bar_rect, b.roundedness_type, b.roundedness, global_rounding_radius_in_pixels, .5);

        draw_procs.set_shader_for_color(true);

        modified := theme.region_background.shape;
        modified.roundedness_type = .ABSOLUTE_FROM_THEME_FIELD;
        modified.roundedness      = radius_pixels;

        frame_pixels = rounded_rectangle(content_area, modified, theme.region_background.color, theme.region_background.frame_color);
    } else {
        content_area.h = 0; // So we can push the scissor... which we pop later anyways.
    }

    push_scissor(expand(content_area, -frame_pixels));

    draw := state.info.draw;
    if draw  draw(state, content_area, state.info.user_data);

    if !some_widget_received_left_mouse_button && (mouse_button_left_state & .START) {
        flags := get_status_flags(full_rect, ignore=.LEFT_CLICK);
        if flags & .OVER // User clicked somewhere on window background.
            state.wants_a_raise = true;
    }

    rth := render_target_height;
    resize_rect: Rect;
    {
        // Draw the resize corner before popping the scissor, please!
        resize_w := floor(theme.resize_rect_size * rth + .5);

        resize_rect.x = r.x + r.w - resize_w;
        resize_rect.y = r.y;
        resize_rect.w = resize_w;
        resize_rect.h = resize_w;

        if theme.subwindow_flags & .VISIBLE_RESIZE_CORNER {
            draw_procs.set_shader_for_color(false);
            draw_resize_corner(theme, state, resize_rect);
            draw_procs.immediate_flush();
        }
    }

    pop_scissor();

    active_pointer: Pointer_Image;
    active_pointer_set := false;

    if state.dragging {
        if active_widget != state  state.dragging = 0;
        if !state.dragging  active_widget_remove(state);
    }


    //
    // :TitleBarOverride
    // Test dragging before drawing the title bar, because we want our drag rectangles
    // to override the title bar (and tell it that the title bar will not be activated
    // if we are over a drag rect).
    //
    occlusion := full_rect;

    if state.draw_proc_adjusted_y {
        state.draw_proc_adjusted_y = false;

        dy := state.draw_proc_new_y1 - content_area.y;
        if dy {
            full_rect.y += dy;
            full_rect.h -= dy;
        }
        
        /*
        old_top := content_area.y + content_area.h;
        
        new_h := old_top - state.draw_proc_new_y1;
        new_y := old_top - new_h;

        occlusion.y = new_y;
        occlusion.h = new_h;
*/
    }
    
    pressed_flags: Resize_Controls;
    over_flags:    Resize_Controls;

    if (theme.resize_controls & .ENWS) && !(active_widget && active_widget_is_grabbing) && !events_occluded() && !some_widget_received_left_mouse_button {
        // @TODO We checked some_widget_received_left_mouse_button here because we don't want to be in the situation of having simultaneously
        // activated a widget and started dragging; this way only the widget activation occurs.  However, since the mouse pointer where
        // this overlap occured will have been the resize pointer (or w/e) this isn't great; the user would expect the resize operation, not
        // the widget activation.  It would be better if this resize stuff happened before we call the draw callback.

        check_resize_rect :: (r: Rect, flag: Resize_Controls, over: *Resize_Controls, pressed: *Resize_Controls) {
            status := get_status_flags(r);
            if status & .PRESSED then pressed.* |= flag;
            if status & .OVER    then over.*    |= flag;
        }

        hmargin := theme.drag_corner_margin * rth;
        vmargin := theme.drag_corner_margin * rth;

        Clamp(*hmargin, 0, r.w * (1/3.0));
        Clamp(*vmargin, 0, r.h * (1/3.0));

        pressed_h, pressed_v: bool;
        over_h, over_v: bool;
        if theme.resize_controls & .EAST {
            i := theme.drag_intrusion_east * rth;
            e := theme.drag_extrusion_east * rth;

            if e + i > 0 {
                s := get_rect(r.x + r.w - i, r.y, e+i, r.h);
                flag := maybe_diagonalize(.EAST, r.y, r.h, vmargin, .SOUTH, .NORTH, mouse_y_float);
                flag &= theme.resize_controls;
                check_resize_rect(s, flag, *over_flags, *pressed_flags);
                occlusion.w += e;
            }
        }

        if theme.resize_controls & .WEST {
            i := theme.drag_intrusion_west * rth;
            e := theme.drag_extrusion_west * rth;

            if e + i > 0 {
                s := get_rect(r.x - e, r.y, e+i, r.h);
                flag := maybe_diagonalize(.WEST, r.y, r.h, vmargin, .SOUTH, .NORTH, mouse_y_float);
                flag &= theme.resize_controls;
                check_resize_rect(s, flag, *over_flags, *pressed_flags);
                occlusion.x -= e;
                occlusion.w += e;
            }
        }

        if theme.resize_controls & .SOUTH {
            i := theme.drag_intrusion_south * rth;
            e := theme.drag_extrusion_south * rth;

            if e + i > 0 {
                s := get_rect(r.x, r.y - e, r.w, e+i);
                flag := maybe_diagonalize(.SOUTH, r.x, r.w, hmargin, .WEST, .EAST, mouse_x_float);
                flag &= theme.resize_controls;
                check_resize_rect(s, flag, *over_flags, *pressed_flags);
                occlusion.y -= e;
                occlusion.h += e;
            }
        }

        if theme.resize_controls & .NORTH {
            i := theme.drag_intrusion_north * rth;
            e := theme.drag_extrusion_north * rth;

            if e + i > 0 {
                s := get_rect(r.x, r.y + r.h - i, r.w, e+i);
                flag := maybe_diagonalize(.NORTH, r.x, r.w, hmargin, .WEST, .EAST, mouse_x_float);
                flag &= theme.resize_controls;
                check_resize_rect(s, flag, *over_flags, *pressed_flags);
                occlusion.h += e;
            }
        }

        if over_flags {
            active_pointer     = get_pointer_from_resize_control(over_flags);
            active_pointer_set = true;

            if pressed_flags {
                start_resizing(state, full_rect);
                state.dragging_resize_control = adjust_resize_control(theme, state, pressed_flags);
            }
        }

        if theme.resize_controls & .CORNER_SE {
            if !over_flags {  // Let the directional edges take priority here... maybe it should be the other way around.
                status := get_status_flags(resize_rect);
                if status & .PRESSED {
                    start_resizing(state, full_rect);
                    state.dragging_resize_control = adjust_resize_control(theme, state, .CORNER_SE);
                } else if status & .OVER {
                    flags := adjust_resize_control(theme, state, .CORNER_SE);
                    active_pointer     = get_pointer_from_resize_control(flags);
                    active_pointer_set = true;
                }
            }
        }
    }


    draw_bar := theme.subwindow_flags & .TITLE_BAR != 0; // bar.w > 2*b && bar.h > 2*b;
    if draw_bar {
        // background_color := theme.title_bar.color;
        sub_hash_title := get_hash(#location(), 0);
        title_button_hash := combine_hashes(state.hash, sub_hash_title);

        close_button_pressed := false;
        close_button_state: *Button_State;

        inside_close_button  := false;
        resize_related_disable := pressed_flags || over_flags;  // :TitleBarOverride  If we changed the mouse pointer image because we are over a drag rect, we by no means want to press or even highlight the button, because we are telling the user that a mouse click will drag the subwindow!

        c: Rect;  // For the close button.
        title_bar_text_rect := state.title_bar_rect;
        if theme.subwindow_flags & .CLOSE_BUTTON {
            t := *state.title_bar_rect;
            w := t.h * theme.close_button_width;
            h := t.h * theme.close_button_height;
            margin := t.h * theme.close_button_right_margin;

            c.x = t.x + t.w - w - margin;
            c.y = t.y + (t.h - h) * .5;
            c.w = w;
            c.h = h;
            title_bar_text_rect.w -= (w + margin);

            if is_inside(mouse_x_float, mouse_y_float, c) {
                inside_close_button = true;
            }
        }

        title_bar_pressed, title_bar_button := button(state.title_bar_rect, "", *theme.title_bar, xx,no_check title_button_hash, disable_press=inside_close_button, disable_over=resize_related_disable);
        core_draw_button_label(title_bar_text_rect, info.title_text, title_bar_button, *theme.title_bar);

        if theme.subwindow_flags & .CLOSE_BUTTON {
            sub_hash_close := get_hash(#location(), 0);
            close_button_hash := combine_hashes(state.hash, sub_hash_close);
            close_button_pressed, close_button_state = button(c, "", *theme.close_button, xx,no_check close_button_hash);

            // Draw the X on the close button.
            x_height := c.h * theme.close_button_height * theme.close_button_x_height;
            x_rect := c;
            x_rect.x += (c.w - x_height)  * .5;
            x_rect.y += (c.h - x_height) * .5;
            x_rect.w  = x_height;
            x_rect.h  = x_height;

            b := x_height * 0.05;  // Half-thickness of each arm of the X.
            p0, p1, p2, p3 := get_quad(x_rect);
            v02 := unit_vector(p2 - p0);
            v13 := unit_vector(p3 - p1);
            w02 := v2(-v02.y, v02.x);
            w13 := v2(-v13.y, v13.x);

            bt := *theme.close_button;
            color := bt.text_color;

            // @Refactor @Robustness: Convert to over_factor    which in button.jai I think is some nonlienar warp of this?
            color = lerp(color, bt.text_color_over,    close_button_state.over_effect_t);
            // @Refactor @Robustness: Convert to pressed_factor which in button.jai I think is some nonlienar warp of this?
            color = lerp(color, bt.text_color_pressed, close_button_state.down_effect_t);

            strut := w02 * b;
            draw_procs.set_shader_for_color(false);
            draw_procs.immediate_quad(p0 - strut, p2 - strut, p2 + strut, p0 + strut, color);
            strut  = w13 * b;
            draw_procs.immediate_quad(p1 - strut, p3 - strut, p3 + strut, p1 + strut, color);
            draw_procs.immediate_flush();
        }

        if close_button_pressed {
            state.info.open = false;
            close_button_state.pressed = false;
            // NOTE(Berk): We need to set the button to not being pressed when we close the window or else when the window reopens the button will think that it is still pressed.
            // This will cause it to steal focus from other widgets if we wanted to, for example, open the window focused on some other widget (like a search bar, which is how I realized this had to be here.)
        } else if title_bar_pressed {
            state.dragging                = .TITLE;
            state.dragging_start          = v2(mouse_x_float, mouse_y_float);
            state.dragging_last           = state.dragging_start;
            state.dragging_offset         = v2(mouse_x_float - r.x, mouse_y_float - r.y);
            state.dragging_resize_control = 0;
            active_widget_add(state, true);

            state.wants_a_raise = true;
        }
    }


    if state.dragging {
        hv := state.dragging_resize_control;
        if hv {
            active_pointer     = get_pointer_from_resize_control(state.dragging_resize_control);
        } else {
            // This is a title bar drag.
            active_pointer     = .DRAGGING_FREE;
        }

        active_pointer_set = true;
    }

    if active_pointer_set  draw_procs.set_pointer_image(active_pointer, state);

    occluder_finish(state, occlusion);

    state.info.rect = full_rect;
}

subwindow_rect_from_content_rect :: (content_rect: Rect, theme: *Subwindow_Theme, override_render_target_height : s32 = 0) -> Rect {
    if !(theme.subwindow_flags & .TITLE_BAR)
        return content_rect;

    result := content_rect;
    result.h += get_title_bar_height(theme, override_render_target_height);
    return result;
}

get_title_bar_height :: (theme: *Subwindow_Theme, override_render_target_height : s32 = 0) -> float {
    rth := ifx override_render_target_height else render_target_height;
    return ifx theme.subwindow_flags & .TITLE_BAR
           then floor(theme.title_bar_size * rth + .5);
}

maybe_diagonalize :: (flag: Resize_Controls, x: float, w: float, margin: float, low: Resize_Controls, high: Resize_Controls, mouse: float) -> Resize_Controls {
    //
    // If the mouse is within a certain distance of the beginning or end of that side
    // of the window, make the motion diagonal instead of lateral, by or-ing the
    // specified flag.
    //
    result := flag;
    if mouse < x + margin           result |= low;
    else if mouse > x + w - margin  result |= high;

    return result;
}

raise :: (state: *Subwindow_State) {
    array_ordered_remove_by_value(*subwindows, state);
    array_add(*subwindows, state);
}

update_dragging :: (state: *Subwindow_State, full: *Rect) {
    base_x := full.x + state.dragging_offset.x;
    base_y := full.y + state.dragging_offset.y;

    dx := mouse_x_float - base_x;
    dy := mouse_y_float - base_y;

    if dx || dy {
        if state.dragging == .TITLE {
            full.x += dx;
            full.y += dy;
        } else if state.dragging == .RESIZE {
            f := *state.content_rect;

            rtw := render_target_width;
            theme := *state.theme;

            flags := state.dragging_resize_control;
            if flags & .CORNER_SE {
                // Remap it so it's easier to deal with here.
                flags |= .SE;
            }

            if !(flags & .NS) dy = 0;
            if !(flags & .EW) dx = 0;

            f_denom := ifx f.w then f.w else 1.0;

            aspect := state.resizing_aspect;   // Whatever the aspect was at the start of resize.
            if state.info.fixed_aspect_ratio > 0  aspect = state.info.fixed_aspect_ratio; // In case the user changed it.

            rth := render_target_height;

            min_w := floor(theme.resize_minimum_size.x * rth + .5);
            min_h := floor(theme.resize_minimum_size.y * rth + .5);

            new_w := f.w;
            if flags & .WEST new_w -= dx;
            else             new_w += dx;

            new_h := f.h;
            if flags & .NORTH new_h += dy;
            else              new_h -= dy;

            if flags & .PROPORTIONAL {
                if flags & .EW {
                    denom := aspect;
                    if !denom denom = 1;
                    if new_w < min_w  new_w = min_w;
                    new_h = new_w / denom;
                    if new_h < 1  new_h = 1;
                } else if flags & .NS {
                    if new_h < min_h  new_h = min_h;
                    new_w = new_h * aspect;
                    if new_w < 1  new_w = 1;
                } else {
                    // Dot the relative motion against the diagonal from upper-left to lower-right.
                    // Then just use the dx from that and compute the corresponding dy.
                    delta := Vector2.{dx, dy};
                    dir   := unit_vector(Vector2.{f.w, -f.h});

                    aligned := dot_product(dir, delta) * dir;

                    new_w = f.w + aligned.x;
                    if new_w < min_w  new_w = min_w;

                    denom := aspect;
                    if !denom denom = 1;
                    new_h = new_w / denom;
                    if new_h < 1  new_h = 1;
                }
            } else {
                if !(ui_get_button_state(.SHIFT) & .DOWN) { // Hardcoded SHIFT key for now; we can add a keybind later.
                    if flags & .SNAP_EW {
                        hmargin := theme.resize_snap_margin * rth;
                        if abs(new_w - state.info.snap_to_size.x) < hmargin
                            new_w = state.info.snap_to_size.x;
                    }
                    
                    if flags & .SNAP_NS {
                        vmargin := theme.resize_snap_margin * rth;
                        if abs(new_h - state.info.snap_to_size.y) < vmargin
                            new_h = state.info.snap_to_size.y;
                    }
                }
                
                if new_w < min_w  new_w = min_w;
                if new_h < min_h  new_h = min_h;
            }

            actual_dx := new_w - f.w;
            if flags & .WEST {
                f.x -= actual_dx;
            } else {
                state.dragging_offset.x += actual_dx;
            }

            f.w = new_w;

            // We need to adjust y, not by the original dy, but by
            // the clamped value... math error here could be pernicious
            // in some way.

            actual_dy := new_h - f.h;
            if !(flags & .NORTH) {  // Instead of checking SOUTH, we check !NORTH, so that windows grow downward if dragging by the sides causes them to grow vertically.
                f.y -= actual_dy;
            } else {
                state.dragging_offset.y += actual_dy;
            }

            f.h = new_h;

            my_full := f.*;
            my_full.h += state.title_bar_rect.h;
            full.* = my_full;
        }
    }

    state.dragging_last   = v2(mouse_x_float, mouse_y_float);
}


start_resizing :: (state: *Subwindow_State, f: Rect) {
    state.dragging = .RESIZE;
    state.dragging_start  = v2(mouse_x_float, mouse_y_float);
    state.dragging_last   = state.dragging_start;

    state.wants_a_raise = true;

    state.resizing_aspect = get_aspect(state.content_rect);

    state.dragging_offset = v2(mouse_x_float - f.x, mouse_y_float - f.y);

    active_widget_add(state, true);
}

adjust_resize_control :: (theme: *Subwindow_Theme, state: *Subwindow_State, f: Resize_Controls) -> Resize_Controls {
    flags := f;
    if (theme.resize_controls & .PROPORTIONAL) || (state.info.fixed_aspect_ratio > 0) || ui_get_button_state(.SHIFT) {  // Hardcoded SHIFT key for now; we can add a keybind later.
        flags |= .PROPORTIONAL;
    }

    flags |= theme.resize_controls & .SNAP; // Always include these flags from theme.

    return flags;
}

get_pointer_from_resize_control :: (flags: Resize_Controls) -> Pointer_Image {
    if flags & .CORNER_SE {
        if flags & .PROPORTIONAL return .DRAGGING_NW_SE;
        return .DRAGGING_FREE;
    } else if flags & .EW {
        // We handle all the corners here.
        masked := flags & .ENWS;
        if (masked == .NE) || (masked == .SW) {
            return .DRAGGING_NE_SW;
        } else if (masked == .NW) || (masked == .SE) {
            return .DRAGGING_NW_SE;
        }

        return .DRAGGING_HORIZONTAL;
    } else if flags & .NS {
        return .DRAGGING_VERTICAL;
    } else {
        return .LOCKED;
    }
}

get_aspect :: (r: Rect) -> float {
    denom := r.h;
    if !denom denom = 1;
    aspect := r.w / denom;
    return aspect;
}

rescale :: (r: Rect, old_w: s32, old_h: s32) -> Rect {
    // old_w and old_h are the dimensions of the render target before.
    // We scale based on their dimensions relative to the current render target.
    new_w := render_target_width;
    new_h := render_target_height;

    if (!old_w) || (!old_h) || (!new_w) || (!new_h) {
        return r;  // Can't do anything with a zero-sized window.
    }

    ux := r.x / cast(float) old_w;
    uy := r.y / cast(float) old_h;
    uw := r.w / cast(float) old_w;
    uh := r.h / cast(float) old_h;

    s: Rect;
    s.x = ux * new_w;
    s.y = uy * new_h;
    s.w = uw * new_w;
    s.h = uh * new_h;

    return s;
}

rescale :: (v: Vector2, old_w: s32, old_h: s32) -> Vector2 {
    // old_w and old_h are the dimensions of the render target before.
    // We scale based on their dimensions relative to the current render target.
    new_w := render_target_width;
    new_h := render_target_height;

    if (!old_w) || (!old_h) || (!new_w) || (!new_h) {
        return v;  // Can't do anything with a zero-sized window.
    }

    ux := v.x / cast(float) old_w;
    uy := v.y / cast(float) old_h;

    w: Vector2;
    w.x = ux * new_w;
    w.y = uy * new_h;

    return w;
}

draw_resize_corner :: (theme: *Subwindow_Theme, state: *Subwindow_State, r: Rect) {

    rth := render_target_height;
    b := theme.resize_corner_line_thickness * r.w;
    if b < 1  b = 1;

    inset_h := theme.drag_intrusion_east  * rth;
    inset_v := theme.drag_intrusion_south * rth;

    junk, tmp    := cut_bottom(r, inset_v);
    hline, junk2 := cut_bottom(tmp, b);
    junk, hline   = cut_right (hline, inset_h * .5);  // @Robustness: Actually need to clip this against rounded corners?

    junk, tmp     = cut_right (r, inset_h);
    vline, junk3 := cut_right (tmp, b);
    junk, vline   = cut_bottom(vline, inset_v * .5);   // @Robustness: Actually need to clip this against rounded corners?
    color := theme.resize_corner_color;

    p0, p1, p2, p3 := get_quad(hline);
    draw_procs.immediate_quad(p0, p1, p2, p3, color);

    p0, p1, p2, p3  = get_quad(vline);
    draw_procs.immediate_quad(p0, p1, p2, p3, color);
}

draw_proc_adjust_y1 :: (state: *Subwindow_State, new_y1: float) {
    state.draw_proc_adjusted_y = true;
    state.draw_proc_new_y1 = new_y1;
}


Subwindow_Flags :: enum_flags u16 {
    TITLE_BAR    ::          0x1;
    CLOSE_BUTTON ::          0x2;
    FRINGE       ::          0x4;
    VISIBLE_RESIZE_CORNER :: 0x8;
}

Resize_Controls :: enum_flags u16 {
    EAST         :: 0x1;
    NORTH        :: 0x2;
    WEST         :: 0x4;
    SOUTH        :: 0x8;
    CORNER_SE    :: 0x10; // Do a free-resize handle in the southeast corner.
    PROPORTIONAL :: 0x20; // Force all resizes to maintain the aspect ratio of the client area (the rect not including the title bar).
    SNAP_EW      :: 0x40; // When resizing, snap width to snap_to_size.x
    SNAP_NS      :: 0x80; // When resizing, snap height to snap_to_size.y

    NS   :: NORTH | SOUTH;
    EW   :: EAST  | WEST;

    NE   :: NORTH | EAST;
    NW   :: NORTH | WEST;
    SE   :: SOUTH | EAST;
    SW   :: SOUTH | WEST;

    ENWS :: NS | EW;

    SNAP :: SNAP_EW | SNAP_NS;
}


Subwindow_Theme :: struct {
    title_bar_size := 0.03;            // Relative to render target height.
    title_bar: Button_Theme;

    title_bar.surface_color                        = .{.165, .233, .379, 1};
    title_bar.surface_color_over                   = .{.183, .311, .484, 1};
    title_bar.surface_color_flash                  = .{.413, .695, .840, 1};
    title_bar.surface_color_down                   = .{.317, .538, .650, 1};
    title_bar.rectangle_shape.rounding_flags       = .NORTH;
    title_bar.rectangle_shape.frame_thickness_type = .ABSOLUTE_FROM_GLOBAL;
    title_bar.rectangle_shape.roundedness_type     = .RELATIVE_TO_WIDTH;
    title_bar.rectangle_shape.roundedness          = .24;
    title_bar.enable_variable_frame_thickness      = true;

    title_bar.frame_thickness_over                 = .1;
    title_bar.frame_thickness_down                 = .12;
    title_bar.frame_thickness_flash                = .15;
    title_bar.frame_color                          = .{.321, .374, .500, 1};
    title_bar.frame_color_over                     = .{.437, .491, .618, 1};
    title_bar.frame_color_flash                    = .{.734, .772, .861, 1};
    title_bar.frame_color_down                     = .{.537, .584, .695, 1};

    close_button: Button_Theme;
    close_button.surface_color                     = .{.70, .25, .08, 1};
    close_button.surface_color_over                = .{.99, .15, .08, 1};
    close_button.surface_color_flash               = .{.90, .90, .90, 1};
    close_button.surface_color_down                = .{.95, .65, .05, 1};

    close_button.text_color                        = .{.07, .07, .07, 1};
    close_button.text_color_over                   = .{.90, .90, .40, 1};
    close_button.text_color_pressed                = .{.99, .99, .99, 1};


    close_button_width        := 1.2;  // Relative to the title bar height.
    close_button_height       := 0.8;  // Relative to the title bar height.
    close_button_right_margin := 0.4;  // Relative to the title bar height.
    close_button_x_height     := 0.7;  // Relative to the close button height.

    region_background: Background_Theme;
    region_background.shape.rounding_flags       = Rectangle_Shape.Rounding_Flags.SOUTHEAST | .SOUTHWEST;
    region_background.shape.frame_thickness_type = .ABSOLUTE_FROM_GLOBAL;
    region_background.shape.roundedness_type     = .RELATIVE_TO_WIDTH;
    region_background.shape.roundedness          = .06; // Scrollable regions are bound to be pretty wide, so default this to a kinda small value
    region_background.frame_color                = .{0.35, 0.28, 0.40, 1.0};
    region_background.color                      = .{0.08, 0.013, 0.10, 1.0};

    horizontal_margin_size := 0.005;   // Relative to render target height.
    vertical_margin_size   := 0.005;   // Relative to render target height. It's intentional that this is width and not height, because by default youwant the sizes of the two margins to be controllable relative to each other, not messed up by random aspect ratio changes.

    subwindow_flags := Subwindow_Flags.TITLE_BAR | .FRINGE | .CLOSE_BUTTON | .VISIBLE_RESIZE_CORNER;
    fringe_color := Vector4.{0, 0, 0, .2};
    fringe_thickness := 0.004; // Relative to render target height.

    resize_corner_line_thickness := 0.025;  // Relative to the size of the resize corner (it is a square region).
    resize_corner_color          := Vector4.{.4, .4, .4, 1};

    // These drag strip intrusion/extrusion parameters control how far into and out
    // of the main rect you want these (invisible) drag strips to extend.
    drag_intrusion_east  := 0.006; // Relative to render target height.
    drag_extrusion_east  := 0.008;
    drag_intrusion_west  := 0.006;
    drag_extrusion_west  := 0.008;
    drag_intrusion_north := 0.002;  // Up here people often want to click on the title bar, so make it easier.
    drag_extrusion_north := 0.011;
    drag_intrusion_south := 0.006;
    drag_extrusion_south := 0.008;

    drag_corner_margin   := 0.05; // Relative to render target height. Make it easier to hit corners by considering anything within this distance of the corner be diagonal instead of straight. Maxxes out at 1/3 the width or height, for smaller windows, to enable the user to still drag by picking the middle.

    resize_controls := Resize_Controls.CORNER_SE | .EAST | .NORTH | .WEST | .SOUTH;

    resize_rect_size := 0.05;   // Relative to render target height.
    resize_minimum_size := Vector2.{.08, .08};  // Relative to render target height (not width and height, just height, for both).
    resize_snap_margin := 0.02; // Relative to render target height.
}

Subwindow_Info :: struct {
    // This is the struct used by client programs to indicate what to draw.
    // Subwindows can be arranged in any order, by the user's raising one in front
    // of another; it's nice if the client program doesn't have to manage this itself,
    // so we let the system do it.

    rect: Rect;
    title_text: string;
    fixed_aspect_ratio := -1.0;  // This is w / h.  Set this to something > 0 in order to force the Subwindow to maintain a fixed aspect ratio. The height of 'rect' will be modified based on the width.
    snap_to_size: Vector2; // With the relevant Resize_Controls set, the subwindow will snap to this size when the user is drag-resizing it.

    user_data: *void;    // This is passed to draw().
    draw: (state: *Subwindow_State, content_rect: Rect, user_data: *void);  // We call this to draw your window.

    open := true;

    wants_a_raise := false;      // wants_a_raise will be reset by the system after it raises the Subwindow_State.
}

Subwindow_State :: struct #type_info_none {
    #as using widget: Active_Widget;

    base: Button_State;

    title_bar_rect: Rect;
    content_rect:   Rect;

    info: *Subwindow_Info;

    wants_draw    := false;
    wants_a_raise := false;

    hash:           u64;

    render_target_width:  s32;  // What these were last time we did stuff. Used for rescaling.
    render_target_height: s32;

    dragging: enum u8 { TITLE :: 0x1; RESIZE :: 0x2; };

    dragging_start:  Vector2;
    dragging_last:   Vector2;

    dragging_offset: Vector2;  // Offset from the lower-right corner of the window at which we started dragging.

    dragging_resize_control: Resize_Controls;  // This can be HORIZONTAL, VERTICAL, or both, and possibly PROPORTIONAL (in case there is a way to choose proportional or non-proportional resize with the same widget... which there currently is not (yet?))
    resizing_aspect: float;

    theme: Subwindow_Theme; // So that we know what they passed to begin_subwindow, and don't require them to pass it again in end_subwindow.

    draw_proc_adjusted_y := false;
    draw_proc_new_y1     := 0.0;
}


