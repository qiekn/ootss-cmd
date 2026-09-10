#import "Basic";
#load "keyboard.jai";

main :: () {
    print("Switch to the game within 3 seconds. Hold Esc to stop.\n");
    sleep_milliseconds(3000);

    if !send("wwwwdddd") {
        exit(1);
    }

    print("Done.\n");
}
