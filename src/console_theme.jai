//
// naysayer.nvim colortheme (https://github.com/qiekn/naysayer.nvim)
// inspired by Jonathon Blow's compiler livestreams
//

Naysayer :: struct {
    background      :: 0x062626;
    selection       :: 0x23444b;
    text            :: 0xd0b892;
    comment         :: 0x40c040;
    punctuation     :: 0x8cde94;
    keyword         :: 0xffffff;
    constant        :: 0x87ffde;
    white           :: 0xffffff;
    error           :: 0xff0000;
    warning         :: 0xffaa00;
    highlight       :: 0x0b3335;
    line_fg         :: 0x126367;
    lualine_fg      :: 0x12251b;
    lualine_bg      :: 0xd3b58e;
    dimmed_variable :: 0xa0b8c8;
}

console_color :: inline (rgb: u32) -> Vector4 {
    return .{
        cast(float)((rgb >> 16) & 0xff) / 255,
        cast(float)((rgb >> 8)  & 0xff) / 255,
        cast(float)( rgb        & 0xff) / 255,
        1
    };
}

#scope_file
#import "Math";
