// Pure pixel processing, shared by screenshot acquisition and synthetic checks.
capture_crop_pixels :: (manifest:Capture_Manifest,source:[]u8,destination:[]u8) -> string {
    if manifest.plan.version!=3 || manifest.plan.crop_world_size<=0 ||
       manifest.width<64 || manifest.height<64 || manifest.width>16384 || manifest.height>16384 ||
       !is_finite(manifest.source_crop_size) || manifest.source_crop_size<2 || manifest.source_crop_size>cast(float64)min(manifest.width,manifest.height) ||
       manifest.crop_width!=cast(s32)floor(manifest.source_crop_size) || manifest.crop_height!=manifest.crop_width ||
       !source.data || !destination.data ||
       source.count!=cast(s64)manifest.width*manifest.height*4 || destination.count!=cast(s64)manifest.crop_width*manifest.crop_height*4
        return "Invalid world-crop pixel buffers or dimensions.";
    left := (manifest.width-manifest.source_crop_size)/2;
    top  := (manifest.height-manifest.source_crop_size)/2;
    if !Capture_Resize.stbir_resize_region(source.data,manifest.width,manifest.height,manifest.width*4,
        destination.data,manifest.crop_width,manifest.crop_height,manifest.crop_width*4,
        .TYPE_UINT8,4,3,0,.CLAMP,.CLAMP,.BOX,.BOX,.COLORSPACE_SRGB,null,
        cast(float)(left/manifest.width),cast(float)(top/manifest.height),
        cast(float)((left+manifest.source_crop_size)/manifest.width),cast(float)((top+manifest.source_crop_size)/manifest.height))
        return "Could not crop the central world square.";
    return "";
}

#scope_file
#import "Basic";
#import "Math";
Capture_Resize :: #import "stb_image_resize";
