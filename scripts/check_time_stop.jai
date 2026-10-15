#!/usr/bin/env jai

// Decode assets without playing them; speed writes target this test's allocated buffer only.
#run {
    set_build_options_dc(.{do_output = false});
    check_shortcut();
    check_config();
    check_transitions();
    check_silent_reload();
    check_audio();
    args := get_build_options().compile_time_command_line;
    if args.count && args[0] == "--device" check_audio_device();
    print("PASS: % time-stop checks; no game writes or audible playback.\n", checks);
}

checks, plays:                           s64;
last_resume, last_alternate, fail_audio: bool;
check :: (ok: bool, message: string) {
    checks += 1;
    if !ok { compiler_report(message); assert(ok); }
}

play :: (resume: bool, alternate: bool) -> string {
    plays += 1;
    last_resume    = resume;
    last_alternate = alternate;
    return ifx fail_audio then "audio failure" else "";
}

fixture :: (bytes: [] u8, speed: float64) -> App.Time_Stop_State {
    (cast(*float64)(bytes.data + 16)).* = speed;
    state: App.Time_Stop_State;
    state.session                   = .{memory = .{handle = Win.GetCurrentProcess()}, writable = true, original = speed, last = speed};
    state.session.layout.multiplier = cast(u64)(bytes.data + 16);
    for *code: state.session.layout.code { code.address = cast(u64) bytes.data; code.count = 1; }
    return state;
}

check_transitions :: () {
    defer { free(App.hud.message); App.hud = .{}; }
    bytes := NewArray(32, u8);
    defer free(bytes.data);
    value := cast(*float64)(bytes.data + 16);
    for alternate: bool.[false, true] {
        for before_finish: bool.[false, true] {
            state := fixture(bytes, 1.75);
            check(!App.time_stop_begin(*state, alternate, play).count && state.phase == .STOPPING && value.* == 1.75 &&
                  !last_resume && last_alternate == alternate, "Stop audio begins while the original custom speed keeps running.");
            check(App.hud.message == "Jotaro Kujo: “Star Platinum: The World!”", "Stop dialogue appears immediately without a premature speed notice.");
            if !before_finish check(!App.time_stop_finish(*state).count && value.* == 0 && state.phase == .STOPPED,
                                     "Only completed stop audio sets speed to zero.");
            if !before_finish check(App.hud.message == "Speed 0x", "Actual pause replaces the dialogue with a separate zero-speed notice.");
            before := value.*;
            error  := App.time_stop_resume(*state, play);
            check(!error.count && value.* == before && state.session.memory.handle != null && last_resume &&
                  last_alternate == alternate, "Resume audio keeps the current speed and uses the matching variant.");
            check(App.hud.message == "Jotaro Kujo: “And time resumes.”", "Resume dialogue appears before the speed changes.");
            check(!App.time_stop_finish(*state).count && value.* == before,
                  "A stale stop completion cannot change speed during resume audio.");
            error = App.time_stop_resume_finished(*state);
            check(!error.count && value.* == 1.75 && !state.session.memory.handle && state.phase == .IDLE && App.hud.message == "Speed 1.75x",
                  "Only resume audio completion restores the original speed and shows its separate notice.");
        }
    }
    for i: 0..29 {
        state := fixture(bytes, 0.5);
        App.time_stop_begin(*state, i % 3 == 0, play);
        if i % 2 == 0 App.time_stop_finish(*state);
        before := value.*;
        error  := App.time_stop_resume(*state, play);
        check(!error.count && value.* == before && last_resume && last_alternate == (i % 3 == 0),
              "Repeated toggling waits for the matching resume audio.");
        check(!App.time_stop_resume_finished(*state).count && value.* == 0.5, "Completion retains the exact saved speed across cycles.");
    }
    state := fixture(bytes, 1.25);
    fail_audio = true;
    check(App.time_stop_begin(*state, false, play).count > 0 && state.phase == .IDLE && value.* == 1.25,
          "Audio failure never silently pauses the game.");
    fail_audio = false;
    App.time_stop_begin(*state, true, play);
    value.* = 2;
    check(App.time_stop_finish(*state).count > 0 && value.* == 2, "An outside speed change is never overwritten at audio completion.");
    error := App.time_stop_resume(*state, play);
    check(!error.count && !App.time_stop_resume_finished(*state).count && value.* == 2 && App.hud.message == "Speed 2x",
          "Resume respects an outside owner's speed and reports the actual value.");
    state = fixture(bytes, 1.5);
    App.time_stop_begin(*state, false, play);
    App.time_stop_finish(*state);
    bytes[0] = 1;
    error = App.time_stop_resume(*state, play);
    check(error.count > 0 && state.session.memory.handle != null && value.* == 0, "Failed validation retains restoration ownership.");
    bytes[0] = 0;
    check(!App.time_stop_resume(*state, play).count && value.* == 0, "Starting resume never restores early.");
    bytes[0] = 1;
    check(App.time_stop_resume_finished(*state).count > 0 && state.session.memory.handle != null && value.* == 0,
          "Failed validation at completion also retains restoration ownership.");
    bytes[0] = 0;
    check(!App.time_stop_resume_finished(*state).count && value.* == 1.5, "Restoration can be retried after validation recovers.");

    state = fixture(bytes, 1.25);
    App.time_stop_begin(*state, false, play);
    App.time_stop_finish(*state);
    for i: 0..9 {
        App.time_stop_resume(*state, play);
        App.time_stop_begin(*state, i % 2 == 0, play);
        check(value.* == 0 && state.session.original == 1.25, "Interrupting resume never unpauses or replaces the original speed with zero.");
        check(!App.time_stop_resume_finished(*state).count && value.* == 0 && App.hud.message == "Jotaro Kujo: “Star Platinum: The World!”",
              "A stale resume completion cannot restore speed or replace a newer stop dialogue.");
        App.time_stop_finish(*state);
    }
    fail_audio = true;
    check(App.time_stop_resume(*state, play).count > 0 && value.* == 0 && state.phase == .STOPPED,
          "Failed resume audio leaves the paused speed and saved original intact for retry.");
    fail_audio = false;
    App.time_stop_resume(*state, play);
    check(!App.time_stop_resume_finished(*state).count && value.* == 1.25, "The last completed resume restores the original speed after repeated cancellations.");

    state = fixture(bytes, 1.75);
    before_plays := plays;
    fail_audio = true;
    check(!App.time_stop_begin(*state, true, play, no_audio = true).count && value.* == 0 &&
          state.phase == .STOPPED && App.hud.message == "Speed 0x", "Silent mode pauses immediately and shows only speed.");
    check(!App.time_stop_resume(*state, play, no_audio = true).count && value.* == 1.75 &&
          state.phase == .IDLE && App.hud.message == "Speed 1.75x" && plays == before_plays,
          "Silent mode restores immediately without opening or playing any audio, even when audio is unavailable.");
    fail_audio = false;
}

check_silent_reload :: () {
    bytes := NewArray(32, u8);
    defer free(bytes.data);
    defer {
        App.time_stop_cancel();
        App.overlay                           = .{};
        App.console.config.time_stop_no_audio = false;
        free(App.hud.message);
        App.hud = .{};
    }
    App.overlay.game                      = Win.GetDesktopWindow();
    App.overlay.window                    = Win.GetForegroundWindow();
    App.time_stop                         = fixture(bytes, 1.25);
    App.time_stop.game                    = App.overlay.game;
    App.time_stop.pid                     = App.process_window_pid(App.overlay.game);
    App.time_stop.phase                   = .STOPPING;
    App.console.config.time_stop_no_audio = true;
    value := cast(*float64)(bytes.data + 16);
    App.time_stop_update();
    check(value.* == 0 && App.time_stop.phase == .STOPPED && App.hud.message == "Speed 0x",
          "Reloading silent mode during stop audio completes the pending pause immediately.");
    App.time_stop.phase = .RESUMING;
    App.time_stop_update();
    check(value.* == 1.25 && App.time_stop.phase == .IDLE && App.hud.message == "Speed 1.25x",
          "Silent mode also completes pending resume without waiting for an audio callback.");
}

check_config :: () {
    state: App.Console_State;
    defer App.console_deinit(*state);
    check(!state.config.time_stop_no_audio && state.config.time_stop_alt_probability == 1.0 / 3.0, "Default config keeps audio and a one-third alt probability.");
    for probability: float64.[0, 0.25, 1] {
        error := App.console_config_parse(*state.config, tprint("TIME_STOP_ALT_PROBABILITY=%; TIME_STOP_NO_AUDIO=true;", probability));
        check(!error.count && state.config.time_stop_alt_probability == probability && state.config.time_stop_no_audio && !state.config.aliases.count,
              "The probability range, endpoints and silent-mode boolean parse case-insensitively as settings.");
    }
    for bad: string.["-0.1", "1.01", "nan", "inf", "1e999", "oops", ""] {
        error := App.console_config_parse(*state.config, tprint("time_stop_no_audio=false;\ntime_stop_alt_probability='%';", bad));
        check(error.count > 0 && contains(error, "Line 2") && state.config.time_stop_no_audio && state.config.time_stop_alt_probability == 1,
              "Invalid probabilities reject the whole config with a line number, retaining previous settings.");
    }
    for bad: string.["1", "yes", ""] {
        error := App.console_config_parse(*state.config, tprint("time_stop_no_audio='%';", bad));
        check(error.count > 0 && state.config.time_stop_no_audio, "The silent-mode setting accepts only true or false.");
    }
    next: App.Console_Config;
    defer App.console_config_free(*next);
    App.console_config_parse(*next, "time_stop_alt_probability=0.75; time_stop_no_audio=false;");
    keys: App.Shortcut_State;
    App.console_config_replace(*state, *next, *keys);
    check(state.config.time_stop_alt_probability == 0.75 && !state.config.time_stop_no_audio, "Hot reload replaces both time-stop preferences.");
    check(!App.time_stop_choose_alternate(0) && App.time_stop_choose_alternate(1), "Zero disables alt and one always selects it.");
    App.console_config_parse(*state.config, "");
    check(!state.config.time_stop_no_audio && state.config.time_stop_alt_probability == 1.0 / 3.0, "Removing both settings restores their defaults.");
}

check_shortcut :: () {
    keys: App.Shortcut_State = .{enabled = true, game = cast(Win.HWND) 123, pid = 123};
    consume, triggered := App.shortcut_filter_key(*keys, .[], #char "P", true, false, keys.game);
    check(consume && triggered && keys.queue_count == 1 && keys.queue[0].index == -3, "P queues time stop even with an open editor.");
    consume, triggered = App.shortcut_filter_key(*keys, .[], #char "P", true, false, keys.game);
    check(consume && !triggered && keys.queue_count == 1, "Physical autorepeat cannot toggle time repeatedly.");
    App.shortcut_filter_key(*keys, .[], #char "P", false, false, keys.game);
    consume, triggered = App.shortcut_filter_key(*keys, .[], #char "P", true, true, keys.game);
    check(!consume && !triggered && keys.queue_count == 1, "Injected P never triggers time stop.");
    consume, triggered = App.shortcut_filter_key(*keys, .[], #char "P", true, false, cast(Win.HWND) 999);
    check(!consume && !triggered && !keys.queue_count, "Typing P outside the game cancels stale work and passes through.");
    App.shortcut_filter_key(*keys, .[], #char "P", false, false, keys.game);
    bindings := App.Command_Shortcut.[.{vk = #char "P", command = "custom", consume = true}];
    consume, triggered = App.shortcut_filter_key(*keys, bindings, #char "P", true, false, keys.game);
    check(consume && triggered && keys.queue[0].index == 0, "Configured P mappings retain priority.");
}

check_audio :: () {
    for alternate: bool.[false, true] for resume: bool.[false, true] {
        clip: App.Time_Audio_Clip;
        defer free(clip.samples.data);
        filename := tprint("%/../%", #filepath, App.time_audio_filename(resume, alternate));
        error    := App.time_audio_load(*clip, filename);
        check(!error.count && clip.samples.count > 0 && clip.format.wBitsPerSample == 16, "Each bundled Ogg decodes completely into owned PCM.");
    }
    clip: App.Time_Audio_Clip;
    check(App.time_audio_load(*clip, "missing-time-stop.ogg").count > 0 && !clip.samples.count, "Missing audio fails without retained buffers.");
    check(!App.time_audio_stop().count && !App.time_audio_finished(), "Stopping an idle audio device is safe and cannot signal completion.");
}

check_audio_device :: () {
    defer App.time_audio_deinit();
    for *clip: App.time_audio_clips {
        clip.samples = NewArray(4800, s16); // 100 ms of silence: exercise the real device without audible effects.
        clip.format  = .{wFormatTag = 1, nChannels = 1, nSamplesPerSec = 48000,
                        nAvgBytesPerSec = 96000, nBlockAlign = 2, wBitsPerSample = 16};
    }
    for i: 0..7 {
        error := App.time_audio_play(i % 2 == 1, i % 3 == 0);
        check(!error.count && App.time_audio_device != null && App.time_audio_prepared,
              "Rapid track replacement closes the previous device and queues exactly one PCM buffer.");
    }
    deadline := seconds_since_init() + 2;
    while !App.time_audio_finished() && seconds_since_init() < deadline sleep_milliseconds(1);
    check(App.time_audio_finished(), "The real device signals completion after playing the buffer.");
    check(!App.time_audio_stop().count && App.time_audio_device == null && !App.time_audio_prepared,
          "Stopping releases both device and prepared buffer.");
}

#import "Basic";
#import "Compiler";
#import "String";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
