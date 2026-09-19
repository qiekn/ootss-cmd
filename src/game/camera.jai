GAME_CAMERA_FROZEN_MODE :: 2;

Game_Camera_Session :: struct {
    memory: Process_Memory;
    layout: Game_Camera_Layout;
    original: Game_Camera_Snapshot;
    position: Game_Position;
    orientation: [4] float;
    owns_mode, settled: bool;
}

game_camera_read_session :: (session: *Game_Camera_Session) -> (pose: Game_Camera_Snapshot, error: string) {
    pose := session.original;
    memory := session.memory;
    layout := session.layout;
    if !session.owns_mode || !game_camera_identity_current(memory, layout, session.original) {
        return pose, "Freecam stopped: the scene or camera changed.";
    }
    if !process_read_memory(memory.handle, layout.mode, *pose.mode, 8) || pose.mode != GAME_CAMERA_FROZEN_MODE ||
       !process_read_memory(memory.handle, pose.scene.manager + layout.position, *pose.position, 12) ||
       !process_read_memory(memory.handle, pose.scene.manager + layout.orientation, *pose.orientation, 16) ||
       !process_read_memory(memory.handle, pose.scene.manager + layout.projection, *pose.projection, 12) ||
       !game_camera_pose_valid(pose) || !game_camera_identity_current(memory, layout, session.original) {
        return pose, "Freecam stopped: the native camera state changed or became unreadable.";
    }
    return pose, "";
}

game_camera_begin :: (session: *Game_Camera_Session, memory: Process_Memory) -> string {
    if session.owns_mode return "Freecam is already active.";
    layout, error := game_camera_layout(memory);
    if error.count return error;
    snapshot, snapshot_error := game_camera_snapshot(memory, layout);
    if snapshot_error.count return snapshot_error;
    if snapshot.mode != 0 return "The game's native camera mode is already in use. Freecam was not enabled.";
    mode: s64;
    if !game_camera_identity_current(memory, layout, snapshot) ||
       !process_read_memory(memory.handle, layout.mode, *mode, 8) || mode != snapshot.mode {
        return "The camera changed before freecam could start.";
    }
    session.* = .{memory = memory, layout = layout, original = snapshot, position = snapshot.position, orientation = snapshot.orientation};
    frozen: s64 = GAME_CAMERA_FROZEN_MODE;
    success, written := process_write_memory(memory.handle, layout.mode, *frozen, 8);
    session.owns_mode = written > 0;
    if !success return tprint("Could not enable freecam (% of 8 bytes; Windows error %).", written, Win.GetLastError());
    pose, pose_error := game_camera_read_session(session);
    if pose_error.count return pose_error;
    return "";
}

// Let a frame already in progress finish before adopting the frozen pose.
// The application calls this after a short, nonblocking settling interval.
game_camera_settle :: (session: *Game_Camera_Session) -> string {
    pose, error := game_camera_read_session(session);
    if error.count return error;
    session.original.position = pose.position;
    session.original.orientation = pose.orientation;
    session.original.projection = pose.projection;
    session.position = pose.position;
    session.orientation = pose.orientation;
    session.settled = true;
    return "";
}

game_camera_pose_unchanged :: (session: *Game_Camera_Session, pose: Game_Camera_Snapshot) -> bool {
    for value: pose.position if value != session.position[it_index] return false;
    for value: pose.orientation if value != session.orientation[it_index] return false;
    for value: pose.projection if value != session.original.projection[it_index] return false;
    return true;
}

game_camera_move :: (session: *Game_Camera_Session, delta: Game_Position) -> (error: string, changed: bool) {
    error, changed := game_camera_move(session, delta, session.orientation);
    return error, changed;
}

// Move by delta and adopt orientation in one verified step; either part may be
// unchanged. The orientation must already be a unit quaternion.
game_camera_move :: (session: *Game_Camera_Session, delta: Game_Position, orientation: [4] float) -> (error: string, changed: bool) {
    if !session.settled return "Freecam is waiting for the camera to settle.", false;
    if !game_position_valid(delta) return "The camera movement is outside the supported range.", false;
    if !game_camera_orientation_valid(orientation) return "The camera orientation must be a unit quaternion.", false;
    pose, error := game_camera_read_session(session);
    if error.count return error, false;
    if !game_camera_pose_unchanged(session, pose) return "Freecam stopped: the game changed the frozen camera.", false;
    destination: Game_Position;
    move, turn: bool;
    for i: 0..2 {
        coordinate := cast(float64) session.position[i] + cast(float64) delta[i];
        if !is_finite(coordinate) || abs(coordinate) > GAME_POSITION_LIMIT {
            return "The camera destination must stay between -1000000 and 1000000.", false;
        }
        destination[i] = cast(float) coordinate;
        if destination[i] != session.position[i] move = true;
    }
    for value: orientation if value != session.orientation[it_index] turn = true;
    if !move && !turn return "", false;
    if !game_camera_identity_current(session.memory, session.layout, session.original) return "The scene changed before camera movement.", false;
    mode: s64;
    if !process_read_memory(session.memory.handle, session.layout.mode, *mode, 8) || mode != GAME_CAMERA_FROZEN_MODE {
        return "The native camera mode changed before movement.", false;
    }
    changed := false;
    if move {
        success, written := process_write_memory(session.memory.handle, pose.scene.manager + session.layout.position, *destination, 12);
        changed = written > 0;
        if !success return tprint("Could not finish camera movement (% of 12 bytes; Windows error %).", written, Win.GetLastError()), changed;
        session.position = destination;
    }
    if turn {
        turned := orientation;
        success, written := process_write_memory(session.memory.handle, pose.scene.manager + session.layout.orientation, *turned, 16);
        if written > 0 changed = true;
        if !success return tprint("Could not finish camera rotation (% of 16 bytes; Windows error %).", written, Win.GetLastError()), changed;
        session.orientation = turned;
    }
    after, after_error := game_camera_read_session(session);
    if after_error.count return after_error, changed;
    if !game_camera_pose_unchanged(session, after) return "The camera was written but changed before verification.", changed;
    return "", changed;
}

game_camera_end :: (session: *Game_Camera_Session) -> string {
    if !session.owns_mode return "";
    memory := session.memory;
    layout := session.layout;
    if !game_camera_code_current(memory, layout) return "Could not restore camera following: the game code is no longer readable or has changed.";
    mode: s64;
    if !process_read_memory(memory.handle, layout.mode, *mode, 8) return "Could not read the native camera mode while stopping freecam.";
    if mode != GAME_CAMERA_FROZEN_MODE {
        session.owns_mode = false; // Another native mode now owns this field; never overwrite it.
        session.settled = false;
        return "";
    }
    restore_error: string;
    // Restore only our current scene. On a level transition release the global
    // mode without ever writing the old scene's pose into the new manager.
    if game_camera_identity_current(memory, layout, session.original) {
        manager := session.original.scene.manager;
        success, written := process_write_memory(memory.handle, manager + layout.position, *session.original.position, 12);
        if success success, written = process_write_memory(memory.handle, manager + layout.orientation, *session.original.orientation, 16);
        if !success restore_error = "The original view could not be restored; normal camera following was resumed.";
        else {
            position: Game_Position;
            orientation: [4] float;
            verified := process_read_memory(memory.handle, manager + layout.position, *position, 12) &&
                        process_read_memory(memory.handle, manager + layout.orientation, *orientation, 16);
            for value: position if value != session.original.position[it_index] verified = false;
            for value: orientation if value != session.original.orientation[it_index] verified = false;
            if !verified restore_error = "The original view could not be verified; normal camera following was resumed.";
        }
    }
    if !game_camera_code_current(memory, layout) ||
       !process_read_memory(memory.handle, layout.mode, *mode, 8) || mode != GAME_CAMERA_FROZEN_MODE {
        return "The native camera state changed during freecam cleanup.";
    }
    normal := session.original.mode;
    success, written := process_write_memory(memory.handle, layout.mode, *normal, 8);
    if !success || !process_read_memory(memory.handle, layout.mode, *mode, 8) || mode != normal {
        return "Could not restore camera following; freecam cleanup will be retried.";
    }
    session.owns_mode = false;
    session.settled = false;
    return restore_error;
}

// This game's camera quaternion maps local +X forward, +Y left, +Z up.
// W/S follow the view direction; Q/E use the world's vertical Z axis.
game_camera_movement :: (orientation: [4] float, forward: float, right: float, up: float,
                         distance: float) -> Game_Position {
    x := orientation[0]; y := orientation[1]; z := orientation[2]; w := orientation[3];
    delta: Game_Position;
    delta[0] = forward * (1 - 2 * (y*y + z*z)) - right * 2 * (x*y - z*w);
    delta[1] = forward * 2 * (x*y + z*w) - right * (1 - 2 * (x*x + z*z));
    delta[2] = forward * 2 * (x*z - y*w) - right * 2 * (y*z + x*w) + up;
    norm := sqrt(delta[0]*delta[0] + delta[1]*delta[1] + delta[2]*delta[2]);
    if norm > 0 for *axis: delta axis.* *= distance / norm;
    return delta;
}

GAME_CAMERA_PITCH_LIMIT :: 89.0 * PI64 / 180;

// Pan along the level's grid: +X is right and +Y is up on screen (the Sokoban
// directions noclip uses), +Z rises away from the ground. The view is unchanged.
game_camera_pan :: (x: float, y: float, z: float, distance: float) -> Game_Position {
    delta: Game_Position;
    delta[0] = x;
    delta[1] = y;
    delta[2] = z;
    norm := sqrt(x*x + y*y + z*z);
    if norm > 0 for *axis: delta axis.* *= distance / norm;
    return delta;
}

// The frozen camera is a yaw about world +Z followed by a pitch about the local
// +Y (left) axis; the observed level camera decomposes exactly this way, so
// rebuilding from the angles keeps the horizon level.
game_camera_angles :: (orientation: [4] float) -> (yaw: float64, pitch: float64) {
    x := cast(float64) orientation[0];
    y := cast(float64) orientation[1];
    z := cast(float64) orientation[2];
    w := cast(float64) orientation[3];
    left_x := 2 * (x*y - z*w);
    left_y := 1 - 2 * (x*x + z*z);
    forward_z := 2 * (x*z - y*w);
    return atan2(-left_x, left_y), asin(clamp(forward_z, -1.0, 1.0));
}

game_camera_orientation :: (yaw: float64, pitch: float64) -> [4] float {
    sz := sin(yaw / 2);
    cz := cos(yaw / 2);
    sy := sin(-pitch / 2);
    cy := cos(-pitch / 2);
    orientation: [4] float;
    orientation[0] = cast(float)(-sz * sy);
    orientation[1] = cast(float)(cz * sy);
    orientation[2] = cast(float)(cy * sz);
    orientation[3] = cast(float)(cz * cy);
    return orientation;
}

game_camera_orientation_valid :: (orientation: [4] float) -> bool {
    norm: float64;
    for value: orientation {
        if !is_finite(value) return false;
        norm += cast(float64) value * value;
    }
    return abs(norm - 1) <= 0.002;
}

#scope_file
#import "Basic";
#import "Math";
Win :: #import "Windows";
