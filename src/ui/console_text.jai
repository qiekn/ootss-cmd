// Return one row as a slice of the original text. Meslo is monospaced; reserve two cells for non-ASCII glyphs.
console_wrapped_row :: (text: string, position: *s64, columns: s64) -> string {
    start := position.*;
    cursor := start;
    cells: s64;
    last_space: s64 = -1;
    limit := max(1, columns);
    while cursor < text.count {
        character, bytes := Unicode.character_utf8_to_utf32(text.data + cursor, text.count - cursor);
        bytes = max(1, bytes);
        width := ifx character < 128 then 1 else 2;
        if cells + width > limit && cursor > start break;
        if text[cursor] == #char " " && cursor > start last_space = cursor;
        cursor += bytes;
        cells += width;
    }
    end := cursor;
    if cursor < text.count && text[cursor] != #char " " && last_space > start {
        end = last_space;
        cursor = last_space + 1;
    }
    while cursor < text.count && text[cursor] == #char " " cursor += 1;
    position.* = cursor;
    return slice(text, start, end - start);
}

#scope_file
#import "Basic";
#import "Math";
#import "String";
Unicode :: #import "Unicode";
