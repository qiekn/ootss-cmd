#!/usr/bin/env jai

// jai -quiet scripts/stitch_map.jai -import_dir ../modules - <capture-directory> <new-output-directory>
#run {
    set_build_options_dc(.{do_output=false});
    set_working_directory(tprint("%/..",#filepath));
    args:=get_build_options().compile_time_command_line;
    if args.count!=2 compiler_report("Usage: stitch_map <capture-directory> <new-output-directory>");
    else {
        error:=stitch(args[0],args[1]);
        if error.count compiler_report(error);
    }
}

Map_Metadata :: struct {
    version:s32=1;
    scene:string;
    projection:string="perspective-center-crops";
    width,height,max_zoom,tile_size:s64;
    xmin,ymin,xmax,ymax,pixels_per_unit,ground,camera_z:float64;
    tile_url:string="tiles/{z}/{y}/{x}.webp";
}

stitch :: (directory:string,output:string) -> string {
    ok,manifest:=Json.json_parse_file(tprint("%/manifest.json",directory),Capture_Manifest);
    defer free(manifest.plan.scene); defer array_free(manifest.frames);
    if !ok return "Could not parse capture manifest.";
    error:=capture_validate_manifest(manifest,complete=true);
    if error.count return error;
    if file_exists(output) return "Output directory already exists. Choose a new directory; source frames are retained.";
    result,stdout,stderr:=Process.run_command("cwebp","-version",capture_and_return_output=true);
    defer free(stdout); defer free(stderr);
    if result.type!=.EXITED || result.exit_code!=0 return "Install libwebp tools (cwebp) on PATH before stitching.";
    if !make_directory_if_it_does_not_exist(output,true) return "Could not create output directory.";
    width:=manifest.columns*manifest.crop_width;
    height:=manifest.rows*manifest.crop_height;
    zoom:=map_max_zoom(width,height);
    pixels:=NewArray(512*512*4,u8);
    defer free(pixels.data);
    z:=zoom;
    while z>=0 {
        defer z-=1;
        scale:=cast(s64)1 << (zoom-z);
        nx:=(width+512*scale-1)/(512*scale);
        ny:=(height+512*scale-1)/(512*scale);
        print("Zoom %: % x % tiles\n",z,nx,ny);
        for y:0..ny-1 for x:0..nx-1 {
            reset_temporary_storage();
            if z==zoom {
                error=map_assemble_tile(manifest,directory,x,y,pixels);
                if error.count return error;
            } else {
                memset(pixels.data,0,pixels.count);
                child_scale:=scale/2;
                cx:=(width+512*child_scale-1)/(512*child_scale);
                cy:=(height+512*child_scale-1)/(512*child_scale);
                for dy:0..1 for dx:0..1 {
                    if x*2+dx>=cx || y*2+dy>=cy continue;
                    child,child_error:=map_read_png(map_tile_file(tprint("%/pyramid",output),z+1,x*2+dx,y*2+dy,"png"),512,512);
                    if child_error.count return child_error;
                    defer map_image_free(*child);
                    map_reduce_child(child.pixels,pixels.data,dx,dy);
                }
            }
            error=map_export_tile(output,z,x,y,pixels);
            if error.count return error;
        }
    }
    metadata:Map_Metadata=.{scene=manifest.plan.scene,width=width,height=height,max_zoom=zoom,tile_size=512,
        xmin=manifest.plan.xmin,ymax=manifest.plan.ymax,xmax=manifest.plan.xmin+manifest.columns*manifest.step_x,
        ymin=manifest.plan.ymax-manifest.rows*manifest.step_y,pixels_per_unit=manifest.pixels_per_unit,
        ground=manifest.plan.ground,camera_z=cast(float64)cast(float)manifest.plan.z};
    error=capture_atomic_json(tprint("%/map.json",output),metadata);
    if error.count return error;
    viewer,read_ok:=read_entire_file(tprint("%/map_viewer.html",#filepath));
    defer free(viewer);
    if !read_ok || !write_entire_file(tprint("%/index.html",output),viewer) return "Could not write the map viewer.";
    print("Map ready: %/map.json\nServe this directory over HTTP to open index.html. Lossless PNG pyramid and WebP tiles retained.\n",output);
    return "";
}

#load "../src/game/capture_plan.jai";
#load "map_tiles.jai";
#import "Basic";
#import "Compiler";
#import "File";
#import "System";
Json :: #import "Json";
Process :: #import "Process";
