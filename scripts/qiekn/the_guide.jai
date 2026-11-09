#!/bin/env jai

#run {
    hyper_gaming();
    set_build_options_dc(.{do_output=false});
}

hyper_gaming :: () {
    for 1..920 {
        if too_easy(it) {
            log("sooooooooooo.. easy!");
            continue;
        };

        log("level % [think_mode: pro_max_ultra]", it);
        think_mode_pro_max_ultra := true;
        while think_mode_pro_max_ultra {
            zzmkn(); // Yet another meme
        }
        fuckyoujonathanblow();
        sleep(seconds_who_knows(2, 4));
    }
}

zzmkn :: () #expand {
    times_who_knows := cast(int)(10 * random_get_zero_to_one());
    for 1..times_who_knows {
        sleep(seconds_who_knows(.5, 2));
        write_string("这怎么可能？\n");
    }
    sleep(seconds_who_knows(0.5, 3.0));
    `think_mode_pro_max_ultra = false;
}

too_easy :: (index : int) -> bool {
    if skill_level == {
        case .NOOB;
            if index < 4 then return true;
            return false;
        case .GOAT; return true;
        case;
            write_string("??? WHO ARE YOU ?");
            return true;
    }
}

fuckyoujonathanblow :: () {
    write_string("It's a good level!\n\n");
}

seconds_who_knows :: (min: float, max: float) -> float {
    return random_get_within_range(min, max);
}

skill_level := SkillLevel.NOOB;

sleep :: (seconds : float) {
    ms := cast(s32) seconds * 1000;
    sleep_milliseconds(ms);
}

SkillLevel :: enum u8 { NOOB; GOAT; }

#import "nothing";
#import "Compiler";
#import "Basic";
#import "Random";

