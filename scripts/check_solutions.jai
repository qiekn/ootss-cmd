#!/usr/bin/env jai

// Isolated files, invalid window handles and mock input only.
#run {
    set_build_options_dc(.{do_output = false});
    root := tprint("%/../.build/solutions_%", #filepath, Win.GetCurrentProcessId());
    check(make_directory_if_it_does_not_exist(root), "Create isolated test directory.");
    check(set_working_directory(root), "Select isolated test directory.");
    check(make_directory_if_it_does_not_exist("data"), "Create isolated data directory.");
    check_parse();
    check_files_and_editor();
    check_rabbit();
    check_timed_waits();
    check_recorded_waits();
    check_inline_wait_edit();
    check_wait_animation();
    check_speed_and_record_shortcuts();
    check_jump_replay();
    print("PASS: % JSON/editor/Rabbit/wait checks; no game writes or input.\n", checks);
}

checks: s64;
check :: (condition: bool, message: string) {
    checks += 1;
    if !condition { compiler_report(message); assert(condition); }
}

check_parse :: () {
    database: App.Solutions_Database;
    defer App.solutions_free(*database);
    source := "[{\"name\":\"mirror_1\",\"note\":\"中文 # : \\\"note\\\"\\nline 2\",\"solution\":\"R2XL4XL6U\"},{\"name\":\"empty\",\"solution\":\"\"}]";
    check(!App.solutions_parse_json(*database, source).count && database.entries.count == 2, "Read simplified JSON and empty solutions.");
    check(App.solution_find_name(*database, "MIRROR_1", ignore_case = true) == 0, "Case-insensitive lookup.");
    keys, key_error := App.timeline_parse(database.entries[0].solution);
    defer free(keys);
    check(!key_error.count && keys == "RRXLLLLXLLLLLLU", "Compressed keys expand correctly.");
    for invalid: string.["", "{}", "[", "[{}]", "[{\"name\":\"bad name\"}]", "[{\"name\":\"a\"},{\"name\":\"A\"}]",
                         "[{\"name\":\"a\",\"solution\":42}]"] {
        check(App.solutions_parse_json(*database, invalid).count > 0 && database.entries.count == 2 &&
              database.entries[0].solution == "R2XL4XL6U", "Malformed JSON and duplicate names fail transactionally.");
    }
    database.entries[0].position = .[61, 70, 4];
    database.entries[0].area     = copy_string("catalog-only");
    serialized, error := App.solutions_serialize_json(*database);
    defer free(serialized);
    check(!error.count && !contains(serialized, "\"position\"") && !contains(serialized, "\"area\"") &&
          !contains(serialized, "\"level\""), "Only name, note and solution are serialized.");
    roundtrip: App.Solutions_Database;
    defer App.solutions_free(*roundtrip);
    check(!App.solutions_parse_json(*roundtrip, serialized).count && roundtrip.entries[0].note == database.entries[0].note,
          "Unicode, punctuation, quotes and multiline notes round-trip.");
    check(!App.solutions_parse_json(*roundtrip, "\xef\xbb\xbf[]").count && !roundtrip.entries.count, "Accept a BOM and an empty JSON array.");
}

check_files_and_editor :: () {
    level_source  := "[{\"name\":\"mirror_1\",\"note\":\"level note\",\"solution\":\"R2XL4XL6U\",\"position\":[61,70,0],\"area\":\"legacy\"},{\"name\":\"other\",\"note\":\"keep\",\"solution\":\"LL\"}]";
    custom_source := "[{\"name\":\"MIRROR_1\",\"solution\":\"L\"},{\"name\":\"custom\",\"note\":\"custom note\",\"solution\":\"(RU)2 3 _2\"}]";
    check(write_entire_file(App.SOLUTIONS_FILE, level_source), "Write level JSON.");
    check(write_entire_file(App.CUSTOM_INPUTS_FILE, custom_source), "Write custom JSON.");
    check(write_entire_file("data/solution.txt", "mirror_1:L"), "Create obsolete text fixture.");
    check(write_entire_file("data/custom_inputs.txt", "custom:L"), "Create obsolete custom text fixture.");
    database: App.Solutions_Database;
    defer App.solutions_free(*database);
    check(!App.solutions_load(*database).count && !database.entries[0].area.count && App.solution_position_equal(database.entries[0].position, .[0, 0, 0]),
          "Legacy metadata is ignored when reading JSON.");
    catalog := #string JSON
{"source":{"package":"levels.package","sha256":"0000000000000000000000000000000000000000000000000000000000000000","scene":"overworld"},
 "levels":[{"name":"mirror_1","region":"mirrors","position":[4,5,6],"entity_id":1},
           {"name":"mirror_2","region":"mirrors","position":[4,5,6],"entity_id":2}]}
JSON
    check(write_entire_file("catalog.json", catalog), "Create an independent level catalog.");
    check(!App.solutions_load(*database, catalog_file = "catalog.json").count && database.entries.count == 3 &&
          database.entries[0].area == "mirrors" && App.solution_position_equal(database.entries[0].position, .[4, 5, 6]) &&
          database.entries[0].solution == "R2XL4XL6U", "Catalog supplies metadata without replacing solutions; shared positions retain distinct names.");
    catalog_record, catalog_custom, catalog_temp, catalog_error := App.editor_load_record("mirror_2", catalog_file = "catalog.json");
    defer App.solution_record_free(*catalog_record);
    check(!catalog_error.count && !catalog_custom && !catalog_temp && catalog_record.name == "mirror_2" && !catalog_record.solution.count,
          "A catalog-only level opens as an empty level solution.");
    for name: string.["mirror_1", "custom"] {
        state: App.Console_State;
        defer App.console_deinit(*state);
        App.console_set_input(*state, tprint("play %", name));
        App.console_submit(*state);
        App.console_play_saved_solution(*state);
        expected := ifx name == "mirror_1" then "ddxaaaaxaaaaaaw" else "dwdw3__";
        check(state.pending_send == expected, "Playback uses JSON even with conflicting TXT files; levels take precedence.");
    }
    for custom: bool.[false, true] {
        name                                := ifx custom then "custom" else "mirror_1";
        record, is_custom, temporary, error := App.editor_load_record(name, catalog_file = "");
        check(!error.count && is_custom == custom && !temporary && record.name == name, "Editor opens level and custom JSON records.");
        record.area     = copy_string("catalog-region");
        record.position = .[61, 70, 4];
        App.editor      = .{open = true, custom = custom, game = cast(Win.HWND) -101, record = record};
        defer {
            App.editor_clear_save_prompt();
            App.solution_record_free(*App.editor.record);
            App.timeline_free(*App.editor.timeline);
            free(App.editor.status);
            App.editor = .{};
        }
        check(!App.timeline_load(*App.editor.timeline, "U2_3.5_ 3 R").count, "Prepare edited timed waits.");
        App.editor.timeline.dirty     = true;
        App.editor_save_prompt.active = true;
        App.console_set_input(*App.editor_save_prompt.name, name);
        check(App.editor_confirm_save(), "Editor confirmation saves JSON.");
        check(!App.editor.timeline.dirty && !App.editor_save_prompt.active && App.editor.record.area == "catalog-region",
              "Save updates the snapshot and retains catalog display metadata.");
        filename := ifx custom then App.CUSTOM_INPUTS_FILE else App.SOLUTIONS_FILE;
        check(!App.solutions_load(*database, filename).count && database.entries.count == 2, "Reload saved JSON.");
        index := App.solution_find_name(*database, name, ignore_case = true);
        check(index >= 0 && database.entries[index].solution == "UU_3.5_ 3 R" &&
              database.entries[index].note == (ifx custom then "custom note" else "level note"), "Save preserves notes and timed waits.");
        saved, saved_ok := read_entire_file(filename);
        defer free(saved);
        check(saved_ok && !contains(saved, "\"position\"") && !contains(saved, "\"area\"") && !contains(saved, "\"level\""),
              "Actual editor output has the simplified schema.");
        external := tprint("[{\"name\":\"%\",\"solution\":\"L\",\"note\":\"new note\"}]", name);
        check(write_entire_file(filename, external), "Simulate external edits.");
        App.editor.timeline.dirty     = true;
        App.editor_save_prompt.active = true;
        App.console_set_input(*App.editor_save_prompt.name, name);
        check(!App.editor_confirm_save() && App.editor_save_prompt.overwrite && App.editor.timeline.dirty,
              "External changes still require overwrite confirmation.");
        check(App.editor_confirm_save(), "Confirmed overwrite succeeds.");
        check(write_entire_file(filename, "invalid"), "Simulate malformed JSON during save.");
        App.editor.timeline.dirty     = true;
        App.editor_save_prompt.active = true;
        App.console_set_input(*App.editor_save_prompt.name, name);
        check(!App.editor_confirm_save() && App.editor.timeline.dirty && App.editor_save_prompt.active,
              "Save errors preserve unsaved edits and the confirmation.");
        check(write_entire_file(filename, ifx custom then custom_source else level_source), "Restore fixture.");
    }
    check(write_entire_file(App.SOLUTIONS_FILE, "[]"), "Write empty JSON.");
    check(!App.solutions_load(*database).count && !database.entries.count, "An empty JSON array never imports TXT.");
    check(file_delete(App.SOLUTIONS_FILE), "Remove the isolated JSON file.");
    check(!App.solutions_load(*database).count && !database.entries.count, "Missing JSON never falls back to TXT.");
    check(!App.solutions_parse_json(*database, "[{\"name\":\"new\",\"solution\":\"R\"}]").count, "Prepare failed write fixture.");
    check(App.solutions_write(*database, "missing/folder/solutions.json").count > 0, "Output failures are reported.");
}

pressed, released: s64;
emit :: (key: App.Game_Key, up: bool) -> string {
    if up released += 1;
    else pressed += 1;
    return "";
}

check_timed_waits :: () {
    waits: [..] s32;
    defer array_free(waits);
    keys, error := App.expand_send("(R_3.5_)2 _3 2", true, *waits);
    defer free(keys);
    check(!error.count && keys == "d_d____2" && waits.count == keys.count && waits[1] == 3500 && waits[3] == 3500 && waits[4] == 250,
          "Timed waits survive nested expansion, repeats, direction mapping and literal digit keys.");
    for bad: string.["_0_", "_-1_", "_1e309_", "_1e-999_", "_3.5", "_3..5_", "_<3.5>_", "_2147484_", "_0.0001_"] {
        invalid, invalid_error := App.expand_send(bad, waits = *waits);
        defer free(invalid);
        check(invalid_error.count > 0 && !invalid.count && waits.count == keys.count, "Reject invalid waits before replacing parsed output.");
    }
    integer_waits: [..] s32;
    defer array_free(integer_waits);
    integer_keys, integer_error := App.expand_send("_3_ _3 _ 3 _1__2_", waits = *integer_waits);
    defer free(integer_keys);
    check(!integer_error.count && integer_keys == "_____3__" && integer_waits[0] == 3000 && integer_waits[1] == 250 &&
          integer_waits[6] == 1000 && integer_waits[7] == 2000,
          "Closed integer waits, legacy repeats, literal digits and adjacent timed waits are unambiguous.");
    timeline: App.Solution_Timeline;
    defer App.timeline_free(*timeline);
    check(!App.timeline_load(*timeline, "U_3.5_R").count && timeline.keys.count == 3 && timeline.wait_ms[1] == 3500,
          "A timed wait is one editable timeline cell.");
    App.timeline_move_caret(*timeline, 1);
    check(!App.timeline_insert(*timeline, "_").count && timeline.wait_ms[1] == 250 && timeline.wait_ms[2] == 3500,
          "Inserted waits default to 0.25 seconds and preserve later durations.");
    check(App.timeline_erase(*timeline, 0, 2) && timeline.keys.count == 2 && timeline.wait_ms[0] == 3500, "Deleting shifts durations with their cells.");
    check(App.timeline_record(*timeline, #char "L") && timeline.wait_ms[0] == 0 && timeline.wait_ms[1] == 3500, "Recording shifts durations with their cells.");
    App.timeline_move_caret(*timeline, 2);
    check(!App.timeline_insert(*timeline, "_", s32.[1250]).count && timeline.wait_ms[2] == 1250, "Pasted waits retain their explicit duration.");
    serialized := App.timeline_serialize(*timeline);
    defer free(serialized);
    check(serialized == "L_3.5__1.25_R", "Export uses the requested timed-wait format.");
    check(!App.timeline_load(*timeline, serialized).count && timeline.wait_ms[1] == 3500 && timeline.wait_ms[2] == 1250, "Export/reload round-trips durations.");
    map := App.game_keymap_defaults();
    for speed: App.Editor_Playback_Speed.[.NORMAL, .RABBIT, .TURTLE] {
        rate := App.editor_playback_rate(speed);
        check(!App.timeline_load(*timeline, "_3.5_R").count, "Load a fixed wait before transport.");
        transport: App.Editor_Transport = .{playing = true, speed = speed};
        count := pressed;
        check(!App.editor_transport_tick(*transport, *timeline, *map, 10, emit).count && transport.phase == .WAIT &&
              transport.deadline == 13.5 && !timeline.playhead, "Waits retain 3.5 nominal seconds at every playback multiplier.");
        check(!App.editor_transport_tick(*transport, *timeline, *map, 10 + 3.499 / rate, emit).count && !timeline.playhead,
              "The next key is not sent before the duration expires.");
        check(!App.editor_transport_tick(*transport, *timeline, *map, 10 + 3.5 / rate, emit).count && timeline.playhead == 2,
              "The next key follows the completed wait.");
        check(!App.editor_transport_stop(*transport, *timeline, emit).count, "Release mock keys after timing checks.");
    }
    App.editor               = .{open = true, game = cast(Win.HWND) -101};
    App.editor_window.handle = cast(Win.HWND) -102;
    defer {
        App.editor_finish_wait_edit();
        App.timeline_free(*App.editor.timeline);
        free(App.editor.status);
        App.editor        = .{};
        App.editor_window = .{};
    }
    check(!App.timeline_load(*App.editor.timeline, "_3.5_R").count, "Load a duration editor fixture.");
    App.editor_window.bounds     = .{0, 0, 1100, 248};
    App.editor_view.display_head = 0;
    App.editor_handle_event(.{kind = .DOUBLE, x = 560, y = 100});
    check(App.editor_wait_edit.active && App.console_input(*App.editor_wait_edit.field) == "3.5", "Double-clicking a timeline wait opens the current duration.");
    App.console_set_input(*App.editor_wait_edit.field, "2.75");
    check(App.editor_confirm_wait() && !App.editor_wait_edit.active && App.editor.timeline.wait_ms[0] == 2750 && App.editor.timeline.dirty,
          "Applying changes updates the duration and marks the solution dirty.");
    check(App.editor_begin_wait_edit(0), "Reopen the duration field.");
    App.console_set_input(*App.editor_wait_edit.field, "0");
    check(!App.editor_confirm_wait() && App.editor_wait_edit.active && App.editor.timeline.wait_ms[0] == 2750,
          "Invalid duration keeps editing in the cell and the old duration intact.");
    App.editor_wait_edit_event(.{kind = .KEY, key = 0x1b});
    check(!App.editor_wait_edit.active && App.editor.timeline.wait_ms[0] == 2750, "Escape cancels without changing the wait.");
    check(!App.editor_begin_wait_edit(1), "Movement cells do not open duration editing.");
    state: App.Console_State;
    defer App.console_deinit(*state);
    App.console_set_input(*state, "send_alt R_3.5_U -rabbit");
    App.console_submit(*state);
    check(state.pending_send == "d_w" && state.pending_send_waits.count == 3 && state.pending_send_waits[1] == 3500,
          "Queued standalone playback owns the timed waits independently of input text.");
}

check_recorded_waits :: () {
    App.editor        = .{open = true, recording = true, game = cast(Win.HWND) -101, keymap = App.game_keymap_defaults()};
    App.editor_window = .{handle = cast(Win.HWND) -102, bounds = .{0, 0, 1100, 248}};
    App.editor_view   = .{};
    defer {
        App.editor_finish_wait_edit();
        App.timeline_free(*App.editor.timeline);
        free(App.editor.status);
        App.editor        = .{};
        App.editor_window = .{};
        App.editor_view   = .{};
    }
    for compact: bool.[false, true] {
        App.editor_view.minimized = compact;
        check(!App.timeline_load(*App.editor.timeline, "U_3.5_R").count, "Load recording fixture.");
        App.editor.timeline.playhead = 1;
        App.editor.timeline.caret    = 2;
        App.editor.timeline.anchor   = 2;
        App.editor.transport.target  = 1;
        check(App.editor_filter_key(#char "B", true, false, App.editor.game), "B during recording is consumed by the editor.");
        App.editor_process_window_events();
        check(App.editor.timeline.playhead == 2 && App.editor.timeline.wait_ms[1] == 250 && App.editor.timeline.wait_ms[2] == 3500 &&
              App.editor.timeline.caret == 3, "Recording adds a default wait at the execution boundary without changing future waits.");
        check(App.editor_filter_key(#char "B", true, false, App.editor.game) && !App.editor_window.event_count,
              "Holding B does not record repeated waits.");
        check(App.editor_filter_key(#char "B", false, false, App.editor.game), "The matching B release is consumed.");
        check(!App.editor_filter_key(#char "B", true, true, App.editor.game) && !App.editor_window.event_count, "Injected B is ignored.");
        App.editor_handle_event(.{kind = .TEXT, key = #char "B"});
        check(App.editor.timeline.keys.count == 5 && App.editor.timeline.wait_ms[3] == 250, "Typing B also inserts a default future wait.");
        serialized := App.timeline_serialize(*App.editor.timeline);
        defer free(serialized);
        check(serialized == "U_0.25__3.5__0.25_R", "Recorded and typed waits serialize identically.");

        // First click hits an executed wait while the strip is easing. The second
        // click lands over its neighbor after easing; it must still edit that wait.
        check(!App.timeline_load(*App.editor.timeline, "U_3.5_R").count, "Load animated double-click fixture.");
        App.editor.timeline.playhead = 3;
        App.editor.transport.target  = 3;
        App.editor_view_reset();
        App.editor_view.display_head = 2;
        strip, controls := App.editor_layout();
        x               := cast(s32)(App.editor_playhead_x(strip) - App.editor_pitch() / 2);
        y               := cast(s32)(strip.y + strip.h / 2);
        App.editor_handle_event(.{kind = .DOWN, x = x, y = y});
        App.editor_handle_event(.{kind = .UP, x = x, y = y});
        App.editor_handle_event(.{kind = .CANCEL}); // Win32 ReleaseCapture.
        App.editor_view.display_head = 3;
        App.editor_handle_event(.{kind = .DOUBLE, x = x, y = y});
        check(App.editor_wait_edit.active && App.editor_wait_edit.index == 1 &&
              App.console_input(*App.editor_wait_edit.field) == "3.5", "A real click sequence edits the same wait despite timeline easing.");
        check(App.editor_view.minimized == compact, "Inline duration editing preserves the compact/full layout.");
        head := App.editor_view.display_head;
        App.editor_view_tick(42);
        check(App.editor_view.display_head == head, "The edited cell stays still while entering its duration.");
        App.editor_wait_edit_event(.{kind = .TEXT, key = #char "2"});
        App.editor_wait_edit_event(.{kind = .TEXT, key = #char "."});
        App.editor_wait_edit_event(.{kind = .TEXT, key = #char "7"});
        App.editor_wait_edit_event(.{kind = .TEXT, key = #char "5"});
        App.editor_wait_edit_event(.{kind = .KEY, key = 0x0d});
        check(!App.editor_wait_edit.active && App.editor.timeline.wait_ms[1] == 2750 && App.editor_view.minimized == compact,
              "Typing and Enter update the wait without resizing the editor.");
        check(App.editor_pitch() >= 44, "Both timeline sizes reserve readable space for seconds.");
    }
}

check_inline_wait_edit :: () {
    App.editor        = .{open = true, recording = true, game = cast(Win.HWND) -101, keymap = App.game_keymap_defaults()};
    App.editor_window = .{handle = cast(Win.HWND) -102, bounds = .{0, 0, 1100, 248}};
    App.editor_view   = .{};
    defer {
        App.editor_finish_wait_edit();
        App.timeline_free(*App.editor.timeline);
        free(App.editor.status);
        App.editor        = .{};
        App.editor_window = .{};
        App.editor_view   = .{};
    }
    for compact: bool.[false, true] {
        App.editor_view.minimized = compact;
        check(!App.timeline_load(*App.editor.timeline, "U_3.5_R_0.125_").count, "Load inline edit fixture.");
        App.editor.timeline.playhead = 1;
        App.editor.timeline.caret    = 3;
        App.editor.timeline.anchor   = 2;
        App.editor.transport.target  = 1;
        App.editor_view_reset();
        check(App.editor_begin_wait_edit(1), "Begin editing a wait inside its cell.");
        App.editor_handle_event(.{kind = .KEY, key = 0x27});
        check(App.editor_wait_edit.field.cursor == 3 && App.editor_wait_edit.anchor == 3,
              "Right collapses the selected duration to its end.");
        App.editor_handle_event(.{kind = .KEY, key = 0x25});
        App.editor_handle_event(.{kind = .KEY, key = 0x2e});
        App.editor_handle_event(.{kind = .TEXT, key = #char "7"});
        check(App.console_input(*App.editor_wait_edit.field) == "3.7" && App.editor.timeline.wait_ms[1] == 3500 &&
              App.editor.timeline.keys.count == 4, "Cursor deletion and insertion edit only the duration draft.");
        App.editor_handle_event(.{kind = .KEY, key = 0x24, shift = true});
        App.editor_handle_event(.{kind = .TEXT, key = #char "2"});
        App.editor_handle_event(.{kind = .TEXT, key = #char "."});
        App.editor_handle_event(.{kind = .TEXT, key = #char "5"});
        App.editor_handle_event(.{kind = .KEY, key = 0x74});
        App.editor_handle_event(.{kind = .KEY, key = #char "K"});
        check(App.editor.recording && !App.editor_busy(), "Typing in a wait cannot toggle recording or playback.");
        App.editor_handle_event(.{kind = .KEY, key = 0x0d});
        check(!App.editor_wait_edit.active && App.editor.timeline.wait_ms[1] == 2500 && App.editor.timeline.dirty &&
              App.editor.timeline.playhead == 1 && App.editor.timeline.caret == 3 && App.editor.timeline.anchor == 2 &&
              App.editor_view.minimized == compact, "Enter applies a selected-text replacement without moving the timeline or resizing.");

        App.editor_begin_wait_edit(1);
        App.editor_handle_event(.{kind = .KEY, key = 8});
        App.editor_handle_event(.{kind = .DOWN, x = 0, y = 0});
        check(App.editor_wait_edit.active && App.editor_wait_edit.error.count > 0 && App.editor.timeline.wait_ms[1] == 2500,
              "Clicking away from an empty duration keeps editing and preserves the saved duration.");
        App.editor_handle_event(.{kind = .TEXT, key = #char "1"});
        App.editor_handle_event(.{kind = .DOWN, x = 0, y = 0});
        App.editor_handle_event(.{kind = .UP, x = 0, y = 0});
        check(!App.editor_wait_edit.active && App.editor.timeline.wait_ms[1] == 1000 && !App.editor_busy(),
              "Clicking away applies a valid duration without executing game actions.");

        App.editor_begin_wait_edit(1);
        App.editor_handle_event(.{kind = .TEXT, key = #char "9"});
        App.editor_handle_event(.{kind = .KEY, key = 0x1b});
        check(!App.editor_wait_edit.active && App.editor.timeline.wait_ms[1] == 1000, "Escape discards the inline draft.");
        App.editor_begin_wait_edit(1);
        App.editor_handle_event(.{kind = .TEXT, key = #char "9"});
        App.editor_window.events[0] = .{kind = .FOCUS_LOST};
        App.editor_window.event_count = 1;
        App.editor_process_window_events();
        check(!App.editor_wait_edit.active && App.editor.timeline.wait_ms[1] == 1000 && App.editor_view.minimized == compact,
              "Focus loss cancels the draft without changing layout or taking focus back.");
        App.editor_begin_wait_edit(3);
        App.editor_handle_event(.{kind = .KEY, key = 0x0d});
        check(App.editor.timeline.wait_ms[3] == 125, "Editing and confirming retains millisecond precision despite two-decimal display.");
    }
}

check_wait_animation :: () {
    App.editor        = .{open = true, keymap = App.game_keymap_defaults()};
    App.editor_window = .{dpi = 96};
    App.editor_view   = .{};
    defer {
        App.timeline_free(*App.editor.timeline);
        App.editor        = .{};
        App.editor_window = .{};
        App.editor_view   = .{};
    }
    for compact: bool.[false, true] {
        App.editor_view.minimized = compact;
        for speed: App.Editor_Playback_Speed.[.NORMAL, .RABBIT, .TURTLE] {
            rate := App.editor_playback_rate(speed);
            check(!App.timeline_load(*App.editor.timeline, "_3.5__0.25_").count, "Load consecutive waits for animation.");
            App.editor.transport = .{playing = true, speed = speed};
            App.editor_view_reset();
            check(!App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 10, emit).count,
                  "Start a real wait using mock input.");
            initial_presses := pressed;
            previous_x: float = 1000;
            for nominal: float64.[10, 10.875, 11.75, 12.625, 13.499] {
                now := 10 + (nominal - 10) / rate;
                App.editor_view_tick(now);
                expected := cast(float)((nominal - 10) / 3.5);
                check(abs(App.editor_view.display_head - expected) < 0.00001 &&
                      App.editor_future_head() == App.editor_view.display_head,
                      "Both timeline sizes track actual elapsed wait time without easing lag.");
                x := -App.editor_view.display_head * App.editor_pitch();
                check(x <= previous_x && !App.editor.timeline.playhead && App.editor.transport.deadline == 13.5 &&
                      !App.editor.timeline.dirty && pressed == initial_presses,
                      "Cells move only right-to-left; rendering never advances steps, edits data or sends keys.");
                previous_x = x;
            }
            end := 10 + 3.5 / rate;
            App.editor_view_tick(end);
            check(App.editor_view.display_head == 1 && !App.editor.timeline.playhead, "Visual completion never marks a wait executed early.");
            check(!App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, end, emit).count,
                  "Transport completes the wait at its deadline.");
            App.editor_view_tick(end);
            check(App.editor_view.display_head == 1 && App.editor.timeline.playhead == 1 && App.editor.transport.deadline == 13.75,
                  "Consecutive waits join without a position jump.");
            App.editor_view_tick(10 + 3.625 / rate);
            check(App.editor_view.display_head == 1.5, "Default waits also cross halfway at half their duration.");
            check(!App.editor_transport_stop(*App.editor.transport, *App.editor.timeline, emit).count, "Pause releases mock time keys.");
            progress, active := App.editor_wait_progress(20);
            check(!active && !progress && App.editor.timeline.playhead == 1, "Paused waits no longer report progressing time.");
            App.editor.transport.playing = true;
            check(!App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 20, emit).count,
                  "Resume restarts the unfinished wait using existing playback semantics.");
            App.editor_view_tick(20);
            check(App.editor_view.display_head == 1 && App.editor.transport.deadline == 20.25, "Resumed animation uses the new deadline.");
            check(!App.editor_transport_stop(*App.editor.transport, *App.editor.timeline, emit).count, "Release mock keys after animation checks.");
        }
    }
    App.timeline_free(*App.editor.timeline);
    App.editor.transport.phase = .WAIT;
    progress, active := App.editor_wait_progress(100);
    check(!active && !progress, "An empty or reset timeline cannot display a stale wait.");
}

check_speed_and_record_shortcuts :: () {
    App.editor        = .{open = true, game = cast(Win.HWND) -101, keymap = App.game_keymap_defaults()};
    App.editor_window = .{handle = cast(Win.HWND) -102};
    defer {
        App.editor_clear_save_prompt();
        App.timeline_free(*App.editor.timeline);
        free(App.editor.status);
        App.editor        = .{};
        App.editor_window = .{};
    }
    rates  := float64.[0.25, 0.5, 1, 1.5, 2, 3, 4];
    labels := string.["0.25x", "0.5x", "1x", "1.5x", "2x", "3x", "4x"];
    speed: App.Editor_Playback_Speed = .TURTLE;
    for rate: rates {
        check(App.editor_playback_rate(speed) == rate && App.editor_playback_speed_name(speed) == labels[it_index],
              "Every playback preset has the requested numeric rate and label.");
        speed = App.editor_playback_speed_adjust(speed, true);
    }
    check(speed == .RABBIT && App.editor_playback_speed_adjust(.TURTLE, false) == .TURTLE, "J/L clamp at 4x and 0.25x.");
    for foreground: Win.HWND.[App.editor.game, App.editor_window.handle] {
        App.editor.transport.speed = .NORMAL;
        App.editor_filter_key(#char "J", true, false, foreground);
        App.editor_process_window_events();
        check(App.editor.transport.speed == .SLOW, "J slows one preset with game or editor focus.");
        App.editor_filter_key(#char "J", true, false, foreground);
        check(!App.editor_window.event_count, "Holding J does not keep slowing playback.");
        App.editor_filter_key(#char "J", false, false, foreground);
        App.editor_filter_key(#char "L", true, false, foreground);
        App.editor_process_window_events();
        check(App.editor.transport.speed == .NORMAL, "L accelerates one preset with game or editor focus.");
        App.editor_filter_key(#char "L", false, false, foreground);
    }
    App.editor_key_input(.{kind = .KEY, key = #char "J"});
    App.editor_key_input(.{kind = .KEY, key = #char "L"});
    check(App.editor.transport.speed == .NORMAL, "Window key events use the same J slower / L faster mapping.");
    check(!App.timeline_load(*App.editor.timeline, "U_2_R").count, "Prepare F5 and speed fixture.");
    App.editor.timeline.playhead = 1;
    App.editor.timeline.dirty    = true;
    for foreground: Win.HWND.[App.editor.game, App.editor_window.handle] {
        App.editor.recording = false;
        check(App.editor_filter_key(0x74, true, false, foreground), "F5 is captured with game or editor focus.");
        App.editor_process_window_events();
        check(App.editor.recording && App.editor.timeline.playhead == 1 && App.editor.timeline.dirty,
              "F5 arms recording without changing the timeline.");
        App.editor_filter_key(0x74, true, false, foreground);
        check(!App.editor_window.event_count, "F5 autorepeat cannot toggle recording.");
        check(App.editor_filter_key(0x74, false, false, foreground), "F5 release is paired.");
        App.editor_filter_key(0x74, true, false, foreground);
        App.editor_process_window_events();
        check(!App.editor.recording && App.editor.timeline.keys.count == 3, "The next F5 stops recording and preserves all steps.");
        App.editor_filter_key(0x74, false, false, foreground);
    }
    App.editor_save_prompt.active = true;
    check(!App.editor_filter_key(0x74, true, false, App.editor_window.handle), "Save confirmation leaves F5 unhandled.");
    App.editor_filter_key(0x74, false, false, App.editor_window.handle);
    App.editor_save_prompt.active = false;
    App.editor.timeline.playhead  = 1;
    App.editor.transport          = .{playing = true, speed = .DOUBLE};
    check(!App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 10, emit, 1.5).count,
          "Start 2x playback over a 1.5x game.");
    check(App.editor.transport.clock.rate == 3, "Playback and game multipliers combine exactly once.");
    App.editor_view_tick(10 + 1.0 / 3);
    check(abs(App.editor_view.display_head - 1.5) < 0.00001, "A 2-second wait is halfway after one-third second at 3x.");
    App.editor.transport.speed = .RABBIT;
    check(!App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 10 + 1.0 / 3, emit, 1.5).count,
          "Change playback speed during a wait.");
    App.editor_view_tick(10 + 1.0 / 3);
    check(abs(App.editor_view.display_head - 1.5) < 0.00001 && App.editor.transport.clock.rate == 6,
          "Changing rate preserves elapsed wait progress.");
    check(App.send_wait_duration(2000, 175) == 1400 && App.send_wait_duration(2000, 500) == 4000,
          "Standalone sleep scales with explicit delay and legacy presets.");
    check(App.send_scaled_hold(1, 4) == 1 && App.send_scaled_hold(75, 1) == 37 &&
          App.send_scaled_hold(250, 2) == 100 && App.send_scaled_hold(250, 16) == 112,
          "Scaled holds preserve integer wall milliseconds and never exceed the full cycle.");
    App.editor_pause();
    check(App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 20, emit, 0).count > 0,
          "A paused game cannot advance playback.");
    result := App.send_sequence("w", target_window = cast(Win.HWND) -999, adapt_speed = true);
    check(!result.success && !result.sent_keys, "Unavailable speed evidence prevents standalone input.");
    App.editor.timeline.playhead = 0;
    App.editor.transport         = .{target = 1, scrubbing = true, scrub_rate = 16};
    check(!App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 30, emit).count &&
          App.editor.timeline.playhead == 1 && App.editor_transport_multiplier(*App.editor.transport, *App.editor.timeline) == 16,
          "The final forward scrub key retains 16x until its complete cycle ends.");
    App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 30.0071, emit);
    check(App.editor.transport.phase == .GAP && App.editor.transport.clock.rate == 16,
          "The final scrub release gap uses the same multiplier as its hold.");
    App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 30.016, emit);
    check(!App.editor_busy(), "Forward scrubbing completes after the scaled cycle.");
    App.editor.transport = .{target = 0, scrubbing = true, scrub_rate = 16};
    App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 31, emit);
    check(App.editor.timeline.playhead == 0 && App.editor_transport_reversing(*App.editor.transport, *App.editor.timeline) &&
          App.editor_transport_multiplier(*App.editor.transport, *App.editor.timeline) == 1,
          "The last undo retains original timing even after reaching the destination.");
    App.editor_transport_stop(*App.editor.transport, *App.editor.timeline, emit);
    App.editor.transport = .{target = 2, scrubbing = true, scrub_rate = 16};
    App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 32, emit);
    App.editor.transport.target = 0;
    App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 32.0071, emit);
    App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 32.016, emit);
    check(App.editor.timeline.playhead == 1 && App.editor.transport.phase == .IDLE &&
          App.editor_transport_reversing(*App.editor.transport, *App.editor.timeline),
          "Changing drag direction yields before undo so the runtime can restore game speed.");
    App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 32.017, emit);
    check(App.editor.timeline.playhead == 0 && App.editor.transport.clock.rate == 1 && App.editor.transport.gap_ms == 5,
          "The first reverse key also keeps the original 10 ms cycle.");
    App.editor_transport_stop(*App.editor.transport, *App.editor.timeline, emit);
}

check_rabbit :: () {
    App.editor = .{open = true, game = cast(Win.HWND) -101, keymap = App.game_keymap_defaults()};
    defer {
        App.editor_clear_save_prompt();
        App.solution_record_free(*App.editor.record);
        App.timeline_free(*App.editor.timeline);
        free(App.editor.status);
        App.editor = .{};
    }
    check(!App.timeline_load(*App.editor.timeline, "UDLR_X").count, "Load a Rabbit fixture.");
    App.editor.timeline.playhead = 2;
    App.editor.timeline.caret    = 5;
    App.editor.timeline.dirty    = true;
    App.editor.recording         = true;
    App.editor.transport.target  = 2;
    for speed: App.Editor_Playback_Speed.[.NORMAL, .SLOW, .FAST] {
        App.editor.transport.speed = speed;
        App.editor_button_action(App.EDITOR_RABBIT_BUTTON);
        check(App.editor.transport.rabbit && App.editor.transport.playing && App.editor.transport.speed == speed &&
              App.editor.timeline.playhead == 2 && App.editor.timeline.caret == 5 && App.editor.timeline.dirty && App.editor.recording,
              "Rabbit temporarily overrides speed without changing playhead, caret, recording or edits.");
        App.editor_button_action(App.EDITOR_RABBIT_BUTTON);
        check(!App.editor_busy() && !App.editor.transport.rabbit && App.editor.transport.speed == speed, "A second Rabbit click pauses and restores the selected speed.");
        App.editor_toggle_play();
        check(App.editor.transport.playing && !App.editor.transport.rabbit && App.editor_transport_speed(*App.editor.transport) == speed,
              "Normal Play uses the prior speed after Rabbit is toggled off.");
        App.editor_pause();
        App.editor_rabbit_play();
        App.editor_toggle_play();
        App.editor_toggle_play();
        check(App.editor.transport.playing && !App.editor.transport.rabbit && App.editor.transport.speed == speed,
              "Pause then Play also clears the temporary Rabbit mode.");
        App.editor_pause();
    }
    App.editor.transport.speed = .NORMAL;
    App.editor_rabbit_play();
    transport := App.editor.transport;
    timeline  := App.editor.timeline; // Borrowed keys; tick changes only this local playhead.
    check(!App.editor_transport_tick(*transport, *timeline, *App.editor.keymap, 0, emit).count &&
          pressed == 1 && !transport.time_held && transport.clock.rate == 4 && transport.gap_ms == 126,
          "Rabbit uses 4x timing without injecting a native time modifier.");
    check(!App.editor_transport_stop(*transport, *timeline, emit).count && !transport.rabbit &&
          !transport.held.scan && !transport.time_held && released == 1, "Stopping releases the injected key and clears Rabbit.");
    App.editor_pause();
    App.editor_rabbit_play();
    transport         = App.editor.transport;
    timeline.playhead = timeline.keys.count;
    check(!App.editor_transport_tick(*transport, *timeline, *App.editor.keymap, 1, emit).count &&
          !transport.playing && !transport.rabbit && transport.speed == .NORMAL, "Natural completion also clears Rabbit.");
    App.editor_pause();
    App.editor_save_prompt.active = true;
    App.editor_rabbit_play();
    check(!App.editor.transport.rabbit && !App.editor_busy(), "Save confirmation blocks Rabbit playback.");
}

jump_keys: [..] App.Game_Key;
jump_fail: bool;
jump_emit :: (key: App.Game_Key, up: bool) -> string {
    if up return "";
    if jump_fail return "Mock restart failure.";
    array_add(*jump_keys, key);
    return "";
}

check_jump_replay :: () {
    App.editor                 = .{open = true, recording = true, game = cast(Win.HWND) -101, keymap = App.game_keymap_defaults()};
    App.editor_window          = .{handle = cast(Win.HWND) -102};
    App.editor_view            = .{};
    App.editor.record.solution = copy_string("X");
    defer {
        array_free(jump_keys);
        App.timeline_free(*App.editor.timeline);
        App.solution_record_free(*App.editor.record);
        free(App.editor.status);
        App.editor        = .{};
        App.editor_window = .{};
        App.editor_view   = .{};
    }
    for target: s64.[5, 2, 0, -1, 4] {
        App.timeline_load(*App.editor.timeline, "UR_0.5_DLX");
        App.editor.timeline.playhead = 4;
        App.editor.timeline.caret    = 5;
        App.editor.timeline.dirty    = true;
        App.editor.transport         = .{target = 4, speed = .TRIPLE};
        jump_keys.count              = 0;
        App.editor_jump_solution(target);
        restart := target >= 0 && target < 4;
        check(App.editor.transport.restart_before_seek == restart && App.editor.timeline.playhead == 4,
              "Earlier jump targets queue restart without rewinding before the key is accepted.");
        if target == 4 {
            check(!App.editor_busy() && !App.editor.transport.scrubbing, "Jump to the current step sends no input or temporary speed change.");
            continue;
        }
        check(App.editor.transport.scrub_rate == 16 && App.editor_transport_multiplier(*App.editor.transport, *App.editor.timeline) == 16,
              "Both forward jump and restart/replay use absolute 16x timing.");
        for i: 0..300 {
            error := App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap,
                                                cast(float64) i * 0.002, jump_emit);
            check(!error.count, "Jump playback accepts mock input.");
            if !App.editor_busy() break;
        }
        resolved := ifx target == -1 then App.editor.timeline.keys.count else target;
        check(!App.editor_busy() && App.editor.timeline.playhead == resolved, "Jump reaches the exact requested step and releases keys.");
        if target == 5 check(jump_keys.count == 1 && jump_keys[0].scan == App.editor.keymap.left.scan,
                              "Forward jump sends only the remaining movement to the target.");
        if restart check(jump_keys.count > 0 && jump_keys[0].scan == App.editor.keymap.restart.scan,
                         "Backward jump starts with the configured restart key.");
        if target == 2 check(jump_keys.count == 3 && jump_keys[1].scan == App.game_key_for_symbol(*App.editor.keymap, #char "U").scan &&
                              jump_keys[2].scan == App.editor.keymap.right.scan,
                              "Backward jump replays from step zero after releasing restart.");
        if target == 0 check(jump_keys.count == 1, "Jump zero only restarts the game.");
        for key: jump_keys check(key.scan != App.editor.keymap.undo.scan, "Jump never uses undo to reach an earlier step.");
        check(App.editor.timeline.keys.count == 6 && App.editor.timeline.wait_ms[2] == 500 &&
              App.editor.timeline.caret == 5 && App.editor.timeline.dirty && App.editor.recording &&
              App.editor.record.solution == "X" && App.editor.transport.speed == .TRIPLE,
              "Restart/replay preserves unsaved steps, waits, caret, recording, selected speed and saved snapshot.");
    }
    App.editor.timeline.playhead = 4;
    App.editor.transport         = .{target = 4};
    App.editor_jump_solution(2);
    jump_fail = true;
    error := App.editor_transport_tick(*App.editor.transport, *App.editor.timeline, *App.editor.keymap, 10, jump_emit);
    jump_fail = false;
    check(error.count > 0 && App.editor.timeline.playhead == 4, "Failed restart cannot rewind the timeline or send replay keys.");
    App.editor_pause();
    check(!App.editor.transport.restart_before_seek && !App.editor_busy(), "Pause cancels a queued restart and replay.");
    App.editor.transport = .{playing = true, target = 6};
    App.editor_jump_solution(7);
    check(App.editor.transport.playing && App.editor.transport.target == 6, "Invalid jump bounds preserve ongoing transport.");
    App.editor_pause();
    App.editor.transport.speed     = .TRIPLE;
    App.editor.transport.scrubbing = true;
    App.editor.game_speed_known    = true;
    App.editor.game_speed_value    = 16;
    check(App.editor_display_speed() == "16x", "Scrubbing displays actual game speed instead of the selected 3x preset.");
    App.editor.game_speed_value = 1.5;
    check(App.editor_display_speed() == "1.5x", "The scrub display follows a restored base speed while finishing pending steps.");
    App.editor_pause();
    check(App.editor_display_speed() == "3x", "Stopping restores the selected playback preset display.");
}

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
#import "Math";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
