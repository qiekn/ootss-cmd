// Size_Computation controls the way the sizes of various widget aspects are computed. Wherever there
// is a declaration of type Size_Computation, there is also a similarly-named floating point parameter
// that acts as an argument. Rectangle_Shape, for example, has two fields 'roundedness_type' and 'roundedness'.
// Setting 'roundedness_type' to RELATIVE_TO_HEIGHT causes the system to multiply 'roundedness' by rect.h
// to get the radius, in pixels, of the circle used to round the corner of the widget.
//
// The various options are:
//
//   RELATIVE_TO_HEIGHT:        Size is computed by multiplying the relevant theme field by the height of the Rect passed to the widget function.
//   RELATIVE_TO_WIDTH:         Size is computed by multiplying the relevant theme field by the width  of the Rect passed to the widget function.
//   ABSOLUTE_FROM_THEME_FIELD: The value in the field is used verbatim as the number of pixels. If the target you are shipping on does not have a known fixed display resolution, you should update this field yourself based on screen resolution.
//   ABSOLUTE_FROM_GLOBAL:      If you want all your themes to have matched sizes for some parameter, regardless of their rect sizes, but you don't want to manually adjust them all whenever the display resolution changes, you can use built-in global variables. See, for example, set_global_rounding_radius_in_pixels() in module.jai. If you do not call these setter functions yourself, the globals will hold some default value that is recomputed whenever the resolution changes. Once you do call any of the setter functions, the system will no longer automatically update it, so responsibility is on you to maintain that value as the resolution changes.
//

Size_Computation :: enum u8 {   // Defaults to RELATIVE_TO_HEIGHT.
    RELATIVE_TO_HEIGHT        :: 0;
    RELATIVE_TO_WIDTH         :: 1;
    ABSOLUTE_FROM_THEME_FIELD :: 2;
    ABSOLUTE_FROM_GLOBAL      :: 3;
};

Rectangle_Shape :: struct {
    roundedness_type: Size_Computation;
    
    roundedness := .18;   // If absolute, this is the number of pixels. If relative, set this to a value in [0, 1]: 0 == totally squared off; 1 == capsule along the width or height (though this will be clamped to the shortest side).
    
    pixels_per_edge_segment  := 10.0;  // How many triangles we generate for the curves, based on the length of the arc.

    frame_thickness_type: Size_Computation;
    frame_thickness := .02;            // By default, .02 * rect.h. Set to a value <= 0 for no frame.

    Rounding_Flags :: enum_flags u32 {
        NORTHEAST :: 0x1;
        NORTHWEST :: 0x2;
        SOUTHWEST :: 0x4;
        SOUTHEAST :: 0x8;

        // Combo flags, for convenience:
        EAST  :: NORTHEAST | SOUTHEAST;
        WEST  :: NORTHWEST | SOUTHWEST;
        SOUTH :: SOUTHEAST | SOUTHWEST;
        NORTH :: NORTHEAST | NORTHWEST;

        ALL :: EAST | WEST;
    }

    rounding_flags := Rounding_Flags.NORTHEAST | .NORTHWEST | .SOUTHWEST | .SOUTHEAST;
}

Label_Theme :: struct {
    font:    *Font;
    effects: Font_Effects;
    
    text_color                      := Vector4.{1, 1, 1, 1};
    alignment                       := Text_Alignment.Center;
    alignment_pad_ems               := 1.0;
    text_baseline_vertical_position := FLOAT32_INFINITY;      // How high up the rect is the text baseline, relative to rect height.  If it is FLOAT32_INFINITY, we choose a default based on the input rect.
}

Background_Theme :: struct {
    shape: Rectangle_Shape;

    color       := Vector4.{.08, .08, .08, 1.0};
    frame_color := Vector4.{.25, .25, .22, 1.0};
}


Margin :: enum_flags {
    Horizontal :: 0x1;
    Vertical   :: 0x2;
}


//
// Right now, Overall_Theme keeps us from having a handy thing where you can just delete
// individual files with widgets you don't want; you also have to comment them out here
// (and maybe do one or two other things; I haven't tested yet). But the long term plan
// is to reduce code spam by being able to make your local copy of this module with
// widgets removed. Maybe if we finally get #if_defined we can use that to bracket these out,
// or, uhh, do something else.   - jblow, 13 December 2021
//
Overall_Theme :: struct {
    button_theme:            Button_Theme;
    checkbox_theme:          Checkbox_Theme;
    color_picker_theme:      Color_Picker_Theme;
    dropdown_theme:          Dropdown_Theme;
    label_theme:             Label_Theme;
    scrollable_region_theme: Scrollable_Region_Theme;
    slidable_region_theme:   Slidable_Region_Theme;
    slider_theme:            Slider_Theme;
    subwindow_theme:         Subwindow_Theme;
    // Text_Display is not yet done.  text_display_theme:      Text_Display_Theme;
    text_input_theme:        Text_Input_Theme;
    color_animation_editor_theme:  Color_Animation_Editor_Theme;
    
    // These are the same ingredients as in Button_Theme ..
    // Hmmmmm!!
    font: *Font;

    background_color        := Vector4.{.10, .10, .10, 1.0};
    background_color_bright := Vector4.{.15, .15, .15, 1.0};
    text_color              := Vector4.{.80, .80, .80, 1.0};

    title_bar_color         := Vector4.{.80, .30, .30, 1.0};
    title_bar_color_hilit   := Vector4.{.95, .50, .50, 1.0};

    border_width       := .004;  // Border of the window, relative to render target height.
    outer_margin_size  := .007;  // Outer margin of the content space, relative to render target height.
    outer_margin_flags := Margin.Horizontal | .Vertical;
    
    scrollable_section_margin_width := .007;  // Outer margin of the content space, relative to render target height.
    scrollable_section_margin_flags := Margin.Horizontal | .Vertical;
    
    alpha_scale := 1.0;
}


set_default_theme :: (theme: Overall_Theme) {
    default_overall_theme = theme;
}

// The theme code below is licensed under the MIT license (the code above is due to Thekla, Inc):
/*

MIT License

Copyright (c) 2022 Andrew J. Haman

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

Default_Themes :: enum {
    Default;
    Grayscale;
    Bentonite;
    Nimbus;
    Blood_Vampire;
    Freddie_Freeloader;
    HIGH_CONTRAST;
}

Theme_Proc :: #type () -> Overall_Theme;

default_theme_procs : [THEME_COUNT] Theme_Proc : Theme_Proc.[
    theme_proc_default,
    theme_proc_grayscale,
    theme_proc_bentonite,
    theme_proc_nimbus,
    theme_proc_blood_vampire,
    theme_proc_freddie_freeloader,
    theme_proc_high_contrast
];

THEME_COUNT :: #run enum_highest_value(Default_Themes) + 1;
#assert default_theme_procs.count == THEME_COUNT;

#scope_export



set_theme_from_base_colors :: (theme : * Overall_Theme, main_surface_color : Vector4, border_color : Vector4, interact_color : Vector4, atop_surface_text : Vector4, atop_border_text : Vector4) {

    extra_low := darken(border_color, 0.1);
    extra_high := whiten(interact_color, 0.1);

    hot_surface_text := whiten(atop_surface_text, 0.2);
    hot_border_text := whiten(atop_border_text, 0.2);

    theme.background_color = darken(main_surface_color, 0.1);
    theme.background_color_bright = darken(border_color, 0.1);

    region_background_color := lerp(main_surface_color, theme.background_color, 0.2);

    theme.text_color = atop_surface_text;

    theme.label_theme.text_color = atop_surface_text;
//    theme.text_display_theme.text_theme = theme.label_theme;

    theme.title_bar_color = border_color;
    theme.title_bar_color_hilit = interact_color;

    {//Button Theme
        using theme.button_theme;

        surface_color = main_surface_color;
        surface_color_over = interact_color;
        surface_color_flash = whiten(main_surface_color, 0.2);
        surface_color_down = darken(main_surface_color, 0.2);

        frame_color = border_color;
        frame_color_over = main_surface_color;
        frame_color_flash = extra_high;
        frame_color_down = border_color;

        text_color = atop_surface_text;
        text_color_over = hot_surface_text;
    }

    {//Subwindow Theme
        using theme.subwindow_theme;

        title_bar.surface_color = border_color;
        title_bar.frame_color = extra_low;
        title_bar.text_color = atop_border_text;     
        title_bar.surface_color_over = interact_color;
        title_bar.frame_color_over = main_surface_color;
        title_bar.text_color_over = hot_border_text;
        title_bar.surface_color_flash = extra_high;
        title_bar.frame_color_flash = extra_high;      
        title_bar.surface_color_down = extra_low;
        title_bar.frame_color_down = theme.button_theme.frame_color_down;

        region_background.frame_color = border_color;
        region_background.color       = main_surface_color;

        close_button.surface_color = border_color;
        close_button.frame_color = border_color;
        close_button.surface_color_over = main_surface_color;
        close_button.frame_color_over = main_surface_color;
        close_button.text_color = atop_border_text;
        close_button.text_color_over = atop_surface_text;

        resize_corner_color = border_color;
        region_background.color = region_background_color;
    }

    {//Checkbox Theme
        using theme.checkbox_theme;
        theme.checkbox_theme.button_theme = theme.button_theme;
        button_theme.label_theme.alignment = Text_Alignment.Left;

        button_theme.text_color = atop_surface_text;
        button_theme.text_color_over = hot_surface_text;

        button_color_selected = hot_surface_text;
        text_color_selected = hot_surface_text;

        alignment_pad_ems = Checkbox_Theme.{}.alignment_pad_ems;
    }

    {//Slidable Region
        using theme.slidable_region_theme;
        divider_theme.surface_color = border_color;
        divider_theme.frame_color = border_color;
        divider_theme.surface_color_over = interact_color;

        first_background.color  = region_background_color;
        first_background.frame_color = border_color;
        second_background.color = region_background_color;
        second_background.frame_color = border_color;
    }

    {//Scrollable Region
        using theme.scrollable_region_theme;

        scrollbar_nib_theme = theme.button_theme;

        scrollbar_background.color = main_surface_color;
        scrollbar_background.frame_color = border_color;

        scrollbar_nib_theme.rectangle_shape.roundedness = region_background.shape.roundedness;
        scrollbar_nib_theme.frame_color = main_surface_color;
        scrollbar_nib_theme.frame_color_over = interact_color;
        scrollbar_nib_theme.frame_color_down = scrollbar_nib_theme.frame_color_over;

        scrollbar_nib_theme.surface_color = border_color;
        scrollbar_nib_theme.surface_color_over = border_color;
        scrollbar_nib_theme.surface_color_down = interact_color;
        
        region_background.color = region_background_color;
        region_background.frame_color = border_color;
    }

    {//Text Input
        using theme.text_input_theme;
        rectangle_shape.frame_thickness = .07;

        theme.text_input_theme.button_theme = theme.button_theme;
        alignment = .Left;

        h,s,v := rgb_to_hsv(surface_color.x, surface_color.y, surface_color.z);
        if v > 0.8 { 
            text_color_autocomplete = darken(surface_color, 0.2);
        } else {
            text_color_autocomplete = whiten(surface_color, 0.2);
        }
        text_color_autocomplete_failed = text_color_autocomplete;
        text_color = atop_surface_text;
        text_color_over = hot_surface_text;
        selection_color = extra_high;
    }

    {//Slider
        using theme.slider_theme;

        foreground.surface_color = interact_color;
        foreground.surface_color_over = extra_high;
        foreground.surface_color_flash = foreground.surface_color_over;//Don't flash.
        foreground.surface_color_down = border_color;

        foreground.frame_color       = main_surface_color;
        foreground.frame_color_over  = interact_color;
        foreground.frame_color_flash = interact_color;
        foreground.frame_color_down  = main_surface_color;

        //The slider labels do not yet support anything besides a single color, so just choose a bright color
        extra_extra_high := whiten(extra_high, 0.5);
        foreground.text_color         = extra_extra_high;
        foreground.text_color_over    = extra_extra_high;
        foreground.text_color_pressed = extra_extra_high;

        background.surface_color = extra_low;
        background.surface_color_over = extra_low;
        background.surface_color_down = extra_low;
        background.surface_color_flash = extra_low;

        background.frame_color = border_color;
        background.frame_color_over = border_color;
        background.frame_color_flash = border_color;
        background.frame_color_down = border_color;

        spinbox_theme = theme.button_theme;
        spinbox_theme.text_color = atop_border_text;
        spinbox_theme.text_color_over = hot_border_text;
        spinbox_theme.text_color_pressed = hot_border_text;

        copy_text_input_colors(theme.text_input_theme, *theme.slider_theme.text_input_theme);
    }

    {//Dropdown
        using theme.dropdown_theme;

        theme_for_current_value = theme.button_theme;
        theme_for_each_choice = theme.button_theme;
        theme_for_current_choice = theme.button_theme;

        invert_button_theme(*theme_for_current_choice);
        invert_button_theme(*theme_for_current_value);
        
        theme_for_each_choice.text_color = atop_surface_text;
        theme_for_each_choice.text_color_over = hot_surface_text;
    }

    {//Color Picker
        using theme.color_picker_theme;

        //Desaturate the provided colors to give an objective baseline for comparing colors.
        desat_surface   := desaturate(main_surface_color);
        desat_border    := desaturate(border_color);
        desat_extra_low := desaturate(extra_low);

        // The surface colors of these buttons will change at runtime, 
        // but we still want to copy the shape/styling if it's changed above.
        apply_and_revert_button_theme = theme.button_theme;
        apply_and_revert_button_theme.frame_color = desat_border;
        apply_and_revert_button_theme.frame_color_over = desat_extra_low;
        
        background.color = desat_surface;
        background.frame_color = desat_border;

        stash_button_theme.surface_color = desat_border;
        stash_button_theme.frame_color = desat_extra_low;
        stash_button_theme.frame_color_over = desat_surface;

        mode_switch_button_theme = stash_button_theme;
        copy_text_input_colors(theme.text_input_theme, *theme.color_picker_theme.type_ins_input_theme.text_input_theme);
    }
}

invert_button_theme :: (button_theme : *Button_Theme) {
    //This will swap frame and surface colors of button_theme.
    //This is useful if for example you want to have a set of buttons atop a scrollable region,
    // which by default would have the same surface_color as the button_theme.
    swap(*button_theme.surface_color,       *button_theme.frame_color);
    swap(*button_theme.surface_color_over,  *button_theme.frame_color_over);
    swap(*button_theme.surface_color_flash, *button_theme.frame_color_flash);
    swap(*button_theme.surface_color_down,  *button_theme.frame_color_down);
}

invert_scrollbar :: (using scrollable_region_theme : *Scrollable_Region_Theme) {
    swap(*scrollbar_background.color, *scrollbar_background.frame_color);
    {
        using scrollable_region_theme.scrollbar_nib_theme;
        surface_color, frame_color = frame_color, surface_color;
    }
}

#scope_file

theme_proc_default :: () -> Overall_Theme {
    default: Overall_Theme;
    return default;
}

theme_proc_grayscale :: () -> Overall_Theme {
    result : Overall_Theme;

    surface_color     :: Vector4.{.20, .20, .22, 1.0};    
    border_color      :: Vector4.{.16, .16, .18, 1.0};
    interact_color    :: Vector4.{.53, .51, .54, 1.0};
    atop_surface_text :: Vector4.{.6, .6, .6, 1.0};
    atop_border_text  :: Vector4.{.6, .6, .6, 1.0};

    set_theme_from_base_colors(*result, surface_color, border_color, interact_color, atop_surface_text, atop_border_text);
    invert_scrollbar(*result.scrollable_region_theme);

    result.background_color = .{.10, .09, .12, 1.0};
    result.button_theme.frame_color = darken(border_color, 0.3);

    {//Dropdown
        using result.dropdown_theme;
        invert_button_theme(*theme_for_each_choice);
        invert_button_theme(*theme_for_current_choice);
        invert_button_theme(*theme_for_current_value);
        theme_for_current_value.frame_color = result.button_theme.frame_color;
    }
    {//Subwindow
        using result.subwindow_theme;

        close_button.surface_color       = .{.16, .16, .18, 1};
        close_button.surface_color_over  = .{.89, .25, .16, 1};
        close_button.surface_color_flash = .{.90, .90, .90, 1};
        close_button.surface_color_down  = .{.95, .65, .05, 1};

        close_button.text_color          = .{.89, .25, .16, 1};
        close_button.text_color_over     = .{.16, .16, .18, 1};
        close_button.text_color_pressed  = .{.99, .99, .99, 1};

        close_button.frame_color         = .{.89, .25, .16, 0};
        close_button.frame_color_over = close_button.text_color_over;
    }
    
    result.text_input_theme.text_color_over = .{.9, .9, .9, 1.0};
    result.text_input_theme.frame_color = result.button_theme.frame_color;
    
    copy_text_input_colors(result.text_input_theme, *result.slider_theme.text_input_theme);
    copy_text_input_colors(result.text_input_theme, *result.color_picker_theme.type_ins_input_theme.text_input_theme);

    return result;
}

theme_proc_bentonite :: () -> Overall_Theme {
    result : Overall_Theme;

    surface_color     :: Vector4.{0.16,0.16,0.16, 1.0};
    border_color      :: Vector4.{0.28,0.24,0.22, 1.0};
    interact_color    :: Vector4.{0.76,0.70,0.55, 1.0};
    atop_surface_text :: Vector4.{0.62,0.60,0.55, 1.0};
    atop_border_text  :: Vector4.{0.89,0.84,0.75, 1.0};

    set_theme_from_base_colors(*result, surface_color, border_color, interact_color, atop_surface_text, atop_border_text);
    invert_button_theme(*result.button_theme);

    result.button_theme.surface_color_down = surface_color;
    
    {//Subwindow
        using result.subwindow_theme.close_button;
        surface_color_over = interact_color;
        frame_color_over = interact_color;
        text_color_over = border_color;
    }
    
    {//Text Input
        using result.text_input_theme;
        button_theme.surface_color_over = darken(button_theme.surface_color, 0.2);
        selection_color = whiten(result.button_theme.surface_color, 0.1);
    }
    
    copy_text_input_colors(result.text_input_theme, *result.slider_theme.text_input_theme);
    copy_text_input_colors(result.text_input_theme, *result.color_picker_theme.type_ins_input_theme.text_input_theme);

    return result;
}

theme_proc_blood_vampire :: () -> Overall_Theme {
    result : Overall_Theme;

    border_color      :: Vector4.{0.28,0.00,0.00, 1};
    surface_color     :: Vector4.{0.10,0.07,0.06, 1};

    interact_color    :: Vector4.{.40, .10, .15, 1};
    atop_surface_text :: Vector4.{.60, .60, .60, 1};
    atop_border_text  :: Vector4.{.90, .90, .90, 1};

    bright_red        :: Vector4.{.8, .2, .05, 1};
    medium_red :: Vector4.{.55, .08, .09, 1.0};

    set_theme_from_base_colors(*result, surface_color, border_color , interact_color, atop_surface_text, atop_border_text);
    
    {//Dropdown
        //CopyPaste from the default Dropdown_Theme values in case those ever want to change.
        using result.dropdown_theme;
        theme_for_current_value.surface_color        = .{.3, .07, .05, 1};
        theme_for_current_value.surface_color_over   = .{.4, .1, .15, 1};
        theme_for_current_value.surface_color_flash  = .{.75, .75, .55, 1};
        theme_for_current_value.surface_color_down   = .{.4, .4, .25, 1};

        theme_for_current_value.frame\  _color       = .{.6, .37, .35, 1};
        theme_for_current_value.frame\  _color_over  = .{.7, .4, .45, 1};
        theme_for_current_value.frame\  _color_flash = .{.95, .95, .85, 1};
        theme_for_current_value.frame\  _color_down  = .{.7, .7, .55, 1};

        theme_for_current_choice.surface_color       = .{.8, .2, .05, 1};
        theme_for_current_choice.surface_color_over  = .{.9, .3, .15, 1};
        theme_for_current_choice.surface_color_flash = .{.95, .75, .55, 1};
        theme_for_current_choice.surface_color_down  = .{.99, .4, .25, 1};

        theme_for_current_choice.frame\ _color       = .{.9, .5, .35, 1};
        theme_for_current_choice.frame\ _color_over  = .{.95, .6, .45, 1};
        theme_for_current_choice.frame\ _color_flash = .{.99, .95, .85, 1};
        theme_for_current_choice.frame\ _color_down  = .{.99, .7, .55, 1};

        theme_for_each\  _choice.surface_color       = .{.15, .05, .05, 1};
        theme_for_each\  _choice.surface_color_over  = .{.25, .12, .12, 1};
        theme_for_each\  _choice.surface_color_flash = .{.65, .55, .35, 1};
        theme_for_each\  _choice.surface_color_down  = .{.40, .20, .10, 1};

        theme_for_each\  _choice.frame\ _color       = .{.35, .20, .20, 1};
        theme_for_each\  _choice.frame\ _color_over  = .{.45, .25, .25, 1};
        theme_for_each\  _choice.frame\ _color_flash = .{.95, .85, .85, 1};
        theme_for_each\  _choice.frame\ _color_down  = .{.70, .50, .35, 1};
    }

    result.button_theme = result.dropdown_theme.theme_for_current_value;

    {//Subwindow
        using result.subwindow_theme;
        close_button.surface_color_over = bright_red;
        close_button.text_color_over = title_bar.surface_color;
    }
    
    {//Text Input
        using result.text_input_theme;
        surface_color = Dropdown_Theme.{}.theme_for_each_choice.surface_color;
        frame_color = .{.73, .35, .3, 1.0};

        surface_color_over = darken(surface_color, 0.4);
        frame_color_over = bright_red;
        frame_color_down = Dropdown_Theme.theme_for_current_choice.surface_color;
        frame_color_flash = Dropdown_Theme.theme_for_current_choice.surface_color;
        selection_color = medium_red;

        text_color_autocomplete_failed = bright_red;
    }
    
    {//Slider
        using result.slider_theme;
        background.surface_color = result.button_theme.surface_color;
        background.frame_color = result.button_theme.frame_color;
        background.frame_color_over = Dropdown_Theme.{}.theme_for_current_choice.surface_color;
        background.frame_color_flash = background.frame_color_over;//no flash

        background.surface_color_over = result.button_theme.surface_color_over;
        background.surface_color_flash = darken(background.surface_color_over, 0.1);

        foreground.surface_color_over = background.frame_color_over;
        foreground.surface_color = medium_red;
        foreground.surface_color_flash = foreground.surface_color_over;//no flash

        spinbox_theme = result.button_theme;
        copy_text_input_colors(result.text_input_theme, *result.slider_theme.text_input_theme);
    }
    
    copy_text_input_colors(result.text_input_theme, *result.color_picker_theme.type_ins_input_theme.text_input_theme);

    result.checkbox_theme.button_color_selected = medium_red;
    result.background_color = .{0.12,0.09,0.11, 1.0};

    return result;
}

theme_proc_nimbus :: () -> Overall_Theme {
    result : Overall_Theme;

    saturated_blue :: Vector4.{0.31,0.55,0.82, 1.0};

    border_color      :: Vector4.{0.65,0.82,0.94, 1};
    surface_color     :: Vector4.{0.87,0.89,0.90, 1};
    interact_color    :: Vector4.{ .39, .71, 1.0, 1};
    atop_border_text  :: Vector4.{0.31,0.31,0.33, 1};
    atop_surface_text :: Vector4.{.4, .4, .4, 1};
    
    whitened :: Vector4.{0.87+.03,0.89+.03,0.90+.03, 1};

    set_theme_from_base_colors(*result, surface_color, border_color, interact_color, atop_surface_text, atop_border_text);

    {//Button
        using result.button_theme;
        surface_color_over = .{0.72,0.77,0.91, 1.0};
        surface_color_flash = interact_color;
        surface_color_down = interact_color;
        frame_color = .{0.62,0.75,0.84, 1};
        frame_color_over = interact_color;
        frame_color_flash = interact_color;
        text_color_pressed = whitened;
    }
    {//Subwindow
        using result.subwindow_theme;
        title_bar.frame_color = darken(border_color, 0.05);
        title_bar.frame_color_over = interact_color;
        title_bar.frame_color_down = interact_color;
        title_bar.frame_color_flash = interact_color;
        title_bar.text_color_over = whitened;

        title_bar.surface_color_over = title_bar.surface_color;
        title_bar.surface_color_down = interact_color;
    }
    {//Slidable Region
        using result.slidable_region_theme;
        divider_theme.frame_color_over = interact_color;
        divider_theme.surface_color_down = interact_color;
    }
    {//Scrollable Region
        using result.scrollable_region_theme;
        scrollbar_nib_theme.surface_color_flash = scrollbar_nib_theme.surface_color;
    }
    {//Text Input
        using result.text_input_theme;
        text_color         = atop_surface_text;
        text_color_over    = darken(atop_surface_text, 0.3);
        text_color_pressed = darken(atop_surface_text, 0.2);
        button_theme.surface_color_over = whiten(surface_color, 0.1);
        frame_color = border_color;
        surface_color = whitened;
        text_color_autocomplete = desaturate(interact_color, 0.5);
        text_color_autocomplete_failed = whiten(result.text_input_theme.text_color, 0.3);
    }
    {//Slider
        using result.slider_theme;
        foreground.surface_color = border_color;
        foreground.frame_color = foreground.surface_color;
        foreground.text_color = atop_surface_text;
        background.surface_color = whitened;
        background.surface_color_over = background.surface_color;
        background.surface_color_flash = background.surface_color;
        background.frame_color_over = interact_color;
        background.frame_color_flash = interact_color;
        background.frame_color_down = interact_color;
        background.frame_color = border_color;
        copy_text_input_colors(result.text_input_theme, *result.slider_theme.text_input_theme);
    }
    {//Checkbox
        using result.checkbox_theme; button_color_selected = saturated_blue; 
        text_color_selected, text_color = text_color, text_color_selected;
        text_color = darken(text_color, 0.1);
        text_color_over = darken(text_color, 0.2);
        text_color_pressed = .{0.0, 0.03, 0.03, 1.0};
        button_color_selected = interact_color;
    }
    {//Dropdown
        using result.dropdown_theme;
        theme_for_current_choice.surface_color = interact_color;
        theme_for_current_value.text_color = atop_border_text;
        theme_for_current_choice.text_color = atop_border_text;
        theme_for_each_choice.text_color = atop_surface_text;
        theme_for_each_choice.text_color_over = atop_surface_text;
        theme_for_current_value.frame_color = interact_color;
    }
    copy_text_input_colors(result.text_input_theme, *result.color_picker_theme.type_ins_input_theme.text_input_theme);

    return result;
}

theme_proc_freddie_freeloader :: () -> Overall_Theme {
    result : Overall_Theme;

    surface_color      :: Vector4.{0.21,0.25,0.38 ,1.0};
    border_color     :: Vector4.{0.30,0.35,0.531,1.0};
    interact_color    :: Vector4.{0.39,0.49,1.00,1.0};
    atop_surface_text :: Vector4.{.8,0.8,0.8,1.0};
    atop_border_text  :: Vector4.{0.99,0.99,0.99,1.0};

    set_theme_from_base_colors(*result, surface_color, border_color, interact_color, atop_surface_text, atop_border_text);

    invert_button_theme(*result.button_theme);

    button_blue :: Vector4.{0.32,0.42,0.64, 1.0};

    {//Button
        using result.button_theme;
        surface_color = button_blue;
        frame_color = darken(button_blue, 0.2);
        text_color = atop_border_text;
    }
    {//Checkbox
        using result.checkbox_theme;
        button_color_selected = interact_color;
        surface_color_over = desaturate(interact_color, -0.25);
    }
    {//Text Input
        using result.text_input_theme;
        frame_color = button_blue;
        text_color_over = atop_border_text;
        text_color_pressed = atop_border_text;
        selection_color = whiten(interact_color, 0.3);
    }
    {//Slider
        using result.slider_theme;
        spinbox_theme = result.button_theme;
        background.frame_color_over = interact_color;
        background.surface_color_over = result.button_theme.surface_color_over;
        copy_text_input_colors(result.text_input_theme, *result.slider_theme.text_input_theme);
    }
    {//Dropdown
        using result.dropdown_theme;
        theme_for_current_choice.surface_color = interact_color;
        theme_for_current_choice.text_color = atop_border_text;
        theme_for_current_value = result.button_theme;
    }
    result.subwindow_theme.close_button.surface_color_over = interact_color;
    result.subwindow_theme.close_button.text_color_over = surface_color;

    copy_text_input_colors(result.text_input_theme, *result.color_picker_theme.type_ins_input_theme.text_input_theme);

    result.background_color = .{0.12,0.13,0.22, 1.0};

    return result;
}

theme_proc_high_contrast :: () -> Overall_Theme {
    result : Overall_Theme;

    surface_color     :: Vector4.{0.92,0.92,0.92, 1.0};
    border_color      :: Vector4.{0.07,0.07,0.07, 1.0};

    very_high_grey  :: #run lerp(surface_color, border_color, 0.1);
    high_grey       :: #run lerp(surface_color, border_color, 0.3);
    mid_grey        :: #run lerp(surface_color, border_color, 0.5);

    interact_color    :: high_grey;
    atop_surface_text :: Vector4.{0.13,0.13,0.13, 1.0};
    atop_border_text  :: Vector4.{0.92,0.92,0.92, 1.0};

    set_theme_from_base_colors(*result, surface_color, border_color, interact_color, atop_surface_text, atop_border_text);
    invert_button_theme(*result.button_theme);
    result.button_theme.text_color = atop_border_text;
    result.button_theme.text_color_over =  border_color;
    result.button_theme.text_color_pressed = surface_color;

    {//Text Input
        using result.text_input_theme;
        text_color_over = border_color;
        text_color_pressed = border_color;
        surface_color_over = very_high_grey;
        selection_color = Vector4.{0.0, 0.9, 0.9, 1.0};
    }
    {//Dropdown
        using result.dropdown_theme;
        theme_for_current_value.text_color = atop_border_text;
        theme_for_current_choice.text_color = atop_border_text;
        theme_for_each_choice.text_color = atop_surface_text;
        theme_for_each_choice.text_color_over = atop_surface_text;
    }
    {//Checkbox
        using result.checkbox_theme;
        button_color_selected = surface_color;
        text_color_selected = Vector4.{0.29,0.29,0.29, 1.0};
    }
    {//Slider
        using result.slider_theme;
        foreground.surface_color = mid_grey;
        foreground.surface_color_over = interact_color;
        foreground.surface_color_flash = foreground.surface_color_over;//Don't flash.
        foreground.surface_color_down = border_color;
        invert_button_theme(*spinbox_theme);
        copy_text_input_colors(result.text_input_theme, *result.slider_theme.text_input_theme);
    }
    result.subwindow_theme.title_bar.frame_color = surface_color;
    copy_text_input_colors(result.text_input_theme, *result.color_picker_theme.type_ins_input_theme.text_input_theme);

    return result;
}

desaturate :: (c : Vector4, amount := 1.0) -> Vector4 {
    h, s, v := rgb_to_hsv(c.x, c.y, c.z);
    s = lerp(s, 0, amount);
    r, g, b := hsv_to_rgb(h, s, v);

    result : Vector4;
    result.x = r;
    result.y = g;
    result.z = b;
    result.w = c.w;
    return result;
}

copy_text_input_colors :: (src : Text_Input_Theme, dest : *Text_Input_Theme) {
    // We want to be able to copy the color fields of a Text_Input_Theme without
    // necessarily copying every field (such as alignment), which would happen
    // when using regular assignment.

    dest.surface_color       = src.surface_color;
    dest.surface_color_over  = src.surface_color_over;
    dest.surface_color_flash = src.surface_color_flash;
    dest.surface_color_down  = src.surface_color_down;

    dest.frame_color       = src.frame_color;
    dest.frame_color_over  = src.frame_color_over;
    dest.frame_color_flash = src.frame_color_flash;
    dest.frame_color_down  = src.frame_color_down;    

    dest.text_color          = src.text_color;
    dest.text_color_over     = src.text_color_over;
    dest.text_color_pressed  = src.text_color_pressed;
    dest.text_color_autocomplete        = src.text_color_autocomplete;
    dest.text_color_autocomplete_failed = src.text_color_autocomplete_failed;

    dest.selection_color = src.selection_color;
    dest.cursor_color    = src.cursor_color;
}
