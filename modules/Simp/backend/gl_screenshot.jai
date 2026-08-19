// create_texture_reader :: (format: Texture_Format, flags: Texture_Flags, w: int, h: int) -> *Pixel_Read;
// destroy_texture_reader/free :: (reader: *Pixel_Read);

// reader_start :: (reader: *Pixel_Read, map: *Texture);
// reader_start :: (reader: *Pixel_Read, map: *Texture, face: int/*, mipmap: int*/);

// reader_lock :: (reader: *Pixel_Read) -> data: *void, pitch:int;
// reader_unlock :: (reader: *Pixel_Read);

// is_read_available :: (reader: *Pixel_Read) -> bool;

// reader_end :: (reader: *Pixel_Read, bitmap: *Bitmap);
// reader_end :: (reader: *Pixel_Read) -> *Bitmap;

// Ignacio Castaño originally wrote this code, but it's been modified a bit, especially as regards the API.


Pixel_Read_Platform :: struct {
    dest_size: s64; // In bytes. Is this platform specific really?

    intermediate_texture: Texture;  // @Leak if this is used (eg for resizing) we don't currently clean it up
    pbo: GLuint;
    src\_fbo_handle: GLuint;
    dest_fbo_handle: GLuint;
}

/*
get_bitmap_from_texture :: (map: *Texture, format:=Texture_Format.Unknown, width:s32=0, height:s32=0, srgb:bool) -> *Bitmap {
    if format == Texture_Format.Unknown format = map.format;
    if width == 0 width = map.width;
    if height == 0 height = map.height;

    reader := create_texture_reader(format, width, height, srgb);
    defer destroy_texture_reader(reader);

    reader_start(reader, map);
    return reader_end(reader);    // This blocks until the read completes.
}
*/

// To start asynchronously reading a screenshot, call pixel_read_begin().
// If 'source' is null, the read will come from the frame buffer.
// Currently, we don't vet whether the graphics API handles 'dest_format',
// so if you pick something weird, you may be on your own.
//
// Call pixel_read_end() to get back a resulting Bitmap (you have memory responsibility
// over the Bitmap's data and must free it in a long-running program).
//
// Call pixel_read_is_done() to know whether the read has finished, in which case,
// when you call pixel_read_end() it will return very quickly. Otherwise, pixel_read_end()
// will block until the screenshot is done.
pixel_read_begin :: (source: *Texture /* may be null */, dest_format: Texture_Format, width: s32 = -1, height: s32 = -1, srgb := false, flip := false) -> *Pixel_Read {
    assert((dest_format == .RGB8) || (dest_format == .RGBA8));
    
    // Note that miplevels are not currently handled. If we cared about them we would have to take a level param and pass
    // that on to the glFramebufferTexture2D call in set_frame_buffer_attachment.

    reader := New(Pixel_Read);  // @Cleanup: Don't use the heap?
    
    // Allocate some shared resources. If we actually were able to thread this, there'd be one per reader.
    glGenFramebuffers(1, *reader.src\_fbo_handle);
    glGenFramebuffers(1, *reader.dest_fbo_handle);

    reader.dest_format = dest_format;
    reader.dest_srgb   = srgb;
    reader.flip        = flip;
    
    source_width, source_height: s32;

    if source {
        source_width  = source.width;
        source_height = source.height;

    } else {
        source_width  = context.simp.current_window_info.window_width;
        source_height = context.simp.current_window_info.window_height;

        reader.flip = !flip;   // Because GL is a poop, frame buffer reads come back in the opposite way from texture reads.
    }

    dest_width  := width;
    dest_height := height;
    if width  == -1  dest_width  = source_width;
    if height == -1  dest_height = source_height;

    reader.dest_width  = dest_width;
    reader.dest_height = dest_height;

    // Compute size.
    size := get_image_size(dest_format, reader.dest_width, reader.dest_height);
    reader.dest_size = size;

    glGenBuffers(1, *reader.pbo);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, reader.pbo);
    glBufferData(GL_PIXEL_PACK_BUFFER, size, null, GL_DYNAMIC_READ);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);

    source_handle: GLuint;  // 0 means read from the frame buffer.

    // Depending on the input source we might need an intermidate buffer.
    needs_intermediate_buffer := false;

    if source {
        // If the texture is multisampled, or we need to do format conversion, or resizing, then use an intermediate buffer.
        source_handle = source.gl_handle;

        // @@ Not sure what's the best way to handle the sRGB flag. We probably don't care here.
        src_srgb := cast(bool)(source.flags & .sRGB);

        needs_intermediate_buffer = source.flags & .Multisampled ||
                                    source.format != dest_format || src_srgb != srgb || 
                                    source.width  != dest_width  || source.height != dest_height;
    } else {
        // When taking screenshots we don't need an intermediate buffer to handle resolving multisampling, but we still 
        // do if we want to resize. What about format?

        is_fullsize := (source_width == dest_width) && (source_height == dest_height);

        needs_intermediate_buffer = !is_fullsize;

        // You can't resolve a multisampled frame buffer, and resize in the same blit, if we need to do both operations we need
        // two intermediate buffers! It is simple enough to add this code, but maybe we should just keep it simple and say
        // we only support fullscreen screenshots when msaa is enabled?
        // 
        // Strangely, we get the same :BlitErrors when we try to resolve and resize a texture, but the output is correct.
        sample_count := context.simp.current_window_info.msaa;
        if !is_fullsize && sample_count > 0 {
            log_error("Reading a multisampled (%) screen framebuffer and scaling ((%, %) -> (%, %)) requires two blits which we don't currently support!", sample_count, source_width, source_height, dest_width, dest_height);
        }
    }

    if needs_intermediate_buffer {
        if reader.intermediate_texture.gl_handle == 0 {
            flags: Texture_Flags;
            if srgb flags |= .sRGB;
            reader.intermediate_texture = texture_create_render_target(dest_width, dest_height, dest_format, flags);
        }

        // Blit src into downsampled_surface.
        src_x, src_y: s32;
        src_width  := source_width;
        src_height := source_height;
            
        // Crop if aspect ratio of src and dst do not match.
        if dest_width*src_height != src_width*dest_height {
            h := (dest_height * src_width) / dest_width;
            crop := (src_height - h) / 2;
            src_y = crop;
            src_height = h;
        }

        dest_handle := reader.intermediate_texture.gl_handle;

        old_read := bind_read_fbo(source_handle, reader.src\_fbo_handle);
        old_draw := bind_draw_fbo(dest_handle,   reader.dest_fbo_handle);

        // Note that destination rectangle is flipped, so we don't have to flip the output later.
        // glBlitFramebuffer(src_x, src_y, src_width, src_height, 0, dest_height, dest_width, 0, GL_COLOR_BUFFER_BIT, GL_LINEAR);

        glBlitFramebuffer(src_x, src_y, src_width, src_height, 0, 0, dest_width, dest_height, GL_COLOR_BUFFER_BIT, GL_NEAREST);

        // This will produce a GL_INVALID_OPERATION error when our source is the screen and multi sampling is enabled and we
        // are resizing. Our output image will be all zeros. But it _also_ produces an error when this path is taken for
        // textures and in those cases we still get the correct output soo... :BlitErrors
        DumpGLErrors("glBlitFramebuffer screenshot");

        unbind_draw_fbo(dest_handle,   old_draw);
        unbind_read_fbo(source_handle, old_read);

        source_handle = reader.intermediate_texture.gl_handle;
    }

    old_read := bind_read_fbo(source_handle, reader.src_fbo_handle);
    defer unbind_read_fbo(source_handle, old_read);

    _, gl_format, gl_type := get_ogl_format(dest_format, srgb);

    // Kick off read to our PBO.
    glBindBuffer(GL_PIXEL_PACK_BUFFER, reader.pbo);
    glReadPixels(0, 0, xx reader.dest_width, xx reader.dest_height, gl_format, gl_type, null);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);

    return reader;
}

pixel_read_is_done :: (reader: *Pixel_Read) -> bool {
    // IC: As far as I can tell, in OpenGL there's no way to determine if the read has completed and we
    // can map the buffer without stalling.
    //
    // NOTE(Charles): It seems like glFenceSync, glClientWaitSync can be used to do this. They appear to be doing something
    // when I use them on my machine, but I wasn't able to understand the results I was seeing to be at all confident they
    // were doing the right thing? This gl sync api has been around for a while so it's probably safe to assume Ignacio knew
    // about them and they don't work for this?
    return true;
}

pixel_read_end :: (reader: *Pixel_Read, bitmap: *Bitmap) {
    // reader_lock
    src: *void;
    src_pitch: int;
    {
        bpp := get_image_bytes_per_texel(reader.dest_format);
        pitch := bpp * reader.dest_width;
        pitch = (pitch + 3) & -4;       // IC: Align to 4 bytes?
        // @Robustness: wtf with the pitch alignment, do we really want to do that?

        glBindBuffer(GL_PIXEL_PACK_BUFFER, reader.pbo);

        #if IS_GLES {
            src = glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, reader.dest_size, GL_MAP_READ_BIT);
        } else {
            src = glMapBuffer(GL_PIXEL_PACK_BUFFER, GL_READ_ONLY);
        }
        src_pitch = pitch;
    }
    defer {
        // reader_unlock
        glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
        glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    }

    dst := bitmap.data.data;
    dest_height := bitmap.height;

    bpp := get_image_bytes_per_texel(bitmap.format);
    dest_pitch := bitmap.width * bpp;

    copy_pitch := min(src_pitch, dest_pitch);
    if reader.flip {
        for y: 0..dest_height-1 {
            memcpy(dst + (dest_height-1 - y) * dest_pitch, src + y * src_pitch, copy_pitch);
        }
    } else {
        if src_pitch == dest_pitch {
            memcpy(dst, src, bitmap.width*bitmap.height*bpp);
        } else {
            for y: 0..dest_height-1 {
                memcpy(dst + y * dest_pitch, src + y * src_pitch, copy_pitch);
            }
        }
    }

    glDeleteBuffers(1, *reader.pbo);
    reader.pbo = 0;
    
    texture_destroy(*reader.intermediate_texture);
    free(reader);
}

pixel_read_end :: (reader: *Pixel_Read) -> Bitmap {
    bitmap: Bitmap;
    bitmap_alloc(*bitmap, reader.dest_width, reader.dest_height, reader.dest_format);
    pixel_read_end(reader, *bitmap);
    return bitmap;
}

#scope_file

bind_read_fbo :: (handle: GLuint, src_fbo_handle: GLuint) -> (old: GLuint) {
    prev_read_fbo: GLuint;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, xx *prev_read_fbo);

    if handle {
        // Bind buffer to read.
        glBindFramebuffer(GL_READ_FRAMEBUFFER, src_fbo_handle);
        set_frame_buffer_attachment(GL_READ_FRAMEBUFFER, handle);
    } else {
        // Read front buffer.
        glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
        #if !IS_GLES  glReadBuffer(GL_FRONT);
    }

    // check_framebuffer_status(GL_DRAW_FRAMEBUFFER);

    return prev_read_fbo;
}

unbind_read_fbo :: (handle: GLuint, prev_read_fbo: GLuint) {
    if handle {
        // Unbind draw framebuffer attachments
        set_frame_buffer_attachment(GL_READ_FRAMEBUFFER, 0);
    } else {
        #if !IS_GLES  glReadBuffer(GL_NONE);
    }

    // Restore read FBO.
    glBindFramebuffer(GL_READ_FRAMEBUFFER, prev_read_fbo);

    // check_framebuffer_status(GL_DRAW_FRAMEBUFFER);
}

bind_draw_fbo :: (handle: GLuint, dest_fbo_handle: GLuint) -> (old: GLuint) {
    prev_draw_fbo: GLuint;
    
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, xx *prev_draw_fbo);

    if handle {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, dest_fbo_handle);
        set_frame_buffer_attachment(GL_DRAW_FRAMEBUFFER, handle);
    } else {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
        #if !IS_GLES  glDrawBuffer(GL_BACK);
    }

    // check_framebuffer_status(GL_DRAW_FRAMEBUFFER);

    return prev_draw_fbo;
}

unbind_draw_fbo :: (handle: GLuint, prev_draw_fbo: GLuint) {
    if handle {
        // Unbind draw framebuffer attachments
        set_frame_buffer_attachment(GL_DRAW_FRAMEBUFFER, 0);
    } else {
        #if !IS_GLES  glDrawBuffer(GL_NONE);
    }

    // Restore draw FBO.
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, prev_draw_fbo);

    // check_framebuffer_status(GL_DRAW_FRAMEBUFFER);
}

set_frame_buffer_attachment :: (target: GLenum, handle: GLuint) {
    // GL_TEXTURE_2D seems to be the thing that works for anything we care about (including render targets).
    textarget := cast(GLenum) GL_TEXTURE_2D;
    glFramebufferTexture2D(target, GL_COLOR_ATTACHMENT0, textarget, handle, 0);

    // GLES assumes the source GL_COLOR_ATTACHMENT0 already
    #if !IS_GLES {
        // @@ Is this saved in the framebuffer object configuration?
        if target == GL_DRAW_FRAMEBUFFER {
            if handle == 0  glDrawBuffer(GL_NONE);
            else            glDrawBuffer(GL_COLOR_ATTACHMENT0);
        } else {
            assert(target == GL_READ_FRAMEBUFFER);
            if handle == 0  glReadBuffer(GL_NONE);
            else            glReadBuffer(GL_COLOR_ATTACHMENT0);
        }
    }
}

// @Temp While trying to figure out :BlitErrors, something people seem to say to check is that the framebuffers are complete.
// This confirms that is _not_ our issue.
check_framebuffer_status :: (target: GLenum) {
    status := glCheckFramebufferStatus(target);
    assert(status == GL_FRAMEBUFFER_COMPLETE);
}
