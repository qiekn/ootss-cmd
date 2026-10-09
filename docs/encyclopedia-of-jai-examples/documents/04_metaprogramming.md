## Introduction

> "There are many features I can get rid of and it would still be the same programming language. If I got rid of full arbitrary compile time execution, it wouldn't be the same programming language. What I mean by "full" here is, many compilers have some limited set of expressions that they'll evaluate at compile time. There's const expr in C++ and languages like D or Rust will try to expand or formalize in order to give you more versatility to be able to do stuff at compile time. My approach is say "why are you doing that? Let's do everything at compile time. And by everything, I mean everything." - Jonathan Blow

In Functional Programming Languages such as Lisp or Scheme, metaprogramming can be used to generate arbitrarily complex code that can be executed at run time. However, these languages have many negatives such as garbage collection and slow unpredictable performance that make them unsuitable for writing performant, fast software like video games.

In compile time low-level languages such as C, C++, one can write performant, fast software, but those languages lack high-level metaprogramming. Arbitrary code generation is limited to only a few poorly supported features, and even the most simple of metaprograms can be a monumental engineering effort. In C, error-prone macros are used to do metaprogramming, which can lead to incredibly confusing, impossible to read code that does not play well with the debugger. In C++, template metaprogramming drastically slows down compile times to around 24+ hours, and have terrible error messaging and incoherent behavior.

The Jai Programming language fixes this by structuring the compiler around arbitrary compile-time code generation and metaprogramming. Any amount of code can be generated easily by insert/run directives, and there is a compiler message loop that tells the compiler what to do, giving the programmer as much power as possible to do whatever complex metaprogramming given that the metaprogramming is done at compile time. Jai is a highly performant language in the tradition of C or C++, yet incorporates many high level metaprogramming features that these compile-time languages lack.

## Directives
### `#insert` directive
The `#insert` directive inserts a code or a piece of code represented as a string into the program.
```
a := 0;
b := 0;
#insert "c := a + b;";
```

There can be multiple inserts that can be run recursively inside `#insert`. In the `unroll_for_loop` example below, the `#insert` directive has an `#insert` that recursively runs for code being inserted.

```
unroll_for_loop :: (a: int, b: int, body: Code) #expand {
  #insert -> string {
    builder: String_Builder;
    print_to_builder(*builder, "{\n");
    print_to_builder(*builder, "`it: int;\n");
    for i: a..b {
      print_to_builder(*builder, "it = %;\n", i);
      print_to_builder(*builder, "#insert body;\n");
    }
    print_to_builder(*builder, "}\n");
    return builder_to_string(*builder);
  }
}


unroll_for_loop(0, 10, #code {
  print("%\n", it);
});
```

### `#insert, scope` directive
`#insert, scope` allows code to access variabes inside the local macro scope. Here is an example that uses `scope` to insert a comparison code into a bubble sort. The inserted code acts like a comparison function, except without the drawbacks of function pointer callback performance cost. Since the code is inserted at compile time, there should be a lot less overhead in the outputted assembly.

```
arr: [10] int;
// initialize the array to something...


bubble_sort(arr, #code (a < b));
print("sorted array: %\n", arr);

bubble_sort :: (arr: [] $T, compare_code: Code) #expand {
  for 0..arr.count-1 {
    for i: 1..arr.count-1 {
      a := arr[i-1];
      b := arr[i];
      if !(#insert,scope() compare_code) {
        arr[i], arr[j] = arr[j], arr[i];
      }
    }
  }
}
```

### `#run` directive
The `#run` directive is used to perform compile time execution and metaprogramming. If you want to run a function at compile time, type in `#run function();` to run a function named `function` at compile time. Compile time execution runs the code in an interpreted bytecode mode.  Any snippet of code can be run at compile-time, from a video playing sound, to a metaprogram that grabs compile information from a build server then compiles to code, to just about anything limited by your imagination.
```
function :: () {
  print("This is function :: ()\n");
}

#run function(); // executes function at compile time.
```
Any arbitrary set of code computed at compile-time through the `#run` directive. In this example, we compute `PI` through running `compute_pi` at compile-time execution.
```
PI :: #run compute_pi();
compute_pi :: () -> float {
  // calculate pi using the leibniz formula.
  n := 1.0;
  s := 1.0;
  pi := 0.0;

  for 0..10000 {
    pi +=  1.0 / (s*n);
    n += 2.0;
    s = -s;
  }
  return pi*4.0;
}
```
Here's another alternative way to write the same functionality. Both are the same, just different syntactic sugar.
```
PI :: #run -> float {
  // calculate pi using the leibniz formula.
  n := 1.0;
  s := 1.0;
  pi := 0.0;

  for 0..10000 {
    pi +=  1.0 / (s*n);
    n += 2.0;
    s = -s;
  }
  return pi*4.0;
}
```

Any arbitrary set of `#run` directives may be executed, even values that depend on one another. Circular dependencies (e.g. where a depends on b and b depends on a) will result in a compiler error.
```
a := #run f1();
b := #run f2(a);

f1 :: () => 1000;
f2 :: (a)=> a + 1;
print("a=%, b=%\n", a, b); // this prints out a=1000, b=1001
```
`#run` is able to return basic struct values or multidimensional arrays. `#run` directives have massive complications when returning structs due to the complications of pointers inside structs. In order to modify more complex data structures with `#run`, consider using the `#no_reset` directive. 

### `#run, stallable` directive
`#run` can do almost anything, and execution can be arbitrary. `#run` directives may require rely on certain dependencies in order to execute correct (i.e. global variables, the code needs to be compiled enough in order to execute correctly). The Jai compiler tries its best to make sure dependencies are resolved in the correct order. If `#run` code is deadlocking, `#run, stallable` allows one to stall a `#run` directive until the dependencies are resolved correctly before resuming execution.

### `#code` directive

The `#code` directive tells the compiler that the things being declared are code. Variables of the type `#code` can be manipulated by a compile-time metaprogram with compile-time functions such as `compiler_get_nodes`.

```
code :: #code a := Vector3.{1,2,3};
#run {
  builder: String_Builder;
  root, exprs := compiler_get_nodes(code);
  print_expression(*builder, root);

  loc := #location(code);
  print("The code at %:% was: \n", loc.fully_pathed_filename, loc.line_number);

  s := builder_to_string(*builder);
  print("%\n", s);
  print("Here are the types of all expressions in this syntax tree:\n");
  for expr, i: exprs {
    print("[%] %\n", i, expr.kind);
  }
}
```

### `#compile_time` directive

This directive tells whether you are running code at compile time or at runtime.
```
if #compile_time {
  // execute compile time code.
} else {
  // execute runtime code.
}
```

### `#no_reset` directive

When a program is compiled, `#run` directives can access and modify globals. By default, global variables will be reset back to the original default values when outputting the executable. The `#no_reset` tells the compiler to allow `#run` directives modify the executable. See the `#no_reset` how_to for more information regarding `#no_reset`.

```
#no_reset array: [4] int;

#run {
  array[0] = 1;
  array[1] = 2;
  array[2] = 3;
  array[3] = 4;
}

print("%\n", array); // at runtime, array = [1,2,3,4] with the #no_reset directive
```

### `#placeholder` directive

`#placeholder` marks an identifier as defined by the metaprogram. This can be used to hint the compiler that the identifier is being generated in a compile time metaprogram.
```
// jai first.jai -- SOA
main :: () {
   print("Var is %, is a constant? %\n", Var, is_constant(Var));
}

#placeholder Var;

#run {
   #import "Compiler";
   options := get_build_options();

   add_build_string("Var :: true;");
}

#import "Basic";
```

### `#compile_time` directive
This directive evaluates to true if code is running at compile-time. When not running at compile-time, this evaluates to false. It does not evaluate to a constant. This directive can be used to distinguish between code designed to run at compile time and code to be run during runt time. The `#compile_time` directive is not a constant, and therefore cannot be used as a constant.

```
if #compile_time {
  #run print("compile time.\n");
} else {
  print("not compile time.\n");
}
```


## Default metaprogram

Metaprogramming can be used to do many things, such as arbitrary code and correctness checking, auto-generating code to place into one's program, etc. Behind the scenes, the compiler internally runs `another` metaprogram at startup to compile the first workspace. This default metaprogram does things such as setting up the working directory for the compiler, setting the default name of the output executable based on command-line arguments, and changing between debug and release build based on command-line arguments.

This default metaprogram can be changed by adding `--- meta` followed by the file name of the metaprogram to replace the default, say `Metaprogram`. Here is an example for how to change the default metaprogram:
```
jai my_file.jai --- meta Metaprogram
```
or:  

```
jai my_file.jai --- import_dir "modules_folder" meta Metaprogram
```
where Metaprogram is a module, either in the default `jai/modules` folder or in a dedicated `modules_folder`. To make this module, create a folder Metaprogram, containing a file module.jai: this has to contain a `build()` and a `#run build()`. You can use modules/Minimal_Metaprogram as a start.

Jai does not operate like most other compilers that use a series of wacky command-line arguments in order to specify the program. Rather, Jai uses a metaprogram that does a compiler message loop to specify flags for the compiler. The flags are given to you as a struct. Here are a few helpful commandline arguments that can be useful when you are still programming at an ad hoc stage and do not want to write a formal metaprogram:
```
jai main.jai -x64     // this compiles the program with the fast x64 backend
jai main.jai -llvm    // this compiles the program with the llvm backend
jai main.jai -release // this compiles the program in release mode w/ llvm backend -O2 optimization
```

## Workspaces
A Workspace in Jai represents a completely separate environment, inside which we can compile programs. When the compiler starts up, it makes a Workspace for the first files that you tell it to compile on the commandline. Different Workspaces cannot refer to each others' namespaces, imported modules, etc; different workspaces are totally separate and encapsulated from each other. This allows you to run a bunch of code that uses global data, imports modules, and so forth inside one workspace, and these things do not affect the target program at all. You can compile separate target workspaces, and they will not affect each other at all.

A workspace can be created using `compiler_create_workspace`.
```
build :: () {
  w := compiler_create_workspace();
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  // ... other code
}
```

A build can instantiate multiple workspaces.
```
build :: () {
  ws1 := compiler_create_workspace("Workspace 1");
  // do build for workspace 1...

  ws2 := compiler_create_workspace("Workspace 2");
  // do build for workspace 2...

  ws3 := compiler_create_workspace("Workspace 3");
  // do build for workspace 3...
}

```

For a more detailed description of Workspaces, there is a great guide in the `how_to` called `how_to/400_workspaces.jai`.

### add_build_string
This function adds a string as a piece of code to the program. Do all sorts of complex string manipulation to create complex metaprogramming code, then add it to your build in string format. The first argument is a string, second argument is the workspace you want to add it to.

## Build options
To get the build options for the compiler, create a workspace with the function `compiler_create_workspace` and call `get_build_options` on the workspace created under `compiler_create_workspace`. Here is an example `build` function that demonstrates this:
```
#import "Basic";
#import "Compiler";

build :: () {
  w := compiler_create_workspace();
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  //...other code
}
```
The `Build_Options` struct contains many build options such as enabling/disabling array bounds check, setting the optimization level, switching the backend between LLVM and x64, changing the executable name, and setting the OS target. 

### Simple Build Options for highly optimized code
This snippet creates a highly optimized build. Optimized builds take a long time, but are around twice as fast as an unoptimized build.
```
set_optimization(*target_options, .OPTIMIZED);
```
### Target Build Options

The output type for `target_options` can be specified between no output, executable, dynamic library, and static library. By default, the output type is an executable.
```
target_options.output_type = .NO_OUTPUT;       // specifies no output for the compiler
target_options.output_type = .EXECUTABLE;      // specifies executable as an output for the compiler
target_options.output_type = .DYNAMIC_LIBRARY; // specifies output to be a dynamic library
target_options.output_type = .STATIC_LIBRARY;  // specifies output to be a static library
target_options.output_type = .OBJECT_FILE;     // specifies output to be an object file
```
Optimization levels can be toggled between debug and release.
```
target_options.optimization_level = .DEBUG;   // specifies the optimization level to be .DEBUG
target_options.optimization_level = .RELEASE; // specifies the optimization level to be .RELEASE
```
The different backend options can be toggled between -x64 and llvm as follows:
```
target_options.backend = .X64;  // specifies the x64 backend
target_options.backend = .LLVM; // specifies the llvm backend
```

Array bounds check can be changed through the `array_bounds_check` field.
```
target_options.array_bounds_check = .OFF; // turns off array bounds check
target_options.array_bounds_check = .ON;  // turns on array bounds check
target_options.array_bounds_check = .ALWAYS;
```

The build options for the llvm and x64 backends can be be set through the `x64_options` and `llvm_options` fields respectively.

### LLVM Options
The LLVM backend options contains many compiler options for optimizing code, turning features of LLVM on or off. Here is a list of some of the flags for the LLVM Options given the `target_options.llvm_options` struct.
```
.enable_tail_calls = false; 
.enable_loop_unrolling = false;
.enable_slp_vectorization = false; 
.enable_loop_vectorization = false; 
.reroll_loop = false; 
.verify_input = false; 
.verify_output = false;
.merge_functions = false;
.disable_inlining = true;
.disable_mem2reg = false;
```
The `-O3`, `-O2`, `-O1` optimization levels for LLVM can be changed by setting the `code_gen_optimization_level` field to 3, 2, 1 respectively. For example, `target_options.llvm_options.code_gen_optimization_level = 2` will set the LLVM options to `-O2`.

A more comprehensive set of compiler options and details can be found under `Compiler.jai`.

## Basic Compiler Metaprogram
This is the most basic, most minimal metaprogram you can create that is correct:
```
#import "Compiler";
#run {
  defer set_build_options_dc(.{do_output=false});
  w := compiler_create_workspace();
  options := get_build_options(w);
  options.output_executable_name = "my_executable";
  set_build_options(options, w);

  // add all your files here.
  add_build_file("main.jai", w);
}
```

## Compiler message loop
To do a basic and simple compiler message loop, create a workspace, call `compiler_begin_intercept`, add all the files you want to compile, run the compiler message loop, call `compiler_end_intercept`, and finally `#run build()`.

The following `build.jai` example code is the minimum code to run a basic compiler message loop:
```
#import "Basic";
#import "Compiler";

build :: () {
  w := compiler_create_workspace();
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  target_options.output_executable_name = "program";
  set_build_options(target_options, w);

  compiler_begin_intercept(w);
  // add all the files
  add_build_file(tprint("%/main.jai", #filepath), w);  
  while true {
    message := compiler_wait_for_message();
    if !message break;
    if message.kind == {
    case .COMPLETE;
      break;
    }
  }
  compiler_end_intercept(w);
  set_build_options_dc(.{do_output=false});
}

#run build();
```
Create a basic "Hello World" `main.jai` file.
```
#import "Basic";

main () {
  print("Hello World!!!\n");
}
```
These two files, `build.jai` and `main.jai` are enough to get a basic compiler message loop up and running.

## Compiler Messages
This is a list of possible messages that one can obtain from the compiler. Note that this is not all the messages. The message struct contains an enum marking the kind of message it is as well as the workspace. Check the kind of message using an if statement, and then cast the message to its appropriate kind of message. More information regarding compiler messages can be found at `Compiler.jai`

### File Message
This message triggers once for each source code file loaded during compilation.
```
message := compiler_wait_for_message();
if message.kind == .FILE {
  message_file := cast(*Message_File) message;
  print("Loading file '%'.\n", message_file.fully_pathed_filename);
}
```

### Import Message
This message triggers for each module that is imported. If the "Basic" module is imported 9 times, you only see this message one, since the compiler only imports it once.
```
message := compiler_wait_for_message();
if message.kind == .IMPORT {
  message_import := cast(*Message_Import) message;
  print("Import module '%'\n", message_import.module_name);
}
```

### Phase Message
This message triggers each time it advances through the various phases of compiler defined in the Message_Phase enum.
```
message := compiler_wait_for_message();
if message.kind == .PHASE {
  message_phase := cast(*Message_Phase) message;
  print("Entering phase %\n", message_phase.phase);
}

```
The phases of the compiler described in the Message_Phase enum are: 
```
phase: enum u32 {
  ALL_SOURCE_CODE_PARSED        :: 0;
  TYPECHECKED_ALL_WE_CAN        :: 1;
  ALL_TARGET_CODE_BUILT         :: 2;
  PRE_WRITE_EXECUTABLE          :: 3;
  POST_WRITE_EXECUTABLE         :: 4;
  READY_FOR_CUSTOM_LINK_COMMAND :: 5;
}
```

### Typechecked Message
This message triggers any time code has passed typechecking. The code can be inspected, searched for things, modified.
```
message := compiler_wait_for_message();
if message.kind == .TYPECHECKED {
  message_typechecked := cast(*Message_Typechecked) message;
  print("% declarations have been typechecked\n", message_typechecked.count);
  for message_typechecked.declarations {
    print("Code declaration: %\n", it);
  }
}
```

### Error Message
This message triggers if an error occurs during compilation
```
message := compiler_wait_for_message();
if message.kind == .ERROR {
  // handle error
}
```

### Debug Dump Message
This message triggers if a debug dump occurs
```
message := compiler_wait_for_message();
if message.kind == .DEBUG_DUMP {
  dump_message := cast(*Message_Debug_Dump) message;
  print("Here is the dump text: %\n", dump_message.dump_text);
}

```

### Complete Message
This message triggers when compilation is finished.
```
message := compiler_wait_for_message();
if message.kind == .COMPLETE {
  // do something that breaks out of the compiler message loop.
}
```

## Notes
Notes are a way to tag a `struct`, `function`, or `struct member`. Notes are represented as strings. This tag will show up in a metaprogram. In the metaprogram, you can use the note to do special metaprogramming such custom program typechecking and modifying the executable based on the metaprogram. Notes in Jai are represented as `strings`, and unlike Java or C#, are not structured (but structured notes may be added in the future).

You cannot use notes to tag statements or parameters.

Here is a simple metaprogram that finds all the functions tagged `@note` and creates a `main` function that calls all functions tagged `@note` in alphabetical order.

Metaprogram `build.jai`:
```
#run {
  w := compiler_create_workspace();

  options := get_build_options(w);
  options.output_executable_name = "exe";
  set_build_options(options, w);

  compiler_begin_intercept(w);
  add_build_file("main.jai", w);  

  // find all functions tagged @note, sort all functions alphabetically,
  // and call all functions in alphabetical order from a generated "main"
  functions: [..] string;
  gen_code := false;
  while true {
    message := compiler_wait_for_message();
    if !message break;
    if message.kind == {
    case .TYPECHECKED;
      typechecked := cast(*Message_Typechecked) message;
      for decl: typechecked.declarations {
        if equal(decl.expression.name , "main") {
          continue;
        }

        for note: decl.expression.notes {
          if equal(note.text, "note") {
            array_add(*functions, copy_string(decl.expression.name));
          }
        }

      }
    case .PHASE;
      phase := cast(*Message_Phase) message;
      if gen_code == false && phase.phase == .TYPECHECKED_ALL_WE_CAN {
        code := generate_code();
        add_build_string(code, w);
        gen_code = true;
      }

    case .COMPLETE;
      break;
    }
  }
  compiler_end_intercept(w);
  set_build_options_dc(.{do_output=false});

  generate_code :: () -> string #expand {
    bubble_sort(functions, compare);
    builder: String_Builder;
    append(*builder, "main :: () {\n");
    for func: functions {
      print_to_builder(*builder, "  %1();\n", func);
    }
    append(*builder, "}\n");
    return builder_to_string(*builder);
  }

}

#import "Compiler";
#import "String";
#import "Basic";
#import "Sort";
```

The main program `main.jai`:

```
dog :: () {
  print("dog\n");
} @note

banana :: () {
  print("banana\n");
} @note

apple :: () {
  print("apple\n");
} @note

cherry :: () {
  print("cherry\n");
} @note

elephant :: () {
  print("elephant\n");
} @note

#import "Basic";

// create the main() function using the metaprogram.
```

## Debug and production builds
### Introduction
The following code is an example of how to do simple debug and release builds. Note that there are multiple ways to do this, and that this is just a simple pseudo-code example for how to do it.
```
#import "Basic";
#import "Compiler";

build_debug :: () {
  // insert debug compile options here...
}

build_release :: () {
  // insert release compile options here...
}

#run build_debug(); // change this to 'build_release' to do the release build
```
Import the `Basic` and `Compiler` module, then create `build_debug` and `build_release` functions. Put your choice of compiler options inside the `build_debug` and `build_release` functions respectively. Finally, run the specific build you want by doing `#run build_debug() or `#run build_release();`.

### Obtain Compiler Command-line Arguments
To obtain command-line arguments from compile-time, we can use `args := target_options.compile_time_command_line;`. From there, we can use the compiler command-line to toggle between debug and release build.

```
#import "Compiler";

#run {
  options := get_build_options();
  args := options.compile_time_command_line;
  for arg : args {
    if arg == {
    case "debug";
      build_debug();
    case "release";
      build_release();
    }
  }
}
```

To toggle between debug and release build from the command-line, do the following for debug and release:
```
jai build.jai -- debug
jai build.jai -- release
```

### Recommended debug options
These are some recommended options for a debug build to make the compiler compile faster with as much debugging information, but has some overhead in order to help debug. An executable built in debug mode will, for example, tell the programmer on which line of code the program crashed on, and check for array out of bounds errors. As expected from debug builds, the code is not as optimized as a release build.
```
target_options := get_build_options(w);
target_options.backend =.X64; // this is the fast backend, LLVM is slower
target_options.optimization_level = .DEBUG;
target_options.array_bounds_check = .ON; // this is on by default
set_build_options(target_options, w);
```
### Recommended release options
These are some recommended options for a release build to make the compiler optimize code to produce the best possible optimized code. An optimized build does not have debug information built into release build, and takes longer to compile.
```
target_options := get_build_options(w);
target_options.backend = .LLVM;
set_optimization(target_options, .OPTIMIZED);
set_build_options(target_options, w);
```
## Running tests
The following code is an example of how to do simple testing. The sat_solver takes a `*.cnf` file, tells whether the answer is sat or unsat. This is not the definitive way of testing things, but it is a simple way of getting started.

The program we are designing is a simple program: take an input file from the command-line, and return an exit code depending on whether the answer is yes or no. In our `build.jai` script, we write a `test :: ()` function to run the executable, check the error code, and tell whether the exit code is correct or not.

Here is the pseudo-code skeleton for our code:

```
#import "Basic";
#import "File";

main :: () {
  args := get_command_line_arguments();
  file_name := args[0];
  text_from_file := read_entire_file(file_name=file_name);

  // do something with the file contents
  if success {
     exit(0);
  } else {
     exit(1);
  }
}

```

In our `build.jai`, we use `run_command` inside the `#import "Process"` module to run the executable, and check the error code. If the error code matches the expected error code, we report success, else report error.
```
#import "Process";
test :: () {
  EXE_NAME := ... // put the name of the executable here...
  EXE_PATH := tprint("%1/%2", #filepath, EXE_NAME);
  file_to_test := "my_test_file.txt";
  success, exit_code := run_command(EXE_PATH, file_to_test);
  if !success then
    print("Error. test failed.\n");
  if exit_code matches expected_exit_code, then
    print("Success! The test has been successful!!!!\n");
  else
    print("Test failed ...\n");
}
```

When you want to run a test, put a `#run test();`;

## Enforcing house rules

The compile-time metaprogram can be used to do all sorts of arbitrary custom compile-time error checking and code modification. The compile-time metaprogram can be used to enforce `house rules`. Because these `house rules` apply only to specific instances, it does not make sense to build `house rules` into a general purpose compiler.

### Compile-Time MISRA Checking: Check for Multiple Levels of Pointer Indirection

The compile-time metaprogram can be used, for example, to check that a program adheres to the MISRA coding standards. MISRA coding standards are a set of C and C++ coding standards, developed by the Motor Industry Software Reliability Association (MISRA). These are standards specific to the automotive industry, and these should not be part of a general purpose compiler. However, a custom compile-time metaprogram can check adherence to the MISRA coding standard.

In this example, we want to check that a `Jai` program adheres to the MISRA coding rule that prevents use multiple levels of pointer indirection (e.g. you cannot do `a: ***int = b;`).

Let's create a metaprogram that makes compiler errors when you do multiple levels of pointer indirection:
```
#import "Basic";
#import "Compiler";

#run build();

build :: () {
    // Create a workspace for the target program.
    w := compiler_create_workspace("Target Program");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    target_options := get_build_options(w);
    target_options.output_executable_name = "checks";
    set_build_options(target_options, w);

    compiler_begin_intercept(w);
    add_build_file("main.jai", w);

    while true {
        message := compiler_wait_for_message();
        if !message break;
        misra_checks(message);

        if message.kind == .COMPLETE  break;
    }

    compiler_end_intercept(w);

    // This metaprogram should not generate any output executable:
    set_build_options_dc(.{do_output=false});
}

misra_checks :: (message: *Message) {
    if message.kind != .TYPECHECKED return;
    code := cast(*Message_Typechecked) message;
    for code.declarations {
        decl := it.expression;
        check_pointer_level_misra_17_5(decl);
    }

    for tc: code.all {
        expr := tc.expression;
        if expr.enclosing_load {
            if expr.enclosing_load.enclosing_import.module_type != .MAIN_PROGRAM  continue;
        }
        
        for tc.subexpressions {
            // Check rule 17.5. We already did the pointer-level check for global declarations
            // but, local declarations don't come in separate messages; instead, we check them here.
            if it.kind == .DECLARATION {
                sub_decl := cast(*Code_Declaration) it;
                check_pointer_level_misra_17_5(sub_decl); 
            }
        }
    }

    check_pointer_level_misra_17_5 :: (decl: *Code_Declaration) {
        type := decl.type;
        pointer_level := 0;
    
        while type.type == .POINTER {
            pointer_level += 1;
            p := cast(*Type_Info_Pointer) type;
            type = p.pointer_to;
        }
        if pointer_level > 2 {
            location := make_location(decl);
            compiler_report("Too many levels of pointer indirection.\n", location);
        }
    }

}
```

Create a `main.jai` to test that our compile-time metaprogram can correctly check for pointer indirection.
```
main :: () {
  a: *int;
  b := *a;
  c := *b; // Too many levels of pointer indirection! c is of Type (***int)
}
```

When we run the metaprogram, we get the following error message:
```
main.jai:6,3: Error: Too many levels of pointer indirection.
```

There is a more detailed example in the how_tos under `480_custom_checks`

## Generating and Using LLVM Bitcode

In the compiler build options, under the LLVM build options, the compiler can output LLVM bitcode by doing:
```
llvm_options.output_bitcode = true;
```

By default, the bitcode is outputted to the **.build** folder. However, one can change where the bitcode is outputted by changing the intermediate path of the compiler:
```
target_options.intermediate_path = #filepath;
```
By setting the intermediate path to whatever you want, you can change where the bitcode files end up at.

Here is a simple compiler message loop example of how to generate LLVM bitcode:
```
#import "Basic";
#import "Compiler";

#run {
  w := compiler_create_workspace("workspace_1");
  if !w {
    print("Workspace creation failed.\n");
    return;
  }
  target_options := get_build_options(w);
  target_options.output_executable_name = "executable";
  target_options.intermediate_path = #filepath;
  set_optimization(*target_options, .OPTIMIZED); 
  target_options.llvm_options.output_bitcode = true;
  set_build_options(target_options, w);

  compiler_begin_intercept(w);
  add_build_file("main.jai", w);  

  while true {
    message := compiler_wait_for_message();
    if !message break;
    if message.kind == {
    case .COMPLETE;
      break;
    }
  }
  compiler_end_intercept(w);
  set_build_options_dc(.{do_output=false});
}
```
Create a simple `main.jai` program that prints "Hello World!". Now your build script can generate LLVM bitcode.
```
#import "Basic";
main :: () {
  print("Hello World\n");
}
```

## Generating Assembly Language from LLVM
To install LLVM on your Linux Ubuntu machine, you can use the following Linux commands:
```
sudo apt install llvm
```
If you have LLVM installed on your Linux Ubuntu machine, you can use the commands:
```
llc < your_bitcode.bc > output.asm
as output.asm
```
to transform the program into assembly language. The **llc** command transforms your bitcode into the assembly language on your machine, and the **as** command compiles that assembly language into binary machine language.

## Programming LLVM Options

The optimizations that LLVM makes and the code generated by LLVM can be controlled using LLVM command-line options. These command-line options can be set using the build options of the compiler metaprogram.

Here is how to interface with LLVM from the metaprogram:

```
executable_name :: "program";
w := compiler_create_workspace(executable_name);
target_options := get_build_options(w);
target_options.output_executable_name = executable_name;
target_options.optimization_level = .RELEASE;
target_options.llvm_options.command_line = string.[executable_name, "--help"];
```

In this example, we interact with LLVM, and ask LLVM for it's command line interface by sending the `--help` flag. You can find documentation about communicating with LLVM through: https://llvm.org/docs/CommandGuide/llc.html. Note that the LLVM backend that comes with Jai might be a different version than the one provided in the documentation, so the command line interface might be different.

### LLVM Commandline Example
This LLVM commandline example says the name of the executable is "executable",  the computer architecture is `x86-64`, use a greedy register allocation scheme, and assume that there are no infinite values when doing floating point arithmetic.
```
ARGUMENTS := string.[
   "executable",
   "-march=x86-64"
   "--regalloc=greedy",
   "--enable-no-infs-fp-math",
   "--enable-no-nans-fp-math",
   "--enable-no-signed-zeros-fp-math",
   "--enable-no-trapping-fp-math",
   "--enable-unsafe-fp-math"
];

target_options.llvm_options.command_line = ARGUMENTS;
```

### Getting Human Readable LLVM IR
You can get the compiler to output somewhat readable LLVM IR using the following command:
```
workspace := compiler_create_workspace();
options := get_build_options(workspace);
options.llvm_options.output_llvm_ir = true;
set_build_options(options, w);
```

### LLVM Intrinsics
LLVM intrinsics can be called directly given the LLVM backend. This does not work for the x64 backend. These intrinsics can be used to target platforms not well supported by Jai.

You can find a list of LLVM supported intrinsics [here](https://llvm.org/docs/LangRef.html)

Anything prefixed "llvm" is an LLVM intrinsic.

```
reverse :: (x: u64) -> u64 #intrinsic "llvm.bitreverse.i64";
memcpy :: (dest: *void, src: *void, size: int) #intrinsic "llvm.memcpy.p0.p0.i64";
```

