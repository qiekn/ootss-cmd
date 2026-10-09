// A session owns only its own 1 -> 0 change. The executable on disk is untouched.
Fog_Session :: struct {
    memory: Process.Process_Memory;
    instruction: u64;
    metadata, upload: u64;
    code: [40] u8;
    upload_code: [47] u8;
    writable: bool;
    changed: bool;
    protection_pending: bool;
    protection: u32;
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
    address := memory.module.base + rva + cast(u64) offset;
    upload_offset := fog_find_upload(code,offset);
    if upload_offset<0 return "Fog layout: nearby parameter upload is missing or ambiguous.";
    session.* = .{memory=memory, instruction=address, metadata=metadata,
                  upload=memory.module.base+rva+cast(u64)upload_offset, writable=writable};
    for byte: session.code session.code[it_index]=code[offset+it_index];
    for byte: session.upload_code session.upload_code[it_index]=code[upload_offset+it_index];
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
        upload: [47] u8;
        if !Process.process_read_memory(session.memory.handle,session.upload,*upload,upload.count)
            return 0,"Fog upload evidence became unreadable.";
        for byte: session.upload_code if byte!=upload[it_index] return 0,"Fog upload evidence changed; no bytes overwritten.";
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
    written_ok, written := Process.process_write_memory(session.memory.handle, address, *value, 1);
    flushed := FlushInstructionCache(session.memory.handle, cast(*void) address, 1) != 0;
    protected := fog_restore_protection(session);
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
        if it_index == FOG_IMMEDIATE { if bytes[it_index] > 1 return false; }
        else if it_index>=19 && it_index<=22 continue; // A compiler-selected temporary stack slot.
        else if bytes[it_index] != byte return false;
    }
    stack := (cast(*u32)(bytes.data+19)).*;
    if stack<0x20 || stack>0x4000 || stack%8!=0 return false;
    return true;
}

fog_find_instruction :: (code: [] u8) -> s64 {
    found: s64 = -1;
    if code.count < FOG_INSTRUCTION.count return -1;
    source: string = .{data=code.data, count=code.count};
    cursor: s64;
    while cursor <= code.count - FOG_INSTRUCTION.count {
        i := find_index_from_left(source, FOG_INSTRUCTION[0], cursor);
        if i < 0 || i > code.count - FOG_INSTRUCTION.count break;
        cursor = i + 1;
        if code[i+1] != FOG_INSTRUCTION[1] || code[i+2] != FOG_INSTRUCTION[2] continue;
        if !fog_instruction_matches(.{data=code.data+i, count=FOG_INSTRUCTION.count}) continue;
        if found >= 0 return -1;
        found = i;
    }
    return found;
}

fog_upload_matches :: (bytes: [] u8) -> bool {
    if bytes.count != FOG_UPLOAD.count return false;
    for byte: FOG_UPLOAD {
        // RIP-relative addresses vary with linking.
        if (it_index >= 26 && it_index <= 29) || (it_index >= 33 && it_index <= 36) continue;
        if bytes[it_index] != byte return false;
    }
    return true;
}

fog_find_upload :: (code: [] u8, instruction: s64) -> s64 {
    if instruction<0 || code.count<FOG_UPLOAD.count || instruction>code.count-FOG_UPLOAD.count return -1;
    found: s64=-1;
    for at: instruction..min(code.count-FOG_UPLOAD.count,instruction+0x4000) {
        if code[at]!=FOG_UPLOAD[0] || code[at+1]!=FOG_UPLOAD[1] continue;
        if !fog_upload_matches(.{data=code.data+at,count=FOG_UPLOAD.count}) continue;
        if found>=0 return -1;
        found=at;
    }
    return found;
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
        at:=memory.module.base+rva+cast(u64)i*8;
        if !fog_validate_metadata(memory,at) continue;
        if found return 0;
        found=at;
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
Fog_Type :: struct { kind, id, size, padding: u32; name: Fog_Remote_Array; }
Fog_Member :: struct {
    name: Fog_Remote_Array;
    type: u64;
    offset: s64;
    flags, padding: u32;
    notes: Fog_Remote_Array;
    constant_offset: s64;
}
#assert(size_of(Fog_Type) == 32);
#assert(size_of(Fog_Member) == 64);
FOG_IMMEDIATE :: 11;
FOG_INSTRUCTION :: u8.[0xf3,0x0f,0x5d,0xc1, 0xc7,0x84,0x24,0x84,0x07,0,0, 1,0,0,0,
    0x48,0x8b,0x94,0x24,0x20,0x01,0,0, 0xf3,0x0f,0x10,0x8a,0x3c,0x03,0,0,
    0xf3,0x0f,0x11,0x8c,0x24,0x8c,0x07,0,0];
FOG_UPLOAD :: u8.[0x48,0x8d,0x84,0x24,0,0x06,0,0, 0x48,0x89,0x44,0x24,0x20,
    0xc6,0x44,0x24,0x30,0, 0xc6,0x44,0x24,0x28,0,
    0x48,0x8d,0x0d,0,0,0,0, 0x48,0x8d,0x15,0,0,0,0,
    0x45,0x31,0xc0, 0x41,0xb9,0xe0,0x01,0,0, 0xe8];

#import "Basic";
#import "String";
Process :: #import,file "../platform/windows/process.jai";
Win :: #import "Windows";
kernel32 :: #library,system "kernel32";
VirtualProtectEx :: (process: Win.HANDLE, address: *void, bytes: u64, protection: u32, previous: *u32) -> s32 #foreign kernel32;
FlushInstructionCache :: (process: Win.HANDLE, address: *void, bytes: u64) -> s32 #foreign kernel32;
