Subtitle_Line :: struct {
    text: string;
    comment: bool;
}

Subtitle_Cue :: struct {
    speaker: string;
    lines: [..] Subtitle_Line;
}

Subtitle_Section :: struct {
    name: string;
    cues: [..] Subtitle_Cue;
}

Subtitle_File :: struct {
    // Names and lines borrow slices of this owned UTF-8 buffer.
    source: string;
    sections: [..] Subtitle_Section;
}

Subtitles_Catalog :: struct {
    english, chinese: Subtitle_File;
    mapping: Subtitles_Mapping;
}

Subtitle_Block :: struct {
    section: string; // A nonempty name introduces a section; otherwise this is a dialogue block.
    english, chinese: [] Subtitle_Cue;
}

subtitles_parse :: (file: *Subtitle_File, source: string) -> string {
    subtitles_file_free(file);
    file.source = copy_string(source);
    text := file.source;
    if text.count >= 3 && text[0] == 0xef && text[1] == 0xbb && text[2] == 0xbf {
        text = slice(text, 3, text.count - 3);
    }
    lines := split(text, #char "\n");
    defer array_free(lines);
    section: s64 = -1;
    cue: s64 = -1;
    for raw: lines {
        line := trim(raw);
        if line.count && line[0] == #char ":" {
            start: s64;
            while start < line.count && line[start] == #char ":" start += 1;
            name := trim(slice(line, start, line.count - start));
            if !name.count return tprint("Subtitle section at line % has no name.", it_index + 1);
            section = subtitles_find_section(file, name);
            if section < 0 {
                array_add(*file.sections, .{name = name});
                section = file.sections.count - 1;
            }
            cue = -1;
            continue;
        }
        if section < 0 continue; // The [1] format version is not dialogue.
        if line.count && line[0] == #char "=" {
            cue = -1;
            header := trim(slice(line, 1, line.count - 1));
            end: s64;
            while end < header.count && header[end] != #char " " && header[end] != #char "\t" end += 1;
            speaker := slice(header, 0, end);
            // '_' is a timing-only clear event; timestamps are intentionally not parsed.
            if !speaker.count || speaker == "_" continue;
            array_add(*file.sections[section].cues, .{speaker = speaker});
            cue = file.sections[section].cues.count - 1;
            continue;
        }
        if cue < 0 continue;
        output := *file.sections[section].cues[cue].lines;
        comment := find_index_from_left(line, "++");
        if comment >= 0 {
            dialogue := trim(slice(line, 0, comment));
            if dialogue.count array_add(output, .{text = dialogue});
            note := trim(slice(line, comment + 2, line.count - comment - 2));
            if note.count array_add(output, .{text = note, comment = true});
        } else if line.count || output.count {
            array_add(output, .{text = line});
        }
    }
    for *entry: file.sections {
        index: s64;
        while index < entry.cues.count {
            current := *entry.cues[index];
            while current.lines.count && !current.lines[current.lines.count - 1].text.count {
                current.lines.count -= 1;
            }
            if !current.lines.count {
                array_free(current.lines);
                array_ordered_remove_by_index(*entry.cues, index);
            } else index += 1;
        }
    }
    if !file.sections.count return "No subtitle sections were found.";
    return "";
}

subtitles_find_section :: (file: *Subtitle_File, name: string) -> s64 {
    for section: file.sections if equal_nocase(section.name, name) return it_index;
    return -1;
}

subtitles_section_matches :: (section: string, level: string) -> bool {
    if !level.count || section.count < level.count return false;
    if !equal_nocase(slice(section, 0, level.count), level) return false;
    return section.count == level.count || subtitles_phase_suffix(slice(section, level.count, section.count - level.count));
}

subtitles_level_name :: (section: string) -> string {
    // Also group variants such as _mid0, _mid2, and _mid_warrior with their level.
    for offset: 1..section.count-1 {
        if section[offset] == #char "_" && subtitles_phase_suffix(slice(section, offset, section.count - offset)) {
            return slice(section, 0, offset);
        }
    }
    return section;
}

subtitles_collect_names :: (catalog: *Subtitles_Catalog, names: *[..] string) {
    for level: catalog.mapping.levels {
        for name: level.subtitle_names {
            if subtitles_find_section(*catalog.english, name) >= 0 || subtitles_find_section(*catalog.chinese, name) >= 0 {
                subtitles_add_name(names, level.level_name);
                break;
            }
        }
    }
    for file: *Subtitle_File.[*catalog.english, *catalog.chinese] {
        for section: file.sections {
            // Offer real level names for mapped IDs; keep direct lookup for unassigned subtitle groups.
            if subtitles_mapping_has_subtitle(*catalog.mapping, section.name) continue;
            name := subtitles_level_name(section.name);
            if subtitles_mapping_find_level(*catalog.mapping, name) continue;
            subtitles_add_name(names, name);
        }
    }
}

subtitles_catalog_load :: (catalog: *Subtitles_Catalog, directory: string, load_english := true, load_chinese := true, mapping_file := "") -> string {
    next: Subtitles_Catalog;
    defer subtitles_catalog_free(*next);
    if mapping_file.count {
        error := subtitles_mapping_load(*next.mapping, mapping_file);
        if error.count return error;
    }
    if load_english {
        path := tprint("%/en.subtitles", directory);
        source, ok := read_entire_file(path, log_errors = false);
        defer free(source);
        if !ok return tprint("Could not read %.", path);
        error := subtitles_parse(*next.english, source);
        if error.count return tprint("%: %", path, error);
    }
    if load_chinese {
        path: string;
        for name: string.["s-cn.subtitles", "ch.subtitles", "ch-subtitles"] {
            candidate := tprint("%/%", directory, name);
            if file_exists(candidate) { path = candidate; break; }
        }
        if !path.count return tprint("No Chinese subtitles found in % (expected s-cn.subtitles).", directory);
        source, ok := read_entire_file(path, log_errors = false);
        defer free(source);
        if !ok return tprint("Could not read %.", path);
        error := subtitles_parse(*next.chinese, source);
        if error.count return tprint("%: %", path, error);
    }
    subtitles_catalog_free(catalog);
    catalog.* = next;
    next = .{};
    return "";
}

subtitles_select :: (catalog: *Subtitles_Catalog, level: string, blocks: *[..] Subtitle_Block) -> bool {
    blocks.count = 0;
    mapped := subtitles_mapping_find_level(*catalog.mapping, level);
    for *section: catalog.english.sections {
        if !subtitles_selection_matches(mapped, section.name, level) continue;
        index := subtitles_find_section(*catalog.chinese, section.name);
        chinese: *Subtitle_Section;
        if index >= 0 chinese = *catalog.chinese.sections[index];
        subtitles_pair_section(section, chinese, blocks);
    }
    for *section: catalog.chinese.sections {
        if !subtitles_selection_matches(mapped, section.name, level) continue;
        if subtitles_find_section(*catalog.english, section.name) >= 0 continue;
        subtitles_pair_section(null, section, blocks);
    }
    return blocks.count > 0;
}

subtitles_file_free :: (file: *Subtitle_File) {
    for *section: file.sections {
        for *cue: section.cues array_free(cue.lines);
        array_free(section.cues);
    }
    array_free(file.sections);
    free(file.source);
    file.* = .{};
}

subtitles_catalog_free :: (catalog: *Subtitles_Catalog) {
    subtitles_file_free(*catalog.english);
    subtitles_file_free(*catalog.chinese);
    subtitles_mapping_free(*catalog.mapping);
}

#scope_file
#import "Basic";
#import "String";
#import "File";

subtitles_add_name :: (names: *[..] string, name: string) {
    for previous: names.* if equal_nocase(previous, name) return;
    array_add(names, name);
}

subtitles_selection_matches :: (mapped: *Subtitle_Level_Mapping, section: string, requested: string) -> bool {
    // A known level's exact references are authoritative, including an empty list.
    if mapped return subtitles_mapping_contains(mapped, section);
    return subtitles_section_matches(section, requested);
}

subtitles_phase_suffix :: (suffix: string) -> bool {
    for phase: string.["_start", "_mid", "_end"] {
        if suffix.count < phase.count || !equal_nocase(slice(suffix, 0, phase.count), phase) continue;
        if suffix.count == phase.count || suffix[phase.count] == #char "_" ||
           (suffix[phase.count] >= #char "0" && suffix[phase.count] <= #char "9") return true;
    }
    return false;
}

Subtitle_Turn :: struct {
    speaker: string;
    cues: [] Subtitle_Cue;
}

subtitles_turns :: (section: *Subtitle_Section) -> [..] Subtitle_Turn {
    turns: [..] Subtitle_Turn;
    if !section return turns;
    start: s64;
    while start < section.cues.count {
        end := start + 1;
        while end < section.cues.count && equal_nocase(section.cues[end].speaker, section.cues[start].speaker) {
            end += 1;
        }
        array_add(*turns, .{section.cues[start].speaker, .{data = section.cues.data + start, count = end - start}});
        start = end;
    }
    return turns;
}

subtitles_pair_section :: (english: *Subtitle_Section, chinese: *Subtitle_Section, blocks: *[..] Subtitle_Block) {
    array_add(blocks, .{section = ifx english then english.name else chinese.name});
    en := subtitles_turns(english);
    zh := subtitles_turns(chinese);
    defer array_free(en);
    defer array_free(zh);

    // Align speaker turns, not timestamps: translations have different timings and sometimes split cues.
    // Within equal-length turns each cue aligns separately. Unequal turns remain together without lost text.
    stride := zh.count + 1;
    matches := NewArray((en.count + 1) * stride, s64);
    defer array_free(matches);
    e := en.count - 1;
    while e >= 0 {
        c := zh.count - 1;
        while c >= 0 {
            if equal_nocase(en[e].speaker, zh[c].speaker) {
                matches[e * stride + c] = matches[(e + 1) * stride + c + 1] + 1;
            } else {
                matches[e * stride + c] = max(matches[(e + 1) * stride + c], matches[e * stride + c + 1]);
            }
            c -= 1;
        }
        e -= 1;
    }
    e = 0;
    c: s64;
    while e < en.count || c < zh.count {
        if e < en.count && c < zh.count && equal_nocase(en[e].speaker, zh[c].speaker) {
            if en[e].cues.count == zh[c].cues.count {
                for index: 0..en[e].cues.count-1 {
                    array_add(blocks, .{english = .{data = en[e].cues.data + index, count = 1},
                                        chinese = .{data = zh[c].cues.data + index, count = 1}});
                }
            } else array_add(blocks, .{english = en[e].cues, chinese = zh[c].cues});
            e += 1;
            c += 1;
        } else if e < en.count && (c == zh.count || matches[(e + 1) * stride + c] >= matches[e * stride + c + 1]) {
            array_add(blocks, .{english = en[e].cues});
            e += 1;
        } else {
            array_add(blocks, .{chinese = zh[c].cues});
            c += 1;
        }
    }
}
