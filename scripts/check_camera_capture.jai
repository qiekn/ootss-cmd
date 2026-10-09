#!/usr/bin/env jai

// Isolated memory-free camera controls, grid geometry and synthetic PNG checks.
#run {
    set_build_options_dc(.{do_output=false});
    set_working_directory(tprint("%/..",#filepath));
    check_controls();
    check_absolute_camera();
    check_grid();
    check_pixels();
    check_restart();
    check_scaled_png();
    print("PASS: % camera/capture checks. Synthetic frames: .build/map-fixture\n",checks);
}

checks:s64;
check :: (value:bool,message:string) {
    checks+=1;
    if !value { compiler_report(message); assert(value); }
}

put :: (bytes:[]u8,offset:s64,value:$T) {
    assert(offset>=0 && offset+size_of(T)<=bytes.count);
    (cast(*T)(bytes.data+offset)).*=value;
}

check_absolute_camera :: () {
    bytes:=NewArray(0x10000,u8);
    defer free(bytes.data);
    base:=cast(u64)bytes.data;
    put(bytes,0,cast(u16)0x5a4d); put(bytes,0x3c,cast(u32)0x80);
    put(bytes,0x80,cast(u32)0x4550); put(bytes,0x84,cast(u16)0x8664);
    put(bytes,0x86,cast(u16)1); put(bytes,0x94,cast(u16)0xf0); put(bytes,0x98,cast(u16)0x20b);
    put(bytes,0x190,cast(u32)0xe000); put(bytes,0x194,cast(u32)0x2000); put(bytes,0x1ac,cast(u32)0xc0000040);
    locator:App.Game_Manager_Locator=.{slot=base+0x2000,instruction=base+0x1000,count=1};
    locator.bytes[0]=0x90; bytes[0x1000]=0x90;
    layout:App.Game_Camera_Layout=.{manager=locator,mode=base+0x2008,position=0x600,orientation=0x618,projection=0x628,cameras=0x538};
    for *code:layout.code {
        offset:=0x1100+it_index;
        bytes[offset]=0x90;
        code.address=base+cast(u64)offset; code.count=1; code.bytes[0]=0x90;
    }
    name:="overworld";
    for c:name bytes[0x3000+it_index]=c;
    type_name:="Camera_Control";
    for c:type_name bytes[0x3100+it_index]=c;
    info:App.Game_Entity_Type=.{kind=7,size=0x120,name_length=cast(u64)type_name.count,name_data=base+0x3100};
    put(bytes,0x3200,info);
    put(bytes,0x2000,base+0x4000); put(bytes,0x2008,cast(s64)2);
    scene_name:App.Game_Entity_List=.{count=cast(u64)name.count,data=base+0x3000};
    list:App.Game_Entity_List=.{count=1,data=base+0x7000};
    put(bytes,0x4000,scene_name); put(bytes,0x4538,list); put(bytes,0x7000,base+0x6000);
    put(bytes,0x60f0,base+0x4000); put(bytes,0x6100,cast(u32)7); put(bytes,0x6108,base+0x3200);
    original:App.Game_Camera_Snapshot=.{scene=.{locator=locator,manager=base+0x4000,name=scene_name},list=list,
        position=.[999999,3,20],orientation=.[0,0,0,1],projection=.[1,0.1,1000],mode=0};
    for c:name original.name[it_index]=c;
    original.entities[0]=.{address=base+0x6000,type=base+0x3200,id=7,size=0x120};
    put(bytes,0x4600,original.position); put(bytes,0x4618,original.orientation); put(bytes,0x4628,original.projection);
    session:App.Game_Camera_Session=.{memory=.{handle=Win.GetCurrentProcess(),module=.{base=base,size=cast(u64)bytes.count}},
        layout=layout,original=original,position=original.position,orientation=original.orientation,owns_mode=true,settled=true};
    pose,error:=App.game_camera_read_session(*session);
    check(!error.count,"Isolated native camera session validates.");
    changed:bool;
    error,changed=App.game_camera_set_position(*session,.[0.1234567,-0.000125,19.75]);
    check(!error.count && changed && session.position[0]==cast(float)0.1234567,"Absolute write avoids catastrophic delta cancellation.");
    pose,error=App.game_camera_read_session(*session);
    check(!error.count && pose.position[0]==session.position[0] && pose.position[1]==-0.000125 && pose.position[2]==19.75,"Read back all absolute camera coordinates.");
    error,changed=App.game_camera_move(*session,.[0,0,0],App.GAME_CAMERA_TOPDOWN);
    check(!error.count && changed,"Exact top-down orientation can be written independently.");
    error,changed=App.game_camera_set_position(*session,.[1000001,0,0]);
    check(error.count>0 && !changed,"Out-of-range camera writes are rejected before mutation.");
    error,changed=App.game_camera_set_position(*session,session.position);
    check(!error.count && !changed,"Setting the current camera is a no-op.");
    bytes[0x1100]^=1;
    error,changed=App.game_camera_set_position(*session,.[1,2,3]);
    check(error.count>0 && !changed,"Changed code evidence blocks camera writes.");
    bytes[0x1100]^=1;
    error=App.game_camera_end(*session);
    check(!error.count && !session.owns_mode,"Camera session releases native mode.");
    restored:App.Game_Position;
    App.process_read_memory(session.memory.handle,base+0x4600,*restored,12);
    for i:0..2 check(restored[i]==original.position[i],"Restore original camera position.");
    rotation:[4]float;
    App.process_read_memory(session.memory.handle,base+0x4618,*rotation,16);
    for i:0..3 check(rotation[i]==original.orientation[i],"Restore original orientation, not the top-down pose.");
    check((cast(*s64)(bytes.data+0x2008)).*==0,"Restore the original native camera mode.");
}

check_controls :: () {
    q:=App.GAME_CAMERA_TOPDOWN;
    check(App.game_camera_orientation_valid(q),"Top-down is a unit quaternion.");
    forward:=App.game_camera_movement(q,1,0,0,1);
    right:=App.game_camera_movement(q,0,1,0,1);
    check(forward[0]==0 && forward[1]==0 && forward[2]==-1,"Top-down points exactly at the ground.");
    check(right[0]==1 && right[1]==0 && right[2]==0,"Screen right is world east.");
    up_x:=2*(q[0]*q[2]+q[1]*q[3]);
    up_y:=2*(q[1]*q[2]-q[0]*q[3]);
    check(up_x==0 && up_y==1,"Screen up is world north.");
    for mode:App.Freecam_Mode.[.PAN,.TOPDOWN] {
        for key:0..5 {
            App.freecam=.{};
            App.freecam.mode=mode;
            App.freecam.tapped[key]=true;
            delta:=App.freecam_frame_delta(1,120);
            axis:=ifx key<2 then 1 else ifx key<4 then 0 else 2;
            sign:=ifx key==0 || key==3 || key==5 then 1 else -1;
            for i:0..2 check(delta[i]==cast(float)(ifx i==axis then sign else 0),"Panning keys use the correct world axis.");
        }
    }
    App.freecam=.{};
    for args:string.["-topdown","enable -TOPDOWN","-topdown enable","-pan"] {
        state:App.Console_State;
        defer App.console_deinit(*state);
        App.command_freecam(*state,args);
        check(state.pending_action==.FREECAM,"Accept valid camera mode.");
        check(state.pending_freecam_topdown==(args!="-pan"),"Keep top-down distinct from existing pan.");
    }
    for args:string.["-top","-topdown -pan","-topdown -topdown","disable -topdown","enable disable"] {
        state:App.Console_State;
        defer App.console_deinit(*state);
        App.command_freecam(*state,args);
        check(state.pending_action==.NONE,"Reject invalid camera mode without queuing.");
    }
    state:App.Console_State;
    defer App.console_deinit(*state);
    App.command_set(*state,"camera -1.25 2e2 0.125");
    check(state.pending_action==.SET_CAMERA && state.pending_camera_position[0]==-1.25 && state.pending_camera_position[1]==200,"Absolute float camera coordinates.");
    for args:string.["camera 1 2","camera nan 2 3","camera 1e10 2 3","camera 1 2 3 4"] {
        state.pending_action=.NONE;
        App.command_set(*state,args);
        check(state.pending_action==.NONE,"Invalid camera coordinates do not queue a write.");
    }
    state.pending_action=.NONE;
    App.command_show(*state,"CAMERA");
    check(state.pending_action==.SHOW_CAMERA,"Camera query is case-insensitive.");
    App.console_set_input(*state,"freecam -topd");
    App.console_complete(*state,.[],.[],.[]);
    check(App.console_input(*state)=="freecam -topdown ","Complete the topdown option.");
    App.capture.phase=.MOVE;
    defer App.capture.phase=.IDLE;
    state.pending_action=.NONE;
    App.command_set(*state,"camera 1 2 3");
    check(state.pending_action==.NONE,"Capture owns camera writes exclusively.");
    App.capture.phase=.WAIT_FOCUS;
    App.console_execute_command(*state,"q");
    check(state.pending_action==.HIDE && App.capture.phase==.WAIT_FOCUS,"Returning from the console must start the queued job, not pause it.");
}

fixture_plan :: () -> Capture_Plan { return .{scene="overworld",xmin=-3,ymin=-5,xmax=27,ymax=15,z=10}; }

check_grid :: () {
    plan:=fixture_plan();
    grid,error:=capture_make_grid(plan,1024,768,cast(float)(PI64/3));
    check(!error.count && grid.columns==3 && grid.rows==3,"Known perspective footprint produces 3 by 3 grid.");
    check(grid.step_x*grid.pixels_per_unit==cast(float64)grid.crop_width,"Pixel-aligned grid width.");
    for index:0..8 {
        frame:=capture_grid_frame(grid,index);
        check(frame.row==index/3 && frame.column==(ifx frame.row&1 then 2-index%3 else index%3),"Snake order retains north-up rows.");
        array_add(*grid.frames,frame);
    }
    defer array_free(grid.frames);
    check(!capture_validate_manifest(grid,true).count,"Complete manifest validates.");
    another:=plan; another.run_id=123;
    check(!capture_plan_equal(plan,another),"A new run cannot resume the previous manifest even with identical coordinates.");
    grid.orientation[0]=0;
    check(capture_validate_manifest(grid,true).count>0,"Reject wrong view orientation.");
    grid.orientation[0]=-0.5;
    grid.frames[3].column+=1;
    check(capture_validate_manifest(grid,true).count>0,"Reject wrong serpentine coordinates.");
    grid.frames[3].column-=1;
    grid.frames.count-=1;
    check(capture_validate_manifest(grid,true).count>0 && !capture_validate_manifest(grid).count,"Incomplete jobs can resume but cannot stitch.");
    grid.frames.count+=1;
    odd,odd_error:=capture_make_grid(plan,1025,769,cast(float)(PI64/3));
    check(!odd_error.count && (odd.width-odd.crop_width)%2==0 && (odd.height-odd.crop_height)%2==0,"Odd resolutions preserve exact crop centers.");
    bad:=plan; bad.z=bad.ground;
    check(capture_validate_plan(bad).count>0,"Camera must be above reference ground.");
    bad=plan; bad.overlap=0.95;
    check(capture_validate_plan(bad).count>0,"Reject excessive overlap.");
    bad=plan; bad.xmax=1000000;
    rejected,reject_error:=capture_make_grid(bad,1024,768,cast(float)(PI64/3));
    check(reject_error.count>0,"Bound grid allocation and output dimensions.");
}

check_pixels :: () {
    directory:=".build/map-fixture";
    check(make_directory_if_it_does_not_exist(directory,true),"Create synthetic fixture directory.");
    grid,error:=capture_make_grid(fixture_plan(),1024,768,cast(float)(PI64/3));
    check(!error.count,"Fixture grid.");
    defer array_free(grid.frames);
    source:=NewArray(grid.width*grid.height*4,u8);
    defer free(source.data);
    for index:0..grid.columns*grid.rows-1 {
        reset_temporary_storage();
        frame:=capture_grid_frame(grid,index);
        for y:0..grid.height-1 for x:0..grid.width-1 {
            px:=source.data+(y*grid.width+x)*4;
            gx:=frame.column*grid.crop_width+x-(grid.width-grid.crop_width)/2;
            gy:=frame.row*grid.crop_height+y-(grid.height-grid.crop_height)/2;
            px[0]=cast(u8)(gx&255); px[1]=cast(u8)(gy&255); px[2]=77; px[3]=255;
        }
        check(!map_write_png(capture_frame_file(directory,index),source.data,grid.width,grid.height).count,"Write synthetic PNG.");
        array_add(*grid.frames,frame);
    }
    check(!capture_atomic_json(tprint("%/manifest.json",directory),grid).count,"Save fixture manifest.");
    ok,loaded:=Json.json_parse_file(tprint("%/manifest.json",directory),Capture_Manifest);
    defer free(loaded.plan.scene); defer array_free(loaded.frames);
    check(ok && !capture_validate_manifest(loaded,true).count,"JSON round-trip preserves exact float grid metadata.");
    pixels:=NewArray(512*512*4,u8);
    parent:=NewArray(512*512*4,u8);
    defer free(pixels.data); defer free(parent.data);
    for ty:0..3 for tx:0..4 {
        reset_temporary_storage();
        check(!map_assemble_tile(loaded,directory,tx,ty,pixels).count,"Assemble a bounded tile across frame seams.");
        valid:=true;
        for y:0..511 for x:0..511 {
            gx:=tx*512+x; gy:=ty*512+y;
            p:=pixels.data+(y*512+x)*4;
            if gx>=grid.columns*grid.crop_width || gy>=grid.rows*grid.crop_height { if p[3]!=0 valid=false; }
            else if p[0]!=(gx&255) || p[1]!=(gy&255) || p[2]!=77 || p[3]!=255 valid=false;
        }
        check(valid,"Stitched pixels match world-coordinate raster, including serpentine seams and transparent edges.");
    }
    memset(pixels.data,0,pixels.count);
    pixels[0]=200; pixels[3]=255;
    map_reduce_child(pixels.data,parent.data,0,0);
    check(parent[0]==200 && parent[3]==64,"Downsample edge alpha without dark fringes.");
    check(map_max_zoom(2148,1608)==3,"Pyramid uses a 512px root tile.");

    output:=".build/map-fixture-output.png";
    check(write_entire_file(output,"old map"),"Seed an existing texture.");
    check(!map_export_png(directory,output).count,"Replace an existing texture with the complete PNG.");
    image,image_error:=map_read_png(output,2148,1608);
    defer map_image_free(*image);
    check(!image_error.count,"Full PNG retains native dimensions.");
    valid:=true;
    for y:0..1607 for x:0..2147 {
        p:=image.pixels+(y*2148+x)*4;
        if p[0]!=(x&255) || p[1]!=(y&255) || p[2]!=77 || p[3]!=255 valid=false;
    }
    check(valid,"Every full PNG pixel matches the north-up synthetic raster across all seams.");
    check(write_entire_file(output,"keep this map"),"Seed texture for failure checks.");
    check(map_export_png(directory,output,123).count>0,"Reject a stale completed capture.");
    grid.frames.count-=1;
    check(!capture_atomic_json(tprint("%/manifest.json",directory),grid).count,"Save incomplete metadata.");
    check(map_export_png(directory,output).count>0,"Incomplete capture cannot replace the texture.");
    grid.frames.count+=1;
    check(!capture_atomic_json(tprint("%/manifest.json",directory),grid).count,"Restore complete metadata.");
    last_file:=capture_frame_file(directory,grid.frames.count-1);
    saved,read_ok:=read_entire_file(last_file);
    defer free(saved);
    check(read_ok && write_entire_file(last_file,"broken png"),"Corrupt the last frame after the other frames decode.");
    check(map_export_png(directory,output).count>0,"A corrupt final frame blocks publishing.");
    check(map_export_png(directory,output,max_side=1200).count>0,"A corrupt final frame also blocks scaled publishing.");
    retained,retained_ok:=read_entire_file(output);
    defer free(retained);
    check(retained_ok && retained=="keep this map","Failed exports retain the previous texture bytes.");
    check(write_entire_file(last_file,saved),"Restore the source fixture.");
    check(!map_export_png(directory,output).count,"A later successful run updates the texture again.");
}

check_restart :: () {
    directory:=".build/capture-reset-fixture";
    check(make_directory_if_it_does_not_exist(directory,true),"Create restart fixture.");
    generated:=string.["manifest.json","manifest.json.tmp","status.json","status.json.tmp","frame_000000.png","frame_099999.png.tmp"];
    retained:=string.["plan.json","run.lock","notes.txt","map.png","frame_custom.png","frame_000000.png.backup"];
    for name:generated check(write_entire_file(tprint("%/%",directory,name),"old"),"Seed generated capture file.");
    for name:retained check(write_entire_file(tprint("%/%",directory,name),"keep"),"Seed retained file.");
    error:=App.capture_load(tprint("%/plan.json",directory),fresh=true);
    check(error.count>0 && file_exists(tprint("%/manifest.json",directory)),"Invalid replacement plan leaves existing capture intact.");
    App.capture.phase=.MOVE;
    error=App.capture_load(tprint("%/plan.json",directory),fresh=true);
    App.capture.phase=.IDLE;
    check(error.count>0 && file_exists(tprint("%/manifest.json",directory)),"Restart cannot erase a running capture.");
    check(!capture_reset_files(directory).count,"Reset generated files.");
    for name:generated check(!file_exists(tprint("%/%",directory,name)),"Generated progress and frames are removed.");
    for name:retained check(file_exists(tprint("%/%",directory,name)),"Plan, lock, texture and unrelated files are retained.");
    check(!capture_reset_files(directory).count,"Reset works repeatedly even without previous progress.");
    status:Capture_Status=.{state="DONE",run_id=123456789012345678};
    check(!capture_atomic_json(tprint("%/status.json",directory),status).count,"Save run identity in completion status.");
    ok,loaded:=Json.json_parse_file(tprint("%/status.json",directory),Capture_Status);
    defer free(loaded.state); defer free(loaded.message);
    check(ok && loaded.run_id==status.run_id,"Run identity round-trips without floating-point loss.");
}

check_scaled_png :: () {
    parsed,manifest:=Json.json_parse_file(".build/map-fixture/manifest.json",Capture_Manifest);
    defer free(manifest.plan.scene); defer array_free(manifest.frames);
    check(parsed,"Read scaled PNG fixture.");
    cw,ch,error:=map_png_layout(manifest,1200);
    check(!error.count && cw*manifest.columns==1074 && ch*manifest.rows==804,"Fit the mosaic without raising the camera.");
    unused_x,unused_y,bad:=map_png_layout(manifest,-1);
    check(bad.count>0,"Reject invalid PNG dimension budgets.");
    unused_x,unused_y,bad=map_png_layout(.{},8192);
    check(bad.count>0,"Reject an empty scaled grid.");
    output:=".build/map-fixture-scaled.png";
    check(!map_export_png(".build/map-fixture",output,max_side=1200).count,"Export a filtered single PNG.");
    image,image_error:=map_read_png(output,1074,804);
    defer map_image_free(*image);
    check(!image_error.count,"Scaled PNG has the expected dimensions.");
    for y:s64.[7,267,268,269,535,536,537] for x:s64.[13,357,358,359,715,716,717] {
        pixel:=image.pixels+(y*1074+x)*4;
        check(abs(cast(s64)pixel[0]-((x*2)&255))<=1 && abs(cast(s64)pixel[1]-((y*2)&255))<=1 &&
              pixel[2]==77 && pixel[3]==255,"Filtering preserves alignment and serpentine row order across seams.");
    }
    world:Capture_Plan=.{scene="overworld",xmin=-40,ymin=-20,xmax=180,ymax=170,z=80,ground=0,overlap=.3,settle_ms=200};
    grid,grid_error:=capture_make_grid(world,3840,2160,cast(float)0.610865235328674316);
    check(!grid_error.count && grid.columns*grid.rows==24,"Height 80 world plan uses 24 frames.");
    cw,ch,error=map_png_layout(grid,8192);
    check(!error.count && cw*grid.columns==5376 && ch*grid.rows==4536,"World frames fit one PNG at half scale.");
}

#load "../src/game/capture_plan.jai";
#load "map_tiles.jai";
#import "Basic";
#import "Compiler";
#import "File";
#import "System";
#import "Math";
App :: #import,file "../src/main.jai";
Json :: #import "Json";
Win :: #import "Windows";
