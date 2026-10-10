#!/usr/bin/env jai

// Read-only: discovers both native multipliers; never changes speed or focus.
#run {
    set_build_options_dc(.{do_output=false});
    session: App.Game_Speed_Session;
    error := App.game_speed_open(*session,App.find_game_window(),writable=false);
    if error.count compiler_report(error);
    else {
        defer App.game_speed_close(*session);
        native: float64;
        if !App.process_read_memory(session.memory.handle,session.layout.native_rate,*native,8) compiler_report("Cannot read native time rate.");
        else print("Speed %x, native %x, combined %x; multiplier RVA 0x%, dt RVA 0x%, clock RVA 0x%.\n",
            session.last,native,session.last*native,
            formatInt(session.layout.multiplier-session.memory.module.base,base=16),
            formatInt(session.layout.delta-session.memory.module.base,base=16),
            formatInt(session.layout.clock-session.memory.module.base,base=16));
    }
}

#import "Basic";
#import "Compiler";
App :: #import,file "../src/main.jai";
