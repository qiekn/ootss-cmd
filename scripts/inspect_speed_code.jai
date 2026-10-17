#!/usr/bin/env jai

// Read-only instruction evidence for new game builds. Writes only a local code dump.
#run {
    set_build_options_dc(.{do_output = false});
    error := inspect();
    if error.count compiler_report(error);
}

inspect :: () -> string {
    memory, error := App.process_open_memory(App.find_game_window(), App.GAME_EXECUTABLE);
    if error.count return error;
    defer App.process_close_memory(*memory);
    code, rva, code_error := App.process_read_module_code(memory);
    defer free(code.data);
    if code_error.count return code_error;
    if !write_entire_file(tprint("%/../.build/speed-code.bin", #filepath), code.data, code.count) return "Could not write local code dump.";
    print("Base 0x%, text RVA 0x%, bytes %.\n", formatInt(memory.module.base, base = 16), formatInt(rva, base = 16), code.count);
    for i: 0..code.count - 16 {
        if code[i]   != 0xf2 || code[i+1] != 0x0f || code[i+2]  != 0x59 || (code[i+3] & 0xc7)  != 5 ||
           code[i+8] != 0xf2 || code[i+9] != 0x0f || code[i+10] != 0x59 || (code[i+11] & 0xc7) != 5 continue;
        print("Adjacent mulsd at RVA 0x% (dump offset 0x%):\n", formatInt(rva + cast(u64) i, base = 16), formatInt(i, base = 16));
        for at: i..min(i + 79, code.count - 1) print("% ", formatInt(code[at], base = 16, minimum_digits = 2));
        print("\n");
    }
    // Candidate 1x-default initialization copies: movaps load, 16-byte rip
    // store, and the stack lea that sat beside the supported forms.
    for i: 0..code.count - 22 {
        if code[i] != 0x0f || code[i+1] != 0x28 || code[i+2] != 0x05 ||
           code[i+7] != 0x0f || (code[i+8] != 0x11 && code[i+8] != 0x29) || code[i+9] != 0x05 ||
           code[i+14] != 0x4c || code[i+15] != 0x8d || code[i+16] != 0xa4 || code[i+17] != 0x24 continue;
        print("Init candidate at RVA 0x% (store opcode 0f %):\n",
              formatInt(rva + cast(u64) i, base = 16), formatInt(code[i+8], base = 16, minimum_digits = 2));
        for at: i..min(i + 31, code.count - 1) print("% ", formatInt(code[at], base = 16, minimum_digits = 2));
        print("\n");
    }
    return "";
}

#import "Basic";
#import "Compiler";
#import "File";
App :: #import,file "../src/main.jai";
