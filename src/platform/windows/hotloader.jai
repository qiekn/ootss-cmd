#scope_export

// Keep this state at a stable address until hotloader_deinit; do not copy it.
Hotloader :: struct {
    watcher:             Watch.File_Watcher;
    filename, directory: string;
    callback:            (user_data: *void);
    user_data:           *void;
    initialized, dirty:  bool;
}

hotloader_init :: (loader: *Hotloader, filename: string, callback: (user_data: *void), user_data: *void = null) -> string {
    if loader.initialized return "The file watcher is already initialized.";
    if !filename.count || !callback return "A watched filename and callback are required.";
    absolute, okay := get_absolute_path(filename);
    if !okay return tprint("Could not resolve the watched file: %.", filename);
    loader.filename = copy_string(absolute);
    path_overwrite_separators(loader.filename, #char "/");
    directory := path_strip_filename(loader.filename);
    // File_Watcher inserts its own separator before each changed filename.
    while directory.count > 3 && directory[directory.count - 1] == #char "/" directory.count -= 1;
    loader.directory = copy_string(directory);
    loader.callback  = callback;
    loader.user_data = user_data;
    if !Watch.init(*loader.watcher, hotloader_file_changed, loader,
                  merge_window_seconds = 0.15, watch_recursively = false,
                  events_to_watch      = .MODIFIED | .ADDED | .MOVED | .REMOVED) {
        hotloader_deinit(loader);
        return "Could not initialize the file watcher.";
    }
    loader.initialized = true;
    if !Watch.add_directories(*loader.watcher, loader.directory) {
        hotloader_deinit(loader);
        return tprint("Could not watch the directory containing %.", filename);
    }
    return "";
}

hotloader_update :: (loader: *Hotloader) {
    if !loader.initialized return;
    Watch.process_changes(*loader.watcher);
    if !loader.dirty return;
    loader.dirty = false;
    loader.callback(loader.user_data);
}

hotloader_deinit :: (loader: *Hotloader) {
    if loader.initialized Watch.deinit(loader.watcher);
    free(loader.filename);
    free(loader.directory);
    loader.* = .{};
}

#scope_file
Watch :: #import "File_Watcher";

hotloader_file_changed :: (watcher: *Watch.File_Watcher(void), change: *Watch.File_Change, user_data: *void) {
    loader := cast(*Hotloader) user_data;
    // Normalize separators, including the doubled separator when watching a drive root.
    absolute, okay := get_absolute_path(change.full_path);
    if !okay return;
    path_overwrite_separators(absolute, #char "/");
    if equal_nocase(absolute, loader.filename) ||
       (change.events & .SCAN_CHILDREN && equal_nocase(absolute, loader.directory)) {
        // File_Change and its path belong to the watcher and expire after dispatch.
        loader.dirty = true;
    }
}
