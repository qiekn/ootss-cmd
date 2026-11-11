draw_popups :: () {
    pointer_end_frame();  // We don't have a better place to put this right now!
    
    quick_sort(popups, (x, y) => ifx x.z == y.z then x.serial-y.serial else x.z-y.z);

    to_raise: *Subwindow_State;
    for subwindows if it.wants_draw {
        draw_subwindow(it);
        it.wants_draw = false;

        if it.wants_a_raise {
            to_raise = it;
            it.wants_a_raise = false;
        }
    }

    if to_raise raise(to_raise);

    drawing_popups = true;
    for * popups {
        it.proc(it.data);
    }
    drawing_popups = false;

    // There is no explicit GetRect end-of-frame call; this is the closest thing.
    // Once we get here, we are done drawing widgets, at least in theory!

    // If the left mouse button was pressed, and no widget ever intercepted it,
    // and we aren't active, deselect active widgets.

    if (mouse_button_left_state & .START) && !some_widget_received_left_mouse_button {
        if !(active_widget && active_widget_is_grabbing) {
            active_widget_deactivate_all();
        }
    }
}

#scope_module

drawing_popups := false;

Popup_Info :: struct {
    proc:   (*void) -> ();
    data:   *void;
    z:      s32;
    serial: s32;
}

add_popup :: (proc: (*void) -> (), data: *void, z: s32) {
    info := array_add(*popups);
    info.proc   = proc;
    info.data   = data;
    info.z      = z;
    info.serial = cast(s32)popups.count;
}

popups_per_frame_update :: () {
    popups.count  = 0;
}

// Subwindows and popups are kinda the same, except, the subwindows
// always draw before any of the popups. We could just do depth sorting
// to make that go, but, we also want to reorder subwindows + bring them
// to the top, etc, and it seems better just to put everything together.

popups:     [..] Popup_Info;        // This gets reset every frame. Popups must be recreated every frame to stay around.
subwindows: [..] *Subwindow_State;  // This is persistent because we maintain the sort order.
