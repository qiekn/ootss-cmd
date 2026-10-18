//
// To Do:
//
// GetDesktopWindow/GetClientRect, getting desktop resolution on Windows and Linux.
//
// widgets/text_display is not done. It needs event handling, etc.
// texture_load_from_memory takes a flags word.
//
// * Don't require ui_init to be called (?)
// * If popups were queued, ensure that the user program calls draw_popups() by the end of the frame.
// * Input and event handling can use a substitute type rather than just modules/Input.
// * Example of not using Simp (Draw_Procs pluggability test).
// * Frame-rate dependence when dragging the Text_Input selection outside the margins. (Also, want themed speed control.)
//
// * I hate that function called "slice". Do something about it.
// * Make DPI-Aware easy.
// * Error-checking that makes sure all scrollable regions are finished, all scissors are popped, we called stop_using_state, etc.
//

#module_parameters ()(Type_Indicator: Type = void);

// Here are some global fields that control size, that you can update
// any time you want between calls to GetRect widgets.
// If you don't ever set them, they will be set from defaults in per_frame_update.
// See the comment on Size_Computation in themes.jai for ways you would use these.


set_global_rounding_radius_in_pixels :: (value: float) {
    global_rounding_radius_in_pixels        = value;
    global_rounding_radius_in_pixels_is_set = true;
}

set_global_frame_thickness_in_pixels :: (value: float) {
    global_frame_thickness_in_pixels        = value;
    global_frame_thickness_in_pixels_is_set = true;
}

set_global_divider_thickness_in_pixels :: (value: float) {
    global_divider_thickness_in_pixels        = value;
    global_divider_thickness_in_pixels_is_set = true;
}

set_global_initial_divider_position_in_pixels :: (value: float) {
    global_initial_divider_position_in_pixels        = value;
    global_initial_divider_position_in_pixels_is_set = true;
}

// @Cleanup We would rather not have slider-specific stuff
// here, because we'd like the principle to be that you can
// just delete files of widgets you don't care about. Well,
// you can still do that, but we'd have a couple variables
// laying around...! Probably what we should do instead is
// just make a type that has the bool + float together, and
// get_float_parameter() just checks whether it is set and
// if not uses the default value.
set_global_slider_nub_thickness_in_pixels :: (value: float) {
    global_slider_nub_thickness_in_pixels        = value;
    global_slider_nub_thickness_in_pixels_is_set = true;
}

#scope_module

global_rounding_radius_in_pixels := 9.0;
global_rounding_radius_in_pixels_is_set := false;

global_frame_thickness_in_pixels := 4.0;
global_frame_thickness_in_pixels_is_set := false;

global_divider_thickness_in_pixels := 4.0;
global_divider_thickness_in_pixels_is_set := false;

global_initial_divider_position_in_pixels := 32.0;
global_initial_divider_position_in_pixels_is_set := false;

global_slider_nub_thickness_in_pixels := 32.0;
global_slider_nub_thickness_in_pixels_is_set := false;


#load "widgets/widgets.jai";
#load "system/system.jai";

#import "Basic";
#import "Input";   // @Incomplete. Let us factor out 'Input' into Type_Indicator? This means we will need to do some interface thing about Event, or ... something. This also means we need to figure out wtf with set_imgui_mode().
#import "Hash_Table";
#import "Math";
#import "String";  // Used in Text_Input.
#import "Unicode"; // Used in Text_Input.
#import "Pool";

#if Type_Indicator == void {
    USE_SIMP :: true;
    Simp :: #import "Simp";
    Window_Creation :: #import "Window_Creation";  // Just for Window_Type. Should that be a module parameter?

    Window_Type  :: Window_Creation.Window_Type;
    Font         :: Simp.Dynamic_Font;
    Font_Effects :: Simp.Font_Effects;
    Texture      :: Simp.Texture;
} else {
    USE_SIMP :: false;
    Window_Type  :: Type_Indicator.Window_Type;
    Font         :: Type_Indicator.Font;
    Font_Effects :: Type_Indicator.Font_Effects;
    Texture      :: Type_Indicator.Texture;
}

#add_context getrect_current_window: Window_Type = WT.INVALID_WINDOW;


scissor_stack: [..] Rect;

Per_Window_State :: struct {
    window: Window_Type;
    mouse_x_float, mouse_y_float: float;
}

this_frame_per_window_states: [..] Per_Window_State;
last_frame_per_window_states: [..] Per_Window_State;

mouse_x, mouse_y: s32;

mouse_x_float, mouse_y_float: float;
mouse_delta_x_float, mouse_delta_y_float: float;

current_tooltip: Tooltip;
active_tooltip:  Tooltip;

current_getrect_frame: u64;  // Wrapping. Just so we have a unique ID per frame!
occluder_under_the_cursor: *Active_Widget;  // Null if no occluder.

mouse_button_left_state:  Key_Current_State;
mouse_button_right_state: Key_Current_State;
shift_key_state:          Key_Current_State;

some_widget_received_left_mouse_button := false;

last_current_time := FLOAT64_INFINITY;
current_time: float64;
current_dt:   float;

last_left_click_time: float64;
left_click_dt := FLOAT32_INFINITY;

render_target_width:  s32;
render_target_height: s32;

current_subwindow: *Subwindow_State;

map_radiobox_full:  *Texture;
map_radiobox_empty: *Texture;
map_checkbox_full:  *Texture;
map_checkbox_empty: *Texture;
map_mode_circle:    *Texture;
map_mode_rgb:       *Texture;
map_mode_hsv:       *Texture;
map_mode_numbers:   *Texture;

#scope_export



Draw_Procs :: struct {  // What GetRect calls into in order to perform operations. By default we use Simp, but you can override these by passing a Draw_Procs to ui_init().
    texture_load_from_memory: (texture: *Texture, memory: [] u8, srgb: bool, build_mipmaps: bool) -> bool;
    set_scissor:   (x0: s32, y0: s32, x1: s32, y1: s32);
    clear_scissor: ();

    set_shader_for_color:  (enable_blend := false);
    set_shader_for_images: (texture: *Texture);

    prepare_text:       (font: *Font, text: string, effects: Font_Effects = 0) -> s64;
    draw_prepared_text: (font: *Font, x: s64, y: s64, text_color: Vector4, effects: Font_Effects = 0);

    get_mouse_pointer_position: (window: Window_Type, right_handed: bool) -> (x: int, y: int, success: bool);

    // For now we assume that other folks are going to be drawing the mouse pointer, though maybe
    // we should build one in. Right now, maybe you are using the OS mouse pointer, which is very
    // snappy and feedbacky, but will race ahead of window sizing for that reason.

    // Unlike everything else in Draw_Procs, if you leave set_pointer_image null at init time,
    // GetRect will replace it with an OS-specific version that sets the hardware cursor.
    set_pointer_image: (image: Pointer_Image, widget: *Active_Widget);

    get_font_at_size:   (memory: [] u8, pixel_height: int) -> *Font;

    immediate_triangle:  (p0: Vector3, p1: Vector3, p2: Vector3, c0 := Vector4.{1,1,1,1}, c1 := Vector4.{1,1,1,1}, c2 := Vector4.{1,1,1,1}, uv0 := Vector2.{}, uv1 := Vector2.{}, uv2 := Vector2.{}, normal := Vector3.{z=1});
    immediate_quad:  (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color := Vector4.{1,1,1,1}, uv0 := Vector2.{0,0}, uv1 := Vector2.{1,0}, uv2 := Vector2.{1,1}, uv3 := Vector2.{0, 1});
    immediate_flush: ();
}

default_overall_theme: Overall_Theme;
draw_procs: Draw_Procs;

Status_Flags :: enum_flags u32 {
    OVER     :: 0x01;
    FOCUS    :: 0x02;
    DOWN     :: 0x04;
    PRESSED  :: 0x08;
//    RELEASED :: 0x10;
}

Text_Alignment :: enum u8 {
    Left   :: 0;
    Center :: 1;
    Right  :: 2;
}


Rect :: struct {
    x, y: float;
    w, h: float;
}

KNUTH_GOLDEN_RATIO_64 :: 11400714819323198485;

get_hash :: (loc: Source_Code_Location, identifier: s64) -> u64 {
    Hash :: #import "Hash";
    // Maybe we should hash the filename pointer in order to better prevent collisions.
    name_hash := Hash.djb2_hash(loc.fully_pathed_filename);
    line_hash := Hash.knuth_hash(cast,no_check(u64) loc.line_number);
    identifier_hash := Hash.knuth_hash(cast,no_check(u64) identifier);

    result := combine_hashes(name_hash, combine_hashes(line_hash, identifier_hash));
    return result;
}

combine_hashes :: (a: u64, b: u64) -> u64 #no_aoc {
    return a * KNUTH_GOLDEN_RATIO_64 + b;
}

expand :: (rect: Rect, amount: float) -> Rect {
    r := rect;
    r.x -= amount;
    r.y -= amount;
    r.w += 2*amount;
    r.h += 2*amount;

    return r;
}

expand_x :: (rect: Rect, amount: float) -> Rect {
    r := rect;
    r.x -= amount;
    r.w += 2*amount;

    return r;
}

expand_y :: (rect: Rect, amount: float) -> Rect {
    r := rect;
    r.y -= amount;
    r.h += 2*amount;

    return r;
}

shrink :: (rect: Rect, amount: float) -> Rect {
    return expand(rect, -amount);
}

shrink_x :: (rect: Rect, amount: float) -> Rect {  // Shrink by 'amount' on both sides of the rectangle.
    return expand_x(rect, -amount);
}

shrink_y :: (rect: Rect, amount: float) -> Rect {  // Shrink by 'amount' on both sides of the rectangle.
    return expand_y(rect, -amount);
}

cut_left  :: (rect: Rect, amount: float, margin := 0.0) -> (left: Rect, remainder: Rect) {
    remainder := rect;

    m := margin * .5;
    remainder.w -= amount + m;
    remainder.x += amount + m;

    left := rect;
    left.w = amount - m;

    return left, remainder;
}

cut_right :: (rect: Rect, amount: float, margin := 0.0) -> (right: Rect, remainder: Rect) {
    m := margin * .5;
    remainder := rect;

    remainder.w -= amount + m;

    right := rect;
    right.x = remainder.x + remainder.w + margin;
    right.w = amount - m;

    return right, remainder;
}

cut_bottom :: (rect: Rect, amount: float, margin := 0.0) -> (bottom: Rect, remainder: Rect) {
    remainder := rect;

    m := margin * .5;
    remainder.h -= amount + m;
    remainder.y += amount + m;

    bottom := rect;
    bottom.h = amount - m;

    return bottom, remainder;
}

cut_top :: (rect: Rect, amount: float, margin := 0.0) -> (top: Rect, remainder: Rect) {
    m := margin * .5;
    remainder := rect;

    remainder.h -= amount + m;

    top := rect;
    top.y = remainder.y + remainder.h + margin;
    top.h = amount - m;

    return top, remainder;
}

Status_Flags_Ignore :: enum_flags u8 {
    NOTHING;
    LEFT_CLICK;
    TOOLTIP;
    SCISSOR;
}

get_status_flags :: (r: Rect, widget_if_querying_outside_of_render_time: *Active_Widget = null, ignore := Status_Flags_Ignore.NOTHING) -> Status_Flags {
    status: Status_Flags;

    process_tooltip := !(ignore & .TOOLTIP);
    defer if process_tooltip  tooltip("");

    x := mouse_x_float;
    y := mouse_y_float;

    if !(ignore & .SCISSOR) && !is_visible_in_scissor(x, y)
        return status;

    // We use implicit z value, so we don't have to pass it everywhere.
    // If that turns into some kind of OpenGL situation, we'll make it explicit later.
    if (!events_occluded(widget_if_querying_outside_of_render_time)) && !(active_widget && active_widget_is_grabbing) {  // What if we are the active widget? @Cleanup
        if is_inside(x, y, r) {
            status |= .OVER;

            if process_tooltip  active_tooltip  = current_tooltip;

            // Sometimes we want status flags to know if we are over a region, but that region
            // contains user content, so we don't want to intercept clicks and count them as
            // being active... for example, the interior of a scrollable region. This way, if the user
            // clicks on the interior of a scrollable region, and no other active widget is hit,
            // we know to close active widgets.
            cares_about_left_click := !(ignore & .LEFT_CLICK);
            if cares_about_left_click && (mouse_button_left_state & .START) {
                status |= .PRESSED;
                some_widget_received_left_mouse_button = true;
            }
        }
    }

    return status;
}

require_texture :: (data: string, loc := #caller_location) -> *Texture {
    texture := New(Texture);

    success := draw_procs.texture_load_from_memory(texture, cast([] u8) data, false, false);
    if !success {
        log_error("Simp could not process loaded texture data! %\n", loc);
        return null;
    }

    return texture;
}

ui_init :: (default_font := "", procs: *Draw_Procs = null) {
    if procs {
        draw_procs = procs.*;
    }

    #if USE_SIMP {
        // Ugh, we need to disambiguate an overload from Window_Creation.
        dummy_window: Window_Creation.Window_Type;
        get_mouse :: #procedure_of_call Window_Creation.get_mouse_pointer_position(dummy_window, true);

        p: Vector2 = ---;
        c: Vector4 = ---;
        memory: [] u8;
        imq1 :: #procedure_of_call Simp.immediate_quad(p, p, p, p, c);
        gfas :: #procedure_of_call Simp.get_font_at_size(memory, 1);

        {
            using draw_procs;
            if !texture_load_from_memory    texture_load_from_memory   = Simp.texture_load_from_memory;
            if !set_scissor                 set_scissor                = Simp.set_scissor;
            if !clear_scissor               clear_scissor              = Simp.clear_scissor;
            if !set_shader_for_color        set_shader_for_color       = Simp.set_shader_for_color;
            if !set_shader_for_images       set_shader_for_images      = Simp.set_shader_for_images;
            if !prepare_text                prepare_text               = Simp.prepare_text;
            if !draw_prepared_text          draw_prepared_text         = Simp.draw_prepared_text;
            if !get_mouse_pointer_position  get_mouse_pointer_position = get_mouse;
            if !get_font_at_size            get_font_at_size           = gfas;
            if !immediate_triangle          immediate_triangle         = Simp.immediate_triangle;
            if !immediate_quad              immediate_quad             = imq1;
            if !immediate_flush             immediate_flush            = Simp.immediate_flush;

            set_pointer_image = getrect_set_pointer_image;
        }
    } else {
        using draw_procs;
        assert(procs != null);  // If you are not using Simp, you need to supply all draw_procs.

        assert(texture_load_from_memory   != null);
        assert(set_scissor                != null);
        assert(clear_scissor              != null);
        assert(set_shader_for_color       != null);
        assert(set_shader_for_images      != null);
        assert(prepare_text               != null);
        assert(draw_prepared_text         != null);
        assert(get_mouse_pointer_position != null);
        assert(get_font_at_size           != null);
        assert(immediate_triangle         != null);
        assert(immediate_quad             != null);
        assert(immediate_flush            != null);

        // set_pointer_image is allowed to be null; if it is, we use our routine
        // that just sets the hardware cursor.
        if !set_pointer_image  set_pointer_image = getrect_set_pointer_image;
    }

    map_radiobox_full  = require_texture(memory_radiobox_full);
    map_radiobox_empty = require_texture(memory_radiobox_empty);
    map_checkbox_full  = require_texture(memory_checkbox_full);
    map_checkbox_empty = require_texture(memory_checkbox_empty);
    map_mode_circle    = require_texture(memory_mode_circle);
    map_mode_rgb       = require_texture(memory_mode_rgb);
    map_mode_hsv       = require_texture(memory_mode_hsv);
    map_mode_numbers   = require_texture(memory_mode_numbers);

    if default_font  default_font_data = default_font;
    else             default_font_data = memory_default_font;
}

ui_get_button_state :: (key: Key_Code) -> Key_Current_State {
    // This used to do something, but now it does not...!
    state := input_button_states[key];

    return state;
}

windows_per_frame_update :: () {
    swap(*last_frame_per_window_states, *this_frame_per_window_states);
    this_frame_per_window_states.count = 0;
}

switch_window :: (window: Window_Type, _render_target_width: s32, _render_target_height: s32) -> (background_occluded: bool, is_active: bool) {
    assert(state_stack.count == 0);
    context.getrect_current_window = window;

    render_target_width  = max(_render_target_width, 1);
    render_target_height = max(_render_target_height, 1);

    w := cast(float)render_target_width;
    h := cast(float)render_target_height;
    diagonal := sqrt(w*w+h*h);

    if !global_rounding_radius_in_pixels_is_set {
        global_rounding_radius_in_pixels = (12 / 2160.0) * diagonal;
    }

    if !global_frame_thickness_in_pixels_is_set {
        global_frame_thickness_in_pixels = (4 / 2160.0) * diagonal;
    }

    if !global_divider_thickness_in_pixels_is_set {
        global_divider_thickness_in_pixels = (22 / 2160.0) * diagonal;
    }

    if !global_initial_divider_position_in_pixels_is_set {
        global_initial_divider_position_in_pixels = .25 * render_target_width;
    }

    if !global_slider_nub_thickness_in_pixels_is_set {
        global_slider_nub_thickness_in_pixels = .25 * render_target_width;
    }

    x, y, success := draw_procs.get_mouse_pointer_position(window, true);
    if success {
        mouse_x = cast(s32) x;
        mouse_y = cast(s32) y;
        mouse_x_float = cast(float) mouse_x;
        mouse_y_float = cast(float) mouse_y;
        array_add(*this_frame_per_window_states, .{ window = window, mouse_x_float = mouse_x_float, mouse_y_float = mouse_y_float });

        last_frame_per_window_state : *Per_Window_State;
        for * last_frame_per_window_states {
            if it.window == window {
                last_frame_per_window_state = it;
                break;
            }
        }

        if last_frame_per_window_state {
            mouse_delta_x_float = mouse_x_float - last_frame_per_window_state.mouse_x_float;
            mouse_delta_y_float = mouse_y_float - last_frame_per_window_state.mouse_y_float;
        } else {
            mouse_delta_x_float = 0.0;
            mouse_delta_y_float = 0.0;
        }
    }

    //
    // Right now, we have swapped the order of occlusion_per_window_update() and events_per_window_update()
    // because if occluder_under_the_cursor is set to null, it confuses some activation/event visibility code.
    // This will produce the wrong result if some widget changes occluder order inside events_per_window_update()
    // and we want that to happen on the same frame. But, currently this does not happen. But we perhaps
    // should think about whether we want a more-explicit design here with more stages.
    //
    occlusion_per_window_update(window);
    events_per_window_update(window);

    return occluder_under_the_cursor && (occluder_under_the_cursor.window == window), active_widget != null;
}

ui_per_frame_update :: (window: Window_Type, _render_target_width: s32, _render_target_height: s32, _current_time: float64) -> (background_occluded: bool, is_active: bool) {
    assert(state_stack.count == 0);

    // If the active widget was not drawn, deactivate it.
    // (e.g. the user is switching pages and whatnot!)
    if active_widget && (active_widget.last_getrect_frame < current_getrect_frame) {
        active_widget_deactivate_all();
    }

    active_tooltip = .{};

    current_getrect_frame += 1;  // This addition may overflow + wrap, and that is fine!

    some_widget_received_left_mouse_button = false;

    mouse_button_left_state  = ui_get_button_state(.MOUSE_BUTTON_LEFT);
    mouse_button_right_state = ui_get_button_state(.MOUSE_BUTTON_RIGHT);
    shift_key_state          = ui_get_button_state(.SHIFT);

    if last_current_time == FLOAT64_INFINITY {
        current_dt = 0;
    } else {
        current_dt   = cast(float) (_current_time - last_current_time);
    }

    last_current_time = current_time;
    current_time      = _current_time;

    if mouse_button_left_state & .START {
        left_click_dt = cast(float) (current_time - last_left_click_time);
        if left_click_dt == current_dt {
            // The clicks occured two frames in a row, so we'll signify that by
            // returning 0 (and if the user is doing the simple thing of checking
            // for double-click by comparing left_click_dt < some click interval,
            // they will correctly register a double-click).
            left_click_dt = 0;
        }
        last_left_click_time = current_time;
    }

    render_target_width  = max(_render_target_width, 1);
    render_target_height = max(_render_target_height, 1);

    popups\  _per_frame_update();
    occlusion_per_frame_update();
    windows\ _per_frame_update();
    events\  _per_frame_update();

    occluded, is_active := switch_window(window, _render_target_width, _render_target_height);
    return occluded, is_active;
}

is_visible_in_scissor :: (x: float, y: float) -> bool {
    if !scissor_stack return true;

    top := peek_pointer(scissor_stack);
    return (x >= top.x) && (x <= top.x + top.w) && (y >= top.y) && (y <= top.y + top.h);
}

is_inside :: (x: float, y: float, r: Rect) -> bool {
    return (x >= r.x) && (x <= r.x + r.w) && (y >= r.y) && (y <= r.y + r.h);
}

is_visible_in_scissor :: (using rect: Rect) -> bool {
    if !scissor_stack return true;
    top := peek_pointer(scissor_stack);

    a_x0 := top.x;
    a_x1 := top.x + top.w;
    a_y0 := top.y;
    a_y1 := top.y + top.h;

    b_x0 := rect.x;
    b_x1 := rect.x + rect.w;
    b_y0 := rect.y;
    b_y1 := rect.y + rect.h;

    return !(a_x0 > b_x1 || a_x1 < b_x0 || a_y0 > b_y1 || a_y1 < b_y0);
}

set_scissor :: (r: Rect) {
    //
    // @Robustness: We need to think about the definition of set_scissor and
    // who exactly is inside the scissor rectangle. Do we want to be adding the +1
    // here, or should that be in Simp, or ... where?
    //
    //               -jblow, 26 June 2021.
    //
    x0 := cast(s32) r.x;
    y0 := cast(s32) r.y;
    x1 := cast(s32) (r.x + r.w + 1);
    y1 := cast(s32) (r.y + r.h + 1);

    draw_procs.set_scissor(x0, y0, x1, y1);
}

get_rect :: (x: float, y: float, w: float, h: float) -> Rect {
    r: Rect;
    r.x = x;
    r.y = y;
    r.w = w;
    r.h = h;

    return r;
}

get_quad :: (using r: Rect, snap_coordinates := false) -> (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) {
    p0 := v2(x  , y  );
    p1 := v2(x+w, y  );
    p2 := v2(x+w, y+h);
    p3 := v2(x  , y+h);

    if snap_coordinates {
        p0.x = floor(p0.x + .5);
        p0.y = floor(p0.y + .5);
        p1.x = floor(p1.x + .5);
        p1.y = floor(p1.y + .5);
        p2.x = floor(p2.x + .5);
        p2.y = floor(p2.y + .5);
        p3.x = floor(p3.x + .5);
        p3.y = floor(p3.y + .5);
    }

    return p0, p1, p2, p3;
}

intersect :: (a: Rect, b: Rect) -> Rect {
    x := max(a.x, b.x);
    y := max(a.y, b.y);

    w := max(min(a.x+a.w, b.x+b.w) - x, 0);
    h := max(min(a.y+a.h, b.y+b.h) - y, 0);

    rect := get_rect(x, y, w, h);
    return rect;
}

bound :: (a: Rect, b: Rect) -> Rect {
    x := min(a.x, b.x);
    y := min(a.y, b.y);

    x1 := max(a.x+a.w, b.x+b.w);
    y1 := max(a.y+a.h, b.y+b.h);

    rect := get_rect(x, y, x1-x, y1-y);
    return rect;
}

push_scissor :: (_rect: Rect) {
    rect := _rect;

    if scissor_stack {
        top := peek_pointer(scissor_stack);
        rect = intersect(top.*, rect);
    }

    set_scissor(rect);
    array_add(*scissor_stack, rect);
}

pop_scissor :: () {
    pop(*scissor_stack);

    if scissor_stack {
        r := peek(scissor_stack);
        set_scissor(r);
    } else {
        draw_procs.clear_scissor();
    }
}

VBase3 :: struct { x, y, z: float; };
darken :: (color: $T/interface VBase3, t: float) -> T {
    result: T;
    result.x = lerp(color.x, 0, t);
    result.y = lerp(color.y, 0, t);
    result.z = lerp(color.z, 0, t);

    #if T == Vector4  result.w = color.w;

    return result;
}

whiten :: (color: $T/interface VBase3, t: float) -> T {
    h, s, v := rgb_to_hsv(color.x, color.y, color.z);
    s -= t;

    v += t;
    Clamp(*v, 0, 1);

    Clamp(*s, 0, 1);
    Clamp(*v, 0, 1);

    r, g, b := hsv_to_rgb(h, s, v);

    result := color;  // Copy other properties like w, or ... whatevs.
    result.x = r;
    result.y = g;
    result.z = b;

    return result;
}

brighten :: (color: $T/interface VBase3, value: float) -> T {
    h, s, v := rgb_to_hsv(color.x, color.y, color.z);

    v += value;
    Clamp(*v, 0, 1);

    r, g, b := hsv_to_rgb(h, s, v);

    result := color;
    result.x = r;
    result.y = g;
    result.z = b;

    return result;
}

em :: (x: float, font: *Font) -> float {
    if font return font.em_width * x;
    return 1;  // In case we get null fonts from the user.
}

/*
button_colors :: (theme: *Button_Theme) -> (normal: Vector4, hilit: Vector4) {
    // @Cleanup
    return theme.background_color, theme.background_color_over;
}
*/


// @Speed: We should not use this, since it hides whether text is prepared or not.
text_size :: (font: *Font, text: string) -> (width: float, height: float) {
    // This code all uses ui_text_size but that is not a very good idea, because
    // using the bounding box around text often just looks sucky. We want to get to a point
    // where this procedure is not being used.  -jblow, 29 April 2021.
    w := cast(float)draw_procs.prepare_text(font, text);
    h := cast(float)font.character_height;

    return w, h;
}

has_focus :: (rect: Rect) -> bool {
    return true;  // This is just a dummy for now!
}


#scope_module

// @TODO ditch these and change to struct literals or rgb/rgba
v2 :: xy;
v3 :: xyz;
v4 :: xyzw;

move_toward :: (a: float, b: float, amount_increasing: float, amount_decreasing := -1.0) -> float {
    if a > b {
        if amount_decreasing == -1  amount_decreasing = amount_increasing;

        a -= amount_decreasing;

        if a < b  a = b;
    } else {
        a += amount_increasing;
        if a > b  a = b;
    }

    return a;
}

move_toward :: (a_pointer: *float, target: float, dt: float, rate_up: float, rate_down: float = -1.0) {
    a := a_pointer.*;

    if a > target {
        if rate_down == -1 rate_down = rate_up;
        a -= dt * rate_down;
        if a < target  a = target;
        a_pointer.* = a;
    } else if a < target {
        a += dt * rate_up;
        if a > target  a = target;
        a_pointer.* = a;
    }
}

#if IS_CROSS_COMPILING {
    // Hopefully temporary workaround for limitations of #run,host
    // Specifically, that lambdas aren't run in the scope of the current module.
    memory_radiobox_full, memory_radiobox_empty, memory_checkbox_full, memory_checkbox_empty, memory_default_font, memory_mode_circle, memory_mode_hsv, memory_mode_rgb, memory_mode_numbers :: #run,host -> string, string, string, string, string, string, string, string, string {
        #import "GetRect";
        r1, r2, r3, r4, r5, r6, r7, r8, r9 := get_rect_get_global_data();
        return r1, r2, r3, r4, r5, r6, r7, r8, r9;
    };
} else {
    // Arrays into which we will load the bitmaps at compile-time.
    // Doing this in a somewhat awkward way because that is just how things work right now:
    memory_radiobox_full, memory_radiobox_empty, memory_checkbox_full, memory_checkbox_empty, memory_default_font, memory_mode_circle, memory_mode_hsv, memory_mode_rgb, memory_mode_numbers :: #run get_global_data();
}

Default_Font_Info :: struct {
    pixel_height: int;
    font: *Font;
}

default_font_data: string;
default_font_at_size: [..] Default_Font_Info;

get_default_font_at_size :: (fsize: float) -> *Font {
    assert(default_font_data.count != 0);
    pixel_height := cast(int) floor(fsize + .5);

    // @Speed: Could use a hash table if we think the user will have many default font instantiations.
    for default_font_at_size {
        if it.pixel_height == pixel_height  return it.font;
    }

    font := draw_procs.get_font_at_size(cast([] u8)default_font_data, pixel_height);
    info := array_add(*default_font_at_size);
    info.pixel_height = pixel_height;
    info.font         = font;

    return font;
}

get_float_parameter :: (r: Rect, type: Size_Computation, local: float, global: float, override: float = FLOAT32_INFINITY) -> float {
    if override != FLOAT32_INFINITY {
        local  = override;
        global = override;
    }

    result: float;
    if #complete type == {
      case .RELATIVE_TO_HEIGHT;
        result = r.h * local;
      case .RELATIVE_TO_WIDTH;
        result = r.w * local;
      case .ABSOLUTE_FROM_THEME_FIELD;
        result = local;
      case; assert(false); #through;
      case .ABSOLUTE_FROM_GLOBAL;
        result = global;
    }

    return result;
}

#scope_file


global_data :: (filename: string) -> (memory: string, success: bool) {
    #import "Compiler";  // We are not currently restricting this to compile-time, hmm.
    #import "File";      // We should do that somehow.

    full_name := tprint("%/data/%", #filepath, filename);

    file_data, success := read_entire_file(full_name);
    if !success {
        compiler_report(tprint("Compile-time loading of '%' failed!\n", full_name), mode=.ERROR);
        return "", false;
    }

    // @ToDo: Re-enable this once we return "[] u8" again instead of "string".
    // When converting #run memory back to AST nodes, we currently don’t check for global data pointers as we do for "[] u8",
    // so the data ends up being emitted into the binary twice if we use add_global_data().
    //  -rluba, 2023-06-27
    //
    // defer free(file_data.data);
    // memory := add_global_data(cast([] u8)file_data, .READ_ONLY);
    // return cast(string) memory, true;
    return cast(string) file_data, true;
}

get_global_data :: () -> string, string, string, string, string, string, string, string, string {
    success: bool;
    all_success := true;

    radiobox_full, radiobox_empty, checkbox_full, checkbox_empty, color_marker, mem_default_font, mem_mode_circle, mem_mode_hsl, mem_mode_rgb, mem_mode_numbers: string;
    radiobox_full,  success = global_data("ui_radiobox_full.png");
    all_success &&= success;

    radiobox_empty, success = global_data("ui_radiobox_empty.png");
    all_success &&= success;

    checkbox_full,  success = global_data("ui_checkbox_full.png");
    all_success &&= success;

    checkbox_empty, success = global_data("ui_checkbox_empty.png");
    all_success &&= success;

    mem_default_font, success = global_data("Karla-Regular.ttf");
    all_success &&= success;

    mem_mode_circle, success  = global_data("mode_circle.png");
    all_success &&= success;

    mem_mode_hsl, success     = global_data("mode_hsl.png");
    all_success &&= success;

    mem_mode_rgb, success     = global_data("mode_rgb.png");
    all_success &&= success;

    mem_mode_numbers, success = global_data("mode_numbers.png");
    all_success &&= success;

    // Hmm, we do not actually use all_success now, we just report_error inside the load routine.

    return radiobox_full, radiobox_empty, checkbox_full, checkbox_empty, mem_default_font, mem_mode_circle, mem_mode_hsl, mem_mode_rgb, mem_mode_numbers;
}

events_to_handle_this_frame: [..] Event;
events_to_handle_next_frame: [..] Event;

events_per_frame_update :: ()
{
    swap(*events_to_handle_this_frame, *events_to_handle_next_frame);
    events_to_handle_next_frame.count = 0;
}

events_per_window_update :: (window: Window_Type) {
    // Search all widgets for one to activate.

    // @Speed: All events are currently considered to be in the same place,
    // but we check every widget each time. This can of course be sped way up.

    // @Speed: Now we are iterating over every single widget!

    // We want to make sure that we can handle several switches of input event,
    // mid-frame, when frame rates are low.

    // @Incomplete: Make this a local temporary pool...

    activation_proc_widgets: [..] *Active_Widget;
    defer free(activation_proc_widgets.data);

    for state_table {
        if !it.check_for_activation_proc continue;
        if it.window != window continue;
        // NOTE(daniel): If the widget was not drawn (state wasn't used last frame), it means it is invisible.
        //  Don't attempt to activate it. Is there a better way to check if something is invisible?
        //  Except for using the `scissor_stack`, that can be empty, but the widget might still not be visible.
        if it.last_getrect_frame < current_getrect_frame - 1 continue;
        array_add(*activation_proc_widgets, it);
    }

    if activation_proc_widgets {
        // Activation may switch multiple times during the frame.
        // Each time it does, pass the events to the last-active widget.

        // @Incomplete: Make this a local temporary pool...
        accrued_events: [..] Event;
        defer free(accrued_events.data);

        for event, event_index: events_to_handle_this_frame {
            for activation_proc_widgets {
                activated := it.check_for_activation_proc(it, event);
                if activated {
                    // Flush events.
                    if accrued_events && active_widget && active_widget.serial_events_proc {
                        active_widget.serial_events_proc(active_widget, accrued_events);
                        accrued_events.count = 0;
                    }

                    active_widget_add(it);
                }
            }

            array_add(*accrued_events, event);
        }

        if accrued_events {
            if active_widget && active_widget.window == window && active_widget.serial_events_proc {
                active_widget.serial_events_proc(active_widget, accrued_events);
            }
        }
    }
}

#scope_export

getrect_handle_event :: (event: Event) {
    // For now, we just buffer events here and handle them at the top of per_frame_update,
    // after the frame counter is incremented, so that we have a consistent counter when
    // handling events.

    array_add(*events_to_handle_next_frame, event);
}

is_grabbing :: () -> bool {
    return active_widget && active_widget_is_grabbing;
}

// Hopefully temporary workaround for cross-compilation
get_rect_get_global_data :: () -> string, string, string, string, string, string, string, string, string {
    r1, r2, r3, r4, r5, r6, r7, r8, r9 := get_global_data();
    return r1, r2, r3, r4, r5, r6, r7, r8, r9;
}

using CI :: #import "Color_Interpolation";

#scope_module
fract :: inline (x: float) -> float { return x - floor(x); }

WT :: #import "Window_Type";
