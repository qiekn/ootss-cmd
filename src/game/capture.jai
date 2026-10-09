Capture_Phase :: enum { IDLE; WAIT_FOCUS; SETTLE; MOVE; WAIT_FRAME; PAUSED; DONE; }
Capture_State :: struct {
    phase: Capture_Phase;
    pending, directory, message: string;
    manifest: Capture_Manifest;
    game: Win.HWND;
    pid: u32;
    ready_at, hidden_at: float64;
    owns_camera, pause_requested: bool;
    frame: Capture_Frame;
}
capture: Capture_State;

capture_active :: () -> bool {
    return capture.phase==.WAIT_FOCUS || capture.phase==.SETTLE || capture.phase==.MOVE || capture.phase==.WAIT_FRAME;
}

capture_status :: (message: string) {
    free(capture.message);
    capture.message=copy_string(message);
    if capture.directory.count {
        status: Capture_Status = .{state=tprint("%", capture.phase), message=message, completed=capture.manifest.frames.count, total=capture.manifest.columns*capture.manifest.rows};
        error := capture_atomic_json(tprint("%/status.json",capture.directory),status);
        if error.count console_write(*console,error,.ERROR);
    }
    if !capture.owns_camera hud_notify(message,2);
}

capture_release_camera :: () {
    if capture.owns_camera {
        freecam_stop(*console);
        capture.owns_camera=false;
    }
    hud.suppressed=false;
}

capture_pause :: (reason: string) {
    capture_release_camera();
    capture.phase=.PAUSED;
    capture.pause_requested=false;
    capture_status(reason);
}

capture_clear :: () {
    capture_release_camera();
    free(capture.directory);
    free(capture.message);
    free(capture.manifest.plan.scene);
    array_free(capture.manifest.frames);
    capture.directory="";
    capture.message="";
    capture.manifest=.{};
    capture.phase=.IDLE;
    capture.pause_requested=false;
    capture.game=null;
    capture.pid=0;
}

capture_load :: (filename: string) -> string {
    if capture_active() return "Pause or cancel the current capture first.";
    if freecam.enabled || freecam.stopping return "Disable freecam before starting a capture job.";
    success, plan := Json.json_parse_file(filename,Capture_Plan);
    defer free(plan.scene);
    if !success return "Could not parse the capture plan.";
    error := capture_validate_plan(plan);
    if error.count return error;
    directory := path_strip_filename(filename);
    if !directory.count return "Use a plan file inside a capture directory.";
    next: Capture_Manifest;
    manifest_file := tprint("%/manifest.json",directory);
    if file_exists(manifest_file) {
        parsed: bool;
        parsed, next = Json.json_parse_file(manifest_file,Capture_Manifest);
        if !parsed || !capture_plan_equal(plan,next.plan) {
            free(next.plan.scene); array_free(next.frames);
            return "Existing capture metadata does not match the plan. Use a new directory.";
        }
        if capture_validate_manifest(next).count {
            free(next.plan.scene); array_free(next.frames);
            return "Invalid capture metadata.";
        }
        for frame: next.frames {
            expected := capture_grid_frame(next,it_index);
            valid := frame.index==it_index && frame.column==expected.column && frame.row==expected.row;
            for axis: 0..2 if frame.position[axis]!=expected.position[axis] valid=false;
            if !valid || !file_exists(capture_frame_file(directory,it_index)) {
                free(next.plan.scene); array_free(next.frames);
                return "A completed frame is missing or its coordinates are invalid.";
            }
        }
    } else {
        next.plan=plan;
        next.plan.scene=copy_string(plan.scene);
    }
    capture_clear();
    capture.directory=copy_string(directory);
    capture.manifest=next;
    capture.game=find_game_window();
    capture.pid=process_window_pid(capture.game);
    if !capture.game || !capture.pid { capture.phase=.PAUSED; capture_status("Game unavailable. Start it before submitting a job."); return capture.message; }
    capture.phase=.WAIT_FOCUS;
    capture_status("Capture queued: focus the game");
    return "";
}

command_capture :: (state: *Console_State, arguments: string) {
    if capture.pending.count { console_write(state,"A capture request is waiting.",.ERROR); return; }
    capture.pending=copy_string(trim(arguments));
    if !capture.pending.count console_write(state,"Usage: capture start <plan.json>, pause, resume, cancel, status",.ERROR);
}

capture_requests :: () {
    if !capture.pending.count return;
    request:=capture.pending;
    capture.pending="";
    defer free(request);
    at:=find_index_from_left(request," ");
    verb:=ifx at<0 then request else slice(request,0,at);
    argument:=ifx at<0 then "" else trim(slice(request,at+1,request.count-at-1));
    if argument.count>=2 && argument[0]==#char "\"" && argument[argument.count-1]==#char "\"" argument=slice(argument,1,argument.count-2);
    error: string;
    if equal_nocase(verb,"start") && argument.count error=capture_load(argument);
    else if equal_nocase(verb,"pause") && !argument.count && capture_active() capture_pause("Capture paused");
    else if equal_nocase(verb,"cancel") && !argument.count {
        capture_release_camera(); capture.phase=.IDLE; capture_status("Capture cancelled; completed frames retained");
    } else if equal_nocase(verb,"resume") && !argument.count && capture.phase==.PAUSED {
        if freecam.enabled || freecam.stopping error="Disable freecam before resuming capture.";
        else { capture.phase=.WAIT_FOCUS; capture_status("Capture queued: focus the game"); }
    } else if equal_nocase(verb,"status") && !argument.count {
        console_write(*console,tprint("% (% / %)",capture.message,capture.manifest.frames.count,capture.manifest.columns*capture.manifest.rows));
    } else error="Usage: capture start <plan.json>, pause, resume, cancel, status";
    if error.count { console_write(*console,error,.ERROR); hud_notify(error,3); }
}

capture_update :: (now: float64) {
    capture_requests();
    if !capture_active() return;
    if capture.pause_requested { capture_pause("Capture paused by movement input"); return; }
    if !capture.game || overlay.game!=capture.game || process_window_pid(capture.game)!=capture.pid {
        capture_pause("Capture paused: the game changed"); return;
    }
    focused := Win.GetForegroundWindow()==capture.game && !overlay.visible && !editor_window.visible && !editor_save_prompt.active;
    if !focused {
        if capture.phase!=.WAIT_FOCUS capture_pause("Capture paused: focus changed or an overlay opened");
        return;
    }
    if capture.phase==.WAIT_FOCUS {
        for key: s32.[Win.VK_RETURN,Win.VK_SHIFT,Win.VK_CONTROL,Win.VK_MENU,Win.VK_LWIN,Win.VK_RWIN] if Win.GetAsyncKeyState(key)<0 return;
        for key:"WSADQE" if Win.GetAsyncKeyState(cast(s32)key)<0 return;
        if console.pending_action!=.NONE || console.pending_send.count || console.pending_position_change || console.pending_freecam_change return;
        scene, scene_error:=game_read_scene();
        defer free(scene);
        if scene_error.count || scene!=capture.manifest.plan.scene { capture_pause("Capture paused: the scene does not match the plan"); return; }
        bounds,bounds_error:=capture_client_bounds(capture.game);
        if bounds_error.count { capture_pause(bounds_error); return; }
        if freecam.enabled || freecam.stopping { capture_pause("Capture paused: freecam is already in use"); return; }
        error:=freecam_start(capture.game,.TOPDOWN);
        if error.count { capture_pause(error); return; }
        capture.owns_camera=true;
        capture.phase=.SETTLE;
        capture_status("Capture started");
        return;
    }
    if !freecam.enabled || !freecam.session.settled {
        if capture.phase!=.SETTLE capture_pause("Capture paused: the camera session stopped");
        else if !freecam.enabled capture_pause("Capture paused: camera startup failed");
        return;
    }
    pose,pose_error:=game_camera_read_session(*freecam.session);
    if pose_error.count { capture_pause(pose_error); return; }
    for axis: 0..3 if pose.orientation[axis]!=GAME_CAMERA_TOPDOWN[axis] { capture_pause("Capture paused: view orientation changed"); return; }
    if capture.manifest.width && pose.projection[0]!=capture.manifest.fov { capture_pause("Capture paused: FOV changed"); return; }
    if capture.phase==.WAIT_FRAME && now>=capture.ready_at-0.15 {
        if !hud.suppressed capture.hidden_at=now;
        hud.suppressed=true;
        hud_hide();
    } else hud.suppressed=false;
    if capture.phase==.SETTLE {
        bounds,error:=capture_client_bounds(capture.game);
        if error.count { capture_pause(error); return; }
        grid,grid_error:=capture_make_grid(capture.manifest.plan,bounds.right-bounds.left,bounds.bottom-bounds.top,pose.projection[0]);
        if grid_error.count { capture_pause(grid_error); return; }
        if capture.manifest.width {
            if grid.width!=capture.manifest.width || grid.height!=capture.manifest.height || grid.fov!=capture.manifest.fov {
                capture_pause("Capture paused: resolution or FOV differs from the saved job"); return;
            }
        } else capture.manifest=grid;
        capture.phase=.MOVE;
    }
    if capture.phase==.MOVE {
        if capture.manifest.frames.count==capture.manifest.columns*capture.manifest.rows {
            capture_release_camera(); capture.phase=.DONE; capture_status("Capture complete"); return;
        }
        capture.frame=capture_grid_frame(capture.manifest,capture.manifest.frames.count);
        error,changed:=game_camera_set_position(*freecam.session,capture.frame.position);
        if error.count { capture_pause(error); return; }
        capture.ready_at=now+max(cast(float64)0.2,cast(float64)capture.manifest.plan.settle_ms/1000);
        capture.phase=.WAIT_FRAME;
        return;
    }
    if capture.phase==.WAIT_FRAME && now>=capture.ready_at && now>=capture.hidden_at+0.15 {
        for axis: 0..2 if pose.position[axis]!=capture.frame.position[axis] { capture_pause("Capture paused: camera moved before the screenshot"); return; }
        error:=capture_save_client(capture.game,capture.manifest.width,capture.manifest.height,
                                   capture_frame_file(capture.directory,capture.frame.index));
        if error.count { capture_pause(error); return; }
        verified,verify_error:=game_camera_read_session(*freecam.session);
        if verify_error.count || !game_camera_pose_unchanged(*freecam.session,verified) { capture_pause("Capture paused: camera changed during the screenshot"); return; }
        array_add(*capture.manifest.frames,capture.frame);
        error=capture_atomic_json(tprint("%/manifest.json",capture.directory),capture.manifest);
        if error.count { capture.manifest.frames.count-=1; capture_pause(error); return; }
        capture_status(tprint("Capturing % / %",capture.manifest.frames.count,capture.manifest.columns*capture.manifest.rows));
        capture.phase=.MOVE;
        hud.suppressed=false;
    }
}

capture_deinit :: () {
    if capture_active() capture_pause("Capture paused: helper closed; start the same plan to resume");
    capture_clear(); free(capture.pending); capture.pending="";
}

#scope_file
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
Win :: #import "Windows";
Json :: #import "Json";
