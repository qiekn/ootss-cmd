#!/usr/bin/env jai

// Real Windows file notifications, isolated configuration and memory-only key state.
// No game writes, injected input, visible windows or screenshots.
#run {
    set_build_options_dc(.{do_output = false});
    set_working_directory(tprint("%/..", #filepath));
    directory = copy_string(tprint(".build/config-reload-%", Win.GetCurrentProcessId()));
    defer free(directory);
    check(make_directory_if_it_does_not_exist(directory, true), "Create an isolated test directory.");
    defer App.game_font_cache_deinit();
    defer App.hud_deinit();
    check_replacement();
    check_shortcut_install();
    check_notifications();
    check_fonts();
    print("PASS: % config hot-reload checks.\n", checks);
}

checks, applied: s64;
directory: string;
keys: App.Shortcut_State;
reject_apply: bool;

check :: (value: bool, message: string) {
    checks += 1;
    if !value { compiler_report(message); assert(value); }
}

apply_config :: (state: *App.Console_State, next: *App.Console_Config) -> string {
    if reject_apply return "Simulated shortcut installation failure.";
    App.console_config_replace(state, next, *keys);
    App.hud_apply_config(state.config.hud);
    applied += 1;
    return "";
}

check_replacement :: () {
    state: App.Console_State;
    defer App.console_deinit(*state);
    error := App.console_config_parse(*state.config, "alpha=back; map M=old; freecam_speed=20;");
    check(!error.count, "Parse the original configuration.");
    App.console_alias_store(*state.temporary_aliases, "alpha", "move -z");
    App.console_set_input(*state, "alpha draft");
    state.cursor = 3;
    array_add(*state.history, copy_string("previous command"));
    array_add(*state.completion.matches, copy_string("old completion"));
    state.show_subtitles = true;
    state.scroll = 3;
    state.scroll_to_line = 2;
    state.reveal_output = false;
    state.pending_action = .NONE;
    local_keys: App.Shortcut_State = .{enabled = true, queue_count = 1};
    local_keys.down[0x4d] = true;
    local_keys.consumed[0x4d] = true;
    next: App.Console_Config;
    defer App.console_config_free(*next);
    error = App.console_config_parse(*next, "alpha=changed; noremap N=new; game_path=elsewhere; show_startup_blow=false;");
    check(!error.count, "Parse a complete replacement.");
    changed := App.console_config_replace(*state, *next, *local_keys);
    check(changed && state.config.game_path == "elsewhere", "Replacing config reports a game-path change.");
    check(next.aliases.count == 0 && next.shortcuts.count == 0 && !next.game_path.count, "Move ownership out of the parsed config.");
    check(state.config.freecam_speed == 12, "Removing a setting restores its default.");
    check(!state.config.show_startup_blow && state.pending_action == .NONE, "Replacing startup preference never dispatches a command.");
    check(App.console_alias_lookup(*state, "ALPHA").command == "move -z", "Temporary aliases keep priority.");
    check(App.console_input(*state) == "alpha draft" && state.cursor == 3 && state.history[0] == "previous command", "Preserve input, caret and history.");
    check(!state.completion.matches.count, "Drop completion results from the old config.");
    check(!local_keys.queue_count && local_keys.down[0x4d] && local_keys.consumed[0x4d], "Cancel old indexed requests but preserve physical key state.");
    consumed, triggered := App.shortcut_filter_key(*local_keys, state.config.shortcuts, 0x4d, false, false, null);
    check(consumed && !triggered && !local_keys.down[0x4d] && !local_keys.consumed[0x4d], "Swallow the old noremap key-up after changing its binding.");
    App.console_config_message(*state, "config.rc reloaded.");
    check(state.show_subtitles && state.scroll == 3 && state.scroll_to_line == 2 && !state.reveal_output, "Reload feedback does not dismiss subtitles or change scroll.");
    check(state.lines[state.lines.count - 1].text == "config.rc reloaded.", "Keep feedback in full console history.");
    App.command_unalias(*state, "alpha");
    check(App.console_alias_lookup(*state, "alpha").command == "changed", "Removing a temporary alias reveals the freshly loaded definition.");
}

// Each test pumps the real main-loop interface. Returned errors are temporary;
// copy them before another frame resets scratch storage.
pump :: (reload: *App.Config_Reload, duration: float64) -> (changes: s64, errors: s64, last_error: string) {
    changes, errors: s64;
    last_error: string;
    deadline := seconds_since_init() + duration;
    while seconds_since_init() < deadline {
        auto_release_temp();
        changed, error := App.config_reload_update(reload, seconds_since_init());
        if changed changes += 1;
        if error.count {
            errors += 1;
            free(last_error);
            last_error = copy_string(error);
        }
        sleep_milliseconds(10);
    }
    return changes, errors, last_error;
}

check_shortcut_install :: () {
    // The test process has no target game; the hook passes through physical input.
    defer App.shortcuts_deinit();
    defer App.console_deinit(*App.console);
    next: App.Console_Config;
    defer App.console_config_free(*next);
    error := App.console_config_parse(*next, "noremap M=back;");
    check(!error.count && !App.shortcuts.enabled, "Start with no shortcut hook or configured mappings.");
    error = App.console_config_apply(*App.console, *next);
    check(!error.count && App.shortcuts.enabled, "Adding the first mapping installs its hook during reload.");
    App.shortcuts.down[0x4d] = true;
    App.shortcuts.consumed[0x4d] = true;
    App.shortcuts.queue_count = 1;
    error = App.console_config_apply(*App.console, *next);
    check(!error.count && App.shortcuts.enabled && !App.console.config.shortcuts.count, "Removing the last mapping keeps the release hook alive.");
    check(!App.shortcuts.queue_count, "Production config replacement cancels pending shortcut indexes.");
    consumed := App.shortcuts_handle_key(0x4d, false, false, null);
    check(consumed && !App.shortcuts.consumed[0x4d], "Production hook swallows a previously consumed key-up after removing all maps.");
}

expect_pump :: (reload: *App.Config_Reload, duration: float64, expected_changes: s64, expected_errors: s64, message: string) {
    changes, errors, detail := pump(reload, duration);
    defer free(detail);
    check(changes == expected_changes && errors == expected_errors, message);
}

check_notifications :: () {
    filename := copy_string(tprint("%/config.rc", directory));
    temporary := copy_string(tprint("%/config.new", directory));
    unrelated := copy_string(tprint("%/unrelated.txt", directory));
    defer free(filename); defer free(temporary); defer free(unrelated);
    defer file_delete(filename); defer file_delete(temporary); defer file_delete(unrelated);
    state: App.Console_State;
    defer App.console_deinit(*state);
    error := App.console_config_parse(*state.config, "alpha=old; freecam_speed=19;");
    check(!error.count, "Seed settings before a missing file is created.");
    reload: App.Config_Reload;
    error = App.config_reload_init(*reload, *state, filename, apply_config);
    check(!error.count, "Watch a directory before config.rc exists.");
    defer App.config_reload_deinit(*reload);
    expect_pump(*reload, 0.25, 0, 0, "Initialization does not execute or replace settings.");
    check(state.config.freecam_speed == 19, "An initially absent config leaves live state intact.");

    check(write_entire_file(filename, "alpha=first; freecam_speed=21;"), "Create watched config.");
    expect_pump(*reload, 0.8, 1, 0, "Creation triggers one complete reload.");
    check(state.config.freecam_speed == 21 && App.console_alias_lookup(*state, "alpha").command == "first", "Created config is applied.");
    count := applied;
    for 0..9999 {
        changed, idle_error := App.config_reload_update(*reload, seconds_since_init());
        if changed || idle_error.count { check(false, "Idle polling must not apply or report anything."); break; }
    }
    print("10000 idle watcher polls: no reloads.\n");
    check(applied == count && !reload.pending, "Idle polling never schedules another read or apply.");
    check(write_entire_file(unrelated, "ignore me"), "Write another file in the watched directory.");
    expect_pump(*reload, 0.4, 0, 0, "Ignore unrelated directory changes.");
    check(write_entire_file(filename, "alpha=first; freecam_speed=21;"), "Save identical content.");
    expect_pump(*reload, 0.65, 0, 0, "Identical saves do not reapply settings.");

    check(write_entire_file(filename, "freecam_speed=22;"), "Begin a burst of saves.");
    sleep_milliseconds(20);
    check(write_entire_file(filename, "freecam_speed=23;"), "Finish the burst.");
    expect_pump(*reload, 0.8, 1, 0, "Coalesce a save burst into its final contents.");
    check(state.config.freecam_speed == 23, "Use the final save in a burst.");
    check(write_entire_file(temporary, "freecam_speed=24; alpha=replaced;"), "Write the editor's temporary file.");
    check(ReplaceConfigFile(utf8_to_wide(temporary,, temp), utf8_to_wide(filename,, temp), 1) != 0, "Atomically replace config by renaming the temporary file.");
    expect_pump(*reload, 0.8, 1, 0, "Renamed replacement triggers hot reload.");
    check(state.config.freecam_speed == 24, "Use the atomically replaced file.");

    check(write_entire_file(filename, "alpha=bad;\nfreecam_speed=oops;"), "Write malformed configuration.");
    changes, errors, detail := pump(*reload, 1.8);
    defer free(detail);
    check(changes == 0 && errors == 1 && contains(detail, "Line 2"), "Report the syntax line once after bounded retries.");
    check(state.config.freecam_speed == 24 && App.console_alias_lookup(*state, "alpha").command == "replaced", "Malformed input never partially replaces live aliases or values.");
    expect_pump(*reload, 0.4, 0, 0, "Invalid files do not cause endless reads or error spam.");
    check(file_delete(filename), "Temporarily remove config.");
    expect_pump(*reload, 1.7, 0, 1, "A missing file reports failure instead of restoring defaults.");
    check(state.config.freecam_speed == 24, "Deletion keeps the last valid settings.");
    check(write_entire_file(filename, "freecam_speed=25;"), "Recreate config after deletion.");
    expect_pump(*reload, 0.8, 1, 0, "A later valid save recovers without restarting.");

    locked, opened := file_open(filename, for_writing = true, keep_existing_content = true);
    check(opened, "Open an in-progress editor write.");
    defer if opened file_close(*locked);
    check(file_write(*locked, "freecam_speed=26;"), "Write while keeping the writer handle open.");
    expect_pump(*reload, 0.5, 0, 0, "A sharing violation is retried without applying defaults.");
    check(state.config.freecam_speed == 25, "Locked file preserves current settings.");
    file_close(*locked);
    expect_pump(*reload, 1.0, 1, 0, "Reload after the editor closes its writer handle.");
    check(state.config.freecam_speed == 26, "Apply complete contents after the lock clears.");

    reject_apply = true;
    check(write_entire_file(filename, "freecam_speed=27;"), "Save before a simulated preparation failure.");
    expect_pump(*reload, 1.8, 0, 1, "Runtime preparation failure retains the old configuration.");
    check(state.config.freecam_speed == 26, "Do not mark a failed apply as committed.");
    reject_apply = false;
    check(write_entire_file(filename, "freecam_speed=27;"), "Retry failed contents after preparation recovers.");
    expect_pump(*reload, 0.8, 1, 0, "A previously failed configuration can be retried unchanged.");
    check(write_entire_file(filename, "hud_show_position=false; hud_text='Custom'; hud_show_notifications=false; hud_show_level_name=true; hud_text='Second';"), "Save HUD item switches, custom text and order.");
    expect_pump(*reload, 0.8, 1, 0, "A normal config save applies HUD settings.");
    check(!App.hud.settings.show_position && !App.hud.settings.show_notifications &&
          App.hud_details("level", .{}, App.hud.settings) == "Custom\nlevel\nSecond",
          "Hot reload updates HUD visibility and order without restarting.");
    check(write_entire_file(filename, "hud_show_level_name=false; hud_text='Changed';\nhud_show_position=invalid;"), "Save an invalid HUD switch after changing text and order.");
    expect_pump(*reload, 1.8, 0, 1, "An invalid HUD configuration is rejected as a whole.");
    check(App.hud.settings.show_level_name && !App.hud.settings.show_position &&
          App.hud_details("level", .{}, App.hud.settings) == "Custom\nlevel\nSecond",
          "Failed hot reload keeps all the previous HUD settings.");
    check(write_entire_file(filename, "hud_show_level_name=true;\nhud_text='Custom'; hud_text='Second';\nhud_show_position=false; hud_show_notifications=false;"), "Save only a change to HUD declaration order.");
    expect_pump(*reload, 0.8, 1, 0, "Moving HUD configuration lines triggers a reload.");
    check(App.hud_details("level", .{}, App.hud.settings) == "level\nCustom\nSecond", "A reorder-only reload updates visible rows.");
    check(write_entire_file(filename, "hud_show_level_name=true; hud_text='Updated'; hud_text='Second'; hud_show_position=false; hud_show_notifications=false;"), "Save only a change to HUD text.");
    expect_pump(*reload, 0.8, 1, 0, "Editing HUD text triggers a reload.");
    check(App.hud_details("level", .{}, App.hud.settings) == "level\nUpdated\nSecond", "A text-only reload replaces one row while retaining the other.");
    check(write_entire_file(filename, "hud_show_level_name=true; hud_text='Updated'; hud_text=''; hud_text='Second'; hud_show_position=false; hud_show_notifications=false;"), "Insert a blank HUD row.");
    expect_pump(*reload, 0.8, 1, 0, "Adding an empty text declaration triggers a reload.");
    check(App.hud_details("level", .{}, App.hud.settings) == "level\nUpdated\n\nSecond" && App.hud_info_line_count(App.hud.settings) == 4,
          "Hot reload preserves the blank row and excludes disabled coordinates.");
    check(write_entire_file(filename, "hud_show_level_name=true; hud_text='Updated\\n\\nSecond'; hud_show_position=false; hud_show_notifications=false;"), "Save multiline custom text.");
    expect_pump(*reload, 0.8, 1, 0, "Saving newline escapes triggers a reload.");
    check(App.hud_details("level", .{}, App.hud.settings) == "level\nUpdated\n\nSecond" && App.hud_info_line_count(App.hud.settings) == 4,
          "Multiline text reloads with the same spacing as separate custom rows.");
    check(write_entire_file(filename, "hud_show_level_name=true; hud_text='Second'; hud_show_position=false; hud_show_notifications=false;"), "Remove one custom text declaration.");
    expect_pump(*reload, 0.8, 1, 0, "Deleting a custom text declaration triggers a reload.");
    check(App.hud_details("level", .{}, App.hud.settings) == "level\nSecond", "Removed text disappears while remaining rows retain their order.");
    check(write_entire_file(filename, ""), "Explicitly clear the config.");
    expect_pump(*reload, 0.8, 1, 0, "Stable empty files restore defaults.");
    check(state.config.freecam_speed == 12 && !state.config.aliases.count, "An empty valid config resets file settings only.");
    check(App.hud.settings.show_position && App.hud.settings.show_notifications && App.hud_info_line_count(App.hud.settings) == 2 &&
          App.hud_details("level", .{}, App.hud.settings) == "level\nUnavailable",
          "Removing HUD configuration hot reloads the default switches and order.");
    check(write_entire_file(filename, "broken='"), "Create another pending change.");
    App.config_reload_deinit(*reload);
    App.config_reload_deinit(*reload);
    expect_pump(*reload, 0.25, 0, 0, "Deinitialization cancels pending callbacks and is repeatable.");

    large := NewArray(65537, u8);
    defer free(large.data);
    memset(large.data, #char " ", large.count);
    check(write_entire_file(filename, large.data, large.count), "Write an oversized fixture.");
    source, read_error := App.console_config_read(filename);
    defer free(source);
    check(read_error.count > 0 && !source.count, "Reject files over 64 KiB before allocating the contents.");
    error = App.config_reload_init(*reload, *state, tprint("%/missing/config.rc", directory), apply_config);
    check(error.count > 0 && !reload.loader.initialized, "Failed watch setup releases its resources.");
}

check_fonts :: () {
    first := copy_string(tprint("%/font-a", directory));
    second := copy_string(tprint("%/font-b", directory));
    defer free(first); defer free(second);
    check(make_directory_if_it_does_not_exist(first) && make_directory_if_it_does_not_exist(second), "Create isolated font directories.");
    name := App.CONSOLE_FONT_FILE;
    a := copy_string(tprint("%/%", first, name));
    b := copy_string(tprint("%/%", second, name));
    defer free(a); defer free(b); defer file_delete(a); defer file_delete(b);
    check(copy_file(tprint("data/fonts/%", name), a) && copy_file(tprint("data/fonts/%", name), b), "Copy the bundled font for cache identity checks.");
    fa := App.get_game_font_file(first, name, 27);
    fb := App.get_game_font_file(second, name, 27);
    check(fa && fb && fa != fb, "Same font filename in two game directories has distinct cached fonts.");
    check(App.get_game_font_file(first, name, 27) == fa, "Returning to an earlier directory reuses its cached font.");
    check(App.get_game_font_file(first, "missing.otf", 27) == null, "A missing new font fails without a modal dialog.");
}

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
#import "System";
#import "Windows_Utf8";
App :: #import,file "../src/main.jai";
Win :: #import "Windows";
kernel32 :: #library,system "kernel32";
ReplaceConfigFile :: (from: *u16, to: *u16, flags: u32) -> s32 #foreign kernel32 "MoveFileExW";
