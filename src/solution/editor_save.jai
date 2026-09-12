Editor_After_Save :: enum { NONE; CLOSE; OPEN; EXIT_PROGRAM; }
EDITOR_CUSTOM_NAME_LIMIT :: 128;
Editor_Save_Prompt :: struct {
    active: bool;
    after: Editor_After_Save;
    name: Console_State;
    select_all: bool;
    high_surrogate: u32;
    message: string;
    error: bool;
    overwrite: bool;
    overwrite_name, overwrite_solution: string;
    next_level: string;
    next_custom: bool;
    was_minimized, had_text_focus: bool;
    button_down: s64 = -1;
}
editor_save_prompt: Editor_Save_Prompt;

editor_clear_save_prompt :: () {
    console_deinit(*editor_save_prompt.name);
    free(editor_save_prompt.message);
    free(editor_save_prompt.overwrite_name);
    free(editor_save_prompt.overwrite_solution);
    free(editor_save_prompt.next_level);
    editor_save_prompt = .{};
}

editor_save_prompt_message :: (message: string, error := false) {
    free(editor_save_prompt.message);
    editor_save_prompt.message = copy_string(message);
    editor_save_prompt.error = error;
}

editor_begin_save_prompt :: (after: Editor_After_Save = .NONE, next_level: string = "", next_custom := false) {
    if !editor.open return;
    if editor_save_prompt.active {
        if after != .NONE {
            next := copy_string(next_level);
            free(editor_save_prompt.next_level);
            editor_save_prompt.next_level = next;
            editor_save_prompt.next_custom = next_custom;
            editor_save_prompt.after = after;
        }
        editor_window_update();
        editor_focus_text();
        return;
    }
    editor_pause();
    if editor.transport.held.scan || editor.transport.time_held return;
    editor_view_cancel_drag();
    editor_save_prompt.active = true;
    editor_save_prompt.after = after;
    editor_save_prompt.was_minimized = editor_view.minimized;
    editor_save_prompt.had_text_focus = Win.GetForegroundWindow() == editor_window_handle();
    editor_save_prompt.next_level = copy_string(next_level);
    editor_save_prompt.next_custom = next_custom;
    console_set_input(*editor_save_prompt.name, editor.record.name);
    editor_save_prompt.select_all = editor.custom && editor.record.name.count > 0;
    if editor.custom editor_save_prompt_message("Choose a name, then confirm Save. This input is stored separately from level solutions.");
    else editor_save_prompt_message("Confirm Save to replace this level's saved solution.");
    editor_set_minimized(false);
    editor_window_update();
    editor_focus_text();
}

editor_finish_save_prompt :: (cancel := false) {
    after := editor_save_prompt.after;
    next_level := copy_string(editor_save_prompt.next_level);
    defer free(next_level);
    next_custom := editor_save_prompt.next_custom;
    was_minimized := editor_save_prompt.was_minimized;
    had_text_focus := editor_save_prompt.had_text_focus;
    editor_clear_save_prompt();
    if cancel || after == .NONE {
        editor_set_minimized(was_minimized);
        if had_text_focus editor_focus_text();
        else editor_focus_game();
        if cancel editor_set_status("Save canceled. Your edits are still in the editor.");
        return;
    }
    editor_close(discard = true);
    if after == .OPEN editor_open_solution(next_level, next_custom);
    if after == .EXIT_PROGRAM overlay.quit_requested = true;
}

editor_confirm_save :: () -> bool {
    if !editor.open || !editor_save_prompt.active return false;
    name := ifx editor.custom then trim(console_input(*editor_save_prompt.name)) else editor.record.name;
    if editor.custom {
        error := editor_custom_name_error(name);
        if error.count { editor_save_prompt_message(error, true); return false; }
    }
    filename := ifx editor.custom then CUSTOM_INPUTS_FILE else SOLUTIONS_FILE;
    database: Solutions_Database;
    defer solutions_free(*database);
    error := ifx editor.custom then custom_inputs_load(*database) else solutions_load(*database);
    if error.count { editor_save_prompt_message(error, true); return false; }
    index := solution_find_name(*database, name, ignore_case = true);
    if index >= 0 {
        saved := database.entries[index];
        different_name := editor.custom && !equal_nocase(editor.record.name, saved.name);
        changed_on_disk := saved.solution != editor.record.solution;
        confirmed := editor_save_prompt.overwrite && equal_nocase(editor_save_prompt.overwrite_name, name) &&
                     editor_save_prompt.overwrite_solution == saved.solution;
        if (different_name || changed_on_disk) && !confirmed {
            free(editor_save_prompt.overwrite_name);
            free(editor_save_prompt.overwrite_solution);
            editor_save_prompt.overwrite = true;
            editor_save_prompt.overwrite_name = copy_string(name);
            editor_save_prompt.overwrite_solution = copy_string(saved.solution);
            editor_save_prompt_message(ifx different_name then tprint("'%': this name already exists. Confirm Overwrite to replace it.", name)
                                       else "The saved solution changed on disk. Confirm Overwrite to replace it.", true);
            return false;
        }
    } else {
        entry := solution_record_copy(editor.record);
        free(entry.name);
        entry.name = copy_string(name);
        array_add(*database.entries, entry);
        index = database.entries.count - 1;
    }
    entry := *database.entries[index];
    if editor.custom {
        entry.position = .[0, 0, 0];
        free(entry.area);
        entry.area = copy_string("none");
    }
    // Reload and update just this record, preserving other inputs and their latest notes.
    free(entry.solution);
    entry.solution = timeline_serialize(*editor.timeline);
    error = solutions_write(*database, filename);
    if error.count { editor_save_prompt_message(error, true); return false; }
    updated := solution_record_copy(entry.*);
    solution_record_free(*editor.record);
    editor.record = updated;
    editor.timeline.dirty = false;
    editor_set_status(tprint("Saved % steps as '%' in %.", editor.timeline.keys.count, editor.record.name, filename));
    editor_finish_save_prompt();
    return true;
}

editor_request_program_exit :: () -> bool {
    if !editor.open || !editor.timeline.dirty return true;
    editor_begin_save_prompt(.EXIT_PROGRAM);
    return false;
}

editor_save_prompt_action :: (index: s64) {
    if index == 0 editor_confirm_save();
    else if index == 1 && editor_save_prompt.after != .NONE editor_finish_save_prompt(); // Explicit Discard.
    else editor_finish_save_prompt(cancel = true);
}

editor_custom_name_error :: (name: string) -> string {
    if !name.count return "Enter a name before saving.";
    if name.count > EDITOR_CUSTOM_NAME_LIMIT return tprint("Use a name of at most % UTF-8 bytes.", EDITOR_CUSTOM_NAME_LIMIT);
    if equal_nocase(name, "temp") || equal_nocase(name, "solution") return "Choose a name other than temp or solution.";
    for c: name {
        if c >= 128 || (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") ||
           (c >= #char "0" && c <= #char "9") || c == #char "_" || c == #char "-" || c == #char "." continue;
        return "Use letters, numbers, Unicode characters, underscores, hyphens or dots; no spaces.";
    }
    return "";
}

editor_save_prompt_changed :: () {
    if editor_save_prompt.overwrite || editor_save_prompt.error {
        editor_save_prompt_message("Choose a name, then confirm Save. This input is stored separately from level solutions.");
    }
    editor_save_prompt.overwrite = false;
    editor_save_prompt.error = false;
    editor_save_prompt.high_surrogate = 0;
}

editor_save_prompt_replace_selection :: () {
    if !editor_save_prompt.select_all return;
    console_set_input(*editor_save_prompt.name, "");
    editor_save_prompt.select_all = false;
}

editor_save_prompt_key :: (event: Editor_Event) {
    if event.key == 0x1b || (event.alt && event.key == 0x73) { editor_finish_save_prompt(cancel = true); return; }
    if event.key == 0x0d { if !event.repeat editor_confirm_save(); return; }
    if !editor.custom return;
    field := *editor_save_prompt.name;
    if event.ctrl && event.key == #char "A" { editor_save_prompt.select_all = true; return; }
    if (event.ctrl && event.key == #char "V") || (event.shift && event.key == 0x2d) {
        if event.repeat return;
        text, error := clipboard_read_text(editor_window_handle());
        defer free(text);
        if error.count { editor_save_prompt_message(error, true); return; }
        editor_save_prompt_replace_selection();
        console_paste_text(field, text);
        editor_save_prompt_changed();
        return;
    }
    if event.key == 8 || event.key == 0x2e {
        if editor_save_prompt.select_all editor_save_prompt_replace_selection();
        else if event.ctrl && event.key == 0x2e console_delete_next_word(field);
        else if event.key == 8 console_backspace(field);
        else console_delete(field);
        editor_save_prompt_changed();
    } else if event.ctrl && event.key == #char "W" {
        if editor_save_prompt.select_all editor_save_prompt_replace_selection();
        else console_delete_previous_word(field);
        editor_save_prompt_changed();
    } else if event.ctrl && event.key == #char "U" {
        if editor_save_prompt.select_all editor_save_prompt_replace_selection();
        else console_clear_before_cursor(field);
        editor_save_prompt_changed();
    } else if event.key == 0x25 || event.key == 0x27 || event.key == 0x24 || event.key == 0x23 {
        if event.key == 0x25 field.cursor = ifx editor_save_prompt.select_all then 0 else console_previous_character(field);
        if event.key == 0x27 field.cursor = ifx editor_save_prompt.select_all then field.input.count else console_next_character(field);
        if event.key == 0x24 field.cursor = 0;
        if event.key == 0x23 field.cursor = field.input.count;
        editor_save_prompt.select_all = false;
    }
}

editor_save_prompt_text :: (character: u32) {
    if !editor.custom || character < 32 || character == 127 return;
    if character >= 0xd800 && character <= 0xdbff { editor_save_prompt.high_surrogate = character; return; }
    if character >= 0xdc00 && character <= 0xdfff {
        if !editor_save_prompt.high_surrogate return;
        character = 0x10000 + ((editor_save_prompt.high_surrogate - 0xd800) << 10) + character - 0xdc00;
    }
    editor_save_prompt_replace_selection();
    console_insert_character(*editor_save_prompt.name, character);
    editor_save_prompt_changed();
}

#scope_file
#import "Basic";
#import "String";
Win :: #import "Windows";
