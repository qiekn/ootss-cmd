GAME_TITLE :: "Order of the Sinking Star";
GAME_EXECUTABLE :: "sinking_star.exe";
GAME_WINDOW_CLASS :: "Default Window Class";

find_game_window :: () -> Win.HWND {
    return process_find_window(GAME_EXECUTABLE, GAME_WINDOW_CLASS, GAME_TITLE);
}

game_window_pid :: (window: Win.HWND) -> u32 { return process_window_pid(window); }

#scope_file
Win :: #import "Windows";
