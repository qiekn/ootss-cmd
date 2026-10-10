#!/usr/bin/env jai

// Isolated fixture memory only. No game access, input, focus changes or captures.
#run {
    set_build_options_dc(.{do_output=false});
    check_commands();
    check_memory();
    print("PASS: % speed checks; no game writes.\n",checks);
}

checks: s64;
check :: (ok: bool, message: string) {
    checks+=1;
    if !ok { compiler_report(message); assert(ok); }
}

check_commands :: () {
    for value: string.["0","0.25","1.25","1.5","3.5","4","2.5e-1"] {
        request,speed,error := App.speed_parse(value);
        check(!error.count && request==.SET && App.game_speed_valid(speed),"Accept fractional, zero and scientific speed values.");
    }
    for value: string.["-1","4.01","nan","inf","1 2","1x","0.25 junk"] {
        request,speed,error := App.speed_parse(value);
        check(error.count>0,"Reject invalid or unsupported speeds before any write.");
    }
    request,speed,error := App.speed_parse("");
    check(!error.count && request==.QUERY,"Bare speed is a read-only query.");
    request,speed,error = App.speed_parse("ReSeT");
    check(!error.count && request==.RESET,"Reset is case insensitive.");
    steps := float64.[0.25,0.5,1,1.25,1.5,1.75,2,3,4];
    for value:steps {
        check(App.speed_step(value,true)==steps[min(it_index+1,steps.count-1)],"Bracket up follows the requested presets.");
        check(App.speed_step(value,false)==steps[max(it_index-1,0)],"Bracket down follows the requested presets.");
    }
    check(App.speed_step(3.5,false)==3 && App.speed_step(3.5,true)==4,"Custom 3.5x steps to the nearest preset in either direction.");
    check(App.speed_step(0,false)==0 && App.speed_step(0,true)==0.25,"Pause stays paused on down and resumes at 0.25x on up.");
    state: App.Console_State;
    defer App.console_deinit(*state);
    App.command_speed(*state,"1.25");
    check(state.pending_speed_change && state.pending_speed_value==1.25,"Queue an exact custom multiplier.");
    state.pending_speed_change = false;
    App.capture.phase          = .MOVE;
    App.command_speed(*state,"2");
    check(!state.pending_speed_change,"Capture exclusively owns speed changes.");
    App.capture.phase = .IDLE;
    App.console_set_input(*state,"spe");
    App.console_complete(*state,.[],.[],.[]);
    check(App.console_input(*state)=="speed ","Speed command completion.");
    App.console_set_input(*state,"speed res");
    App.console_complete(*state,.[],.[],.[]);
    check(App.console_input(*state)=="speed reset ","Speed argument completion.");
    keys: App.Shortcut_State=.{enabled=true,game=cast(Win.HWND)123,pid=123};
    consume,trigger := App.shortcut_filter_key(*keys,.[],0xdb,true,false,keys.game,speed_keys=true);
    check(consume && trigger && keys.queue_count==1 && keys.queue[0].index==-1,"Left bracket queues one speed decrease.");
    consume,trigger = App.shortcut_filter_key(*keys,.[],0xdb,true,false,keys.game,speed_keys=true);
    check(consume && !trigger && keys.queue_count==1,"Autorepeat cannot change speed repeatedly.");
    consume,trigger = App.shortcut_filter_key(*keys,.[],0xdb,false,false,keys.game,speed_keys=false);
    check(consume && !trigger,"Consume matching release even if editor opened.");
    consume,trigger = App.shortcut_filter_key(*keys,.[],0xdd,true,false,keys.game,speed_keys=false);
    check(!consume && !trigger,"Editor bracket behavior has priority over built-in speed keys.");
    App.shortcut_filter_key(*keys,.[],0xdd,false,false,keys.game);
    consume,trigger = App.shortcut_filter_key(*keys,.[],0xdd,true,true,keys.game,speed_keys=true);
    check(!consume && !trigger,"Injected brackets never change speed.");
    consume,trigger = App.shortcut_filter_key(*keys,.[],0xdd,true,false,cast(Win.HWND)456,speed_keys=true);
    check(!consume && !trigger && !keys.queue_count,"Unrelated focus cancels queued speed changes.");
    App.shortcut_filter_key(*keys,.[],0xdd,false,false,keys.game);
    bindings := App.Command_Shortcut.[.{vk=0xdd,command="custom",consume=true}];
    consume,trigger = App.shortcut_filter_key(*keys,bindings,0xdd,true,false,keys.game,speed_keys=true);
    check(consume && trigger && keys.queue[0].index==0,"Explicit user mapping overrides the built-in speed bracket.");
    pose: App.Game_Camera_Snapshot=.{position=.[80,69,80],orientation=App.GAME_CAMERA_TOPDOWN};
    check(App.capture_map_view_valid(pose,80),"Accept the observed Q view geometry.");
    pose.position[2]=40;
    check(!App.capture_map_view_valid(pose,80),"Reject a different camera height before capture.");
    pose.position[2]=80; pose.orientation=.[0,0,0,1];
    check(!App.capture_map_view_valid(pose,80),"Reject the regular oblique camera.");
}

put :: (bytes: [] u8, offset: s64, value: $T) { (cast(*T)(bytes.data+offset)).*=value; }

check_memory :: () {
    bytes := NewArray(4096,u8);
    defer free(bytes.data);
    chain := u8.[0xf2,0x0f,0x59,0x05,0,0,0,0,0xf2,0x0f,0x59,0x05,0,0,0,0,
        0xf2,0x0f,0x5a,0xc0,0xf3,0x0f,0x11,0x05,0,0,0,0,0xf3,0x0f,0x5a,0xc0,
        0xf2,0x0f,0x58,0x05,0,0,0,0,0xf2,0x0f,0x11,0x05,0,0,0,0];
    initial := u8.[0x0f,0x28,0x05,0,0,0,0,0x0f,0x11,0x05,0,0,0,0,0x4c,0x8d,0xa4,0x24,0,0,0,0];
    memcpy(bytes.data+32,chain.data,chain.count);
    memcpy(bytes.data+128,initial.data,initial.count);
    put(bytes,36,cast(s32)(520-40)); put(bytes,44,cast(s32)(512-48));
    put(bytes,56,cast(s32)(528-60)); put(bytes,68,cast(s32)(536-72)); put(bytes,76,cast(s32)(536-80));
    put(bytes,131,cast(s32)(560-135)); put(bytes,138,cast(s32)(512-142));
    base         := cast(u64)bytes.data;
    layout,error := App.game_speed_layout_from_code(bytes,base);
    check(!error.count && layout.multiplier==base+520 && layout.native_rate==base+512,"Discover relocated multiplier and independent initialization.");
    ignored,bad := App.game_speed_layout_from_code(.[],base);
    check(bad.count>0,"Reject empty code.");
    ignored,bad = App.game_speed_layout_from_code(.{data=bytes.data,count=149},base);
    check(bad.count>0,"Reject truncated initialization evidence.");
    bytes[68]+=8;
    ignored,bad = App.game_speed_layout_from_code(bytes,base);
    check(bad.count>0,"Reject inconsistent accumulated-clock references.");
    bytes[68]-=8;
    memcpy(bytes.data+256,bytes.data+32,48);
    ignored,bad = App.game_speed_layout_from_code(bytes,base);
    check(bad.count>0,"Reject ambiguous time update chains.");
    memset(bytes.data+256,0,48);
    put(bytes,520,cast(float64)1.25);
    session: App.Game_Speed_Session=.{memory=.{handle=Win.GetCurrentProcess()},layout=layout,original=1.25,last=1.25,writable=true};
    check(!App.game_speed_set(*session,0).count && (cast(*float64)(bytes.data+520)).*==0,"Pause an isolated time multiplier.");
    check(App.game_speed_set(*session,4.01).count>0 && (cast(*float64)(bytes.data+520)).*==0,"Reject out-of-range writes without mutation.");
    bytes[32]^=1;
    check(App.game_speed_close(*session).count>0 && session.memory.handle!=null,"Changed code blocks restoration and retains retry ownership.");
    bytes[32]^=1;
    check(!App.game_speed_close(*session).count && (cast(*float64)(bytes.data+520)).*==1.25,"Restore the exact previous custom speed after validation recovers.");
    check(!App.game_speed_close(*session).count,"Closing twice is safe.");
    for action:0..2 {
        put(bytes,520,cast(float64)1.75);
        App.capture_speed = .{memory=.{handle=Win.GetCurrentProcess()},layout=layout,original=1.75,last=1.75,writable=true};
        check(!App.game_speed_set(*App.capture_speed,0).count,"Capture owns its independent saved multiplier.");
        App.hud.enabled   = false;
        App.capture.phase = .MOVE;
        if action==0 App.capture_pause("isolated test pause");
        if action==1 { App.capture.pending=copy_string("cancel"); App.capture_requests(); }
        if action==2 App.capture_deinit();
        check(!App.capture_speed.memory.handle && (cast(*float64)(bytes.data+520)).*==1.75,"Pause, cancel and shutdown restore the exact pre-capture speed.");
        App.capture_clear();
    }
    session = .{memory=.{handle=Win.GetCurrentProcess()},layout=layout,original=1.75,last=1.75,writable=true};
    check(!App.game_speed_set(*session,0).count,"Acquire multiplier ownership.");
    put(bytes,520,cast(float64)2);
    check(App.game_speed_set(*session,1).count>0,"An outside change blocks further owned writes.");
    check(!App.game_speed_close(*session).count && (cast(*float64)(bytes.data+520)).*==2,"Cleanup preserves another owner's changed value.");
    session = .{memory=.{handle=Win.GetCurrentProcess()},layout=layout,original=2,last=2};
    check(App.game_speed_set(*session,0).count>0,"A read-only session refuses all writes.");
    App.game_speed_close(*session);
}

#import "Basic";
#import "Compiler";
#import "Math";
Win :: #import "Windows";
App :: #import,file "../src/main.jai";
