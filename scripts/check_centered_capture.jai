#!/usr/bin/env jai

// Generated pixels only: never opens the game or takes/displays screenshots.
#run {
    set_build_options_dc(.{do_output=false});
    set_working_directory(tprint("%/..",#filepath));
    check_order();
    check_export();
    print("PASS: % centered capture checks.\n",checks);
}

checks: s64;
check :: (ok: bool, message: string) {
    checks+=1;
    if !ok { compiler_report(message); assert(ok); }
}

check_order :: () {
    for rows:1..7 for columns:1..9 for cy:0..rows-1 for cx:0..columns-1 {
        grid:    Capture_Manifest=.{plan=.{center_first=true},columns=columns,rows=rows,center_column=cx,center_row=cy,step_x=1,step_y=1};
        visited: [63]bool;
        radius:  s64=-1;
        for index:0..rows*columns-1 {
            frame := capture_grid_frame(grid,index);
            check(frame.column>=0 && frame.column<columns && frame.row>=0 && frame.row<rows,"Every ring frame remains in the rectangular grid.");
            cell := frame.row*columns+frame.column;
            check(!visited[cell],"Each clipped ring visits every cell exactly once.");
            visited[cell]=true;
            check(capture_grid_index(grid,frame.column,frame.row)==index,"Constant-time inverse mapping agrees with center-out acquisition.");
            next := max(abs(frame.column-cx),abs(frame.row-cy));
            check(next>=radius,"Acquisition proceeds outward from the anchor.");
            radius = next;
        }
    }
    plan: Capture_Plan=.{version=2,scene="overworld",xmin=-40,ymin=-20,xmax=180,ymax=170,z=80,
        center_first = true,center_x=80,center_y=69,freeze_time=true,require_map_view=true,settle_ms=200};
    grid,error := capture_make_grid(plan,3840,2160,0.478175);
    check(!error.count,"Build the native Q-view world capture grid.");
    first := capture_grid_frame(grid,0);
    check(first.position[0]==80 && first.position[1]==69 && first.position[2]==80,"The first frame is exactly 80,69,80.");
    x,y := capture_grid_origin(grid);
    check(x<=plan.xmin && y>=plan.ymax && x+grid.columns*grid.step_x>=plan.xmax && y-grid.rows*grid.step_y<=plan.ymin,"Anchor-aligned cells cover all requested world bounds.");
    print("Q-view example: % x % = % frames; actual bounds %, % to %, %.\n",grid.columns,grid.rows,grid.columns*grid.rows,x,y-grid.rows*grid.step_y,x+grid.columns*grid.step_x,y);
    cw,ch,size_error := map_image_layout(grid,32768,true);
    check(!size_error.count && cw==grid.crop_width && ch==grid.crop_height && cw*grid.columns==13440 && ch*grid.rows==12096,
          "JPEG retains the full Q-view mosaic instead of the smaller PNG budget.");
    cw,ch,size_error = map_image_layout(grid,32769,true);
    check(size_error.count>0,"Reject JPEG dimensions outside the supported limit.");
    oversized := grid; oversized.columns=1000; oversized.rows=1000;
    cw,ch,size_error = map_image_layout(oversized,0,true);
    check(size_error.count>0,"Native-size JPEG obeys the allocation budget before allocating pixels.");
    for index:0..grid.columns*grid.rows-1 array_add(*grid.frames,capture_grid_frame(grid,index));
    defer array_free(grid.frames);
    check(!capture_validate_manifest(grid,true).count,"The complete centered manifest validates.");
    grid.origin_x+=0.01;
    check(capture_validate_manifest(grid,true).count>0,"Reject shifted world bounds.");
    grid.origin_x = x;
    changed := plan; changed.freeze_time=false;
    check(!capture_plan_equal(plan,changed),"Resume cannot silently change time-freeze behavior.");
    changed = plan; changed.center_x+=1;
    check(!capture_plan_equal(plan,changed),"Resume cannot silently change the grid anchor.");
    changed = plan; changed.version=1;
    check(capture_validate_plan(changed).count>0,"Version 1 cannot silently ignore new options.");
    changed = plan; changed.center_y=1000;
    check(capture_validate_plan(changed).count>0,"Reject an anchor outside the requested bounds.");
}

check_export :: () {
    directory := ".build/centered-map-fixture";
    check(make_directory_if_it_does_not_exist(directory,true),"Create isolated generated-frame directory.");
    plan: Capture_Plan=.{version=2,scene="overworld",xmin=-3,ymin=-5,xmax=27,ymax=15,z=10,
        center_first = true,center_x=12,center_y=5};
    grid,error := capture_make_grid(plan,64,64,cast(float)(PI64/3));
    check(!error.count,"Create small centered export fixture.");
    defer array_free(grid.frames);
    source := NewArray(grid.width*grid.height*4,u8);
    defer free(source.data);
    for index:0..grid.columns*grid.rows-1 {
        auto_release_temp();
        frame := capture_grid_frame(grid,index);
        for i:0..grid.width*grid.height-1 {
            source[i*4]=cast(u8)(frame.column*20);
            source[i*4+1]=cast(u8)(frame.row*20);
            source[i*4+2]=cast(u8)index;
            source[i*4+3]=255;
        }
        check(!map_write_png(capture_frame_file(directory,index),source.data,grid.width,grid.height).count,"Save generated ring-order PNG.");
        array_add(*grid.frames,frame);
    }
    check(!capture_atomic_json(tprint("%/manifest.json",directory),grid).count,"Save version 2 metadata.");
    ok,loaded := Json.json_parse_file(tprint("%/manifest.json",directory),Capture_Manifest);
    defer free(loaded.plan.scene); defer array_free(loaded.frames);
    check(ok && !capture_validate_manifest(loaded,true).count,"Round-trip centered geometry at full float precision.");
    width  := grid.columns*grid.crop_width; height:=grid.rows*grid.crop_height;
    pixels := NewArray(width*height*4,u8);
    defer free(pixels.data);
    check(!map_assemble_region(loaded,directory,0,0,width,height,pixels).count,"Assemble north-up mosaic from ring-order frames.");
    for y:0..height-1 for x:0..width-1 {
        row   := y/grid.crop_height; column:=x/grid.crop_width;
        pixel := pixels.data+(y*width+x)*4;
        if pixel[0]!=column*20 || pixel[1]!=row*20 || pixel[2]!=capture_grid_index(grid,column,row) || pixel[3]!=255 {
            check(false,"Every output pixel must come from the correct ring-order source frame."); return;
        }
    }
    check(true,"All full-size stitched pixels match the north-up source cells.");
    cw     := grid.crop_width/2; ch:=grid.crop_height/2;
    scaled := NewArray(grid.columns*cw*grid.rows*ch*4,u8);
    defer free(scaled.data);
    check(!map_assemble_scaled(loaded,directory,cw,ch,scaled).count,"Scaled PNG uses the same inverse frame mapping.");
    for row:0..grid.rows-1 for column:0..grid.columns-1 {
        pixel := scaled.data+((row*ch+ch/2)*grid.columns*cw+column*cw+cw/2)*4;
        check(pixel[0]==column*20 && pixel[1]==row*20 && pixel[2]==capture_grid_index(grid,column,row),"Scaled cell centers retain the right ring source.");
    }
    output := ".build/centered-map-fixture.jpg";
    check(write_entire_file(output,"previous image"),"Seed an existing JPEG destination.");
    check(map_export_image(directory,output,jpeg_quality=0).count>0,"Reject invalid JPEG quality before replacing output.");
    check(!map_export_image(directory,output,max_side=32768,jpeg_quality=92).count,"Publish the completed JPEG atomically.");
    encoded,read_ok := read_entire_file(output);
    defer free(encoded);
    check(read_ok && encoded.count>4 && encoded[0]==0xff && encoded[1]==0xd8 && encoded[encoded.count-2]==0xff && encoded[encoded.count-1]==0xd9,
          "Output contains a real, complete JPEG stream.");
    // The shared decoder detects JPEG as well as source PNGs.
    decoded,decode_error := map_read_png(output,cast(s32)width,cast(s32)height);
    defer map_image_free(*decoded);
    check(!decode_error.count,"JPEG decodes at full mosaic dimensions.");
    for row:0..grid.rows-1 for column:0..grid.columns-1 {
        pixel := decoded.pixels+((row*grid.crop_height+grid.crop_height/2)*width+column*grid.crop_width+grid.crop_width/2)*4;
        check(abs(cast(s64)pixel[0]-column*20)<=3 && abs(cast(s64)pixel[1]-row*20)<=3,
              "JPEG retains centered-grid alignment within lossy encoding tolerance.");
    }
    grid.frames.count-=1;
    check(!capture_atomic_json(tprint("%/manifest.json",directory),grid).count,"Seed incomplete JPEG capture metadata.");
    check(map_export_image(directory,output).count>0,"An incomplete capture cannot replace a previous JPEG.");
    retained,retained_ok := read_entire_file(output);
    defer free(retained);
    check(retained_ok && retained==encoded,"Failed JPEG export leaves existing bytes intact.");
    grid.frames.count+=1;
    check(!capture_atomic_json(tprint("%/manifest.json",directory),grid).count,"Restore complete fixture metadata.");
}

#load "../src/game/capture_plan.jai";
#load "map_tiles.jai";
#import "Basic";
#import "Compiler";
#import "Math";
#import "System";
#import "File";
Json :: #import "Json";
