Capture_Plan :: struct {
    version: s32 = 1;
    run_id: u64;
    scene: string;
    xmin, ymin, xmax, ymax, z, ground: float64;
    overlap: float64 = 0.3;
    settle_ms: s32 = 500;
}

Capture_Frame :: struct {
    index, column, row: s64;
    position: [3] float;
}
Capture_Status :: struct { state, message: string; completed, total: s64; run_id: u64; }

CAPTURE_COPYDATA_ID :: 0x4f4f5443;
CAPTURE_RUN_COPYDATA_ID :: 0x4f4f5444;

Capture_Manifest :: struct {
    version: s32 = 1;
    plan: Capture_Plan;
    width, height, crop_width, crop_height: s32;
    columns, rows: s64;
    pixels_per_unit, step_x, step_y: float64;
    fov: float;
    orientation: [4] float;
    frames: [..] Capture_Frame;
}

capture_validate_plan :: (plan: Capture_Plan) -> string {
    if plan.version != 1 || !plan.scene.count || plan.scene.count > 128 return "Expected plan version 1 and a scene name.";
    for c: plan.scene if !((c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") ||
        (c >= #char "0" && c <= #char "9") || c == #char "_" || c == #char "-" || c == #char ".") return "Invalid scene name.";
    for v: float64.[plan.xmin,plan.ymin,plan.xmax,plan.ymax,plan.z,plan.ground] {
        if !is_finite(v) || abs(v) > 1000000 return "World coordinates must be finite and within +/-1000000.";
    }
    if plan.xmax <= plan.xmin || plan.ymax <= plan.ymin || plan.z <= plan.ground return "Expected positive map extents and Z above the reference ground.";
    if !is_finite(plan.overlap) || plan.overlap < 0.1 || plan.overlap > 0.8 return "Overlap must be between 0.1 and 0.8.";
    if plan.settle_ms < 100 || plan.settle_ms > 10000 return "Settle time must be 100-10000 ms.";
    return "";
}

capture_make_grid :: (plan: Capture_Plan, width: s32, height: s32, fov: float) -> (manifest: Capture_Manifest, error: string) {
    result: Capture_Manifest;
    error := capture_validate_plan(plan);
    if error.count return result, error;
    if width < 64 || height < 64 || width > 16384 || height > 16384 ||
       !is_finite(fov) || fov < 0.01 || fov > 3.13 return result, "Invalid capture resolution or FOV.";
    result.plan = plan;
    result.width = width;
    result.height = height;
    // Matching parity keeps the crop centered, even with odd client dimensions.
    result.crop_width = cast(s32) max(2, cast(s64)(width*(1-plan.overlap))/2*2);
    result.crop_height = cast(s32) max(2, cast(s64)(height*(1-plan.overlap))/2*2);
    if width&1 result.crop_width+=1;
    if height&1 result.crop_height+=1;
    result.fov = fov;
    result.orientation = .[-0.5,0.5,0.5,0.5];
    camera_z:=cast(float64)cast(float)plan.z;
    if camera_z<=plan.ground return .{}, "Camera height rounds to the reference ground.";
    result.pixels_per_unit = height / (2*(camera_z-plan.ground)*tan(cast(float64) fov/2));
    result.step_x = result.crop_width / result.pixels_per_unit;
    result.step_y = result.crop_height / result.pixels_per_unit;
    nx := ceil((plan.xmax-plan.xmin)/result.step_x);
    ny := ceil((plan.ymax-plan.ymin)/result.step_y);
    if !is_finite(nx) || !is_finite(ny) || nx < 1 || ny < 1 || nx*ny > 100000 ||
       nx*result.crop_width > 1000000 || ny*result.crop_height > 1000000 return .{}, "Capture grid is too large (maximum 100000 frames).";
    result.columns = cast(s64) nx;
    result.rows = cast(s64) ny;
    // Float coordinates must locate a tile to substantially better than one pixel.
    for index: 0..result.columns*result.rows-1 {
        frame := capture_grid_frame(result, index);
        x := plan.xmin+(frame.column+0.5)*result.step_x;
        y := plan.ymax-(frame.row+0.5)*result.step_y;
        if abs(x)>1000000 || abs(y)>1000000 || abs(cast(float64)frame.position[0]-x)*result.pixels_per_unit > 0.05 ||
           abs(cast(float64)frame.position[1]-y)*result.pixels_per_unit > 0.05 ||
           abs(cast(float64)frame.position[2]-plan.z)*result.pixels_per_unit > 0.05 return .{}, "Capture coordinates exceed the supported range or float precision.";
    }
    return result, "";
}

capture_grid_frame :: (manifest: Capture_Manifest, index: s64) -> Capture_Frame {
    row := index/manifest.columns;
    column := index%manifest.columns;
    if row & 1 column = manifest.columns-1-column;
    return .{index=index, column=column, row=row, position=.[
        cast(float)(manifest.plan.xmin+(column+0.5)*manifest.step_x),
        cast(float)(manifest.plan.ymax-(row+0.5)*manifest.step_y), cast(float)manifest.plan.z]};
}

capture_plan_equal :: (a: Capture_Plan, b: Capture_Plan) -> bool {
    return a.version==b.version && a.run_id==b.run_id && a.scene==b.scene && a.xmin==b.xmin && a.ymin==b.ymin && a.xmax==b.xmax &&
           a.ymax==b.ymax && a.z==b.z && a.ground==b.ground && a.overlap==b.overlap && a.settle_ms==b.settle_ms;
}

capture_frame_file :: (directory: string, index: s64) -> string {
    return tprint("%/frame_%.png", directory, formatInt(index, minimum_digits=6));
}

// A fresh job removes only generated capture files, never the directory or
// unrelated user files. Validate the plan before calling this procedure.
capture_reset_files :: (directory: string) -> string {
    State :: struct { failed: bool; }
    state: State;
    visitor :: (info: *File_Visit_Info, state: *State) {
        if state.failed || !capture_generated_file(info.short_name) return;
        if !file_delete(info.full_name) state.failed=true;
    }
    if !visit_files(directory,false,*state,visitor,visit_symlinks=false,follow_directory_symlinks=false) || state.failed
        return "Could not remove previous capture files. No new capture was started.";
    return "";
}

capture_generated_file :: (filename: string) -> bool {
    name:=filename;
    if ends_with(name,".tmp") name=slice(name,0,name.count-4);
    if name=="manifest.json" || name=="status.json" return true;
    if name.count!=16 || !begins_with(name,"frame_") || !ends_with(name,".png") return false;
    for i:6..11 if name[i]<#char "0" || name[i]>#char "9" return false;
    return true;
}

capture_validate_manifest :: (manifest: Capture_Manifest, complete := false) -> string {
    grid,error:=capture_make_grid(manifest.plan,manifest.width,manifest.height,manifest.fov);
    if error.count return error;
    if manifest.version!=1 || manifest.columns!=grid.columns || manifest.rows!=grid.rows ||
       manifest.crop_width!=grid.crop_width || manifest.crop_height!=grid.crop_height ||
       manifest.pixels_per_unit!=grid.pixels_per_unit || manifest.step_x!=grid.step_x || manifest.step_y!=grid.step_y ||
       manifest.frames.count>grid.columns*grid.rows return "Invalid capture grid metadata.";
    for i:0..3 if manifest.orientation[i]!=grid.orientation[i] return "Expected a north-up top-down camera.";
    if complete && manifest.frames.count!=grid.columns*grid.rows return "Capture is incomplete; resume it before stitching.";
    for frame:manifest.frames {
        expected:=capture_grid_frame(grid,it_index);
        if frame.index!=expected.index || frame.column!=expected.column || frame.row!=expected.row return "Invalid frame order.";
        for i:0..2 if frame.position[i]!=expected.position[i] return "Invalid frame coordinates.";
    }
    return "";
}

capture_atomic_json :: (filename: string, value: $T) -> string {
    temporary := tprint("%.tmp", filename);
    builder:String_Builder;
    defer free_buffers(*builder);
    capture_json_value(*builder,*value,type_info(T));
    if !write_entire_file(temporary,*builder) return tprint("Could not write %.", temporary);
    if !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary, filename) return "Could not atomically replace capture metadata.";
    return "";
}

// The normal console JSON formatter rounds floats for display. Capture metadata
// must round-trip exact coordinates, FOV and scale across process restarts.
capture_json_value :: (builder:*String_Builder,data:*void,info:*Type_Info) {
    if info.type==.FLOAT {
        value:float64;
        if info.runtime_size==4 value=cast(float64)(cast(*float)data).*;
        else value=(cast(*float64)data).*;
        print_to_builder(builder,"%",formatFloat(value,trailing_width=17,mode=.SCIENTIFIC,zero_removal=.NO));
    } else if info.type==.STRUCT {
        record:=cast(*Type_Info_Struct)info;
        append(builder,"{\n");
        first:=true;
        for member:record.members {
            if member.flags & .CONSTANT continue;
            if !first append(builder,",\n");
            first=false;
            Json.json_append_escaped(builder,member.name);
            append(builder,": ");
            capture_json_value(builder,cast(*u8)data+member.offset_in_bytes,member.type);
        }
        append(builder,"\n}");
    } else if info.type==.ARRAY {
        array:=cast(*Type_Info_Array)info;
        count:=array.array_count;
        pointer:=cast(*u8)data;
        if count==-1 { count=(cast(*s64)data).*; pointer=(cast(**u8)(cast(*u8)data+8)).*; }
        append(builder,"[");
        for i:0..count-1 {
            if i append(builder,",");
            capture_json_value(builder,pointer+i*array.element_type.runtime_size,array.element_type);
        }
        append(builder,"]");
    } else Json.json_write_native(builder,data,info,indent_char="");
}

#scope_file
#import "Basic";
#import "Math";
#import "File_Utilities";
#import "File";
#import "String";
Json :: #import,dir "../../modules/Json";
