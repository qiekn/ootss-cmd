state_table: Table(u64, *Active_Widget);
    
find_or_create_state :: ($T: Type, hash: u64, start_using := true) -> (*T, created: bool) {
    // @Memory: table_find_multiple uses temporary_storage each time, and maybe we are burning
    // through a lot if you draw a lot of widgets, so we might want to do a thing where we only
    // call table_find_multiple if we encounter an unexpected result -- we will almost never
    // actually see collisions!

    // We need to handle collisions, though, because what if there's e.g. a collision
    // between a Button and a Text_Input and this causes us to punt on the Text_Input...
    // what do we do? We could just claim that this will never happen, but, this probably
    // requires stronger auditing on our hashes than we have done.  -jblow, 29 November 2021
    found := table_find_multiple(*state_table, hash);
    for p: found {
        if p.widget_type == T {
            if start_using start_using_state(p);
            return cast(*T)p, false;
        }
    }

    state := New(T);  // For now we allocate these and store them in the table by pointer, so that we have pointer stability in case we want to return them to the user, etc.
    state.widget_type = T;

    table_add(*state_table, hash, state);
    if start_using start_using_state(state);
    
    return state, true;
}

