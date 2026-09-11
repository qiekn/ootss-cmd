console_paste_from_clipboard :: (console: *Console_State, owner: Win.HWND) {
    if !Win.OpenClipboard(owner) {
        console_write(console, "Clipboard is busy. Try pasting again.", .ERROR);
        return;
    }
    defer Win.CloseClipboard();

    data := Win.GetClipboardData(Win.CF_UNICODETEXT);
    if !data return;
    buffer := cast(*u16) Win.GlobalLock(data);
    if !buffer {
        console_write(console, "Could not read clipboard text.", .ERROR);
        return;
    }
    defer Win.GlobalUnlock(data);

    capacity := GlobalSize(data) / size_of(u16);
    length: u64;
    while length < capacity && buffer[length] != 0 length += 1;
    if length == capacity || length > 0x7fffffff {
        console_write(console, "Clipboard text is not a valid terminated string.", .ERROR);
        return;
    }
    text, success := Utf8.wide_to_utf8(buffer, cast(s32) length);
    if !success {
        console_write(console, "Could not decode clipboard text.", .ERROR);
        return;
    }
    defer free(text);
    console_paste_text(console, text);
}

#scope_file

#import "Basic";
Win :: #import "Windows";
Utf8 :: #import "Windows_Utf8";

kernel32 :: #library,system "kernel32";
GlobalSize :: (memory: Win.HGLOBAL) -> u64 #foreign kernel32;
