#!/usr/bin/env jai

// Synthetic world-coordinate gradients only. Never accesses or displays a game.
#run {
    set_build_options_dc(.{do_output=false});
    set_working_directory(tprint("%/..",#filepath));
    check_world_grid();
    check_crop_stitch();
    print("PASS: % world-crop checks.\n",checks);
}

checks: s64;
check :: (ok:bool,message:string) {
    checks+=1;
    if !ok { compiler_report(message); assert(ok); }
}

check_world_grid :: () {
    plan: Capture_Plan=.{version=3,scene="overworld",xmin=-40,ymin=-20,xmax=180,ymax=170,z=80,
        center_first = true,center_x=80,center_y=69,crop_world_size=9,freeze_time=true,require_map_view=true};
    grid,error := capture_make_grid(plan,3840,2160,cast(float)0.478175431489944458);
    check(!error.count && grid.columns==25 && grid.rows==22,"The world requires 550 centered 9 by 9 cells.");
    check(grid.step_x==9 && grid.step_y==9,"Both camera steps are exactly nine world cells.");
    check(grid.crop_width==498 && grid.crop_height==498 && grid.source_crop_size>498 && grid.source_crop_size<499,
          "Resample the fractional world footprint into a square pixel tile.");
    check(grid.origin_x==-41.5 && grid.origin_y==172.5,"Exact world bounds are independent of pixel rounding.");
    for index:0..grid.columns*grid.rows-1 {
        frame := capture_grid_frame(grid,index);
        check(frame.position[0]==cast(float)(80+(frame.column-grid.center_column)*9) && frame.position[1]==cast(float)(69-(frame.row-grid.center_row)*9) && frame.position[2]==80,
              "Every camera position stays on the exact nine-cell lattice.");
        check(capture_grid_index(grid,frame.column,frame.row)==index,"World-sized tiles preserve center-out ordering.");
        array_add(*grid.frames,frame);
    }
    defer array_free(grid.frames);
    check(!capture_validate_manifest(grid,true).count,"A completed world-crop manifest validates.");
    cw,ch,size_error := map_image_layout(grid,32768,true);
    check(!size_error.count && cw*grid.columns==12450 && ch*grid.rows==10956,"The full-resolution cropped map fits the JPEG budget.");
    odd,odd_error := capture_make_grid(plan,3839,2159,grid.fov);
    check(!odd_error.count && odd.crop_width==odd.crop_height && odd.step_x==9 && odd.step_y==9,"Odd viewport dimensions retain the exact square world footprint.");
    bad := grid; bad.source_crop_size+=0.01;
    check(capture_validate_manifest(bad).count>0,"Reject altered fractional source geometry.");
    bad = grid; bad.origin_x+=0.01;
    check(capture_validate_manifest(bad).count>0,"Validate version 3 map origins.");
    changed := plan; changed.crop_world_size=8;
    check(!capture_plan_equal(plan,changed),"A changed world crop cannot resume an earlier capture.");
    changed = plan; changed.version=2;
    check(capture_validate_plan(changed).count>0,"Older plans must not silently ignore world crop size.");
    changed = plan; changed.crop_world_size=-1;
    check(capture_validate_plan(changed).count>0,"Reject negative world crop size.");
    for size:float64.[FLOAT64_NAN,FLOAT64_INFINITY] {
        changed = plan; changed.crop_world_size=size;
        check(capture_validate_plan(changed).count>0,"Reject nonfinite world crop size.");
    }
    for size:float64.[0.000001,1000] {
        changed = plan; changed.crop_world_size=size;
        rejected,reject_error := capture_make_grid(changed,3840,2160,grid.fov);
        check(reject_error.count>0,"Reject subpixel or out-of-view squares before taking screenshots.");
    }
    changed = plan; changed.crop_world_size=0;
    legacy,legacy_error := capture_make_grid(changed,3840,2160,grid.fov);
    width,height        := capture_frame_dimensions(legacy);
    check(!legacy_error.count && width==3840 && height==2160,"Zero world crop retains the full-frame overlap mode.");
    print("9 x 9 world grid: % x % frames; % x % PNG cells; % x % final pixels.\n",grid.columns,grid.rows,grid.crop_width,grid.crop_height,cw*grid.columns,ch*grid.rows);
}

check_gradient :: (grid:Capture_Manifest,pixels:[]u8,cell_width:s64,cell_height:s64) {
    width  := grid.columns*cell_width;
    height := grid.rows*cell_height;
    for y:0..height-1 for x:0..width-1 {
        wx := grid.origin_x+(x+0.5)*grid.step_x/cell_width;
        wy := grid.origin_y-(y+0.5)*grid.step_y/cell_height;
        p  := pixels.data+(y*width+x)*4;
        if abs(cast(float64)p[0]-(128+wx*3))>2 || abs(cast(float64)p[1]-(128+wy*3))>2 || p[2]!=77 || p[3]!=255 {
            check(false,tprint("World gradient mismatch at %, %: %, %, %, %.",x,y,p[0],p[1],p[2],p[3]));
            return;
        }
    }
    check(true,"All pixels, including seams, match world coordinates; peripheral sentinel pixels are discarded.");
}

check_crop_stitch :: () {
    directory := ".build/world-crop-fixture";
    check(make_directory_if_it_does_not_exist(directory,true),"Create isolated crop fixtures.");
    plan: Capture_Plan=.{version=3,scene="overworld",xmin=-8,ymin=-8,xmax=8,ymax=8,z=10,center_first=true,crop_world_size=9};
    grid,error := capture_make_grid(plan,257,193,cast(float)(PI64/3));
    check(!error.count && grid.columns==3 && grid.rows==3,"Generate a small odd-sized perspective viewport.");
    defer array_free(grid.frames);
    source  := NewArray(cast(s64)grid.width*grid.height*4,u8);
    cropped := NewArray(cast(s64)grid.crop_width*grid.crop_height*4,u8);
    defer free(source.data); defer free(cropped.data);
    check(capture_crop_pixels(grid,.{},cropped).count>0,"Reject empty source storage.");
    check(capture_crop_pixels(grid,source,.{}).count>0,"Reject empty destination storage.");
    bad := grid; bad.crop_width+=1;
    check(capture_crop_pixels(bad,source,cropped).count>0,"Reject inconsistent output geometry.");
    bad = grid; bad.source_crop_size=FLOAT64_NAN;
    check(capture_crop_pixels(bad,source,cropped).count>0,"Reject nonfinite source geometry before entering the native resizer.");
    source_scale := grid.source_crop_size/9;
    for index:0..grid.columns*grid.rows-1 {
        auto_release_temp();
        frame := capture_grid_frame(grid,index);
        for y:0..grid.height-1 for x:0..grid.width-1 {
            dx := (x+0.5-grid.width/2.0);
            dy := (y+0.5-grid.height/2.0);
            p  := source.data+(y*grid.width+x)*4;
            p[0]=cast(u8)floor(128.5+(frame.position[0]+dx/source_scale)*3);
            p[1]=cast(u8)floor(128.5+(frame.position[1]-dy/source_scale)*3);
            p[2]=77; p[3]=255;
            if abs(dx)>grid.source_crop_size/2+2 || abs(dy)>grid.source_crop_size/2+2 { p[0]=255; p[1]=0; p[2]=255; }
        }
        check(!capture_crop_pixels(grid,source,cropped).count,"Crop the exact reference-ground footprint.");
        check(!map_write_png(capture_frame_file(directory,index),cropped.data,grid.crop_width,grid.crop_height).count,"Save only the cropped square as PNG.");
        array_add(*grid.frames,frame);
    }
    check(!capture_atomic_json(tprint("%/manifest.json",directory),grid).count,"Save crop geometry and frame order.");
    ok,loaded := Json.json_parse_file(tprint("%/manifest.json",directory),Capture_Manifest);
    defer free(loaded.plan.scene); defer array_free(loaded.frames);
    check(ok && !capture_validate_manifest(loaded,true).count,"Round-trip fractional crop metadata exactly.");
    width  := grid.columns*grid.crop_width;
    height := grid.rows*grid.crop_height;
    pixels := NewArray(width*height*4,u8);
    defer free(pixels.data);
    check(!map_assemble_region(loaded,directory,0,0,width,height,pixels).count,"Assemble already-cropped cells without cropping twice.");
    check_gradient(grid,pixels,grid.crop_width,grid.crop_height);
    tile := NewArray(512*512*4,u8);
    defer free(tile.data);
    check(!map_assemble_tile(loaded,directory,0,0,tile).count,"Tile export reads cropped frame dimensions.");
    identical := true;
    for y:0..511 for x:0..511 for c:0..3 {
        expected: u8;
        if x<width && y<height expected=pixels[(y*width+x)*4+c];
        if tile[(y*512+x)*4+c]!=expected identical=false;
    }
    check(identical,"Tile pixels match the full mosaic and uncovered padding stays transparent.");
    cw     := grid.crop_width/2;
    scaled := NewArray(grid.columns*grid.rows*cw*cw*4,u8);
    defer free(scaled.data);
    check(!map_assemble_scaled(loaded,directory,cw,cw,scaled).count,"Downscale already-cropped cells.");
    check_gradient(grid,scaled,cw,cw);
    check(!map_export_image(directory,tprint("%/map.jpg",directory),max_side=300).count,"Export a cropped JPEG through the complete manifest path.");
    saved,saved_ok := read_entire_file(capture_frame_file(directory,0));
    defer free(saved);
    check(saved_ok,"Retain the first synthetic cropped frame.");
    check(!map_write_png(capture_frame_file(directory,0),source.data,grid.width,grid.height).count,"Substitute a legacy full viewport for one cropped frame.");
    invalid,invalid_error := map_read_capture_frame(loaded,directory,0);
    defer map_image_free(*invalid);
    check(invalid_error.count>0,"Reject mixing full screenshots with cropped-frame metadata.");
    check(write_entire_file(capture_frame_file(directory,0),saved),"Restore the original synthetic frame byte for byte.");
}

#load "../src/game/capture_plan.jai";
#load "../src/game/capture_image.jai";
#load "map_tiles.jai";
#import "Basic";
#import "Compiler";
#import "File";
#import "Math";
#import "System";
Json :: #import,dir "../modules/Json";
