Solution_Timeline :: struct {
    keys: [..] u8;
    playhead: s64;
    caret: s64;
    anchor: s64;
    dirty: bool;
}

timeline_free :: (timeline: *Solution_Timeline) {
    array_free(timeline.keys);
    timeline.* = .{};
}

timeline_key_valid :: (key: u8) -> bool {
    // Z is an editor transport action, not a forward step.
    return contains("UDLRCXFV0123456789_", key);
}

timeline_key_is_character_switch :: (key: u8) -> bool {
    return key == #char "C" || (key >= #char "0" && key <= #char "9");
}

timeline_key_is_undoable :: (key: u8) -> bool {
    return key != #char "_" && !timeline_key_is_character_switch(key);
}

timeline_parse :: (source: string) -> (keys: string, error: string) {
    keys, error := expand_send(source);
    if error.count return "", error;
    for *key: keys {
        if key.* >= #char "a" && key.* <= #char "z" key.* -= #char "a" - #char "A";
        if key.* == #char "B" key.* = #char "_";
        if !timeline_key_valid(key.*) {
            free(keys);
            return "", "Use U/D/L/R, C/X/F/V, digit keys, or _ waits. Use Undo to rewind.";
        }
    }
    return keys, "";
}

timeline_load :: (timeline: *Solution_Timeline, source: string) -> string {
    keys, error := timeline_parse(source);
    defer free(keys);
    if error.count return error;
    timeline_free(timeline);
    for key: keys {
        array_add(*timeline.keys, key);
    }
    return "";
}

timeline_selection :: (timeline: *Solution_Timeline) -> (first: s64, last: s64) {
    return max(0, min(timeline.keys.count, min(timeline.caret, timeline.anchor))),
           max(0, min(timeline.keys.count, max(timeline.caret, timeline.anchor)));
}

timeline_move_caret :: (timeline: *Solution_Timeline, position: s64, select := false) {
    timeline.caret = max(0, min(timeline.keys.count, position));
    if !select timeline.anchor = timeline.caret;
}

timeline_caret_is_executed :: (timeline: *Solution_Timeline) -> bool {
    return timeline.caret < timeline.playhead || (timeline.caret == timeline.playhead && timeline.anchor < timeline.playhead);
}

timeline_select_side :: (timeline: *Solution_Timeline) {
    past := timeline_caret_is_executed(timeline);
    first := ifx past then 0 else timeline.playhead;
    last := ifx past then timeline.playhead else timeline.keys.count;
    timeline_move_caret(timeline, first);
    timeline_move_caret(timeline, last, select = true);
}

timeline_erase :: (timeline: *Solution_Timeline, first: s64, last: s64) -> bool {
    if first < 0 || last > timeline.keys.count || first >= last return false;
    removed_executed := max(0, min(last, timeline.playhead) - min(first, timeline.playhead));
    for i: last..timeline.keys.count-1 {
        timeline.keys[i - (last - first)] = timeline.keys[i];
    }
    timeline.keys.count -= last - first;
    timeline.playhead -= removed_executed;
    timeline_move_caret(timeline, first);
    timeline.dirty = true;
    return true;
}

timeline_delete :: (timeline: *Solution_Timeline, backwards := false) {
    first, last := timeline_selection(timeline);
    if first == last {
        if backwards first -= 1;
        else last += 1;
    }
    timeline_erase(timeline, first, last);
}

timeline_insert :: (timeline: *Solution_Timeline, keys: string) -> string {
    first, last := timeline_selection(timeline);
    if first < timeline.playhead return "Executed steps can be deleted. Move the caret to Future to insert new steps.";
    if keys.count > SEND_KEY_LIMIT - (timeline.keys.count - (last - first)) {
        return tprint("A solution can contain at most % steps.", SEND_KEY_LIMIT);
    }
    for key: keys if !timeline_key_valid(key) return "Unsupported solution key.";
    if !keys.count return "";
    timeline_erase(timeline, first, last);
    for key: keys {
        array_insert_at(*timeline.keys, key, first + it_index);
    }
    timeline_move_caret(timeline, first + keys.count);
    timeline.dirty = true;
    return "";
}

timeline_record :: (timeline: *Solution_Timeline, key: u8) -> bool {
    if !timeline_key_valid(key) || timeline.keys.count == SEND_KEY_LIMIT return false;
    array_insert_at(*timeline.keys, key, timeline.playhead);
    if timeline.caret >= timeline.playhead timeline.caret += 1;
    if timeline.anchor >= timeline.playhead timeline.anchor += 1;
    timeline.playhead += 1;
    timeline.dirty = true;
    return true;
}

timeline_advance :: (timeline: *Solution_Timeline, direction: s64) {
    following := timeline.caret == timeline.playhead && timeline.anchor == timeline.playhead;
    timeline.playhead = max(0, min(timeline.keys.count, timeline.playhead + direction));
    if following {
        timeline.caret = timeline.playhead;
        timeline.anchor = timeline.playhead;
    }
}

// A physical Z undoes one game action, skipping character switches and waits.
timeline_apply_game_undo :: (timeline: *Solution_Timeline) -> bool {
    position := timeline.playhead;
    while position > 0 {
        position -= 1;
        if !timeline_key_is_undoable(timeline.keys[position]) continue;
        timeline_advance(timeline, position - timeline.playhead);
        return true;
    }
    return false; // There is no known game action to undo in this session.
}

timeline_clear_executed :: (timeline: *Solution_Timeline) {
    count := timeline.playhead;
    timeline_erase(timeline, 0, count);
    timeline.caret = 0;
    timeline.anchor = 0;
}

timeline_serialize :: (timeline: *Solution_Timeline) -> string {
    result: String_Builder;
    defer free_buffers(*result);
    for key: timeline.keys {
        // Digit cells are literal character switches, never a suffix repetition.
        digit := key >= #char "0" && key <= #char "9";
        if digit append(*result, " ");
        append(*result, key);
        if digit append(*result, " ");
    }
    return builder_to_string(*result);
}

#scope_file
#import "Basic";
#import "String";
