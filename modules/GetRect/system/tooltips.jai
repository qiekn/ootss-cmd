Tooltip :: struct {
    text: string;

    pointer_data: *void;
    int_data:     s64;
}

tooltip :: (text := "", pointer_data: *void = null, int_data := 0) {  // 'text' must live at least until the end of the frame when you query the tooltip!
    t := *current_tooltip;
    t.text         = text;
    t.pointer_data = pointer_data;
    t.int_data     = int_data;
}

get_active_tooltip :: () -> Tooltip {
    return active_tooltip;
}
