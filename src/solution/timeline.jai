Solution_Timeline :: struct {
    keys: [..] u8;
    playhead: s64;
    caret: s64;
    anchor: s64;
    dirty: bool;
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
    array_free(timeline.keys);
    timeline.* = .{};
    for key: keys array_add(*timeline.keys, key);
    return "";
}

timeline_selection :: (timeline: *Solution_Timeline) -> (first: s64, last: s64) {
    return max(timeline.playhead, min(timeline.caret, timeline.anchor)),
           max(timeline.playhead, max(timeline.caret, timeline.anchor));
}

timeline_move_caret :: (timeline: *Solution_Timeline, position: s64, select := false) {
    timeline.caret = max(timeline.playhead, min(timeline.keys.count, position));
    if !select timeline.anchor = timeline.caret;
}

timeline_erase :: (timeline: *Solution_Timeline, first: s64, last: s64) -> bool {
    if first < timeline.playhead || first < 0 || last > timeline.keys.count || first >= last return false;
    for i: last..timeline.keys.count-1 timeline.keys[i - (last - first)] = timeline.keys[i];
    timeline.keys.count -= last - first;
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
    if keys.count > SEND_KEY_LIMIT - (timeline.keys.count - (last - first)) {
        return tprint("A solution can contain at most % steps.", SEND_KEY_LIMIT);
    }
    for key: keys if !timeline_key_valid(key) return "Unsupported solution key.";
    if !keys.count return "";
    timeline_erase(timeline, first, last);
    for key: keys array_insert_at(*timeline.keys, key, first + it_index);
    timeline_move_caret(timeline, first + keys.count);
    timeline.dirty = true;
    return "";
}

timeline_record :: (timeline: *Solution_Timeline, key: u8) -> bool {
    if !timeline_key_valid(key) || timeline.keys.count == SEND_KEY_LIMIT return false;
    array_insert_at(*timeline.keys, key, timeline.playhead);
    timeline.playhead += 1;
    timeline.caret += 1;
    timeline.anchor += 1;
    timeline.dirty = true;
    return true;
}

timeline_advance :: (timeline: *Solution_Timeline, direction: s64) {
    timeline.playhead = max(0, min(timeline.keys.count, timeline.playhead + direction));
    timeline.caret = max(timeline.caret, timeline.playhead);
    timeline.anchor = max(timeline.anchor, timeline.playhead);
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
    for i: count..timeline.keys.count-1 timeline.keys[i - count] = timeline.keys[i];
    timeline.keys.count -= count;
    timeline.playhead = 0;
    timeline.caret = 0;
    timeline.anchor = 0;
    if count > 0 timeline.dirty = true;
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
