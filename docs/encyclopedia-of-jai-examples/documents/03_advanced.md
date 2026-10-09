This page covers advanced Jai language constructs and topics such as polymorphism, inline assembly, and context are covered under the advanced section. This section assumes you already understand the basic language constructs covered in the `Getting Started` section.

## `void` type and return
`void` (NOTE: **not** `void *`), is a type with a size of zero, that other types cannot cast to. There are no values of the type void. A variable can be declared a type of `void`, but it will have a size of 0.
```
variable: void;
print("%\n", variable); // prints out 'void'
```
A function that returns void can return a void variable. This can be useful when working with polymorphic structs/functions, and you want to return an empty void from the function.
```
function :: () -> void {
  variable: void;
  return variable;
}
```
`void` can also be used as a polymorphic type in e.g. `f :: ($T: Type) -> T { x: T; return x; }` as `T`: `f(void)`

Note that there is a difference between a function `f :: () -> void { ... }` and a procedure `f :: () { ... }`. Returning `void` is an explicit, if zero-byte, return, while the latter simply does not return anything.

### void as a struct member
`void` can be used as struct members. This allows you to put notes on struct members that do not take up space, or serve as markers for a `#overlay` directive.

```
Object :: struct {
  member: void; @notes
  #overlay member;
  x: float;
  #overlay member;
  y: float;
  #overlay member;
  z: float;
}
```

## Operator Overloading
Jai supports operator overloading. Operators that can be overloaded include: `+`, `-`, `*`, `/`, `==`, `!=`, `<<`, `>>`, `&`, `|`, `[]`, `%`, `^`, `<<<`, `>>>`, `[]=`. Operator overloading should be used conservatively, limited only to mathematical operations. Unlike C++, operator overloading in Jai does not have a concept of references.

Given a `Vector3` datatype, you can define an `operator +` for it. Defining `operator +` automatically defines `operator +=` and vice versa.

```
Vector3 :: struct { x: float; y: float; z: float;} // Vector3 of {x,y,z}

operator + :: (a: Vector3, b: Vector3)->Vector3 {
  c: Vector3;
  c.x = a.x + b.x;
  c.y = a.y + b.y;
  c.z = a.z + b.z;
  return c;
}

a := Vector3.{1.0, 2.0, 3.0};
b := Vector3.{3.0, 4.0, 2.5};
c := a + b;
c += a;
```

Adding the keyword `#symmetric` to any two parameter function causes the order of two parameters to be irrelevant. We can define `operator *` on a `Vector3` to mean scalar multiplication:
```
operator *:: (a: Vector3, b: float)->Vector3 #symmetric {
  c: Vector3;
  c.x = a.x * b;
  c.y = a.y * b;
  c.z = a.z * b;
  return c;
}

a := Vector3.{3.0, 4.0, 5.0};
c: Vector3;
c = a * 3;
c = 3 * a;
c *= 3;
```
As the example above shows, the `#symmetric` keyword allows someone to create a `Vector3` with an `operator *` that can perform both `a * 3` and `3 * a`.

### Operator Overloading Examples

Here is an example of using `operator []`. The `operator []` is a read-only operator overload, i.e. `b := object[index]`. To do a write operator, use `operator []=` to do `object[index] = b`.
```
Obj :: struct {
  array: [10] int;
}

operator [] :: (obj: Obj, i: int) -> int {
  return obj.array[i];
}

o : Obj;
print("o[0] = %\n", o[0]);
```

Here is an example of using and implementing `operator []=`.
```
Obj :: struct {
  array: [10] int;
}

operator []= :: (obj: *Obj, i: int, item: int) #expand {
  obj.array[i] = item;
}

o : Obj;
o[0] = 10;
print("o[0] = %\n", o[0]);
```



Here is an example of using `operator *=`.
```
operator *= :: (obj: *Obj, scalar: int) {
  for *a : obj.array {
    a.* *= scalar;
  }
}

o : Obj;
o *= 100;
```

To see an extended set of operator overloading example, please see [Encyclopedia of Jai Examples - Using Operator Overloading for Math](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples/wiki/Using-Operator-Overloading-for-Math)

### Operators that you can NOT overload
`operator =` can **not** be overloaded. Although you can overload `+=`, `-=`, `*=`, etc., you cannot overload `operator =`. Overloading `operator =` can cause a lot of confusion in which one may think one is just assigning a variable, but is accidentally calling `operator =`, causing a massive slowdown in the code.

`operator new` can **not** be overloaded. `New` in Jai is a regular function call, not a keyword built into the language. You can change the context of the `New` function, and that is the way you can change the allocator.

## Polymorphism

Polymorphism is used to define functions and `struct`s that require at compile-time known types `T` via `$T`.

The dollar-sign before the type-parameter `$T` indicates that this type has to be derived by the compiler and therefore all required type information has to be known at compile time.

### Polymorphic type declarations

There are (at least) three major ways of defining polymorphic types. As we already saw, we can define the type of a variable via e.g. `x : int;`. Here, the compiler knows the type at compiletime, since it's explicitely written out. 


If we accept any (compile-time) type, we can use the dollar sign, e.g.
```
x : $T
```
In this case, **any** type is matched to `T`, that includes any `struct`, `int`, `bool`, `Any`, etc. There is no restriction on the possible types used. On the one hand, this enables us to write truly generic functions, on the other hand, we expect the programmers to know, what they're using `x` for - and in case they don't, the compiler will complain or the program will crash.


We can be more precise than that. Assuming we have polymorphic structs (see below), e.g. `Foo(T: Type)`, we can restrict the type of `x` by only allowing `Foo`s:
```
x : Foo($T)
```
In this case, the inner type `T` still could be anything, but at least we know that `x` is some kind of `Foo`. This declaration can be nested, e.g.
```
x : Foo(Bar($T, Sth($C, $D)), $U)
```


Sometimes, however, this way of restricting the type of `x` is too strict. It is possible to require members of `x` similar to traits or interfaces in other languages via the `/` notation:
```
x : $T/Foo
```
Here, we know that `x` has the fields of `Foo` and we can treat it as such. This does **not** mean `x` is a `Foo`! It can simply incorporate a `Foo` via e.g. `using f: Foo;`. This enables also component based systems where each struct links via `using _c: SomeComponent;`

In all of these cases, it is possible to re-use the polymorphic types, e.g. `T`, once the compiler could figure what they were. Examples of that are further below.

There are also other ways of defining the types, e.g. `$T/interface Foo` that will be explained further below.

### Functions

Let's take a look at a simple function:
```
foo :: (x: $T) {
    print("%\n", x);
}
```
At this point, we don't know the type of `x`, but we name it `T` and it has to be known at compile time! We can use it like this:
```
x := 42; // T == int
y := "hello"; // T == string

foo(x); // knows it's an int
foo(y); // knows it's a string
```

Of course, functions can have multiple polymorphic variables
```
foo :: (a: $A, b: $B, c: $C) {...}
```
You can use the same type for multiple parameters and return values, just use the identifier for the type.
```
foo :: (a: $T, b: T, c: T) -> T {...}
```

**Polymorphic return parameter:**
We already know, that we can reuse the polymorphic type definition for the return type of a function, see the example above. However, in some cases, the return parameter depends on the argument parameter types
```
foo :: (a: $A, b: $B) -> [some function determining the type depending on A and B] {...}
```
One way of doing this is `#modify` which will be explained further down below. Unfortunately, this method is cumbersome since it does not work directly with the types `A` and `B`, but the AST representation of the parameters.

Another way of achieving this functionality, is with helper-structs: We can define
```
Helper :: struct(A: Type, B: Type) {
  T :: #run helper(A,B);
}
helper :: ($A: Type, $B: Type) -> Type {
  T : Type = A; // do your logic here
  return T;
}
```
The `helper` function actually does the logic and returns the wanted return type depending on the input types. It is run at compile-time via the `#run` instruction. To use the return type, we now define our original function `foo` as
```
foo :: (a: $A, b: $B) -> Helper(A,B).T {...}
```
The `Helper` struct can be used anywhere to define the type of a variable, e.g. in `foo`
```
x : Helper(A,B).T;
```

To see more examples of polymorphic algorithms, see [Encyclopedia of Jai - Polymorphic Algorithms](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples/wiki/Polymorphic-Algorithms)

### Structs

Similar to function, polymorphic structs are also possible! In this case, you need to introduce the polymorphic type `$T` after the `struct` keyword for compile-time constants:
```
Foo :: struct(x: $T) {...}
```
This way, the type of `x` has to be known at compile time:
```
a : Foo(42); // ok, 42 is a constant
x := 2;
// b : Foo(x); // not ok, x is not a constant value!
y :: 2;
b : Foo(y); // ok, y is a constant value
```

If you want to define a struct that has a polymorphic type for it's members, you can use the type `Type` to define it during compile-time
```
Foo :: struct(T: Type) {
    some_data : T;
}
```
When using this struct, you have to declare the type
```
f : Foo(int);
```
Continuing the example above, you can access the type parameter of `Foo` through `Foo.T`.
```
f: Foo(int);
print("type = %\n", f.T); // prints out "type = int"
```

The polymorphic struct do not only restrict to data types, but they can also extend to functions:
```
Foo :: struct(
  // everything here has to be known at compile time
  // these entries will be baked out and do not remain part of the struct in memory during run-time!

  T: Type,
  fun: (T) -> T
  // ...
) {
  // everything here can be changed 
  // (as long as it's not a constant via :: ) at run-time 
  // and stays in memory

  value: T;
  // ...
}
```

Further, it is possible to define recursive types, e.g.
```
Foo :: struct(
  T: Type,
  fun: (T) -> int
){}

Bar :: struct(_T: Type) {
  using f: Foo(Bar(_T), bar_fun)
}
bar_fun :: (b: Bar($T)) -> int {
  return 42;
}
```

To see more examples of polymorphic data structures, visit [Encyclopedia of Jai Examples - Polymorphic Data Structures](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples/wiki/Polymorphic-Data-Structures).

### Arrays

It is possible to use polymorphic arrays int both size `N` and element-type `T`, e.g.
```
foo :: (x: [$N]$T) {
    print("%: %, %\n", type_of(N), N, T);
}
```
Here, both `N` and `T` have to be known at compile time. `N` refers to the number of elements and is itself of type `int`! Using the above definition of `foo`, we'd get in this example
```
x := int.[1,2,3,4];
foo(x); // prints "s64: 4, s64"
```
It is important to know, that arrays of different sizes are different types! So
```
[4]int != [5]int
```

### Type Comparison

We can compare types with the equals operator `==`:
```
x : float64 = 0.1;
assert(type_of(x) == float64);

n := 42;
assert(type_of(n) == int);

Foo :: struct {}
f : Foo;
assert(type_of(f) == Foo);
```

However, when using polymorphic structs, e.g.
```
Bar :: struct(T: Type) {
    value: T;
}
```
we can only compare specializations of said type, in this case
```
b : Bar(int);
assert(type_of(b) == Bar(int));
assert(b.T == int);
```

It is not possible to compare without specialization:
```
b : Bar(int);
assert(type_of(b) == Bar); // this does not work!
```
even though
```
print("%\n", type_of(b)); // prints "Bar".
```

### `$T/Object` syntax
`$T/Object` indicates that the `$T` must be a parameterized struct of the type `Object`. This saves time so that one does not have to type out all the parameters of a parameterized struct. Consider the following example:
```
Hash_Table :: struct (K: Type, V: Type, N: int) {
  keys: [N] K;
  values: [N] V;
}

function1 :: (table: Hash_Table($K, $V, $N), key: K, value: V) {
  // do stuff
}

function2 :: (table: $T/Hash_Table, key: T.K, value: T.V) {
  // do stuff
}

function3 :: (table: $T, key: T.K, value: T.V) {
  // do stuff
}

```
All the following ways are correct ways to write functions with parameterized structs. `function1` is slightly more verbose and utilizes pattern matching to specify the type, while `function2` is less verbose but still specifies that the `$T` must be a Hash_Table. `function3` is the most generic, least verbose, but loses a lot of useful type information. Use whatever way fits ones own programming style.

To see more examples of polymorphic data structures, visit [Encyclopedia of Jai Examples - Polymorphic Data Structures](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples/wiki/Polymorphic-Data-Structures).

### Implicit Polymorphism

This is another way of writing `$T/Object`, called implicit polymorphism. In this example, `Table` is being called directly.

```
function4 :: (table: Table, key: table.K, value: table.V) {
  // do stuff
}
```

### `$T/interface Object` syntax
`$T/interface Object` indicates that the `$T` must have the fields that `Object` has. $T/interface accepts only types that contain members declared in the target struct.

Here is a basic example of this:
```
Vec3 :: struct {
  x, y, z: float;
}

Another :: struct {
  x, y, z: float;
}

dot_product :: (a: $T/interface Vec3, b: T) -> float {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

main :: () {
  another: Another;
  c := dot (o,o);
}
```

The interface type does not work on polymorphic structs. Only structs without polymorphic types can work at compile time.

### `#modify` directive

The `#modify` compiler directive lets one put a block of code that is executed at compile-time each time a call to that procedure is resolved. The `#modify` directive allows one to inspect parameter types at compile-time.

Here is an example for how to use `#modify`.

```
do_something :: (T: Type) -> bool {
    type_info := cast(*Type_Info) T;
    if type_info.type == .INTEGER  return true;
    if type_info.type == .ENUM     return true;
    if type_info.type == .POINTER  return true;
    return false;
}


function :: (dest: *$T, value: T)
#modify { return do_something(T); }
{
    
}
```

In the example above, returning `false` generates a compile-time error, while returning `true` tells the compiler that `$T` is a type that will be accepted at compile-time.

## Context 

Jai has a first class concept of _context_, which is always present and accessible, but beyond being a simple global state variable, a new context can be "pushed", changing the operational context for a duration. But before we get into that, let's look at what a context provides.

In most languages, various system-level services such as memory allocations or logging are done via some common library function. For example, in C, you allocate memory using the `malloc` function. If you want to create your own custom allocator, it has to have a different name and will only be used when explicitly called. This means that libraries that you call out to won't know to use your clever custom allocator. Same is true of other features, like loggers, or what have you. Sometimes this will make you sad because a pesky library is messing up your heap or is slinging undesirable commentary at your terminal.

In Jai, the context is there to guide different parts of your program to use whatever services you desire. The default context comes with good defaults, but you can change them as needed. Among these are the allocator, the temporary allocator, the logger, the assertion failure callback, formatting options for `print`, runtime error logging options, and so on. You can also access your current thread index through the context. But wait, there's more: if for whatever reason it makes sense for your program to have additional context, you can add it yourself!

### `push_context`
Example:
```
my_context: Context;
push_context my_context {
    // Do stuff here with this context.
}
```

### `#add_context`

If you want to add something to your context, you use the `#add_context` compiler directive, like so:
```
#add_context this_is_the_way := true;
```

## Modules

### External libraries

Mapping a dynamic library (.dll / .so) is a fairly simple process: you specify the library file, and then provide signatures for the procedures you want to use.

For example:

```jai
lz4 :: #library "liblz4";

LZ4_compressBound :: (inputSize: s32) -> s32 #foreign lz4;
LZ4_compress_fast :: (source: *u8, dest: *u8, sourceSize: s32, maxDestSize: s32, acceleration: s32) -> s32 #foreign lz4;
LZ4_sizeofState :: () -> s32 #foreign lz4;
```

* We can specify a path to the library inside the double-quotes, but *You **MUST** copy the .dll next to the .exe, or it will not work!*
* Instead of linking to a local library file, you can link to a system library (built into the OS) with `#system_library`, e.g. `d3d11 :: #system_library "d3d11";`

Your procedure name does not need to exactly match the name in the library: you can rename it if you wish.  If you do, then add the original name in quotes at the end:

```jai
compress_bound :: (inputSize: s32) -> s32 #foreign lz4 "LZ4_compressBound";
compress_fast :: (source: *u8, dest: *u8, sourceSize: s32, maxDestSize: s32, acceleration: s32) -> s32 #foreign lz4 "LZ4_compress_fast";
size_of_state :: () -> s32 #foreign lz4 "LZ4_sizeofState";
```

If you are converting a C `.h` file then some familiarity with C is obviously required, but it can more-or-less be translated mechanically: put in the `::`, move the return type to the end and add the `#foreign <lib>` declaration, and flip the parameter types/names.  Things to be aware of:

* A pointer to `char` becomes a pointer to `u8`
* Elide extraneous prefixes (i.e. `const` before parameters, macros, etc.)
* References become pointers (i.e. `&` becomes `*`)
* You should almost always specify a 32-bit size for an `enum`, i.e. `IL_Result :: enum s32 {`, or `D3DCOMPILE_FLAGS :: enum_flags u32 {`.
* The size of `int` and `float` may be hard to discern; if you can't work it out from the code, comments or documentation then go for 32-bit versions; if your data comes out mangled you can re-apprise.
* Rename any parameter which happens to coincide with a Jai keyword.  `context` -> `ctx` is common, for instance.

Once you have the code compiling and your program running, you need to check the data that's being passed back and forth from the library: incorrect values will likely indicate incorrectly sized struct members, variables, constants, or parameters.  Be especially observant of the types mentioned above.


#### Callbacks

We use two directives to specify callback types: `#type` and `#c_call`.  `#type` lets us specify the expected parameters of the callback (rather than just using a `*void`), and `#c_call` tells the compiler to use the C ABI.

* We need to specify a `void` return type if that's the case.
* When we write an actual callback procedure to use with our definition, we need to push a new context inside it.

For example:

```jai
IL_Logger_Callback :: #type(level: IL_LoggingLevel, text: *u8, ctx: *void) -> void #c_call;

logger_callback :: (level: IL_LoggingLevel, text: *u8, ctx: *void) #c_call {
    new_context : Context;
    push_context new_context {
        log("%", to_string(text));
    }
}
```

#### Example Conversion

```c
IL_C_API IL_Result IL_SetAdapter(IL_Context* context, IL_AdapterFunctions* adapterFunctions);

typedef void(*IL_Logger_Callback)(IL_LoggingLevel level, const char* text, void* context);

typedef struct IL_Logger
{
    IL_Logger_Callback callback;
    IL_LoggingLevel level;
    void* context;
} IL_Logger;

typedef enum IL_DeviceNotification
{
    IL_DeviceNotification_None = 0,
    IL_DeviceNotification_UpdatedStreamsAvailable = 1,
    IL_DeviceNotification_UpdatedConfig = 2
} IL_DeviceNotification;
```

Becomes:

```jai
IL :: #library "ILlibrary";

// Ditch the IL_C_API macro and rename `context` to `ctx`.
IL_SetAdapter :: (ctx: *IL_Context, adapterFunctions: *IL_AdapterFunctions) -> IL_Result #foreign IL;

// See above section on callbacks, `const char*` becomes `*u8`.
IL_Logger_Callback :: #type(level: IL_LoggingLevel, text: *u8, ctx: *void) -> void #c_call;

IL_Logger :: struct {
    callback : IL_Logger_Callback;
    level    : IL_LoggingLevel;
    ctx      : *void;
}

// Add `s32` size info to enum
IL_DeviceNotification :: enum s32 {
    IL_DeviceNotification_None                    :: 0;
    IL_DeviceNotification_UpdatedStreamsAvailable :: 1;
    IL_DeviceNotification_UpdatedConfig           :: 2;
}
```

### Bindings Generator

You can automatically generate bindings for a particular library using the `Bindings Generator` module. Here is a small script showing how to generate bindings.

```
generate_bindings :: () -> bool {
    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {
            output_filename          = "windows.jai";
            strip_flags = 0;
        } else #if OS == .LINUX {
            output_filename          = "linux.jai";
            strip_flags = .INLINED_FUNCTIONS; // Inlined constructor doesn't exist in the library
        } else #if OS == .MACOS {
            output_filename          = "macos.jai";
            strip_flags = .INLINED_FUNCTIONS; // Inlined constructor doesn't exist in the library
        } else {
            assert(false);
        }

        array_add(*libpaths,       ".");
        array_add(*libnames,      "your_cool_library");
        array_add(*source_files,  "your_cool_library.h");
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN");
    }

    return generate_bindings(opts, output_filename);
}

#import "Basic";
#import "Bindings_Generator";

#run generate_bindings();
```

### Rolling your own

A minimal example of how to build a dynamic library (`.dll`) and how to load it can be found in the [Snippets and Benchmarks](https://github.com/Jai-Community/Jai-Community-Library/wiki/Snippets-and--Benchmarks#writing-and-loading-dynamic-libraries).

## Module Parameters
The `#module_parameters` directive can be used to declare parameters that the user can set when importing a module. Default values can be provided so that the user does not have to know about these parameters in order to import.

When creating a `module`, you can use `#module_parameters` to create user parameters that can be set by the user. Let's create a module called `Module`, by creating a file `module.jai` in a folder called `Module`.
```
#module_parameter(VERBOSE := false);

#run {
  if VERBOSE {
    print("The module is in VERBOSE mode\n");
  } else {
    print("The module is in NON_VERBOSE mode\n");
  }
}

```

In your `main.jai`, you can import the `Module` using `jai main.jai -import_dir Module`.
```
#import "Module" (VERBOSE=true);

main :: () {

}
```

## Temporary Storage

`Temporary Storage` is linear allocator with a pointer to the start of free memory. If there is a request for memory, it advances the pointer and returns the result. If it runs out of memory, it asks the OS for more RAM. In `Temporary Storage`, you cannot free individual items, rather all allocated items are freed all at once when `reset_temporary_storage` is called.

The appropriate time to call `reset_temporary_storage` depends from application to application. In a game loop, you could reset temporary storage at either the beginning or end of a game loop:

```
while true {
  input();
  simulate();
  render();
  reset_temporary_storage();
}
```

Here is the struct definition for `Temporary Storage`:
```
Temporary_Storage :: struct {
  data: *u8;
  size: s64;
  occupied: s64;
  high_water_mark: s64;
  overflow_allocator := __default_allocator;
  overflow_allocator_data: *void;
  overflow_pages: *Overflow_Page;
  original_data: *u8;
  original_size: s64;
}
```

In a debug build, if the high water mark exceeds the temporary storage memory capacity, temporary storage will default back to the default heap allocator to allocate more memory. In a release build, your program might crash, or have memory corruption problems.

### New using Temporary Allocator
You can do a temporary storage allocation `New` using the following code:
```
Node :: struct {
  value: int;
  name: string;
}

node  := New(Node,, allocator=temp);
array := NewArray(10, int,, allocator=temp);
```

The `,,` double commas syntax is used to indicate to push the `Context` with the temporary allocator.

### Resizable Array w/ Temporary Allocator
You can set the resizable array to use the temporary allocator by setting the `.allocator` field to `__temporary_allocator`.
```
array: [..] int;
array.allocator = temp;
```

### Push Temporary Allocator
To use the Temporary Allocator as the context allocator, you can use the `push_allocator(temp)` macro to push the temporary allocator to the context. When the scope closes, you get back the allocator prior.

```
push_allocator(temp);
```

### Using Temporary Allocator as a Stack Allocator
The temporary allocator can act as a stack allocator by using the `auto_release_temp :: ()` macro to set the mark. Allocate whatever you want temporarily, then release all the memory at once when the stack unwinds by setting the mark back to the original location.

```
auto_release_temp();
```


## Stack Trace
Stack traces are compiled into the program when `build_options.stack_trace = true`, which is `true` by default. These can be turned off for release builds. When enabled, every time a procedure is called, code is generated to output a `Stack_Trace_Node` on the stack and link it up, and unlink it when the procedure returns.

Stack traces are good for writing instrumentation code such as a profiler or memory debugger. The definition for stack traces can be found in `modules/Preload.jai`.

Here is some example code to use stack traces:
```
print_stack_trace :: (node: *Stack_Trace_Node) {
  while node {
    if node.info {
      print("[%] at %:%. call depth %\n", 
                      node.info.name, 
                      node.info.location.fully_pathed_filename, 
                      node.line_number, 
                      node.call_depth);
    }
    node = node.next;
  }
}

f :: (x: int) {
  if x < 1 {
    print_stack_trace(context.stack_trace);
  } else {
    f(x-1);
  }
}

f(3);
```

## Compiler Directives

`#add_context` adds a declaration to a context.

`#as` indicates that a struct can implicitly cast to one of its members. It is similar to `using`, except #as does not also import the names. `#as` works on non-struct-typed members. For example, you can make a struct with a float member, mark that #as, and pass that struct implicitly to any procedure taking a float argument.

`#asm` specifies that the next statements in a block are inline assembly.

`#assert` does a compile-time assert. This is useful for debugging compile-time meta-programming bugs.

`#bake_arguments` does a compile-time currying of a function/parameterized struct.

`#bytes` directive adds binary data to a particular location.

`#c_call` makes the function to use the C calling convention. Used for interacting with libraries written in C.

`#char` makes the next one character string after it into a single ASCII character (e.g. #char "A").

`#code` specifies that the next statement/block is a code type.

`#complete` requires an if-case statement to fill out all the cases for an enum.

`#compiler` specifies a function that interfaces with the compiler as a library. The function works with compiler internals.

`#compile_time` is a boolean value that evaluates to `true` during compile time and `false` during runtime.

`#cpp_method` allows one to specify a C++ calling convention.

`#cpp_return_type_is_non_pod` allows one to specify that the return type of a function is a C++ class, for calling convention purposes.

`#deprecated` marks a function as deprecated. Calling a deprecated function leads to a compiler warning.

`#dump` dumps out the bytecode and basic blocks used to construct the function. This is useful for viewing the disassembly of the bytecode.

`#exists` is similar to the 'defined' part of #ifdef in C. This directive takes as an argument an identifier, or sequence of dot-dereferenced identifiers; #exists constant-evaluates as true or false depending on whether those variable declarations exist. (If #exists returns false, then trying to dereference that sequence in your actual program would be an error.)

`#expand` marks the function as a macro.

`#filepath` gets the current filepath of the program as a string

`#foreign` specifies a foreign procedure

`#library` specifies file for foreign functions

`#system_library` specifies system file for foreign functions

`#if` is a compile-time if statement

`#import` takes foreign modules located in the Jai `modules` directory and compile the library into your program.

`#insert` inserts a piece of compile-time generated code into a function or a struct.

`#intrinsic` marks a function that is handled specifically by the compiler. 

`#load` takes `Jai` code files written by the programmer and adds the files to your project.

`#modify` lets one put a block of code that is executed at compile-time each time a call to that procedure is resolved. One can inspect parameter types at compile-time.

`#module_parameters` specifies the variable as a module parameter.

`#no_abc` means that in this function, do not do array bounds checking

`#no_aoc` means no arithmetic overflow check. This can be used in the same places as array bounds checking.

`#no_call` means that the function does absolutely nothing on when calling the function.

`#no_context` tells the compiler that the function does not use the context.

`#no_debug` prevents the compiler from generating any debug line info for a particular macro or macro call. Used to avoid stepping into macros during debugging.

`#no_padding` tells the compiler to do no padding when it comes to structs.

`#no_reset` lets one store data in the executable's global data, without having to write it out as text.

`#overlay` is another way of forming a union data type. 

`#placeholder` specifies to the compiler that a particular symbol will be defined/generated by the compile-time metaprogram.

`#procedure_name` gives you the statically-known-at-compile-time name of a procedure.

`#run` takes the function in question and runs that function at compile time (e.g. `PI :: #run compute_pi();`).

`#scope_export` makes the function accessible to the entire program
 
`#scope_file` makes the function only callable within the particular file.

`#specified` requires values of an enum to explicitly be initialized to a specific value. An enum marked specified will not auto-increment, and every value of the enum must be declared explicitly.

`#string TOKEN` is used to specify a multi-line string.

`#symmetric` allows to swap the 1st and 2nd parameters in a two parameter function. Useful in the case of operator overloading.

`#this` returns the procedure, struct type, or data scope that contains it, as a compile-time constant.

`#through` allows fall-through behavior in a if-case statement.

`#type` tells the compiler that the next following syntax is a type. Useful for resolving ambiguous type grammar.

`#type_info_none` marks a struct such that the struct will not generate the type information.

`#type_info_procedures_are_void_pointers` makes all the member procedures of a struct void pointers when generating type information. See Type_Info_Struct_Member.Flags.PROCEDURE_WITH_VOID_POINTER_TYPE_INFO.

`#type_info_no_size_complaint` prevents the compiler from complaining about the size of the type information generated by a struct.

## Program entry point details

As you've seen, the entry point of your program is called `main`, it returns `void` and does not take any arguments.
But, wait, shouldn't it be a `main :: (argc : s32, argv : **u8) -> s32` like in other languages instead ? Well not in Jai! Jai has an intermediate step, where it initializes a few things such as the context, and the command line arguments are cached in the `__command_line_arguments` array.  
The actual entry point of your program is called `__system_entry_point`, and can be found in `modules/Runtime_Support.jai`:  

```
#program_export
__jai_runtime_init :: (argc: s32, argv: **u8) -> *Context #c_call {
    __command_line_arguments.count = argc;
    __command_line_arguments.data  = argv;

    ts := *first_thread_temporary_storage;
    ts.data = first_thread_temporary_storage_data.data;
    ts.size = TEMPORARY_STORAGE_SIZE;

    ts.original_data = first_thread_temporary_storage_data.data;
    ts.original_size = TEMPORARY_STORAGE_SIZE;
    
    first_thread_context.temporary_storage = ts;

    return *first_thread_context;
}

#program_export
__jai_runtime_fini :: (_context: *void) #c_call {
    // Nothing here for now!
}

#program_export "main"
__system_entry_point :: (argc: s32, argv: **u8) -> s32 #c_call {
    __jai_runtime_init(argc, argv);

    push_context first_thread_context {
        __program_main :: () #runtime_support;
        __program_main();
    }
    
    return 0;
}
```  

So, you can see that this procedure does take a `s32` and a `**u8`, and returns a `s32`. It is also marked as `#c_call`, and is exported as `main` so the OS can find it.
This procedure is responsible for initializing the `context`, `temporary_storage`, and the `__command_line_arguments` array by calling `__jai_runtime_init`, defined right before. It then calls `__program_main`, which is the `main` you've defined, after pushing the newly created context.

## Cache Alignment
The `#align` directive is used to align struct member fields relative to the start of the struct. If you have a member field that is `#align 64`, and the base of the struct is also aligned 64, then the member field will also be aligned 64. If you make a member field `#align 32`, the member field will be aligned 32, and `#align 16` will make a member field aligned 16. This directive is useful if you are working with cache-sensitive data structures that required alignment in a particular way.

If the base of the struct is **not** aligned correctly, the struct member will not align correctly since the base of the struct is not aligned correctly. `#align` assumes that the base of the struct is aligned correctly.

Here is an example of how to use the `#align` directive on a struct member:
```
Accumulator :: struct {
  // make the 'accumulation' struct member variable is 64-bit cache-aligned
  accumulation: [2][256] s16 #align 64;
  computedAccumulation: s32;
}
```

`#align x` cannot be applied directly to a struct. It can only be applied to struct members. If you want to align an array of structs to the appropriate alignment, add appropriate padding to pad the struct to the desired alignment. For example, in the following code:
```
Object :: struct {
  member: int;
} #align 64  // This has NO effect on the struct
```
This will compile, but `#align` will have no effect on the code.

A global variable can be made cache aligned by applying the `#align 64` directive, just like aligning object member fields.
```
global_var: [100] int #align 64; // makes the global variable 64-bit cache aligned

assert(cast(int)(*global_var) % 64 == 0); 
```
To align the base of an array to a particular alignment, you can change the `alignment` parameter on the `NewArray` heap allocation function so that the array can have the appropriate alignment. 
```
// perform heap allocation that is 64-bit aligned
N :: 100;
object_array := NewArray(N, Object, alignment=64);  
assert(cast(int)(*object_array[0]) % 64 == 0);  
```

Here is another alternative to align to a particular alignment to using `NewArray`, in case you do not want to return an array view type. `amount_to_align` is an arbitrary number, dictated by the user. `align_forward` aligns the memory in the way you specifically want.
```
amount_to_align := 64; 
memory: *void = alloc(size_of(Object) + amount_to_align);
memory = cast(*void) align_forward(cast(int)memory, amount_to_align);
assert( (cast(int) memory) % amount_to_align == 0);
```

Aligning a struct on the stack is supported using `#align x`.

```
function :: () {
    array: [32] float #align 16; // aligns the array on the stack along 16-byte alignment
}
```


### Move Aligned SIMD
The `movaps` instruction requires a memory address that is 16-byte aligned. Align the data you want to 16-byte aligned in order to use `movaps`. Having an aligned memory address is important for SSE SIMD, where aligned memory can be read faster than non aligned memory.
```
array: [16] float #align 16;
data := array.data;
#asm {
  movaps.x ymm0: vec, [data];
}
```

## Inline Assembly
Inline assembly can be used to specify exactly what machine language instructions need to be executed in order to get the most optimized code, or doing SIMD instructions for parallelizing data transformations. Here is the basic starter code for inline assembly blocks. Currently, only the x64 platform is supported. Assembly language is mainly used to generate custom CPU instructions, support SIMD, or take explicit control over the code generation when the compiler is not optimizing the code correctly. Inline assembly does not support jumping, branching, NOP, or calling functions. Use the high level constructs of Jai in order to do looping and branching.

When entering an `#asm` block, there is a ton of upfront glue instruction code before and after the `#asm` block.

Places where you can find inline assembly examples: 
* modules/Atomics
* modules/Bit_Operations
* modules/Runtime_Support
* modules/meow_hash

Here is an excerpt of atomic swap from the `Atomics` module that uses assembly language:
```
atomic_swap :: (dest: *$T, new_value: T) -> (old_value: T) {
  SIZE :: size_of(T);
  // The Intel documentation says that the lock prefix is ignored
  // for xchg, but we'll put it here just in case I guess?
  v := new_value;
  #if SIZE == 1 {
    #asm { lock_xchg.b v, [dest]; }
  } else #if SIZE == 2 {
    #asm { lock_xchg.w v, [dest]; }
  } else #if SIZE == 4 {
    #asm { lock_xchg.d v, [dest]; }
  } else #if SIZE == 8 {
    #asm { lock_xchg.q v, [dest]; }
  } else {
    #assert false, "Invalid size passed to atomic_swap; argument must be 1, 2, 4, or 8 bytes.";
  }
  return v;
}
```

The `lock_xchg` is the `atomic swap` assembly instruction. The `.q`, `.d`, `.w`, and `.b` specifies the size of the assignment. Here is the list of different operations:

`.q` is quad-word (64-bit integer). 

`.d` is double-word (32-bit integer).

`.w` is a regular word (16-bit integer).

`.b` is a byte (8-bit integer).

`.x` is the SSE is in the feature set, xmmword (128-bit)

`.y` is the AVX is in the feature set, ymmword (256-bit)

`.z` is the AVX512F is in the feature set, zmmword (512-bit)

### Assembly Limitations
There are no `goto`, `jump`, `nop`, or `call` instructions. You cannot call a function in the middle of an assembly block. Looping and branching can only be implemented through typical `while`, `if`, and `for` loops. You cannot modify/change the stack pointer using assembly. Modifying the stack pointer does not work robustly in Jai, so this is not supported at all.

If you need to call a C function with a specific ABI (Application Binary Interface), consider `#no_call`, a directive you can add to a function that does absolutely nothing on call and return.

### List of All the Assembly Instructions
Instructions are named based on the mnemonic and operands provided. Instruction mnemonics are identical to the official mnemonic provided by Intel and AMD. With that being said, you can refer to official manuals when programming instead of having to indirectly go through the intrinsics guide. 

* List of [instructions found to be supported by the compiler](https://github.com/Jai-Community/Jai-Community-Library/wiki/List-of-x64-mnemonics-the-compiler-supports)
* List of all possible x86-64 assembly instructions: https://www.felixcloutier.com/x86/index.html

### Assembly Language Data Types
The data types usable within inline assembly are `gpr`, `str`, `vec`, or `omr`.

* `gpr` stands for general purpose register.
* `gpr.a` means that the gpr must be pinned to the register `a` (e.g. `EAX: gpr === a`)
* `imm8` is an 8 bit immediate
* `mem` means the operation must be a memory operand (e.g. lea.q [EAX], rax)
* `str` stands for stack register, this is used by the fpu and mmx instructions.
* `vec` stands for a vector type. This is used for manipulating SIMD instructions
* `omr` stands for op-mask register, only available with AVX512
* `vec&` and `vec&*` stands for `AVX512` `EVEX` bit masking. The `&` operator is the merging operator while `&*` operator is the zeroing operator.

Here are some valid assembly language syntax declaration examples:
```
#asm {
  var: gpr; // declared a general purpose register named 'var'
  mov var, 1; // assign var = 1
}

#asm {
  // declared a general purpose register named 'var', and mov 1 into it
  mov var: gpr, 1; // assign var = 1
}

#asm {
  // implicitly declare 'var' without specifying the type
  mov var:, 1;
}
```

### Assembly Registers

In `#asm`, registers declared in inline assembly in one `#asm` block are available in other `#asm` blocks. This is useful especially if `#asm` needs to be done in a multiple loops.

```
#asm {
  mov var: gpr, 0;
}

success: bool = true;
if success == true {
  // can access the 'var' register in the `#asm` block.
  #asm {
    mov var, 100;
  }
}
```
### Assembly Grammar Syntax Notes
There must be a semicolon after every assembly instruction. Putting `//` or `/* */` in an assembly block denotes a comment.

```
  #asm {
    /*
    This is a multi-line comment.
    The quick brown fox jumped over
    the lazy dog.
    */

    mov var, 100; // This is a comment.
  }
```

### Register Allocation
In inline assembly, the compiler implements register allocation to replace variables with registers, allowing you to use variable names to convey data flow the same way as in high level code. The register allocator takes lifetimes into account. Register management is turned into a working set size problem rather than an annoying book-keeping one. There is no automatic spilling of registers, meaning if you ever exceed the maximum number of alive registers, you will get an error from the compiler.

### Pinning a variable to a register
The `===` operator is used to pin variables to general purpose registers. In this simplified byte swap example, result is assigned to a register. The `===` operator can be used to map to registers `a`, `b`, `c`, `d`, `bp`, `si`, `di`, or an integer between 0 and 15 (representing SIMD registers from `xmm0` to `xmm15`.

```
byte_swap :: (input: s64) -> s64 {
  result := input;
  #asm { 
     result === a;   // result is represented as register a
     bswap.q result;
  }
  return result;
}
```
In the following example below, the multiply requires the `d` register and the `a` register for the multiply instruction. To do `z = x * y;`, pin the `x` value to register `a`, followed by pinning the `z` value to register `d`.
```
x: u64 = 197589578578;
y: u64 = 895173299817;
z: u64 = ---;
#asm {
   x === a; // We pin the high level var 'x' to gpr 'a' as required by mul.
   z === d; // We pin the high level var 'z' to gpr 'd' as required by mul.
   mul z, x, y;
}
```

### Assembly Memory Operands
In x86, there are several memory operands with the format `base + index * scale + displacement`. Just like in a traditional assembly, you can indicate a memory operand by wrapping it with brackets `[]`. The ordering of the expression is rigid, and must be in the order `base + index * scale + displacement`. You cannot place the displacement first, or the base second, etc. This reduces ambiguity and confusion when fields can be ambiguous identifiers.

The `scale` is limited to the number literals `8`, `4`, `2`.

In this example, we demonstrate loading memory into registers.
```
array: [32] u8;
pointer := array.data;
#asm {
  mov a:, [pointer];      // a := array.data
  mov i:, 10;             // declare i:=10
  mov a,  [pointer + 8];
  mov a,  [pointer + i*1];
}
```

### Load Effective Address (LEA) Load and Read Instruction Example
Here is a basic example to do load effective address. Note that in `rax*4`, the constant must go after the register. You can look up what `LEA` does [here](https://www.felixcloutier.com/x86/lea)
```
#asm {lea.q rax, [rdx];}
#asm {lea.q rax, [rdx + rax*4];}

// NOTE: This does not work, 4*rax is wrong, must be rax*4
// #asm {lea.q rax, [rdx + 4*rax];} 
```

### Assembly Feature Flag Tagging

When you make a block with assembly feature flag tagging, the compiler will error if you use a feature from a feature set you haven't tagged the block with, unless the feature has been enabled globally in a build script. All the assembly feature flag options can be found in `Machine_X64.jai`. Flag options includes flags such as `AVX` (Advanced Vector Extensions), `MMX` (MMX instructions), `SSE3` (SSE3 instructions), and many other instructions.
```
#asm AVX, AVX2 {

}
```

### Assembly Feature Flag Check
`x86` does not have a single set of instructions. Rather, there are feature flags that tell someone whether or not a particular set of instructions is present or not. There is a helper function in `Machine_X64` module that helps you find out what instructions are available to you on a particular machine.

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

### Passing Registers through Macro Arguments
Registers can be passed through macro arguments, giving you the power of macros while using inline assembly. `__reg` cannot be returned as values from macros, only passed in as arguments. `__reg` can represent any of the assembly datatypes, like `gpr`, `vec`, `str`, or `omr`.
```
add_regs :: (c: __reg, d: __reg) #expand {
  #asm {
     add c, d;
  }
}

main :: () {
  #asm {
     mov a:, 10;
     mov b:, 7;
  }

  add_regs(b, a);
}
```

### SIMD Floating Point Addition
These are some basic SIMD Vector Code for adding few 32-bit floats together at the same time. `.x` means to adding 4 floats at the same time, while `.y` indicates adding 8 floats together at the same time.

This example uses `addps.x` to add 4 32-bit floats together at the same time.
```
array := float32.[1, 2, 3, 4];
ptr := array.data;
print("array before: %\n",array); // outputs 1, 2, 3, 4
#asm {
  v: vec;
  movups.x v, [ptr];
  addps.x v, v;
  movups.x [ptr], v;
}
print("array after: %\n", array); // outputs 2, 4, 6, 8
```

This example uses `addps.y` to add 8 32-bit floats together at the same time.
```
array := float32.[1, 2, 3, 4, 5, 6, 7, 8];
ptr := array.data;
print("array before: %\n",array); // outputs 1, 2, 3, 4, 5, 6, 7, 8
#asm {
    v: vec;
    movups.y v, [ptr];
    addps.y v, v, v;
    movups.y [ptr], v;
}
print("array after: %\n", array); // outputs 2, 4, 6, 8, 10, 12, 14, 16
```

### SIMD Integer Addition
These are some basic SIMD Vector Code for adding 8-bit integers together at the same time. `.x` indicates a 128-bit vector lane, and since 128/8 is 16, this piece of code is adding 16 8-bit integers all at once. We use `paddb`, or add packed integers assembly instruction to add all the integers together using SIMD.
```
a: [16] u8;
b: [16] u8;
c: [16] u8;

// initialize 
for i: 0..15 {
  a[i] = xx i;
  b[i] = xx (i+1);
}

ptr1 := a.data;
ptr2 := b.data;
ptr3 := c.data;

#asm AVX, AVX2 {
  movdqu.x v1:, [ptr1]; // v1 = [a]
  movdqu.x v2:, [ptr2]; // v2 = [b]
  paddb.x  v3:, v1, v2; // v3 = v1 + v2
  movdqu.x [ptr3],  v3; // [c] = v3
}

print("a=%\n", a);
print("b=%\n", b);
print("c=%\n", c);
```
### Fetch and Add

The fetch-and-add instruction increments the contents of a memory location by a specified value. This is a translation of a C++ fetch add from `Godbolt`. This operation is normally used in concurrency. More information on this can be found at: [Fetch-and-Add](https://en.wikipedia.org/wiki/Fetch-and-add)

```
// fetch and add.
fetch_and_add :: (val: *int) #expand {
  #asm {
    mov incr: gpr, 1;
    xadd.q [val], incr;
  }
}

global_variable: int;
fetch_and_add(*global_variable);
```

### Creating your own Print function in Assembly Language

By pinning the `gpr` and the interrupt instruction `int`, you can create your own `print` function.
```
print :: (str: string) {
  len := str.count;
  msg := str.data;
  #asm {
    mov edx: gpr === d, len;
    mov ecx: gpr === c, msg;
    mov ebx: gpr === b, 1;
    mov eax: gpr === a, 4;
    int 0x80;
  }
}

print("Hello World!\n"); // prints "Hello World!\n".
```

More assembly language example snippets can be found [here](https://github.com/Jai-Community/Jai-Community-Library/wiki/Snippets-and--Benchmarks#assembly-language)

### Assembly Language Reference/Value

In an effort to reduce friction when using `#asm`, there is a by-reference / by-value distinction (like in high level code) as well as allowing by-value moves of structs into and out of vector registers. The intention of this is to let the compiler manage some moves such that they can be avoided during code generation. This allows you to drop single `#asm` instructions in small composable functions that will be properly collapsed by LLVM in release mode.

Here is an example of the by-value semantics:
```
Vector4 :: struct {
  x: float;
  y: float;
  z: float;
  w: float;
}

mul :: (a: Vector4, b: Vector4) -> Vector4 {
  result := a;
  #asm {
    mulps result, b;
  }
  return result;
}

add :: (a: Vector4, b: Vector4) -> Vector4 {
  result := a;
  #asm {
    addps result, b;
  }
  return result;
}

mad :: (a: Vector4, b: Vector4, c: Vector4) -> Vector4 {
  return add(mul(a, b), c);
}

main :: () {
  a := Vector4.{ 1.0, 2.0, 3.0, 4.0 };
  b := Vector4.{ 5.0, 6.0, 7.0, 8.0 };
  c := Vector4.{ 9.0, 10.0, 11.0, 12.0 };
  d := mad(a, b, c);
  print("%\n", d);
}
```

When compiled in LLVM release mode, the instruction stream for `main` looks like this:
```
movaps      xmm0,xmmword ptr [...]  // load `a` from a data segment
movaps      xmm1,xmmword ptr [...]  // load `b` from a data segment
mulps       xmm0,xmm1               // the instruction from `mul`
movaps      xmm1,xmmword ptr [...]  // load `c` from a data segment
addps       xmm0,xmm1               // the instruction from `add`
```

The functions all collapse into a few instructions.

The Vector4 struct **must** be 16-bytes in order for the compiler to accept a by-value move into a `xmm` register. 

Here is a simple example of the by-reference semantics:
```
Vector4 :: struct {
  x: float;
  y: float;
  z: float;
  w: float;
}

a := Vector4.{1.0,2.0,3.0,4.0};
b := Vector4.{5.0,6.0,7.0,8.0};

#asm {
  movups c:, [*b];
  mulps a, c;
}

print("%\n", a);
```

Only 128-bit `xmm` registers are supported. Due to LLVM complexity issues, `ymm` registers (256-bit SIMD registers) and `zmm` registers (512-bit SIMD registers) are NOT supported.

To see more concrete assembly language examples, visit [Encyclopedia of Jai Examples - Assembly Language Examples](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples/wiki/Assembly-Language-Examples)


## `#bytes` and adding binary data to your program

The `#bytes` directive puts individual bytes into your program as machine code. This could be used to write one's own assembler.

On `x86_64`, the `NOP` assembly instruction has an opcode of `0x90` (see [here](https://www.felixcloutier.com/x86/nop)). Given that inline assembly does not support NOP, and we find ourselves in a situation where we want to use NOP, we can use the bytes directive to get a NOP. Here, we use `#bytes` to add a `NOP` in between the two print statements.

```
NOP :: 0x90;

print("Hello World");
#bytes [NOP];         // put a NOP instruction in between two print statements.
print("Hello World");
```

Since `#bytes` merely inserts binary data into the program, technically, this means that `#bytes` can do literally almost anything.

```
main :: () {

  str := "Hello World!\n";
  ptr := str.data;
  #asm {
    mov ecx: gpr === c, ptr;
  }

  #bytes. [0x90, 0xb8, 0x04, 0x00, 0x00, 0x0,  0xbb, 0x01, 0x00, 0x00, 0x0,
           0xba, 0x0d, 0x00, 0x00, 0x00, 0xcd, 0x80, 0x90, 0x90, 0xb8, 0x01, 
           0x00, 0x00, 0x00, 0xbb, 0x00, 0x00, 0x00, 0x00, 0xcd, 0x80];
}
```
On `x86` Linux, this should be the `#bytes` equivalent of "Hello World!". Use `#bytes` to win an Obfuscated Jai Code Competition! :)

## Deprecated
You can mark up a function using the directive `deprecated`. Here is an example use case:
```
old_function :: () #deprecated {

}
```
If `old_function` is called anywhere in code, the compiler will generate a `deprecated` warning.

### Adding messages to deprecated functions
You can add string messages after deprecated procedures as warnings to tell someone to use a different procedure or different set of instructions to accomplish what you want.

```
old_function :: () #deprecated "please use the new_function :: () instead" {

}

new_function :: () {

}
```




