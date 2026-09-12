Overlay_Image_Placement :: struct {
    bounds: Win.RECT;
    image_left, image_top, image_width, image_height: s32;
}

Overlay_Image_Surface :: struct {
    dc: Win.HDC;
    bitmap, previous: Win.HGDIOBJ;
    pixels: *u8;
    width, height: s32;
}

Overlay_Image_State :: struct {
    window: Win.HWND;
    pixels: *u8;
    bitmap: Win.BITMAPINFO;
    placement: Overlay_Image_Placement;
    screen_bounds: Win.RECT;
    visible: bool;
    per_pixel_alpha: bool;
    surface: Overlay_Image_Surface;
}

overlay_image: Overlay_Image_State;

overlay_image_fit :: (width: s32, height: s32, left: s32, top: s32, right: s32, bottom: s32,
                      padding: s32 = 0) -> Overlay_Image_Placement {
    result: Overlay_Image_Placement;
    left += padding;
    top += padding;
    right -= padding;
    bottom -= padding;
    if width <= 0 || height <= 0 || right <= left || bottom <= top return result;
    scale := min(cast(float64)(right - left) / width, cast(float64)(bottom - top) / height);
    result.image_width = max(cast(s32) 1, cast(s32)(width * scale));
    result.image_height = max(cast(s32) 1, cast(s32)(height * scale));
    x := left + (right - left - result.image_width) / 2;
    y := top + (bottom - top - result.image_height) / 2;
    result.bounds = .{x, y, x + result.image_width, y + result.image_height};
    return result;
}

overlay_image_fit_integer :: (width: s32, height: s32, left: s32, top: s32, right: s32, bottom: s32,
                              padding: s32 = 0) -> Overlay_Image_Placement {
    result: Overlay_Image_Placement;
    left += padding;
    top += padding;
    right -= padding;
    bottom -= padding;
    if width <= 0 || height <= 0 || right <= left || bottom <= top return result;
    scale := max(cast(s32) 1, min((right - left) / width, (bottom - top) / height));
    result.image_width = width * scale;
    result.image_height = height * scale;
    x := left + (right - left - result.image_width) / 2;
    y := top + (bottom - top - result.image_height) / 2;
    // If even 1x cannot fit, clip within the padded viewport instead of distorting the pixels.
    result.bounds = .{max(left, x), max(top, y), min(right, x + result.image_width), min(bottom, y + result.image_height)};
    result.image_left = x - result.bounds.left;
    result.image_top = y - result.bounds.top;
    return result;
}

overlay_image_create :: (per_pixel_alpha := false) -> bool {
    if overlay_image.window && overlay_image.per_pixel_alpha == per_pixel_alpha return true;
    if overlay_image.window overlay_image_destroy();
    if !overlay.window return false;
    instance := Win.GetModuleHandleW(null);
    name := utf8_to_wide("OOTSS Console GIF",, temp);
    wc: Win.WNDCLASSEXW;
    wc.cbSize = size_of(Win.WNDCLASSEXW);
    wc.style = Win.CS_HREDRAW | Win.CS_VREDRAW;
    wc.lpfnWndProc = overlay_image_window_proc;
    wc.hInstance = instance;
    wc.hCursor = Win.LoadCursorW(null, Win.IDC_ARROW);
    wc.lpszClassName = name;
    if !Win.RegisterClassExW(*wc) && Win.GetLastError() != 1410 return false;

    // Owned popups have independent opacity. PNGs use per-pixel alpha; opaque media uses the existing GDI path.
    style: u32 = Win.WS_EX_TOOLWINDOW | Win.WS_EX_TOPMOST | Win.WS_EX_NOACTIVATE;
    if per_pixel_alpha style |= Win.WS_EX_LAYERED;
    overlay_image.window = Win.CreateWindowExW(
        style,
        name, name, Win.WS_POPUP, 0, 0, 1, 1, overlay.window, null, instance, null);
    overlay_image.per_pixel_alpha = per_pixel_alpha;
    return overlay_image.window != null;
}

overlay_image_show :: (pixels: *u8, width: s32, height: s32, placement: Overlay_Image_Placement,
                       pixels_changed: bool, per_pixel_alpha := false) -> bool {
    r := placement.bounds;
    if !overlay.visible || !pixels || r.right <= r.left || r.bottom <= r.top {
        overlay_image_hide();
        return true;
    }
    origin: Win.POINT = .{r.left, r.top};
    if !Win.ClientToScreen(overlay.window, *origin) || !overlay_image_create(per_pixel_alpha) {
        overlay_image_hide();
        return false;
    }
    screen: Win.RECT = .{origin.x, origin.y, origin.x + r.right - r.left, origin.y + r.bottom - r.top};
    old := overlay_image.screen_bounds;
    moved := !overlay_image.visible || screen.left != old.left || screen.top != old.top ||
             screen.right != old.right || screen.bottom != old.bottom;
    redraw := moved || pixels_changed || overlay_image.pixels != pixels ||
              overlay_image.bitmap.bmiHeader.biWidth != width || overlay_image.bitmap.bmiHeader.biHeight != -height ||
              overlay_image.placement.image_left != placement.image_left ||
              overlay_image.placement.image_top != placement.image_top ||
              overlay_image.placement.image_width != placement.image_width ||
              overlay_image.placement.image_height != placement.image_height;
    overlay_image.pixels = pixels;
    overlay_image.placement = placement;
    overlay_image.bitmap.bmiHeader = .{
        biSize = size_of(Win.BITMAPINFOHEADER), biWidth = width, biHeight = -height,
        biPlanes = 1, biBitCount = 32, biCompression = Win.BI_RGB
    };
    if redraw && per_pixel_alpha {
        surface := *overlay_image.surface;
        if !overlay_image_surface_resize(surface, screen.right - screen.left, screen.bottom - screen.top) {
            overlay_image_hide();
            return false;
        }
        overlay_image_scale_alpha(pixels, width, height, placement, surface);
        destination: Win.POINT = .{screen.left, screen.top};
        source: Win.POINT;
        size: Win.SIZE = .{surface.width, surface.height};
        blend: Image_Blend_Function = .{0, 0, 255, 1}; // AC_SRC_OVER, full opacity, AC_SRC_ALPHA.
        if !UpdateLayeredWindow(overlay_image.window, null, *destination, *size, surface.dc, *source, 0, *blend, 2) {
            overlay_image_hide();
            return false;
        }
    }
    if moved {
        if !Win.SetWindowPos(overlay_image.window, Win.HWND_TOPMOST, screen.left, screen.top,
                            screen.right - screen.left, screen.bottom - screen.top,
                            Win.SWP_NOACTIVATE | Win.SWP_NOOWNERZORDER | Win.SWP_SHOWWINDOW) {
            overlay_image_hide();
            return false;
        }
        overlay_image.screen_bounds = screen;
        overlay_image.visible = true;
    }
    if redraw && !per_pixel_alpha {
        InvalidateRect(overlay_image.window, null, 0);
        Win.UpdateWindow(overlay_image.window);
    }
    return true;
}

overlay_image_surface_resize :: (surface: *Overlay_Image_Surface, width: s32, height: s32) -> bool {
    if width <= 0 || height <= 0 return false;
    if surface.pixels && surface.width == width && surface.height == height return true;
    overlay_image_surface_free(surface);
    ready := false;
    defer if !ready overlay_image_surface_free(surface);
    surface.dc = Win.CreateCompatibleDC(null);
    if !surface.dc return false;
    info: Win.BITMAPINFO;
    info.bmiHeader = .{biSize = size_of(Win.BITMAPINFOHEADER), biWidth = width, biHeight = -height,
                      biPlanes = 1, biBitCount = 32, biCompression = Win.BI_RGB};
    surface.bitmap = CreateDIBSection(surface.dc, *info, Win.DIB_RGB_COLORS, *surface.pixels, null, 0);
    if !surface.bitmap || !surface.pixels return false;
    surface.previous = Win.SelectObject(surface.dc, surface.bitmap);
    if !surface.previous || surface.previous == cast(Win.HGDIOBJ) -1 {
        surface.previous = null;
        return false;
    }
    surface.width = width;
    surface.height = height;
    ready = true;
    return true;
}

overlay_image_surface_free :: (surface: *Overlay_Image_Surface) {
    if surface.dc && surface.previous Win.SelectObject(surface.dc, surface.previous);
    if surface.bitmap Win.DeleteObject(surface.bitmap);
    if surface.dc Win.DeleteDC(surface.dc);
    surface.* = .{};
}

overlay_image_scale_alpha :: (pixels: *u8, width: s32, height: s32, placement: Overlay_Image_Placement,
                             surface: *Overlay_Image_Surface) {
    // Scale premultiplied color and alpha together so transparent RGB never creates a dark fringe.
    for y: 0..surface.height - 1 {
        source_y := max(cast(float64) 0, min(cast(float64)(height - 1),
            (cast(float64)(y - placement.image_top) + 0.5) * height / placement.image_height - 0.5));
        y0 := cast(s32) source_y;
        y1 := min(y0 + 1, height - 1);
        fy := source_y - y0;
        for x: 0..surface.width - 1 {
            source_x := max(cast(float64) 0, min(cast(float64)(width - 1),
                (cast(float64)(x - placement.image_left) + 0.5) * width / placement.image_width - 0.5));
            x0 := cast(s32) source_x;
            x1 := min(x0 + 1, width - 1);
            fx := source_x - x0;
            top_left := pixels + (cast(s64) y0 * width + x0) * 4;
            top_right := pixels + (cast(s64) y0 * width + x1) * 4;
            bottom_left := pixels + (cast(s64) y1 * width + x0) * 4;
            bottom_right := pixels + (cast(s64) y1 * width + x1) * 4;
            output := surface.pixels + (cast(s64) y * surface.width + x) * 4;
            for channel: 0..3 {
                top := top_left[channel] * (1 - fx) + top_right[channel] * fx;
                bottom := bottom_left[channel] * (1 - fx) + bottom_right[channel] * fx;
                output[channel] = cast(u8)(top * (1 - fy) + bottom * fy + 0.5);
            }
        }
    }
}

overlay_image_hide :: () {
    if overlay_image.window && overlay_image.visible Win.ShowWindow(overlay_image.window, Win.SW_HIDE);
    overlay_image.visible = false;
    // WM_PAINT must never retain a pointer into an image that can now be unloaded.
    overlay_image.pixels = null;
}

overlay_image_destroy :: () {
    overlay_image_hide();
    if overlay_image.window Win.DestroyWindow(overlay_image.window);
    overlay_image_surface_free(*overlay_image.surface);
    overlay_image = .{};
}

overlay_image_paint :: (dc: Win.HDC) {
    if !overlay_image.pixels || overlay_image.per_pixel_alpha return;
    placement := overlay_image.placement;
    Win.SetStretchBltMode(dc, .HALFTONE);
    SetBrushOrgEx(dc, 0, 0, null);
    StretchDIBits(dc, placement.image_left, placement.image_top, placement.image_width, placement.image_height,
                 0, 0, overlay_image.bitmap.bmiHeader.biWidth, -overlay_image.bitmap.bmiHeader.biHeight,
                 overlay_image.pixels, *overlay_image.bitmap, Win.DIB_RGB_COLORS, .SRCCOPY);
}

#scope_file
#import "Basic";
#import "Windows_Utf8";
Win :: #import "Windows";

overlay_image_window_proc :: (window: Win.HWND, message: u32, wparam: u64, lparam: s64) -> s64 #c_call {
    push_context {
        // Route mouse input through to the console on this thread, without ever taking keyboard focus.
        if message == Win.WM_NCHITTEST return -1; // HTTRANSPARENT
        if message == Win.WM_MOUSEACTIVATE return 3; // MA_NOACTIVATE
        if message == Win.WM_ERASEBKGND return 1;
        if message == Win.WM_DPICHANGED return 0; // The console supplies physical pixel bounds each frame.
        if message == Win.WM_PAINT {
            paint: Paint_Struct;
            dc := BeginPaint(window, *paint);
            if dc overlay_image_paint(dc);
            EndPaint(window, *paint);
            return 0;
        }
        if message == Win.WM_NCDESTROY && window == overlay_image.window {
            overlay_image.window = null;
            overlay_image.visible = false;
            overlay_image.pixels = null;
        }
        return Win.DefWindowProcW(window, message, wparam, lparam);
    }
}

Paint_Struct :: struct {
    dc: Win.HDC;
    erase: s32;
    bounds: Win.RECT;
    restore, incremental: s32;
    reserved: [32] u8;
}

Image_Blend_Function :: struct { operation, flags, opacity, alpha_format: u8; }

user32 :: #library,system "user32";
gdi32 :: #library,system "gdi32";
CreateDIBSection :: (dc: Win.HDC, info: *Win.BITMAPINFO, usage: u32, pixels: **u8,
                     section: Win.HANDLE, offset: u32) -> Win.HGDIOBJ #foreign gdi32;
UpdateLayeredWindow :: (window: Win.HWND, destination_dc: Win.HDC, destination: *Win.POINT, size: *Win.SIZE,
                        source_dc: Win.HDC, source: *Win.POINT, color_key: u32,
                        blend: *Image_Blend_Function, flags: u32) -> s32 #foreign user32;
BeginPaint :: (window: Win.HWND, paint: *Paint_Struct) -> Win.HDC #foreign user32;
EndPaint :: (window: Win.HWND, paint: *Paint_Struct) -> s32 #foreign user32;
InvalidateRect :: (window: Win.HWND, bounds: *Win.RECT, erase: s32) -> s32 #foreign user32;
SetBrushOrgEx :: (dc: Win.HDC, x: s32, y: s32, previous: *Win.POINT) -> s32 #foreign gdi32;
StretchDIBits :: (dc: Win.HDC, x: s32, y: s32, width: s32, height: s32,
                  source_x: s32, source_y: s32, source_width: s32, source_height: s32,
                  pixels: *void, bitmap: *Win.BITMAPINFO, usage: u32, operation: Win.ROP) -> s32 #foreign gdi32;
