//
// So that immediate rendering is threadsafe, we add its state to the Context.
//

Immediate_State :: struct {
    current_window_info: Window_Info;

    current_shader: *Shader;
    texture_render_target: *Texture;
    num_vertices: s32;

    MAX_VERTICES :: 2400;
    vertices: [MAX_VERTICES] Immediate_Vertex;

    specific: Backend_Platform_Specific;

    coordinate_system := Simp_Coordinate_System.RIGHT_HANDED;

    // We may wish to add a user-data pointer here.
}

// We add a pointer to the context, so that we don't use much memory
// if that thread never does immediate rendering.
#add_context simp: *Immediate_State;

//
// Immediate_Vertex is meant to be flexible rather than efficient.
// It has a bunch of members for different things you may or may not
// be doing: for example, it's got a normal and tangent in case you
// are doing 3D rendering; it's got two pairs of uv coordinates so
// that you can do two-layer texture effects. If these aren't used,
// the memory for the vertices is still occupied, but the shader
// just ignores the coefficients. This is all fine; if you want
// high-performance rendering, you should use pre-baked meshes rather
// than this interface.
//
Immediate_Vertex :: struct {
    position:    Vector3;
    color_scale: Vector4;
    uv0:         Vector2;
    uv1:         Vector2;
    normal:      Vector3;
    tangent:     Vector4;
}

immediate_reset :: () {
    CheckInit();

    state.current_shader = null;
}

immediate_set_texture :: (texture: *Texture) {
    CheckInit();
    shader := state.current_shader;
    if !shader {
        log_error("Attempted to immediate_set_texture when no shader was set.");
        return;
    }

    backend_set_texture(shader, texture);
}

immediate_set_shader :: (s: *Shader) {
    CheckInit();

    if state.current_shader && (state.current_shader != s) {
        immediate_flush();
    }

    backend_update_shader_parameter_locations(s);

    state.current_shader = s;
    backend_use_shader(s);
}

immediate_begin :: () {
    CheckInit();
}

immediate_flush :: () {
    CheckInit();
    if !state.num_vertices return;

    if !state.current_shader {
        assert(false, "Tried to immediate_flush when no shader was set.\n");
        state.num_vertices = 0;
        return;
    }

    //
    // In the long run, we want to send this buffer off to the main thread, probably.
    // But for now, we just say you can only do this from the main thread, because.
    //

    backend_draw_immediate_vertices(state.num_vertices);
    state.num_vertices = 0;
}


#scope_file


//
// These are just different utility functions that we use to fill out the vertex array.
//
immediate_vertex_pointer :: inline (index: s32) -> *Immediate_Vertex {
    return context.simp.vertices.data + index;
}

put_vertex :: inline (using vertex: *Immediate_Vertex, p: Vector2, color: Vector4, u: float, v: float) {
    position.xy  = p;
    position.z   = 0;
    color_scale  = color;
    normal       = .{z=1};
    uv0.x        = u;
    uv0.y        = v;
    uv1          = .{};
}

put_vertex :: inline (using vertex: *Immediate_Vertex, p: Vector3, color: Vector4, u: float, v: float) {
    position     = p;
    color_scale  = color;
    normal       = .{z=1};
    uv0.x        = u;
    uv0.y        = v;
    uv1          = .{};
}

put_vertex :: inline (using vertex: *Immediate_Vertex, p: Vector3, color: Vector4, _normal: Vector3, u: float, v: float) {
    position     = p;
    color_scale  = color;
    normal       = _normal;
    uv0.x        = u;
    uv0.y        = v;
    uv1          = .{};
}

put_vertex :: inline (using vertex: *Immediate_Vertex, p: Vector3, color: Vector4,
                      _normal: Vector3, _tangent: Vector4, _uv0: Vector2, _uv1: Vector2) {
    position     = p;
    color_scale  = color;
    normal       = _normal;
    tangent      = _tangent;
    uv0          = _uv0;
    uv1          = _uv1;
}

#scope_export

//
// These are the routines that you, as a user, would call, depending
// on what is more convenient to you. We don't provide all permutations,
// but, we do provide a lot.
//

//
// First, here are some routines for outputting one vertex at a time.
// This API only does triangles, so, every 3 vertices indicates one triangle.
//

// If you are outputting 3D vertices with a color at each vertex:

/*
These are omitted for brevity, because we can do it all with one immediate_vertex():
immediate_vertex :: (position: Vector3, color_scale: Vector4) {
    CheckSpace(1);
    put_vertex(v, position, color_scale, 0, 0);
}

immediate_vertex :: (position: Vector3, color_scale: Vector4, uv: Vector2) {
    CheckSpace(1);
    put_vertex(v, position, color_scale, uv.x, uv.y);
}

// Four 3D points plus a color and an optional normal:
immediate_quad :: (p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Vector4, normal := Vector3.{z=1}) {
    CheckSpace(6);

    put_vertex(*v[0], p0, color,  normal,  0, 0);
    put_vertex(*v[1], p1, color,  normal,  1, 0);
    put_vertex(*v[2], p2, color,  normal,  1, 1);

    put_vertex(*v[3], p0, color,  normal,  0, 0);
    put_vertex(*v[4], p2, color,  normal,  1, 1);
    put_vertex(*v[5], p3, color,  normal,  0, 1);
}
*/

immediate_vertex :: (position: Vector3, color_scale: Vector4, uv: Vector2 = .{}, normal: Vector3 = .{}) {
    CheckSpace(1);
    put_vertex(v, position, color_scale, normal, uv.x, uv.y);
}

//
// Most of the time, you want to output quads: quadrilaterals, where the 4 points
// don't need to be in any particular relation. (The sides don't have to be the same length,
// the angles don't have to be the same). We do assume that this quad represents
// a convex positive area. If in 3D, we assume the 4 vertices are coplanar.
//
// We output quads just by outputting two triangles, as 6 vertices.
//

// But first we'll start with the simplest, an axis-aligned quad where you just
// want to declare the two corners (x0, y0) and (x1, y1):
immediate_quad :: (x0: float, y0: float, x1: float, y1: float, color: Vector4) {
    CheckSpace(6);

    put_vertex(*v[0], .{x1, y0}, color,  1, 0);
    put_vertex(*v[1], .{x0, y0}, color,  0, 0);
    put_vertex(*v[2], .{x1, y1}, color,  1, 1);

    put_vertex(*v[3], .{x1, y1}, color,  1, 1);
    put_vertex(*v[4], .{x0, y0}, color,  0, 0);
    put_vertex(*v[5], .{x0, y1}, color,  0, 1);
}

// Four 2D points making an arbitrary quad, plus a color,
// and optional uv coordinates for mapping a texture:
immediate_quad :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color := Vector4.{1,1,1,1},
                   uv0 := Vector2.{0,0}, uv1 := Vector2.{1,0}, uv2 := Vector2.{1,1}, uv3 := Vector2.{0, 1}) {
    CheckSpace(6);

    put_vertex(*v[0], p0, color,  uv0.x, uv0.y);
    put_vertex(*v[1], p1, color,  uv1.x, uv1.y);
    put_vertex(*v[2], p2, color,  uv2.x, uv2.y);

    put_vertex(*v[3], p0, color,  uv0.x, uv0.y);
    put_vertex(*v[4], p2, color,  uv2.x, uv2.y);
    put_vertex(*v[5], p3, color,  uv3.x, uv3.y);
}

// A 2D quad with different colors at each vertex:
immediate_quad :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
                   c0: Vector4, c1: Vector4, c2: Vector4, c3: Vector4,
                   uv0 := Vector2.{0,0}, uv1 := Vector2.{1,0}, uv2 := Vector2.{1,1}, uv3 := Vector2.{0, 1}) {
    CheckSpace(6);

    put_vertex(*v[0], p0, c0,  uv0.x, uv0.y);
    put_vertex(*v[1], p1, c1,  uv1.x, uv1.y);
    put_vertex(*v[2], p2, c2,  uv2.x, uv2.y);

    put_vertex(*v[3], p0, c0,  uv0.x, uv0.y);
    put_vertex(*v[4], p2, c2,  uv2.x, uv2.y);
    put_vertex(*v[5], p3, c3,  uv3.x, uv3.y);
}


// Four 3D points plus a color, and optional uv coordinates and a normal:
immediate_quad :: (p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Vector4,
                   uv0 := Vector2.{0,0}, uv1 := Vector2.{1,0}, uv2 := Vector2.{1,1}, uv3 := Vector2.{0, 1}, normal := Vector3.{z=1}) {
    CheckSpace(6);

    put_vertex(*v[0], p0, color, normal, uv0.x, uv0.y);
    put_vertex(*v[1], p1, color, normal, uv1.x, uv1.y);
    put_vertex(*v[2], p2, color, normal, uv2.x, uv2.y);

    put_vertex(*v[3], p0, color, normal, uv0.x, uv0.y);
    put_vertex(*v[4], p2, color, normal, uv2.x, uv2.y);
    put_vertex(*v[5], p3, color, normal, uv3.x, uv3.y);
}


//
// And, the 3D quad for that special someone who already has everything:
//
immediate_quad :: (p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Vector4,
                   uv0: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2,
                   st0: Vector2, st1: Vector2, st2: Vector2, st3: Vector2,
                   normal: Vector3, tangent: Vector4) {

    // I guess the Vector4 part of tangent says whether we are right or left-handed?

    CheckSpace(6);

    put_vertex(*v[0], p0, color, normal, tangent, uv0, st0);
    put_vertex(*v[1], p1, color, normal, tangent, uv1, st1);
    put_vertex(*v[2], p2, color, normal, tangent, uv2, st2);

    put_vertex(*v[3], p0, color, normal, tangent, uv0, st0);
    put_vertex(*v[4], p2, color, normal, tangent, uv2, st2);
    put_vertex(*v[5], p3, color, normal, tangent, uv3, st3);
}


//
// You can make your own immediate_quad functions that, for example,
// pass one color per vertex, and so forth. Actually, we should probably
// provide that here. @Incomplete.
//

//
// You can draw individual triangles instead of quads. For example,
// if you want to draw a circle, you can make it out of triangles.
//
// Here we just provide one, for simplicity (if you want to draw 2D stuff,
// just put in a dummy Z coordinate, like 0):
//

/*
immediate_triangle :: (p0: Vector3, p1: Vector3, p2: Vector3,
                       color: Vector4,
                       uv0 := Vector2.{}, uv1 := Vector2.{}, uv2 := Vector2.{},
                       normal := Vector3.{z=1}) {
    CheckSpace(3);
    put_vertex(*v[0], p0, color, normal, uv0.x, uv0.y);
    put_vertex(*v[1], p1, color, normal, uv1.x, uv1.y);
    put_vertex(*v[2], p2, color, normal, uv2.x, uv2.y);
}
*/

immediate_triangle :: (p0: Vector3, p1: Vector3, p2: Vector3,
                       c1: Vector4, c2: Vector4, c3: Vector4,
                       uv0 := Vector2.{}, uv1 := Vector2.{}, uv2 := Vector2.{},
                       normal := Vector3.{z=1}) {
    CheckSpace(3);
    put_vertex(*v[0], p0, c1, normal, uv0.x, uv0.y);
    put_vertex(*v[1], p1, c2, normal, uv1.x, uv1.y);
    put_vertex(*v[2], p2, c3, normal, uv2.x, uv2.y);
}

immediate_set_2d_projection :: (render_target_width: s32, render_target_height: s32) {
    CheckInit();

    shader := state.current_shader;
    if !shader {
        assert(false, "Tried to immediate_set_2d_projection when no shader was set.\n");
        state.num_vertices = 0;
        return;
    }

    m: Matrix4 = ---;
    if state.coordinate_system == .LEFT_HANDED {
        m = orthographic_projection_matrix(0, cast(float) render_target_width, cast(float) render_target_height, 0, -1.0, 1.0);
    } else {
        m = orthographic_projection_matrix(0, cast(float) render_target_width, 0, cast(float) render_target_height, -1.0, 1.0);
    }

    backend_tweak_projection_matrix(*m);

    set_parameter(shader, "projection", m);
}



#scope_module

// Every entry point must call CheckInit to make sure we are initialized.
// That way nobody needs to call an init function.
CheckInit :: () #expand {
    if !context.simp  per_thread_init();
    `state := context.simp;

    #if render_api == .METAL {
        init_metal();
    }
}

// Or you can call CheckSpace, to do a CheckInit but also
// ensure n vertices are available in the buffer.
// And when we return, bump the number of occupied vertices by n.
// So anyone calling CheckSpace had better fill those vertices out!

CheckSpace :: (n: s32) #expand {
    if !context.simp  per_thread_init();
    `state := context.simp;
    if state.num_vertices >= state.vertices.count-(n-1)  immediate_flush();
    `v := immediate_vertex_pointer(state.num_vertices);
    state.num_vertices += n;
}

per_thread_init :: () {
    // Actually, init all Simp stuff here.
    context.simp = New(Immediate_State);
}


#import "Window_Type";
