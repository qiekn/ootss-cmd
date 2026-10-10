// Shared, bounded-memory tile assembly. No game access or screen display.
MAP_TILE_SIZE  :: 512;
Map_Image      :: struct { pixels:*u8; width,height:s32; }
map_image_free :: (image:*Map_Image) { if image.pixels Image.stbi_image_free(image.pixels); image.*=.{}; }

map_read_png :: (filename:string, width:s32, height:s32) -> (image:Map_Image,error:string) {
    bytes,ok := read_entire_file(filename);
    defer free(bytes);
    if !ok || bytes.count<24 || bytes.count>0x7fffffff return .{},tprint("Cannot read PNG: %",filename);
    x,y,c: s32;
    if !Image.stbi_info_from_memory(bytes.data,cast(s32)bytes.count,*x,*y,*c) || x!=width || y!=height return .{},tprint("Wrong frame dimensions: %",filename);
    pixels := Image.stbi_load_from_memory(bytes.data,cast(s32)bytes.count,*x,*y,*c,4);
    if !pixels return .{},tprint("Invalid PNG pixels: %",filename);
    return .{pixels=pixels,width=x,height=y},"";
}

map_read_capture_frame :: (manifest:Capture_Manifest,directory:string,index:s64) -> (image:Map_Image,error:string) {
    width,height := capture_frame_dimensions(manifest);
    image,error  := map_read_png(capture_frame_file(directory,index),width,height);
    return image,error;
}

map_write_png :: (filename:string,pixels:*u8,width:s32,height:s32) -> string {
    encoded: String_Builder;
    defer free_buffers(*encoded);
    if !PNG.stbi_write_png_to_func(map_png_callback,*encoded,width,height,4,pixels,width*4) return "PNG encoding failed.";
    temporary := tprint("%.tmp",filename);
    if !write_entire_file(temporary,*encoded) || !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary,filename) return tprint("Could not save %",filename);
    return "";
}

map_tile_file :: (directory:string,z:s64,x:s64,y:s64,extension:string) -> string {
    return tprint("%/%/%/%.%",directory,z,y,x,extension);
}

map_max_zoom :: (width:s64,height:s64) -> s64 {
    zoom: s64; side:s64=MAP_TILE_SIZE;
    while side<max(width,height) { side*=2; zoom+=1; }
    return zoom;
}

// Each source cell contributes only its centered rectangle. Source rows run
// north to south; serpentine acquisition order never changes the mosaic order.
map_assemble_tile :: (manifest:Capture_Manifest,directory:string,tile_x:s64,tile_y:s64,pixels:[]u8) -> string {
    return map_assemble_region(manifest,directory,tile_x*MAP_TILE_SIZE,tile_y*MAP_TILE_SIZE,MAP_TILE_SIZE,MAP_TILE_SIZE,pixels);
}

map_assemble_region :: (manifest:Capture_Manifest,directory:string,left:s64,top:s64,width:s64,height:s64,pixels:[]u8,show_progress:=false) -> string {
    assert(left>=0 && top>=0 && width>0 && height>0 && pixels.count==width*height*4);
    memset(pixels.data,0,pixels.count);
    right  := min(left+width,manifest.columns*manifest.crop_width);
    bottom := min(top+height,manifest.rows*manifest.crop_height);
    if right<=left || bottom<=top return "";
    for row:top/manifest.crop_height..(bottom-1)/manifest.crop_height {
        if show_progress print("Assembling row % / %\n",row+1,manifest.rows);
        for column:left/manifest.crop_width..(right-1)/manifest.crop_width {
            index        := capture_grid_index(manifest,column,row);
            source,error := map_read_capture_frame(manifest,directory,index);
            if error.count return error;
            defer map_image_free(*source);
            cell_left := column*manifest.crop_width; cell_top:=row*manifest.crop_height;
            x0        := max(left,cell_left); x1:=min(right,cell_left+manifest.crop_width);
            y0        := max(top,cell_top); y1:=min(bottom,cell_top+manifest.crop_height);
            for y:y0..y1-1 {
                sy := (source.height-manifest.crop_height)/2+y-cell_top;
                sx := (source.width-manifest.crop_width)/2+x0-cell_left;
                memcpy(pixels.data+((y-top)*width+x0-left)*4,source.pixels+(sy*source.width+sx)*4,(x1-x0)*4);
            }
        }
    }
    return "";
}

// The existing tile exporter remains available for maps too large for one PNG.
// Publish only after all frames decode and the complete image encodes correctly.
map_export_png :: (directory:string,output:string,run_id:u64=0,max_side:s64=0) -> string {
    return map_export_image(directory,output,run_id,max_side);
}

map_export_image :: (directory:string,output:string,run_id:u64=0,max_side:s64=0,jpeg_quality:s32=92) -> string {
    extension,found := path_extension(output);
    jpeg            := found && (equal_nocase(extension,"jpg") || equal_nocase(extension,"jpeg"));
    if !jpeg && (!found || !equal_nocase(extension,"png")) return "Output must use .jpg, .jpeg or .png.";
    if jpeg_quality<1 || jpeg_quality>100 return "JPEG quality must be 1-100.";
    ok,manifest := Json.json_parse_file(tprint("%/manifest.json",directory),Capture_Manifest);
    defer free(manifest.plan.scene); defer array_free(manifest.frames);
    if !ok return "Could not parse capture manifest.";
    if run_id && manifest.plan.run_id!=run_id return "Capture was replaced by another run.";
    error := capture_validate_manifest(manifest,complete=true);
    if error.count return error;
    cell_width,cell_height,layout_error := map_image_layout(manifest,max_side,jpeg);
    if layout_error.count return layout_error;
    width  := manifest.columns*cell_width;
    height := manifest.rows*cell_height;
    pixels := NewArray(width*height*4,u8);
    defer free(pixels.data);
    if cell_width==manifest.crop_width && cell_height==manifest.crop_height
        error = map_assemble_region(manifest,directory,0,0,width,height,pixels,show_progress=true);
    else error=map_assemble_scaled(manifest,directory,cell_width,cell_height,pixels,show_progress=true);
    if error.count return error;
    parent := path_strip_filename(output);
    if parent.count && !make_directory_if_it_does_not_exist(parent,true) return "Could not create image output directory.";
    print("Encoding % (% x % pixels)...\n",ifx jpeg then "JPEG" else "PNG",width,height);
    if jpeg error=map_write_jpeg(output,pixels.data,cast(s32)width,cast(s32)height,jpeg_quality);
    else error=map_write_png(output,pixels.data,cast(s32)width,cast(s32)height);
    if !error.count print("Map ready: % (% x % pixels)\n",output,width,height);
    return error;
}

map_png_layout :: (manifest:Capture_Manifest,max_side:s64) -> (cell_width:s64,cell_height:s64,error:string) {
    width,height,error := map_image_layout(manifest,max_side,false);
    return width,height,error;
}

map_image_layout :: (manifest:Capture_Manifest,max_side:s64,jpeg:bool) -> (cell_width:s64,cell_height:s64,error:string) {
    maximum: s64=ifx jpeg then 32768 else 16384;
    budget:  s64=ifx jpeg then 268435456 else 67108864;
    if max_side!=0 && (max_side<64 || max_side>maximum) return 0,0,tprint("Maximum side must be 64-%, or 0 for native resolution.",maximum);
    if manifest.columns<1 || manifest.rows<1 || manifest.columns>100000 || manifest.rows>100000 ||
       manifest.crop_width<1 || manifest.crop_height<1 || manifest.crop_width>16384 || manifest.crop_height>16384
        return 0,0,"Invalid image grid dimensions.";
    limit := ifx max_side then max_side else maximum;
    divisor: s64=1;
    while divisor<=max(manifest.crop_width,manifest.crop_height) {
        cw    := (manifest.crop_width+divisor-1)/divisor;
        ch    := (manifest.crop_height+divisor-1)/divisor;
        width := manifest.columns*cw; height:=manifest.rows*ch;
        if width<=limit && height<=limit && width*height<=budget return cw,ch,"";
        if !max_side break;
        divisor+=1;
    }
    return 0,0,"Single image exceeds its size budget. Set max_side to resize, or export map tiles.";
}

map_write_jpeg :: (filename:string,pixels:*u8,width:s32,height:s32,quality:s32) -> string {
    if quality<1 || quality>100 || width<1 || height<1 || width>32768 || height>32768 || !pixels return "Invalid JPEG size, pixels or quality.";
    temporary := tprint("%.tmp",filename);
    // stb emits JPEG entropy bytes one at a time. Keep its buffered file writer
    // native: millions of callbacks into Jai's #run VM stall/crash large exports.
    // The installed stb module builds Windows filenames with STBIW_WINDOWS_UTF8.
    defer if file_exists(temporary) file_delete(temporary);
    if !PNG.stbi_write_jpg(to_c_string(temporary),width,height,4,pixels,quality)
        return tprint("Could not encode JPEG: %",filename);
    // stb does not report fwrite/fclose failures. Check the on-disk header and
    // final marker before publishing; a truncated file must retain the old map.
    error := map_validate_jpeg_file(temporary,width,height);
    if error.count return error;
    if !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary,filename)
        return tprint("Could not publish JPEG: %",filename);
    return "";
}

map_validate_jpeg_file :: (filename:string,width:s32,height:s32) -> string {
    file,opened := file_open(filename);
    if !opened return tprint("Could not read encoded JPEG: %",filename);
    defer file_close(*file);
    length,sized := file_length(file);
    if !sized || length<4 return tprint("Empty or incomplete JPEG: %",filename);
    // Our stb encoder writes all metadata before the first 1 KiB. Avoid a
    // second image-sized allocation just to check dimensions and completion.
    header: [4096]u8;
    count   := min(length,header.count);
    ok,read := file_read(file,header.data,count);
    if !ok || read!=count || header[0]!=0xff || header[1]!=0xd8 return tprint("Invalid JPEG header: %",filename);
    x,y,components: s32;
    if !Image.stbi_info_from_memory(header.data,cast(s32)count,*x,*y,*components) || x!=width || y!=height || components!=3
        return tprint("Wrong encoded JPEG dimensions: %",filename);
    if !file_set_position(file,length-2) return tprint("Could not seek encoded JPEG: %",filename);
    tail: [2]u8;
    ok,read = file_read(file,tail.data,tail.count);
    if !ok || read!=tail.count || tail[0]!=0xff || tail[1]!=0xd9 return tprint("Incomplete JPEG (check free disk space): %",filename);
    return "";
}

// Resize each cell directly into the destination. Legacy full screenshots also
// supply surrounding filter samples; memory is one source frame plus the output.
map_assemble_scaled :: (manifest:Capture_Manifest,directory:string,cw:s64,ch:s64,pixels:[]u8,show_progress:=false) -> string {
    width := manifest.columns*cw;
    if cw<1 || ch<1 || pixels.count!=width*manifest.rows*ch*4 return "Invalid scaled PNG buffer.";
    for row:0..manifest.rows-1 for column:0..manifest.columns-1 {
        if show_progress && column==0 print("Assembling row % / %\n",row+1,manifest.rows);
        index        := capture_grid_index(manifest,column,row);
        source,error := map_read_capture_frame(manifest,directory,index);
        if error.count return error;
        defer map_image_free(*source);
        left   := (source.width-manifest.crop_width)/2;
        top    := (source.height-manifest.crop_height)/2;
        target := pixels.data+(row*ch*width+column*cw)*4;
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
        sums: [4]u32;
        for dy:0..1 for dx:0..1 {
            p := source+((y*2+dy)*512+x*2+dx)*4;
            for c:0..2 sums[c]+=cast(u32)p[c]*p[3];
            sums[3]+=p[3];
        }
        p := destination+((quadrant_y*256+y)*512+quadrant_x*256+x)*4;
        for c:0..2 p[c]=ifx sums[3] then cast(u8)((sums[c]+sums[3]/2)/sums[3]) else 0;
        p[3]=cast(u8)((sums[3]+2)/4);
    }
}

map_export_tile :: (output:string,z:s64,x:s64,y:s64,pixels:[]u8) -> string {
    png_dir  := tprint("%/pyramid/%/%",output,z,y);
    webp_dir := tprint("%/tiles/%/%",output,z,y);
    if !make_directory_if_it_does_not_exist(png_dir,true) || !make_directory_if_it_does_not_exist(webp_dir,true) return "Could not create tile directories.";
    source := map_tile_file(tprint("%/pyramid",output),z,x,y,"png");
    error  := map_write_png(source,pixels.data,512,512);
    if error.count return error;
    destination          := map_tile_file(tprint("%/tiles",output),z,x,y,"webp");
    temporary            := tprint("%.tmp",destination);
    result,stdout,stderr := Process.run_command("cwebp","-quiet","-lossless",source,"-o",temporary,capture_and_return_output=true);
    defer free(stdout); defer free(stderr);
    if result.type!=.EXITED || result.exit_code!=0 return tprint("cwebp failed. Install libwebp tools on PATH. %",stderr);
    if !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary,destination) return "Could not publish WebP tile.";
    return "";
}

#scope_file
#import "Basic";
#import "File";
#import "File_Utilities";
Image            :: #import "stb_image";
PNG              :: #import "stb_image_write";
Resize           :: #import "stb_image_resize";
Process          :: #import "Process";
Json             :: #import,dir "../modules/Json";
map_png_callback :: (builder:*void,bytes:*void,count:s32) #c_call {
    push_context { append(cast(*String_Builder)builder,string.{data=cast(*u8)bytes,count=count}); }
}
