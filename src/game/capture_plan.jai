Capture_Plan :: struct {
    version:                           s32 = 1;
    run_id:                            u64;
    scene:                             string;
    xmin, ymin, xmax, ymax, z, ground: float64;
    overlap:                           float64 = 0.3;
    settle_ms:                         s32 = 500;
    // Version 2: anchor a tile at this point, then visit concentric square rings.
    center_first:                  bool;
    center_x, center_y:            float64;
    freeze_time, require_map_view: bool;
    // Version 3: keep only this square at reference ground; 0 uses overlap.
    crop_world_size: float64;
}

Capture_Frame :: struct {
    index, column, row: s64;
    position:           [3] float;
}
Capture_Status :: struct { state, message: string; completed, total: s64; run_id: u64; }

CAPTURE_COPYDATA_ID     :: 0x4f4f5443;
CAPTURE_RUN_COPYDATA_ID :: 0x4f4f5444;
CAPTURE_V2_COPYDATA_ID  :: 0x4f4f5445;
CAPTURE_V3_COPYDATA_ID  :: 0x4f4f5446;

Capture_Manifest :: struct {
    version:                                s32 = 1;
    plan:                                   Capture_Plan;
    width, height, crop_width, crop_height: s32;
    columns, rows:                          s64;
    pixels_per_unit, step_x, step_y:        float64;
    source_crop_size:                       float64; // Fractional source pixels when crop_world_size > 0.
    origin_x, origin_y:                     float64; // Actual northwest mosaic edge (version 2).
    center_column, center_row:              s64;
    fov:                                    float;
    orientation:                            [4] float;
    frames:                                 [..] Capture_Frame;
}

capture_validate_plan :: (plan: Capture_Plan) -> string {
    if plan.version<1 || plan.version>3 || !plan.scene.count || plan.scene.count > 128 return "Expected plan version 1-3 and a scene name.";
    if plan.version==1 && (plan.center_first || plan.freeze_time || plan.require_map_view) return "New capture options require plan version 2.";
    if !is_finite(plan.crop_world_size) || plan.crop_world_size<0 || plan.crop_world_size>1000000 return "World crop size must be finite and between 0 and 1000000.";
    if plan.version<3 && plan.crop_world_size!=0 return "World-sized crops require plan version 3.";
    for c: plan.scene if !((c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") ||
        (c >= #char "0" && c <= #char "9") || c == #char "_" || c == #char "-" || c == #char ".") return "Invalid scene name.";
    for v: float64.[plan.xmin,plan.ymin,plan.xmax,plan.ymax,plan.z,plan.ground,plan.center_x,plan.center_y] {
        if !is_finite(v) || abs(v) > 1000000 return "World coordinates must be finite and within +/-1000000.";
    }
    if plan.xmax <= plan.xmin || plan.ymax <= plan.ymin || plan.z <= plan.ground return "Expected positive map extents and Z above the reference ground.";
    if plan.center_first && (plan.center_x<plan.xmin || plan.center_x>plan.xmax || plan.center_y<plan.ymin || plan.center_y>plan.ymax)
        return "The capture center must lie within the requested map bounds.";
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
    result.plan    = plan;
    result.version = plan.version;
    result.width   = width;
    result.height  = height;
    // Matching parity keeps the crop centered, even with odd client dimensions.
    result.crop_width  = cast(s32) max(2, cast(s64)(width*(1-plan.overlap))/2*2);
    result.crop_height = cast(s32) max(2, cast(s64)(height*(1-plan.overlap))/2*2);
    if width&1 result.crop_width+=1;
    if height&1 result.crop_height+=1;
    result.fov         = fov;
    result.orientation = .[-0.5,0.5,0.5,0.5];
    camera_z := cast(float64)cast(float)plan.z;
    if camera_z<=plan.ground return .{}, "Camera height rounds to the reference ground.";
    result.pixels_per_unit = height / (2*(camera_z-plan.ground)*tan(cast(float64) fov/2));
    result.step_x          = result.crop_width / result.pixels_per_unit;
    result.step_y          = result.crop_height / result.pixels_per_unit;
    if plan.crop_world_size>0 {
        result.source_crop_size = plan.crop_world_size*result.pixels_per_unit;
        if !is_finite(result.source_crop_size) || result.source_crop_size<2 || result.source_crop_size>cast(float64)min(width,height)
            return .{},"The world crop must fit inside the camera view and span at least two pixels.";
        // Resample the exact fractional footprint into whole pixels. Camera
        // steps stay exact world units, so pixel rounding cannot accumulate gaps.
        result.crop_width      = cast(s32)floor(result.source_crop_size);
        result.crop_height     = result.crop_width;
        result.pixels_per_unit = result.crop_width/plan.crop_world_size;
        result.step_x          = plan.crop_world_size;
        result.step_y          = plan.crop_world_size;
    }
    nx := ceil((plan.xmax-plan.xmin)/result.step_x);
    ny := ceil((plan.ymax-plan.ymin)/result.step_y);
    result.origin_x = plan.xmin;
    result.origin_y = plan.ymax;
    if plan.center_first {
        left   := max(ceil((plan.center_x-plan.xmin)/result.step_x-0.5),0.0);
        right  := max(ceil((plan.xmax-plan.center_x)/result.step_x-0.5),0.0);
        top    := max(ceil((plan.ymax-plan.center_y)/result.step_y-0.5),0.0);
        bottom := max(ceil((plan.center_y-plan.ymin)/result.step_y-0.5),0.0);
        nx = left+1+right;
        ny = top+1+bottom;
        if !is_finite(nx) || !is_finite(ny) || nx*ny>100000 return .{},"Capture grid is too large.";
        result.center_column = cast(s64)left;
        result.center_row    = cast(s64)top;
        result.origin_x      = plan.center_x-(left+0.5)*result.step_x;
        result.origin_y      = plan.center_y+(top+0.5)*result.step_y;
    }
    if !is_finite(nx) || !is_finite(ny) || nx < 1 || ny < 1 || nx*ny > 100000 ||
       nx*result.crop_width > 1000000 || ny*result.crop_height > 1000000 return .{}, "Capture grid is too large (maximum 100000 frames).";
    result.columns = cast(s64) nx;
    result.rows    = cast(s64) ny;
    // Float coordinates must locate a tile to substantially better than one pixel.
    for index: 0..result.columns*result.rows-1 {
        frame := capture_grid_frame(result, index);
        x,y   := capture_grid_xy(result,frame.column,frame.row);
        if abs(x)>1000000 || abs(y)>1000000 || abs(cast(float64)frame.position[0]-x)*result.pixels_per_unit > 0.05 ||
           abs(cast(float64)frame.position[1]-y)*result.pixels_per_unit > 0.05 ||
           abs(cast(float64)frame.position[2]-plan.z)*result.pixels_per_unit > 0.05 return .{}, "Capture coordinates exceed the supported range or float precision.";
    }
    return result, "";
}

capture_grid_frame :: (manifest: Capture_Manifest, index: s64) -> Capture_Frame {
    row    := index/manifest.columns;
    column := index%manifest.columns;
    if row & 1 column = manifest.columns-1-column;
    if manifest.plan.center_first {
        if index==0 { column=manifest.center_column; row=manifest.center_row; }
        else {
            low: s64 = 1;
            high := max(manifest.columns,manifest.rows);
            while low<high {
                middle := (low+high)/2;
                if capture_ring_inside(manifest,middle)>index high=middle;
                else low=middle+1;
            }
            offset := index-capture_ring_inside(manifest,low-1);
            for segment:capture_ring_segments(manifest,low) {
                if offset>=segment.count { offset-=segment.count; continue; }
                column = segment.column+segment.dx*offset;
                row    = segment.row+segment.dy*offset;
                break;
            }
        }
    }
    x,y := capture_grid_xy(manifest,column,row);
    return .{index=index, column=column, row=row, position=.[
        cast(float)x,cast(float)y,cast(float)manifest.plan.z]};
}

capture_grid_xy :: (manifest: Capture_Manifest, column: s64, row: s64) -> (x: float64, y: float64) {
    if manifest.plan.center_first return manifest.plan.center_x+(column-manifest.center_column)*manifest.step_x,
        manifest.plan.center_y-(row-manifest.center_row)*manifest.step_y;
    return manifest.plan.xmin+(column+0.5)*manifest.step_x,manifest.plan.ymax-(row+0.5)*manifest.step_y;
}

capture_grid_origin :: (manifest: Capture_Manifest) -> (x: float64,y: float64) {
    if manifest.version==1 return manifest.plan.xmin,manifest.plan.ymax;
    return manifest.origin_x,manifest.origin_y;
}

Capture_Ring_Segment :: struct { column,row,dx,dy,count: s64; }

capture_ring_inside :: (manifest: Capture_Manifest, radius: s64) -> s64 {
    return (min(manifest.columns-1,manifest.center_column+radius)-max(0,manifest.center_column-radius)+1)*
           (min(manifest.rows-1,manifest.center_row+radius)-max(0,manifest.center_row-radius)+1);
}

// Clockwise perimeter, clipped to the requested rectangular grid. Each corner
// belongs to exactly one segment, even for a one-row or one-column map.
capture_ring_segments :: (manifest: Capture_Manifest, radius: s64) -> [4] Capture_Ring_Segment {
    segments: [4] Capture_Ring_Segment;
    left   := manifest.center_column-radius;
    right  := manifest.center_column+radius;
    top    := manifest.center_row-radius;
    bottom := manifest.center_row+radius;
    if top>=0 && top<manifest.rows {
        start := max(0,left);
        end   := min(manifest.columns-1,right);
        segments[0]=.{start,top,1,0,max(0,end-start+1)};
    }
    if right>=0 && right<manifest.columns {
        start := max(0,top+1);
        end   := min(manifest.rows-1,bottom);
        segments[1]=.{right,start,0,1,max(0,end-start+1)};
    }
    if bottom>=0 && bottom<manifest.rows {
        start := min(manifest.columns-1,right-1);
        end   := max(0,left);
        segments[2]=.{start,bottom,-1,0,max(0,start-end+1)};
    }
    if left>=0 && left<manifest.columns {
        start := min(manifest.rows-1,bottom-1);
        end   := max(0,top+1);
        segments[3]=.{left,start,0,-1,max(0,start-end+1)};
    }
    return segments;
}

// Inverse mapping used by all stitch paths; no scan over the frame list.
capture_grid_index :: (manifest: Capture_Manifest, column: s64, row: s64) -> s64 {
    if !manifest.plan.center_first return row*manifest.columns+(ifx row&1 then manifest.columns-1-column else column);
    radius := max(abs(column-manifest.center_column),abs(row-manifest.center_row));
    if !radius return 0;
    index := capture_ring_inside(manifest,radius-1);
    for segment:capture_ring_segments(manifest,radius) {
        offset := (column-segment.column)*segment.dx+(row-segment.row)*segment.dy;
        if offset>=0 && offset<segment.count && column==segment.column+offset*segment.dx && row==segment.row+offset*segment.dy return index+offset;
        index+=segment.count;
    }
    return -1;
}

capture_plan_equal :: (a: Capture_Plan, b: Capture_Plan) -> bool {
    return a.version==b.version && a.run_id==b.run_id && a.scene==b.scene && a.xmin==b.xmin && a.ymin==b.ymin && a.xmax==b.xmax &&
           a.ymax==b.ymax && a.z==b.z && a.ground==b.ground && a.overlap==b.overlap && a.settle_ms==b.settle_ms &&
           a.center_first==b.center_first && a.center_x==b.center_x && a.center_y==b.center_y &&
           a.freeze_time==b.freeze_time && a.require_map_view==b.require_map_view && a.crop_world_size==b.crop_world_size;
}

capture_frame_dimensions :: (manifest: Capture_Manifest) -> (width:s32,height:s32) {
    if manifest.plan.crop_world_size>0 return manifest.crop_width,manifest.crop_height;
    return manifest.width,manifest.height;
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
    name := filename;
    if ends_with(name,".tmp") name=slice(name,0,name.count-4);
    if name=="manifest.json" || name=="status.json" return true;
    if name.count!=16 || !begins_with(name,"frame_") || !ends_with(name,".png") return false;
    for i:6..11 if name[i]<#char "0" || name[i]>#char "9" return false;
    return true;
}

capture_validate_manifest :: (manifest: Capture_Manifest, complete := false) -> string {
    grid,error := capture_make_grid(manifest.plan,manifest.width,manifest.height,manifest.fov);
    if error.count return error;
    if manifest.version!=grid.version || manifest.columns!=grid.columns || manifest.rows!=grid.rows ||
       manifest.crop_width!=grid.crop_width || manifest.crop_height!=grid.crop_height ||
       manifest.pixels_per_unit!=grid.pixels_per_unit || manifest.step_x!=grid.step_x || manifest.step_y!=grid.step_y ||
       manifest.source_crop_size!=grid.source_crop_size ||
       manifest.frames.count>grid.columns*grid.rows return "Invalid capture grid metadata.";
    if manifest.version>=2 && (manifest.origin_x!=grid.origin_x || manifest.origin_y!=grid.origin_y ||
       manifest.center_column!=grid.center_column || manifest.center_row!=grid.center_row) return "Invalid centered grid metadata.";
    for i:0..3 if manifest.orientation[i]!=grid.orientation[i] return "Expected a north-up top-down camera.";
    if complete && manifest.frames.count!=grid.columns*grid.rows return "Capture is incomplete; resume it before stitching.";
    for frame:manifest.frames {
        expected := capture_grid_frame(grid,it_index);
        if frame.index!=expected.index || frame.column!=expected.column || frame.row!=expected.row return "Invalid frame order.";
        for i:0..2 if frame.position[i]!=expected.position[i] return "Invalid frame coordinates.";
    }
    return "";
}

capture_atomic_json :: (filename: string, value: $T) -> string {
    temporary := tprint("%.tmp", filename);
    builder: String_Builder;
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
        value: float64;
        if info.runtime_size==4 value=cast(float64)(cast(*float)data).*;
        else value=(cast(*float64)data).*;
        print_to_builder(builder,"%",formatFloat(value,trailing_width=17,mode=.SCIENTIFIC,zero_removal=.NO));
    } else if info.type==.STRUCT {
        record := cast(*Type_Info_Struct)info;
        append(builder,"{\n");
        first := true;
        for member:record.members {
            if member.flags & .CONSTANT continue;
            if !first append(builder,",\n");
            first = false;
            Json.json_append_escaped(builder,member.name);
            append(builder,": ");
            capture_json_value(builder,cast(*u8)data+member.offset_in_bytes,member.type);
        }
        append(builder,"\n}");
    } else if info.type==.ARRAY {
        array   := cast(*Type_Info_Array)info;
        count   := array.array_count;
        pointer := cast(*u8)data;
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
