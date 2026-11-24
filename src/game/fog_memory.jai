// A session owns only its own 1 -> 0 change. The executable on disk is untouched.
Fog_Session :: struct {
    memory:             Process.Process_Memory;
    instruction:        u64;
    metadata, upload:   u64;
    code:               [40] u8;
    upload_code:        [43] u8;
    parameter_address:  u64;
    parameter_code:     [1024] u8;
    parameter_count:    s64;
    writable:           bool;
    changed:            bool;
    protection_pending: bool;
    protection:         u32;
}

fog_session_exited :: (session: *Fog_Session) -> bool {
    return Process.process_memory_has_exited(session.memory);
}

fog_session_open :: (session: *Fog_Session, window: Win.HWND, writable := true) -> string {
    if session.memory.handle return "A fog session is already open.";
    memory, error := Process.process_open_memory(window, "sinking_star.exe", writable=writable);
    if error.count return error;
    keep := false;
    defer if !keep Process.process_close_memory(*memory);
    code, rva, code_error := Process.process_read_module_code(memory);
    defer free(code.data);
    if code_error.count return code_error;
    offset := fog_find_instruction(code);
    if offset < 0 return "Unsupported game build: fog instruction is missing or ambiguous.";
    metadata := fog_find_metadata(memory);
    if !metadata return "Fog layout: parameter metadata is missing, ambiguous or differs.";
    // Verify that this stack block is uploaded as the complete 480-byte params.
    address       := memory.module.base + rva + cast(u64) offset;
    upload_offset := fog_find_upload(code,offset);
    if upload_offset<0 return "Fog layout: nearby parameter upload is missing or ambiguous.";
    // The uploaded Fog_Voxelization_Params and the flag's stack slot must agree:
    // the flag displacement sits exactly at the struct's 0x184 field offset.
    parameter_start, parameter_count := fog_parameter_source(code, offset, upload_offset);
    if parameter_start < 0 return "Fog layout: parameter pointer branches and upload disagree.";
    session.* = .{memory=memory, instruction=address, metadata=metadata,
                  upload = memory.module.base+rva+cast(u64)upload_offset, writable=writable};
    for byte: session.code session.code[it_index]=code[offset+it_index];
    for byte: session.upload_code session.upload_code[it_index]=code[upload_offset+it_index];
    session.parameter_address = memory.module.base + rva + cast(u64) parameter_start;
    session.parameter_count   = parameter_count;
    for i: 0..parameter_count-1 session.parameter_code[i] = code[parameter_start+i];
    keep = true;
    return "";
}

// Read-only capability check. The returned message uses temporary storage.
fog_inspect :: (window: Win.HWND) -> (description: string, error: string) {
    session: Fog_Session;
    error := fog_session_open(*session,window,writable=false);
    if error.count return "",error;
    defer fog_session_close(*session);
    value,read_error := fog_session_read(*session);
    if read_error.count return "",read_error;
    return tprint("enabled=%, instruction RVA=0x%, metadata RVA=0x%, upload RVA=0x%",value,
        formatInt(session.instruction-session.memory.module.base,base=16),
        formatInt(session.metadata-session.memory.module.base,base=16),
        formatInt(session.upload-session.memory.module.base,base=16)),"";
}

fog_session_disable :: (session: *Fog_Session) -> string {
    value, error := fog_session_read(session);
    if error.count return error;
    if value == 0 return "";
    // Mark ownership before writing, so an OS error still takes the restore path.
    session.changed = true;
    return fog_session_write(session, 0);
}

// On failure retain the process handle and ownership so restoration can be retried.
fog_session_close :: (session: *Fog_Session) -> string {
    if !session.memory.handle return "";
    if !Process.process_memory_has_exited(session.memory) {
        if session.changed {
            value, error := fog_session_read(session);
            if error.count return error;
            if value == 0 {
                error = fog_session_write(session, 1);
                if error.count return error;
            }
        }
        if session.protection_pending && !fog_restore_protection(session)
            return "Could not restore the fog code page protection; retry fog.";
    }
    Process.process_close_memory(*session.memory);
    session.* = .{};
    return "";
}

fog_session_read :: (session: *Fog_Session) -> (value: u8, error: string) {
    bytes: [FOG_INSTRUCTION.count] u8;
    if !session.memory.handle ||
       !Process.process_read_memory(session.memory.handle, session.instruction, *bytes, bytes.count) ||
       !fog_instruction_matches(bytes) return 0, "Fog code changed or became unreadable; no bytes overwritten.";
    for byte: session.code if it_index!=FOG_IMMEDIATE && byte!=bytes[it_index]
        return 0,"Fog instruction evidence changed; no bytes overwritten.";
    if session.upload {
        upload: [43] u8;
        if !Process.process_read_memory(session.memory.handle,session.upload,*upload,upload.count)
            return 0,"Fog upload evidence became unreadable.";
        for byte: session.upload_code if byte!=upload[it_index] return 0,"Fog upload evidence changed; no bytes overwritten.";
    }
    if session.parameter_address {
        parameters: [1024] u8;
        if session.parameter_count <= 0 || session.parameter_count > parameters.count ||
           !Process.process_read_memory(session.memory.handle, session.parameter_address, *parameters, cast(u64) session.parameter_count)
            return 0,"Fog parameter pointer evidence became unreadable.";
        for i: 0..session.parameter_count-1 if parameters[i] != session.parameter_code[i]
            return 0,"Fog parameter pointer evidence changed; no bytes overwritten.";
    }
    return bytes[FOG_IMMEDIATE], "";
}

fog_session_write :: (session: *Fog_Session, value: u8) -> string {
    if !session.writable return "This fog session is read-only.";
    if value > 1 return "Invalid fog switch value.";
    current, error := fog_session_read(session);
    if error.count return error;
    if session.protection_pending && !fog_restore_protection(session)
        return "Could not restore the fog code page protection.";
    address := session.instruction + FOG_IMMEDIATE;
    if !VirtualProtectEx(session.memory.handle, cast(*void) address, 1, Win.PAGE_EXECUTE_READWRITE, *session.protection)
        return "Could not make the fog instruction writable.";
    session.protection_pending = true;
    written_ok, written  := Process.process_write_memory(session.memory.handle, address, *value, 1);
    flushed              := FlushInstructionCache(session.memory.handle, cast(*void) address, 1) != 0;
    protected            := fog_restore_protection(session);
    observed, read_error := fog_session_read(session);
    if !protected return "Could not restore fog page protection; retry fog.";
    if !written_ok || !flushed || read_error.count || observed != value
        return "Could not write and verify the fog switch; restoration is required.";
    return "";
}

fog_restore_protection :: (session: *Fog_Session) -> bool {
    previous: u32;
    if !VirtualProtectEx(session.memory.handle, cast(*void)(session.instruction + FOG_IMMEDIATE), 1,
                        session.protection, *previous) return false;
    session.protection_pending = false;
    return true;
}

fog_instruction_matches :: (bytes: [] u8) -> bool {
    if bytes.count != FOG_INSTRUCTION.count return false;
    for byte: FOG_INSTRUCTION {
        if byte < 0 continue; // A stack displacement, checked below.
        if it_index == FOG_IMMEDIATE { if bytes[it_index] > 1 return false; }
        else if bytes[it_index] != byte return false;
    }
    stack  := (cast(*u32)(bytes.data+7)).*;
    mirror := (cast(*u32)(bytes.data+29)).*;
    if stack<0x20 || stack>0x4000 || stack%4!=0 return false; // A dword store keeps 4-byte alignment.
    return mirror == stack + 8;
}

// The fixed first bytes of FOG_INSTRUCTION drive the pre-scan.
FOG_INSTRUCTION_FIRST: u8 = 0xf3;
fog_find_instruction :: (code: [] u8) -> s64 {
    found: s64 = -1;
    if code.count < FOG_INSTRUCTION.count return -1;
    source: string = .{data=code.data, count=code.count};
    cursor: s64;
    while cursor <= code.count - FOG_INSTRUCTION.count {
        i := find_index_from_left(source, FOG_INSTRUCTION_FIRST, cursor);
        if i < 0 || i > code.count - FOG_INSTRUCTION.count break;
        cursor = i + 1;
        if code[i+1] != 0x0f || code[i+2] != 0x5d continue;
        if !fog_instruction_matches(.{data=code.data+i, count=FOG_INSTRUCTION.count}) continue;
        if found >= 0 return -1;
        found = i;
    }
    return found;
}

fog_upload_matches :: (bytes: [] u8) -> bool {
    if bytes.count != FOG_UPLOAD.count return false;
    for byte: FOG_UPLOAD {
        if byte < 0 continue; // RIP-relative addresses vary.
        if bytes[it_index] != byte return false;
    }
    return true;
}

fog_find_upload :: (code: [] u8, instruction: s64) -> s64 {
    if instruction<0 || code.count<FOG_UPLOAD.count || instruction>code.count-FOG_UPLOAD.count return -1;
    found: s64=-1;
    for at: instruction..min(code.count-FOG_UPLOAD.count,instruction+0x4000) {
        if code[at]!=0x4c || code[at+1]!=0x89 continue; // FOG_UPLOAD's fixed first bytes.
        if !fog_upload_matches(.{data=code.data+at,count=FOG_UPLOAD.count}) continue;
        if found>=0 return -1;
        found = at;
    }
    return found;
}

// In the 2026-11-24 build the params pointer is kept in r9 through four
// floating-point conversion branches. All four producers must select the same
// reflected stack block, and both the immediate and deferred uploads use r9.
// Retain the entire intervening code, including branches, until restoration.
fog_parameter_source :: (code: [] u8, instruction: s64, upload: s64) -> (start: s64, count: s64) {
    start := upload - 0x395;
    count := 0x395 + FOG_UPLOAD.count;
    if instruction < 0 || instruction > code.count-FOG_INSTRUCTION.count || start <= instruction ||
       !fog_instruction_matches(.{data=code.data+instruction,count=FOG_INSTRUCTION.count}) ||
       !fog_code_matches(code, upload, FOG_UPLOAD) || start < 0 || start > code.count - count return -1,0;
    stack     := (cast(*u32)(code.data+instruction+7)).*;
    producers := s64.[upload-0x395, upload-0x287, upload-0x24c, upload-0x1ea];
    for at: producers {
        if !fog_code_matches(code, at, s16.[0x4c,0x8d,0x8c,0x24,-1,-1,-1,-1]) return -1,0;
        displacement := (cast(*u32)(code.data+at+4)).*;
        if displacement < 0x20 || displacement > 0x4000 || displacement%8 || displacement + 0x184 != stack return -1,0;
    }
    if !fog_code_matches(code, producers[0]+8, s16.[0x84,0xdb,0x0f,0x85,-1,-1,-1,-1,
           0xf3,0x41,0x0f,0x10,0x0c,0x24,0xe9,-1,-1,-1,-1]) ||
       !fog_code_matches(code, producers[1]+8, s16.[0xf3,0x0f,0x5e,0xc1,0x84,0xdb,0x0f,0x85,-1,-1,-1,-1,0xe9,-1,-1,-1,-1]) ||
       !fog_code_matches(code, producers[2]+8, s16.[0x0f,0x85,-1,-1,-1,-1]) ||
       !fog_code_matches(code, producers[3]+8, s16.[0x75,0x06,0x0f,0x8b,-1,-1,-1,-1]) ||
       fog_branch_target(code, producers[0]+12) != upload-0xae ||
       fog_branch_target(code, producers[0]+23) != upload-0xa6 ||
       fog_branch_target(code, producers[1]+16) != upload-0xae ||
       fog_branch_target(code, producers[1]+21) != producers[0]+16 ||
       fog_branch_target(code, producers[2]+10) != upload-0xba ||
       fog_branch_target(code, producers[3]+12) != upload-0xef return -1,0;
    // je selects the direct upload; the other branch records the same pointer
    // and 480-byte size in the renderer's deferred upload arrays.
    if !fog_code_matches(code, upload-0x60, s16.[0x80,0x3d,-1,-1,-1,-1,0,0x74,0x57]) ||
       !fog_code_matches(code, upload-0x57, s16.[0x48,0x8b,0x84,0x24,-1,-1,-1,-1]) ||
       !fog_code_matches(code, upload-0x4f, s16.[
           0x48,0x8d,0x0d,-1,-1,-1,-1,0x48,0x89,0x8c,0xc4,-1,-1,-1,-1,
           0x48,0x8b,0x84,0x24,-1,-1,-1,-1,0xc7,0x84,0x84,-1,-1,-1,-1,0,0,0,0,
           0x48,0x8b,0x84,0x24,-1,-1,-1,-1,0xc7,0x84,0x84,-1,-1,-1,-1,0xe0,1,0,0,
           0x48,0x8b,0x84,0x24,-1,-1,-1,-1,0x4c,0x89,0x8c,0xc4,-1,-1,-1,-1,
           0x48,0xff,0x84,0x24,-1,-1,-1,-1,0xeb,0x2b]) ||
       fog_branch_target(code, upload-0x4f+3) != fog_branch_target(code, upload+25) return -1,0;
    batch  := code.data + upload - 0x4f;
    cursor := (cast(*u32)(batch+19)).*;
    buffer := (cast(*u32)(batch+11)).*;
    if cursor < 0x20 || cursor > 0x4000 || cursor%8 || buffer != cursor+8 ||
       (cast(*u32)(code.data+upload-0x53)).* != cursor ||
       (cast(*u32)(batch+38)).* != cursor || (cast(*u32)(batch+57)).* != cursor ||
       (cast(*u32)(batch+73)).* != cursor ||
       (cast(*u32)(batch+26)).* != buffer+0x400 || (cast(*u32)(batch+45)).* != buffer+0x600 ||
       (cast(*u32)(batch+65)).* != buffer+0x800 return -1,0;
    return start,count;
}

fog_code_matches :: (code: [] u8, at: s64, pattern: [] s16) -> bool {
    if at < 0 || pattern.count > code.count || at > code.count-pattern.count return false;
    for byte: pattern if byte >= 0 && code[at+it_index] != byte return false;
    return true;
}

// Displacement offsets are used only after their complete instruction matches.
fog_branch_target :: (code: [] u8, displacement: s64) -> s64 {
    return displacement + 4 + (cast(*s32)(code.data+displacement)).*;
}

#scope_file
// Discover relocated RTTI by its structure and exact name, not a build RVA.
fog_find_metadata :: (memory: Process.Process_Memory) -> u64 {
    bytes,rva,error := Process.process_read_module_section(memory,".rdata\0\0",0x40000000);
    defer free(bytes.data);
    if error.count || bytes.count<0x50 return 0;
    found: u64;
    for i: 0..(bytes.count-0x50)/8 {
        owner := cast(*Fog_Type)(bytes.data+i*8);
        if owner.kind!=7 || owner.size!=0x1e0 || owner.name.count!="Fog_Voxelization_Params".count continue;
        at := memory.module.base+rva+cast(u64)i*8;
        if !fog_validate_metadata(memory,at) continue;
        if found return 0;
        found = at;
    }
    return found;
}

fog_validate_metadata :: (memory: Process.Process_Memory, at: u64) -> bool {
    owner: Fog_Type;
    if !Process.process_module_contains(memory.module, at, 0x50) ||
       !Process.process_read_memory(memory.handle, at, *owner, size_of(Fog_Type)) ||
       owner.kind != 7 || owner.size != 0x1e0 ||
       !fog_name_equals(memory, owner.name, "Fog_Voxelization_Params") return false;
    members: Fog_Remote_Array;
    if !Process.process_read_memory(memory.handle, at+0x40, *members, size_of(Fog_Remote_Array)) ||
       !members.count || members.count > 128 ||
       !Process.process_module_contains(memory.module, members.data, members.count*size_of(Fog_Member)) return false;
    found := false;
    for i: 0..cast(s64) members.count-1 {
        member: Fog_Member;
        if !Process.process_read_memory(memory.handle, members.data+cast(u64)i*size_of(Fog_Member), *member, size_of(Fog_Member)) return false;
        if !fog_name_equals(memory, member.name, "fog_of_war_enabled") continue;
        if found || member.offset != 0x184 || member.flags != 0 return false;
        child: Fog_Type;
        if !Process.process_module_contains(memory.module, member.type, size_of(Fog_Type)) ||
           !Process.process_read_memory(memory.handle, member.type, *child, size_of(Fog_Type)) ||
           child.kind != 0 || child.size != 4 return false;
        found = true;
    }
    return found;
}

fog_name_equals :: (memory: Process.Process_Memory, remote: Fog_Remote_Array, expected: string) -> bool {
    bytes: [128] u8;
    if remote.count != cast(u64) expected.count || remote.count > bytes.count ||
       !Process.process_module_contains(memory.module, remote.data, remote.count) ||
       !Process.process_read_memory(memory.handle, remote.data, *bytes, remote.count) return false;
    for byte: expected if bytes[it_index] != byte return false;
    return true;
}

Fog_Remote_Array :: struct { count, data: u64; }
Fog_Type         :: struct { kind, id, size, padding: u32; name: Fog_Remote_Array; }
Fog_Member       :: struct {
    name:            Fog_Remote_Array;
    type:            u64;
    offset:          s64;
    flags, padding:  u32;
    notes:           Fog_Remote_Array;
    constant_offset: s64;
}
#assert(size_of(Fog_Type) == 32);
#assert(size_of(Fog_Member) == 64);
FOG_IMMEDIATE :: 11;
// The 2026-11-24 build keeps the fog settings in r14 rather than reloading a
// stack pointer. Displacements still vary; their typed relationships are checked.
FOG_INSTRUCTION :: s16.[0xf3,0x0f,0x5d,0xc1, 0xc7,0x84,0x24,-1,-1,-1,-1, 1,0,0,0,
    0xf3,0x41,0x0f,0x10,0x8e,0x3c,0x03,0,0,
    0xf3,0x0f,0x11,0x8c,0x24,-1,-1,-1,-1,0x49,0x8d,0x86,0x30,0x03,0,0];
FOG_UPLOAD :: s16.[0x4c,0x89,0x4c,0x24,0x20,
    0xc6,0x44,0x24,0x30,0, 0xc6,0x44,0x24,0x28,0,
    0x48,0x8d,0x0d,-1,-1,-1,-1, 0x48,0x8d,0x15,-1,-1,-1,-1,
    0x45,0x31,0xc0, 0x41,0xb9,0xe0,0x01,0,0, 0xe8,-1,-1,-1,-1];

#import "Basic";
#import "String";
Process               :: #import,file "../platform/windows/process.jai";
Win                   :: #import "Windows";
kernel32              :: #library,system "kernel32";
VirtualProtectEx      :: (process: Win.HANDLE, address: *void, bytes: u64, protection: u32, previous: *u32) -> s32 #foreign kernel32;
FlushInstructionCache :: (process: Win.HANDLE, address: *void, bytes: u64) -> s32 #foreign kernel32;
