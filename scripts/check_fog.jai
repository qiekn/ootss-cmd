#!/usr/bin/env jai

// Local memory only. Never opens or modifies the game.
#run {
    set_build_options_dc(.{do_output=false});
    check_signature();
    check_upload();
    check_session();
    check_commands();
    print("PASS: % fog checks.\n",checks);
}

checks: s64;
check :: (ok: bool, message: string) {
    checks += 1;
    if !ok { compiler_report(message); assert(ok); }
}

SAMPLE :: u8.[0xf3,0x0f,0x5d,0xc1,0xc7,0x84,0x24,0x84,0x07,0,0,1,0,0,0,
    0x48,0x8b,0x94,0x24,0x20,0x01,0,0,0xf3,0x0f,0x10,0x8a,0x3c,0x03,0,0,
    0xf3,0x0f,0x11,0x8c,0x24,0x8c,0x07,0,0];

check_signature :: () {
    bytes: [128] u8;
    memcpy(bytes.data+5,SAMPLE.data,SAMPLE.count);
    check(Fog.fog_find_instruction(bytes)==5,"Find a unique complete instruction.");
    check(Fog.fog_find_instruction(.[])<0,"Reject empty code.");
    check(Fog.fog_find_instruction(.{data=bytes.data+5,count=SAMPLE.count-1})<0,"Reject truncated code.");
    bytes[16]=0;
    check(Fog.fog_find_instruction(bytes)==5,"Recognize the disabled instruction.");
    bytes[16]=2;
    check(Fog.fog_find_instruction(bytes)<0,"Reject an unknown immediate value.");
    bytes[16]=1;
    bytes[24]=0x10;
    check(Fog.fog_find_instruction(bytes)==5,"Accept a relocated temporary stack slot.");
    bytes[24]=0x11;
    check(Fog.fog_find_instruction(bytes)<0,"Reject an unaligned temporary stack slot.");
    bytes[24]=0x20;
    bytes[12]=0;
    check(Fog.fog_find_instruction(bytes)<0,"Reject a different stack field.");
    memcpy(bytes.data+5,SAMPLE.data,SAMPLE.count);
    memcpy(bytes.data+64,SAMPLE.data,SAMPLE.count);
    check(Fog.fog_find_instruction(bytes)<0,"Reject ambiguous matches.");
}

check_upload :: () {
    pattern := u8.[0x48,0x8d,0x84,0x24,0,0x06,0,0,0x48,0x89,0x44,0x24,0x20,
        0xc6,0x44,0x24,0x30,0,0xc6,0x44,0x24,0x28,0,
        0x48,0x8d,0x0d,0,0,0,0,0x48,0x8d,0x15,0,0,0,0,
        0x45,0x31,0xc0,0x41,0xb9,0xe0,0x01,0,0,0xe8];
    bytes: [512] u8;
    memcpy(bytes.data+140,pattern.data,pattern.count);
    check(Fog.fog_find_upload(bytes,0)==140,"Discover the upload without a fixed instruction distance.");
    bytes[140+26]=0xa7;
    check(Fog.fog_find_upload(bytes,0)==140,"Allow relocated RIP-relative references.");
    bytes[140+42]=0xd0;
    check(Fog.fog_find_upload(bytes,0)<0,"Reject a different parameter upload size.");
    bytes[140+42]=0xe0;
    memcpy(bytes.data+250,pattern.data,pattern.count);
    check(Fog.fog_find_upload(bytes,0)<0,"Reject ambiguous nearby uploads.");
    check(Fog.fog_find_upload(.[],0)<0 && Fog.fog_find_upload(bytes,-1)<0,"Reject empty code and invalid search offsets.");
}

check_session :: () {
    page := cast(*u8)Win.VirtualAlloc(null,4096,Win.MEM_RESERVE|Win.MEM_COMMIT,Win.PAGE_READWRITE);
    check(page!=null,"Allocate an isolated local memory fixture.");
    defer Win.VirtualFree(page,0,Win.MEM_RELEASE);
    memcpy(page,SAMPLE.data,SAMPLE.count);
    session: Fog.Fog_Session;
    session.memory.handle = Win.GetCurrentProcess();
    session.instruction   = cast(u64)page;
    session.writable      = true;
    for byte: SAMPLE session.code[it_index]=byte;
    check(!Fog.fog_session_disable(*session).count && session.changed && page[11]==0,"Disable only the owned immediate.");
    info: Win.MEMORY_BASIC_INFORMATION;
    check(Win.VirtualQuery(page,*info,size_of(Win.MEMORY_BASIC_INFORMATION))>0 && info.Protect==Win.PAGE_READWRITE,
          "Restore the original page protection after a code write.");
    check(!Fog.fog_session_disable(*session).count && session.changed,"Repeated disable retains ownership.");
    page[19]=0x10;
    check(Fog.fog_session_close(*session).count>0 && page[11]==0,"Even a supported stack-slot change invalidates an active session.");
    page[19]=SAMPLE[19];
    page[0]=0;
    check(Fog.fog_session_close(*session).count>0 && session.memory.handle!=null && page[11]==0,
          "Foreign code changes block restoration and retain retry state.");
    page[0]=SAMPLE[0];
    check(!Fog.fog_session_close(*session).count && page[11]==1 && !session.memory.handle,"Restore and release after validation succeeds.");
    check(!Fog.fog_session_close(*session).count,"Closing an empty session is safe.");
    session.memory.handle = Win.GetCurrentProcess();
    session.instruction   = cast(u64)page;
    session.writable      = true;
    for byte: SAMPLE session.code[it_index]=byte;
    page[11]=0;
    check(!Fog.fog_session_disable(*session).count && !session.changed,"Do not claim an already disabled switch.");
    check(!Fog.fog_session_close(*session).count && page[11]==0,"Preserve a switch disabled before this session.");
    session.memory.handle = Win.GetCurrentProcess();
    session.instruction   = cast(u64)page;
    for byte: SAMPLE session.code[it_index]=byte;
    check(Fog.fog_session_write(*session,1).count>0 && page[11]==0,"Read-only diagnosis cannot toggle fog.");
    check(!Fog.fog_session_close(*session).count,"Read-only cleanup does not write.");
}

check_commands :: () {
    state: App.Console_State;
    defer App.console_deinit(*state);
    App.console_execute_command(*state,"UNFOG");
    check(state.pending_fog_change && !state.pending_fog_enabled,"Queue case-insensitive unfog without touching memory.");
    state.pending_fog_change = false;
    App.console_execute_command(*state,"FoG");
    check(state.pending_fog_change && state.pending_fog_enabled,"Queue case-insensitive fog.");
    state.pending_fog_change = false;
    App.command_fog(*state,"extra");
    check(!state.pending_fog_change,"Reject extra arguments.");
    state.pending_position_change = true;
    App.command_unfog(*state,"");
    check(!state.pending_fog_change,"Do not replace an already queued position command.");
    state.pending_position_change = false;
    App.console_set_input(*state,"unfo");
    App.console_complete(*state,.[],.[],.[]);
    check(App.console_input(*state)=="unfog ","Complete unfog.");
    App.console_set_input(*state,"fo");
    App.console_complete(*state,.[],.[],.[]);
    check(App.console_input(*state)=="fog ","Complete fog.");
}

#import "Basic";
#import "Compiler";
Win :: #import "Windows";
Fog :: #import,file "../src/game/fog_memory.jai";
App :: #import,file "../src/main.jai";
