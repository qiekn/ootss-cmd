Speed_Request :: enum { QUERY; SET; UP; DOWN; RESET; }
speed_session: Game_Speed_Session;
speed_game:    Win.HWND;
speed_pid:     u32;

speed_parse :: (arguments: string) -> (request: Speed_Request, value: float64, error: string) {
    text := trim(arguments);
    if !text.count return .QUERY,0,"";
    if equal_nocase(text,"up") return .UP,0,"";
    if equal_nocase(text,"down") return .DOWN,0,"";
    if equal_nocase(text,"reset") return .RESET,0,"";
    value,ok,rest := string_to_float64(text);
    if !ok || rest.count || !game_speed_valid(value) return .QUERY,0,"Usage: speed [0..4|up|down|reset]. 0 pauses; 1 is normal speed.";
    return .SET,value,"";
}

speed_step :: (current: float64, up: bool) -> float64 {
    steps := float64.[0.25,0.5,1,1.25,1.5,1.75,2,3,4];
    if up {
        for value:steps if value>current return value;
        return GAME_SPEED_MAX;
    }
    for i:0..steps.count-1 {
        value := steps[steps.count-1-i];
        if value<current return value;
    }
    return min(current,steps[0]);
}

command_speed :: (state: *Console_State, arguments: string) {
    request,value,error := speed_parse(arguments);
    if error.count { console_write(state,error,.ERROR); return; }
    if !console_position_command_ready(state) return;
    if request!=.QUERY && (capture_active() || capture_speed.memory.handle) {
        console_write(state,"Pause or cancel map capture before changing time speed.",.ERROR); return;
    }
    state.pending_speed_change  = true;
    state.pending_speed_request = request;
    state.pending_speed_value   = value;
}

console_run_pending_speed :: (state: *Console_State) {
    if !state.pending_speed_change return;
    ready,waiting := console_submission_ready(state,sends_input=false);
    if waiting return;
    state.pending_speed_change = false;
    game := find_game_window();
    pid  := process_window_pid(game);
    if !ready || editor_save_prompt.active || !game || !console_submission_target_matches(state.submission,game,pid) {
        console_write(state,"Speed command cancelled: focus or the game changed.",.ERROR); return;
    }
    request := state.pending_speed_request;
    if request!=.QUERY && (capture_active() || capture_speed.memory.handle) { console_write(state,"Pause capture and restore its time control before changing speed.",.ERROR); return; }
    if speed_session.memory.handle && (game!=speed_game || pid!=speed_pid || process_memory_has_exited(speed_session.memory)) {
        error := game_speed_close(*speed_session);
        if error.count { console_write(state,error,.ERROR); return; }
    }
    if request==.QUERY {
        // Queries never request write access and do not take ownership.
        query: Game_Speed_Session;
        error := game_speed_open(*query,game,writable=false);
        if error.count { console_write(state,error,.ERROR); return; }
        defer game_speed_close(*query);
        native: float64;
        if !process_read_memory(query.memory.handle,query.layout.native_rate,*native,8) || !game_speed_valid(native) {
            console_write(state,"Could not read the native held-key multiplier.",.ERROR); return;
        }
        console_write(state,tprint("Speed: %x (native held-key multiplier %x; combined %x).",query.last,native,query.last*native));
        return;
    }
    if request==.RESET {
        error := game_speed_close(*speed_session);
        if error.count console_write(state,error,.ERROR);
        else { console_write(state,"Previous time speed restored; control released."); hud_notify("Time speed restored"); }
        return;
    }
    if !speed_session.memory.handle {
        error := game_speed_open(*speed_session,game);
        if error.count { console_write(state,error,.ERROR); return; }
        speed_game = game;
        speed_pid  = pid;
    }
    value := state.pending_speed_value;
    if request==.UP || request==.DOWN value=speed_step(speed_session.last,request==.UP);
    error := game_speed_set(*speed_session,value);
    if error.count { console_write(state,error,.ERROR); return; }
    message := tprint("Speed: %x",value);
    console_write(state,message);
    hud_notify(message);
}

speed_deinit :: () {
    error := game_speed_close(*speed_session);
    if error.count print("Time speed restoration failed: %\n",error);
}
