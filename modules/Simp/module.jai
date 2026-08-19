//
// This is a simple framework for drawing graphics that you can use
// for most programs that are not too demanding. Or, you could copy this module
// and customize it to become what you want.
//
// Generally, doing graphics is super complicated and hairy and you have to
// think about a lot of annoying things. This framework is an experiment in asking,
// if you aren't trying to maximize performance, how simple can we make it?
// The answer is going to be, probably still not as simple as we'd like,
// because there is too much innate complication arbitrarily embedded in
// the systems we need to use in order to draw things. But, in graphics a great deal
// of complexity comes from trying to make things as fast as possible, so, we should
// be able to shave most of that off.
//
// One of the biggest problems of modern software is that people think the software
// should always be getting "better" in the sense that it tries to do every little
// thing that everyone wants. But this leads to increasing complexity, step by step.
// It's like playing Go, where, at first just putting a stone here or over there
// seemed like small, uncostly moves that provided big benefits, but now they
// have grown into a huge infrastructure that has to be maintained, and that
// maintenance itself adds more structure, and so much effort needs to be put into
// your understanding that structure that has been built up, and if your understanding
// is too incomplete then the structure will collapse.
//
// So we draw a certain very close boundary over what we are attempting to do here.
// For many simple programs, this module will be enough. Maybe someone can make
// another module called Simp+ that does more, and does introduce more constraints
// on the application, but they are not too bad, and upgrading from Simp to Simp+
// doesn't take much more than an afternoon, or whatnot. But for now we just say,
// there's a line, if your program is inside the line you can use this; once it grows
// outside the line, you probably want to switch to a bigger framework or engine
// that is much more complicated.
//

// NOTE(Charles): render_api is a module paramater, but we `#add_context simp`, so you can never actually import simp
// with different render apis? (Or actually even with same render_api it seems to break, something with module
// deduplication I guess?). The obvious move is just make it a program parameter instead?
#module_parameters (render_api := Render_API.OPENGL)() {
    Render_API :: enum u32 {
        NONE;
        SOFTWARE;
        OPENGL;
        METAL;
        NVN;
    }
}

#scope_module

#if OS == {
    case .WINDOWS;  #import "Windows";   // Maybe we should clean this up and not pull all of Windows into the namespace.
    case .LINUX;    #import "X11";       // Same.
    case .MACOS;    #import "Objective_C"; #import "Objective_C/AppKit";
}

#if render_api == .OPENGL {
    // The only platform GLES has been tested on is Android so far, but we make the distinction between Android and gles.
    IS_GLES :: OS == .ANDROID || OS == .NN_SWITCH2;

    // Android GL stuff is defined in a separate GLES module right now.
    // Is this the right thing to do? Maybe.
    #if OS == .ANDROID {
        #import "Android/EGL";
        #import "Android/GLES";

        DumpGLErrors :: inline (tag: string, loc := #caller_location) -> bool {
            // @TODO Implement this for gles.
            // Actually, the implementation in GL.jai looks like it should just work for GLES. Seems a lot like
            // Android/GLES should just be in GL module.
            return false;  // @Hack
        }
    } else #if OS == .NN_SWITCH2 {
        #import "Nintendo/EGL"(DUMP_GL_ERRORS = true);
    } else {
        #import "GL";
    }

    #load "backend/gl.jai";
} else #if render_api ==  .METAL {
    #import "Metal";
} else #if render_api == .NVN {
    #load "backend/nintendo.jai";
} else #if render_api == .NONE {
    #load "backend/none.jai";
} else {
    #assert false "Unimplemented Render Api";
}

// @Bug! This triggers an assertion in the compiler:
// *** Assertion failed: statement_index != STATEMENT_INDEX_UNNECESSARY
//     On file: C:\git\jai\src\scope.cpp
//     On line: 510
//
// #if render_api == {
//     case .OPENGL;
//         // Android GL stuff is defined in a separate GLES module right now.
//         // Is this the right thing to do? Maybe.
//         #if OS == .ANDROID {
//             #import "Android/EGL";
//             #import "Android/GLES";

//             DumpGLErrors :: inline (tag: string, loc := #caller_location) -> bool {
//                 // @TODO Implement this for gles.
//                 return false;  // @Hack
//             }
//         } else {
//             #import "GL";
//         }

//         #load "backend/gl.jai";
//     case .METAL;
//         #import "Metal";
//     case .NONE;
//         Shader_Platform :: struct {}
//         Backend_Platform_Specific :: struct {}
//         Texture_Platform_Specific :: struct {}
//         Window_Info_Platform_Specific :: struct {}

//         clear_render_target :: (r: float, g: float, b: float, a: float) {
//         }

//         pixel_read_begin :: (source: *Texture /* may be null */, dest_format: Texture_Format, width: s32 = -1, height: s32 = -1, srgb := false, flip := false) -> *Pixel_Read {
//             reader := New(Pixel_Read);  // @Cleanup: Don't use the heap?
//             return reader;
//         }

//         pixel_read_is_done :: (reader: *Pixel_Read) -> bool {
//             return true;
//         }

//         pixel_read_end :: (reader: *Pixel_Read, bitmap: *Bitmap) {
//             free(reader);
//         }
// }


#import "Basic";
#import "Math";
#import "String";
#import "Bit_Operations";
#import "Thread";

// Bitmap loading and saving:
#import "stb_image";
#import "stb_image_write";
#import "stb_image_resize";

#scope_export

// Document: New init API ... Window creation...


// Optional call to override defaults.
prepare_window :: (window: Window_Type, wanted_msaa: int) -> chosen_msaa: s32 {
    CheckInit();

    info, added := find_or_add_window_info(window);
    info.wanted_msaa = cast(s32) wanted_msaa;

    assert(!info.backend_initted_for_this_window);
    backend_init(info);
    info.backend_initted_for_this_window = true;

    if added {
        update_window(window); // Reads window width and height to the info
    }

    return info.msaa;
}


Simp_Coordinate_System :: enum u8 {
    LEFT_HANDED  :: 0;  // Will eventually be the default, but not for now.
    RIGHT_HANDED :: 1;
}

set_render_target :: (window: Window_Type, coords := Simp_Coordinate_System.RIGHT_HANDED) {
    CheckInit();

    immediate_flush();
    backend_flush();

    state.current_shader        = null;
    state.texture_render_target = null;

    context.simp.coordinate_system = coords;

    info, added := find_or_add_window_info(window);
    if !info.backend_initted_for_this_window {
        backend_init(info);
        info.backend_initted_for_this_window = true;
    }

    if added {
        update_window(window);
    }

    backend_set_render_target(info);

    state.current_window_info = info.*;
}

set_render_target :: (texture: *Texture, coords := Simp_Coordinate_System.RIGHT_HANDED) {
    // Check texture.flags for Render_Target?

    CheckInit();

    if !texture {
        log_error("Attempt to set_render_target on a null texture!\n");
        return;
    }

    immediate_flush();
    backend_flush();
    state.current_shader = null;

    state.texture_render_target = texture;
    context.simp.coordinate_system = coords;

    backend_set_render_target(texture);
}

update_window :: (window: Window_Type) {
    CheckInit();

    info := find_or_add_window_info(window); // @Cleanup: Shouldn't this be find_window_info if we might not care about it?
    if !info return;  // Ignore windows we don't understand.

    window_width, window_height := get_render_dimensions(window);
    info.window_width  = window_width;
    info.window_height = window_height;

    c := *state.current_window_info;
    if c.window == window {
        if (window_width != c.window_width) || (window_height != c.window_height) {
            backend_resize_render_target(info.*);

            // If the user changes the window after setting a shader,
            // the projection will be out-of-date, so, update it here.
            // We check state.current_shader because immediate_set_2d_projection will error
            // if it is not set.
            if !context.simp.texture_render_target {
                if state.current_shader  immediate_set_2d_projection(window_width, window_height);
            }
        }

        state.current_window_info = info.*;
    }
}

draw_text :: (font: *Dynamic_Font, x: s64, y: s64,
              text: string, color := Vector4.{1,1,1,1}, effects: Font_Effects = 0) -> width: s64 {
    // @Cleanup: generate_quads should return quads in a threadsafe way?
    width := prepare_text(font, text, effects);
    generate_quads_for_prepared_text(font, x, y, effects);
    draw_generated_quads(font, color);
    return width;
}

draw_prepared_text :: (font: *Dynamic_Font, x: s64, y: s64, color := Vector4.{1, 1, 1, 1}, effects: Font_Effects = 0) {
    generate_quads_for_prepared_text(font, x, y, effects);
    draw_generated_quads(font, color);
}

Window_Info :: struct {
    window: Window_Type;
    window_width, window_height: s32;
    wanted_msaa: s32;
    msaa:        s32;

    backend_initted_for_this_window := false;
    specific: Window_Info_Platform_Specific;
}

window_infos: [..] Window_Info;

#scope_export

set_scissor :: (p0: Vector2, p1: Vector2) {
    set_scissor(xx p0.x, xx p0.y, xx p1.x, xx p1.y);
}

// @Cleanup: This has a lot of overlap with Window_Creation’s "get_dimensions"
get_render_dimensions :: (window: Window_Type) -> (width: s32, height: s32) {
    #if OS == .WINDOWS {
        c: RECT;
        success := GetClientRect(window, *c);
        if !success  return 0, 0;

        return cast(s32)(c.right - c.left), cast(s32)(c.bottom - c.top);
    } else #if OS == .LINUX {
        root: Window;
        x, y: s32;
        width, height: u32;
        border_width, depth_return: u32;

        status := XGetGeometry(x_global_display, window, *root, *x, *y, *width, *height, *border_width, *depth_return);
        return cast(s32) width, cast(s32) height;
    } else #if OS == .MACOS {
        view := NSWindow.contentView(window);
        frame := NSView.frame(view);
        fb := NSView.convertRectToBacking(view, frame); // :MacHighResDisplays
        return cast(s32) fb.size.width, cast(s32) fb.size.height;
    } else #if OS == .ANDROID || OS == .NN_SWITCH2 {
        // Relating to the above @Cleanup, we literally use Window_Creation for switch and android!
        WC :: #import "Window_Creation";
        x, y, w, h := WC.get_dimensions(window, false);
        return w, h;
    } else {
        #assert false;
        return 0, 0;
    }
}

Pixel_Read :: struct {
    dest_format: Texture_Format;
    dest_srgb:   bool;
    dest_width, dest_height: s32;

    flip := false;

    using platform_specific: Pixel_Read_Platform;
}

// @Cleanup!
#if render_api != .OPENGL {
    disable_window :: (window: Window_Type) { assert(false, "enable/disable_window is only an opengl (and only android) thing atm."); }
    enable_window  :: (window: Window_Type) { assert(false, "enable/disable_window is only an opengl (and only android) thing atm."); }
}

//
// Those are the preliminaries. Here are this module's own files:
//

#load "bitmap.jai";
#load "texture.jai";
#load "texture_format.jai";
#load "shader.jai";
#load "immediate.jai";
#load "font.jai";

#scope_module
find_window_info :: (window: Window_Type) -> *Window_Info {
    for * window_infos  if it.window == window  return it;
    return null;
}
#scope_file

find_or_add_window_info :: (window: Window_Type) -> *Window_Info, bool {
    for * window_infos  if it.window == window  return it, false;

    info := array_add(*window_infos);
    info.window = window;
    return info, true;
}


