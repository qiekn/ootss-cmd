#!/usr/bin/env jai

// Generated noise only; no game access, capture or image display.
#run {
    set_build_options_dc(.{do_output=false});
    set_working_directory(tprint("%/..",#filepath));
    check_large_jpeg();
    print("PASS: % JPEG export checks.\n",checks);
}

checks: s64;
check :: (ok:bool,message:string) {
    checks+=1;
    if !ok { compiler_report(message); assert(ok); }
}

check_large_jpeg :: () {
    directory := ".build/jpeg-地图";
    output    := tprint("%/large.jpg",directory);
    temporary := tprint("%.tmp",output);
    check(make_directory_if_it_does_not_exist(directory,true),"Create Unicode JPEG fixture directory.");
    width  :: 4096;
    height :: 4096;
    pixels := NewArray(width*height*4,u8);
    defer free(pixels.data);
    // This detailed 16 MP image reproduces the old per-byte #run callback's
    // excessive committed memory and crash, unlike the old tiny flat fixture.
    state: u32=123456789;
    for i:0..65535 {
        state = state^(state<<13); state=state^(state>>17); state=state^(state<<5);
        for c:0..2 pixels[i*4+c]=cast(u8)((state>>(c*8))&255);
        pixels[i*4+3]=255;
    }
    for block:1..255 memcpy(pixels.data+block*65536*4,pixels.data,65536*4);
    started := seconds_since_init();
    check(!map_write_jpeg(output,pixels.data,width,height,92).count,"Write a detailed large JPEG through a Unicode path without VM callbacks.");
    print("Large JPEG encoded in % seconds.\n",seconds_since_init()-started);
    check(!file_exists(temporary),"Successful JPEG publication leaves no temporary file.");
    encoded,read_ok := read_entire_file(output);
    defer free(encoded);
    check(read_ok && encoded.count>10000000,"Exercise millions of entropy bytes, not just large flat dimensions.");
    check(!map_validate_jpeg_file(output,width,height).count,"Validate the encoded dimensions and end marker.");
    decoded,decode_error := map_read_png(output,width,height);
    defer map_image_free(*decoded);
    check(!decode_error.count,"Decode every pixel of the large JPEG.");
    difference: s64;
    samples :: 4096;
    for i:0..samples-1 {
        pixel := i*4093;
        for c:0..2 difference+=abs(cast(s64)decoded.pixels[pixel*4+c]-pixels[pixel*4+c]);
    }
    check(difference<samples*3*12,"Decoded detail matches source samples within JPEG loss tolerance.");

    check(map_write_jpeg(output,pixels.data,width,height,0).count>0,"Reject invalid quality without replacing output.");
    check(map_write_jpeg(output,pixels.data,32769,height,92).count>0,"Reject unsupported dimensions before accessing pixels.");
    check(map_write_jpeg(output,null,width,height,92).count>0,"Reject absent pixels.");
    check(map_write_jpeg(tprint("%/missing/image.jpg",output),pixels.data,1,1,92).count>0,"Report a temporary-file creation failure.");
    {
        locked,opened := file_open(temporary,for_writing=true);
        check(opened,"Hold the temporary file against writer access.");
        defer file_close(*locked);
        check(map_write_jpeg(output,pixels.data,1,1,92).count>0,"Report a locked temporary file without replacing the map.");
    }
    check(file_delete(temporary),"Remove the isolated locked-file fixture.");
    {
        locked,opened := file_open(output);
        check(opened,"Hold destination against replacement.");
        defer file_close(*locked);
        check(map_write_jpeg(output,pixels.data,1,1,92).count>0,"Report atomic publication failure.");
    }
    check(!file_exists(temporary),"Failed publication cleans up the temporary JPEG.");
    retained,retained_ok := read_entire_file(output);
    defer free(retained);
    check(retained_ok && retained==encoded,"All failed exports preserve the previous image byte for byte.");

    damaged := tprint("%/truncated.jpg",directory);
    defer if file_exists(damaged) file_delete(damaged);
    check(write_entire_file(damaged,encoded.data,encoded.count-2),"Generate a truncated on-disk JPEG.");
    check(map_validate_jpeg_file(damaged,width,height).count>0,"Reject an interrupted write with no end marker.");
    check(write_entire_file(damaged,""),"Generate an empty output file.");
    check(map_validate_jpeg_file(damaged,width,height).count>0,"Reject an empty output file.");
    check(write_entire_file(damaged,"not a JPEG"),"Generate an invalid header.");
    check(map_validate_jpeg_file(damaged,width,height).count>0,"Reject invalid JPEG headers.");
    check(map_validate_jpeg_file(output,width+1,height).count>0,"Reject mismatched JPEG dimensions.");
}

#load "../src/game/capture_plan.jai";
#load "map_tiles.jai";
#import "Basic";
#import "Compiler";
#import "File";
#import "System";
