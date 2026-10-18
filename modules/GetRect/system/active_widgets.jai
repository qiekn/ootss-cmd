active_widgets_per_frame_update :: () {
    // Swap(*active_widgets_current_frame, *active_widgets_next_frame);
    // active_widgets_next_frame.count = 0;
}

active_widget_add :: (widget: *Active_Widget, is_grabbing := false) {
    if active_widget != widget {
        active_widget_deactivate_all(widget);
        active_widget = widget;
    }

    active_widget_is_grabbing = is_grabbing;
    // array_add(*active_widgets_next_frame, widget);
}

active_widget_remove :: (widget: *Active_Widget) {
    if widget == active_widget  {
        deactivate(widget);
        active_widget = null;
    }
}

active_widget_deactivate_all :: (except: *Active_Widget = null) {
    if active_widget && (active_widget != except) {
        if array_find(state_stack, active_widget) return; // This widget is what we are doing right now ... don't reset it!
        deactivate(active_widget);
        active_widget = null;
    }
}

#scope_module
Active_Widget :: struct {
    widget_type: Type;

    deactivate\         _proc: (w: *Active_Widget);
    serial_events\      _proc: (w: *Active_Widget, events: [] Event);
    check_for_activation_proc: (w: *Active_Widget, event: Event) -> bool;

    last_getrect_frame: u64;
    is_on_state_stack := false;

    last_update_time: float64;
    cosmetic_dt:      float32;

    window: Window_Type;
    exists_on_occluder: *Active_Widget; // For example, if we are drawn on a Subwindow, this is assigned to that subwindow, so that we know we aren't occluded by queries that hit that subwindow.
}

// @Threadsafety?
active_widget: *Active_Widget;
active_widget_is_grabbing := false;

state_stack: [..] *Active_Widget;  // These are all states we are currently drawing. If someone is on this stack, and someone else does a deactivate, don't deactivate that guy...! For example, Dropdown drawing a Button.

gave_widget_location_error := false;

start_using_state :: (widget: *Active_Widget) {
    window := context.getrect_current_window;
    assert(window != WT.INVALID_WINDOW);
    widget.window = window;
    widget.exists_on_occluder = occluder_being_drawn;

    if (widget.last_getrect_frame == current_getrect_frame) && !drawing_popups && !disable_the_duplicate_widget_error { // If drawing popups, we give ourselves license to get the same widget again.
        // For now we report an error. Later we can think about making this actually work in most cases
        // (just by remembering the highest integer identifier per widget, and generating a new widget
        // using an incremented identifier).

        if !gave_widget_location_error {
            gave_widget_location_error = true;

            log(WIDGET_ERROR_MESSAGE);

            if context.stack_trace {
                log("Stack trace:\n");

                log_stack_trace(context.stack_trace);
            } else {
                log("(Compile with stack trace nodes enabled to get a trace of the location of this call.)\n");
            }
        }
    }

    // :CosmeticTimer
    // last_update_time is here to compute cosmetic_dt. cosmetic_dt is different from the per-frame dt,
    // since a button may appear and disappear due to the user switching between screens, etc -- a button
    // may not be rendered for a long time, then come back. We want its cosmetic timers to tick during
    // that time, so if it's fading out, it isn't still lit 30 seconds later. But rather than ticking
    // every widget, for now we just compute cosmetic_dt when it comes back, and use this really long
    // dt to compute effects. Maybe that is not the best idea and we should instead tick everyone.
    // We'll see how it goes.  -jblow, 21 December 2021.

    if widget.last_update_time {
        widget.cosmetic_dt = cast(float) (current_time - widget.last_update_time);
    } else {
        widget.cosmetic_dt = current_dt;
    }

    widget.last_update_time = current_time;

    widget.last_getrect_frame = current_getrect_frame;
    array_add(*state_stack, widget);
    widget.is_on_state_stack = true;
}

stop_using_state :: (widget: *Active_Widget) {
    old := pop(*state_stack);
    widget.is_on_state_stack = false;
    assert(old == widget);

    // A weird place to reset the tooltip I guess? But we want to make sure it's before
    // we return back to the user, but after we query for OVER state.
    if !state_stack  current_tooltip = .{};
}

#scope_module

disable_the_duplicate_widget_error := false;

#scope_file

deactivate :: (widget: *Active_Widget) {
    proc := widget.deactivate_proc;
    if proc proc(widget);
}

// active_widgets_current_frame: [..] *Active_Widget;
// active_widgets_next_frame:    [..] *Active_Widget;


WIDGET_ERROR_MESSAGE :: #string DONE
Error: A widget was drawn, more than once during a frame,
from the same point in the source code. This is not legal.
The most common ways for this to happen are to draw a widget
(for example a button) inside a 'for' loop
or inside a wrapper function.
Because GetRect identifies widgets by the location
where they are drawn (in order to make it easy
to write simple code that draws complex UIs
without having to instantiate and remember a bunch of objects),
in these cases these look like the same widget to GetRect,
even though you mean them to be different ones.

If you are drawing inside a 'for' loop, the simplest fix
is to pass the 'identifier' argument when drawing the widget,
and assign it to it_index or some other unique integer
inside the loop. If drawing inside a wrapper function,
you can pass the #caller_location of your wrapper function
to the 'loc' argument in widget drawing.

Another way to cause this problem is by not consistently calling
GetRect.ui_per_frame_update().
DONE
