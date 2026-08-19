#load "gl_screenshot.jai";

//
// Init stuff:
//

backend_init :: (info: *Window_Info) {
    CheckInit();  // Set up context.simp.

    do_first_time_init := false;

    // @Threadsafety
    if the_gl_context {
        #if OS == .WINDOWS {
            hdc := GetDC(info.window);
            windows_change_pixel_format(hdc);
            info.specific.hdc = hdc;
        }
    } else {
        do_first_time_init = true;

        #if OS == .WINDOWS {
            hglrc, hdc, chosen_msaa := wgl_create_context(info.window, null, MINIMUM_GL_MAJOR_VERSION, MINIMUM_GL_MINOR_VERSION, wanted_msaa=info.wanted_msaa);
            the_gl_context = hglrc;
            the_hdc_for_pixel_format_cloning = hdc;
            info.msaa = chosen_msaa;
            info.specific.hdc     = hdc;
        } else #if OS == .LINUX {
            the_gl_context, the_gl_fbc, info.msaa = glx_create_context(info.window, MINIMUM_GL_MAJOR_VERSION, MINIMUM_GL_MINOR_VERSION);
        } else #if OS == .MACOS {
            the_gl_context, info.msaa = nsgl_create_context(MINIMUM_GL_MAJOR_VERSION, MINIMUM_GL_MINOR_VERSION, wanted_msaa=info.wanted_msaa);
            autorelease(the_gl_context);
        } else #if OS == .ANDROID {
            egl_info, info.msaa = egl_create_context(info.window, info.wanted_msaa);
            the_gl_context = egl_info.context_;
        } else #if OS == .NN_SWITCH2 {
            the_gl_context, the_egl_display, the_egl_surface, info.msaa = egl_create_context(info.window, info.wanted_msaa);
        } else {
            #assert false;
        }
    }

    #if OS == .MACOS {
        // Get the GL view from the window.
        // This relies on this window having a content view with OpenGL support (eg. as created by Window_Creation).
        view := NSWindow.contentView(info.window);
        assert(view != null);
        NSView.setWantsBestResolutionOpenGLSurface(view, YES);
        NSOpenGLContext.setView(the_gl_context, view);
        NSOpenGLContext.update(the_gl_context);
    }

    #if OS == .LINUX {
        // Make dumb wrapper window.
        // Must happen before glGen*, because we make current.
        glx_window := glXCreateWindow(x_global_display, the_gl_fbc, info.window, null);
        info.specific.glx_window = glx_window;
    }

    if do_first_time_init {
        // @Cleanup: Windows and Android make current during egl/wgl_create_context, Linux and mac don't. Which is correct?
        #if OS == .LINUX  glXMakeCurrent(x_global_display, glx_window, the_gl_context);
        #if OS == .MACOS  NSOpenGLContext.makeCurrentContext(the_gl_context);

        #if OS == .NN_SWITCH2 {
            egl_init();
        }
        #if OS != .ANDROID && OS != .NN_SWITCH2 {
            // @Incomplete: Android/switch2 have separate GLES modules that don't have this modules/GL stuff.
            gl_load(*gl);
        }
        #if OS != .ANDROID {
            gl_enable_debug_output(break_on_error = true);
        }

        glGenVertexArrays(1, *opengl_is_stupid_vao);
        glGenBuffers(1, *immediate_vbo);

        backend_init_shaders();

        DumpGLErrors("context");
    }

    state.current_window_info = info.*;
}

// NOTE(Charles): To support :AndroidWindowSurfaceRecreation. We want to keep all our gl stuff, but we need to recreate
// the window surface, and update the info.window reference. See example.jai for usage.
//
// I initially tried to make a platform abstration that would work for android, and potentially iOS which I think will
// want to do something similar. But it got pretty messy/dumb so this is more directly just an android thing atm.
//
// A wild idea... Simp puts its state on the context, maybe the Input module could handle the surface destroy/creation
// itself if Simp is in use, and not require the user to call this enable/disable_window thing? We can log error in
// swap_buffers if the user trys to render while we dont have a window. This would be Simp specific though...

disable_window :: (window: Window_Type) {
    CheckInit();

    // info := find_window_info(window);
    // if !info  return;

    // backend_disable_window(*info);
    #if OS == .ANDROID {
        assert(window_infos.count == 1, "There can be only one (window on android)");
        info := *window_infos[0];

        assert(info.specific.disabled == false, "Window is already disabled");
        assert(info.window != INVALID_WINDOW);

        current := *state.current_window_info;
        assert(info.window == current.window, "There should only ever be one window on android");

        info.window = INVALID_WINDOW;
        info.specific.disabled = true;
        egl_destroy_surface(*egl_info);

        current.* = info.*;
    } else {
        assert(false, "enable/disable window is an android only thing atm!");
    }
}

enable_window :: (window: Window_Type) {
    CheckInit();

    // info := find_window_info(window);
    // if !info  return;

    // backend_enable_window(*info, window);
    #if OS == .ANDROID {
        assert(window_infos.count == 1, "There can be only one (window on android)");
        info := *window_infos[0];

        assert(info.specific.disabled == true, "Window is not disabled");
        assert(window != INVALID_WINDOW);

        current := *state.current_window_info;
        assert(info.window == current.window, "There should only ever be one window on android");

        info.window = window;
        info.specific.disabled = false;
        egl_create_surface(*egl_info, window);

        current.* = info.*;
    } else {
        assert(false, "enable/disable window is an android only thing atm!");
    }
}

#scope_module


opengl_is_stupid_vao: GLuint;
immediate_vbo:        GLuint;
main_fbo_handle:      GLuint;

#if OS == .WINDOWS {
    the_gl_context: HGLRC;
    the_hdc_for_pixel_format_cloning: HDC;
} else #if OS == .LINUX {
    the_gl_context: GLXContext;
    the_gl_fbc: GLXFBConfig;
} else #if OS == .ANDROID {
    the_gl_context:  EGLContext;
    egl_info: EGL_Info;
    // NOTE(Charles): EGL_Info contains the window surface, which could maybe go in Window_Info_Platform_Specific, but
    // afaict you only ever have one window on android so I am not sweating it!
} else #if OS == .NN_SWITCH2 {
    the_gl_context:  EGLContext;
    the_egl_display: EGLDisplay;
    the_egl_surface: EGLSurface;
} else {
    the_gl_context: *NSOpenGLContext;
}

is_supported :: (tf: Texture_Format) -> bool {
    return get_ogl_format(tf) != GL_INVALID_ENUM;
}

#scope_file

MINIMUM_GL_MAJOR_VERSION :: 3;
MINIMUM_GL_MINOR_VERSION :: 3;

set_vertex_format_to_XCNUU :: (shader: *Shader) {
//    using extensions;

//    vertex_format_set_to_XCNUU = true;

    T :: Immediate_Vertex;
    stride := cast(GLsizei) size_of(T);
    offset: *T: null;

    if shader.position_loc != -1 {
        DumpGLErrors("position - beforehand abc");
        // ArrayAttrib is GL 4.5 and some Intel chips don't have it.
        // glEnableVertexArrayAttrib(opengl_is_stupid_vao, xx shader.position_loc);
        glEnableVertexAttribArray(xx shader.position_loc);
        DumpGLErrors("position - mid");
        glVertexAttribPointer(xx shader.position_loc, 3, GL_FLOAT, xx false, stride, xx *offset.position);
        DumpGLErrors("position - After");
    }

    DumpGLErrors("position - VertexAttribArray");

    if shader.color_scale_loc != -1 {
        glVertexAttribPointer(xx shader.color_scale_loc, 4, GL_FLOAT, xx true, stride, xx *offset.color_scale);
        glEnableVertexAttribArray(xx shader.color_scale_loc);
        DumpGLErrors("color");
    }

    if shader.normal_loc != -1 {
        glVertexAttribPointer(xx shader.normal_loc, 3, GL_FLOAT, xx false, stride, xx *offset.normal);
        glEnableVertexAttribArray(xx shader.normal_loc);
        DumpGLErrors("normal");
    }

    if shader.tangent_loc != -1 {
        glVertexAttribPointer(xx shader.tangent_loc, 4, GL_FLOAT, xx false, stride, xx *offset.tangent);
        glEnableVertexAttribArray(xx shader.tangent_loc);
        DumpGLErrors("tangent");
    }

    if shader.uv_0_loc != -1 {
        glVertexAttribPointer(xx shader.uv_0_loc, 2, GL_FLOAT, xx false, stride, xx *offset.uv0);
        glEnableVertexAttribArray(xx shader.uv_0_loc);
        DumpGLErrors("uv0");
    }

    if shader.uv_1_loc != -1 {
        glVertexAttribPointer(xx shader.uv_1_loc, 2, GL_FLOAT, xx false, stride, xx *offset.uv1);
        glEnableVertexAttribArray(xx shader.uv_1_loc);
        DumpGLErrors("uv1");
    }

//    if shader.blend_weights_loc != -1  glDisableVertexAttribArray(xx shader.blend_weights_loc);
//    if shader.blend_indices_loc != -1  glDisableVertexAttribArray(xx shader.blend_indices_loc);
}


//
// Shader stuff:
//

#scope_export

Shader_Platform :: struct {
    gl_handle: GLuint;

    position_loc:      GLint = -1;
    color_scale_loc:   GLint = -1;
    normal_loc:        GLint = -1;
    tangent_loc:       GLint = -1;
    uv_0_loc:          GLint = -1;
    uv_1_loc:          GLint = -1;

    diffuse_texture_loc: GLint = -1;

    alpha_blend := false;
}

set_parameter :: (shader: *Shader, name: *u8, m: Matrix4) {
    loc := glGetUniformLocation(shader.gl_handle, name);
    if loc < 0   log_error("Unknown parameter: '%'\n", to_string(name));
    if loc >= 0  glUniformMatrix4fv(loc, 1, GL_TRUE, *m._11);
}

clear_render_target :: (r: float, g: float, b: float, a: float) {
    glClearColor(r, g, b, a);
    glClear(GL_COLOR_BUFFER_BIT);
}

set_scissor :: (x0: s32, y0: s32, x1: s32, y1: s32) {
    CheckInit();

    immediate_flush();
    glEnable(GL_SCISSOR_TEST);

    h := ifx state.texture_render_target {
        state.texture_render_target.height;
    } else {
        state.current_window_info.window_height;
    }

    dx := cast(u32)max(x1-x0, 0);  // If you invert the input rectangle, just give a 0 width.
    dy := cast(u32)max(y1-y0, 0);
    if state.coordinate_system == .LEFT_HANDED {
        glScissor(x0, h-y1, dx, dy);
    } else {
        glScissor(x0, y0, dx, dy);
    }
}

clear_scissor :: () {
    immediate_flush();
    glDisable(GL_SCISSOR_TEST);
}

swap_buffers :: (window: Window_Type, vsync := true) {  // @Incomplete: Have some more-sophisticated vsync flags.
    CheckInit();
    if state.current_shader immediate_flush();

    #if OS == .WINDOWS {
        dc := GetDC(window);
        SwapBuffers(dc);
    } else #if OS == .LINUX {
        info := find_window_info(window);
        if (!info) || !info.specific.glx_window {
            log_error("Simp: Attempt to swap_buffers on a previously unseen window!\n");
            return;
        }

        glXSwapBuffers(x_global_display, info.specific.glx_window);
    } else #if OS == .MACOS {
        // On macOS, OpenGL buffer swapping is done on the context, not on the view.
        // So we can only swap for the active window. (And you need to swap before switching to another view).
        assert(window == state.current_window_info.window);
        NSOpenGLContext.flushBuffer(the_gl_context);
    } else #if OS == .ANDROID {
        status := eglSwapBuffers(egl_info.display, egl_info.surface);
        if status != EGL_TRUE {
            log_error("eglSwapBuffers failed with error %: %", status, egl_error_to_string(xx status));
        }
    } else #if OS == .NN_SWITCH2 {
        assert(false, "No swap buffers for switch 2? Did this ever work?"); // Doesn't look like it, backend_set_render_target is also not implemented for switch2.
    } else {
        assert(false);
    }
}


#scope_module

backend_init_shaders :: () {
    shader_color.gl_handle   = get_shader_program(SHADER_COLOR);
    shader_color.alpha_blend = false;

    shader_color_with_blend.gl_handle   = shader_color.gl_handle;
    shader_color_with_blend.alpha_blend = true;

    shader_text.gl_handle   = get_shader_program(SHADER_TEXT);
    shader_text.alpha_blend = true;

    shader_sprite_right_handed.gl_handle   = get_shader_program(SHADER_SPRITE_RIGHT_HANDED);
    shader_sprite_right_handed.alpha_blend = true;

    shader_sprite_left_handed.gl_handle   = get_shader_program(SHADER_SPRITE_LEFT_HANDED);
    shader_sprite_left_handed.alpha_blend = true;
}

#scope_file

//
//
// Shaders Here!
//
//
SHADER_TEXT :: #string END

OUT_IN vec2 TextureCoords;
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
in vec4 vert_position;
in vec4 vert_color;
in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    gl_Position     = projection * vec4(vert_position.xy, 0.0, 1.0);
    iterated_color  = vert_color;
    TextureCoords   = vert_uv0;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

uniform sampler2D text_sampler;
uniform vec4 text_color;

void main () {
    vec4 texture_sample = texture(text_sampler, TextureCoords);
    color = vec4(iterated_color.xyz, texture_sample.a * iterated_color.a); // text_color * texture_sample;
}
#endif // FRAGMENT_SHADER
END


SHADER_COLOR :: #string END
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
in vec4 vert_position;
in vec4 vert_color;

uniform mat4 projection;

void main() {
    gl_Position = projection * vec4(vert_position.xy, 0.0, 1.0);
    iterated_color    = vert_color;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

void main () {
    color = iterated_color;
}
#endif // FRAGMENT_SHADER
END


// @Cleanup:
// shader_sprite_right_handed is 1-v from shader_text. Do we pack the text texture upside down,
// or what?
SHADER_SPRITE_RIGHT_HANDED :: #string END
OUT_IN vec2 TexCoords;
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
in vec4 vert_position;
in vec4 vert_color;
in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    TexCoords = vec2(vert_uv0.x, 1.0-vert_uv0.y);  // @Cleanup: Figure out what to do to avoid this vertical flip... sigh!
    gl_Position = projection * vec4(vert_position.xy, 0.0, 1.0);
    iterated_color = vert_color;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

uniform sampler2D diffuse_texture;

void main () {
    vec4 color_tex = iterated_color * texture(diffuse_texture, TexCoords);
    if (color_tex.a < 0.1) discard;

    color = color_tex;
}
#endif // FRAGMENT_SHADER
END


SHADER_SPRITE_LEFT_HANDED :: #string END
OUT_IN vec2 TexCoords;
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
in vec4 vert_position;
in vec4 vert_color;
in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    TexCoords = vert_uv0.xy;
    gl_Position = projection * vec4(vert_position.xy, 0.0, 1.0);
    iterated_color = vert_color;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

uniform sampler2D diffuse_texture;

void main () {
    vec4 color_tex = iterated_color * texture(diffuse_texture, TexCoords);
    if (color_tex.a < 0.1) discard;

    color = color_tex;
}
#endif // FRAGMENT_SHADER
END


#scope_export

get_shader_program :: (shader_text: string) -> GLuint {
    LOG_BUFFER_SIZE :: 512;

    make_shader_object :: (shader: string, prefix: string, shader_type: GLenum) -> GLuint {
        shader_object := glCreateShader(shader_type);

        //shader_str := temp_c_string(shader);
        shaders := *u8.[prefix.data, shader.data];
        lengths := s32.[xx prefix.count, xx shader.count];

        glShaderSource(shader_object, 2, shaders.data, lengths.data);

        glCompileShader(shader_object);

        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success then {
            log_data: [LOG_BUFFER_SIZE] u8;
            glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
            log("%", to_string(log_data.data), flags=.ERROR);
            return 0;
        }

        return shader_object;
    }

    // GLES has a different version directive and needs to specify float precision.
    #if IS_GLES {
        PREFIX_V :: #string END
        #version 300 es
        #define VERTEX_SHADER
        #define OUT_IN out
        precision mediump float;
        END

        PREFIX_F :: #string END
        #version 300 es
        #define FRAGMENT_SHADER
        #define OUT_IN in
        precision mediump float;
        END
    } else {
        PREFIX_V :: #string END
        #version 330 core
        #define VERTEX_SHADER
        #define OUT_IN out
        END

        PREFIX_F :: #string END
        #version 330 core
        #define FRAGMENT_SHADER
        #define OUT_IN in
        END
    }

    shader_v := make_shader_object(shader_text, PREFIX_V, GL_VERTEX_SHADER);
    shader_f := make_shader_object(shader_text, PREFIX_F, GL_FRAGMENT_SHADER);
    shader_p := glCreateProgram();

    glAttachShader(shader_p, shader_v);
    glAttachShader(shader_p, shader_f);
    glLinkProgram(shader_p);

    success : GLint = 0;
    glGetProgramiv(shader_p, GL_LINK_STATUS, *success);

    if !success then {
        log_data: [LOG_BUFFER_SIZE] u8;
        glGetProgramInfoLog(shader_p, log_data.count, null, log_data.data);
        log_error("%", to_string(log_data.data));
        return 0;
    }

    glDeleteShader(shader_v);
    glDeleteShader(shader_f);

    return shader_p;
}

draw_generated_quads :: (font: *Dynamic_Font, color := Vector4.{1, 1, 1, 1}) {
    CheckInit();
    quads := font.current_quads;

    if state.current_shader immediate_flush();

    set_shader_for_text();
    immediate_begin();

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);

    draw_letter_quad :: (font: *Dynamic_Font, quad: Font_Quad, color: Vector4) {

/*
        // @Robustness: These assume our coordinates are in screenspace...
        if quad.x1 < 0 return;
        if quad.x0 > cast(float) render_target_width return;
        if quad.y1 < 0 return;
        if quad.y0 > cast(float) render_target_height return;
*/
        page := quad.glyph.page;

        if page.bitmap_data.width  <= 1 return;
        if page.bitmap_data.height <= 1 return;

        using quad;
        uv0 := Vector2.{u0, v0};
        uv1 := Vector2.{u1, v0};
        uv2 := Vector2.{u1, v1};
        uv3 := Vector2.{u0, v1};

        immediate_quad(p0, p1, p2, p3, color, uv0, uv1, uv2, uv3);
    }

    last_texture: s64 = -1;

    for quad, i: quads {
        page := quad.glyph.page;
        map  := *page.texture;

        if page.dirty {
            page.dirty = false;
            texture_load_from_bitmap(map, page.bitmap_data);
        }

        if map.gl_handle != last_texture {
            immediate_flush();
            handle := map.gl_handle;
            last_texture = handle;

            shader := state.current_shader;
            loc := glGetUniformLocation(shader.gl_handle, "text_sampler");
            if loc < 0  log_error("Unable to find text_sampler in shader_text!");
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, handle);  // Bind handle to slot 0.

            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 1);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

            glUniform1i(loc, 0);
        }

        draw_letter_quad(font, quad, color);
    }

    immediate_flush();

    glDisable(GL_BLEND);
}

#scope_module

Texture_Platform_Specific :: struct {
    gl_handle: GLuint;
}

//
// @CompilerFeature
//
// We would like to be able to #if individual 'case' statements, but a lot of the redundancy below
// is because we are unable to do that (I think?)   -jblow, 13 January 2024
//
#if IS_GLES {
    // A bunch of formats, eg GL_BGRA, are not supported on gles. Some are available via extensions we would have to
    // check if supported. Only including directly supported ones for now.
    get_ogl_format :: (tf: Texture_Format, srgb:=false) -> (format: GLenum, src_format: GLenum = GL_INVALID_ENUM, src_type: GLenum = GL_INVALID_ENUM, compressed := false) {
        using Texture_Format;

        format: GLenum;

        if tf == {
            case R8;
            assert(srgb == false);
            return GL_R8, src_format = GL_RED, src_type = GL_UNSIGNED_BYTE;
            case RG8;
            assert(srgb == false);
            return GL_RG8, src_format = GL_RG, src_type = GL_UNSIGNED_BYTE;
            case RGB8;
            if srgb format = GL_SRGB8;
            else format = GL_RGB8;
            return format, src_format = GL_RGB, src_type = GL_UNSIGNED_BYTE;
            case RGBA8;
            if srgb format = GL_SRGB8_ALPHA8;
            else format = GL_RGBA8;
            return format, src_format = GL_RGBA, src_type = GL_UNSIGNED_BYTE;

            case R16F;
            assert(srgb == false);
            return GL_R16F, src_format = GL_RED, src_type = GL_HALF_FLOAT;
            case RG16F;
            assert(srgb == false);
            return GL_RG16F, src_format = GL_RG, src_type = GL_HALF_FLOAT;
            case RGBA16F;
            assert(srgb == false);
            return GL_RGBA16F, src_format = GL_RGBA, src_type = GL_HALF_FLOAT;
            case R32F;
            assert(srgb == false);
            return GL_R32F, src_format = GL_RED, src_type = GL_FLOAT;
            case RG32F;
            assert(srgb == false);
            return GL_RG32F, src_format = GL_RG, src_type = GL_FLOAT;
            case RGBA32F;
            assert(srgb == false);
            return GL_RGBA32F, src_format = GL_RGBA, src_type = GL_FLOAT;
            case RG11B10F;
            assert(srgb == false);
            return GL_R11F_G11F_B10F, src_format = GL_RGB, src_type = GL_UNSIGNED_INT_10F_11F_11F_REV;  // @@ Not tested.
            case RGB9E5F;
            assert(srgb == false);
            return GL_RGB9_E5, src_format = GL_RGB, src_type = GL_UNSIGNED_INT_5_9_9_9_REV; // @@ Not tested.

            case R16I;
            assert(srgb == false);
            return GL_R16I, src_format = GL_RED, src_type = GL_SHORT;
            case RG16I;
            assert(srgb == false);
            return GL_RG16I, src_format = GL_RG, src_type = GL_SHORT;
            case RGBA16I;
            assert(srgb == false);
            return GL_RGBA16I, src_format = GL_RGBA, src_type = GL_SHORT;
            case R32I;
            assert(srgb == false);
            return GL_R32I, src_format = GL_RED, src_type = GL_INT;
            case RG32I;
            assert(srgb == false);
            return GL_RG32I, src_format = GL_RG, src_type = GL_INT;
            case RGBA32I;
            assert(srgb == false);
            return GL_RGBA32I, src_format = GL_RGBA, src_type = GL_INT;

            case D16;
            assert(srgb == false);
            return GL_DEPTH_COMPONENT16, src_format=GL_DEPTH_COMPONENT, src_type=GL_UNSIGNED_SHORT;
            case D24S8;
            assert(srgb == false);
            return GL_DEPTH24_STENCIL8, src_format=GL_DEPTH_STENCIL, src_type=GL_UNSIGNED_INT_24_8;
            case D32F;
            assert(srgb == false);
            //if NV_depth_buffer_float return GL_DEPTH_COMPONENT32F_NV, src_format=GL_DEPTH_COMPONENT, src_type=GL_FLOAT; // IC: This allows unclamped depth values.
            return GL_DEPTH_COMPONENT32F, src_format=GL_DEPTH_COMPONENT, src_type=GL_FLOAT;
            case D32FS8;
            assert(srgb == false);
            //if NV_depth_buffer_float return GL_DEPTH32F_STENCIL8_NV, src_format=GL_DEPTH_STENCIL, src_type=GL_FLOAT_32_UNSIGNED_INT_24_8_REV; // IC: This allows unclamped depth values.
            return GL_DEPTH32F_STENCIL8, src_format=GL_DEPTH_STENCIL, src_type=GL_FLOAT_32_UNSIGNED_INT_24_8_REV;

            case;
            assert(false, "Unsupported texture format %.", tf);
        }

        return GL_INVALID_ENUM;
    }
} else {
    get_ogl_format :: (tf: Texture_Format, srgb:=false) -> (format:GLenum, src_format:GLenum=GL_INVALID_ENUM, src_type:GLenum=GL_INVALID_ENUM, compressed:=false) {
        using Texture_Format;

        format : GLenum;

        if tf == {
            case R8;
            assert(srgb == false);
            return GL_R8, src_format = GL_RED, src_type = GL_UNSIGNED_BYTE;
            case RG8;
            assert(srgb == false);
            return GL_RG8, src_format = GL_RG, src_type = GL_UNSIGNED_BYTE;
            case RGB8;
            if srgb format = GL_SRGB8;
            else format = GL_RGB8;
            return format, src_format = GL_RGB, src_type = GL_UNSIGNED_BYTE;
            case RGBA8;
            if srgb format = GL_SRGB8_ALPHA8;
            else format = GL_RGBA8;
            return format, src_format = GL_RGBA, src_type = GL_UNSIGNED_BYTE;
            case BGRA8;
            if srgb format = GL_SRGB8_ALPHA8;
            else format = GL_RGBA8;
            return format, src_format = GL_BGRA, src_type = GL_UNSIGNED_BYTE;
            case B5G6R5;
            if srgb format = GL_SRGB;
            else format = GL_RGB;
            return format, src_format = GL_BGR, src_type = GL_UNSIGNED_SHORT_5_6_5;
            case RGB10A2;
            assert(srgb == false);
            return GL_RGB10_A2, src_format = GL_RGBA, src_type = GL_UNSIGNED_INT_10_10_10_2;
            case R16;
            assert(srgb == false);
            return GL_R16, src_format = GL_RED, src_type = GL_UNSIGNED_SHORT;

            case R16F;
            assert(srgb == false);
            return GL_R16F, src_format = GL_RED, src_type = GL_HALF_FLOAT;
            case RG16F;
            assert(srgb == false);
            return GL_RG16F, src_format = GL_RG, src_type = GL_HALF_FLOAT;
            case RGBA16F;
            assert(srgb == false);
            return GL_RGBA16F, src_format = GL_RGBA, src_type = GL_HALF_FLOAT;
            case R32F;
            assert(srgb == false);
            return GL_R32F, src_format = GL_RED, src_type = GL_FLOAT;
            case RG32F;
            assert(srgb == false);
            return GL_RG32F, src_format = GL_RG, src_type = GL_FLOAT;
            case RGBA32F;
            assert(srgb == false);
            return GL_RGBA32F, src_format = GL_RGBA, src_type = GL_FLOAT;
            case RG11B10F;
            assert(srgb == false);
            return GL_R11F_G11F_B10F, src_format = GL_RGB, src_type = GL_UNSIGNED_INT_10F_11F_11F_REV;  // @@ Not tested.
            case RGB9E5F;
            assert(srgb == false);
            return GL_RGB9_E5, src_format = GL_RGB, src_type = GL_UNSIGNED_INT_5_9_9_9_REV; // @@ Not tested.

            case R16I;
            assert(srgb == false);
            return GL_R16I, src_format = GL_RED, src_type = GL_SHORT;
            case RG16I;
            assert(srgb == false);
            return GL_RG16I, src_format = GL_RG, src_type = GL_SHORT;
            case RGBA16I;
            assert(srgb == false);
            return GL_RGBA16I, src_format = GL_RGBA, src_type = GL_SHORT;
            case R32I;
            assert(srgb == false);
            return GL_R32I, src_format = GL_RED, src_type = GL_INT;
            case RG32I;
            assert(srgb == false);
            return GL_RG32I, src_format = GL_RG, src_type = GL_INT;
            case RGBA32I;
            assert(srgb == false);
            return GL_RGBA32I, src_format = GL_RGBA, src_type = GL_INT;

            case BC1;
            if srgb format = GL_COMPRESSED_SRGB_S3TC_DXT1_EXT;
            else format = GL_COMPRESSED_RGB_S3TC_DXT1_EXT;
            return format, compressed = true;
            case BC3;
            if srgb format = GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT;
            else format = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
            return format, compressed = true;
            case BC4;
            assert(srgb == false);
            return GL_COMPRESSED_RED_RGTC1, compressed = true;
            case BC5;
            assert(srgb == false);
            return GL_COMPRESSED_RG_RGTC2, compressed = true;
            case BC6;
            assert(srgb == false);
            return GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT, compressed = true;
            case BC7;
            if srgb format = GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM;
            else format = GL_COMPRESSED_RGBA_BPTC_UNORM;
            return format, compressed = true;

            case D16;
            assert(srgb == false);
            return GL_DEPTH_COMPONENT16, src_format=GL_DEPTH_COMPONENT, src_type=GL_UNSIGNED_SHORT;
            case D24S8;
            assert(srgb == false);
            return GL_DEPTH24_STENCIL8, src_format=GL_DEPTH_STENCIL, src_type=GL_UNSIGNED_INT_24_8;
            case D32F;
            assert(srgb == false);
            //if NV_depth_buffer_float return GL_DEPTH_COMPONENT32F_NV, src_format=GL_DEPTH_COMPONENT, src_type=GL_FLOAT; // IC: This allows unclamped depth values.
            return GL_DEPTH_COMPONENT32F, src_format=GL_DEPTH_COMPONENT, src_type=GL_FLOAT;
            case D32FS8;
            assert(srgb == false);
            //if NV_depth_buffer_float return GL_DEPTH32F_STENCIL8_NV, src_format=GL_DEPTH_STENCIL, src_type=GL_FLOAT_32_UNSIGNED_INT_24_8_REV; // IC: This allows unclamped depth values.
            return GL_DEPTH32F_STENCIL8, src_format=GL_DEPTH_STENCIL, src_type=GL_FLOAT_32_UNSIGNED_INT_24_8_REV;

            case;
            assert(false, "Unsupported texture format %.", tf);
        }

        return GL_INVALID_ENUM;
    }
}

backend_realloc_texture :: (texture: *Texture, bitmap: *Bitmap) {
    // This routine needs to make sure we have enough space to store the bitmap.
    // But, that is handled invisibly by GL, so, we just make sure we have a handle.
    if !texture.gl_handle {
        glGenTextures(1, *texture.gl_handle);
        glBindTexture(GL_TEXTURE_2D, texture.gl_handle);

        // Clamp to edge due to alpha textures.
        // @Temporary. We'll want to provide more control over this.
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    }
}

backend_update_texture :: (texture: *Texture, bitmap: *Bitmap) {
    internal_format, gl_format, gl_type, compressed := get_ogl_format(texture.format, (texture.flags & .sRGB) != 0);

    texture_target :: GL_TEXTURE_2D;
    glBindTexture(texture_target, texture.gl_handle);

    bpp := get_image_bytes_per_texel(bitmap.format);
    stride_in_pixels := ifx bpp then bitmap.stride/bpp else bitmap.width;

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, xx stride_in_pixels);
    glTexImage2D(texture_target, 0, xx internal_format, xx bitmap.width, xx bitmap.height, 0, gl_format, gl_type, bitmap.data.data);

    //    resource_size := update_texture_2d(map, compressed, gl_format, gl_type, bittexture.data);
    //    assert (texture.resource_size == xx resource_size);
}


backend_set_render_target :: (info: *Window_Info) {
    if info.backend_initted_for_this_window {
        #if OS == .WINDOWS {
            success := wglMakeCurrent(info.specific.hdc, the_gl_context);
            errno := GetLastError();
        } else #if OS == .LINUX {
            display := x_global_display;
            XLockDisplay(display);
            success := glXMakeCurrent(display, info.specific.glx_window, the_gl_context);
            if !success log_error("glxMakeCurrent failed! (glx_window %, context%)\n", info.specific.glx_window, the_gl_context);
            XUnlockDisplay(display);
        } else #if OS == .MACOS {
            // Get the GL view from the window.
            // This relies on this window having a content view with OpenGL support (eg. as created by Window_Creation).
            view := NSWindow.contentView(info.window);
            assert(view != null);
            NSOpenGLContext.setView(the_gl_context, view);
        } else #if OS == .ANDROID {
            // On Android we only ever have one window (and render to texture is done via FBO and not pbuffers) so this
            // is a bit redunant to happen everytime we set_render_target. But there is no harm in it.
            make_current_result := eglMakeCurrent(egl_info.display, egl_info.surface, egl_info.surface, the_gl_context);
            assert(make_current_result != EGL_FALSE, "Unable to eglMakeCurrent");
        } else {
            assert(false);
        }
    } else {
        backend_init(info);
        info.backend_initted_for_this_window = true;
    }

    glViewport(0, 0, xx info.window_width, xx info.window_height);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // glDrawBuffer is not a thing in GLES.
    #if !IS_GLES  glDrawBuffer(GL_BACK);
}

backend_create_render_target :: (texture: *Texture) {
    // Get the currently bound texture so we can restore it.
    old_map: GLuint;
    glActiveTexture(GL_TEXTURE0);
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *old_map);
    defer glBindTexture(GL_TEXTURE_2D, old_map);

    // Create the actual render target.
    glGenTextures(1, *texture.gl_handle);
    glBindTexture(GL_TEXTURE_2D, texture.gl_handle);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, xx texture.width, xx texture.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);  // This has no mipmaps.
}

backend_set_render_target :: (texture: *Texture) {
    if !main_fbo_handle glGenFramebuffers(1, *main_fbo_handle);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, main_fbo_handle);

    glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.specific.gl_handle, 0);

    glViewport(0, 0, xx texture.width, xx texture.height);
}

backend_use_shader :: (s: *Shader) {
    if s.alpha_blend {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable(GL_BLEND);
    } else {
        glDisable(GL_BLEND);
    }

    glUseProgram(s.gl_handle);
}

backend_update_shader_parameter_locations :: (s: *Shader) {
    p := s.gl_handle;
    s.position_loc    = glGetAttribLocation(p, "vert_position");
    s.color_scale_loc = glGetAttribLocation(p, "vert_color");
    s.normal_loc      = glGetAttribLocation(p, "vert_normal");
    s.tangent_loc     = glGetAttribLocation(p, "vert_tangent");
    s.uv_0_loc        = glGetAttribLocation(p, "vert_uv0");
    s.uv_1_loc        = glGetAttribLocation(p, "vert_uv1");
//    s.transform_loc = glGetUniformLocation(p, "projection");
}

backend_draw_immediate_vertices :: (num_vertices: int) {
    glBindVertexArray(opengl_is_stupid_vao);
    glBindBuffer(GL_ARRAY_BUFFER, immediate_vbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    DumpGLErrors("glBindBuffer immediate_vbo");

    glBufferData(GL_ARRAY_BUFFER, size_of(Immediate_Vertex) * num_vertices, context.simp.vertices.data, GL_STREAM_DRAW);
    DumpGLErrors("glBufferData immediate_vertices");

    // glCullMode(GL_NONE);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    // @Speed:
    #if true { // !vertex_format_set_to_XCNUU) {
        set_vertex_format_to_XCNUU(context.simp.current_shader);
        DumpGLErrors("XCNUU");
    }

    glDrawArrays(GL_TRIANGLES, 0, xx num_vertices);
    DumpGLErrors("out");
}

backend_set_texture :: (shader: *Shader, texture: *Texture) {
    loc := glGetUniformLocation(shader.gl_handle, "diffuse_texture");

    if loc < 0 {
        log_error("Unable to find 'diffuse_texture' in the current shader.");
        return;
    }

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture.gl_handle);  // Bind handle to slot 0.
    glUniform1i(loc, 0);
}

backend_resize_render_target :: (info: Window_Info) {
    if context.simp.current_window_info.window == info.window {
        glViewport(0, 0, xx info.window_width, xx info.window_height);
        #if OS == .MACOS {
            NSOpenGLContext.update(the_gl_context);
        }
    }
}

backend_flush :: () {
    if the_gl_context {
        glFlush();
    }
}

backend_tweak_projection_matrix :: (m: *Matrix4) {
    if context.simp.texture_render_target {
        m._21 *= -1;
        m._22 *= -1;
        m._23 *= -1;
        m._24 *= -1;
    }
}

backend_texture_destroy :: (texture: *Texture) {
    handle := texture.gl_handle;
    if !handle  return;

    glDeleteTextures(1, *handle);
    texture.gl_handle = 0;
}

#if OS == .WINDOWS {
    Backend_Platform_Specific :: struct { }

    Window_Info_Platform_Specific :: struct {
        hdc:   HDC;
    }

    windows_change_pixel_format :: (hdc: HDC) {
        assert(the_hdc_for_pixel_format_cloning != null);

        pfd: PIXELFORMATDESCRIPTOR;
        format := GetPixelFormat(the_hdc_for_pixel_format_cloning);
        result := DescribePixelFormat(the_hdc_for_pixel_format_cloning, format, size_of(type_of(pfd)), *pfd);
        assert(result != 0);

        SetPixelFormat(hdc, format, *pfd);
    }
}

#if OS == .LINUX {
    Backend_Platform_Specific :: struct {
    }

    Window_Info_Platform_Specific :: struct {
        glx_window: GLXWindow;
    }
} else #if OS == .MACOS {
    Backend_Platform_Specific :: struct {
        // @Incomplete
    }

    Window_Info_Platform_Specific :: struct {
        // @Incomplete
    }
} else #if OS == .ANDROID {
    Backend_Platform_Specific :: struct {
    }

    Window_Info_Platform_Specific :: struct {
        disabled := false; // Our app is in the background, we don't currently actually have a window, but our gl context still remains. Window_Info.window holds the reference to the old window.
    }
} else #if OS == .NN_SWITCH2 {
    Backend_Platform_Specific :: struct {
    }

    Window_Info_Platform_Specific :: struct {
    }
}
