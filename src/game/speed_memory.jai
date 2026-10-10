Game_Speed_Layout :: struct {
    multiplier, native_rate, delta, clock, initial: u64;
    code:                                           [2] Game_Camera_Code;
}

Game_Speed_Session :: struct {
    memory:            Process_Memory;
    layout:            Game_Speed_Layout;
    original, last:    float64;
    writable, changed: bool;
}

GAME_SPEED_MAX :: 4.0;

game_speed_valid :: (value: float64) -> bool {
    return is_finite(value) && value >= 0 && value <= GAME_SPEED_MAX;
}

// Both multipliers feed simulation dt and its accumulated clock. Discover the
// data through this complete chain and its independent initialization evidence.
game_speed_layout_from_code :: (code: [] u8, base: u64) -> (layout: Game_Speed_Layout, error: string) {
    layout: Game_Speed_Layout;
    at := game_camera_find_code(code, s16.[
        0xf2,0x0f,0x59,0x05,-1,-1,-1,-1, 0xf2,0x0f,0x59,0x05,-1,-1,-1,-1,
        0xf2,0x0f,0x5a,0xc0, 0xf3,0x0f,0x11,0x05,-1,-1,-1,-1,
        0xf3,0x0f,0x5a,0xc0, 0xf2,0x0f,0x58,0x05,-1,-1,-1,-1,
        0xf2,0x0f,0x11,0x05,-1,-1,-1,-1]);
    init := game_camera_find_code(code, s16.[0x0f,0x28,0x05,-1,-1,-1,-1,0x0f,0x11,0x05,-1,-1,-1,-1,
        0x4c,0x8d,0xa4,0x24,-1,-1,-1,-1]);
    if at < 0 || init < 0 return layout,"Unsupported game build: time multiplier evidence is missing or ambiguous.";
    layout.multiplier  = game_speed_rip(code,base,at,4,8);
    layout.native_rate = game_speed_rip(code,base,at+8,4,8);
    layout.delta       = game_speed_rip(code,base,at+20,4,8);
    layout.clock       = game_speed_rip(code,base,at+32,4,8);
    layout.initial     = game_speed_rip(code,base,init,3,7);
    if layout.multiplier != layout.native_rate+8 || layout.multiplier%8 || layout.delta%4 || layout.clock%8 ||
       layout.delta==layout.multiplier || layout.delta==layout.native_rate || layout.clock==layout.multiplier ||
       layout.clock==layout.native_rate || layout.clock==layout.delta ||
       game_speed_rip(code,base,at+40,4,8)!=layout.clock ||
       game_speed_rip(code,base,init+7,3,7)!=layout.native_rate return .{},"Time multiplier dataflow differs from the supported layout.";
    if !game_camera_save_code(*layout.code[0],code,base,at,48) ||
       !game_camera_save_code(*layout.code[1],code,base,init,22) return .{},"Invalid time code bounds.";
    return layout,"";
}

game_speed_rip :: (code: [] u8, base: u64, at: s64, displacement: s64, length: s64) -> u64 {
    return cast(u64)(cast(s64)base+at+length+(cast(*s32)(code.data+at+displacement)).*);
}

game_speed_open :: (session: *Game_Speed_Session, window: Win.HWND, writable := true) -> string {
    if session.memory.handle return "A time speed session is already open.";
    memory,error := process_open_memory(window,GAME_EXECUTABLE,writable=writable);
    if error.count return error;
    keep := false;
    defer if !keep process_close_memory(*memory);
    code,rva,code_error := process_read_module_code(memory);
    defer free(code.data);
    if code_error.count return code_error;
    layout,layout_error := game_speed_layout_from_code(code,memory.module.base+rva);
    if layout_error.count return layout_error;
    for address: u64.[layout.multiplier,layout.native_rate,layout.clock,layout.delta] {
        if !process_module_writable_data(memory,address,8) return "Time layout does not refer to writable non-executable module data.";
    }
    initial: [2] float64;
    if !process_module_contains(memory.module,layout.initial,16) ||
       !process_read_memory(memory.handle,layout.initial,*initial,16) || initial[0]!=1 || initial[1]!=1
        return "Time multipliers do not initialize to the expected 1x defaults.";
    session.* = .{memory=memory,layout=layout,writable=writable};
    value,read_error := game_speed_read(session);
    if read_error.count { session.*=.{}; return read_error; }
    session.original = value;
    session.last     = value;
    keep             = true;
    return "";
}

game_speed_read :: (session: *Game_Speed_Session) -> (value: float64, error: string) {
    if !session.memory.handle return 0,"No time speed session is open.";
    for evidence: session.layout.code {
        bytes: [96] u8;
        if evidence.count<=0 || evidence.count>bytes.count ||
           !process_read_memory(session.memory.handle,evidence.address,*bytes,cast(u64)evidence.count)
            return 0,"Time code became unreadable; no memory overwritten.";
        for i: 0..evidence.count-1 if bytes[i]!=evidence.bytes[i] return 0,"Time code changed; no memory overwritten.";
    }
    value: float64;
    if !process_read_memory(session.memory.handle,session.layout.multiplier,*value,8) || !game_speed_valid(value)
        return 0,"Time multiplier is unreadable or outside the supported range 0-4.";
    return value,"";
}

game_speed_set :: (session: *Game_Speed_Session, value: float64) -> string {
    if !session.writable || !game_speed_valid(value) return "Speed must be a finite number from 0 to 4 in a writable session.";
    current,error := game_speed_read(session);
    if error.count return error;
    if current!=session.last return "Time speed changed outside this session; no memory overwritten.";
    if value==current return "";
    // Retain restore ownership even if the write succeeds but verification fails.
    session.last    = value;
    session.changed = true;
    ok,written          := process_write_memory(session.memory.handle,session.layout.multiplier,*value,8);
    observed,read_error := game_speed_read(session);
    if !ok || written!=8 || read_error.count || observed!=value return "Could not write and verify time speed; restoration is required.";
    return "";
}

game_speed_close :: (session: *Game_Speed_Session) -> string {
    if !session.memory.handle return "";
    if session.changed && !process_memory_has_exited(session.memory) {
        value,error := game_speed_read(session);
        if error.count return error;
        if value==session.last {
            error = game_speed_set(session,session.original);
            if error.count return error;
        }
        // A reset/other owner changed the value: leave their value in place.
    }
    process_close_memory(*session.memory);
    session.*=.{};
    return "";
}
