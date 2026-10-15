Time_Audio_Clip :: struct {
    samples: [] s16; // Owned until shutdown, after the output device releases its buffer.
    format:  Wav.Waveformatex;
}

Time_Audio_Header :: struct {
    data:             *u8;
    length, recorded: u32;
    user:             u64;
    flags, loops:     u32;
    next:             *Time_Audio_Header;
    reserved:         u64;
}
#assert size_of(Time_Audio_Header) == 48;
#assert size_of(Wav.Waveformatex) == 18;

time_audio_clips:    [4] Time_Audio_Clip;
time_audio_device:   *void;
time_audio_header:   Time_Audio_Header;
time_audio_prepared: bool;

time_audio_filename :: (resume: bool, alternate: bool) -> string {
    if resume return ifx alternate then "data/audio/time-resume_alt.ogg" else "data/audio/time-resume.ogg";
    return ifx alternate then "data/audio/time-stop_alt.ogg" else "data/audio/time-stop.ogg";
}

time_audio_load :: (clip: *Time_Audio_Clip, filename: string) -> string {
    if clip.samples.count return "";
    data, ok := read_entire_file(filename);
    if !ok return tprint("Could not read %.", filename);
    defer free(data);
    if !data.count || data.count > 64*1024*1024 return "Invalid time audio file size.";
    code: s32;
    decoder := Vorbis.stb_vorbis_open_memory(data.data, cast(s32) data.count, *code, null);
    if !decoder return tprint("Could not decode % (Vorbis %).", filename, code);
    defer Vorbis.stb_vorbis_close(decoder);
    info   := Vorbis.stb_vorbis_get_info(decoder);
    frames := Vorbis.stb_vorbis_stream_length_in_samples(decoder);
    if info.channels < 1 || info.channels > 2 || info.sample_rate < 8000 || info.sample_rate > 192000 ||
       !frames || frames > cast(u64) info.sample_rate * 120 return "Unsupported time audio format or duration.";
    samples := NewArray(cast(s64) frames * info.channels, s16);
    decoded := Vorbis.stb_vorbis_get_samples_short_interleaved(decoder, info.channels, samples.data, cast(s32) samples.count);
    if decoded != cast(s32) frames || Vorbis.stb_vorbis_get_error(decoder) != 0 {
        free(samples.data);
        return tprint("Incomplete time audio: %.", filename);
    }
    clip.samples = samples;
    clip.format  = .{wFormatTag = 1, nChannels = cast(s16) info.channels, nSamplesPerSec = cast(s32) info.sample_rate,
                    nAvgBytesPerSec = cast(s32) info.sample_rate * info.channels * 2,
                    nBlockAlign     = cast(s16)(info.channels * 2), wBitsPerSample = 16};
    return "";
}

time_audio_stop :: () -> string {
    if !time_audio_device return "";
    // Reset discards queued samples before a replacement track can start.
    if waveOutReset(time_audio_device) != 0 return "Could not stop time audio.";
    if time_audio_prepared {
        if waveOutUnprepareHeader(time_audio_device, *time_audio_header, size_of(Time_Audio_Header)) != 0
            return "Could not release time audio buffer.";
        time_audio_prepared = false;
    }
    if waveOutClose(time_audio_device) != 0 return "Could not close time audio device.";
    time_audio_device = null;
    time_audio_header = .{};
    return "";
}

time_audio_play :: (resume: bool, alternate: bool) -> string {
    error := time_audio_stop();
    if error.count return error;
    index := (ifx alternate then 2 else 0) + (ifx resume then 1 else 0);
    clip  := *time_audio_clips[index];
    error = time_audio_load(clip, time_audio_filename(resume, alternate));
    if error.count return error;
    if waveOutOpen(*time_audio_device, 0xffffffff, *clip.format, 0, 0, 0) != 0 return "Could not open time audio output.";
    time_audio_header = .{data = cast(*u8) clip.samples.data, length = cast(u32)(clip.samples.count * 2)};
    if waveOutPrepareHeader(time_audio_device, *time_audio_header, size_of(Time_Audio_Header)) != 0 {
        time_audio_stop();
        return "Could not prepare time audio.";
    }
    time_audio_prepared = true;
    if waveOutWrite(time_audio_device, *time_audio_header, size_of(Time_Audio_Header)) != 0 {
        time_audio_stop();
        return "Could not play time audio.";
    }
    return "";
}

time_audio_finished :: () -> bool {
    // WHDR_DONE is set by the driver after playback, rather than after decoding or a guessed timer.
    return time_audio_device != null && (time_audio_header.flags & 1) != 0;
}

time_audio_deinit :: () {
    error := time_audio_stop();
    if error.count { print("%\n", error); return; }
    for *clip: time_audio_clips { free(clip.samples.data); clip.* = .{}; }
}

#scope_file
Vorbis                 :: #import "stb_vorbis";
Wav                    :: #import "Wav_File";
time_winmm             :: #library,system "winmm";
waveOutOpen            :: (device: **void, id: u32, format: *Wav.Waveformatex, callback: u64, instance: u64, flags: u32) -> u32 #foreign time_winmm;
waveOutPrepareHeader   :: (device: *void, header: *Time_Audio_Header, size: u32) -> u32 #foreign time_winmm;
waveOutUnprepareHeader :: (device: *void, header: *Time_Audio_Header, size: u32) -> u32 #foreign time_winmm;
waveOutWrite           :: (device: *void, header: *Time_Audio_Header, size: u32) -> u32 #foreign time_winmm;
waveOutReset           :: (device: *void) -> u32 #foreign time_winmm;
waveOutClose           :: (device: *void) -> u32 #foreign time_winmm;
