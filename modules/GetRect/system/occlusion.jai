//
// Occlusion is one-frame delayed, and the thesis is
// that this is probably fine for practical purposes.
// It's considered an acceptable tradeoff for the
// simplicity we gain by not having to delay knowing the
// response to a button press, etc. That said, there is
// definitely room for a more-deferred version of this API
// if that makes more sense later.
//

occlusion_per_frame_update :: () {
    swap(*occlusions_current_frame, *occlusions_next_frame);
    occlusions_next_frame.count = 0;

    quick_sort(occlusions_current_frame, x => -x.serial);

    occluder_under_the_cursor = null;
}

occlusion_per_window_update :: (window: Window_Type) {
    x, y := mouse_x_float, mouse_y_float;
    for * occlusions_current_frame {
        if it.widget.window != window continue;
        if is_inside(x, y, it.rect) {
            occluder_under_the_cursor = it.widget;
            break;
        }
    }
}

occluder_start :: (widget: *Active_Widget, rect: Rect) {
    record := array_add(*occlusions_next_frame);
    record.serial = cast(s32)(occlusions_next_frame.count);
    record.rect   = rect;
    record.widget = widget;

    occluder_being_drawn = widget;
    array_add(*occluders_being_drawn_stack, widget);
}

occluder_finish :: (widget: *Active_Widget, rect := Rect.{}) {
    assert(occluders_being_drawn_stack.count > 0, "occluder_finish called without preceding occluder_start call.");
    assert(peek(occluders_being_drawn_stack) == widget, "occluder_finish widget does not match occluder_start.");
    pop(*occluders_being_drawn_stack);
    occluder_being_drawn = ifx occluders_being_drawn_stack then peek(occluders_being_drawn_stack);

    if rect.w {
        for * < occlusions_next_frame {
            if it.widget == widget {
                it.rect = rect;
                return;
            }
        }
        assert(false, "Could not find this widget on occlusions_next_frame (which is where it should be if occluder_start was called!)");
    }
}

events_occluded :: (widget_if_querying_outside_of_render_time: *Active_Widget = null) -> bool {
    // @Cleanup: We can probably simplify this now.

    if !occluder_under_the_cursor                   return false;
    if occluder_under_the_cursor.is_on_state_stack  return false;

    w := widget_if_querying_outside_of_render_time;
    if w && (occluder_under_the_cursor == w.exists_on_occluder) return false;

    return occluder_under_the_cursor.last_getrect_frame != current_getrect_frame;
}

Occlusion_Record :: struct {
    serial: s32;   // Used to compare occlusions against each other. Higher serial occludes lower serial.
    rect:   Rect;
    widget: *Active_Widget;
}

occlusions_current_frame: [..] Occlusion_Record;
occlusions_next_frame:    [..] Occlusion_Record;

occluder_being_drawn: *Active_Widget;

#scope_file

occluders_being_drawn_stack: [..] *Active_Widget;

#import "Sort";
