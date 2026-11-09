#!/usr/bin/env jai

// Isolated camera controls and restoration checks; no game access or input.
#run {
    set_build_options_dc(.{do_output=false});
    check_controls();
    check_absolute_camera();
    print("PASS: % isolated camera checks; no game writes or input.\n",checks);
}

checks: s64;
check :: (value:bool,message:string) {
    checks+=1;
    if !value { compiler_report(message); assert(value); }
}

put :: (bytes:[]u8,offset:s64,value:$T) {
    assert(offset>=0 && offset+size_of(T)<=bytes.count);
    (cast(*T)(bytes.data+offset)).*=value;
}

check_absolute_camera :: () {
    bytes := NewArray(0x10000,u8);
    defer free(bytes.data);
    base := cast(u64)bytes.data;
    put(bytes,0,cast(u16)0x5a4d); put(bytes,0x3c,cast(u32)0x80);
    put(bytes,0x80,cast(u32)0x4550); put(bytes,0x84,cast(u16)0x8664);
    put(bytes,0x86,cast(u16)1); put(bytes,0x94,cast(u16)0xf0); put(bytes,0x98,cast(u16)0x20b);
    put(bytes,0x190,cast(u32)0xe000); put(bytes,0x194,cast(u32)0x2000); put(bytes,0x1ac,cast(u32)0xc0000040);
    locator: App.Game_Manager_Locator=.{slot=base+0x2000,instruction=base+0x1000,count=1};
    locator.bytes[0]=0x90; bytes[0x1000]=0x90;
    layout: App.Game_Camera_Layout=.{manager=locator,mode=base+0x2008,position=0x600,orientation=0x618,projection=0x628,cameras=0x538};
    for *code:layout.code {
        offset := 0x1100+it_index;
        bytes[offset]=0x90;
        code.address = base+cast(u64)offset; code.count=1; code.bytes[0]=0x90;
    }
    name := "overworld";
    for c:name bytes[0x3000+it_index]=c;
    type_name := "Camera_Control";
    for c:type_name bytes[0x3100+it_index]=c;
    info: App.Game_Entity_Type=.{kind=7,size=0x120,name_length=cast(u64)type_name.count,name_data=base+0x3100};
    put(bytes,0x3200,info);
    put(bytes,0x2000,base+0x4000); put(bytes,0x2008,cast(s64)2);
    scene_name: App.Game_Entity_List=.{count=cast(u64)name.count,data=base+0x3000};
    list:       App.Game_Entity_List=.{count=1,data=base+0x7000};
    put(bytes,0x4000,scene_name); put(bytes,0x4538,list); put(bytes,0x7000,base+0x6000);
    put(bytes,0x60f0,base+0x4000); put(bytes,0x6100,cast(u32)7); put(bytes,0x6108,base+0x3200);
    original: App.Game_Camera_Snapshot=.{scene=.{locator=locator,manager=base+0x4000,name=scene_name},list=list,
        position = .[999999,3,20],orientation=.[0,0,0,1],projection=.[1,0.1,1000],mode=0};
    for c:name original.name[it_index]=c;
    original.entities[0]=.{address=base+0x6000,type=base+0x3200,id=7,size=0x120};
    put(bytes,0x4600,original.position); put(bytes,0x4618,original.orientation); put(bytes,0x4628,original.projection);
    session: App.Game_Camera_Session=.{memory=.{handle=Win.GetCurrentProcess(),module=.{base=base,size=cast(u64)bytes.count}},
        layout = layout,original=original,position=original.position,orientation=original.orientation,owns_mode=true,settled=true};
    pose,error := App.game_camera_read_session(*session);
    check(!error.count,"Isolated native camera session validates.");
    changed: bool;
    error,changed = App.game_camera_set_position(*session,.[0.1234567,-0.000125,19.75]);
    check(!error.count && changed && session.position[0]==cast(float)0.1234567,"Absolute write avoids catastrophic delta cancellation.");
    pose,error = App.game_camera_read_session(*session);
    check(!error.count && pose.position[0]==session.position[0] && pose.position[1]==-0.000125 && pose.position[2]==19.75,"Read back all absolute camera coordinates.");
    error,changed = App.game_camera_move(*session,.[0,0,0],App.GAME_CAMERA_TOPDOWN);
    check(!error.count && changed,"Exact top-down orientation can be written independently.");
    check(App.game_camera_grid_view_current(session.memory, layout, original, .[0, 1, 0], .[0, 1, 0]),
          "Read-only view validation accepts the current screen grid direction.");
    put(bytes, 0x4618, App.game_camera_orientation(PI64, -PI64 / 4));
    check(!App.game_camera_grid_view_current(session.memory, layout, original, .[0, 1, 0], .[0, 1, 0]),
          "A view turn before player movement rejects the stale direction.");
    put(bytes, 0x4618, session.orientation);
    App.freecam.session = session;
    error, changed      = App.freecam_center_topdown();
    check(error.count > 0 && !changed, "Missing player selection cannot move the topdown camera.");
    App.freecam   = .{};
    error,changed = App.game_camera_set_position(*session,.[1000001,0,0]);
    check(error.count>0 && !changed,"Out-of-range camera writes are rejected before mutation.");
    error,changed = App.game_camera_set_position(*session,session.position);
    check(!error.count && !changed,"Setting the current camera is a no-op.");
    bytes[0x1100]^=1;
    error,changed = App.game_camera_set_position(*session,.[1,2,3]);
    check(error.count>0 && !changed,"Changed code evidence blocks camera writes.");
    bytes[0x1100]^=1;
    error = App.game_camera_end(*session);
    check(!error.count && !session.owns_mode,"Camera session releases native mode.");
    restored: App.Game_Position;
    App.process_read_memory(session.memory.handle,base+0x4600,*restored,12);
    for i:0..2 check(restored[i]==original.position[i],"Restore original camera position.");
    rotation: [4]float;
    App.process_read_memory(session.memory.handle,base+0x4618,*rotation,16);
    for i:0..3 check(rotation[i]==original.orientation[i],"Restore original orientation, not the top-down pose.");
    check((cast(*s64)(bytes.data+0x2008)).*==0,"Restore the original native camera mode.");
}

check_controls :: () {
    q := App.GAME_CAMERA_TOPDOWN;
    check(App.game_camera_orientation_valid(q),"Top-down is a unit quaternion.");
    forward := App.game_camera_movement(q,1,0,0,1);
    right   := App.game_camera_movement(q,0,1,0,1);
    check(forward[0]==0 && forward[1]==0 && forward[2]==-1,"Top-down points exactly at the ground.");
    check(right[0]==1 && right[1]==0 && right[2]==0,"Screen right is world east.");
    up_x := 2*(q[0]*q[2]+q[1]*q[3]);
    up_y := 2*(q[1]*q[2]-q[0]*q[3]);
    check(up_x==0 && up_y==1,"Screen up is world north.");
    // Pan and topdown translate along the frozen view's screen directions;
    // press each direction at north-up and at a half-turn view.
    for mode:App.Freecam_Mode.[.PAN,.TOPDOWN] {
        for key:0..5 {
            App.freecam                     = .{};
            App.freecam.mode                = mode;
            App.freecam.session.orientation = App.GAME_CAMERA_TOPDOWN;
            App.freecam.tapped[key]=true;
            delta := App.freecam_frame_delta(1,120);
            axis  := ifx key<2 then 1 else ifx key<4 then 0 else 2;
            sign  := ifx key==0 || key==3 || key==5 then 1 else -1;
            for i:0..2 check(delta[i]==cast(float)(ifx i==axis then sign else 0),"Panning keys follow the screen axes at north-up.");
        }
    }
    for mode:App.Freecam_Mode.[.PAN,.TOPDOWN] {
        App.freecam                     = .{};
        App.freecam.mode                = mode;
        App.freecam.session.orientation = App.game_camera_orientation(PI64,-PI64/2);
        App.freecam.tapped[0]=true;
        delta := App.freecam_frame_delta(1,120);
        check(delta[0]==-1 && delta[1]==0 && delta[2]==0,"At a half-turn view, W moves world -X.");
        App.freecam                     = .{};
        App.freecam.mode                = mode;
        App.freecam.session.orientation = App.game_camera_orientation(PI64,-PI64/2);
        App.freecam.tapped[3]=true;
        delta = App.freecam_frame_delta(1,120);
        check(delta[0]==0 && delta[1]==1 && delta[2]==0,"At a half-turn view, D moves world +Y.");
    }
    App.freecam = .{};
    for args:string.["-topdown","enable -TOPDOWN","-topdown enable","-pan"] {
        state: App.Console_State;
        defer App.console_deinit(*state);
        App.command_freecam(*state,args);
        check(state.pending_action==.FREECAM,"Accept valid camera mode.");
        check(state.pending_freecam_topdown==(args!="-pan"),"Keep top-down distinct from existing pan.");
    }
    for args:string.["-top","-topdown -pan","-topdown -topdown","disable -topdown","enable disable"] {
        state: App.Console_State;
        defer App.console_deinit(*state);
        App.command_freecam(*state,args);
        check(state.pending_action==.NONE,"Reject invalid camera mode without queuing.");
    }
    state: App.Console_State;
    defer App.console_deinit(*state);
    App.command_set(*state,"camera -1.25 2e2 0.125");
    check(state.pending_action==.SET_CAMERA && state.pending_camera_position[0]==-1.25 && state.pending_camera_position[1]==200,"Absolute float camera coordinates.");
    for args:string.["camera 1 2","camera nan 2 3","camera 1e10 2 3","camera 1 2 3 4"] {
        state.pending_action = .NONE;
        App.command_set(*state,args);
        check(state.pending_action==.NONE,"Invalid camera coordinates do not queue a write.");
    }
    state.pending_action = .NONE;
    App.command_show(*state,"CAMERA");
    check(state.pending_action==.SHOW_CAMERA,"Camera query is case-insensitive.");
    App.console_set_input(*state,"freecam -topd");
    App.console_complete(*state,.[],.[],.[]);
    check(App.console_input(*state)=="freecam -topdown ","Complete the topdown option.");
}

#import "Basic";
#import "Compiler";
#import "Math";
App :: #import,file "../src/main.jai";
Win :: #import "Windows";
