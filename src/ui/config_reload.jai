Config_Apply :: #type (state: *Console_State, next: *Console_Config) -> string;

// Owns the watcher and file snapshots. Keep at a stable address while active.
Config_Reload :: struct {
    loader:                                Hotloader;
    state:                                 *Console_State;
    apply:                                 Config_Apply;
    pending, has_candidate, has_last_good: bool;
    candidate, last_good:                  string;
    attempts:                              s32;
    next_attempt:                          float64;
}

config_reload: Config_Reload;

config_reload_init :: (reload: *Config_Reload, state: *Console_State, filename := CONSOLE_CONFIG_FILE,
                       apply: Config_Apply = console_config_apply) -> string {
    if reload.loader.initialized return "Configuration hot reload is already initialized.";
    if !state || !apply return "Configuration hot reload requires state and an apply callback.";
    reload.state = state;
    reload.apply = apply;
    return hotloader_init(*reload.loader, filename, config_reload_changed, reload);
}

config_reload_deinit :: (reload: *Config_Reload) {
    hotloader_deinit(*reload.loader);
    free(reload.candidate);
    free(reload.last_good);
    reload.* = .{};
}

config_reload_update :: (reload: *Config_Reload, now: float64) -> (changed: bool, error: string) {
    hotloader_update(*reload.loader);
    if !reload.pending || now < reload.next_attempt return false, "";
    reload.next_attempt = now + 0.15;
    source, error := console_config_read(reload.loader.filename);
    defer free(source);
    if error.count return false, config_reload_failed(reload, error);
    // Two matching reads also cover saves that briefly truncate a file before writing it.
    if !reload.has_candidate || reload.candidate != source {
        free(reload.candidate);
        reload.candidate     = copy_string(source);
        reload.has_candidate = true;
        return false, "";
    }
    if reload.has_last_good && reload.last_good == source {
        config_reload_finish(reload);
        return false, "";
    }
    next: Console_Config;
    defer console_config_free(*next);
    error = console_config_parse(*next, source);
    if !error.count error = reload.apply(reload.state, *next);
    if error.count return false, config_reload_failed(reload, error);
    free(reload.last_good);
    reload.last_good     = copy_string(source);
    reload.has_last_good = true;
    config_reload_finish(reload);
    return true, "";
}

// Transfers next's owned data only after preparation succeeds. Session aliases,
// input, history, presentation and the editor are not part of this transaction.
console_config_replace :: (state: *Console_State, next: *Console_Config, keys: *Shortcut_State) -> bool {
    path_changed := state.config.game_path != next.game_path;
    shortcuts_clear_queue(keys); // Requests store indexes into the old bindings.
    console_completion_reset(*state.completion);
    console_config_free(*state.config);
    state.config = next.*;
    next.* = .{};
    return path_changed;
}

console_config_apply :: (state: *Console_State, next: *Console_Config) -> string {
    if next.shortcuts.count {
        error := shortcuts_install(required = true);
        if error.count return error;
    }
    // Keep an installed hook even when the new map is empty: it must consume
    // key-up events for noremap keys whose key-down was already consumed.
    if console_config_replace(state, next, *shortcuts) console_reload_game_fonts(state);
    hud_apply_config(state.config.hud);
    return "";
}

console_config_message :: (state: *Console_State, message: string, kind: Console_Line_Kind = .OUTPUT) {
    subtitles := state.show_subtitles;
    reveal    := state.reveal_output;
    scroll    := state.scroll;
    scroll_to := state.scroll_to_line;
    console_write(state, message, kind);
    state.show_subtitles = subtitles;
    state.reveal_output  = reveal;
    state.scroll         = scroll;
    state.scroll_to_line = scroll_to;
}

#scope_file

config_reload_changed :: (user_data: *void) {
    reload := cast(*Config_Reload) user_data;
    config_reload_finish(reload);
    reload.pending      = true;
    reload.next_attempt = 0;
}

config_reload_finish :: (reload: *Config_Reload) {
    free(reload.candidate);
    reload.candidate     = "";
    reload.has_candidate = false;
    reload.pending       = false;
    reload.attempts      = 0;
}

config_reload_failed :: (reload: *Config_Reload, error: string) -> string {
    reload.attempts += 1;
    if reload.attempts < 8 return "";
    config_reload_finish(reload);
    return tprint("%: % Keeping the previous configuration.", reload.loader.filename, error);
}
