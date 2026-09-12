console_paste_from_clipboard :: (console: *Console_State, owner: Win.HWND) {
    text, error := clipboard_read_text(owner);
    defer free(text);
    if error.count { console_write(console, error, .ERROR); return; }
    console_paste_text(console, text);
}

clipboard_read_text :: (owner: Win.HWND) -> (text: string, error: string) {
    if !Win.OpenClipboard(owner) {
        return "", "Clipboard is busy. Try pasting again.";
    }
    defer Win.CloseClipboard();

    data := Win.GetClipboardData(Win.CF_UNICODETEXT);
    if !data return "", "";
    buffer := cast(*u16) Win.GlobalLock(data);
    if !buffer {
        return "", "Could not read clipboard text.";
    }
    defer Win.GlobalUnlock(data);

    capacity := GlobalSize(data) / size_of(u16);
    length: u64;
    while length < capacity && buffer[length] != 0 length += 1;
    if length == capacity || length > 0x7fffffff {
        return "", "Clipboard text is not a valid terminated string.";
    }
    text, success := Utf8.wide_to_utf8(buffer, cast(s32) length);
    if !success {
        return "", "Could not decode clipboard text.";
    }
    return text, "";
}

clipboard_write_text :: (owner: Win.HWND, text: string) -> string {
    if !owner return "Could not copy text without an editor window.";
    wide, converted, bytes := Utf8.utf8_to_wide(text);
    defer free(wide);
    if !converted return "Could not encode clipboard text.";

    // CF_UNICODETEXT takes ownership of movable global memory only after SetClipboardData succeeds.
    memory := Win.GlobalAlloc(Win.GMEM_MOVEABLE, cast(u64) bytes + size_of(u16));
    if !memory return "Could not allocate clipboard text.";
    transferred := false;
    defer if !transferred GlobalFree(memory);
    buffer := cast(*u16) Win.GlobalLock(memory);
    if !buffer return "Could not prepare clipboard text.";
    for i: 0..bytes / 2 - 1 buffer[i] = wide[i];
    buffer[bytes / 2] = 0;
    Win.GlobalUnlock(memory);

    if !Win.OpenClipboard(owner) return "Clipboard is busy. Try copying again.";
    defer Win.CloseClipboard();
    if !Win.EmptyClipboard() return "Could not clear the clipboard.";
    if !Win.SetClipboardData(Win.CF_UNICODETEXT, memory) return "Could not write clipboard text.";
    transferred = true;
    return "";
}

#scope_file

#import "Basic";
Win :: #import "Windows";
Utf8 :: #import "Windows_Utf8";

kernel32 :: #library,system "kernel32";
GlobalSize :: (memory: Win.HGLOBAL) -> u64 #foreign kernel32;
GlobalFree :: (memory: Win.HGLOBAL) -> Win.HGLOBAL #foreign kernel32;
