# Snippets / Benchmarks

This is a miscellaneous collection of code-examples and snippets that might be useful in your development.

Benchmarks are code examples created by the Jai Community to stress test the Jai Compiler in terms of code generation quality. If a Jai Beta Community member feels their Jai Programming Language Project is a good stress test of the language, feel free to put up a benchmark of language. Benchmarks generally give a summary of the program, how the code generation is measured, and description of the program.

To see a much more comprehensive collection of Jai examples, see [The Encyclopedia of Jai Examples](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples).

## Functions / Macros

### Swap

Swap can be done using `a, b = b, a;`. This also works for longer sequences with arbitrary permutations. All right hand side values are evaluated in the first pass, and then assignments are done to the left hand side values on the second pass.

### Blocking Console Input

If you want a blocking input in the Windows console, use this:
```
#import "Windows";

kernel32 :: #system_library "kernel32";

stdin, stdout  : HANDLE;

ReadConsoleA  :: (
    hConsoleHandle: HANDLE, 
    buff : *u8, 
    chars_to_read : s32,  
    chars_read : *s32, 
    lpInputControl := *void 
) -> bool #foreign kernel32;

input :: () -> string {
    MAX_BYTES_TO_READ :: 1024;
    temp : [MAX_BYTES_TO_READ] u8;
    result: string = ---;
    bytes_read : s32;
    
    if !ReadConsoleA( stdin, temp.data, xx temp.count, *bytes_read )
        return "";

    result.data  = alloc(bytes_read);
    result.count = bytes_read;
    memcpy(result.data, temp.data, bytes_read);
    return result;
}

main :: () {
    stdin = GetStdHandle( STD_INPUT_HANDLE );
    str := input();
}
```
Don't forget to remove the carriage return (e.g. `"\r"`, CR) at the end of lines.

If you want a blocking input in the Linux console, this is the corresponding Linux console input example:
```
#import "Basic";
#import "POSIX";

main :: () {
  buffer: [4096] u8;
  bytes_read := read(STDIN_FILENO, buffer.data, buffer.count-1);
  str := to_string(buffer.data, bytes_read);
  print("Here is the string from console input: %\n", str);
}
```

## Debugging

### Ad-Hoc print debugging
Sometimes, you want to find bugs in your program in the old-fashioned way: print debugging. Using a print and a defer print statement, you can locate the bug line quickly.

```
function_with_bug :: () {
  print("Entering function_with_bug :: ()\n");
  defer print("Exiting function_with_bug :: ()\n");
}
```

### Quick and Dirty Bytecode Debugger
Jai has a simple bytecode debugger. This bytecode debugger can be accessed by doing `jai -debugger main.jai`. To debug your entire program in the bytecode debugger, you can do `#run main()`.


## Metaprogramming

### Unrolling Loops
Sometimes, one might want to unroll loops to optimize a program's execution speed so that the program does less branching. Loops can be unrolled through a mixture of `#insert` directives and macros. In this example below, we unroll a basic for loop that counts from 0 to 10.
```
unroll_for_loop :: (a: int, b: int, body: Code) #expand {
  #insert -> string {
    builder: String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);

    append(*builder, "{\n");
    append(*builder, "    `it: int;\n");
    for a..b {
      print_to_builder(*builder, "    it = %;\n", it);
      append(*builder, "    #insert body;\n");
    }
    append(*builder, "}\n");
    return builder_to_string(*builder);
  }
}


unroll_for_loop(0, 10, #code {
  print("%\n", it);
});
```

### for_each_member
A quick helper to create some code for each member in a structure. (Not recursive)

```
// %1          = member name
// type_of(%1) = member type
for_each_member :: ($T: Type, format: string) -> string
{
    builder: String_Builder;
    defer free_buffers(*builder);

    struct_info := cast(*Type_Info_Struct) T;
    assert(struct_info.type == Type_Info_Tag.STRUCT);

    for struct_info.members 
    {
        if it.flags & .CONSTANT continue;

        print_to_builder(*builder, format, it.name);
    }

    return builder_to_string(*builder);
}
```

Usage:
```
serialize_structure :: (s: $T, builder: *String_Builder) -> success: bool
{
    #insert #run for_each_member(T, "if !serialize(s.%1, builder) return false;\n" );
    return true;
}
serialize  :: (to_serialize: int, builder: *String_Builder) -> success: bool { return true; } // @Placeholder
serialize  :: (to_serialize: u16, builder: *String_Builder) -> success: bool { return true; } // @Placeholder

main :: ()
{
    Player :: struct
    {
        status: u16;
        health: int;
    }
    p: Player;
    
    builder: String_Builder;
    defer free_buffers(*builder);

    success := serialize_structure(p, *builder);
}
```

Adds the following to the polymorphic serialize_structure(Player, *String_Builder) function
```
if !serialize(s.status, builder) return false;
if !serialize(s.health, builder) return false;
```

### Adding Import Path to Compiler

If you want to import custom modules in another directory than the compiler modules:

```
options := Compiler.get_build_options();
import_path: [..] string;
Basic.array_add(*import_path, ..options.import_path);
Basic.array_add(*import_path, "/my/own/path/modules");
options.import_path = import_path;
Compiler.set_build_options(options, workspace);
```

### Bake structs
You can't directly bake a struct at compile time; the closest you can get is to compute the struct then stash its memory representation, and then retrieve it at runtime:

```jai
#import "Basic";
 
 
Foo :: struct {
    x : int;
}
 
foo : Foo;
foo_data :: #run bake_as_u8(make_struct());
 
make_struct :: () -> Foo {
    // compute a struct
    return Foo.{12};
}

bake_as_u8 :: (value : $T) -> [] u8 {
    array : [size_of(T)] u8;
    memcpy(*array, *value, size_of(T));
    return array;
}
 
restore_from_u8 :: (dest: *$T, data: [] u8) {
    value : T;
    memcpy(dest, data.data, size_of(T));
}
 
init :: () {
    restore_from_u8(*foo, foo_data);
}
 
main :: () {
    init();
    print("% % %\n", foo, foo.x, type_of(foo));
}
```

### Writing and loading dynamic libraries
Build.jai:

```
// build.jai
#import "Basic";
#import "Compiler";

build :: ()
{
    // Build the dll
    {
        w := compiler_create_workspace();
        options := get_build_options(w);
        options.output_type = .DYNAMIC_LIBRARY;
        options.output_executable_name = "dll";
        set_build_options(options, w);

        compiler_begin_intercept(w);
        add_build_file("dll.jai", w);
        while true {
            message := compiler_wait_for_message();
            if !message || message.kind == .COMPLETE  break;
        }
        compiler_end_intercept(w);
    }

    // Build the exe after 
    {
        w := compiler_create_workspace();
        options := get_build_options(w);
        options.output_executable_name = "main";
        set_build_options(options, w);
        add_build_file("main.jai", w);
    }

    set_build_options_dc(.{do_output=false});
}

#run build();
```

dll.jai:

```
//dll.jai
#import "Basic";

// Add #c_call and push a fresh context here if you plan on calling this from another language
#program_export dll_func :: () #c_call {
    new_context: Context;  
    push_context new_context {
        print("Hello Sailor");
    }
}
```

main.jai

```
//main.jai
#import "Basic";

main :: ()
{
    dll_func();
}

dll_func :: () #foreign dll #c_call;
dll :: #library "dll";
```

### Build-script with inlining enabled

The following is a minimal build-script that enables inlining (via `inline`).
Compile your program, e.g. `main.jai`, via `jai build.jai - main`.

```
#import "Basic";
#import "Compiler";

#run build();

build :: () {
    w := compiler_create_workspace("Target Program");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }
    
    options := get_build_options(w);

    args := options.compile_time_command_line;
    print("\nargs: %\n", args);
    filename := args[2];

    options.output_executable_name = filename;
    
    // activate inlining
    options.enable_bytecode_inliner = true;
    
    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file(sprint("%.jai", filename), w);
    message_loop();
    compiler_end_intercept(w);

    set_build_options_dc(.{do_output=false});
}

message_loop :: () {
    while true {
        message := compiler_wait_for_message();

        if message.kind == {
            case .COMPLETE;
                break;
        }
    }
}
```

### Detect if variable is on Stack

J. Blow: _There is no “the heap”, as there are many allocators with their own heaps. If you knew what all the allocators were, you might be able to ask them if it’s in their memory (which we do not provide at this time for the default allocator)._
_Asking if a variable is on the stack is easier. We were going to add a stack-range-reporting intrinsic, but, it’s not really necessary for stuff like this. You just take an address of a local variable at startup, and have your “is this thing on the stack” take an address of its own local variable, and ask if the target address is between those two locations._

Ville : _You could even store that address into context so that you can easily access it everywhere and point to thread own stack._

```
#import "Basic";

#add_context stack_base: *void;

init_stack_checker :: () #expand {
    stack_value: u8;
    context.stack_base = *stack_value;
}

is_in_stack :: (pointer: *void) -> bool {
    stack_value: u8;
    return pointer > *stack_value && pointer < context.stack_base;
}

main :: () {
    init_stack_checker();

    value: int;
    print("value: %\n", is_in_stack(*value));

    external := New(int);
    defer free(external);
    print("external: %\n", is_in_stack(external));
}
```
J. Blow: _The only caveat here being, if you start a new thread you need to call `init_stack_checker()` on that thread. To catch this, it’s probably good to `assert(context.stack_base != null)` inside `is_in_stack()`._

## Assembly Language

### BLSR - Reset Lowest Set Bit
`BLSR`, or Reset Lowest Set Bit, is an instruction that copies all bits from the source into the destination, and sets the least significant bit to zero. This is equivalent to `a &= a-1`.
You can find more information on `BLSR` [here](https://www.felixcloutier.com/x86/blsr).

```
popbit :: (a: u64) -> u64 #expand {
  #asm { blsr.q a, a; }
  return a;
}
```
Here is an example of using `BSLR`.
```
a: u64 = 0xFF;
print("%\n", formatInt(a, 2));
a = popbit(a);
print("%\n", formatInt(a, 2));
a = popbit(a);
print("%\n", formatInt(a, 2));
a = popbit(a);
print("%\n", formatInt(a, 2));
```
When we run this code, we get:
```
11111111
11111110
11111100
11111000
```

### Reversing 64-bits using Inline Assembly
This is some code to reverse a 64-bit integer, translated from an objdump on a clang intrinsic. `movabs` can be replaced by a `mov.q`.

```
bit_reverse64  :: (x: u64) -> u64 #expand {
  // Modified from clang objdump
  rdi: u64 = x;
  rax, rcx, rdx: u64;
  #asm {
    bswap.q   rdi;
    mov.q     rax, 1085102592571150095;
    and.q     rax, rdi;
    shl.q     rax, 4;
    mov.q     rcx, -1085102592571150096;
    and.q     rcx, rdi;
    shr.q     rcx, 4;
    or.q      rcx, rax;
    mov.q     rax, 3689348814741910323;
    and.q     rax, rcx;
    mov.q     rdx, -3689348814741910324;
    and.q     rdx, rcx;
    shr.q     rdx, 2;
    lea.q     rax, [rdx + rax*4];
    mov.q     rcx, 6148914691236517205;
    and.q     rcx, rax;
    mov.q     rdx, -6148914691236517206;
    and.q     rdx, rax;
    shr.q     rdx;
    lea.q     rax, [rdx + rcx*2];
  }
  return rax;
}
```

### Intel Intrinsic SIMD translation
There is some Intel Intrinsic SIMD code that is easy to translate into the Jai inline assembly language. However, there are some examples where this can be difficult, especially when the Intel Intrinsic does not come with a corresponding SIMD instruction. This is a list of some difficult to translate instructions, and an effective way of translating them.


### _mm256_set1_epi32
The Intel Intrinsic Instruction `_mm256_set1_epi32` initializes 256-bit vector with scalar integer values. This instruction does not corresponding to any Intel AVX instruction. 

The following C++ SIMD code snippet: 
```
#include <immintrin.h>
int value = 1;
auto vector = _mm256_set1_epi16(value);
```
can be translated into:
```
#asm AVX, AVX2 {
  movd xmm0: vec, value;
  pbroadcastw vector: vec, xmm0; 
}
```
The `movd` assembly instruction transfers `value` into the xmm0 vector register, and `pbroadcastw` takes the `xmm0` and broadcasts it to the rest of the values.

## Concurrency

### Go style channels
This is a super simple example of Go-style blocking channels. Note that this channel implementation is so simplistic it doesn't do any locking. It should work fine in certain situations but you may want to add locking.

These channels are bounded, synchronous, blocking, and optionally buffered. To turn off buffering, set n=1. It is obviously meaningless to set n=0.

```
Channel :: struct(T: Type, n: u64) {
    buffer      : [n]T;
    writeidx    : u64 = 0;
    readidx     : u64 = 0;
    unread      : u64 = 0;
}

channel_write :: (using c: *Channel($T, $n), data: T) {
    while unread == buffer.count sleep_milliseconds(50);

    buffer[writeidx] = data;
    writeidx = (writeidx + 1) % buffer.count;
    unread += 1;
}

channel_read :: (using c: *Channel($T, $n)) -> T {
    while unread == 0 sleep_milliseconds(50);

    val := buffer[readidx];
    readidx = (readidx + 1) % buffer.count;
    unread -= 1;
    return val;
}

channel_write_array :: (c: *Channel($T, $n), data: []T) {
    // Note: This will block if the channel buffer is full.
    for data channel_write(c, it);
}

channel_read_all :: (c: *Channel($T, $n)) -> [..]T {
    // Note: This will read everything there is currently in the channel.
    out : [..]T;

    while c.unread > 0 array_add(*out, channel_read(c));
    return out;
}

channel_reset :: (c: *Channel($T, $n)) {
    c.unread = 0;
}
```
Obviously, you probably want to use these in a multithreaded situation, and if you use it uncareful you might end up hanging. But here's a single-thread linear example:
```
d : Channel(int, 20);

print("channel d has buffer of %\n", d.buffer.count);

channel_write(*d, 1);
print("Read from d: %\n", channel_read(*d));
channel_write(*d, 2);
print("Read from d: %\n", channel_read(*d));
channel_write(*d, 3);
channel_write(*d, 4);
print("Read from d: %\n", channel_read(*d));
channel_write(*d, 5);
print("Read from d: %\n", channel_read_all(*d));

channel_write_array(*d, int.[10, 20, 30]);
print("Read from d: %\n", channel_read(*d));
channel_reset(*d);
print("Read from d: %\n", channel_read_all(*d));
```

## Function and Struct Polymorphism

### Trait

Code to implement a simple trait in Jai. This kind of trait is limited and only works during compile time. Dynamic virtual function type traits are not supported.
```
Trait :: struct(T: Type, func: #type (*T)) {

}

Object :: struct {
  x: float;
  y: float;
  z: float;
  using #as trait: Trait(Object, function);
}

function :: (object: *Object) {
  print("object.x = %\n", object.x);
  print("object.y = %\n", object.y);
  print("object.z = %\n", object.z);
}

do_something :: (thing: *Trait) {
  func :: thing.func;
  func(thing);
}
```

A user can call `do_something` on the object, and the trait gives a good compile-time type checking to the `trait`.
```
object: Object;
object.x = 1;
object.y = 2;
object.z = 3;
do_something(*object);
```

### Macro: Cast to derived function overload

The `specialize` macro allows to automatically cast the pointer of a "general" struct to the specialized versions at runtime and call their overloaded functions, see the example below:
```
#import "Basic";
#import "String";

Types :: Type.[Foo, Zap];

Base :: struct {
    b_type: Type;
}
do_sth :: (b: *Base) {
    #insert #run specialize(Types, "do_sth", type_var="b_type");
}
bar :: (base: *Base, msgs: []string) -> bool {
    #insert #run specialize(Types, "bar", .["msgs"], 1, "base", "b_type");
}


Foo :: struct {
    using _b : Base;
}
foo :: () -> *Foo {
    res := New(Foo);
    res.b_type = Foo;
    return res;
}
do_sth :: (f: *Foo) {
    print("Foo!!!\n");
}
bar :: (f: *Foo, msgs: []string) -> bool {
    for msgs {
        print("Foo: %\n", it);
    }
    return true;
}


Zap :: struct {
    using _b : Base;
}
zap :: () -> *Zap {
    res := New(Zap);
    res.b_type = Zap;
    return res;
}
do_sth :: (f: *Zap) {
    print("Zap!!!\n");
}
bar :: (f: *Zap, msgs: []string) -> bool {
    for msgs {
        print("Zap: %\n", it);
    }
    return true;
}


main :: () {
    f := foo();
    b := cast(*Base)f;
    do_sth(b); 
    bar(b, .["hello", "world"]);

    z := zap();
    b = cast(*Base)z;
    do_sth(b); 
    bar(b, .["hello", "world"]);
}


specialize :: (
    enum_array: []Type, 
    fct_name: string, 
    other_fct_args: []string = .[], 
    num_return_vars: int = 0,
    base: string = "b", 
    type_var: string = "type"
) -> string {
    builder : String_Builder;
    print_to_builder(*builder, "if %.% == {\n", base, type_var);

    for enum_array {
        print_to_builder(*builder, "    case %;\n", it);
        print_to_builder(*builder, "        s := cast(*%)%;\n", it, base);
        if num_return_vars != 0 {
            append(*builder, "        ");
            for i: 0..num_return_vars-1 {
                print_to_builder(*builder, "v%", i);
                if i != num_return_vars-1 then
                    append(*builder, ", ");
            }
            print_to_builder(*builder, " := %(s", fct_name);
            if other_fct_args.count != 0 {
                append(*builder, ", ");
                for a, ia: other_fct_args {
                    print_to_builder(*builder, "%", a);
                    if ia != other_fct_args.count-1 then 
                        append(*builder, ", ");
                }
            } 
            append(*builder, ");\n");

            append(*builder, "        return ");
            for i: 0..num_return_vars-1 {
                print_to_builder(*builder, "v%", i);
                if i != num_return_vars-1 then
                    append(*builder, ", ");
            }
            append(*builder, ";\n");
        } else {
            append(*builder, "        ");
            print_to_builder(*builder, "%(s", fct_name);
            if other_fct_args.count != 0 {
                append(*builder, ", ");
                for a, ia: other_fct_args {
                    print_to_builder(*builder, "%", a);
                    if ia != other_fct_args.count-1 then 
                        append(*builder, ", ");
                }
            } 
            append(*builder, ");\n");
        }
    }

    append(*builder, "}\n");

    res := builder_to_string(*builder);
    print(res);
    return res;
}
```

### MACRO - Modify Require

Require a polymorphic function to take parameters of a specific type.

```
ModifyRequire :: (t: Type, kind: Type_Info_Tag) #expand {
    `return (cast(*Type_Info)t).type == kind, tprint("T must be %", kind);
}

foo :: (t: $T) #modify ModifyRequire(T, .ENUM) {
}

Bar :: enum {
    ASD;
}

foo(123); // triggers `Error: #modify returned false: T must be ENUM`
foo(Bar.ASD);
```

## Benchmarks

A set of Jai community project benchmarks. Benchmarks are code examples created by the Jai Community to stress test the Jai Compiler in terms of code generation quality. If a Jai Beta Community member feels their Jai Programming Language Project is a good stress test of the language, feel free to put up a benchmark of language. Benchmarks generally give a summary of the program, how the code generation is measured, and description of the program. Ideally, try to compare a Jai program against a similar C program.

### Ceij (Chess Engine in Jai)
This Chess Engine is a state of the art open source chess AI that uses the Minimax Algorithm with Alpha Beta Pruning, just like [Stockfish](https://en.wikipedia.org/wiki/Stockfish_(chess)). This engine uses Efficiently Updatable Neural Networks (NNUE) to evaluate chess positions, and a small handcrafted evaluation for trivial endgames. Because both use the same neural network architecture for the evaluation function, one can compare Ceij to Stockfish one-to-one. It has to be noted that Stockfish will be faster because it uses a hybrid NNUE and handcrafted evaluation approach that makes it faster in some circumstances, while Ceij uses NNUE only and handcrafted evaluation only works for trivial endgames. Stockfish, of course, has more developers working on it, and Ceij may or may not be fully optimized.

As a bitboard chess engine, this serves to measure how well Jai can optimize bit manipulation, as well as optimizing assembly code such as `blsr` (reset lowest set bit), `bsf` (bit scan forward), `popcount`. Since neural networks use matrix multiplication, Ceij supports CPU with no special SIMD as well as CPUs with AVX2 support. SIMD Jai support for NNUE matrix multiplication is implemented using Jai inline assembly.

This Chess Engine was written in around 10,000 lines of code, with modules included, it is around 40,000 lines of code.

#### Perft

[Perft](https://www.chessprogramming.org/Perft) is a debugging technique used to find move generation bugs within a chess engine as well as test the performance of move generation. The move generation code is incredibly important to Minimax Alpha Beta algorithms since a slow move generator will drastically slow down the engine when trying to evaluate millions of nodes.

Ceij and Stockfish use around the same move generation techniques, with small variations of the same algorithm. Ceij uses a legal move generator exclusively, while Stockfish uses pseudo-legal move generation. Here are some of the similar implementation details shared between both engines:
* Fancy Magic Bitboards using `pext` instruction
* 64-bit bitboards used to represent 64 squares
* Bit manipulation
* Zobrist Hashing
* 16-bit Move Encoding
* Using `bit_scan_forward` and `blsr` assembly instructions to serialize bits

Here are some perft results comparing `Ceij` against other engines in terms of time to complete the perft. Lower the number, the less time it takes to complete the perft, and the faster the engine is. This test was done on an Intel Core i5-9600K CPU with 3.70GHz, 6 cores.
|Engine                                                   | Starting Position Perft 7 | Kiwipete Perft 6  |
|---------------------------------------------------------|---------------------------|-------------------|
|[Stockfish 15](https://stockfishchess.org/)              |14.611 seconds             | 35.284 seconds    |
|[Ceij](https://github.com/danieltan1517/chess-jai)       |11.885 seconds             | 24.762 seconds    |
|[Berserk](https://github.com/jhonnold/berserk)           |12.312 seconds             | 30.415 seconds    |

`Ceij` has a faster move generation than `Stockfish` given both use similar algorithms. This means that in terms of regular, non-SIMD, serial code that adds two singular values together, Jai code generation is almost equivalent to C code.

#### Minimax and Search Speed

As a Minimax Algorithm, this program simulates as many chess positions as possible, and evaluates the point score of that particular position using a Neural Network. The better the Nodes per Second, the more positions it evaluates, and the faster the program is. All arithmetic is integer arithmetic, and does **not** use floating point numbers in critical sections of the code.

The following data was taken from the starting position after running `Stockfish` and `ceij` engine for 1 minute using an Intel Core i5-9600K CPU with 3.70GHz, 6 cores. To reproduce the same results on your machine, just open up the engine(s), then type `go movetime 60000`, which tells a UCI chess engine to think for 60,000 ms.

|Engine|Programming Language|SIMD|Nodes per Second|elo|
|------|--------------------|----|----------------|------|
|Stockfish 15|C++|AVX2|1190739|3534|
|Ceij        |Jai|AVX2|1463542|3100|

As one can see, `Ceij` has the same performance speed as `Stockfish`. Comparing Jai to the C implementation, the C implementation makes use of intrinsics to implement SIMD instructions, while the Jai code is inline assembly. The C Intrinsics rely on the compiler optimizing the code magically and transforming it into fast code. The C compiler is moving around and optimizing the intrinsics in complex ways. Originally, `Ceij` was 8% slower than `Stockfish`. However, explicitly optimizing the Jai inline assembly by hand instead of relying on the Jai compiler to optimize the code made `Ceij` just as fast as `Stockfish`.

Here is a link to the [code](https://github.com/danieltan1517/chess-jai)

#### Summary

For regular, non-SIMD, serial code that adds two singular values together, `Jai` code generation is almost equivalent to C code. Any algorithm written in Jai that involves doing math on scalar values will have just as good code generation as doing it in C. When using SIMD instructions, `Jai` SIMD code can be just as fast as the `C` implementation, given that you optimize the SIMD instructions correctly.

## Troubleshooting

This section discusses Jai installation problems, and ways to fix these problems.

### Solution for install problem on Linux distros
On many 64 bit Linux platforms (Mint, Ubuntu, ...) starting the Jai compiler gives the following error message:

```
In Workspace 1 ("First Workspace"):
/etc/jai/modules/POSIX/libc_bindings.jai:243,20: Error: /lib/i386-linux-gnu/libdl.so.2: Dynamic library load failed. Error code 2, message: No such file or directory

    // @header dlfcn.h
    dynamic_linker :: #foreign_system_library "libdl";

/etc/jai/modules/Basic/posix.jai:1,2: Info: This occurred inside a module that was imported here.

    #import "POSIX";

/etc/jai/modules/Default_Metaprogram.jai:435,2: Info: ... which was imported here.

    }
    #import "Basic";

/home/sl3dge/.build/.added_strings_w1.jai:2,2: Info: ... which was imported here.

    #import "Default_Metaprogram";

    dlerror says: /lib/i386-linux-gnu/libdl.so.2: wrong ELF class: ELFCLASS32
```

The main issue here is: **libdl.so.2: wrong ELF class: ELFCLASS32**  
Other similar errors can occur, like:    
**librt.so.1: wrong ELF class: ELFCLASS32**  
**libpthread.so.0: wrong ELF class: ELFCLASS32**

For some reason when you ask for `libdl` or `librt` or `libpthread`, the OS points you to the 32bit version instead of the 64 bit version.

As suggested on the Discord channel, all that is needed to solve these problems is to install **libc6-dev-amd64**.  
This is done by executing the following commands in a terminal:  
```
1) sudo apt-get update -y
2) sudo apt-get install -y libc6-dev-amd64
```

Check with `jai -version`:  
Version: beta 0.1.039, built on 17 September 2022.

Remark:  
1) WSL on Windows with Ubuntu doesn't have this problem on a 64 bit machine.
2) For Simp or other OpenGL modules you need to install libgl-dev.

