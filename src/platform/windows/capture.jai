// DWM desktop capture, limited to the unobscured game client. Helpers are hidden
// before acquisition; focus and occlusion are checked again after copying pixels.
capture_client_bounds :: (game: Win.HWND) -> (bounds: Win.RECT, error: string) {
    bounds: Win.RECT;
    origin: Win.POINT;
    if !game || Win.GetForegroundWindow()!=game || !Win.GetClientRect(game,*bounds) ||
       !Win.ClientToScreen(game,*origin) return bounds, "Focus the game to capture it.";
    bounds.right += origin.x;
    bounds.bottom += origin.y;
    bounds.left = origin.x;
    bounds.top  = origin.y;
    x := Win.GetSystemMetrics(76); y := Win.GetSystemMetrics(77);
    if bounds.left<x || bounds.top<y || bounds.right>x+Win.GetSystemMetrics(78) ||
       bounds.bottom>y+Win.GetSystemMetrics(79) return bounds, "Keep the entire game client on screen.";
    return bounds, "";
}

capture_unobscured :: (game: Win.HWND, bounds: Win.RECT) -> bool {
    search: Capture_Occlusion = .{game=game,bounds=bounds};
    CaptureEnumWindows(capture_occlusion_proc,cast(s64)*search);
    return search.found && !search.blocked;
}

capture_save_client :: (game: Win.HWND, manifest: Capture_Manifest, filename: string) -> string {
    width         := manifest.width;
    height        := manifest.height;
    bounds, error := capture_client_bounds(game);
    if error.count return error;
    if bounds.right-bounds.left!=width || bounds.bottom-bounds.top!=height return "Game resolution changed; capture paused.";
    if !capture_unobscured(game,bounds) return "Another window covers the game; capture paused.";
    surface: Overlay_Image_Surface;
    defer overlay_image_surface_free(*surface);
    if !overlay_image_surface_resize(*surface,width,height) return "Could not allocate screenshot pixels.";
    dc := Win.GetDC(null);
    if !dc return "Could not access the desktop drawable.";
    defer Win.ReleaseDC(null,dc);
    if !Win.BitBlt(surface.dc,0,0,width,height,dc,bounds.left,bounds.top,.SRCCOPY) return "Game capture failed.";
    after, after_error := capture_client_bounds(game);
    if after_error.count || after.left!=bounds.left || after.top!=bounds.top || after.right!=bounds.right ||
       after.bottom!=bounds.bottom || !capture_unobscured(game,bounds) return "The game moved or lost focus during capture.";
    visible := false;
    for i: 0..cast(s64)width*height-1 {
        pixel := surface.pixels+i*4;
        if pixel[0]>3 || pixel[1]>3 || pixel[2]>3 visible=true;
        red := pixel[2]; pixel[2]=pixel[0]; pixel[0]=red; pixel[3]=255;
    }
    if !visible return "The captured frame is black. Use a visible windowed or borderless game.";
    cropped: []u8;
    defer if cropped.data free(cropped.data);
    pixels := surface.pixels;
    if manifest.plan.crop_world_size>0 {
        cropped = NewArray(cast(s64)manifest.crop_width*manifest.crop_height*4,u8);
        error   = capture_crop_pixels(manifest,.{data=surface.pixels,count=cast(s64)width*height*4},cropped);
        if error.count return error;
        pixels = cropped.data;
        width  = manifest.crop_width;
        height = manifest.crop_height;
    }
    encoded: String_Builder;
    defer free_buffers(*encoded);
    if !PNG.stbi_write_png_to_func(capture_png_callback,*encoded,width,height,4,pixels,width*4) return "PNG encoding failed.";
    temporary := tprint("%.tmp",filename);
    if !write_entire_file(temporary,*encoded) || !atomic_file_replace_or_just_rename_if_destination_file_does_not_exist(temporary,filename) {
        return "Could not save screenshot atomically.";
    }
    return "";
}

Capture_Copy_Data :: struct { id: u64; count: u32; data: *u8; }

capture_receive_request :: (lparam: s64) -> s64 {
    request := cast(*Capture_Copy_Data)lparam;
    if !request || (request.id!=CAPTURE_COPYDATA_ID && request.id!=CAPTURE_RUN_COPYDATA_ID && request.id!=CAPTURE_V2_COPYDATA_ID && request.id!=CAPTURE_V3_COPYDATA_ID) || !request.count || request.count>32768 ||
       !request.data || capture.pending.count return 0;
    text: string = .{data=request.data,count=request.count};
    if contains(text,cast(u8)0) return 0;
    capture.pending = copy_string(text);
    return 1;
}

#scope_file
PNG                          :: #import "stb_image_write";
user32                       :: #library,system "user32";
dwmapi                       :: #library,system "dwmapi";
CaptureEnumWindows           :: (callback: #type (Win.HWND,s64)->s32 #c_call, parameter: s64) -> s32 #foreign user32 "EnumWindows";
CaptureIsWindowVisible       :: (window: Win.HWND) -> s32 #foreign user32 "IsWindowVisible";
CaptureDwmGetWindowAttribute :: (window: Win.HWND, attribute: u32, value: *void, size: u32) -> s32 #foreign dwmapi "DwmGetWindowAttribute";
Capture_Occlusion            :: struct { game: Win.HWND; bounds: Win.RECT; found, blocked: bool; }
capture_occlusion_proc       :: (window: Win.HWND, parameter: s64) -> s32 #c_call {
    push_context {
        search := cast(*Capture_Occlusion)parameter;
        if window==search.game { search.found=true; return 0; }
        if !CaptureIsWindowVisible(window) return 1;
        cloaked: u32;
        if CaptureDwmGetWindowAttribute(window,14,*cloaked,4)==0 && cloaked return 1;
        r: Win.RECT;
        if Win.GetWindowRect(window,*r) && r.right>search.bounds.left && r.left<search.bounds.right &&
           r.bottom>search.bounds.top && r.top<search.bounds.bottom {
            search.blocked = true;
            return 0;
        }
        return 1;
    }
}
capture_png_callback :: (builder: *void, bytes: *void, count: s32) #c_call {
    push_context { append(cast(*String_Builder)builder,string.{data=cast(*u8)bytes,count=count}); }
}
