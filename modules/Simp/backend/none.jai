Shader_Platform :: struct {}
Backend_Platform_Specific :: struct {}
Texture_Platform_Specific :: struct {}
Window_Info_Platform_Specific :: struct {}
Pixel_Read_Platform :: struct {}

backend_init :: (info: *Window_Info) {
}

backend_realloc_texture :: (texture: *Texture, bitmap: *Bitmap) {
}

backend_set_render_target :: (info: *Window_Info) {
}

backend_create_render_target :: (texture: *Texture) {
}

backend_set_render_target :: (texture: *Texture) {
}

backend_update_texture :: (texture: *Texture, bitmap: *Bitmap) {
}

backend_use_shader :: (s: *Shader) {
}

backend_update_shader_parameter_locations :: (s: *Shader) {
}

backend_draw_immediate_vertices :: (num_vertices: int) {
}

backend_set_texture :: (shader: *Shader, texture: *Texture) {
}

backend_resize_render_target :: (info: Window_Info) {
}

backend_flush :: () {
}

is_supported :: (tf: Texture_Format) -> bool {
    return true;
}

clear_render_target :: (r: float, g: float, b: float, a: float) {
}

set_scissor :: (x0: s32, y0: s32, x1: s32, y1: s32) {
}

clear_scissor :: () {
}

pixel_read_begin :: (source: *Texture /* may be null */, dest_format: Texture_Format, width: s32 = -1, height: s32 = -1, srgb := false, flip := false) -> *Pixel_Read {
    reader := New(Pixel_Read);  // @Cleanup: Don't use the heap?
    return reader;
}

pixel_read_is_done :: (reader: *Pixel_Read) -> bool {
    return true;
}

pixel_read_end :: (reader: *Pixel_Read) -> Bitmap {
    return .{};
}

swap_buffers :: (window: Window_Type, vsync := true) {
}

backend_tweak_projection_matrix :: (m: *Matrix4) {
}

set_parameter :: (shader: *Shader, name: *u8, m: Matrix4) {
}

draw_generated_quads :: (font: *Dynamic_Font, color := Vector4.{1, 1, 1, 1}) {
}