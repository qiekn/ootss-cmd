// Shared, bounded-memory tile assembly. No game access or screen display.
MAP_TILE_SIZE :: 512;
Map_Image :: struct { pixels:*u8; width,height:s32; }
map_image_free :: (image:*Map_Image) { if image.pixels Image.stbi_image_free(image.pixels); image.*=.{}; }

map_read_png :: (filename:string, width:s32, height:s32) -> (image:Map_Image,error:string) {
    bytes,ok:=read_entire_file(filename);
    defer free(bytes);
    if !ok || bytes.count<24 || bytes.count>0x7fffffff return .{},tprint("Cannot read PNG: %",filename);
    x,y,c:s32;
    if !Image.stbi_info_from_memory(bytes.data,cast(s32)bytes.count,*x,*y,*c) || x!=width || y!=height return .{},tprint("Wrong frame dimensions: %",filename);
    pixels:=Image.stbi_load_from_memory(bytes.data,cast(s32)bytes.count,*x,*y,*c,4);
    if !pixels return .{},tprint("Invalid PNG pixels: %",filename);
    return .{pixels=pixels,width=x,height=y},"";
}

map_write_png :: (filename:string,pixels:*u8,width:s32,height:s32) -> string {
    encoded:String_Builder;
    defer free_buffers(*encoded);
    if !PNG.stbi_write_png_to_func(map_png_callback,*encoded,width,height,4,pixels,width*4) return "PNG encoding failed.";
    temporary:=tprint("%.tmp",filename);
    if !write_entire_file(temporary,*encoded) || !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary,filename) return tprint("Could not save %",filename);
    return "";
}

map_tile_file :: (directory:string,z:s64,x:s64,y:s64,extension:string) -> string {
    return tprint("%/%/%/%.%",directory,z,y,x,extension);
}

map_max_zoom :: (width:s64,height:s64) -> s64 {
    zoom:s64; side:s64=MAP_TILE_SIZE;
    while side<max(width,height) { side*=2; zoom+=1; }
    return zoom;
}

// Each source cell contributes only its centered rectangle. Source rows run
// north to south; serpentine acquisition order never changes the mosaic order.
map_assemble_tile :: (manifest:Capture_Manifest,directory:string,tile_x:s64,tile_y:s64,pixels:[]u8) -> string {
    return map_assemble_region(manifest,directory,tile_x*MAP_TILE_SIZE,tile_y*MAP_TILE_SIZE,MAP_TILE_SIZE,MAP_TILE_SIZE,pixels);
}

map_assemble_region :: (manifest:Capture_Manifest,directory:string,left:s64,top:s64,width:s64,height:s64,pixels:[]u8) -> string {
    assert(left>=0 && top>=0 && width>0 && height>0 && pixels.count==width*height*4);
    memset(pixels.data,0,pixels.count);
    right:=min(left+width,manifest.columns*manifest.crop_width);
    bottom:=min(top+height,manifest.rows*manifest.crop_height);
    if right<=left || bottom<=top return "";
    for row:top/manifest.crop_height..(bottom-1)/manifest.crop_height {
        for column:left/manifest.crop_width..(right-1)/manifest.crop_width {
            index:=row*manifest.columns+(ifx row&1 then manifest.columns-1-column else column);
            source,error:=map_read_png(capture_frame_file(directory,index),manifest.width,manifest.height);
            if error.count return error;
            defer map_image_free(*source);
            cell_left:=column*manifest.crop_width; cell_top:=row*manifest.crop_height;
            x0:=max(left,cell_left); x1:=min(right,cell_left+manifest.crop_width);
            y0:=max(top,cell_top); y1:=min(bottom,cell_top+manifest.crop_height);
            for y:y0..y1-1 {
                sy:=(manifest.height-manifest.crop_height)/2+y-cell_top;
                sx:=(manifest.width-manifest.crop_width)/2+x0-cell_left;
                memcpy(pixels.data+((y-top)*width+x0-left)*4,source.pixels+(sy*source.width+sx)*4,(x1-x0)*4);
            }
        }
    }
    return "";
}

// The existing tile exporter remains available for maps too large for one PNG.
// Publish only after all frames decode and the complete image encodes correctly.
map_export_png :: (directory:string,output:string,run_id:u64=0,max_side:s64=0) -> string {
    ok,manifest:=Json.json_parse_file(tprint("%/manifest.json",directory),Capture_Manifest);
    defer free(manifest.plan.scene); defer array_free(manifest.frames);
    if !ok return "Could not parse capture manifest.";
    if run_id && manifest.plan.run_id!=run_id return "Capture was replaced by another run.";
    error:=capture_validate_manifest(manifest,complete=true);
    if error.count return error;
    cell_width,cell_height,layout_error:=map_png_layout(manifest,max_side);
    if layout_error.count return layout_error;
    width:=manifest.columns*cell_width;
    height:=manifest.rows*cell_height;
    pixels:=NewArray(width*height*4,u8);
    defer free(pixels.data);
    if cell_width==manifest.crop_width && cell_height==manifest.crop_height
        error=map_assemble_region(manifest,directory,0,0,width,height,pixels);
    else error=map_assemble_scaled(manifest,directory,cell_width,cell_height,pixels);
    if error.count return error;
    parent:=path_strip_filename(output);
    if parent.count && !make_directory_if_it_does_not_exist(parent,true) return "Could not create PNG output directory.";
    error=map_write_png(output,pixels.data,cast(s32)width,cast(s32)height);
    if !error.count print("Map ready: % (% x % pixels)\n",output,width,height);
    return error;
}

map_png_layout :: (manifest:Capture_Manifest,max_side:s64) -> (cell_width:s64,cell_height:s64,error:string) {
    if max_side!=0 && (max_side<64 || max_side>16384) return 0,0,"PNG maximum side must be 64-16384, or 0 for native resolution.";
    if manifest.columns<1 || manifest.rows<1 || manifest.columns>100000 || manifest.rows>100000 ||
       manifest.crop_width<1 || manifest.crop_height<1 || manifest.crop_width>16384 || manifest.crop_height>16384
        return 0,0,"Invalid PNG grid dimensions.";
    limit:=ifx max_side then max_side else 16384;
    divisor:s64=1;
    while divisor<=max(manifest.crop_width,manifest.crop_height) {
        cw:=(manifest.crop_width+divisor-1)/divisor;
        ch:=(manifest.crop_height+divisor-1)/divisor;
        width:=manifest.columns*cw; height:=manifest.rows*ch;
        if width<=limit && height<=limit && width*height<=67108864 return cw,ch,"";
        if !max_side break;
        divisor+=1;
    }
    return 0,0,"Single PNG exceeds its size budget. Set png_max_side to resize, or export map tiles.";
}

// Resize each center region directly into the destination. The surrounding
// overlap supplies filter samples; memory is one source frame plus the output.
map_assemble_scaled :: (manifest:Capture_Manifest,directory:string,cw:s64,ch:s64,pixels:[]u8) -> string {
    width:=manifest.columns*cw;
    if cw<1 || ch<1 || pixels.count!=width*manifest.rows*ch*4 return "Invalid scaled PNG buffer.";
    left:=(manifest.width-manifest.crop_width)/2;
    top:=(manifest.height-manifest.crop_height)/2;
    for row:0..manifest.rows-1 for column:0..manifest.columns-1 {
        index:=row*manifest.columns+(ifx row&1 then manifest.columns-1-column else column);
        source,error:=map_read_png(capture_frame_file(directory,index),manifest.width,manifest.height);
        if error.count return error;
        defer map_image_free(*source);
        target:=pixels.data+(row*ch*width+column*cw)*4;
        if !Resize.stbir_resize_region(source.pixels,source.width,source.height,source.width*4,
            target,cast(s32)cw,cast(s32)ch,cast(s32)(width*4),.TYPE_UINT8,4,3,0,
            .CLAMP,.CLAMP,.BOX,.BOX,.COLORSPACE_SRGB,null,
            cast(float)left/source.width,cast(float)top/source.height,
            cast(float)(left+manifest.crop_width)/source.width,cast(float)(top+manifest.crop_height)/source.height)
            return "Could not resize a capture frame.";
    }
    return "";
}

// Four child tiles become one parent. Alpha-weighted box filtering preserves
// map-edge coverage and avoids dark fringes against the transparent padding.
map_reduce_child :: (source:*u8,destination:*u8,quadrant_x:s64,quadrant_y:s64) {
    for y:0..255 for x:0..255 {
        sums:[4]u32;
        for dy:0..1 for dx:0..1 {
            p:=source+((y*2+dy)*512+x*2+dx)*4;
            for c:0..2 sums[c]+=cast(u32)p[c]*p[3];
            sums[3]+=p[3];
        }
        p:=destination+((quadrant_y*256+y)*512+quadrant_x*256+x)*4;
        for c:0..2 p[c]=ifx sums[3] then cast(u8)((sums[c]+sums[3]/2)/sums[3]) else 0;
        p[3]=cast(u8)((sums[3]+2)/4);
    }
}

map_export_tile :: (output:string,z:s64,x:s64,y:s64,pixels:[]u8) -> string {
    png_dir:=tprint("%/pyramid/%/%",output,z,y);
    webp_dir:=tprint("%/tiles/%/%",output,z,y);
    if !make_directory_if_it_does_not_exist(png_dir,true) || !make_directory_if_it_does_not_exist(webp_dir,true) return "Could not create tile directories.";
    source:=map_tile_file(tprint("%/pyramid",output),z,x,y,"png");
    error:=map_write_png(source,pixels.data,512,512);
    if error.count return error;
    destination:=map_tile_file(tprint("%/tiles",output),z,x,y,"webp");
    temporary:=tprint("%.tmp",destination);
    result,stdout,stderr:=Process.run_command("cwebp","-quiet","-lossless",source,"-o",temporary,capture_and_return_output=true);
    defer free(stdout); defer free(stderr);
    if result.type!=.EXITED || result.exit_code!=0 return tprint("cwebp failed. Install libwebp tools on PATH. %",stderr);
    if !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary,destination) return "Could not publish WebP tile.";
    return "";
}

#scope_file
#import "Basic";
#import "File";
#import "File_Utilities";
Image :: #import "stb_image";
PNG :: #import "stb_image_write";
Resize :: #import "stb_image_resize";
Process :: #import "Process";
Json :: #import,dir "../modules/Json";
map_png_callback :: (builder:*void,bytes:*void,count:s32) #c_call {
    push_context { append(cast(*String_Builder)builder,string.{data=cast(*u8)bytes,count=count}); }
}
