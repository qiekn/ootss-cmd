This section covers some of the default modules and libraries that currently come shipped with the Jai Compiler, such as `Basic`, `String`, `Random`, `Math`, etc. Community libraries are not covered in this section (but if an overwhelming majority find a particular community library useful, we could possibly include that here too).

The `modules` that come with the Jai compiler are providing people with tools that most people would want, that is not trivial.

A more detailed understanding of the modules can be found by looking through the module code, examples, and experimenting around with the libraries yourself.

## Preload
This module is automatically loaded into your program by default. This is the minimal code the compiler needs to compile your program. Here is a list of things found inside preload:
* Type Info Structs
* Any Type
* Allocator definition
* Context definition
* Logger structs and functions
* Stack Trace
* Temporary Storage
* Array Views and Resizable Arrays
* Source Code Location Information

### Getting Commandline Arguments
This small example gets the commandline arguments as string array `[] string`.
```
args := get_command_line_arguments();
```

### memcpy, memset

A typical `memcpy` and `memset`. Similar to C.
```
memcpy :: (dest: *void, source: *void, count: s64);
memset :: (dest: *void, value: u8, count: s64);
```

### OS
This constant is set depending on which OS you are on. Useful when you need to write platform specific OS code.
```
#if OS == .WINDOWS {
  // do code for windows
} else #if OS == .LINUX {
  // do code for linux
} else #if OS == .MACOS {
  // do code for macos.
}
```

### CPU
This constant is set depending on which CPU architecture you are running. Useful when writing hardware specific code.

```
#if CPU == .X64 {
  // do code for x86-64
} else #if CPU == .ARM64 {
  // do code for ARM.
}
```

## Basic
This module contains the "basic" things you probably want in a program. This module is a bit arbitrary in what is put in here. This module will not contain heavyweight libraries such as graphics or GUIs. Here is a brief summary of what can be found in here:
* print functions
* assert
* heap allocation routines
* exit
* String Builder
* time routines
* sleep
* temporary allocator
* Memory Debugger


### Print
The `print` function is defined in `modules/Basic`, and is used to write strings directly to standard output or console.

Here is the function definition:
```
print :: (format_string: string, args: .. Any) -> bytes_printed: s64;
```

A `%` sign marks the place in which the variable will be printed out at. `%1` prints out the first argument, `%2` prints out the second argument, `%3` prints out the third argument, and so on. `%%` will print out a single `%` sign. 
```
// prints out "Hello, My name is John Newton"
print("Hello, My name is % %\n", "John", "Newton");   


// prints out "Hello, My name is Newton John"
print("Hello, My name is %2 %1\n", "John", "Newton"); 


// prints out "Congratulations! You scored 100% on the test!"
print("Congratulations! You scored 100%% on the test!\n"); 
```

The print function supports internationalization and localization.
```
print("你好！\n"); // prints hello in Chinese.
```

### println function
You can create your own `println` function from the `print` function.
```
println :: inline (msg: string, args: ..Any) {
    print(msg, ..args);
    #if OS == .WINDOWS {
      print("\r\n"); // windows
    } else #if OS == .LINUX {
      print("\n"); // linux
    }
}

println :: inline (arg: Any) {
    print("%", arg);
    #if OS == .WINDOWS {
      print("\r\n"); // windows
    } else #if OS == .LINUX {
      print("\n"); // linux
    }
}
```


### Formatting Variables
Just like C, Jai supports formatting variables with functions such as `formatFloat`, `formatStruct`, and `formatInt`. These are defined in `modules/Basic/Print.jai`.
```
v := Vector3.{1.0, 2.0, 3.0};
print("v = %\n", formatStruct(v, 
                              use_long_form_if_more_than_this_many_members=2, 
                              use_newlines_if_long_form=true);

i := 0xFF;
print("i = %\n", formatInt(i, base=16)); // prints out the number in hexadecimal
```

### Apollo Time and Getting the Current Date

Some code to get the current date.
```
time := to_calendar(current_time_consensus(), .LOCAL);
year := time.year;
month := time.month_starting_at_0 + 1;
day := time.day_of_month_starting_at_0 + 1;
print("[Date \"%1.%2.%3\"]\n", formatInt(year, minimum_digits=4), formatInt(month, minimum_digits=2), formatInt(day, minimum_digits=2));
```

Use `current_time_consensus` for getting calendar dates. Use `current_time_monotonic` for getting time when doing simulations.

### S128 / U128

`S128` and `U128` are structs used to support 128-bit integers as structs. Here are the definitions for `S128` and `U128`:
```
S128 :: struct {
  low: u64;
  high: s64;
}

U128 :: struct {
  low: u64;
  high: u64;
}
```

Operations such as `+`, `-`, `*`, `/`, `<<`, `>>`, `<`, and `<=` are supported for both `U128` and `S128`.

This feature is used in `Apollo_Time` for time related operations.


### Sleep
`sleep_milliseconds` puts the computer to sleep for `x` milliseconds.
```
sleep_milliseconds :: (milliseconds: u32);
```

### Assert
`assert` is used as a check for if a certain condition true within the code. If an `assert` fails, it causes the program to print out an error message, print out a stack trace to help you diagnose a problem with your program, and kills your process. If the `ENABLE_ASSERT` parameter is set to false, assertions will be removed from the program.

```
assert :: inline (arg: bool, message := "", args: .. Any, loc := #caller_location);
```

### Heap Allocation Routines

The following are the heap allocation routines found inside the Jai `Basic` module. By default, they function basically the same as in C or C++; when you allocate, you also need to free. `alloc` in Jai is the same as `malloc` in C. `alloc` returns a pointer to uninitialized memory. `New` in Jai is the same as `new` in C++.
```
a := alloc(size_of(int));  // dynamically heap allocates 8 bytes, alloc returns *void
b := New(int);             // dynamically allocate an int
c := NewArray(10, int);    // dynamically allocates an int array of size 10, type of array is "[] int"
```

You can cache align a heap allocation by passing an `alignment` parameter to `New`. For example, if you need your heap allocation to be 64-bit cache aligned, you can do:
```
array := NewArray(500, int, alignment=64);
```
to make the array 64-bit cache aligned.

These are the corresponding memory freeing routines associated with allocation.
```
free(a);       // frees dynamically allocated int variable "a"
free(b);       // frees dynamically allocated int variable "b"
array_free(c); // frees dynamically allocated array "c"
```

### Get Time
```
seconds_since_init :: () -> float
```
Gets the time in seconds. `seconds_since_init` can be used to measure the performance of a piece of code.
```
secs := seconds_since_init();
funct(); // do some work.
secs = seconds_since_init() - secs;
print("funct :: () took % seconds\n", secs);
```

### Measure code performance using a macro
You can take the small example that measures the performances of a piece of code, and place it into a macro.
```
performance_test :: (code: Code) #expand {
  secs := seconds_since_init();
  #insert code; // do some work.
  secs = seconds_since_init() - secs;
  print("Piece of code took % seconds\n", secs);
}
```


### exit function
exit is a function that immediately terminates the program. Make sure to flush and close any open files and networking sockets you are using before exiting the program.
```
exit(0); // exits the program
```

### String Builder

```
init_string_builder :: (builder: *String_Builder, buffer_size := -1)
```
This function initializes the `String Builder` .

```
builder: String_Builder;
builder.allocator = temp;
```
This line of code sets the `String_Builder`'s allocator to whatever context allocator one wants. In this case, we set it to the temporary allocator.

```
free_buffers :: (builder: *String_Builder)
```
This function deallocates the `String Builder` memory.

```
append :: (builder: *String_Builder, s: *u8, length: s64)
append :: (builder: *String_Builder, s: string)
append :: (builder: *String_Builder, byte: u8)
```
Appends a string to the buffer. Used to concatenate multiple strings together, for example, when in a loop.

```
print_to_builder :: (builder: *String_Builder, format_string: string, args: ..Any) -> bool
```
Prints out the items to the String_Builder. Has a format similar to the `print` function. Here is an example use case:

```
builder: String_Builder;

number := 42;
print_to_builder(*builder, "My name is: %1 %2. My favorite number is: %3\n", "Issac", "Newton", number);
print("String_Builder output is: [%]\n", builder_to_string(*builder));
```

```
builder_to_string :: (builder: *String_Builder, extra_bytes_to_prepend := 0) -> string
```
Takes the `String_Builder` contents and returns a string.

### `struct_printer`

The `struct_printer` member of `context.Print_Style` can be used to print arbitrary struct types. `print()` will call this with either a struct or a pointer to a struct. If it returns true, print() will assume it is handled.

## Array
This module contains ways to manipulate `arrays`, and especially dynamically allocated arrays.

```
array_copy :: (array: [] $T) -> [] T;
```
Copies the array and returns the result as an array view.

```
array_free :: (array: [] $T);
```
Frees the heap allocated array.

```
array_add :: (array: *[..]$T, item: T);
```
Adds an element to the end of a dynamically allocated array.

```
array_find :: (array: [] $T, item: T) -> bool, s64;
```
Finds an element in an array.

```
peek :: inline (array: [] $T) -> T;
```
Treats the array as a stack. Peeks the last element of an array.

```
pop :: (array: *[] $T) -> T;
```
Treats the array as a stack. Pops the last element of an array.

```
array_reset :: (array: *[..] $T);
```
Resets all the memory in the array.

```
array_reserve :: (array: *[..] $T, desired_items: s64);
```
Reserves a certain amount of elements in an array.

## File

This is a module for manipulating files. This module has functions for opening, closing, writing, and reading from a file.

### Open and write the entire file
Elementary example to open and write the entire file.
```
write_entire_file :: inline (name: string, data: string) -> bool;
write_entire_file :: (name: string, data: *void, count: int) -> bool;
write_entire_file :: (name: string, builder: *String_Builder, do_reset := true) -> bool;
```

### Open and read the entire file
Elementary example to open and read the entire file.
```
file_name := "hello_sailor.txt";
text, TF := read_entire_file(file_name);
if TF {
  print("File successfully read. Here are the file contents: \n%\n", text);
} else {
  print("Error. Cannot open file.\n");
}
```

### Using defer to close files
After opening a file-like handle, you can use `defer` to close the said handle.
```
#import "File";

file := file_open("my_file.txt");
defer file_close(*file);
// do something with the file.

```

## String
This module contains string manipulation routines.

```
compare :: (a: string, b: string) -> int
```
Compare two strings. This function matches C's strcmp semantics, meaning if `a < b`, return -1, if `a == b`, return 0, and if `a > b`, return 1.

Here is an example use case:
```
result : int;
result = compare("a", "b");
print("result = %\n", result); // prints -1

result = compare("a string", "a string");
print("result = %\n", result); // prints 0

result = compare("b", "a");
print("result = %\n", result); // prints 1
```

```
compare_nocase :: (a: string, b: string) -> int
```
A case insensitive version of `compare`.

```
equal :: (a: string, b: string) -> bool
```
Checks if the two strings are equal. This comparison is case sensitive.

```
equal_nocase :: (a: string, b: string) -> bool
```
Checks if the two strings are equal given no case sensitivity.

```
replace_chars :: (s: string, chars: string, replacements: u8);
```
Replaces all the characters in a string 's' with the replacement `u8`.

## Random
This module deals with random number generation.
```
random_seed :: (new_seed: u32)
```
This function sets the global random seed to the value passed into the function.

```
random_get_zero_to_one :: () -> float
```
Returns a 32 bit floating point number within the range of 0.0 and 1.0, such as .1358701.

```
random_get_within_range :: (min: float, max: float) -> float
```
Returns a 32 bit floating point number within the range of `min` and `max`.

```
random_get :: () -> u32
```
Returns a 32 bit unsigned integer. This is a random number between 0 and 4,294,967,295.

## Math
This module deals with mathematical operations, such as multiplying `2x2`, `3x3`, and `4x4` matrices, with an emphasis on game programming related math.

Here is a list of scalar constants. A lot of these constants are self-explainatory based on the name.
```
TAU
TAU64

PI
PI64

FLOAT16_MAX
FLOAT16_MIN

FLOAT32_INFINITY
FLOAT32_NAN

FLOAT64_MIN
FLOAT64_MAX
FLOAT64_INFINITY
FLOAT64_NAN

S8_MIN
S8_MAX
U8_MAX
S16_MIN
S16_MAX
U16_MAX
```

A set of common mathematical functions.
```
abs :: (x: int) -> int
```
A set of common mathematical objects.
```
Vector2 :: struct;
Vector3 :: struct;
Vector4 :: struct;
Quaternion :: struct;
Matrix2 :: struct;
Matrix3 :: struct;
Matrix4 :: struct;
```

These are trigonometry functions. The functions return results in radians.
```
sin :: (a: float) -> float;
cos :: (a: float) -> float;
tan :: (a: float) -> float;
asin :: (a: float) -> float;
acos :: (a: float) -> float;
atan :: (a: float) -> float;
```

## SIMP

SIMP is a simple rendering framework for programming simple 2D graphics. SIMP has a GL backend. Eventually, SIMP will have other backends.

Bare minimum code to open and close a window in Simp
```
#import "Window_Creation";
#import "System";
#import "Basic";
simp :: #import "Simp";
#import "Input";

main :: () {
  window_width  : s32 = 1920;
  window_height : s32 = 1080;
  render_width  : s32 = 1920;
  render_height : s32 = 1080;

  win := create_window(window_width, window_height, "Simp Window");
  simp.set_render_target(win);
  quit := false;
  while !quit {
    update_window_events();
    for get_window_resizes() {
        if it.window == win {
            window_width  = it.width;
            window_height = it.height;
            render_width  = window_width;
            render_height = window_height;
            simp.update_window(win);
        }
    }

    simp.clear_render_target(0.15555, 0.15555, 0.15555, 1.0);
    for events_this_frame {
        if it.type == .QUIT then 
          quit = true;
    }

    sleep_milliseconds(10);
    simp.swap_buffers(win);
    reset_temporary_storage();
  }
}
```

This makes `SIMP` draw objects with opacity.
```
simp.set_shader_for_color(true);
```


## Machine X64
This module contains useful routines for 64-bit x86 computer architecture machines.

### Prefetch
```
prefetch :: (pointer: *void, $hint: Prefetch_Hint);
```
Prefetching is a method for speeding up fetch operations by beginning a fetch operation before the memory is needed.

The `prefetch` hint specifies where to `prefetch` the data to. The `prefetch` hints include `T0`, `T1`, `T2`, and `NTA`
* `T0` prefetches data into all levels of the cache hierarchy
* `T1` prefetches data into level 2 cache and higher
* `T2` prefetches data into level 3 cache and higher, or an implementation-specific choice.
* `NTA` prefetches data into non-temporal cache structure and into a location close to the processor, minimizing cache pollution.

Here is an example use case for prefetching:
```
prefetch(array.data, Prefetch_Hint.T0);
```

### Memory Fence
```
mfence :: ();
```
This instruction does memory fencing. Memory fence performs a serializing operation on all load-from-memory and store-to-memory instructions that were issued prior the `mfence` instruction. This serializing operation guarantees that every load and store instruction that precedes in program order the `mfence` instruction is globally visible before any load or store instruction that follows the `mfence` instruction is globally visible. 

### Pause
```
pause :: ();
```
The PAUSE instruction will de-pipeline memory reads, so that the pipeline is not filled with speculative CMP instructions.

### Get CPU Info and Check Feature
These set of instructions get the CPU info and checks whether a particular assembly instruction is available.
```
cpu_info := get_cpu_info();
if check_feature(cpu_info.feature_leaves, x86_Feature_Flag.AVX2) {
  #asm AVX2 {
    // Here the pxor gets the 256-bit .y version, since that is the default operand size with AVX. In an AVX512
    // block, the default operand size would be the 512-bit .z.
    pxor v1:, v1, v1;
  }
} else {
  // AVX2 is not available on this processor, we have to run our fallback path...
}
```

### rdtscp

RDTSCP (Read Time-Stamp Counter and Processor ID) reads the value of the processor’s time-stamp counter into EDX and EAX registers. The value of the IA32_TSC_AUX MSR (address C0000103H) is read into the ECX register.

```
rdtscp :: () -> (timestamp: u64, msr: u32) #expand;
```

This instruction is useful for measuring the performance of an application with high precision.

## Process
This module deals with starting, ending, writing to, and reading from processes. This is used to run external programs from the current process.

```
create_process :: (process: *Process, args: .. string, working_directory := "", capture_and_return_output := false, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED, kill_process_if_parent_exits := true) -> success: bool;
```

This function creates a process.

```
write_to_process :: (process: *Process, data: [] u8) -> success: bool, bytes_written: int;
```
This function writes an array of bytes to a process.

```
read_from_process :: (process: *Process, output_buffer: [] u8, error_buffer: [] u8, timeout_ms := -1) -> success: bool, output_bytes: int, error_bytes: int;
```
This function reads an array of bytes from a process.

```
run_command :: (args: .. string, working_directory := "", capture_and_return_output := false, print_captured_output := false, timeout_ms := -1, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED) -> (process_result: Process_Result, output_string := "", error_string := "", timeout_reached := false);
```
This function runs a process within the program. Arguments are passed to the function through the `args` parameter.

## GetRect

Here is a simple `GetRect` program that creates and draws buttons to the screen:
```
main :: () {
  win := create_window(800, 600, "Window");
  window_width, window_height := get_render_dimensions(win);
  set_render_target(win);
  ui_init();
  while eventloop := true {
    Input.update_window_events();
    for Input.get_window_resizes() {
      update_window(it.window);
      if it.window == win {
        window_width  = it.width;
        window_height = it.height;
      }
    }

    mouse_pressed := false;
    for event: Input.events_this_frame {
      if event.type == .QUIT then {
        break eventloop;
      }
      getrect_handle_event(event);
    }

    current_time := seconds_since_init();
    render(win, current_time);
    sleep_milliseconds(10);
    reset_temporary_storage();
  }
}

render :: (win: Window_Type, current_time: float64) #expand {
  // background.
  clear_render_target(.35, .35, .35, 1);
  defer swap_buffers(win);

  // update ui
  width, height := get_render_dimensions(win);
  ui_per_frame_update(win, width, height, current_time);

  // create a button in the top left hand corner.
  k := height * 0.10;
  r := get_rect(5.0, (xx height) - 5.0 - k, 8.5*k, k);
  if button(r, "Button 0") {
    print("Button 0\n");
  }

  r.y -= k + 5.0;

  if button(r, "Button 1") {
    print("Button 1\n");

  }

}

#import "Basic";
#import "Simp";
#import "Window_Creation";
#import "GetRect";
Input :: #import "Input";
```
In the event loop, you need to call `getrect_handle_event(event);`, and before rendering to the screen, you need to call `  ui_per_frame_update(win, width, height, current_time);`, where `win` is the window, `width` is the window width, `height` is the height, and `current_time` is the current time calculated.

The example above draws a window to the screen with two buttons: `Button 0` and `Button 1`. When the if statement is true, it means the button has been pressed. The code for handling the button pressed should execute inside the `if` statement.

### Dropdown Menu
In this render function, we create a `Dropdown` menu. At the end of the rendering, you need to call `draw_popups`. Any change to the index value of the dropdown menu happens after the `draw_popups` function.
```
render :: (win: Window_Type, current_time: float64) #expand {
  // background.
  clear_render_target(.35, .35, .35, 1);
  defer swap_buffers(win);

  // update ui
  width, height := get_render_dimensions(win);
  ui_per_frame_update(win, width, height, current_time);

  // create a button in the top left hand corner.
  k := height * 0.10;
  r := get_rect(5.0, (xx height) - 5.0 - k, 8.5*k, k);

  ARRAY :: string.["Item 0", "Item 1", "Item 2"];

  dropdown(r, ARRAY, *val); // val is global

  defer draw_popups();
}

val: s32 = 0;
```

### Scrollable Region
Here is some basic code to set up a `scrollable region` using `GetRect`.

```
render_scrollable_region :: (win: Window_Type, current_time: float64) #expand {
  // background.
  slider_theme := *default_overall_theme.slider_theme;
  slidable_region_theme := *default_overall_theme.scrollable_region_theme;

  // update ui
  width, height := get_render_dimensions(win);
  ui_per_frame_update(win, width, height, current_time);

  // create a button in the top left hand corner.
  k := height * 0.05;
  r := get_rect(5.0, (xx height) - 8.5*k - 5.0, 8.5*k, 8.5*k);

  slidable_region_theme.region_background.shape.rounding_flags = 0;
  region, inside := begin_scrollable_region(r, slidable_region_theme);
  s := inside;
  s.y = s.y + s.h - k;
  s.h = k;
  s.y += scroll_value;
  index := 0;
  
  for count: 0..9 {

    // increment index by 1
    button(s, "Button", identifier=index);
    index += 1;
    s.y -= floor(k * 1.1 + 0.5);

    // increment index by 1
    boolean_value: bool = true;
    base_checkbox(s, "Checkbox", boolean_value, identifier=index);
    index += 1;
    s.y -= floor(k * 1.1 + 0.5);

    // increment index by 3 to prevent 'GetRect' error
    slider(s, *values[count], 0, 10, 1, slider_theme, "", "", identifier=index);
    index += 3;
    s.y -= floor(k * 1.1 + 0.5);
  }
  end_scrollable_region(region, s.x + s.w, s.y, *scroll_value);

}
```
As demonstrated in the code, `slider` needs to have its `identifier` incremented by 3 instead of the usual 1. Other UI elements, such as `button`, `base_checkbox`, etc. do not have such issues. This is because `slider` consists of 3 separate buttons working together to create one `slider` UI element.

### Setting GetRect Theme

There are many `GetRect` color theming options available. Here's how you can set theme easily.

```
setup_getrect_theme :: (theme: Default_Themes) #expand {
  proc := default_theme_procs[theme];
  getrect_theme = proc();
  button_theme := *getrect_theme.button_theme;
  button_theme.label_theme.alignment = .Left;

  slider_theme := *getrect_theme.slider_theme;
  slider_theme.foreground.alignment = .Left;
  set_default_theme(getrect_theme);
}

//when you want to set the theme call the follow procedure:
setup_getrect_theme(.Grayscale);
```

## Threads
This module deals with Threads. The general items covered in this module include:
* Threads
* Mutexes
* Threading primitives
* Semaphores
* Thread Groups

### Thread

Here is the struct definition for the `Thread` primitive:
```
Thread :: struct {
    index : Thread_Index;
    proc  : Thread_Proc;
    data  : *void;
    workspace : Workspace;
    starting_context: Context;
    starting_temporary_storage: Temporary_Storage;
    allocator_used_for_temporary_storage: Allocator;
    worker_info: *Thread_Group.Worker_Info; // Used by Thread_Group; unused otherwise.
    #if _STACK_TRACE  stack_trace_sentinel: Stack_Trace_Node;
    using specific : Thread_Os_Specific;
}
```
The `Thread_Os_Specific` is information for specific OS'es. The `index` starts at zero, and is incremented every time a new thread is spawned with `thread_init`.

```
thread_init :: (thread: *Thread, proc: Thread_Proc, temporary_storage_size : s32 = 16384, starting_storage: *Temporary_Storage = null) -> bool;
```
This function initializes a thread. This function does not start a thread, but rather just initializes data.

```
thread_start :: (thread: *Thread);
```
This function starts the thread.

```
thread_deinit :: (thread: *Thread);
```
This function closes a thread. Call this function when you do not need a thread anymore.

### Thread Group
A `Thread_Group` is a way of launching a bunch of threads to asynchronously respond to requests. You can initialize a thread group using the `init :: ()` function. Call `start :: ()` on the `Thread_Group` to start running the threads. When you want the threads to stop running, call `shutdown :: ()`. It is best practice to call shutdown before your program exits.

The `Thread_Group` specializes in calling only one function. It does not compute any arbitrary amount of work passed to it, and only deals with one specific function.

```
init :: (group: *Thread_Group, num_threads: s32, group_proc: Thread_Group_Proc, enable_work_stealing := false);
```
This function initializes the `Thread_Group`. Changing the number of threads increases the number of threads in the `Thread_Group`.

The `Thread_Group_Proc` function pointer is defined as follows:
```
Thread_Group_Proc :: #type (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status;
```
The `group` is the `Thread_Group`, the `thread` refers to the particular thread in question, and the `work` is the work passed into the `Thread_Group` through the `add_work :: ()` function. The `Thread_Continue_Status` is returned by procedure. Returning `.STOP` causes the thread to terminate. `.CONTINUE` causes the thread to continue to run. You usually want to return `.CONTINUE`, and `.STOP` is for a resource shortage of some kind.

```
start :: (group: *Thread_Group);
```
Starts up the threads in the thread group.


```
add_work :: (group: *Thread_Group, work: *void, logging_name := "");
```
Adds a unit of work, which will be given to one of the threads.

### Basic Thread Group Example
```
main :: () {
  thread_group: Thread_Group;
  init(*thread_group, 4, thread_test, true);
  thread_group.logging = false; // turns debugging off. set logging = true to turn on debugging

  start(*thread_group);
  for i: 0..10
    add_work(*thread_group, null);

  sleep_milliseconds(5000);

  shutdown(*thread_group);
  print("exit program\n");
}

thread_test :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
  print("thread_test :: () from thread.index = %\n", thread.index);
  return .CONTINUE;
}

#import "Thread";
#import "Basic";
```
In this basic thread group example, we initialize a thread group, start it, add work to the group, and shutdown the thread group.

### Thread Group Example with response to completed work
In the following example, we kick off a set of threads to do a set of tasks, then we use `get_completed_work :: ()` to get the results back. In the main thread, we do something with those results achieved.
```
main :: () {
  thread_group: Thread_Group;
  init(*thread_group, 4, thread_test, true);
  thread_group.logging = false;

  start(*thread_group);
  arr: [10] Work;
  for i: 0..9 {
    arr[i].count = 10000;
    add_work(*thread_group, *arr[i]);
  }

  sleep_milliseconds(5000);

  work_list := get_completed_work(*thread_group);
  total := 0;
  for work: work_list {
    val := cast(*Work) work;
    print("%\n", val.result);
    total += val.result;
  }
  print("Total = %\n", total);
  shutdown(*thread_group);
  print("exit program\n");
}

thread_test :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
  w := cast(*Work)work;
  print("thread_test :: () from thread.index = %, work.count = %\n", thread.index, w.count);

  sum := 0;
  for i: 0..w.count {
    sum += i;
  }
  // return the result.
  w.result = sum;
  return .CONTINUE;
}

Work :: struct {
  count: int;
  result: int;
}


#import "Thread";
#import "Basic";
```

## Pool
### Pool memory
Simple usage of `Pool` memory allocator to automatically free memory of a code block:
```
#import "Basic";
Pool :: #import "Pool";

pool :: (code: Code) #expand {
    _pool: Pool.Pool;
    Pool.set_allocators(*_pool);
    
    {
        push_allocator(Pool.pool_allocator_proc, *_pool);
        #insert code;
    }

    print("The pool contains % bytes.\n", _pool.memblock_size - _pool.bytes_left);
    print("Releasing the pool now.\n");
    Pool.release(*_pool);
}
```
Can be used via
```
x: string; // define variables that need to out-live the pool outside
pool(#code {
    // your code here
    x = "some allocated data";
});
print(x);
```

## Hash Table

A Hash Table data structure that stores a key value pair.

```
table_add :: (table: *Table, key: table.Key_Type, value: table.Value_Type) -> *table.Value_Type;
```

This function adds a key and value to a table.

```
table_set :: (table: *Table, key: table.Key_Type, value: table.Value_Type) -> *table.Value_Type;
```

This function adds or replaces a given key value pair.

```
table_contains :: (table: *Table, key: table.Key_Type) -> bool;
```

This function returns whether a table contains a given key.

```
table_find_pointer :: (table: *Table, key: table.Key_Type) -> *table.Value_Type;
```

This function looks up a given key and returns a pointer to the corresponding value. If multiple values are added with the same key, the first match is returned. If no element has been found, return null.

You can iterate through a given hash table straightforwardly:
```
for value, key: table {
   // go through all hash table elements.
}
```




