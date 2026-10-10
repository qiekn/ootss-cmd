#!/usr/bin/env jai

// Conservative project formatting: align adjacent declarations/assignments.
// No expression rewriting. Keep strings, comments and escaped identifiers intact.
// Run without arguments to check, or with - --write to apply to first.jai/src/scripts.
#run {
    set_build_options_dc(.{do_output=false});
    set_working_directory(tprint("%/..",#filepath));
    args := get_build_options().compile_time_command_line;
    if args.count>1 || (args.count==1 && args[0]!="--write") compiler_report("Usage: format_style.jai [- --write]");
    else {
        state: Style_Run;
        state.write = args.count==1;
        style_file("first.jai",*state);
        for directory: string.["src","scripts"] {
            if !visit_files(directory,true,*state,style_visit,visit_symlinks=false,follow_directory_symlinks=false)
                state.failed = true;
        }
        print("Style: % files checked, % changed, % duplicate imports removed (%).\n",
              state.files,state.changed,state.imports,ifx state.write then "write" else "check");
        if state.failed || (!state.write && state.changed) compiler_report("Style check failed; run with - --write to apply formatting.");
    }
}

Style_Run  :: struct { write,failed: bool; files,changed,imports: s64; }
Style_Line :: struct {
    original,left,op,right: string;
    indent:                 s64;
    candidate:              bool;
    literal:                bool;
}

style_visit :: (info: *File_Visit_Info, state: *Style_Run) {
    if !info.is_directory && ends_with(info.short_name,".jai") style_file(info.full_name,state);
}

style_file :: (filename: string, state: *Style_Run) {
    auto_release_temp();
    source,ok := read_entire_file(filename);
    if !ok { state.failed=true; return; }
    defer free(source);
    state.files+=1;
    lines: [..] Style_Line;
    defer array_free(lines);
    raw_end: string;
    start:   s64;
    for end:0..source.count {
        if end<source.count && source[end]!=10 continue;
        line := slice(source,start,end-start);
        start = end+1;
        if ends_with(line,"\r") line.count-=1;
        row: Style_Line=.{original=line};
        if raw_end.count {
            row.literal = true;
            if trim(line)==raw_end raw_end="";
        } else {
            row = style_line(line);
            if row.candidate && begins_with(row.right,"#string ") {
                raw_end = trim(slice(row.right,8,row.right.count-8));
            }
        }
        array_add(*lines,row);
    }
    cleaned: [..] Style_Line;
    defer array_free(cleaned);
    for row:lines {
        if !row.literal && style_duplicate_import(filename,trim(row.original)) { state.imports+=1; continue; }
        array_add(*cleaned,row);
    }
    // An empty file-local tail no longer declares anything.
    last := cleaned.count-1;
    while last>=0 && !trim(cleaned[last].original).count last-=1;
    if last>=0 && trim(cleaned[last].original)=="#scope_file" {
        cleaned.count = last;
        while cleaned.count && !trim(cleaned[cleaned.count-1].original).count cleaned.count-=1;
        array_add(*cleaned,.{});
    }
    builder: String_Builder;
    defer free_buffers(*builder);
    newline := ifx contains(source,"\r\n") then "\r\n" else "\n";
    i: s64;
    while i<cleaned.count {
        row   := cleaned[i];
        end   := i+1;
        width := row.left.count;
        if row.candidate {
            while end<cleaned.count && cleaned[end].candidate && cleaned[end].op==row.op && cleaned[end].indent==row.indent {
                width = max(width,cleaned[end].left.count);
                end+=1;
            }
        }
        for j:i..end-1 {
            item := cleaned[j];
            if item.candidate {
                append(*builder,slice(item.original,0,item.indent));
                append(*builder,item.left);
                if item.op==":" {
                    append(*builder,":");
                    style_spaces(*builder,width-item.left.count+1);
                } else {
                    style_spaces(*builder,width-item.left.count+1);
                    append(*builder,item.op);
                    append(*builder," ");
                }
                append(*builder,item.right);
            } else append(*builder,ifx item.literal then item.original else style_section(item.original));
            if j<cleaned.count-1 append(*builder,newline);
        }
        i = end;
    }
    result := builder_to_string(*builder);
    defer free(result);
    if source==result return;
    state.changed+=1;
    if state.write && !write_entire_file(filename,result) state.failed=true;
    print("  %\n",filename);
}

style_spaces :: (builder: *String_Builder, count: s64) {
    for i:0..count-1 append(builder," ");
}

style_line :: (source: string) -> Style_Line {
    row: Style_Line=.{original=source};
    while row.indent<source.count && source[row.indent]==32 row.indent+=1;
    text := slice(source,row.indent,source.count-row.indent);
    at   := find_index_of_any_from_left(text,":=");
    if at<=0 return row;
    left := trim(slice(text,0,at));
    // Only identifier/member lists. In particular preserve backslash identifiers,
    // control-flow statements, parameter lists and expressions verbatim.
    if !style_names(left) return row;
    length: s64=1;
    if text[at]==#char ":" && at+1<text.count && (text[at+1]==#char ":" || text[at+1]==#char "=") length=2;
    if text[at]==#char "=" && at+1<text.count && text[at+1]==#char "=" return row;
    row.left      = left;
    row.op        = slice(text,at,length);
    row.right     = trim_left(slice(text,at+length,text.count-at-length));
    row.candidate = row.right.count>0;
    return row;
}

style_names :: (source: string) -> bool {
    expect_name := true;
    space       := false;
    for c:source {
        if c==32 || c==9 { if !expect_name space=true; continue; }
        if c==#char "," {
            if expect_name return false;
            expect_name = true; space=false; continue;
        }
        if c==#char "." {
            if expect_name || space return false;
            expect_name = true; continue;
        }
        letter := (c>=#char "a" && c<=#char "z") || (c>=#char "A" && c<=#char "Z") || c==#char "_";
        if !letter && (expect_name || c<#char "0" || c>#char "9") return false;
        if space return false;
        expect_name = false;
    }
    return !expect_name;
}

style_section :: (line: string) -> string {
    text := trim_left(line);
    if !begins_with(text,"// --") return line;
    colon := find_index_from_left(text,":");
    if colon<0 return line;
    for c:slice(text,3,colon-3) if c!=#char "-" && c!=32 return line;
    label := trim(slice(text,colon+1,text.count-colon-1));
    return tprint("// ----------------------------------------------------------------------------: %",label);
}

style_duplicate_import :: (filename: string, line: string) -> bool {
    // These shared files also compile as independent modules or script fragments.
    if !(begins_with(filename,"src/") || begins_with(filename,"src\\")) ||
       ends_with(filename,"main.jai") || ends_with(filename,"process.jai") ||
       ends_with(filename,"fog_memory.jai") || ends_with(filename,"capture_plan.jai") || ends_with(filename,"capture_image.jai") return false;
    for module:string.["Basic","String","System","Math","Windows_Utf8","File","File_Utilities"]
        if line==tprint("#import \"%\";",module) return true;
    for item:string.["Win","Input","Simp","Json"] {
        module := ifx item=="Win" then "Windows" else item;
        row    := style_line(line);
        if row.candidate && row.left==item && row.op=="::" && row.right==tprint("#import \"%\";",module) return true;
    }
    return false;
}

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
#import "System";
