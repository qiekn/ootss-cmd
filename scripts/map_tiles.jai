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
    assert(pixels.count==MAP_TILE_SIZE*MAP_TILE_SIZE*4);
    memset(pixels.data,0,pixels.count);
    left:=tile_x*MAP_TILE_SIZE; top:=tile_y*MAP_TILE_SIZE;
    right:=min(left+MAP_TILE_SIZE,manifest.columns*manifest.crop_width);
    bottom:=min(top+MAP_TILE_SIZE,manifest.rows*manifest.crop_height);
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
                memcpy(pixels.data+((y-top)*MAP_TILE_SIZE+x0-left)*4,source.pixels+(sy*source.width+sx)*4,(x1-x0)*4);
            }
        }
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
Process :: #import "Process";
map_png_callback :: (builder:*void,bytes:*void,count:s32) #c_call {
    push_context { append(cast(*String_Builder)builder,string.{data=cast(*u8)bytes,count=count}); }
}
