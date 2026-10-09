
--- Start of file: documents/01_overview.md ---
This is a basic summary of the Jai Programming Language history, compiler internals, and language features. An in-depth look at the design decisions of Jai can be found in the article: [Philosophy of Jai](https://github.com/Jai-Community/Jai-Community-Library/wiki/Philosophy-of-Jai)

### History
* Jonathan Blow is the author of this project
* Jonathan Blow started this compiler project in 2014 as a C++ replacement for game development
* Jonathan Blow is developing a 3D commercial Sokoban video game named [Order of the Sinking Star](https://www.orderofthesinkingstar.com/en/) to test the Jai Compiler
* [Order of the Sinking Star](https://www.orderofthesinkingstar.com/en/) is a 3D puzzle game around 250,000 lines of Jai code with 1000+ puzzle levels
* The closed beta started around January 2020
* During the 1st year, the beta grew to over 100 members
* During the 3rd year, the beta is over 500 members
* The compiler was around 10,000 lines of code in its initial form in 2014
* The compiler expanded to around 50,000 lines of code after adding the LLVM backend, macros, operator overloading, multiple return values, unions, etc.
* The compiler jumped to around 75,000 lines of code after adding inline assembly support

### Licensing
* Compiler is currently proprietary, and the compiler should not be distributed to anyone outside of beta testers
* When compiler source code is released, it will have a permissive software license (e.g. BSD or MIT license)
* Licensing to prevent **embrace, extend, extinguish** tactics of larger companies

### Current State
* Possible language syntax rewrite in the future
* Most language features are nailed down, adding minor improvements
* Focused on language semantics, code optimization not implemented yet

### Performance
* The goal is to compile 1M lines of code in <1s (from scratch, without delta builds).
* According to the CHANGELOG of beta 0.0.045, the official compilation speed is 250,000 lines per second using the x64 backend, measured using Sokoban as a benchmark.
* Optimized Code generated is just as fast as C. Code that does arithmetic on scalar values is just as fast as C code. However, SIMD operations must be hand optimized rather than relying on the compiler to do automatic SIMD intrinsics for you (see [Benchmarks](https://github.com/Jai-Community/Jai-Community-Library/wiki/Snippets-and--Benchmarks#benchmarks) for more info).

### Compiler Internals
* Compiler code is proprietary, but Jonathan intends to open-source it later
* Compiler was programmed in 87,000 lines of C++ code
* Jonathan Blow has no plans to self-host the compiler in the near future
* Multi-threaded Job System Compiler, Lexing and Parsing Parallelized
* Hand-written recursive descent top-down parser
* Compiler front-end is primarily written by Jonathan Blow
* Compiler has its own internal byte-code
* Two compiler backends: x64 and LLVM backend
* x64 backend was developed by Jonathan Blow and his compiler team
* x64 backend does fast but naive code generation, without any code optimization
* LLVM backend does better code optimization, but has slower compilation speed
* LLVM backend produces significantly better code generation than x64 backend
* Out of order compilation model

### Features
* Imperative, general purpose programming language
* Statically, strongly typed
* Supports x86 architecture only (limited Nintendo Switch support)
* Platforms: Windows, Ubuntu Linux 18.04, MacOS, at least one gaming console
* Basic WASM, Android, and iOS support
* Compiled language as fast and optimized as C or C++ code
* Arbitrary compile-time execution, with powerful metaprogramming features to modify your code in whatever way you want
* Compiler gives you the compiler AST (Abstract Syntax Tree) for you to modify
* User can access compiler through a compiler message loop
* Parameterized structs (similar to C++ templates or Java generics, except cleaner)
* Function polymorphism
* Multiple return values
* Operator Overloading
* Hygienic macros
* Stack Traces
* The syntax is not yet finalized
* Struct of Arrays supported through `#insert` directives.
* Context based allocation and Temporary Storage
* Basic multi-threading support (threads, mutexes)
* Inline Assembly with `SSE`, `AVX`, `AVX2`, `AVX512` SIMD instructions support
* Lambda Expressions (no closures)
* Notes (similar to Java annotations)
* Pointer auto-dereferencing
* Array Bounds Checking
* Cast Bounds Checking
* Math Bounds Checking
* Null Pointer Checking
* Cross Compiling (somewhat working. not fully working yet.)

### What will NOT be in Jai
* No Makefiles
* No header files
* No preprocessor
* No constructors or destructors
* No RAII (Resource acquisition is initialization)
* No exceptions
* No virtual functions/design patterns/object oriented inheritance hierarchies
* No incremental rebuilds
* No garbage collection
* No coroutines (e.g. no Go-style channels)
* No package managers
* No reference types
* No array programming
* No UFCS (Uniform Function Call Syntax, dot calls, object member function)
* No relative pointers
* No gotos

---

# Comparison with Other Languages
This is a comparison between Jai and other programming languages such as C++, Java, Rust, Go, Haskell, etc. This compares Jai and other languages in terms of language design, goals, and features.

---
# C++
## Similarities
Both Jai and C++ are statically typed, compiled languages, no garbage collection, and designed for performance oriented programs such as 3D games.

Both support generic programming, Jai does so with parameterized structs and C++ has templates.

Both support structs, unions, and enums in the same exact way.

Both support inline assembly.

Both support operator overloading.

### Pointers
Just like C, Jai has pointers with the same exact functionality as C, just using different operators for getting the address of and de-referencing a pointer. You can do pointer arithmetic on pointers as well as compare pointers against each other. Unlike C however, arrays do not cast to pointers, but rather arrays in Jai are objects with a data pointer and a count that counts the number of elements in an array.

## Differences
### Arrays
Arrays in C are equivalent to pointers, and arrays in C do not come with a count. In order to add a count to a C array, you either need to create a struct and pass the count to an array struct or pass an extra count parameter to a function. In Jai, however, arrays are objects with a pointer to the data as well as a count of how many objects are in an array.

### Malloc, New, Placement New
In C++, `new` is a keyword indicating a call to a heap allocation routine. In Jai, `New` is **not** a keyword built into the language, but rather regular function that does heap allocation. In Jai, you can change the way memory is allocated by passing a different context to the function. In C++, you can do a placement new, i.e. overload the `operator new` in order to change the behavior of the `new` keyword. In Jai, there is no such thing as a `operator new`.


### No Makefiles
C/C++ compilers do not have a way to specify how to build a program, and are reliant on outside systems foreign to the language to build the language, such as Makefiles, Ninja, and CMake. All these build systems are clunky, need to use a different system for different operating systems, and building a large program can be incredibly messy. In Jai, all you would ever need to compile your code is the compiler itself, no external dependencies.

### References
C++ has a concept for references (e.g. `void function(int &a);`). In Jai, there is no such concept as references. Operator overloading is implemented in this language without need for references.

### RAII (Resource Acquisition is Initialization)
Jai does not have any RAII, while C++ has RAII (Resource Acquisition is Initialization). C++ is a "big idea language", in that C++ dogmatically encourages RAII as the primary mechanism for handling everything from opening/closing files to mangaging memory. In C++, RAII is seen as fundamental dogma. Meanwhile, Jai has specialized mechanisms that handle specific cases well rather than have a "big idea" to solve everything.

### Object-Oriented Programming
C++ code usually has object oriented programs with massive inheritance hierarchies, and virtual functions overloading member functions. Although Jai can do function pointers, virtual functions are not supported in the compiler at all. Jai supports struct inclusion with the `using` keyword, but you cannot automatically generate functions with a `virtual` keyword like in C++.

Jai is less dogmatic about the "correct way" to write a program, and tries to provide a series of broad tools to do whatever you want rather than enforce an object oriented hierarchy designed through UML diagrams.

Jai does NOT have member functions. There is no concept of functions "belonging" to a particular struct or datatype. All member fields of a struct are public by default and there is no built in feature to make a member field private.

### const keyword
Jai has no concept of const. Littering your entire codebase with const everywhere just makes the code messier and more noisy. The concept of const can get confusing, and it does not help the compiler with anything.

### Volatile Keyword
This keyword is NOT inside the Jai Programming Language. Volatile is a confusing concept that means many different things and has an ambiguous use case.

### Macros
C/C++ macros are merely textual substitutions. C/C++ macros are powerful, but heavily error-prone, play terribly with the debugger, and lack any coherent structure. Jai macros are hygenic macros, meaning macros are better structured and checked by the compiler.

### For Loop Custom Iteration
In C, you can make a for loop through macros. However, C macros cause tons of problems due to its lack of proper structure, and using a macro in C are bad practice. C++ requires you to create 7+ different functions and/or data structures to create a custom for loop iteration. This can be tedious and painstaking for such a simple idea. In Jai, custom for loops are simple and clean, just create a **for_expansion** macro.

### Metaprogramming
C++ uses a mixture of object-oriented programming, template metaprogramming, macros, and C++ concepts to do metaprogramming. All these features are sloppily and incoherently put together, creating a giant mess of contradictory design problems for C++. The combination of all these features drastically slow down C++. In Jai however, arbitrary compile-time metaprogramming execution has been built into the language from the start. Metaprograms can modify the program in arbitrarily complex ways easily.

### Bitfields
This feature is NOT in the Jai Programming Language.

### Exceptions
There are no exceptions in Jai. Although C++ allows exceptions, they are strongly discouraged. Jai does not have exceptions at all, and they are not a language feature.

---
# Java
## Similarities
Both Jai and Java are statically typed.

Both support generic programming, Jai does so with parameterized structs and Java has generics.

Jai and Java have notes and annotations, respectively. Java annotations, however, can be parameterized.

## Differences

### Interpreted
Java code is translated into Java byte code, which then is run by the Java virtual machine. Jai is a compiled language that translates code directly into a binary executable. Jai can run programs in bytecode during compilation, but only at compile-time. At runtime, a Jai executable is executing machine code directly.

### Garbage Collection
Unlike Java, Jai does not have garbage collection. However, Jai takes a context-based allocation scheme in which the memory allocator is implicitly passed to all functions (unless otherwise specified with `#c_call`). The context can be overloaded with a custom allocator, and shifts the burden of memory management away from ambiguity towards being coordinated between the compiler and the user.

### Operator Overloading
Java does not have any operator overloading outside of string concatenation. Jai supports operator overloading in general for all sorts of different operations.

### Object-Oriented Programming
Java code usually has object oriented programs with massive inheritance hierarchies, and Java encourages overloading member functions. Although Jai has function pointers, Java-like member functions are not supported at all. For example, you cannot overload a `toString` function in order to print out a struct to the console.

Unlike Java, there is no base `Object` class in which all objects inherit from.

Jai is less dogmatic about the "correct way" to write a program, and tries to provide a series of broad tools to do whatever you want rather than enforce an object oriented hierarchy designed through UML diagrams.

### Exceptions
Java regularly uses and requires exceptions to handle files, read from a network socket, etc for flow control. Jai does not have exceptions at all. Exceptions are not a Jai language feature.

### Volatile Keyword
This keyword is NOT inside the Jai Programming Language. Volatile is a confusing concept that means many different things and has an ambiguous use case.

---
# Rust
## Similarities
Jai and Rust are both statically typed, compiled languages with no garbage collection. Both are designed for performance-critical applications, although Rust is not commonly used for game development.

Both support generic programming: Jai does so with parameterized structs, and Rust has generics.

Both support structs in the same way.

Both support operator overloading.

Both support hygienic Lisp-like macros that execute at compile time, enabling metaprogramming.

Neither language uses exceptions for error handling.

## Differences
### Mutable Variables
Rust variables are immutable by default. A variable declared as `let x: i32 = 42;` cannot be modified; you must explicitly opt into mutability with `let mut x: i32 = 42;`. Jai distinguishes between runtime mutable variables via `x : int = 42;` and compile-time constants via `x : int : 42;`. In general, variables in Jai are mutable by default.

### Borrow Checker
Rust is a "big idea" language built around a static compile-time ownership and borrowing system. The borrow checker attempts to eliminate entire classes of memory-related bugs at compile time. While valuable in some domains, this system creates significant friction with the allocation patterns common in game development, such as arena allocation and temporary storage. These patterns tend to work poorly with the borrow checker's ownership rules.

Because the borrow checker performs deep static analysis of pointer lifetimes, it also contributes to Rust's famously slow compile times. This runs counter to Jai's philosophy, which targets compiling one million lines of code per second. Jai does not have a built-in borrow checker. However, its metaprogramming features allow one to build arbitrary custom code analysis tools suited to whatever problem is at hand.

### References
Rust has a concept of references carried over from C++. Jai does not have a references feature.

### Incremental Rebuilds
Rust supports incremental compilation to help manage its compile times, which are primarily driven by the cost of borrow checking and monomorphization. Jai performs full fresh rebuilds every time and has no incremental compilation step. The philosophy here is that the compiler itself should simply be fast enough that incremental builds are unnecessary.

### Unsafe
Rust allows programmers to deliberately suspend certain safety guarantees using `unsafe` blocks, which is sometimes necessary for low-level work. In game development especially, large portions of a codebase may require `unsafe` — for example, any code that reads or writes to global mutable state must be wrapped in `unsafe`. When a significant portion of a codebase is marked `unsafe`, much of the benefit of Rust's safety model is lost. Jai addresses low-level concerns through its context-based allocation system and explicit memory management rather than through safety annotations.

### Pointers
Rust permits raw pointers only inside `unsafe` blocks, or through smart pointer and reference-counted types. Jai follows the C pointer model, allowing raw pointers freely throughout the program.

### Package Manager
Cargo is the package manager for Rust. Jai does not have a package manager.

### Iterators vs For Expansion Macros
Rust implements [iterators](https://doc.rust-lang.org/stable/rust-by-example/trait/iter.html) through a trait system. To make a custom type iterable, you implement a set of traits including `Iterator`. Jai takes a different approach entirely: there are no iterator traits. Instead, you write a `for_expansion` macro that defines exactly how the loop body behaves for your data structure, which is simpler and more direct.

### Error Handling
Rust uses `Option` and `Result` types to make fallibility explicit in function signatures, allowing callers to see at a glance whether a function can fail. Jai does not support these types at the compiler level, though they can be built in user code. Error handling in Jai is typically done through multiple return values.

### Metaprogramming
Rust's macro system is significantly more structured than C's, using token-stream manipulation rather than raw text substitution. Rust macros can be powerful, but procedural macros in particular are widely considered complex and difficult to write correctly.

In Jai, metaprogramming is designed to feel like ordinary programming. Code can be represented and manipulated as strings, then inserted at compile time with `#insert`. Functions can be generated through string manipulation routines. Macros are syntactically indistinguishable from regular function calls. The intention is that metaprogramming in Jai should not feel like a separate, intimidating system — it should feel like writing normal code that happens to run at compile time.

One area where Rust's macro system goes further is arbitrary syntax: procedural macros can process token streams flexibly enough that developers have embedded small domain-specific languages inside Rust. Jai's out-of-order compilation model makes this kind of arbitrary syntax extension incompatible with its design, so Jai does not support it.

---
# Go
## Similarities
Both Jai and Go are statically typed, compiled languages. Both do full rebuilds with no incremental compilation.

Both languages have a `defer` keyword. However, there is an important difference in behavior: in Go, a deferred statement executes at the end of the enclosing function, whereas in Jai it executes at the end of the enclosing block. This means Jai's defer inside a loop fires at the end of each loop iteration, not at the end of the function containing the loop.

## Differences
### Garbage Collection
Go uses a garbage collector to manage memory automatically. Jai does not. Instead, Jai uses a context-based allocation scheme in which the memory allocator is implicitly threaded through all function calls. The allocator stored in the context can be swapped out for a custom implementation, giving the programmer direct control over allocation strategy without requiring it to be passed explicitly to every function.

### Coroutines (Go Channels)
Go's concurrency model is built around goroutines and channels, which are well-suited to certain classes of problems such as networked services. Jai does not and will not support coroutines or Go-style channels. Jon's view is that these constructs address relatively simple concurrency scenarios while doing little to help with the harder problems that arise in areas like game engine development, where fine-grained control over memory layout and thread synchronization matters most.

### Panic
Go provides a `panic` and `recover` mechanism for handling unexpected runtime errors, which functions similarly to exceptions in other languages. Jai has no equivalent — there is no exception or panic system of any kind.

---

# Functional Languages (Haskell, Scheme, etc.)
## Similarities
### Metaprogramming
Both Jai and Lisp-like functional programming languages have powerful, robust metaprogramming features capable of arbitrary unlimited functionality. The only limitation of Jai metaprogramming is that all metaprogramming is limited strictly to compile-time execution. Meanwhile, Lisp-like functional programming languages can do arbitrary metaprogramming at both the runtime and compile-time level, but as a result, suffer serious performance issues.

### Function Currying
Functional programming languages have the powerful ability to curry arbitrary functions at compile and runtime, and create new functions by currying values together. Jai has function currying through `#bake_arguments`, except function curry only happens at compile time. There is **no** runtime function currying in Jai.

## Differences
### Linked Lists
In Functional Programming Languages, linked lists are the fundamental data structure. In Jai, arrays and looping over arrays is the most part of Jai. Linked lists are defined as a struct.

### Pattern Matching
Functional Programming Languages use pattern matching to pattern match statements to the correct control flow. This feature is not be in Jai. Jai is based on traditional imperative structured programming languages with while loops, if statements, and for loops. The closest thing to pattern matching would be `if case` statements.

### Lazy Evaluation
This will not be in Jai. Lazy evaluation makes no sense in an imperative programming language where adding two number together generates literal machine code that adds two numbers together. Jai is about generating high-level code that has a close as possible mapping to machine code.

---

# Scripting Languages (PHP, JavaScript, Ruby, Python, etc.)

|Feature|Jai|Scripting Languages|
|-------|---|-------------------|
|Garbage Collection|Jai does not not have garbage collection. However, Jai takes a context-based allocation scheme in which the memory allocator is implicitly passed to all functions (unless otherwise specified with `#c_call`). The context can be overloaded with a custom allocator, and shifts the burden of memory management away from ambiguity towards being coordinated between the compiler and the user. Also see #memory-management |[PHP](https://www.php.net/manual/en/features.gc.php), [JavaScript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Memory_Management), [Ruby](https://docs.ruby-lang.org/en/3.0.0/GC.html), [Python](https://docs.python.org/3/library/gc.html) all use Garbage Collection. 
|Generator Functions| Jai does not have generator functions. These are high-level language features that do not compile down to fast code. The closest Jai language feature to generator functions is writing a custom for_expansion macro for a for loop. | Python, Ruby, Perl, Javascript
|Dynamic Typing| Jai is a statically compiled language, meaning all variables must be labeled and defined at compile time through a type system. Unlike scripting languages which allow you to randomly create new structs at runtime, Jai requires you to define every struct at compile-time. | Python, Ruby, Perl, Javascript

---

### Compiler Videos vs Current State of the Language
This article compares the current state of the Jai Programming Language against Jonathan Blow's Compiler Videos. The Jai Programming Language has changed significantly since those videos have been posted, and this article attempts to keep track of language features which are still in the language, and which language features have been replaced/removed.


[Data-Oriented Demo: SOA, composition](https://www.youtube.com/watch?v=ZHqFrNyLlpA)
* SOA (Structure of Arrays) have been removed from the language. This has been replaced by a more generalized metaprogramming system involving `#insert` directive. See [SOA](https://jai.community/t/struct-of-arrays-soa/136).
* `using` has been modified to only pull in a struct into a namespace. The "inherited" `structs` do not alias for base structs anymore, to get this aliasing effect, you need to do `using #as Object`.

[Macros and Iteration](https://www.youtube.com/watch?v=QX46eLqq1ps)
* `for_expansion` no longer has the function signature `for_expansion :: (obj: *Object, code: Code, a: bool, b: bool)`. It now has the function signature `for_expansion :: (obj: *Object, code: Code, flags: For_Flags)`.
* Macros can return values
* `#insert_internal` has been removed from the compiler. This feature has been replaced by `#insert, scope(code);`.

[Structs with Parameters](https://www.youtube.com/watch?v=2IBr0XZOPsk)
* Structs and Function Polymorphism concepts have been unified together
* Objects can now be written as:
```
Object :: struct(t: $T) {
  // stuff
}
```
* You can do arrays as: `array: [$N] int`
```
function :: (array: [$N] int) {

}
```
* Array literals have been changed. Now the syntax is: `int.[1,2,3,4,5,6]`.

* The `#place` directive has been removed from the language. Now there is the `#overlay` directive syntax used like this:
```
Object :: struct {
    x: int;
    #overlay (x) y: int;
}
```


[Constructors, Destructors](https://www.youtube.com/watch?v=8C6zuDDGU2w)
* Constructors and Destructors have been removed from the language

[Polymorphic Procedures, part 2](https://www.youtube.com/watch?v=7Fsy2WaxLOY&list=PLmV5I2fxaiCKfxMBrNsU1kgKJXD3PkyxO&index=13)
* `#body_text` has been removed from the language. Use `#insert` directives.

[Demo: Operator Overloading](https://www.youtube.com/watch?v=cpPsfcxP4lg)
* Procedures can no longer be called using `a 'cross' b`. This feature has been removed.


[Demo: Relative Pointers](https://www.youtube.com/watch?v=Z0tsNFZLxSU&ab_channel=JonathanBlow)
* Relative Pointers have been removed from the language
* Relative Pointers had too many downsides to having them built in automatically. e.g. runtime checks for relative pointer safety are difficult to implement

[Demo: LLVM Back-End, Speed Overview (part 1)](https://www.youtube.com/watch?v=HLk4eiGUic8)
* There is no C backend anymore. There is a x64 backend, however.

[Arguments and Return Values](https://www.youtube.com/watch?v=CttIYXCUeVY)
* The `#must` directive has been removed from the language.


--- End of file: documents/01_overview.md ---

--- Start of file: documents/02_getting_started.md ---
# Getting Started

This is a guide to help you get started with Jai. It assumes that you've done at least some programming before, and will often state the differences between Jai and languages such as C or C++. This section covers basic things such as variables, types, flow control, and looping. More advanced topics such as polymorphism, inline assembly, and context are covered under the advanced section.

If you prefer to learn by example as opposed to reading theoretical definitions consider: [Encyclopedia of Jai Examples](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples/wiki)

## Running Jai

1. Download and extract the Jai compiler to a custom directory.
   * On Linux, you might consider `/opt/jai`
2. Set your environment to know how to find the `jai`-binary
   * for Windows, add the path to `jai.exe` to your `%PATH`.
   * On Linux, a symbolic link like `ln -s /path/to/jai/bin/jai /usr/bin/jai` will get you there.
3. Compile a Jai program via `jai main.jai`, given that there's a `main.jai` file in your current path.
4. Run the generated executable.

If you are having installation problems, consider reading the [Troubleshooting](https://github.com/Jai-Community/Jai-Community-Library/wiki/Snippets-and--Benchmarks#troubleshooting) section.

## Hello, World!

This horrific cliché of an initial program does nothing to express the actual power of any language, but it does serve as a convenient [crib](https://en.wikipedia.org/wiki/Known-plaintext_attack) to get an idea of what the language will look like and its baseline semantics.

```
#import "Basic";

main :: () {
    print("Hello, World!\n");
}
```

Save this to `hello.jai` and compile it with `jai hello.jai`. Then you should be able to run: `./hello` or `hello.exe` (depending on your OS).

Some basics, here:
 * `#import` imports a module, in this case the bundled module `Basic`.
 * Each and every Jai program must have a `main` function.
 * The `::` operator is used to define a constant. Top level functions are typically constant.
 * The syntax is pretty C-like in many regard. Statements are terminated with `;`.
 * The function `print` comes from the `Basic` library. More on it later!

By the way, comments are useful:
```
// Single line comment; starts at the slashes, ends at the end of line.
/*
 *  Multiline comment, starts at the opening /* and ends at the */ 
 *  But hey, here's something odd! In C or C++, the closing bit ^-- here would have ended the comment. 
 *  But in Jai, you can nest multiline comments.
 */
```

## `#import` and `#load`

_Modules_ are stored in the compiler directory under `jai/modules/`.
Modules can be imported via `#import "ModuleName";`. 
You can create your own module by simply putting it in `jai/modules/`.
This can also be done inside a folder `jai/modules/YourModuleFolder/`. In this case, you need to have a `module.jai` inside the folder.
Modules can be assigned to identifiers e.g. `Math :: #import "Math";`. Then everything inside the module will be namespaced with the given name, e.g. `Math.sqrt(...)`.
Additional modules from other directories can be imported via the `-import_dir "Path/To/Module"` flag, e.g. to load a `module.jai` in the same folder:
```
jai hello_world.jai -import_dir "./"
```

You can load any `jai`-file via `#load`, e.g. `#load "my_file.jai";`. The path is relative to the calling file. 
Think of _loading_ a file as pasting the code directly into the calling file: If you load two files
```
#load "file_a.jai";
#load "file_b.jai";
```
then all (exported) functions/structs/globals of `file_a` will be available in `file_b` and vice versa.

### Named `#import`
You can name modules that are imported. A named `#import` allows you to namespace function. This allows you to resolve namespace collusions in code.
```
Math :: #import "Math";
y := Math.sqrt(2.0);
```

### `import file, dir, string`
You can import a specific `file`, `dir`, and `string` based on what you prefer. 

```
module :: #import, file "themodule/module.jai";
```
This loads a file with a known filename, without searching the `import_path`.

```
module :: #import, dir "files/directory";
```
This loads a directory-style module from a specific path.

```
#import, string "factorial :: (x: int) -> int { if x <= 1 return 1; return x*factorial(x-1);}";
```
This loads a specific string into your program. This string must be known at parse time, meaning it cannot import runtime code created by `#run` directives.

## Variables, constants, and types

Variables are defined using the `:=` operator, which allows you to specify a type and a value for your new variable. Specifically:
```
name : type = value;
```

For example:
```
a : int = 3;
b : string = "hello";
```

We'll get into the details of the available types in a bit, but first, a bit more about this declaration syntax.

While `name` obviously can't be skipped, either the type or the value can be. If you skip the type, it will be inferred from the provided value. If you skip the value, it will be initialized to whatever is the zero-equivalent for the type. For example:

```
a := 3;         // Inferred as int.
b := 3.1415;    // Inferred as float.
c := "hello";   // Inferred as string.
d : string;     // Defaults to empty string, "".
e : *u32;       // Defaults to a null pointer to a u32.
f := #char "1"; // Inferred as s64. f has the value of the ASCII character '1'
```

Earlier, we mentioned the `::` syntax, which is used instead of `:=` when defining constants. But much like `:=`, you can separate the two colons to specify the type if you want to be precise. For example:
```
PI :: 3.141592;
my_word : u16 : 65535;
```
You'll notice later that we typically define functions, structs and various other things as constants most of the time.

### Types

Jai comes with a number of basic types, along with some mechanisms to create custom types.

The basic types are:
 * `bool`       - a boolean, that can take values `true` or `false`. This value takes up 8 bits of memory.
 * `s8`, `u8`   - signed and unsigned 8 bit integers.
 * `s16`, `u16` - signed and unsigned 16 bit integers.
 * `s32`, `u32` - signed and unsigned 32 bit integers.
 * `s64`, `u64` - signed and unsigned 64 bit integers.
 * `float32`    - 32 bit floating point number.
 * `float64`    - 64 bit floating point number.
 * `string`     - a string, an array view of u8. Jai strings are NOT zero-terminated

Additionally, there are `int` which defaults to `s64` and `float` which defaults to `float32`. The type `void` also exists, but you'll probably use it less than in some other languages that have that type.

### Assignment and arithmetic operators

Although you declare variables using the `:=` format, you assign values just using the `=`-part, such as:
```
mynumber := 5; // Declare variable
mynumber = 17; // Assign 17 to variable.
```

Arithmetic is performed using the regular `+`, `-`, `*`, `/` and `%` operators for addition, subtraction, multiplication, division and modulus respectively.

As in many programming languages, there are convenient variations on the assignment operator available for arithmetic manipulation as needed, namely `+=`, `-=`, `*=`, `/=` and `%=`, corresponding to the appropriate arithmetic operators. Note that unlike some other languages, there are no increment or decrement operators.

If the user does not explicitly initialize a variable, the variable is set to zero. You can have explicitly uninitialized variables by typing `a: int = ---`. Uninitialized variables have undefined behavior until a value is written to.

### Compound Assignments

`a, b = b, a` will swap elements. This also works for longer sequences with arbitrary permutations. All right hand side values are evaluated in the first pass, and then assignments are done to the left hand side values on the second pass.

### Boolean and bitwise operators

In addition to a normal range of arithmetic operators, Jai has a number of boolean operators, namely:

 * `!` - boolean NOT
 * `||` - boolean OR
 * `&&` - boolean AND

Additionally, it has a number of bitwise operators:

 * `|` - bitwise OR
 * `&` - bitwise AND
 * `^` - bitwise XOR
 * `<<` - shift left
 * `<<<` - rotate left
 * `>>` - shift right
 * `>>>` - rotate right
 * `~` - bitwise NOT (one's complement) (unary) 

The bitwise operators perform an arithmetic shift, following C's rules regarding bitwise operators.

Bitwise AND compares the respective bits between two numbers together. If both respective bits are 1, then the output is 1. If either respective bits are 0, then the output is zero.
```
  11001100
& 10001000
----------
= 10001000
```

Bitwise OR compares the respective bits between two numbers together. If either respective bits are 1, then the output is 1. If both respective bits are 0, then the output is zero.
```
  11001100
| 10000011
----------
= 11001111
```

### Number literals

You can write number literals in a number of ways. First off, you have typical decimal format, but additionally there are prefixes for hexadecimal and binary numbers. Unlike many languages, there is no special format for octal literals. You can optionally use an underscore to separate digit groups as desired. For example:

```
A :: 10;   // here's a 10
C :: 0b10; // this is 2 in binary
B :: 0x10; // and this is 16 in hexadecimal
D :: 0b1010_0010_0101_1111;
E :: 0xFFFF_FF_FF;      // This is inconsistent and weird, but legal.
F :: 16_777_216;
```

### Strings
Strings are a datatype representing a sequence of characters, where each character is a byte, or `u8`. Here is the definition for a string:
```
string :: struct {
  count: int;
  data: *u8;
}
```
The `count` represents the length of the string, while `data` is the pointer to the data. String has the same definition as array view.

### Multi-line String
Multi-line strings can be declared first by typing in the identifier, followed by an assign statement, `#string`, following by a token indicator for the end of the string, followed by the multi-line string.

```
multi_line_string := #string END_STRING
This
is
a
multi-line
string.
END_STRING;

print(multi_line_string);
```
In the example above, `multi_line_string` prints out:
```
This
is
a
multi-line
string.
```

### Strings as boolean values

Strings implicitly cast to boolean values that can be then used in if statements. If `str` has characters in it, then the automatic cast to `boolean` is `true`. Otherwise if `str` is an empty string, it is `false`.
```
str : string = "Hello.";
if str {

} else {

}
```

### String operations
Here are some common string operations people may use that are available in the `String` and `Basic` module:

```
// string comparing functions
equal :: (a: string, b: string) -> bool;
compare :: (a: string, b: string) -> int;
contains :: (str: string, substring: string) -> bool;
```
`equal` checks if two strings are equal. Returns true if both strings are equal. Returns false if not equal. `compare` compares two strings `a` and `b`. Returns -1 if `a` is less than `b`, 1 if `a` is greater than `b`, and 0 if they are equal. Similar to `strcmp` in C. `contains` returns `true` if the string contains `substring`.


```
// string begins with and ends with functions
begins_with :: (str: string, prefix: string) -> bool;
ends_with :: (str: string, suffix: string) -> bool;
```
`begins_with` checks if a given string begins with a specified prefix. `ends_with` checks if a given string ends with a specified suffix.

```
// concatenating and spliting strings
join :: (inputs: .. string, separator := "", before_first := false, after_last := false) -> string;
split :: (str: string, separator: string) -> [] string;
```
Joins all the string inputs together to form a larger string. For example: `join("a","b","c","d")` outputs "abcd".
Splits an input string according to a separator.

```
// string to int/float and parsing functions
string_to_int :: (str: string) -> int, bool;
string_to_float :: (str: string) -> float, bool;
parse_float :: (line: *string) -> float, bool;
parse_int :: (line: *string) -> int, bool;
parse_token :: (line: *string) -> string, bool;
```
Attempts to parse a string into a float, token, or int.

```
// c string manipulation functions
to_c_string :: (str: string) -> *u8; // NOTE: This function heap allocates memory
c_style_strlen :: (ptr: *u8) -> int;
```
These functions manipulate c-strings received from c-libraries

### Any Type
The `Any` Type is a type that is matches against all other types in the language. Structs, primitives, strings, arrays, array views, and dynamic arrays are all auto castable to `Any` Type. Take for example the `print` function in the Basic module:
```
print :: (fmt: string, param: ..Any) {
  //..
}
```
The print function takes in a variable number of type `Any` parameters at compile time, and the type information is available at runtime.

The `Any` Type is a struct of two values: the type info and the pointer to the value.
```
Any :: struct {
  type: *Type_Info;
  value_pointer: *void;
}
```

When you assign a variable to `Any`, it translates to the following:
```
number: int = 8;
any: Any;
any = number;

// these two expressions are the same.
any.type = type_of(number);
any.value_pointer = *number;
```

### Casting

The type system in Jai is fairly strict. Types, though similar, may need explicit casting if there is any risk of loss of information. Therefore, you can cast a `u16` to a `u32` implicitly, but you can't cast a `u32` to a `u16` without being explicit about it, and the compiler will give you an error if you attempt to.

Instead, you can use `cast()`, like so:
```
a : u32 = 50000;
b : u16;

b = cast(u16) a;
```
Now, in this case the value of `a` in this case fit into a `u16`, so this was no problem. But what happens if you had a bigger value, such as `a = 16000000;`?
In this case, by default, you'll get a runtime error:
```
Cast bounds check failed.  Number must be in [0, 65535]; it was 16000000.  Site is example.jai:8.
```
This is to say, you cannot just throw away information without being explicit about your intent. This may seem annoying, but it's actually going to save you in a lot of cases. If you do decide to throw away unwanted information, you can do so in two ways - but note that they are actually identical: `trunc` and `no_check`. They both exist so that you can document your intent ─ are you trying to explicitly throw away information (`trunc`), or are you just trying to make it run fast by skipping runtime boundary checks (`no_check`)?

Either way, if you do `b = cast,trunc(u16) a;` or `b = cast,no_check(u16) a;`, the new value of `b` is 9216, thereby truncating the bits you don't care about. This will speed up your code, so it can be good if you have a way to be certain that you'll not exceed the bounds, but if you're not careful something strange might happen.

It's worth noting that you can turn off bounds checking at run time (see Metaprogramming section) if you want your build to run at maximum speed, with the penalty of possible accidental truncation.

In many cases, you want to just cast but you don't really care what the receiving type is. For these situations there is an autocast operator, `xx`, which you can use to cast while glossing over the details:
```
b = xx a;
```

### Pointers
A pointer is an address data type. It is used to store the address of another variable. In Jai, just like C, pointers are defined using the `*` marker; but beware, the syntax is a bit different from C or C++. 
```
a : int = 42; // Just a normal integer
b : *int;     // Here's a pointer to a integer.

b = *a; // Point b at a.
print("Value of a is %, address of a is %\n", a, *a);
print("Value of b is %, but b points at address %\n", b.*, b);
```
As you can see there, we use unary `*` to get the address of a variable. The `.*` can also be used to dereference a pointer.

### Pointer Arithmetic
A pointer is a data address, which is a numeric value. You can perform arithmetic operations such as `+`, `-`, `*`, and `/` on a pointer just as you can on a numeric value. You can check pointers for equality using `==`, `!=`, `<`, `<=`, `>`, and `>=`.

```
array: [10] int
a: *int = array.data; // set a to point to array.data
a += 1;
```

In the example above, incrementing pointer `a` by 1 adds 8 to the pointer, since a 64-bit integer consists of 8 bytes. A pointer increments depending on the size of the data the pointer points to.

### void pointer
`variable: *void;` is a void pointer, or a pointer with no associated data type. A void pointer can hold the address of any type and can be typcasted to any type. void pointer has the same functionality as in C.


### Pointers to Pointers
Just like in C++, pointers can also point to other pointers, allowing multiple indirection.
```
a: int = 3;
b: *int = *a;
c: **int = *b;
d: ***int = *c;
print("%\n", d.*.*.*); // prints out the value of a, which is 3
```

### Function Pointers
Function pointers can be declared almost in the same way as regular functions.
```
function :: (a: int, b: int)->int { // declare function
  return a + b; 
} 

f_ptr: (int,int)->int = function;

// call the function that the function pointer is pointing to
c := f_ptr(1,2); 
```

## Reserved Keywords and Identifiers
This is a list of keywords and identifiers available in the Jai Programming Language. This is not a comprehensive list, and is subject to change while the programming language is still inside the closed beta.
| Keywords                             |    Purpose |
| ------------------------------------ | ---------- |
| `bool`, `true`, `false` | boolean keywords |
| `int`, `s8`, `u8`, `s16`, `u16`, `s32`, `u32`, `s64`, `u64` | integers |
| `float`, `float32`, `float64` | float point numbers |
| `void` | Just like C, it means nothing, and when used in `void*`, means a pointer to anything |
| `enum`, `enum_flags` | enums and enum_flags keyword |
| `size_of` | used to get the size of a type. To use it on a variable, do `size_of(type_of(variable))`. |
| `struct`, `using`, `union` | Keywords denoting a record with multiple data members |
| `string` | Denotes a string of characters such as `"John Newton"` |
| `type_of` | used to get the type of something. |
| `cast` | used to cast a variable to a different type. For example, `b := cast(int)a`. |
| `if`, `ifx`, `then`, `else`, `case` | if statement and branching keywords |
| `for`, `while` | Looping and control flow statements|
| `break`, `continue`, `remove` | Used to for control flow within a loop |
| `return` | Returns from a function |
| `defer` | Similar to the Go Language. This statement is executed at the closing of a code block. |
| `inline` | Forced inlining of a particular function |

## Arrays

In addition to scalar variables, Jai supports both static and dynamic arrays, and array views. 

### Static arrays 

```
a : [4]u32;      // An array of 4 u32 integers.
b : [30]float64; // An array of 30 float64's.
```
You access array members similarly to in other languages, using the `[]` subscript syntax.

```
a: [4]float; 
a[0] = 10.0;
a[1] = 20.0;
a[2] = 1.4;
a[3] = 10.0;

print("a = %\n", a);
```
> **Note:** The `print` function uses `%` to indicate insertion points for variables. Unlike the C language `printf`, you don't need to specify what kind of thing is being printed, and it handles complex types too. However, if you want any special formatting of the variable to be printed, you must handle that separately.

You can initialize arrays using the following syntax:
```
array : [4]float = float.[10.0, 20.0, 1.4, 10.0];
```

Unlike C, Jai stores array length information. You can find out the array length by using `array.count`.
```
print("array has % number of elements\n", array.count);
```

### Using Arrays as boolean values

Arrays implicitly convert to boolean values, and can be used in if statements to check if the array has elements. If an array has at least one element in the array, the boolean value of the array is `true`. If the array has zero elements, the boolean value of the array is `false`.
```
array: [..] int;
if array {

} 
```

### Multi-Dimensional Static arrays 
Jai supports multi-dimensional static arrays. Multi-dimensional static arrays can be declared like this:
```
a: [4][4] float;    // 2D static array
b: [4][4][4] float; // 3D static array
```
Multi-dimenional arrays can be initialized using the following syntax:
```
array: [2][2] int = .[int.[1,0], int.[0,3]];
```

### Heap-allocated arrays

A simple way of generating heap-allocated arrays is by `#import "Basic";` and using `NewArray`:
```
a := NewArray(4, float); // will heap-allocate an array of 4 floats.
```
You can also pass a custom allocator and more, see `Basic/module.jai` (line 477 in beta 0.0.102)
Make sure to free memory via `array_free(a);`.

### Dynamic arrays

Sometimes you don't know how many you will need in your list. Dynamic arrays are the most basic data structure at your disposal for arbitrary-length data. You can of course build much more powerful data structures if you need them, but you'll be surprised at how often a dynamic array is just what you need. Here's the declaration syntax:
```
a : [..]int;   // A dynamic array of integers.
b : [..]string;  // A dynamic array of strings.
```
A few things to note about dynamic arrays:
 * They allocate memory as needed.
 * When you add things, memory is reallocated as needed.
 * They will use your context's default allocator; this will be explained later.

Here is the struct definition and member fields of the resizable array found in `Preload.jai`:
```
Resizable_Array :: struct {
  count: s64;             // number of elements in the array
  data : *void;           // array data
  allocated: s64;         // total space used by the resizable array
  allocator: Allocator;   // the allocator in use by the resizable array
}
```
The resizable array functions similar to C++ `std::vector`, but with the added bonus that they use your current context's allocator. Contexts are explained in a different section ─ for now, just know that this is pretty great.

With those caveats out of the way, here's how you work with them:
```
array_add(*myarray, 5); // Add 5 to the end of myarray
array_add(*myarray, 9); // Add 9 to the end of myarray
array_reset(*myarray);  // Reset myarray
array_find(myarray, 5); // look for 5 in myarray
array_copy(*anotherarray, myarray); // copy array into anotherarray
```

In many cases, you'll be adding a number of entries to dynamic arrays at once, and you might even know how many there are. For this situation, it's worth considering that allocating once is almost always better than allocating as needed. Here we're going to demonstrate this using a loop ─ if these are unfamiliar to you, check ahead to the chapter on `for` loops before reading on.

```
myarray : [..]int;
N :: 50;
for 1..N array_add(*myarray, it);
```
The above example works just fine, but involves many additional allocations for no reason, since we already knew we were going to add 50 items. So it's better to do:
```
myarray : [..]int;
N :: 50;
array_reserve(*myarray, N); // Reserve 50 items!
for 1..N array_add(*myarray, it);
```

This will only perform one allocation as opposed to guessing and adjusting every time `array_add` is called.

Note that `array_reserve` wants the total number of items to reserve, not the number to additionally reserve. So you may want to use `myarray.count` or `myarray.allocated` to get the number of items currently in the array, or the number currently reserved in the array.
Alternatively, you can write a small helper function as in [`NewResizableArray`](https://github.com/Jai-Community/Jai-Community-Library/wiki/Snippets#resizable-array-with-initial-size).

When you're done with a dynamic array, it's good to `array_free` the array. Consider using `defer` for this!

### Array views

The array view data structure represents a view into the data that is contained in an array or a subsection of an array. Here is how the array view is declared.
```
arr: []int = int.[1,2,3,4,5];
```
This is the array view struct declaration and data fields as found in `Preload.jai`:
```
Array_View_64 :: struct {
  count: s64;  // number of elements
  data : *u8;  // pointer to element array data
}
```
Both Static Arrays and Dynamic Arrays are autocasted to Array Views if the array view is a parameter. Because strings are array views with `u8`,  both share the same definition.

## Loops and Branching
### `if` statements

The basic conditional statement in Jai is similar to other languages:
```
if a == b  
    print("They're equal!\n"); 
else
    print("They're not equal!\n");
```
Unlike many other languages, the condition does not require parenthesis. Optionally, you can put a `then` after the condition. This can be convenient for visual separation in some cases. Like so:
```
if a == b then print("They're equal!\n"); 
```

The comparison operators are:
 * `==` - logical equivalence
 * `!=` - logical inequivalence
 * `<` - less than
 * `>` - greater than
 * `<=` - less than or equal
 * `>=` - greater than or equal

### `if`, `else if` statements
An `if` statement can be followed by multiple `else if` statements to test various other conditions.
```
grade := 100;
if grade >= 97 {
  print("Your grade is an A+\n");
} else if grade >= 90 {
  print("Your grade is an A\n");
} else if grade >= 80 {
  print("Your grade is a B\n");
} else if grade >= 70 {
  print("Your grade is a C\n");
} else if grade >= 60 {
  print("Your grade is a D\n");
} else {
  print("You grade is a F\n");
}
```
Here is the static compile-time version of `#if` statements.
```
CONSTANT :: 3;
#if CONSTANT == 0 {

} else #if CONSTANT == 1 {

} else #if CONSTANT == 2 {

}
```

### ifx Ternary Operator Statement
Just like C++, Jai has its own ternary operator statement. `ifx` allows a programmer to condense a simple `if` statement down to a single line statement. The syntax of `ifx` is `ifx` followed by a condition statement, the value assigned if the condition is true, `else`, and finally the value assign if the condition is false.
```
a := 0;
b := 100;
c := ifx a > b 10 else 1000;
d := ifx a > b then 10 else 1000;
```

### Case branching

The `if-case` statement in Jai allows a variable to be tested for equality against a list of values. Each value is called a case, and the variable is checked for each case. This `if-case` statement is similar to a `switch` statement in C, with a few exceptions. Unlike C, there is no need to put a `break` statement after each case to prevent fallthrough, if there is a `break` statement in the `if-case`, the statement will attempt to break out of a loop the statement is nested in. Also unlike C, there is no need to add brackets to segregate the cases. `case;` will assign to the default value.
```
a := 0;
if a == {
case 0;
  print("case 0\n"); // because a=0, this if-case statement will print out "case 0".
case 1;
  print("case 1\n"); // because a=0, this will be ignored
case;
  print("default case\n"); // because a=0, this print will be ignored.
}
```
Fallthrough switch behavior like in C can be obtained by adding a `#through;` at the end of a case statement.
```
a := 0;
if a == {
case 0;
  print("case 0\n"); // because a=0, this if-case statement will print out "case 0".
  #through;
case 1;
  // because of the #through statement, this if-case statement will print out "case 1" 
  // in addition to "case 0". 
  print("case 1\n"); 
case;
  print("default case\n"); // because there is no #through statement, this print will be ignored
}
```
`if-case` statements work on integers, strings, enums, bools, arrays, and floats. Be careful when using `if-case` statements with floats since floating point numbers approximate values.

The `#complete` compiler directive requires you to fill out all the case possibilities when using enum. This is useful when adding additional enum members to an enum. `#complete` only works when applied to enums or enum_flag datatypes.
```
Val :: enum { A; B; C; }

a := Val.A;
if #complete a == {
case Val.A;
  print("This is Val.A case\n");
case Val.B;
  print("This is Val.B case\n");
case Val.C;
  print("This is Val.C case\n");
}
```

### `while` loops

While loops simply loop until the loop condition is met. Their syntax is `while condition action;`, where `condition` is some expression that can be evaluated as true or false, and action is a statement or a block of statements. For instance:

```
n := 0;
while n < 10 {
    n += 1;
}
```
This `while` loop keeps on incrementing the `n` variable when `n` is less than 10. When `n` is no longer less than 10, the program will terminate the loop.

### `for` loops

If you have a type that can be iterated over, such as an array of some sort, you can use a `for` loop to iterate through it. For-loops in Jai are actually deceptively powerful, for a few reasons.

The simple format for for loops is `for set action`, where the `set` is something that supports iteration and `action` is a statement or a block.

To iterate over a sequence of numbers, say from 1 to 10, simply do:
```
for number:1..10 print("Number %\n", number);
```
Here, `number` is the iterator variable name, but Jai allows you to skip it, in which case it will be called `it` by default:
```
for 1..10 print("Number %\n", it);
```
It's worth noting that this will iterate from 1 to 10 _inclusive_, or, as mathematicians might put it, _[1, 10]_.

Sometimes, you want the index to be a non `s64` type. In the following example, `i` is casted to a `s8` type:
```
for i: 0..cast(u8)255 {
  // casts i to s8.
  print("%\n", i);
}
```

Often, rather than iterating over a sequence of numbers, you'll want to iterate over an array. Then you simply state the array name as the set. For instance:
```
my_array := u8.[5, 10, 15, 20, 25, 30];
for my_array {
    print("We got a %\n", it);
}
```
In addition to `it`, Jai also defines `it_index` by default, which contains the index of the item.
```
foods := string.["Burek", "Pho", "Khachapuri", "Empanadas", "Jjajangmyeon"];
print("Top five dishes:\n");
for foods {
    print(" %. %\n", it_index, it);
}
```
### `break` statement
The break statement terminates the current loop immediately after the break statement is executed. The `break` statement works in both `for` and `while` loops. 
```
for i: 0..5 {  // This for loop prints out 0, 1, 2 then breaks out of the loop
  if i == 3
    break;
  print("%, ", i);
}
```
In the example above, the for loop loops three times, printing out 0, 1, 2, then the break statement stops the iteration.

The `break` statement can also be used to break out of an outer loop through the syntax: break `var`, where `var` is the variable
name in the for loop. Here is the syntax for using `break` to `break` from an outer `for` loop.
```
for i: 0..5 {  
  for j: 0..5 {
    if i == 3
      break i; // breaks out of the outer loop for i: 0..5
    print("(%, %)", i, j);
  }
}
```
The example above prints out (0,0), (0,1), (0,2), (0,3)... (2,5), then when it reaches i==3, the break statement stops the outer loop.

### `continue` statement
The continue statement is used to skip all the statements in the current loop after the continue statement is executed. The `continue` statement works in both `for` and `while` loops. 
```
for i: 0..5 {  // This for loop prints out 0, 1, 2, 4, 5
  if i == 3
    continue;
  print("%, ", i);
}
```
In the example above, the for loop loops six times, printing out 0, 1, 2, 4, 5. The value of 3 is not printed since the continue statement causes the program to skip the rest of the loop.

The `continue` statement can also be used to skip to the outer loop through the syntax: continue `var`, continue `var` is the variable
name in the for loop.

```
for i: 0..5 {  
  for j: 0..5 {
    if i == 3
      continue i; // breaks out of the outer loop for i: 0..5
    print("(%, %)", i, j);
  }
}
```
The example above prints out (0,0), (0,1), (0,2), (0,3)... (2,5), (4,0), (4,1), (4,2)...(5,5). The for-loop skips all the value pairs starting with a 3, since the continue skips all the instructions after the continue statement.

### Breaking out of an outer `while` loop

`break` and `continue` can also be used to modify the control flow of a `while` loop, not just a `for` loop. As you can see in the example below, `condition` is used to label a `while` loop. There is a nested loop inside of the outer loop. `break condition` is being used to break out of an outer `while` loop when the control flow is in the inner loop.
```
x := 0;
while condition := x < 10 {
  y := 0;
  while y < 3 {
    print("x=%, y=%\n", x, y);
    y += 1;
    if x > 3
      break condition; // break out of an outer while loop
  }

  x += 1;
}
```


### `remove` statement
The remove statement is used to remove an element from a dynamic array [..] without needing to rewrite the entire for loop into a while loop. The remove statement assumes an unordered remove, the remove swaps the current element that is being iterated on with the last element, and then removes the last element. The remove statement happens in constant time O(1).
```
arr: [..] int;
for i: 0..10 {
  array_add(*arr, i);
}
for a: arr {
  if a == 2 {
    remove a;
  }
}
```

### Reverse `for` loop
To do a for loop in reverse, add a `<` in front of the `for` loop. The `for` loop will start at the beginning number and countdown to the ending number. In this example, the `for` loop will iterate from 5 down to 0 _inclusive_.
```
for < i: 0..5 { // This for loop prints out 5 4 3 2 1 0 in that order
  print("%\n", i); 
}
```

### `for` loop by pointer
To iterate an array by pointer, add a `*` in front of the `for` loop. Because you are taking a pointer to the array, you can modify the array elements. In this example, we take all the values in the array and square the elements. The resulting array should be `int.[1, 4, 9, 16, 25]`;
```
array := int.[1, 2, 3, 4, 5];
for * ele : array {
  val := ele.*;
  ele.* = val * val; // take all the values in an array and square the elements
}
```

### `for_expansion`
Jai allows you to use the `for` loop to iterate over custom data structures. `for` loops are designated through a macro as follows:
```
LinkedList :: struct {
  data: int;
  next: *LinkedList;
}

for_expansion :: (list: *LinkedList, body: Code, flags: For_Flags) #expand {
  iter := list;
  i := 0;
  while iter != null {
    `it := iter.data;
    `it_index := i;
    #insert body;
    iter = iter.next;
    i += 1;
  }
}
```
In the example above, we define a custom LinkedList, a very common computer science data structure. We define using the for loop over that data structure by using a `for_expansion`. `for_expansion` takes in three parameters: a pointer to the data structure one wants to use the for loop on, a `Code` datatype, and a `For_Flags` flags. The `#insert body;` inserts body of the for loop at that portion of the macro.

You need to backtick an `it` and `it_index` to get the `for_expansion` working. Else, this is an error.

The `For_Flags` enum_flags is found in `Preload.jai` with the following definition:
```
For_Flags :: enum_flags u32 {
  POINTER :: 0x1; // this for-loop is done by pointer.
  REVERSE :: 0x2; // this for-loop is a reverse for loop.
}
```
### Redefining break and continue inside for_expansion
In the `#insert` directive, `break`, `continue`, and `remove` can be redefined and the default behavior can be overwritten to do custom things.
```
#insert (break=do_something(), continue=do_something()) code;
```

### Named Custom For Expansion
There can be multiple ways to iterate a data structure that do not fit into the narrow descriptions of the basic `For_Flags` enums such as reverse iteration or by pointer. For example, someone might want to make a `Tree` struct with a breath-first search and a depth-first search iteration of a `Tree`. This can be accomplished by writing a breath first search macro and a depth first search macro with the following parameter arguments:
```
macro :: (o: *Object, body: Code, flag: For_Flags) #expand;
```
Writing a macro with that function signature allows the macro to be used to label a for loop expansion. In the following example below, we create a `bfs` and `dfs` for expansion macro that allows the for loop to traverse either in breath first search or depth first search respectively.

```
tree: Tree;
for :bfs node: tree {
  // breath first search the tree
  print("%\n", node);
}

for :dfs node: tree {
  // depth first search the tree
  print("%\n", node);
}


Tree :: struct {
  data: int;
  left: *Tree;
  right: *Tree;
}

bfs :: (t: *Tree, body: Code, flags: For_Flags) #expand {
  // define breath first search here..
}

dfs :: (t: *Tree, body: Code, flags: For_Flags) #expand {
  // define depth first search here..
}
```

## Functions
A function is a group of statements that together perform a task. Every program has at least one function, which is main(), and all but the most trivial programs can define additional functions.

This is an example of how to declare a function with the name `function`:
```
function :: (arg1: int, arg2: int, arg3: int) -> int {
  // write function code here.
}
```

Here is how you call the function:
```
function(1, 2, 3);
function(arg1=1, arg2=2, arg3=3);
```
Functions can take multiple arguments and return multiple values. Unlike languages such as Rust or Go, functions do not return tuple object values, but rather return the values in registers. The idea of creating some kind of tuple type and then optimizing away the tuple type so it becomes a normal function is just adding unnecessary loads of work to the compiler optimizer.
```
function :: (arg1: int, arg2: int, arg3: int) -> ret1: int, ret2: int {
  // write function code here.
}

ret1, ret2 := function(arg1=1, arg2=2, arg3=3);
```

You can ignore some or all of the return values of a function with multiple return values. You can only get the return values in the order that you return the values, meaning in order to get the second returned value, you need to get the first value.

```
function :: () -> int, int, int {

}

a := function(); // get only the first value in the function
a, b := function(); // get the first and second value in the function
a, b, c := function(); // get all the return values.
```

It is sometimes useful to ignore some of the return values from a function. The `_` can be used to ignore a particular return value. If you want to ignore `a` and `b` and use `c` only, you can do:
```
// ignore a, b.
_, _, c := function();
```

In the case where one wants to declare several variables, but one already exists, one can add a modifiers '=' or ':' to each comma-separated argument to indicate what should happen if one wants it to be different from the rest of the statement. If a statement is a declaration of multiple variables, you can add '=' if one variable already exists.

```
b := 5;
a, b=, c := 1, 2, 3;
```
In this case, `b=` is just assign to 2, the `b` ignores the `:=` operator, and `b` is not being redeclared.

This syntax can be useful especially when writing parsing code. For example:
```
token: string = "1 2 3 4";
num1, success := parse_int(*token);
num2, success= := parse_int(*token);
num3, success= := parse_int(*token);
```

In the following example above, we reuse the `success` boolean value for every `parse_int` function rather than having multiple success values (e.g. `success1`, `success2`, `success3`, etc.).

### Named and default return values
A named return value is merely a comment for a programmer. The name of the return value is not a variable, and is **NOT** a variable declaration. In the example below, the `-> a: int, b: int {` part of the function signature does not declare a variable. The named return values serve as comments for the programmer to remind the programmer of what the return values mean. As one can see, you need to declare `a: int = 100;` and `b: int = 200;` later on in the function body.
```
function :: () -> a: int, b: int {
  a: int = 100;
  b: int = 200;
  return a, b;
}
```

Jai functions can have default return values. A default return value, similar to a default function argument, is a value provided in a function that is automatically assigned by the compiler if the function doesn’t provide a value. 
```
function :: (var: bool) -> a: int = 100, b: int = 200 {
  if var then
    return; // 100, 200 are automatically returned by default
  else
    return 1_000_000; //
}

a, b := function(true);
print("(%, %)\n", a, b); // prints out '(100, 200)'

a, b := function(false);
print("(%, %)\n", a, b); // prints out '(1000000, 200)'

```

### Recursion

Just like any other imperative programming language, you can have recursive functions:
```
factorial :: (a: int) -> int {
  if a <= 1
    return a;
  return a * factorial(a - 1);
}
```

### `#this` directive

`#this` refers to the current function/struct in the current scope. This is the same factorial function that performs in the same exact way as the recursive definition, except using `#this` instead of calling `factorial` directly.
```
factorial :: (a: int) -> int {
  if a <= 1
    return a;
  return a * #this(a - 1);
}
```

### Overloading
Functions can be overloaded with several definitions for the same function name. The functions must differ from each other by the types and/or the number of arguments passed into it.
```
function :: (x: int) {
  print("function overload 1\n"); // first overloaded function
}
function :: (x: int, y: int) {
  print("function overload 2\n"); // second overloaded function
}

function(1);    // prints "function overload 1"
function(1, 2); // prints "function overload 2"
```
In this example, the first overloaded function is called, printing out "function overload 1", then the second overloaded function is called, printing out "function overload 2".

### Default Arguments
Just like C++, Jai functions can have default arguments. A default argument is a value provided in a function that is automatically assigned by the compiler if the caller of the function doesn’t provide a value.
```
// a = 0 by default
funct :: (a: int = 0) {

}

funct(); // a is passed 0
```
If a default parameter is used, parameters following `a` need to be explicitly passed to `a`.
```
funct :: (a: int = 0, b: int, c: int) {

}

funct(b=8, c=0);
```

### Varargs Function
A function can take a variadic number of arguments, or a variable number of arguments into a function. Consider the `print` function inside the Basic module. Notice that it can take in either 1 argument, 2 arguments, 4 arguments, or indeed any number of arguments:
```
#import "Basic";
x, y, z, w := 0, 1, 2, 3;
print("Hello!\n"); //
print("x=%\n", x);
print("x=%, y=%, z=%, w=%\n", x, y, z, w);
```
You can create your own variadic function using the following syntax:
```
#import "Basic";

var_args :: (args: ..int) {
  print("args=%\n", args);
}

var_args(1,2,3,4,5,6,7);

args := int.[1,2,3,4,5,6,7];
var_args(..args);    // same as doing var_args(1,2,3,4,5,6,7);
var_args(args=..args); // same as doing var_args(1,2,3,4,5,6,7);
```
In variadic functions, the variadic arguments are passed to the function as an array, and arrays can be passed to variadic functions by adding a `..` to the array identifier.

### Inner Functions
Functions can be defined inside the scope of other functions. The function defined inside another function cannot access the local variables of the outer function.
``` 
function :: () {
  x := 1;
  inner_function();
  inner_function();

  inner_function :: () {
    print("This is an inner function\n");
    // x = 42; // this does not work! cannot access variable of inner_function scope!
  }
}
```
If you want, however, to define "inner functions" that _do_ access the outer scope variables, than one way of doing this is to use `#expand`, see also the section below:
```
function :: () {
  inner_function :: () #expand {
    `x = 42;
  }

  x := 1;
  inner_function();
}
```

### Inlined Functions
Functions can be inlined through adding `inline` to the function declaration. `inline` replaces the function call with the actual body of the function. Unlike C or C++, `inline` in Jai is not just a suggestion to inline a function, but forces the compiler to attempt to inline a function.

From beta `0.1.032` onwards the compiler does inline functions by default.

A function can be inlined from the function definition as follows:
```
function :: inline (a: int, b: int)->int {
   //... function body
}
```
A function can also be inlined from the place the function is called:
```
answer := inline function(10, 20);
```

### Lambda Expressions
Lambda Expressions, i.e. simple small one-line functions, can be declared as follows:
```
funct :: (a, b) => a + b;
```
The following lambda expression takes in two parameters `a` and `b`, adds them together, and outputs `a+b`.

Let's create an anonymous lambda expression to map a bunch of values from `array_a` to `array_b`. In this example, we add 100 to all the values in `array_a`, and place those values in `array_b`.
```
map :: (array_a: [$N] $T, f: (T)->T)-> [N]T {
  array_b: [N] T;
  for i: 0..N-1 {
    array_b[i] = f(array_a[i]);
  }
  return array_b;
}

array_a := int.[1, 2, 3, 4, 5, 6, 7, 8];
array_b := map(array_a, (x)=>x+100); // array_b := int.[101, 102, 103, 104, 105, 106, 107, 108];
```

Unlike C++ or Rust, closures and capture blocks are not supported! The best way to get the desired functionality of closures would be to write a macro.

### `#bake_arguments`
`#bake_arguments` is a directive that takes an existing function and creates a new function with the existing function's arguments partially evaluated as constants at compile-time. This has similar functionality to currying in functional programming languages, except any random function argument parameter can be evaluated rather than depending on the order the parameters come in. The `#bake_arguments` directive, unlike currying values in functional programming languages, cannot be done at runtime, and is only limited to compile-time evaluation.

```
add :: (a,b) => a+b;
add10 :: #bake_arguments add(a=10); // create an add10 function that adds 10 to a given number

b := 20;
c := add10(b);  // prints out 30
```

Arguments can be baked into functions by adding a `$` in front of the identifier.
```
funct :: ($a: int) -> int {return a + 100;} // $a is baked into the function due to `$` in front of a
```

`$$` will attempt to bake arguments into the parameter list if the parameter value is constant. If not, it will be a regular function without the baking. You can use static `#if`'s to determine which version of the function is being called.
```
funct :: ($$a: int) -> int {
  #if is_constant(a) {
     print("a is constant\n");
     return a + 100;
  } else {
     print("a is not constant\n");
     return a + 100;
  }
}
```
`#bake_arguments` can also be used on a parameterized struct to partially evaluate the constants at compile-time.
```
A :: struct (M: int, N: int) {
  array: [M][N] int;
}

AA :: #bake_arguments A(M=10);
a: AA(N=2);
print("a=(%,%)\n", a.M, a.N); //prints out "a=(10,2)".
```
### Deferred calls

Jai allows you to defer some execution of a piece of code until the end of a scope. Put a `defer` keyword before a block of code to make it execute right at the end of the scope. Defer statements in loops are executed at the end of the code scope, not the end of the function. This is significantly different from other languages such as Go where `defer` executes at the end of a function.

```
print("1, ");
defer print("5, ");
print("2, ");
defer print("4, ");
print("3, ");
```
This will print out the text "1, 2, 3, 4, 5, ". Note that deferred statements execute in reverse. Things deferred first will be executed last.

## Macros
The Jai Programming Language implements hygienic macros. Hygienic macros do not cause any accidental captures of identifiers. Hygienic macros modify variables only when explicitly allowed. Unlike the C programming language in which a macro is completely arbitrary, hygienic macros are more controlled, better supported by the compiler, and come with much better typechecking.

Macros can be created by adding the `#expand` directive to the end of the function declaration before the curly brackets.
```
macro :: () #expand {
  // This is a macro
}
```
Macros are similar to inline functions in that the compiler inlines the code with the macro functionality. Anything with a backtick is something the macro refers to in the outer scope. In this language, macros work like hygienic macros in Lisp: local variables are available locally, and if the macro refers to something in the outer scope, mark the variable with a backtick `` ` ``.
```
a := 0;
macro(); //call the macro

macro :: () #expand {
  a := "No backtick"; // local variable, does not pollute the outer scope.
  `a += 10; // add 10 to the "a" variable found in the outer scope.
}
```

Macros can take in `Code` as an argument and `#insert` directives can be used inside the macros to insert the code into the body of the macro.
```
macro :: (c: Code) #expand {
  #insert c;
  #insert c;
  #insert c; // In this macro, we insert the code "c" into the macro three times
}
```
Just like regular functions, you can return values from macros.
```
max :: (a: int, b: int) -> int #expand {
  if a > b then return a;
  return b;
}

function :: () -> string { 
  c := max(2,3); // c = 3
  return "done";
}
```
Variables are not the only piece of code that can be backticked "\`". You can also backtick return values and defer statements. You cannot backtick `continue`, `break`, or `remove` statements. Backticking return values means the macro returns from the outer scope. In this example, the backticked return from the macro return a string value from the outer `function`.
```
function :: () -> string {

  macro :: () -> int #expand {
    `defer print("Defer inside macro\n");
    if `a < `b {
      `return "Backtick return macro"; // return a value from the "function"
    }
    return 1;
  }

  a := 0;
  b := 100;
  c := macro();
  return "none";
}

s := function();
print("%\n", s); // s = "Backtick return macro"
```

### Passing Inline Assembly Registers through Macro Arguments
Registers can be passed through macro arguments, giving you the power of macros while using inline assembly.
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

### Nested Macros
Macros can be nested. You call a macro within another macro. There is a macro limit, meaning there is a limit to how many macro calls you can generate. If you call a macro recursively (e.g. creating a fibonacci macro to call fibonacci recursively), this results in a compiler error that you hit a macro limit. The macro limit is by default 1000.
```
macro :: () #expand {
  print("This is a macro\n");
  nested_macro();

  nested_macro :: () #expand {
    print("This is a nested macro\n");
  }

}
```
The following recursive fibonacci macro calls results in a compiler error, saying you hit the macro limit.
```
fibonacci :: () #expand {
  fibonacci();
}

fibonacci();
```
Here's the error generated:
```
Error: Too many nested macro expansions. (The limit is 1000.)
```

If you want to make a recursive macro, compute the `if` at compile-time with a compile-time `#if`.
```
/*
// This version of the macro fails to compile since the 'if' is a runtime 'if'
factorial :: (n: int) -> int #expand {
  if n <= 1 return 1;
  else {
    return n * factorial(n-1);
  }
}
*/

// This code works and compiles.
factorial :: (n: int) -> int #expand {
  #if n <= 1 return 1;
  else {
    return n * factorial(n-1);
  }
}

x := factorial(5);
print("factorial of 5 = %\n", x);
```


## Structures

Frequently, you will need to represent something more complicated than a single number or text string, or a list of the same. Things in reality will tend to have multiple dimensions of different types, such as a person who has a name, an age, a location, and a favorite animal. Using structures, we might define such a person like this:
```
Person :: struct {
    name            : string;
    age             : int;
    location        : Vector2;
    favorite_animal : Animal;
}
```
Let's leave the definition of `Animal` for now as a bit of foreshadowing, and instead focus on what the structure represents. It is a complex data type that allows you to keep track of multiple properties. You can use this new struct as a type for variables, and use the `.` operator to reach into it for assignment and to read from it:
```
bob : Person;
bob.name = "Bob";
bob.age = 42;
bob.location.x = 64.14;
bob.location.y = -21.92;
print("% is aged % and is currently at %\n", bob.name, bob.age, bob.location);
```
You'll notice here that location, which is of type `Vector2`, is also a structure. `Vector2` is a vector that is part of the Jai `Math` module.

It's worth noting that unlike C/C++, when you have a pointer to a structure, you don't need special syntax to dereference properties. The same `.` notation just works:
```
move_person :: (person: *Person, newlocation: Vector2) {
    person.location = newlocation;
}
```
As you can see there, assignment of entire structures also works; it will copy the values.

### Initializing Structs
This section will go through several different ways to initialize a struct. All the different ways are different aesthetic ways to write the same code.

```
Vec3 :: struct {
  x: float;
  y: float;
  z: float;
}
```
The first way we initialize a struct is the most obvious way that we have already seen in previous sections:
```
vec3: Vec3;
vec3.x = 1.0;
vec3.y = 2.0;
vec3.z = 3.0;
```
`structs` can be initialized using `struct` initializers.
```
vec3 := Vec3.{1, 2, 3};
```
`struct` initializers can take in named parameters.
```
vec3 := Vec3.{x=1, y=2, z=3};
```
`struct` initializers work during runtime.
```
x := 1.0;
y := 2.0;
z := 3.0;
vec3 := Vec3.{x=x, y=y, z=z};
```

Please see the following links for concrete examples on structs and operations on structs: 
* [Encyclopedia of Jai Examples - Linked List and Binary Trees](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples/wiki/Linked-Lists-and-Binary-Trees)
* [Encyclopedia of Jai Examples - Graph Algorithms](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples/wiki/Graph-Algorithms)

## Unions
Unions are a data type that can only hold one of its non-static fields at a time. Unions have the same exactly functionality like in the C programming language.
```
T :: union { 
  a: s64 = 0; 
  b: float64 = 5.0; 
  c: Type; 
}

t: T;
t.a = 100;
print("t.a = %\n", t.a); // prints out 100
t.b = 3.0;
print("t.b = %\n", t.b); // prints out 3.0
print("t.a = %\n", t.a); // prints out gibberish, since b has been assigned
t.c = s64;
print("t.c = %\n", t.c); // prints out s64
print("t.a = %\n", t.a); // prints out gibberish, since b has been assigned
```

You can obtain the same `union` functionality using `#place` directives.
```
T :: struct {
  a: s64; 
  #place a;
  b: float64;
  #place a;
  c: Type; 
}

```
In `unions` or `#place` directive, when you initialize multiple values to some piece of memory, they get overwritten in that order.

### Anonymous Structs and Unions

`structs`, `unions`, and `enums` can be declared anonymously, without a type name attached to it.
```
struct {
  // This is an anonymous struct.
  x: int;
  y: int;
  z: int;
}
```

## SOA

Structs of Arrays is a way of rearranging the layout of the data fields of a struct. Specifically, Structs of Arrays (SoA) is a data layout separating elements of a struct into one parallel array per field. Take the following example:

```
// this is just a normal struct, no SOA
Vec3 :: struct {
  x: float;
  y: float;
  z: float;
}

// this is a SOA Vec3 struct
SOA_Vec3 :: struct {
  x: [100] float;
  y: [100] float;
  z: [100] float;
}
```

Using an `#insert` directive and generating code at compile time, we can generalize the concept of SOA to any structs using the following:
```
Vec3 :: struct {
  x: float;
  y: float;
  z: float;
}

Person :: struct {
  age: int;
  is_cool: bool;
}

SOA :: struct(T: Type, count: int) {
  #insert -> string {
    t_info := type_info(T);
    builder: String_Builder;  
    defer free_buffers(*builder);
    for fields: t_info.members {
      print_to_builder(*builder, "  %1: [%2] type_of(T.%1);\n", fields.name, count);
    }
    result := builder_to_string(*builder);
    return result;
  }
}

// create an soa_vec3
soa_vec: SOA(Vec3, 10);
for i: 0..soa_vec.count-1 {
  print("soa_vec.x[i]=%, soa_vec.y[i]=%, soa_vec.z[i]=%\n", soa_vec.x[i], soa_vec.y[i], soa_vec.z[i]);
}

// create an soa_person
soa_person: SOA(Person, 10);
for i: 0..soa_person.count-1 {
  print("soa_person.age[i]=%, soa_person.is_cool[i]=%\n", soa_person.age[i], soa_person.is_cool[i]);
}
```

## Enumerations
### Enum
An enumerator is a user defined datatype to assign names to integer constants. This is how to declare an enum:
```
my_enum :: enum {
  A; 
  B;
  C;
  D;
}
```
By default, `my_enum.A` is the value of 0, and the subsequent values for `B`, `C`, and `D` are 1, 2, 3 respectively. 
```
my_enum :: enum {
  A :: 100; 
  B;
  C;
  D;
}
```
By default, an enum variable is 64 bits wide. To change the default enumerator value, add a specifying integer type in front of the variable.
```
my_enum :: enum s16 { // This enum is a signed s16
  A;
  B;
  C;
  D;
}
```

### Enum Flags
An enum flag is an enumerator where each individual bit is an individual flag value of true or false. The next value in an enum flag is bit shifted to the left rather than incremented as in enums.
```
flags :: enum_flags u32 {
  A; // A = 0b00_01
  B; // B = 0b00_10
  C; // C = 0b01_00
  D; // D = 0b10_00
}
```
Enum flags can either be assigned to or use bit manipulation to set certain values to either true or false. The compiler recognizes when flags are set/unset, and will print out the flags accordingly.

```
using flags;
print("%\n", A|B); // will print out "A|B"
print("%\n", A|B|C); // will print out "A|B|C"

var := A|B|C|D;
print("%\n", var); // wil print out "A|B|C|D"
```

You can assign enum flags in the following ways:
```
f: flags = flags.A | .B;
f: flags = .A;
f: flags = 1; // numbers
f: flags = flags.A + 1;
```

### Using on structs, unions, and enums
Jai allows `using` keyword on `structs`, `unions`, and `enums`, importing the members into that particular scope.

We use struct inclusion on `a` to access `x`, `y`, and `z` directly without needing to do something such as `a.x`. Same example works with unions too.
```
Vec3 :: struct {
  x: float; y: float; z: float;
}

a: Vec3 = Vec3.{1,2,3};
using a;
print("a.x=%\n", x); // no need to do a.x, just access x directly
```
Putting a `using` on an enum imports the enum into the scope.
```
Enum :: enum {
  A; B; C; D;
}

using Enum;
e := A;
if e == {
case A; print("e=A\n");
case B; print("e=B\n");
case C; print("e=C\n");
case D; print("e=D\n");
}
```

`using` can contain modifiers to allow for more fine grained control over the `using`. This is useful especially when programs get larger and there are more naming conflicts. Here are some modifiers that can be applied to `using`:
* `,only`
* `,except` 
* `,map`

`,except` means the `using` will import all identifiers found, except the identifiers found in the name list. The identifiers in the named list will be excluded from the `using`.

```
Obj :: struct {
  x: float;
  y: float;
  z: float;
}

function :: (using, except(x) obj: Obj) {
  print("obj.x = %\n", obj.x); // x is excluded by the 'except', so need to access it by obj.x
  print("obj.y = %\n", y);     // y is included in the using
  print("obj.z = %\n", z);
}
```

`,only` means the `using` will only apply to the names listed in the name list, and ignore everything else. The identifiers not found in the named list will be excluded from the `using`.

```
Obj :: struct {
  x: float;
  y: float;
  z: float;
}

function :: (using, only(x) obj: Obj) {
  print("obj.x = %\n", x);         // x is included in the only, so it can be access by only typing 'x'
  print("obj.y = %\n", obj.y);
  print("obj.z = %\n", obj.z);     
}
```

`,map` takes in a function that modifies an array of strings, and maps all the function names to a different set of names of your choosing.
```
Obj :: struct {
  x: float;
  y: float;
  z: float;
}

add_a_char :: (array: [] string) {
  character := "0";
  for *identifier: array {
    // str = str + "0"
    identifier.* = join(identifier.*, character);
  }
}

function :: (using, map(add_a_char) obj: Obj) {
  print("obj.x0 = %\n", x0); // x 
  print("obj.y0 = %\n", y0); // y 
  print("obj.z0 = %\n", z0);
}

#import "Basic";
#import "String";
```

In the following example, we change all the identifiers in the struct from `x`, `y`, `z` to `x0`, `y0`, and `z0`.

### #as compiler directive
`#as` indicates that a struct can implicitly cast to one of its members. It is similar to using, except #as does not also import the names. #as works on non-struct-typed members. For example, you can make a struct with a int member, mark that #as, and pass that struct implicitly to any procedure taking a int argument.

```
num: Number;

// pass 'num' to the function as an int
function(num);

Number :: struct {
  #as a: int;
}

function :: (a: int) {
  // do something here...
}
```


## Types and Type Info

Types are a first class type in Jai. You can do the things with a type that you would with any other variable. You can get the type of some variable using `type_of`. The `Type` from `type_of` is a `Type`.

```
var: Type = int;
print("%\n", var); // prints "s64". since var=int and int is a synonym for s64.
var = Vec3;
print("%\n", var); // print "Vec3", since var=Vec3.
```

You can compare types for equality. The type matches another type in cases when `int == int`, `float == float`, etc. `int != u8`.
```
var: Type = int;
if var == int then {
  print("var = %\n", var); prints "var = s64"
}
```

`Type_Info` is a struct containing all sorts of type information, such as the name of the struct members, the offset of the member in bytes, the type of the members, notes attached to the members, etc.

```
Vec3 :: struct { x, y, z: float; }

info := type_info(Vec3);
for member : info.members {
  print("%\n", member.name); // prints out x, y, z
}
```

To check if a type is any version of a polymorphic struct with a particular name, you can do:
```
is_complex_number :: (T: *Type_Info) -> bool {
    if T.type != .STRUCT then return false;
    S := cast(*Type_Info_Struct)T;

    if S.name == "Complex" then return true;

    return false;
}
```
In this example, if the struct is of the name `Complex`, where `Complex` is any type of struct with the name `Complex`, the function will return `true`.

## Identifier Backslash
You can add a backslash followed by multiple spaces in between identifier names. The ability to add backslashes followed by multiple spaces is for purely aesthetic purposes.
```
helloworld := 0;
hello\   world += 1; // add 1 to "helloworld".
```





--- End of file: documents/02_getting_started.md ---

--- Start of file: documents/03_advanced.md ---
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





--- End of file: documents/03_advanced.md ---

--- Start of file: documents/04_metaprogramming.md ---
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


--- End of file: documents/04_metaprogramming.md ---

--- Start of file: documents/05_modules_and_libraries.md ---
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





--- End of file: documents/05_modules_and_libraries.md ---

--- Start of file: documents/06_snippets_and_benchmarks.md ---
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


--- End of file: documents/06_snippets_and_benchmarks.md ---

--- Start of file: documents/07_philosophy_of_jai.md ---
This section addresses some of the language design philosophy of Jai. This is an in-depth look at why certain language design decisions were made in the way they were. This is an attempt to best represent Jon's design philosophy for this language. The other sections address how to use the programming language, but this section will go in-depth about **why**.

## Design Philosophy
> "There are many features I can get rid of and it would still be the same programming language. If I got rid of full arbitrary compile time execution, it wouldn't be the same programming language. What I mean by "full" here is, many compilers have some limited set of expressions that they'll evaluate at compile time. There's const expr in C++ and languages like D or Rust will try to expand or formalize in order to give you more versatility to be able to do stuff at compile time. My approach is say "why are you doing that? Let's do everything at compile time. And by everything, I mean everything." - Jonathan Blow

This is a basic description of the design philosophy of Jai.
* Powerful Metaprogramming, a compiler can do literally everything through compile time execution
* Software Programming Language that compiles to fast machine code, like C/C++
* Structured, Procedural Programming, like C++
* Context-based Allocation Scheme for memory management
* Explicit Control, nothing should happen invisibly behind your back.
* The compiler alone should be everything you need to compile your program. No external tools. No Makefiles.
* The compiler gives the user the ability to inspect and modify the AST (Abstract Syntax Tree).

Jai is a "working person's" language that is built around what programmers do everyday. Jai seeks to tackle the most complicated system of all: metaprogramming, and attempts to make metaprogramming as simple and as easy as regular imperative programming while at the same time delivering code with high performance. Jai gives the programmer full arbitrary compile time execution and full ability to inspect the AST.

Jai is not a "big idea" language that tries to solve all the problems of programming. There will be no heavyweight compile-time verification systems that dramatically slow down compile speeds, no reference counted pointers, and no garbage collection overhead slowing down the application during runtime. Jai provides some mechanisms to make it easier to debug and trace bugs, but Jai does not claim to solve every possible bug that could possibly happen. This is **not** a language where "everything uses garbage collected functional programming everywhere". Instead of trying to provide 100% solutions for everything, Jai is built around 80% solutions.

The most unique and interesting feature of Jai is arbitrary compile time execution. While other languages have very heavyweight operations for metaprogramming, in Jai, metaprogramming is just a `#run` followed by a block of code to be executed at compile time. In Jai, metaprogramming is simple and easy. Jai makes it easy to execute arbitrary metaprograms, which would be necessary when a build system for a complicated project becomes as large as Visual Studio. During the arbitrary compile time execution, the Jai Compiler interprets the `#run` code as bytecode.

Jai is a programming language similar to C/C++ in that both languages provide as close as possible a mapping between a high level construct and the machine code generated. An add expression `c := a + b` will generate an assembly instruction `add c, a, b`, for example. Adding two number will should compile to machine code that adds two numbers.

Jai is a strong statically typed programming language. A variable must be annotated with the exact number of bytes it will use up and the variable's properties are known at compile time. When you type `a: float = 0.0;`, you know that it is a 32-bit floating point number and that it will not magically transform into a string at runtime. When someone accidentally typos an identifier, the compiler will report an error, just like in C. You know exactly how much memory your program is using up because you annotated your program with that information.

Just like C, Jai allows the programmer to do arbitrary casts and do pointers arithmetic in complex ways. A strongly typed programming language is necessary in creating robust, performant software, but sometimes, it is necessary to break the type system using some complicated casting in order to write the software the programmer wants. Unlike certain high level programming languages like Java or C# which abstract these details away and do not allow programmers to mess with pointers, Jai allows the programmer to do the special operations that people want to do.
 
## Thoughts of Jon

### Explicit vs Implicit Software Code

In C, the flexible type system filled with implicit casts makes it easier to expression more with less syntax. However, tons of implicit casts may hide bugs or mistakes inside code. On the opposite end, one can make everything explicit where in order to do anything, someone has to heavily annotate one's program in a verbose, explicit way. There might be less bugs, but then development of software can become painful and slow due to the many rules someone has to follow. Jai tries to strike some middle ground between a language design that could hide dangerous bugs behind some innocent looking code and requiring extremely verbose syntax that causes high friction. 

### Solving Hard Problems

Jai is designed for solving hard problems. Over time, codebases get massive, and can get over thousands or even millions of lines long. Jai will be designed to managing that complexity. Most language design seems to be focused on trivial conveniences like transforming a trivial 30 line program into a 15 line program, but not maintaining gigantic codebases. Meanwhile, different from other languages, Jai will be based on designing non-trivial programs and the problems that need to be solved when dealing with non-trivial code.

### Undefined Behavior

One of the biggest problems with the C programming language is the tons of undefined behaviors built into the language. Many seemingly reasonable things in C have undefined behavior, and this results in bugs and security vulnerabilities. Undefined behavior allowing a compiler to "do whatever a compiler wants" is absurd. If one wants to leave things open enough for different CPUs/OSs to be able to do whatever is natural to them, one can have "system-defined behavior" wherein each platform can say exactly what happens. "Undefined behavior" is an embarrassing, garbage idea, and "undefined behavior optimization" is absurd.

### Pointer Aliasing

Aliasing is a situation that happens with pointers that can cause ones code to not be optimizable, or that a piece of code can be optimized, but a compiler is unable to figure it out. Pointer aliasing is a complicated problem, and Jon is not sure what to do in this case. Jon is not sure what the correct solution is.

### Joy of Programming

The design of most programming languages, such as C++, Java, Rust, etc. has been to automatically manage memory for the programmer. C++ uses RAII to automatically clean up after you finished. Java uses garbage collection. Rust has static compile-time verification checking and RAII. The design philosophy of these languages produce code with confusing, complicated hierarchies that feel very bureaucratic.

For example, when writing C++ code, you need to write out tons of constructors and destructors, and make implementations and headers for these. Every time you add an object, adding the constructor, the destructor, the copy constructor, dealing with move semantics feels like filling out tax forms rather than programming. The "rule of five" and "rule of three" in C++, which argues you need "x, y, z" functions for every single object in order to have a functioning program is depressing grunt work just to do programming.

Jai is designed for you, the software developer. You should feel the joy of programming new and interesting functionality. Programming should not be a matter of filling out income tax forms all day. Jai does not have any concept of constructors, destructors, move semantics, etc. If you need to do something interesting, write the code as directly and as simply as you know you can. If you need to organize the code better, write a function to encapsulate the functionality. If data is best to organize together, create a struct for that. If some much more complicated systems are neccessary, function/struct polymorphism exists as well as full, arbitrary compile-time execution.

### Resource Acquisition is Initialization (RAII)

The main programming paradigm of C++, Rust, Java, and most object-oriented languages is the concept of RAII i.e., resource acquisition is initialization. In RAII, the object is allocated and initialized in the constructor, and the destructor releases the object memory and handles whatever cleanup needs to happen for that object. This paradigm does little to solve the everyday problems of software developers.

Suppose we have a C++ `Object` with a constructor that does a nontrivial initialization:
```
class Object {
  Object() {
    // non-trivial initialization...
    //
  }
}


Object object;
```

As we can see above, the `Object` constructor is invisibly called behind your back without you knowing it is happening. It seems clean and nice for simple examples such as this, but when writing non-trivial code, you want to be *explicit* when dealing with complex code. Non-trivial code should not be accidentally firing behind your back without you knowing. All algorithms should follow an explicit sequence of events in an order. Jumping around code in a complicated way confuses a lot of people.

The RAII acronym makes no sense. There is no such thing as a "resource". A "resource" is a generic object that means lot of different complex concepts such as memory allocation, file handling, texture maps, threads, etc. However, all these "resources" need to be handled very differently from each other. Forgetting to close a file handle or texture map may be a simple bug, but figuring out how to manage memory is the main issue that programmers care the most about. Programs store memory, use memory, and have to figure out how to cache memory correctly so their programs can run fast.

A programming language should be focused on building tools to help manage memory and cache related issues. File handles and texture maps should not have the same solution as memory management. Having an 80% solution that is best for dealing with memory related issues is better than a general purpose RAII mechanism to solve everything but do it poorly.

In some cases, RAII is a convenient abstraction that does exactly what you want, but RAII is usually not the common case. In those cases where RAII is convenient, you may write a macro such as:
```
create_object :: () -> Object #expand {
    object: Object;
    init(*object);
    `defer {
        destroy(*object);
    }
    return object;
}
```

### Object Oriented Programming

Object Oriented Programming is characterized by object inheritance hierarchies with virtual functions overloading everything. Object oriented programs have public member functions encapsulating private data, and objects interact with each other through public member functions. Objects are organized together through "design patterns".

Jai does not support object oriented programming. Focusing on the importance of "objects" and treating functionality as "cross cutting concerns" ignores that the most interesting code is the cross cutting concerns. Take for example, in a space invaders game, a "bullet object" hits an "alien object", causing the "alien object" to explode and die. The objects are not central in programming, but rather the way the objects interact with each other and are organized together is what is interesting.

Focusing on an individual object by itself makes a programmer miss the big picture, which is that this one individual object is one out of many, many objects. Thinking of an individual object makes one forget about operating on objects as a group, or operating on the objects in bulk.

### Member Functions

Jai rejects the concept of a member function completely. Both member functions and regular functions operate in the same exact way in machine code, but member functions are given some sort of special status. Consider the following C++ code:

```
struct Object {
  int data;
  void set_data(int data) {
    this->data = data;
  }
}

void set_data(Object *this, int data) {
  this->data = data;
}
```

Both the member function as well as the normal function do the same exact thing! But, C++ compilers need to have a built-in idea of a member function. Functions do not "belong" to any particular object, rather a function operates on one or multiple objects/variables. Forcing a function to belong to a particular object is a nonsensical way to model complex interactions between different pieces of data.

[A note about programming language design](http://the-witness.net/news/2012/09/a-note-about-programming-language-design/)

### Virtual Functions

This feature does not solve any issues, and just adds unnecessary complexity to the compiler. All of the functionality of virtual functions can be easily replicated by either if/else-if statements or callbacks (function pointers). As stated in the member functions section, functions do not "belong" to any particular object. Functions operate on one or multiple objects/variables.

All things that can be solved by virtual functions can be solved by using an if statement. If there is a need for even greater abstraction, you can use function pointers and callbacks. The idea of a callback can be decoupled from the ideology of object oriented programming.

### Garbage Collection

Garbage collection causes a lot of friction in games, and garbage collection will not work for serious game projects. Most games allocate all of the memory upfront, and for most of the runtime of the game, do not allocate/deallocate memory. You do not need fancy memory management algorithms to write a 3D video game. With that being said, a garbage collector  takes up tons of overhead and does not provide any benefit for managing memory.

There are some specific algorithms that might be easier, better, or cleaner when using a garbage collector, but those do not apply to the vast majority of games. Jai seeks to provide a good basis for doing the basic items, and people should be able to build the most sophisticated software possible from that baseline without destroying the language design.

### Rust Borrow Checker
Please see [Rust](https://github.com/Jai-Community/Jai-Community-Library/wiki/Overview#rust) in the `Comparison with Other Languages` section.

### Makefiles, CMake, Ninja, etc.

When working on a big project, a big project will end up with a large Makefile. Often, this Makefile could end up with the size and complexity of something such as Visual Studio. It becomes incredibly difficult to program a Makefile. Unfortunately, in modern software, people dedicate entire teams just to manage Makefile and build problems. In Jai, there will be no more teams of engineers dedicated to managing Makefile problems, since metaprogramming is no different than regular programming.

In Jai, Jon seeks to eliminate the Makefile build system problems altogether. Instead of handling the build using confusing tools, program your own build system using the Jai programming language itself. Building and compiling a program should be as simple as normal programming. There should be no distinction between writing code for the build system and writing code for the actual program you are trying to write.

In Jai, your build system will be mostly done in Jai. One big problem in C++ is that C++ does not know anything about how to build a program, and the build uses all sorts of frameworks that no one knows how to use. Builds can end up becoming programs as large as Visual Studio, and figuring out what went wrong with the build can be very complicated. In Jai, you can build your program with the compiler alone, and you can write the entire build in the Jai Programming Language itself. Using some hacky scripting language in-between is optional. Your build is not spread across 20 different tools that you do not understand at all.

### Incremental Rebuilds

Incremental rebuilds cause a lot of compilation problems, bugs, and errors. Incremental rebuilds are also slow due to the amount of in between files generated between builds. Jai will contain no incremental rebuild steps. All will be compiled in one fresh compilation. This means that the compiler will need to run fast with high performance. The eventual goal is to compile a 1 million lines of code in 1 second, but as of right now, the compiler can only do 250,000 lines in 1 second.


### Open-Source Software

Open-source software has been stagnant for years. They are not creative. They just copy existing proprietary software and try to make an open-source version of it.

Windows is much better at backwards compatibility in comparison to Linux. Everytime Linux gets an update, everything breaks. Linux is terrible when it comes to backwards compatibility.

Linux is terrible when it comes to sound (e.g., the mess that is pulse audio). Linux users have spent the last couple of decades announcing that this year will be the year of the Linux Desktop, but it has never come true. Jon has spent a long time trying to switch to Linux because "free software" is more ethical than the exploitative proprietary software made by corporations. However, every time Jon tries to switch over, he has always run into all sorts of problems.

Jon wants to open source the compiler and give the source code out for free, but does not want to do open source community management. Taking pull requests from random people on the Internet is not a good way of advancing software.

### Pattern Matching

Jon considers pattern matching to be a feature that looks aesthetically pleasing for toy programs, but as programs get larger, pattern matching makes the program messier. Pattern matching does not scale well to large projects. Anything you are going to have to decompose later on as soon as you start doing more real stuff, just skip it, don't bother.

### Operating System Design

The Operating System of a computer should be small. Instead of putting everything in a gigantic 38 million lines of code monolithic kernel, all of the code should be in userspace. If, for example, someone wants to talk to the network card, there should be no kernel interactions. Instead, if a piece of code talks to the network card, it should be possible to write all of that code in userspace. Programs should be heavily sandboxed from each other, and it should be impossible for a program to just look at the file system.

There should be no drivers. Each program should implement their way of using the hardware system resources and talk to the hardware as directly as possible. There should not be an operating system kernel function to abstraction the resource for you. The programmer should be allowed to write their own functions to use the hardware resources in their own way rather than being forced to use a general-purpose kernel function that is slow because it is trying to cover all the cases.

An [Exokernel](https://pdos.csail.mit.edu/6.828/2008/readings/engler95exokernel.pdf) encapsulates a lot of Jon's ideas. As Jon say himself, "We should basically write an exokernel. Take the exokernel idea, and basically do a modern version of that."

### Functional Programming

Functional programming (e.g. Haskell, Lisp, Scheme, etc.) is too esoteric and too complex to use as a programming language. It's ideas have been in circulation for a long time, but functional programming has never taken off as the right way to create software. 

Some interesting features from functional programming, such as metaprogramming, formal software verification, function/struct polymorphism, and type inference are useful and provide convenience to the programmer. Jai has some functional programming concepts such as hygienic macros and type inference. But functional programming as a whole is too abstract and serious big projects are not done in functional programming. Function programming is most likely to stay as strictly an academic novelty.

Functional programming also is garbage collected, which makes it terrible for high performance software such as video games.

### Unit Testing

Unit testing is a terrible way to develop software. Often, bugs are not caught through unit testing, but rather bugs are found in complex interactions between various complex systems working together. Individual functions that do simple isolated things are trivial to test, but a complex software product with multiple moving parts is incredibly difficult to unit test. There are much more productive ways of testing (e.g. soak testing) that catch a wider array of bugs than unit testing.

### Explicit Uninitialization

In C, values are always uninitialized by default, and causes undefined behavior. This can cause a lot of bugs because it can be difficult to spot that `int a;` has not been initialized before reading from it. Because the behavior is undefined, your program sometimes runs correctly, and other times does not run at all, causing massive headaches in development. The non deterministic behavior of the program makes the bug incredibly difficult to catch.

In other high level languages, like for example, Java, `int a;` means that `a` will always be zero by default. However, this means implicitly, `a` will be set to zero, which might cost a cycle to initialize. What if something wants to remain uninitialized for some time before you then initialize it?

Jai tries to strike a balance between the two approaches. Implicit uninitialization can lead to undefined behavior, which in turn leads to non deterministic bugs that can be difficult to catch. However, setting `a` to zero all the time costs cycles to initialize. By default, `a: int;` will initialize `a = 0`. However, if you find that explicitly leaving the variable uninitialized is the best way to achieve performance, you can use the `a: int = ---;` to explicitly leave the variable uninitialized. This way, you explicitly know something is uninitialized by the `---` syntax, and know where to check if you find some sort of non deterministic bug.

### Struct of Arrays (SOA)

Struct of Arrays may be able to solve many headaches when it comes to optimizing code but it is too specific and too narrow of a use case that is not broadly applicable to complex systems. The only way to test whether an SOA compiler feature works is to have a massive project in which that feature gets used. Unfortunately, Jai is not at that point where massive feats of software engineering are written in it. With that being said, you can create SOA using existing `#insert` directives and metaprogramming features.

### Inline Assembly vs SIMD Intrinsics

SIMD compiler intrinsics do not give as much control over the code as inline assembly. In inline assembly, you can explicitly tell the compiler exactly what assembly code to actually generate, while SIMD compiler intrinsics may take a simple 4 line intrinsics and expand it out to 50 instructions in a debug build. If a programmer wants "SIMD datatypes" such as `s64x8` (8 integers, 64 bits each), you can create your own datatype `s64x8 :: struct { data: [8] u64; }`. 

Jon does not believe there is any benefit to making intrinsics and hoping that the compiler might optimize the code. If you want your code to run faster, the programmer should be given explicit control over how that works. The only way to get good performance is to measure and test your own methods against reality.

### What should be part of a Computer Science Curriculum

Here is a list of useful and important deep computer science knowledge.

* Time complexity of algorithms
* The different programming paradigms (Functional, Declarative, Imperative Languages)
* Recursion
* Boolean Logic
* Operating System Kernels, Filesystems
* Data Structures (Binary Trees, Arrays, Hash Tables. etc.)
* Sorting Algorithms
* Floating Point Number Representation
* Concurrency, what data races are and how to solve them
* Databases
* Discrete Math
* Linear Algebra

There should be much more serious programming practice embedded into the computer science curriculum. Industry requires building of giant complex software, and Computer Science courses do little to encourage students to practice.

Things that are **NOT** useful because this is not deep knowledge
* Grammars
* Databases Relational Algebra
* Particular knowledge of a trending library or framework

## Quotations and Interesting Excerpts

This is a gathering of different quotations and excerpts from Jonathan Blow, as well as other peoples and materials which attempts to capture the essence of the kind of code philosophy Jai supports.

> "Design patterns are spoonfeed material for brainless programmers incapable of independent thought, who will be resolved to producing code as mediocre as the design patterns they use to create it." - Christer Ericson

Design patterns do not help solve hard problems that software engineers deal with. Rather, they add complexity because code needs to confirm to meet "design patterns" ideology rather than writing the code that solves algorithmic problems. If and switch statements are much easier for people to understand over layers of object graphs filled with objects all inheriting from each other in complicated, incoherent ways.

> "The reality is that this (referring to the single responsibility principle) is NOT true. We have lots of things in reality, practically speaking, from an engineering point of view, that have more than one responsibility. Because they must. Because it is more efficient. Because it makes more sense. Because the combination of things is the most likely scenario. Multiply add (madd) is a straightforward example that everyone can understand. Statistically, you are going to multiply and add together. Doing multiply and add separately has no intrinsic value to do them separately." - Mike Acton

Most programming advice tells you to separate out the responsibilities and hide the implementation details of one thing from another thing. In this quote, Mike is saying the **EXACT OPPOSITE**. We want to mix together units and combine them, rather than keep them separate. Combine them together makes the most sense, because the units work together well. As stated above, multiplying and adding are two completely separate operations. However, we can combine the two operations into one operation.

Separating code out into different responsibilities is not always the correct way to go. Sometimes, combining two or more different separate parts of a piece of software to make a more unified whole makes the software better for maintenance, reliability, performance, etc.

> "Don't reinvent the wheel is total nonsense. What we often do is reinvent the wheel in order to learn how the wheel works and make our own adjustments to it. And the reality of the world is that it is not one size fits all...your technology was built under certain conditions for certain contexts, for certain group of people, for a certain type of game. Whatever that is does not necessarily fit your situation, and so you may have to create something that works better for you." - Mike Acton

Reinventing the wheel is important for being able to understand what is going on better. To do a better job at writing the functionality, one needs to dive deeper about the fundamentals about **why** something works and **what** makes it useful. Reinventing the wheel is important to adapting the solution to match the problem at hand.

[How NASA Reinvented The Wheel](https://www.youtube.com/watch?v=vSNtifE0Z2Q&ab_channel=Veritasium)

> "Mature programers know that the idea that everything is an object is a myth. Sometimes you really do want simple data structures with procedures operating on them." - Bob Martin, author of "Clean Code"

There is no such thing as an object. Bob Martin, the author of "Clean Code", says that the idea that "everything is an object" is a myth. Objects/object oriented programming techniques are just an organizational tool for helping a programmer keep the code organized, not the guiding principle that should dictate how the entire program should be structured.

> "...so I took the main tick function and started inlining all the subroutines. While I can't say that I found a hidden bug that could have caused a crash, I did find several variables that were set multiple times, a couple control flow things that looked a bit dodgy, and the final code got smaller and cleaner...besides awareness of the actual code being executed, inlining functions also has the benefit of not making it possible to call the function from other places. That sounds ridiculous, but there is a point to it. As a codebase grows over years of use, there will be lots of opportunities to take a shortcut and just call a function that does only the work you think needs to be done. There might be a FullUpdate() function that calls PartialUpdateA(), and PartialUpdateB(), but in some particular case you may realize that you only need to do PartialUpdateB(), and you are being efficient by avoiding the other work. Lots and lots of bugs stem from this. **Most bugs are a result of the execution state not being exactly what you think it is.**" - John Carmack, in an email to Id Software programmers

When being taught to program, one is told to write small functions, and every function should be under 20 lines. In programming school, one is told to split up the big function into smaller functions. However, what ends up happening when you split up functions into small chunks is loss of awareness about what is going on in the code since everything is split up into millions of small functions, you are unsure about what that particular small function snippet even does, and it becomes difficult to make optimizations since everything is split up into millions of small functions.

Writing large functions has the benefit of all the implementation details being encapsulated within the large function. The implementation details are not spread out across all the different systems in different states that one is unaware of. Rather, all of the code is written in a straight, understandable linear block that reads from top to bottom, left to right. 

> "The problem is that Rust does not have respect for the kinds of things you need to do in a game engine and so it makes them a lot harder than they should be and/or those things are directly counter to the vision of Rust...both the Braid and the Witness, if they were 10% harder to make, the projects would have failed. They were on the edge of what we could do." - Jonathan Blow

Rust runs contrary to everything game engine developers want for a programming language for games. Fighting with the borrow checker would slow the production of the engine, and Jon imagines if he programmed his games in Rust, those projects would have failed.

> "Metaprogramming, as you stereotypically think of it, is hard to think about...And the point here is that we are bringing the meta as close as to what you regularly do as possible. So it's just normal stuff that you are used to thinking about, that you are used to being effective in." - Jonathan Blow

Metaprogramming is normally seen as a scary thing that is difficult to use. The thesis of the Jai Programming Language is that "metaprogramming" is actually simple. Metaprogramming is just normal programming, just that it happens to execute at compile time. 

> "Your program should be a mathematical object that is self defining. It should have an unambiguous meaning." - Jonathan Blow

A program should be self defining. A programming language should specify how it builds itself. It is not defined using Makefiles, CMake, etc. There is no third party build system tool used to compile the program.

> "There are no zero cost abstractions. And imaging there are is causing serious problems." - Chandler Carruth, "There Are No Zero-Cost Abstractions"

C++ encourages people to use abstraction layers to write good code. Unfortunately, these abstractions do not always work for reasons such as the compiler not optimizing the function correctly, the code is highly performant but takes forever to compile, the abstraction is too overly complicated to understand, etc. Measure carefully what you are doing, and measure the output produced by the abstraction. Abstraction is great, but there needs to be a cost-benefit analysis about what you are doing.

> "Constantly saying don't do that feature existing systems don't handle it well is an extremely anti-progress attitude, and if I were to follow that on all fronts, it would kill the language because most new things could not happen." - Jonathan Blow

Being backwards compatible is important, but the purpose of this compiler is to design a new language with a different philosophy than C++ or any existing language currently.

> "I invented the term object oriented, and I can tell you that C++ wasn't what I had in mind." - Alan Kay

Much of what is considered "object oriented" (C++, Java, etc.) is a terrible implementation of Alan Kay's original ideas. Object oriented ideas may contain some interesting engineering modeling techniques, but the current design patterns and inheritance hierarchies found in many C++, Java, and other languages fall far short of the original design.

> "The question is always, if something can be implemented at user-level, how much better is it to put it into the compiler, and what is the added complexity, and is that benefit/cost ratio worth it?" - Jonathan Blow

People do not consider the complexity costs of implementing something in a compiler, so compilers become increasingly complex nightmares because of it. Removing the bad ideas that cause tons of problems is good for making a clean language/compiler design.

> "I actually err much more on the side of complexity in the core semantics than most language designers do, because in cases where this buys real ergonomic benefit for the programmer, I value that benefit at a very high rate." - Jonathan Blow

The compiler will be more complex and the language design will be more complex to make the life of the programmer easier. Complexity in the compiler to achieve simplicity and ease of use for the user is the goal.

## Questions and Answers

### Can Jai have "X, Y, Z" language syntax?

Jon is interested in building out the functionality of the programming language, and minor syntax differences are a wasting time when he can be building out more language functionality. Yes, there will be a syntax pass where the language gets a syntax upgrade, but syntax is not a goal of Jon until much later.

### Why are there two backends for Jai? Why not just have the LLVM backend?

To paraphrase Jonathan Blow, the LLVM API is extremely difficult to use. It is programmed in some convoluted object-oriented way that makes it incredibly difficult to use the API. For all of the work LLVM does, it has a substantial overhead to it. LLVM takes forever to compile (30 minutes to an hour) and is a high friction tool. Jonathan Blow hopes to one day to be independent on LLVM, but for the time being, LLVM is useful for supporting cross-platform compiling. Compiler optimization is one of the hardest parts about developing software, and it will take a while before being able to make a backend to compete against LLVM. Since LLVM is so complicated, Jon hires other people to work on LLVM just so he does not have to deal with it.

Jon's problems with LLVM is as follows: LLVM is incredibly slow, it has terrible documentation, and is too much of a continuation of the bad practices that make software code hard to use.

One can look at the [LLVM Documentation](https://llvm.org/doxygen/) to see just how confusing LLVM is.

### Will there be plans for optimizing the x64 backend?

In the long term, Jon plans to make the x64 backend a fully optimizing backend. LLVM is powerful and gives Jai the ability to support multiple platforms, but LLVM is incredibly bloated and slow. Making a fully optimizing x64 backend will not delay the public release of the Jai compiler.

### Can Jai be used for web development?

Jon is not interested in web development at all. Web development has contributed to the decline of programming, and the poor design decisions around that time made software terrible. Web development revolves around Javascript, which is terrible and not robust enough for building serious software. Jon is not personally interested in web development, and he does not plan on doing anything for web, since that is not his particular domain of expertise.

### Why doesn't Jai have bitfields?

Bitfields are not useful for Jon and game development. Bitfields are terrible for multi-threading.

### Why were infix function call operators removed?

Infix function calls were never used except in very few places (e.g. `c := a 'dot' b` is easily translated to `c := dot(a,b)`), and added a lot of complexity to the compiler. 

### Are there any plans on marking variables as volatile, like in C?

No, the `volatile` keyword does not mean anything consistent in C. It is sketchy to solve a problem by marking a variable as volatile. These problems are probably best solved through compiler directive feature(s). Programmers think it does something, but it doesn't do what they think. Jon is taking an open attitude toward discovering what are the simplest constraints required to practically do threading stuff.

### How do I do `x >= 'a'`, like in C?

You can translate `x >= 'a'` into `x >= #char "a"`. Jon wants to save the single quotes for some special operation that would be interesting or useful later on. However, as of right now, the language does not use single quotes to do anything special.

### Why can't I pass multiple return values to multiple arguments in functions?

It sounds aesthetically pleasing to be able to pass multiple return values to multiple arguments, but this is actually a terrible idea. If the number of function parameters changes or number of return values change, then it becomes difficult to find the error in the code. Debugging a bug within such code becomes difficult because it is difficult to set a breakpoint, so one ends up reverting back to explicitly passing the return values to the parameters of the function.

There is also the concern that as soon as one declares that multiple return values are actually tuple types, one has the compiler packing and unpacking all these values, and one is relying on some optimization to make it fast, but the optimization might not work. This jeopardizes stuff such as return value optimizations.

### How can Jai make parallel code easier?

Jon is unsure about what mechanisms to create to make parallel code easier. Jai supports basic threading primitives (e.g. threads, mutexes, semaphores, etc.), but none of the other programming languages have any good ideas about handling multiple threads. All the other programming languages have terrible ideas about how to write code.

### Will Jai support Go-style Channels?

Go-style channels do not tackle the real difficult problems of concurrency and parallelizing code. They only solve trivial software problems but do nothing for real difficult problems of multi-threading.

### Will Jai support closures?

Jon is considering closure support, but closures are not an important feature that massively increase productivity in programming. Complicated functions can be best handled by a function with a descriptive function name that describes exactly what the function does, and there is not much place for a small anonymous lambda expression with closures.

### Will Jai support function chaining?

No. Here are several reasons why:
* Function chaining is bad for debugging, both debugger debugging and print debugging. There is no place in the middle to stop and put a breakpoint or write out some information. 
* It is bad for efficiency. You end up writing a lot of code that operates on one thing just so people can chain the function.
* It is bad for program semantics because you find people returning things when they really want the function to mutate things or do side effects.
* It reinforces the ideology of "objects owning functions", which leads to slow computer programs which are hard to understand
* To continue supporting this style, people create strange stuff such as having state on the object that the functions look at since they do not want to pass extra parameters since those do not chain
* It does not solve any actual programs. It is just syntactic sugar that is aesthetic pleasing in niche situations. Outside of those cases, it breaks down

### Can Simp include functions to draw lines?

No, to draw lines, just draw a rectangle. You want to be able to control line thickness, and as soon as you want to control line thickness, you are talking about a rectangle.

### What happened to Relative Pointers?

Originally, relative pointers were in the language. However, relative pointers have been removed from the language. Relative pointers added a lot of complexity to the compiler, and there were too many drawbacks to having them built into the language. After a discussion about whether relative pointers were useful for Jai Beta members, they have been removed. Jai Beta members were not using relative pointers for serious important work.

### What will Jai do regarding concurrency?

Jon does not have much multi-thread experience, and he does not know how to deal with that situation. Concurrency is a complicated problem, and many high level languages deal with solving low hanging fruit rather than dealing with real, tough concurrency problems.

### Will 32-bit programs be supported in Jai?
No. 32-bit programs will add significant complexity to the compiler, and supporting only 64-bit programs keeps the language massively simple.

### Are there plans for self hosting the compiler?

Self hosting a compiler is not a good proof of concept of a programming language. Being able to ship an extremely complex 3D game in a programming language (like the Sokoban game Jon is making) is far better at testing the language than a simplistic compiler. There are no plans to rewrite the compiler into Jai until much, much later.

### Why can I not run a build at runtime?

Running a build at runtime goes against the philosophy of this programming language. Runtime compilation requires distribution of the compiler, which is a bad thing for a software product one wants to build. To do that, one would have to create, distribute, and maintain the compiler as a library, including figuring out how to integrate and give your native program access to the metaprogram information, which is difficult.

### Are there plans for making builds less dependent on metaprograms?

No. For small programs, using some generic settings to build a program would be okay. However, when you reach large projects with many complicated settings that need to be built in a complicated way, you want to be able to handle those builds using a powerful metaprogram. Nowadays, building a program is a nightmare: it only works on your machine, but when you distribute your program elsewhere, it fails. Build systems are a massive point of friction in most programming languages, and much of this is wasteful. Your own program defines how it is built across different platforms. The only thing you need in order to compile your program should be the compiler itself. There should not be a Make system on Linux, Visual Studio build settings on Windows, something else on Mac, etc. **Your program should be a mathematical object that is self defining. It should have an unambiguous meaning.**

Here are some example issues that occur with commandline options:
* You need to write some script to compile your program, because you end up using a huge number of compiler commandline options
* The compiler options break your program, or slow down your program drastically
* You do not know if the compiler options exist in your environment
* Have the compiler arguments been changed across different versions of the compiler?

If you need to do some tweaky stuff for a particular OS, but that option is not available for other OS's, you can give a nice clean error message.

Jon wants to decrease the reliance on command line options. Increasing command line options goes against the design philosophy of this language.

## Future Goals

A list of future goals of the compiler
* making cross compiling work better
* making the language features work well with DLLs and libraries
* making macros better
* robustness of the compiler and making the features as good as they can be
* making inline assembly better. there are overhead instructions in `#asm` blocks, and those overhead instructions negate the purpose of doing inline assembly.
* making it more of an optimizing compiler
* more program visualization
* externalizing the assembler so that the assembler can support multiple platforms, not just x64.

## Temperance

One of the biggest problems is software right now is that there is far too much code in existence, and the code does too little compared to what it should actually do. A lot of this leads to low productivity, unreliable code, massive security vulnerabilities, and unmaintainable code. Just in order to run programs on a computer, we decided that a bloated tens of millions of lines of code is required.

If your program is in the neighborhood of 50,000 lines of code, it should provide a large amount of interesting and novel functionality. If it doesn't, it is time to ask questions.

Write code that does a lot for its small size, and ask questions about whether the program is robust in handling its input.

* Insufficient documentation leads to code being done inefficiently
* Transfer of the understanding of the code base is important. If the understanding about the code is lost, code quality will decline.
* Understanding of the code base is hard to recover just by looking at the code.

Keep the use of compile-time execution to conservative levels. It is a powerful tool for expressing high level software ideas, but compile time execution is slower than actual machine code execution.

Use programming language features only when you need them. Do not use programming language features just for the sake of using them. Use the right tool for the right job, and use as simple a tool as you can to do the thing you need to do. When you use the wrong tool for the job, you will find that your code becomes much slower, less performant, less reliable, less able to debug, and unmaintainable.






--- End of file: documents/07_philosophy_of_jai.md ---

--- Start of file: documents/08_references.md ---
# Community Libraries
Libraries, Modules, and Programs written by the Jai Beta Community.

### **GUI/UI**
   * [ImGUI](https://github.com/overlord-systems/jai-imgui/tree/prod) - IMGUI bindings for Jai.
   * [XCB](https://github.com/Breush/lava-jai-bindings/tree/master/Xcb) - XCB bindings for linux windowing.

### **Graphics**
   * [bgfx](https://github.com/DrProfesor/jai-bgfx) - Bindings for bgfx.
   * [JaiGLFW](https://github.com/kujukuju/JaiGLFW) - Original GLFW port before removal with a few added bindings.
   * [Sokol](https://github.com/judah-caruso/jai-sokol) - Bindings for Sokol.
   * [Vulkan](https://github.com/osor-io/Vulkan) - Vulkan tooling for Jai.
   * [OpenXR](https://github.com/Breush/lava-jai-bindings/tree/master/OpenXr) - OpenXR API for VR and AR.
   * [ShaderC](https://github.com/Breush/lava-jai-bindings/tree/master/Shaderc) - To compile GLSL shaders into SPIR-V at runtime.
   * [Jai-Shader-Transpiler](https://github.com/PixelRifts/Jai-Shader-Transpiler) - Jai metaprogram for converting Jai functions to GLSL shaders.
   * [Raylib-Jai](https://github.com/ahmedqarmout2/raylib-jai) - Bindings for Raylib version 5.5
   * [KodaJai](https://github.com/kujukuju/KodaJai) - Graphics library.
   * [ofbx](https://github.com/DrProfesor/ofbx) - a port of [OpenFBX](https://github.com/nem0/OpenFBX).
   * [jai_wgpu_native](https://github.com/SogoCZE/jai_wgpu_native) - Jai Bindings for [wgpu_native](https://github.com/gfx-rs/wgpu-native).
   * [Easing Collection in Jai](https://gist.github.com/xThuby/7bbbf0782ac52a08f05abab466ce469b) - A collection of very handy easing functions.

### **Audio**
   * [clap-jai](https://github.com/jatinchowdhury18/clap-jai) - CLAP [Audio plugin API](https://cleveraudio.org/) bindings for Jai
   * [clap-jai-plugin-base](https://github.com/jatinchowdhury18/clap-jai-plugin-base) - Framework for creating CLAP plugin, depends on clap-jai - [Example plugin](https://github.com/jatinchowdhury18/clap-jai-example-plugin).


### **Cryptography**
   * [Crypto](https://github.com/smari/jai-crypto) - Cryptographic primitives library.

### **Networking**
   * [GameNetworkingSockets](https://github.com/Manquia/gns-jai) - Bindings for GameNetworkingSockets.
   * [libmicrohttpd-jai](https://github.com/kujukuju/libmicrohttpd-jai) - Bindings for libmicrohttpd, a compact multithreaded http/1.1 web server, [helpers](https://github.com/kujukuju/KodaMicroHttp).
   * [MongooseJai](https://github.com/kujukuju/mongooseJai) - Mongoose bindings, [helpers](https://github.com/kujukuju/mongooseJaiHelpers).
   * [nghttp2-jai](https://github.com/kujukuju/nghttp2-jai) - nghttp2 bindings for low level http2 multithread-able web server.
   * [SimpleHTTP](https://github.com/smari/jai-simplehttp) - a super simple HTTP server library. 
   * [JaiSimpleServer](https://github.com/kujukuju/JaiSimpleServer) - A simple static http server. 
   * [Jai-HTTP-Server](https://github.com/farzher/Jai-HTTP-Server) - Features: HTTP / HTTPS / Websockets / epoll threading / Brotli compression - Focused on maximum performance.
   * [Winsock](https://github.com/judah-caruso/jai-winsock) - Bindings for Winsock 1.
   * [Winsock 2](https://github.com/judah-caruso/jai-winsock2) - Bindings for Winsock 2. 
   * [wsServer](https://github.com/kujukuju/wsServerJai) - Bindings for wsServer, a very simple not optimized websocket server.  
   * [enet-jai](https://github.com/rytc/enet-jai) - Native Jai port of the ENet Reliable UDP networking library.
   * [jai-s3](https://github.com/smari/jai-s3) - Bindings for [libs3](https://github.com/ceph/libs3).
   * [yojimbo](https://github.com/dbechrd/jai-yojimbo) - Jai port of the [yojimbo](https://github.com/mas-bandwidth/yojimbo) network library for client/server games
   * [jai-reliable](https://github.com/dbechrd/jai-reliable) - Reliable UDP Protocol
   * [jai-netcode](https://github.com/dbechrd/jai-netcode) - UDP Connection Protocol
   * [jai-serialize](https://github.com/dbechrd/jai-serialize) - Packet serialization
   * [jai-ip-address](https://github.com/dbechrd/jai-ip-address) - Standalone IPv4/6 address parser with zero dependencies other than Jai's Basic module. Has much better error messages.

### **Databases**
   * [Postgresql](https://github.com/rluba/jai-postgres) - Postgres bindings.
   * [Redis](https://github.com/smari/jai-redis) - Redis API library.
   * [SQLite3Jai](https://github.com/kujukuju/sqlite3Jai) - SQLite3 bindings.  
   * [jai-sqlite3](https://github.com/rluba/jai-sqlite3) - A little example of how to use Jai’s bindings generator to use sqlite3 in Jai.

### **Math, Linear Algebra, & Physics**
   * [GraphBLAS](https://github.com/smari/jai-graphblas) - Sparse matrix linear algebra library.
   * [Linalg](https://github.com/ostef/linalg) - Linear algebra library with vectors, matrices and quaternions.
   * [MathExtensions](https://github.com/shiMusa/MathExtensions) - Advanced math functions for Jai

### **File formats**
   * [CSV](https://github.com/rluba/jai-csv) - CSV file reader.
   * [GDAL](https://github.com/smari/jai-gdal) - GDAL library interface; handles dozens of file graphical/geographical file formats.
   * [INI](https://github.com/smari/jai-ini) - INI file reader/writer.
   * [ContiguousJson](https://github.com/kujukuju/ContiguousJsonJai) - JSON reader/writer that keeps the data in contiguous memory.
   * [JSON](https://github.com/rluba/jason) - JSON reader/writer.
   * [QOI](https://github.com/mimhufford/jai-qoi) - QOI file reader.
   * [ZIP](https://github.com/mcourteaux/jai-zip) - ZIP read/write library. Wrapper around _kuba--/zip_.
   * [XML](https://github.com/smari/jai-xml) - XML parser and DOM interface library.
   * [LDTK Importer](https://github.com/CraigGiles/jai-ldtk-importer)
   * [TOML](https://github.com/sjorsdonkers/toml-jai) - A module for TOML v1.0.0 support.
   * [FFmpeg](https://github.com/charlesastaylor/jai-ffmpeg) - FFmpeg bindings for jai and some examples decoding and play videos


### Compression

   * [ZFP](https://github.com/smari/jai-zfp) - bindings for the [LLNL ZFP library](https://computing.llnl.gov/projects/zfp).

### **Utilities**
   * [Metaprogram](https://github.com/onelivesleft/Metaprogram) - automatically download jai-modules from github via `#import`
   * [C](https://github.com/judah-caruso/C) - Interop library for writing C bindings. 
   * [jai-string](https://github.com/onelivesleft/jai-string) - onelivesleft's String library.  
   * [Fmt](https://github.com/ostef/jai-fmt) - A string formatting library.
   * [jai-date](https://github.com/rluba/jai-date) - Small date module for Jai  
   * [jai-unicode](https://github.com/rluba/jai-unicode) - Unicode utility functions for Jai
   * [Magic](https://github.com/smari/jai-magic) - libmagic bindings.
   * [Steam API](https://github.com/onelivesleft/jai-steam) - Steam API library.
   * [Uniform](https://github.com/rluba/uniform) - Fully-featured regular expression library.
   * [jai-parallel-for](https://github.com/shiMusa/jai-parallel-for) - execute for-like loops in parallel
   * [SimpleSerializer](https://github.com/shiMusa/SimpleSerializer) - serialize and de-serialize to/from binary data
   * [JaiSerializer](https://github.com/kujukuju/JaiSerializer) - Simple library to read/write structs or nearly any data type into binary.  
   * [osor_serialization](https://github.com/osor-io/osor_serialization) - A serialization module for Jai  
   * [construct](https://github.com/shiMusa/construct) - `#insert` structs as constants during compile time
   * [Jai-Plot](https://github.com/shiMusa/Jai-Plot) - a simple scientific plotting tool to be called from Jai code
   * [Symbols](https://github.com/shiMusa/Symbols) - A load macro that allows the use of non-ascii characters in `.jai` code files
   * [stb/truetype](https://github.com/Breush/lava-jai-bindings/tree/master/StbTrueType) - To load fonts.
   * [Arithmetic Coding](https://github.com/mcourteaux/jai-arithmetic-coding) - An arithmetic coder (encoding and decoding) with custom frequency tables.  
   * [JaiBoy](https://github.com/Sl3dge78/JaiBoy) - A GameBoy Emulator in Jai   
   * [3ds-hello-jai](https://github.com/TheGag96/3ds-hello-jai) - An example Jai program for the Nintendo 3DS (archived)!
   * [Playdate](https://github.com/rezich/Playdate) - Playdate handheld bindings for Jai
   * [Jai Bunnymark - D3D11](https://github.com/farzher/Bunnymark-Jai-D3D11) - Just checking how fast computers can go  
   * [clipman](https://github.com/farzher/clipman) - A Clipboard manager for Windows, alternative to Ditto.
   * [jisp](https://github.com/judah-caruso/jisp) - Automatically parses a Lisp into Jai code at compile-time.  
   * [osor_parser](https://github.com/osor-io/osor_parser) - A parsing module for Jai  
   * [osor_coroutine](https://github.com/osor-io/osor_coroutine) - A coroutine module for Jai.
   * [tracy](https://github.com/wolfpld/tracy) - Jai bindings for Tracy, a powerful open-source telemetry profiler.  
   * [twitch_irc](https://github.com/rluba/twitch_irc) - A Twitch IRC library written in Jai
   * [chi_state_tracker](https://github.com/CraigGiles/chi_state_tracker) - System to track and query against the systems knowledge of a game state.  
   * [jai-autocomplete](https://github.com/mimhufford/jai-autocomplete) - A simple command line tool to list which procedures accept a given struct as a parameter. 
   * [kscurses](https://github.com/CyanMARgh/kscurses) - A Jai port of curses (a terminal control library (TUI) for Unix-like systems). 
   * [gltf_parser](https://github.com/kooparse/gltf_parser) - A glTF parser for Jai codebase.
   * [jai-sim86-bindings](https://github.com/tomasz-rozanski/jai-sim86-bindings) - Jai bindings for Casey Muratori's [8086 Simulator](https://github.com/cmuratori/computer_enhance/tree/main/perfaware/sim86)
   * [nanoid](https://github.com/cguess/nanoid-jai/tree/main) - A simple [NanoID](https://github.com/ai/nanoid) implementation.
   * [MetaThreadSafe](https://github.com/kujukuju/metathreadsafe) - A metaprogram plugin to verify safe thread access and help prevent multithreading issues.
   * [jai-modules](https://github.com/gudinoff/jai-modules) - Various modules: **Saturation** provides integer saturation arithmetic procedures: `add`, `sub`, `mul`, and `div`; **TUI** provides functionalities similar to the ncurses library; **UTF8** provides basic operations over UTF8 encoded strings.

### **Version Control Systems**
   * [ark-vcs](https://www.ark-vcs.com/) - A Versioning Control System with Games in mind, by Nuno Afonso.

### **Testing**
   * [Stubborn](https://github.com/rluba/stubborn) - Minimal test runner and assertion library.

### **Algorithms**
   * [Binary BVH Tree](https://github.com/kujukuju/JaiBoundingTree) - Jai Binary BVH Tree
   * [jai-ryu](https://github.com/ostef/jai-ryu) - Ryū: Fast float to string conversion and Ryū printf
   * [John Conway's Game of Life](https://github.com/danieltan1517/game_of_life) - Didactic implementation of John Conway's Game of Life
   * [Jai-OpenSimplex](https://github.com/shiMusa/Jai-OpenSimplex) - Jai port of the OpenSimplex algorithm.
   * [Parallel Merge Sort](https://github.com/kujukuju/ParallelMergeSort) - Simple & efficient jai parallel merge sort.
   * [Performance Monitoring Counters](https://github.com/charlesastaylor/Performance_Monitoring_Counters) - Jai module to enable collecting Performance-Monitoring Counters (PMCs) thread-safe, continuously on a running program
   * [jdsp](https://github.com/mathaou/jdsp) - Jai Digital Signal Processing Utilities

### **Physics**
   * [JaiBox2D](https://github.com/kujukuju/JaiBox2D) - Bindings for Box2D.
   * [JaiBullet](https://github.com/kujukuju/JaiBullet) - Bindings for Bullet Physics based on an incomplete C wrapper.
   * [JaiPhysX](https://github.com/kujukuju/JaiPhysX) - PhysX 4.1 c-style bindings.
   * [KodaPhysics](https://github.com/kujukuju/KodaPhysics) - Static only physics engine.  

### **Artificial Intelligence and Machine Learning**
   * [Chess AI + UI](https://github.com/danieltan1517/chess-jai) - Chess Engine with Neural Networks and Lazy SMP Parallel Search with User Interface
   * [Xiangqi AI](https://github.com/danieltan1517/orange-xiangqi) - Xiangqi Chinese Chess Engine with Neural Networks and Lazy SMP Parallel Search with User Interface
   * [MNIST in Jai](https://github.com/danieltan1517/mnist_in_jai) - Neural Networks in Jai to detect MNIST handwritten digits.

### **Operating Systems**
   * [theos](https://github.com/dlandahl/theos-2) - The Operating System. An Operating System written in Jai

### **Scientific**
   * [Jai-Scientific-Units](https://github.com/shiMusa/Jai-Scientific-Units) - Use numbers with units!

### **Compilation and WASM**
   * [Wasm Compiler & WebGL](https://github.com/kujukuju/JaiWasmGL) - Helper functions, memory allocator, and bindings to run jai code in browser with webgl.  
   * [Jai WebAssembly](https://github.com/tsoding/jai-wasm) - Proof-of-Concept 
   * [jai_wasm](https://github.com/SogoCZE/jai_wasm) - Jai WASM Plugin
   * [Raspberry Jai](https://github.com/TheGag96/raspberry-jai) - Cross-compiling Jai for the Raspberry Pi

### **Other**
   * [Jai-Win32](https://github.com/ostef/Jai-Win32) - Win32 bindings for the Jai programming language (includes Direct3D12 related bindings)
   * [Jai experiments](https://github.com/GufNZ/jai)
   * [jai-assertive](https://github.com/dbechrd/jai-assertive) - Better asserts (can be used for unit testing, or to replace asserts in debug builds for better error messages).

# Example code
 * [jaitro](https://github.com/kevinw/jaitro) - a libretro frontend.
 * [jaidoku](https://github.com/mimhufford/jaidoku) - A Sudoku game.
 * [jai-shooter](https://github.com/kevinw/jai-shooter/) - A shooting game.
 * [Cavy](https://github.com/smari/Cavy) - a simple multithreaded web server.
 * [Mara](https://github.com/smari/Mara) - a simple Gopher server.  
 * [jaibreak](https://github.com/tsoding/jaibreak) - a breakout game
 * [aoc2022](https://github.com/forrestthewoods/aoc2022) - Advent of Code 2022 implementation
 * [arrow-jai](https://github.com/Byteron/arrow-jai) - One Arrow Colosseum - GMTK 2019 Game Jam Entry
 * [SimpleGames-Jai](https://github.com/hopeforsenegal/SimpleGames-Jai) - Three simple games in Jai with 
    Raylib (v3.7.0).
 * [Jai-Mines](https://github.com/baileysostek/Jai-Mines) - A Minesweeper Game made in Jai.
 * [sokoban](https://github.com/daafu/sokoban) - A [published](https://badcastle.itch.io/piotr-pushowski) Sokoban game made in Jai.
 * [TIS-99](https://github.com/CyanMARgh/tis-99)
 * [Checkers for 4 players](https://github.com/CyanMARgh/jai-checkers)
 * [Skeletal Animation](https://github.com/ostef/skeletal-animation-example) - a 3d skeletal animation viewer

# Other Guides and Documentation
 * [Jonathan Blow's language playlist on YouTube](https://www.youtube.com/watch?v=TH9VCN6UkyQ&list=PLmV5I2fxaiCKfxMBrNsU1kgKJXD3PkyxO&ab_channel=JonathanBlow)
 * [Encyclopedia of Jai Examples](https://github.com/Jai-Community/Encyclopedia-of-Jai-Examples)
 * [The Way to Jai - A gradual guide to discover and learn the Jai programming language](https://github.com/Ivo-Balbaert/The_Way_to_Jai)
 * [Joy of Programming in Jai YouTube Series - Nuno Afonso](https://www.youtube.com/watch?v=i1vbvikDiI8&list=PLhEuCycbde-vyFoSBJbdKjw-AVTdQRE5g)
 * [Jai on Reddit](https://www.reddit.com/r/Jai/) 
 * [Jai resources - Inductive.no](https://inductive.no/jai/)
 * Patrick's [Getting started with Jai](https://github.com/patrickgh3/jai-getting-started)
 * [BSVino's Jai Primer](https://github.com/BSVino/JaiPrimer/blob/master/JaiPrimer.md)
 * [Iain King's Jai Cookbook](https://github.com/onelivesleft/jai-cookbook)

# Articles
 * [Learning Jai via Advent of Code](https://www.forrestthewoods.com/blog/learning-jai-via-advent-of-code/) 
     ForrestTheWoods - 2023 Feb 13
 * [My Experience With Jai ](https://www.siltutorials.com/blog/2023/1/5/my-experience-with-jai-part-1) 
     SilTutorials - 2023 Jan 5

# Tooling Ecosystem
 * [Smash](https://github.com/rluba/smash) - A debugger for Linux (and hopefully macOS), written from scratch in Jai by [rluba](https://github.com/rluba).
 * [Focus - A simple editor in Jai](https://github.com/focus-editor/focus)
 * [LLDB formatters for Jai types](https://github.com/puremourning/lldb-jai)
 * [Ctags](https://github.com/rluba/jai-ctags) - generate ctags for various editors
 * [Jai LSP by Patrik Smělý](https://github.com/SogoCZE/Jails)
 * [jai-lsp by Pyromuffin](https://github.com/Pyromuffin/jai-lsp)
 * [jai-lsp by Sl3dge78](https://github.com/Sl3dge78/jai_lsp)
 * [JaiTools for Sublime Text 3](https://github.com/RobinWragg/JaiTools)
 * [tree-sitter-jai](https://github.com/Pyromuffin/tree-sitter-jai)
 * [Vim syntax](https://github.com/rluba/jai.vim)
 * [Jai mode for Emacs](https://github.com/krig/jai-mode)
 * [Notepad++ Syntax Highlighting](https://github.com/cookednick/jai_npp)
 * [Jai language definition file for Kakoune](https://github.com/dgrisham/jai.kak)
 * [jai-format](https://github.com/OrangeLightning219/jai-format) - Simple code formatter for Jai.
 * [discourse-highlightjs-jai](https://github.com/Jai-Community/discourse-highlightjs-jai) - Discourse theme component to highlight Jai syntax  
 * VS Code support:
   * Iain King's [VS Code support](https://marketplace.visualstudio.com/items?itemName=onelivesleft.the-language)
   * [BetterComments extension with Jai support](https://github.com/shiMusa/better-comments)

# Resources
 * [Hacker's Delight](https://doc.lagout.org/security/Hackers%20Delight.pdf)
 * [Modern x64 Assembly: Beginning Assembly Programming](https://www.youtube.com/watch?v=rxsBghsrvpI&list=PLKK11Ligqitg9MOX3-0tFT1Rmh3uJp7kA)
 * [x86 and amd64 instruction reference](https://www.felixcloutier.com/x86/index.html)
 * [Intel Intrinsics Guide](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html#)
 * [Godbolt, Compiler Explorer](https://godbolt.org/)
 * [Learn OpenGL](https://learnopengl.com/)
 * [OpenGL](https://www.opengl.org/)
 * [LLVM](https://llvm.org/)
 * [LLVM Documentation](https://llvm.org/doxygen/modules.html)
 * [Linear Algebra Done Right](https://linear.axler.net/)
 * [Memory Allocation Strategies](https://www.gingerbill.org/series/memory-allocation-strategies/)
 * [A Digital Signal Processing Primer: With Applications to Digital Audio and Computer Music](https://www.amazon.com/Digital-Signal-Processing-Primer-Applications/dp/0805316841)
 * [Hypercomplex Numbers: An Elementary Introduction to Algebras](https://www.amazon.com/Hypercomplex-Numbers-Elementary-Introduction-Algebras/dp/1461281911/ref=sr_1_1?crid=11CHIZ5HA8JEO&dib=eyJ2IjoiMSJ9.6pUWj-WUbLXp85E6brZlxw.UfXmZtPyqh60x4wV5D_NB7NuFM109Y0ILUVpYTsr9sI&dib_tag=se&keywords=hypercomplex+numbers+an+elementary+introduction+to+algebras&qid=1736674232&sprefix=hypercomplex+nu%2Caps%2C145&sr=8-1)



--- End of file: documents/08_references.md ---

--- Start of file: documents/09_leetcode_basics_arrays_strings.md ---
This page demonstrates how to solve common LeetCode programming interview questions in Jai, focusing on array manipulation, string processing, and basic number problems.

Each section describes:
* The problem statement
* A Jai solution, with an explanation of the approach

---

# Fizz Buzz

**Problem:** Fizz Buzz is a classic interview screening problem. Count from 1 to 100, replacing any number divisible by 3 with "Fizz", any number divisible by 5 with "Buzz", and any number divisible by both 3 and 5 with "FizzBuzz".

## While Loop Solution

```jai
main :: () {
    i := 1;
    while i < 100 {
        if (i % 5) == 0 && (i % 3) == 0 {
            print("FizzBuzz\n");
        } else if (i % 3) == 0 {
            print("Fizz\n");
        } else if (i % 5) == 0 {
            print("Buzz\n");
        } else {
            print("%\n", i);
        }
        i += 1;
    }
}

#import "Basic";
```

## For Loop Solution

```jai
main :: () {
    for i : 1..100 {
        if (i % 3) == 0 && (i % 5) == 0 {
            print("FizzBuzz\n");
        } else if (i % 3) == 0 {
            print("Fizz\n");
        } else if (i % 5) == 0 {
            print("Buzz\n");
        } else {
            print("%\n", i);
        }
    }
}

#import "Basic";
```

The output of both programs is:
```
1
2
Fizz
4
Buzz
Fizz
...
14
FizzBuzz
```

---

# Shuffle the Array

**Problem:** Given an array `nums` of `2n` elements in the form `[x1, x2, ..., xn, y1, y2, ..., yn]`, return the array interleaved as `[x1, y1, x2, y2, ..., xn, yn]`.

## Solution

Iterate through the array and alternate between picking elements from the first half and the second half, building the interleaved result.

```jai
shuffle :: (nums: [] int, n: int) -> [..] int {
    ans: [..] int;
    i := 0;
    j := 0;
    count := 0;
    while count < nums.count {
        if (count % 2) == 0 {
            array_add(*ans, nums[i]);
            i += 1;
        } else {
            array_add(*ans, nums[n+j]);
            j += 1;
        }
        count += 1;
    }
    return ans;
}
```

---

# XOR Operation in an Array

**Problem:** Given an integer `n` and an integer `start`, define an array `nums` where `nums[i] = start + 2 * i` (0-indexed) and `n == nums.length`. Return the bitwise XOR of all elements of `nums`.

## Solution

Build the sequence on the fly and accumulate the XOR result in a single pass, avoiding the need to allocate the array.

```jai
xor_operation :: (n: int, start: int) -> int {
    value := 0;
    i := 0;
    while i < n {
        value ^= start;
        start += 2;
        i += 1;
    }
    return value;
}
```

---

# Remove Duplicates from Sorted Array

**Problem:** Given an integer array `nums` sorted in non-decreasing order, remove duplicates in-place so that each unique element appears only once. Return the count `k` of unique elements. The first `k` elements of `nums` must hold the unique values in sorted order.

## Solution

Use a read pointer `i` and a write pointer `unique`. When a new distinct value is encountered, write it to the front of the array at position `unique`.

```jai
remove_duplicates :: (nums: [] int) -> int {
    unique := 1;
    number := nums[0];
    i := 1;
    while i < nums.count {
        if nums[i] != number {
            number = nums[i];
            nums[unique] = number;
            unique += 1;
        }
        i += 1;
    }
    return unique;
}
```

---

# Partitioning Into Minimum Number of Deci-Binary Numbers

**Problem:** A decimal number is called deci-binary if each of its digits is either `0` or `1` without any leading zeros. For example, `101` and `1100` are deci-binary, while `112` and `3001` are not.

Given a string `n` representing a positive decimal integer, return the minimum number of positive deci-binary numbers needed so that they sum up to `n`.

## Solution

The minimum number of partitions equals the largest digit in the string. A digit `d` requires exactly `d` deci-binary numbers to represent it (each contributing one `1` in that position). Simply scan the string to find the maximum digit.

```jai
min_partitions :: (n: string) -> int {
    numbers := 0;
    i := 0;
    while i < n.count {
        d := n[i] - #char "0";
        if d > numbers {
            numbers = d;
        }
        i += 1;
    }
    return numbers;
}
```

---

# Gray Code

**Problem:** An n-bit Gray code sequence is a sequence of `2^n` integers where every integer is in `[0, 2^n - 1]`, starts at `0`, each integer appears exactly once, and adjacent integers differ by exactly one bit (including the first and last). Given `n`, return any valid n-bit Gray code sequence.

## Solution

The standard Gray code formula is `gray(i) = i XOR (i >> 1)`. Iterate from `0` to `2^n - 1` and apply the formula to each index.

```jai
gray_code :: (n: int) -> [..] int {
    result: [..] int;
    totalCodes := (1 << n) - 1;
    for i: 0..totalCodes {
        grayValue := i ^ (i >> 1);
        array_add(*result, grayValue);
    }
    return result;
}
```

---

# Reverse Integer

**Problem:** Given a signed 32-bit integer `x`, return `x` with its digits reversed. If reversing `x` causes the value to go outside the signed 32-bit integer range `[-2^31, 2^31 - 1]`, return `0`.

## Solution

Handle the sign separately, then repeatedly extract the last digit with modulo and build the reversed number, checking for overflow before multiplying.

```jai
reverse :: (x: int) -> int {
    negative := 0;
    if x < 0 {
        if x == -2147483648 {
            return 0;
        }
        x = -x;
        negative = 1;
    }
    y := 0;
    while x > 0 {
        if y <= 214748364 {
            y *= 10;
        } else {
            return 0;
        }
        y += x % 10;
        x /= 10;
    }
    if negative == 1 {
        return -y;
    }
    return y;
}
```

---

# Check if Binary String Has At Most One Segment of Ones

**Problem:** Given a binary string `s` without leading zeros, return `true` if `s` contains at most one contiguous segment of ones. Otherwise, return `false`.

## Solution

Scan past the initial block of ones until a `'0'` is found. Then scan the remainder of the string — if any `'1'` appears after the first `'0'`, there is a second segment, so return `false`.

```jai
check_ones_segment :: (s: string) -> bool {
    i := 0;
    while i < s.count {
        if s[i] == #char "0" {
            i += 1;
            break;
        }
        i += 1;
    }

    while i < s.count {
        if s[i] == #char "1" {
            return false;
        }
        i += 1;
    }

    return true;
}
```

---

# Ugly Number

**Problem:** An ugly number is a positive integer whose only prime factors are 2, 3, and 5. Given an integer `n`, return `true` if `n` is an ugly number.

## Solution

Repeatedly divide `n` by 2, 3, and 5 for as long as it is divisible by each. If the result is 1, the number had no other prime factors, so it is ugly. Non-positive numbers are never ugly.

```jai
is_ugly :: (n: int) -> bool {
    if n >= 1 && n <= 3 {
        return true;
    }
    if n <= 0 {
        return false;
    }
    while (n % 5) == 0 {
        n /= 5;
    }
    while (n % 3) == 0 {
        n /= 3;
    }
    while (n % 2) == 0 {
        n /= 2;
    }
    return n == 1;
}
```

---

# Single Number

**Problem:** Given a non-empty array of integers `nums`, every element appears twice except for one. Find the single element. You must use linear runtime and constant extra space.

## Solution

XOR-ing any number with itself yields 0, and XOR-ing any number with 0 yields the number itself. Folding XOR over the entire array cancels all duplicates, leaving only the unique element.

```jai
single_number :: (nums: [] int) -> int {
    value := 0;
    for num : nums {
        value ^= num;
    }
    return value;
}
```

---

# Single Number II

**Problem:** Given an integer array `nums` where every element appears three times except for one element which appears exactly once, find and return the single element. You must use linear runtime and constant extra space.

## Solution

Use two bitmasks, `ones` and `twos`, to track bits that have appeared once and twice respectively. After a third occurrence, a bit is cleared from both masks. The answer is stored in `ones`.

```jai
single_number :: (nums: [] int) -> int {
    ones := 0;
    twos := 0;
    for num : nums {
        ones = (ones ^ num) & ~twos;
        twos = (twos ^ num) & ~ones;
    }
    return ones;
}
```

---

# Array Partition

**Problem:** Given an integer array `nums` of `2n` integers, group them into `n` pairs such that the sum of `min(a_i, b_i)` across all pairs is maximized. Return that maximized sum.

## Solution

Sort the array and sum every other element starting from the second-to-last. When sorted, the optimal pairing always puts adjacent elements together, and every even-indexed element (0-indexed from the back) is the minimum of its pair.

```jai
array_pair_sum :: (nums: [] int) -> int {
    sort(nums);
    sum := 0;
    i := nums.count - 2;
    while i >= 0 {
        sum += nums[i];
        i -= 2;
    }
    return sum;
}
```

---

# Hamming Distance

**Problem:** Given two integers `x` and `y`, return the Hamming distance between them — the number of bit positions at which the corresponding bits differ.

## Solution

XOR the two numbers to isolate all differing bits. Then count the set bits using Brian Kernighan's algorithm: repeatedly clear the lowest set bit with `bits &= bits - 1`.

```jai
hamming_distance :: (x: int, y: int) -> int {
    bits := x ^ y;
    count := 0;
    while bits {
        count += 1;
        bits &= bits - 1;
    }
    return count;
}
```

---

# Power of Two

**Problem:** Given an integer `n`, return `true` if it is a power of two, otherwise return `false`.

## Solution

A power of two has exactly one bit set in its binary representation. Clearing the lowest set bit with `n &= n - 1` will produce zero if and only if `n` had exactly one bit set. Non-positive numbers are immediately rejected.

```jai
is_power_of_two :: (n: int) -> bool {
    if n <= 0 return false;
    n &= n - 1;
    return n == 0;
}
```

---

# Count Primes

**Problem:** Given an integer `n`, return the count of prime numbers strictly less than `n`.

## Solution

Use the Sieve of Eratosthenes. Mark composite numbers by iterating through multiples of each prime found. Count the unmarked numbers.

```jai
count_primes :: (n: int) -> int {
    numbers := NewArray(n, bool);
    for i : 0..n-1 {
        numbers[i] = false;
    }
    count := 0;
    for i : 2..n-1 {
        if numbers[i] {
            continue;
        }
        count += 1;
        numbers[i] = true;
        y := i;
        while y < n {
            numbers[y] = true;
            y += i;
        }
    }
    return count;
}
```

---

# Pascal's Triangle

**Problem:** Given an integer `num_rows`, return the first `num_rows` of Pascal's triangle. In Pascal's triangle, each number is the sum of the two numbers directly above it. Assume `1 <= num_rows <= 300`.

## Solution

The first row is `[1]`. For each subsequent row, the first and last elements are `1`, and every interior element is the sum of the two elements directly above it in the previous row.

```jai
generate :: (num_rows: int) -> [][] int {
    pascal_triangle: [][] int = NewArray(num_rows, ([] int));
    first := NewArray(1, int);
    first[0] = 1;
    pascal_triangle[0] = first;

    previous := 0;
    numbers := 2;
    for i : 1..num_rows - 1 {
        next_row := NewArray(numbers, int);
        next_row[0] = 1;
        next_row[numbers - 1] = 1;
        for j : 1..numbers - 2 {
            next_row[j] = pascal_triangle[previous][j-1] + pascal_triangle[previous][j];
        }
        pascal_triangle[i] = next_row;
        previous += 1;
        numbers += 1;
    }

    return pascal_triangle;
}
```

---

# Count Equal and Divisible Pairs in an Array

**Problem:** Given a 0-indexed integer array `nums` of length `n` and an integer `k`, return the number of pairs `(i, j)` where `0 <= i < j < n`, `nums[i] == nums[j]`, and `(i * j)` is divisible by `k`.

## Solution

Use nested loops to examine every pair. For each pair, check both conditions and increment the count if both are satisfied.

```jai
count_pairs :: (nums: [] int, k: int) -> int {
    count := 0;
    i := 0;
    while i < nums.count {
        j := i + 1;
        while j < nums.count {
            multiply := i * j;
            if nums[i] == nums[j] && (multiply % k) == 0 {
                count += 1;
            }
            j += 1;
        }
        i += 1;
    }
    return count;
}
```

---

# Valid Parentheses

**Problem:** Given a string `s` containing only `'('`, `')'`, `'{'`, `'}'`, `'['`, and `']'`, determine if the input string is valid. Brackets must close in the correct order and every closing bracket must have a matching open bracket.

## Solution

Use a dynamic array as a stack. Push each opening bracket. When a closing bracket is encountered, pop the top of the stack and verify it matches. If the stack is empty at the end, the string is valid.

```jai
is_valid :: (s: string) -> bool {
    braces: [..] u8;
    i := 0;
    while i < s.count {
        ch := s[i];
        if ch == #char ")" || ch == #char "}" || ch == #char "]" {
            if !braces return false;
            top := peek(braces);
            if ch == #char ")" && top == #char "(" {
                pop(*braces);
            } else if ch == #char "}" && top == #char "{" {
                pop(*braces);
            } else if ch == #char "]" && top == #char "[" {
                pop(*braces);
            } else {
                return false;
            }
        } else {
            array_add(*braces, ch);
        }
        i += 1;
    }
    return braces.count == 0;
}
```

---

# Missing Number

**Problem:** Given an array `nums` containing `n` distinct numbers in the range `[0, n]`, return the only number in the range that is missing.

## Solution

Allocate a boolean array of size `n + 1` and mark each value present in `nums`. Scan the boolean array for the unmarked index, which is the missing number.

```jai
missing_number :: (nums: [] int) -> int {
    array := NewArray(nums.count + 1, bool);
    for * value : array {
        value.* = false;
    }
    for n : nums {
        array[n] = true;
    }
    for value, i : array {
        if (!value) {
            return i;
        }
    }
    return -1;
}
```

---

# Sort Integers by Number of 1 Bits

**Problem:** Given an integer array `arr`, sort the integers in ascending order by the number of `1`s in their binary representation. Ties are broken by the integer's numeric value.

## Solution

Use a stable sort with a custom comparator that counts set bits using Brian Kernighan's algorithm and falls back to numeric comparison for ties.

```jai
count_bits :: (n: int) -> int {
    count := 0;
    while n {
        count += 1;
        n &= n - 1;
    }
    return count;
}

sort_by_bits :: (arr: [] int) {
    // insertion sort with custom comparison
    i := 1;
    while i < arr.count {
        key := arr[i];
        j := i - 1;
        while j >= 0 {
            bits_j   := count_bits(arr[j]);
            bits_key := count_bits(key);
            if bits_j > bits_key || (bits_j == bits_key && arr[j] > key) {
                arr[j + 1] = arr[j];
                j -= 1;
            } else {
                break;
            }
        }
        arr[j + 1] = key;
        i += 1;
    }
}
```

---

# Integer to Roman

**Problem:** Given an integer, convert it to a Roman numeral using the standard subtractive notation (e.g., `IV` for 4, `IX` for 9, `XL` for 40, etc.).

## Solution

Pre-store lookup tables for the ones, tens, hundreds, and thousands places. Decompose the number digit by digit and concatenate the corresponding Roman numeral strings.

```jai
int_to_roman :: (num: int) -> string {
    ones := string.["","I","II","III","IV","V","VI","VII","VIII","IX"];
    tens := string.["","X","XX","XXX","XL","L","LX","LXX","LXXX","XC"];
    hrns := string.["","C","CC","CCC","CD","D","DC","DCC","DCCC","CM"];
    ths  := string.["","M","MM","MMM"];
    return join(ths[num/1000], hrns[(num%1000)/100], tens[(num%100)/10], ones[num%10]);
}
```

---

# Roman to Integer

**Problem:** Given a Roman numeral string, convert it to an integer. Subtractive notation is used for values like 4 (IV), 9 (IX), 40 (XL), 90 (XC), 400 (CD), and 900 (CM).

## Solution

Scan the string left to right. For each character, check whether the next character forms a subtractive pair. If so, add the two-character value and advance two positions; otherwise add the single character value.

```jai
roman_to_int :: (s: string) -> int {
    sum := 0;
    i := 0;
    while i < s.count {
        if s[i] == #char "M" {
            sum += 1000;
        } else if s[i] == #char "D" {
            sum += 500;
        } else if s[i] == #char "I" && i < s.count-1 && s[i+1] == #char "V" {
            i += 1;
            sum += 4;
        } else if s[i] == #char "I" && i < s.count-1 && s[i+1] == #char "X" {
            i += 1;
            sum += 9;
        } else if s[i] == #char "X" && i < s.count-1 && s[i+1] == #char "L" {
            i += 1;
            sum += 40;
        } else if s[i] == #char "X" && i < s.count-1 && s[i+1] == #char "C" {
            i += 1;
            sum += 90;
        } else if s[i] == #char "C" && i < s.count-1 && s[i+1] == #char "D" {
            i += 1;
            sum += 400;
        } else if s[i] == #char "C" && i < s.count-1 && s[i+1] == #char "M" {
            i += 1;
            sum += 900;
        } else if s[i] == #char "I" {
            sum += 1;
        } else if s[i] == #char "V" {
            sum += 5;
        } else if s[i] == #char "X" {
            sum += 10;
        } else if s[i] == #char "L" {
            sum += 50;
        } else if s[i] == #char "C" {
            sum += 100;
        }
        i += 1;
    }
    return sum;
}
```

---

# Sort Colors

**Problem:** Given an array `nums` with `n` objects colored red (`0`), white (`1`), or blue (`2`), sort them in-place so that objects of the same color are adjacent, in the order red, white, blue. Do not use the library's sort function.

## Solution

Count the occurrences of each color (0, 1, 2), then overwrite the array by writing each color the appropriate number of times.

```jai
sort_colors :: (nums: [] int) {
    colors: [3] int = .[0, 0, 0];
    for n : nums {
        colors[n] += 1;
    }

    index := 0;
    for i : 0..2 {
        for j : 0..(colors[i] - 1) {
            nums[index] = i;
            index += 1;
        }
    }
}
```

---

# Length of Last Word

**Problem:** Given a string `s` consisting of words and spaces, return the length of the last word.

## Solution

Walk backwards from the end of the string to skip trailing spaces. Then continue walking backwards to find the start of the last word. The difference between the two positions is the length.

```jai
length_of_last_word :: (s: string) -> int {
    endWordIndex := s.count - 1;
    while endWordIndex >= 0 && is_space(s[endWordIndex]) {
        endWordIndex -= 1;
    }

    beginWordIndex := endWordIndex;
    while (beginWordIndex >= 0 && !is_space(s[beginWordIndex])) {
        beginWordIndex -= 1;
    }

    return endWordIndex - beginWordIndex;
}
```

---

# Contains Duplicate II

**Problem:** Given an integer array `nums` and an integer `k`, return `true` if there exist two distinct indices `i` and `j` such that `nums[i] == nums[j]` and `abs(i - j) <= k`.

## Naive Solution

Use two nested loops to check all pairs. This runs in O(n²) time.

```jai
contains_nearby_duplicate :: (nums: [] int, k: int) -> bool {
    N := nums.count - 1;
    for i : 0..N {
        for j : i + 1 .. N {
            if nums[i] == nums[j] && (j - i) <= k {
                return true;
            }
        }
    }
    return false;
}
```

## Optimized Hash Table Solution

Store each value's most recent index in a hash table. For each new element, check whether the stored index is within `k` of the current index. This runs in O(n) time.

```jai
contains_nearby_duplicate :: (nums: [] int, k: int) -> bool {
    values: Table(int, int);
    i := 0;
    while i < nums.count {
        j, success := table_find(*values, nums[i]);
        if success && abs(j - i) <= k {
            return true;
        }
        table_add(*values, nums[i], i);
        i += 1;
    }
    return false;
}
```

---

# Majority Element

**Problem:** Given an array `nums` of size `n`, return the majority element — the element that appears more than `n / 2` times. You may assume the majority element always exists.

## Sorting Solution

Sort the array. Because the majority element appears more than half the time, it will always occupy the middle index of the sorted array. This runs in O(n log n) time.

```jai
majority_element :: (nums: [] int) -> int {
    quicksort(nums);
    mid := nums.count / 2;
    return nums[mid];
}
```

## Hash Table Solution

Count the frequency of each element using a hash table, then return the element with the highest count. This runs in O(n) time and O(n) space.

```jai
majority_element :: (nums: [] int) -> int {
    table: Table(int, int);
    for n : nums {
        table_value, added := find_or_add(*table, n);
        if added {
            table_value.* = 1;
        } else {
            table_value.* += 1;
        }
    }

    count := 0;
    element := -1;
    for value, key : table {
        if (value > count) {
            count = value;
            element = key;
        }
    }
    return element;
}
```

---

# Majority Element II

**Problem:** Given an integer array of size `n`, find all elements that appear more than `n / 3` times.

## Solution

Count each element's frequency using a hash table, then collect all elements whose frequency exceeds `n / 3`.

```jai
majority_element :: (nums: [] int) -> [] int {
    table: Table(int, int);
    for n : nums {
        value, newly_added := find_or_add(*table, n);
        if !newly_added {
            value.* += 1;
        } else {
            value.* = 1;
        }
    }

    n_div_3 := nums.count / 3;
    answer: [..] int;
    for value, key: table {
        if value > n_div_3 {
            array_add(*answer, key);
        }
    }

    return answer;
}
```

---

# Final Value of Variable After Performing Operations

**Problem:** A variable `X` starts at 0. Given an array of operation strings (`"++X"`, `"X++"`, `"--X"`, `"X--"`), return the final value of `X` after applying all operations.

## Solution

Iterate over the operations and increment or decrement `x` depending on whether the operation string contains `"++"` or `"--"`.

```jai
finalValueAfterOperations :: (operations: [] string) -> int {
    x := 0;
    for op : operations {
        if compare(op, "--X") == 0 || compare(op, "X--") == 0 {
            x -= 1;
        } else if compare(op, "++X") == 0 || compare(op, "X++") == 0 {
            x += 1;
        }
    }
    return x;
}
```

---

# Isomorphic Strings

**Problem:** Given two strings `s` and `t`, determine if they are isomorphic. Two strings are isomorphic if the characters in `s` can be consistently replaced to produce `t`, with no two characters mapping to the same character.

## Array Solution

Use two 256-element byte arrays to record the mapping from `s` to `t` and from `t` to `s`. If any character is mapped to a different character than previously recorded, return `false`.

```jai
is_isomorphic :: (s: string, t: string) -> bool {
    array1: [256] u8;
    array2: [256] u8;
    for i : 0..255 {
        array1[i] = 0;
        array2[i] = 0;
    }

    n := s.count - 1;
    for i : 0..n {
        if array1[s[i]] && array1[s[i]] != t[i] {
            return false;
        }
        if array2[t[i]] && array2[t[i]] != s[i] {
            return false;
        }
        array1[s[i]] = t[i];
        array2[t[i]] = s[i];
    }

    return true;
}
```

## Hash Table Solution

The same logic as the array solution, using `Table` instead of fixed-size arrays.

```jai
is_isomorphic :: (s: string, t: string) -> bool {
    table1: Table(u8, u8);
    table2: Table(u8, u8);
    n := s.count - 1;
    for i : 0..n {
        value1, success1 := table_find(*table1, s[i]);
        if success1 && value1 != t[i] {
            return false;
        }
        value2, success2 := table_find(*table2, t[i]);
        if success2 && value2 != s[i] {
            return false;
        }

        table_set(*table1, s[i], t[i]);
        table_set(*table2, t[i], s[i]);
    }
    return true;
}
```

---

# String to Integer (atoi)

**Problem:** Implement `my_atoi(s: string)` that converts a string to an integer. The algorithm should: (1) skip leading whitespace, (2) read an optional `+` or `-` sign, and (3) read digits until a non-digit character or end of string. Return 0 if no digits were read.

## Solution

```jai
my_atoi :: (s: string) -> int {
    i := 0;
    n := s.count;
    result := 0;
    sign := 1;

    // 1. Skip leading whitespace
    while i < n && is_space(s[i]) i += 1;

    // 2. Handle optional sign
    if i < n && (s[i] == #char "+" || s[i] == #char "-") {
        sign = ifx s[i] == #char "-" then -1 else 1;
        i += 1;
    }

    // 3. Convert digits
    while i < n && is_digit(s[i]) {
        digit := s[i] - #char "0";
        result = result * 10 + digit;
        i += 1;
    }

    return sign * result;
}
```

---

# Permutations

**Problem:** Given an array `nums` of distinct integers, return all possible permutations. You may return them in any order.

## Solution

Use a recursive backtracking approach. Swap each element into the current position and recurse to fill the remaining positions, then swap back to restore the array for the next iteration.

```jai
permute :: (nums: [] int) -> [][] int {
    permute_helper :: (values: *[..][] int, nums: [] int, l: int, r: int) {
        if l == r {
            array_add(values, array_copy(nums));
            return;
        }

        for i : l..r {
            nums[i], nums[l] = nums[l], nums[i];
            permute_helper(values, nums, l+1, r);
            nums[i], nums[l] = nums[l], nums[i];
        }
    }

    values: [..][] int;
    permute_helper(*values, nums, 0, nums.count-1);
    return values;
}
```

---

# Kth Lexicographical String of All N-Length Happy Strings

**Problem:** A happy string consists only of `'a'`, `'b'`, and `'c'`, and no two adjacent characters are the same. Given `n` and `k`, return the `k`th lexicographically ordered happy string of length `n`, or an empty string if fewer than `k` such strings exist.

## Solution

Use depth-first search to enumerate happy strings in lexicographical order. A counter tracks how many complete strings have been produced; when the counter reaches `k`, return that string.

```jai
get_happy_string :: (n: int, k: int) -> string {
    s := NewArray(n + 1, u8);
    i := 0;
    while i <= n {
        s[i] = 0;
        i += 1;
    }
    count := 0;
    return get_happy_string_helper(s, 0, n, k, *count);
}

get_happy_string_helper :: (s: [] u8, i: int, n: int, k: int, count: *int) -> string {
    if n == 0 {
        count.* += 1;
        if count.* == k {
            return to_string(s);
        } else {
            return "";
        }
    }

    array := u8.[#char "a", #char "b", #char "c"];
    for c : array {
        if i > 0 && c == s[i - 1] {
            continue;
        }
        s[i] = c;
        answer := get_happy_string_helper(s, i + 1, n - 1, k, count);
        if answer {
            return answer;
        }
        s[i] = 0;
    }

    return "";
}
```

---

# Next Permutation

**Problem:** Given an array of integers, rearrange it into the next lexicographically greater permutation. If no such permutation exists (the array is in descending order), rearrange to the lowest possible order (ascending).

## Solution

Find the rightmost element that is smaller than the element to its right. Swap it with the smallest element to its right that is larger than it. Then reverse the suffix after the swap position to restore ascending order.

```jai
next_permutation :: (nums: [] int) {
    i := nums.count - 2;
    while i >= 0 && nums[i] >= nums[i + 1] {
        i -= 1;
    }

    if i >= 0 {
        j := nums.count - 1;
        while j > i {
            if nums[j] > nums[i] {
                nums[i], nums[j] = nums[j], nums[i];
                break;
            }
            j -= 1;
        }
    }

    begin := i + 1;
    end := nums.count - 1;
    while begin < end {
        nums[begin], nums[end] = nums[end], nums[begin];
        begin += 1;
        end -= 1;
    }
}
```

---

# Flip Square Submatrix Vertically

**Problem:** Given an `m x n` integer matrix `grid` and integers `x`, `y`, and `k`, reverse the rows of the `k x k` submatrix whose top-left corner is at `(x, y)`. Return the updated matrix.

## Solution

Swap rows within the submatrix working inward from the outermost pair to the middle.

```jai
reverse_submatrix :: (grid: [][] int, x: int, y: int, k: int) -> [][] int {
    i := 0;
    k_div_2 := k / 2;
    while i < k_div_2 {
        j := 0;
        while j < k {
            temp := grid[x + i][y + j];
            grid[x + i][y + j] = grid[x + k - i - 1][y + j];
            grid[x + k - i - 1][y + j] = temp;
            j += 1;
        }
        i += 1;
    }
    return grid;
}
```

---

# Minimum Changes to Make Alternating Binary String

**Problem:** Given a binary string `s`, return the minimum number of character flips needed to make the string alternating (no two adjacent characters the same).

## Solution

There are only two possible alternating strings for any length: one starting with `'0'` and one starting with `'1'`. Count the mismatches against each pattern and return the smaller count.

```jai
min_operations :: (s: string) -> int {
    c: u8 = #char "0";
    value1 := 0;
    i := 0;
    while i < s.count {
        if s[i] != c {
            value1 += 1;
        }
        c ^= 1;
        i += 1;
    }

    value2 := 0;
    c = #char "1";
    i = 0;
    while i < s.count {
        if s[i] != c {
            value2 += 1;
        }
        c ^= 1;
        i += 1;
    }
    return min(value1, value2);
}
```

---

# Successful Pairs of Spells and Potions

**Problem:** Given arrays `spells` and `potions` and an integer `success`, a spell-potion pair is successful if `spell * potion >= success`. Return an array where `pairs[i]` is the number of potions that form a successful pair with `spells[i]`.

## Naive Solution

Check all spell-potion combinations with nested loops. This is O(n × m) and suitable for small inputs.

```jai
successful_pairs :: (spells: [] int, potions: [] int, success: int) -> [..] int {
    answer: [..] int;
    for spell, spell_index : spells {
        pairs := 0;
        for potion, potion_index : potions {
            if (spell * potion) >= success {
                pairs += 1;
            }
        }
        array_add(*answer, pairs);
    }
    return answer;
}
```

---

# Count Submatrices with Top-Left Element and Sum ≤ K

**Problem:** Given a 0-indexed integer matrix `grid` and an integer `k`, return the number of submatrices that include the top-left element `grid[0][0]` and have a sum less than or equal to `k`.

## Solution

Build a 2D prefix sum array. The prefix sum at `(i, j)` gives the sum of the submatrix from `(0, 0)` to `(i, j)`. Then count how many of these prefix sums are `<= k`.

```jai
count_sub_matrices :: (grid: [$M][$N] int, k: int) -> int {
    array: [M][N] int;
    array[0][0] = grid[0][0];
    for i : 1..M-1 {
        array[i][0] = array[i-1][0] + grid[i][0];
    }
    for j : 1..N-1 {
        array[0][j] = array[0][j-1] + grid[0][j];
    }

    for i : 1..M-1 {
        for j : 1..N-1 {
            array[i][j] = array[i-1][j] + array[i][j-1] + grid[i][j] - array[i-1][j-1];
        }
    }

    count := 0;
    for i : 0..M-1 {
        for j : 0..N-1 {
            if array[i][j] <= k {
                count += 1;
            }
        }
    }
    return count;
}
```

--- End of file: documents/09_leetcode_basics_arrays_strings.md ---

--- Start of file: documents/10_leetcode_dynamic_programming_and_greedy.md ---
This page demonstrates how to solve common LeetCode problems in Jai that involve dynamic programming, greedy algorithms, and optimization over sequences.

Each section describes:
* The problem statement
* A Jai solution, with an explanation of the approach

---

# Maximum Subarray

**Problem:** Given an integer array `nums`, find the contiguous subarray with the largest sum and return its sum.

## Solution

Use Kadane's algorithm. Build a DP array where `dp[i]` holds the maximum subarray sum ending at index `i`. For each element, the best we can do is either start a new subarray or extend the previous best. Scan the DP array for the overall maximum.

```jai
max_sub_array :: (nums: [] int) -> int {
    array := NewArray(nums.count, int);
    array[0] = nums[0];
    for i : 1..nums.count-1 {
        array[i] = max(nums[i], nums[i] + array[i-1]);
    }

    answer := array[0];
    for i : 1..nums.count-1 {
        answer = max(array[i], answer);
    }
    return answer;
}
```

---

# Best Time to Buy and Sell Stock II

**Problem:** Given an integer array `prices` where `prices[i]` is the stock price on day `i`, find the maximum profit. You may buy and sell on the same day, but you may only hold at most one share at a time.

## Solution

Greedily accumulate profit whenever the price rises. Track the current local minimum price; whenever the price drops or a local peak is reached, add the profit from the last buy and reset the minimum.

```jai
max_profit :: (prices: [] int) -> int {
    profit := 0;
    min := prices[0];
    for i : 1..prices.count-1 {
        if prices[i] < min || prices[i] < prices[i-1] {
            profit += (prices[i-1] - min);
            min = prices[i];
        }
    }

    l := prices.count - 1;
    p := prices[l] - min;
    if p > 0 {
        profit += p;
    }

    return profit;
}
```

---

# House Robber

**Problem:** You are a robber planning to rob houses along a street. Adjacent houses are connected to the same alarm, so you cannot rob two adjacent houses. Given an integer array `nums` representing the money in each house, return the maximum amount you can rob without triggering the alarm.

## Solution

Use a DP array. `dp[i]` is the maximum money robable up to house `i`. For each house, you either skip it (take `dp[i-1]`) or rob it (take `nums[i] + dp[i-2]`). The answer is the last element.

```jai
rob :: (nums: [] int) -> int {
    if nums.count == 1 {
        return nums[0];
    }

    if nums.count == 2 {
        return max(nums[0], nums[1]);
    }

    arr := NewArray(nums.count, int);
    arr[0] = nums[0];
    arr[1] = max(nums[1], nums[0]);
    for i : 2..nums.count-1 {
        value := nums[i] + arr[i-2];
        arr[i] = max(value, arr[i-1]);
    }
    return arr[arr.count-1];
}
```

---

# Climbing Stairs

**Problem:** You are climbing a staircase of `n` steps. Each time you can climb either 1 or 2 steps. Return the number of distinct ways to reach the top.

## Solution

This is equivalent to computing the `n`th Fibonacci number. Define `steps[i]` as the number of ways to reach step `i`. Each step can be reached from the step one below it or two below it, giving `steps[i] = steps[i-1] + steps[i-2]`.

```jai
climb_stairs :: (n: int) -> int {
    if n <= 2 {
        return n;
    }

    steps := NewArray(n, int);
    steps[0] = 1;
    steps[1] = 2;

    i := 2;
    while i < n {
        steps[i] = steps[i-1] + steps[i-2];
        i += 1;
    }

    return steps[n-1];
}
```

---

# Coin Change

**Problem:** Given an integer array `coins` representing coin denominations and an integer `amount`, return the fewest number of coins needed to make up `amount`. If the amount cannot be made up, return `-1`. You have an unlimited supply of each coin denomination.

## Solution

Use bottom-up DP. Initialize `dp[0] = 0` and compute `dp[i]` for each amount from 1 to `amount`. For each coin, if using that coin leads to a smaller count for the current amount, update the table.

```jai
coin_change :: (coins: [] int, amount: int) -> int {
    array := NewArray(amount+1, int);
    array[0] = 0;
    for c : coins {
        if amount < c {
            continue;
        }
        array[c] = 1;
    }

    for i : 1..amount {
        if array[i] == 1 {
            continue;
        }
        min_val := 1000000;
        for c : coins {
            sub := i - c;
            if sub <= 0 || array[sub] <= 0 {
                continue;
            }
            value := 1 + array[sub];
            min_val = ifx value < min_val then value else min_val;
        }
        if min_val != 1000000 {
            array[i] = min_val;
        } else {
            array[i] = -1;
        }
    }
    return array[amount];
}
```

---

# Coin Change II

**Problem:** Given an integer array `coins` and an integer `amount`, return the number of distinct combinations that sum to `amount`. You have an unlimited supply of each coin. The answer is guaranteed to fit in a signed 32-bit integer.

## Naive Brute Force Solution

Try every combination recursively: either include the current coin or skip it. This is exponential in time and recomputes many subproblems.

```jai
change :: (amount: int, coins: [] int) -> int {

    change_recursive :: (amount: int, coins: [] int, index: int) -> int {
        if amount < 0 {
            return 0;
        }
        if amount == 0 {
            return 1;
        }

        sum := 0;
        i := index;
        while i < coins.count {
            sum += change_recursive(amount - coins[i], coins, i);
            i += 1;
        }

        return sum;
    }

    return change_recursive(amount, coins, 0);
}
```

## Bottom-Up Dynamic Programming Solution

Use a 1D DP array. Iterate over coins in the outer loop to ensure combinations are counted without repetition. For each coin, update all amounts from `coin` to `amount`.

```jai
change :: (amount: int, coins: [] int) -> int {
    values := NewArray(amount + 1, int);
    values[0] = 1;
    for coin : coins {
        for j : coin..amount {
            values[j] += values[j - coin];
        }
    }
    return values[amount];
}
```

---

# Unique Paths

**Problem:** A robot starts at the top-left corner of an `m x n` grid and wants to reach the bottom-right corner. It can only move right or down. Return the number of distinct paths.

## Solution

Use a 2D DP grid. The first row and column each have only one path (move entirely right or entirely down). Every other cell is the sum of the paths from the cell above and the cell to the left.

Note: `M` and `N` are compile-time constants, allowing the grid to be stack-allocated.

```jai
unique_paths :: ($M: int, $N: int) -> int {
    a: [M][N] int;

    for i : 0..M-1 {
        a[i][0] = 1;
    }
    for i : 0..N-1 {
        a[0][i] = 1;
    }

    for i : 1..M-1 {
        for j : 1..N-1 {
            a[i][j] = a[i-1][j] + a[i][j-1];
        }
    }

    return a[M-1][N-1];
}
```

---

# Jump Game II

**Problem:** Given a 0-indexed integer array `nums` where `nums[i]` is the maximum jump length from index `i`, return the minimum number of jumps needed to reach the last index.

## Solution

Use a greedy approach with a sliding window. Track the current reachable window `[l, r]`. From every position in that window, find the furthest reachable index. Slide the window forward and increment the jump count.

```jai
jump :: (nums: [] int) -> int {
    res := 0;
    l := 0;
    r := 0;
    furthest := 0;

    while r < nums.count - 1 {
        for i : l..r {
            furthest = max(furthest, i + nums[i]);
        }
        l = r + 1;
        r = furthest;
        res += 1;
    }

    return res;
}
```

---

# Maximum Subarray (Nim Game Context)

See the Nim Game entry in the [Trees, Graphs, and Linked Lists](leetcode_trees_graphs.md) file for a related greedy/DP example.

---

# Missing Number

**Problem:** Given an array `nums` containing `n` distinct numbers in the range `[0, n]`, return the missing number.

## Solution

Create a boolean array of size `n + 1` and mark each value present in `nums`. The unmarked index is the missing number.

```jai
missing_number :: (nums: [] int) -> int {
    array := NewArray(nums.count + 1, bool);
    for * value : array {
        value.* = false;
    }
    for n : nums {
        array[n] = true;
    }
    for value, i : array {
        if (!value) {
            return i;
        }
    }
    return -1;
}
```

---

# Pascal's Triangle

**Problem:** Given `num_rows`, return the first `num_rows` of Pascal's triangle. Each element is the sum of the two elements directly above it. Assume `1 <= num_rows <= 300`.

## Solution

The first row is `[1]`. For each subsequent row, the boundary elements are `1` and every interior element is the sum of the two elements above it from the previous row.

```jai
generate :: (num_rows: int) -> [][] int {
    pascal_triangle: [][] int = NewArray(num_rows, ([] int));
    first := NewArray(1, int);
    first[0] = 1;
    pascal_triangle[0] = first;

    previous := 0;
    numbers := 2;
    for i : 1..num_rows - 1 {
        next_row := NewArray(numbers, int);
        next_row[0] = 1;
        next_row[numbers - 1] = 1;
        for j : 1..numbers - 2 {
            next_row[j] = pascal_triangle[previous][j-1] + pascal_triangle[previous][j];
        }
        pascal_triangle[i] = next_row;
        previous += 1;
        numbers += 1;
    }

    return pascal_triangle;
}
```

---

# Gray Code

**Problem:** Return any valid n-bit Gray code sequence — a sequence of `2^n` integers where adjacent entries differ by exactly one bit.

## Solution

Apply the formula `gray(i) = i XOR (i >> 1)` for each `i` in `[0, 2^n - 1]`. This produces the standard binary-reflected Gray code.

```jai
gray_code :: (n: int) -> [..] int {
    result: [..] int;
    totalCodes := (1 << n) - 1;
    for i: 0..totalCodes {
        grayValue := i ^ (i >> 1);
        array_add(*result, grayValue);
    }
    return result;
}
```

---

# Majority Element

**Problem:** Given an array `nums` of size `n`, return the majority element — the element appearing more than `n / 2` times. The majority element always exists.

## Sorting Solution

Sort the array. The element at the middle index is always the majority element, since it occupies more than half the array. This is O(n log n).

```jai
majority_element :: (nums: [] int) -> int {
    quicksort(nums);
    mid := nums.count / 2;
    return nums[mid];
}
```

## Hash Table Solution

Count frequencies in a hash table. Return the element with the highest count. This is O(n) time and O(n) space.

```jai
majority_element :: (nums: [] int) -> int {
    table: Table(int, int);
    for n : nums {
        table_value, added := find_or_add(*table, n);
        if added {
            table_value.* = 1;
        } else {
            table_value.* += 1;
        }
    }

    count := 0;
    element := -1;
    for value, key : table {
        if (value > count) {
            count = value;
            element = key;
        }
    }
    return element;
}
```

---

# Majority Element II

**Problem:** Given an integer array of size `n`, find all elements that appear more than `n / 3` times.

## Solution

Count frequencies with a hash table and collect all elements whose count exceeds `n / 3`.

```jai
majority_element :: (nums: [] int) -> [] int {
    table: Table(int, int);
    for n : nums {
        value, newly_added := find_or_add(*table, n);
        if !newly_added {
            value.* += 1;
        } else {
            value.* = 1;
        }
    }

    n_div_3 := nums.count / 3;
    answer: [..] int;
    for value, key: table {
        if value > n_div_3 {
            array_add(*answer, key);
        }
    }

    return answer;
}
```

---

# Count Complete Tree Nodes

**Problem:** Given the root of a complete binary tree, return the number of nodes. Run in O(n).

## Solution

Base case: a null node has 0 nodes. Otherwise, count 1 plus the recursive count of both subtrees.

```jai
count_nodes :: (root: *TreeNode) -> int {
    if !root {
        return 0;
    }
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```

---

# Partitioning Into Minimum Number of Deci-Binary Numbers

**Problem:** Given a string `n` representing a positive decimal integer, return the minimum number of positive deci-binary numbers needed to sum to `n`. A deci-binary number has only `0`s and `1`s as digits.

## Solution

The minimum number of terms equals the largest digit in `n`. A digit of value `d` needs exactly `d` deci-binary terms, each contributing one `1` in that position.

```jai
min_partitions :: (n: string) -> int {
    numbers := 0;
    i := 0;
    while i < n.count {
        d := n[i] - #char "0";
        if d > numbers {
            numbers = d;
        }
        i += 1;
    }
    return numbers;
}
```

---

# Maximum Subarray (Kadane's) — See Earlier Entry

---

# Sort Colors

**Problem:** Given an array `nums` of red (0), white (1), and blue (2) objects, sort them in-place without using the library sort.

## Solution

Count the occurrences of each color, then overwrite the array with the right number of each color in order.

```jai
sort_colors :: (nums: [] int) {
    colors: [3] int = .[0, 0, 0];
    for n : nums {
        colors[n] += 1;
    }

    index := 0;
    for i : 0..2 {
        for j : 0..(colors[i] - 1) {
            nums[index] = i;
            index += 1;
        }
    }
}
```

---

# Successful Pairs of Spells and Potions

**Problem:** Given arrays `spells` and `potions` and an integer `success`, return an array where entry `i` is the number of potions that form a successful pair with `spells[i]` (i.e., `spell * potion >= success`).

## Naive Solution

Check all combinations. This is O(n × m).

```jai
successful_pairs :: (spells: [] int, potions: [] int, success: int) -> [..] int {
    answer: [..] int;
    for spell, spell_index : spells {
        pairs := 0;
        for potion, potion_index : potions {
            if (spell * potion) >= success {
                pairs += 1;
            }
        }
        array_add(*answer, pairs);
    }
    return answer;
}
```

---

# Next Permutation

**Problem:** Given an array of integers, rearrange it into the next lexicographically greater permutation. If already at the maximum, wrap around to the ascending order.

## Solution

Find the rightmost element smaller than its successor. Swap it with the smallest element to its right that is larger than it. Reverse the suffix after the swap position to get the next permutation.

```jai
next_permutation :: (nums: [] int) {
    i := nums.count - 2;
    while i >= 0 && nums[i] >= nums[i + 1] {
        i -= 1;
    }

    if i >= 0 {
        j := nums.count - 1;
        while j > i {
            if nums[j] > nums[i] {
                nums[i], nums[j] = nums[j], nums[i];
                break;
            }
            j -= 1;
        }
    }

    begin := i + 1;
    end := nums.count - 1;
    while begin < end {
        nums[begin], nums[end] = nums[end], nums[begin];
        begin += 1;
        end -= 1;
    }
}
```

---

# Count Submatrices with Top-Left Element and Sum ≤ K

**Problem:** Given a matrix `grid` and integer `k`, return the number of submatrices anchored at the top-left corner with sum ≤ k.

## Solution

Build a 2D prefix sum array where `prefix[i][j]` is the sum of the submatrix from `(0, 0)` to `(i, j)`. Count how many prefix sums are ≤ k.

```jai
count_sub_matrices :: (grid: [$M][$N] int, k: int) -> int {
    array: [M][N] int;
    array[0][0] = grid[0][0];
    for i : 1..M-1 {
        array[i][0] = array[i-1][0] + grid[i][0];
    }
    for j : 1..N-1 {
        array[0][j] = array[0][j-1] + grid[0][j];
    }

    for i : 1..M-1 {
        for j : 1..N-1 {
            array[i][j] = array[i-1][j] + array[i][j-1] + grid[i][j] - array[i-1][j-1];
        }
    }

    count := 0;
    for i : 0..M-1 {
        for j : 0..N-1 {
            if array[i][j] <= k {
                count += 1;
            }
        }
    }
    return count;
}
```

---

# Two Sum (Hash Table)

**Problem:** Given an array `nums` and a `target`, return the indices of the two numbers that add up to `target`.

## Solution

For each element, compute its complement (`target - element`). Look the complement up in a hash table. If found, return the pair. Otherwise, store the current element and its index.

```jai
two_sum :: (nums: [] int, target: int) -> int, int {
    values: Table(int, int);
    for num, i : nums {
        difference := target - num;
        success, val := table_find(*values, difference);
        if success {
            return i, val;
        } else {
            table_set(*values, num, i);
        }
    }
    return -1, -1;
}
```

---

# Three Sum

**Problem:** Given an integer array `nums`, return all unique triplets `[nums[i], nums[j], nums[k]]` such that `i`, `j`, and `k` are distinct and their values sum to zero.

## Solution

Sort the array. For each element (fixed as the first of the triplet), use two pointers to find pairs among the remaining elements that sum to its negation. Skip duplicates to avoid repeated triplets.

```jai
three_sum :: (nums: [] int) -> [][] int {
    sort(nums);
    res: [..][] int;
    for i : 0..nums.count-1 {
        if nums[i] > 0 break;
        if i > 0 && nums[i] == nums[i - 1] continue;

        l := i + 1;
        r := nums.count - 1;
        while l < r {
            sum := nums[i] + nums[l] + nums[r];
            if sum > 0 {
                r -= 1;
            } else if sum < 0 {
                l += 1;
            } else {
                array_add(*res, int.[nums[i], nums[l], nums[r]]);
                l += 1;
                r -= 1;
                while l < r && nums[l] == nums[l - 1] {
                    l += 1;
                }
            }
        }
    }
    return res;
}
```

---

# Minimum Changes to Make Alternating Binary String

**Problem:** Given a binary string `s`, return the minimum number of flips needed to make it alternating (no two adjacent characters are equal).

## Solution

There are only two valid alternating patterns. Count mismatches against each pattern and return the smaller count.

```jai
min_operations :: (s: string) -> int {
    c: u8 = #char "0";
    value1 := 0;
    i := 0;
    while i < s.count {
        if s[i] != c {
            value1 += 1;
        }
        c ^= 1;
        i += 1;
    }

    value2 := 0;
    c = #char "1";
    i = 0;
    while i < s.count {
        if s[i] != c {
            value2 += 1;
        }
        c ^= 1;
        i += 1;
    }
    return min(value1, value2);
}
```

--- End of file: documents/10_leetcode_dynamic_programming_and_greedy.md ---

--- Start of file: documents/11_leetcode_trees_graphs_linked_lists.md ---
This page demonstrates how to solve common LeetCode problems in Jai involving binary trees, linked lists, and grid/matrix traversal.

Each section describes:
* The problem statement
* A Jai solution, with an explanation of the approach

---

# Path Sum

**Problem:** Given the root of a binary tree and an integer `target_sum`, return `true` if the tree has a root-to-leaf path whose node values sum to `target_sum`. A leaf is a node with no children.

## Solution

Recursively reduce `target_sum` by the current node's value as you descend. When a leaf is reached, check whether the remaining sum equals the leaf's value.

```jai
has_path_sum :: (root: *TreeNode, target_sum: int) -> bool {
    if !root {
        return false;
    }

    if has_path_sum(root.left, target_sum - root.val) || has_path_sum(root.right, target_sum - root.val) {
        return true;
    }

    return !root.left && !root.right && root.val == target_sum;
}
```

---

# Count Complete Tree Nodes

**Problem:** Given the root of a complete binary tree, return the number of nodes. Your algorithm must run in O(n) time.

The `TreeNode` struct is defined as:

```jai
TreeNode :: struct {
    data: int;
    left:  *TreeNode;
    right: *TreeNode;
}
```

## Solution

At the base case, return 0 for a null node. Otherwise, count the current node (1) and recursively add the counts from the left and right subtrees.

```jai
count_nodes :: (root: *TreeNode) -> int {
    if !root {
        return 0;
    }
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```

---

# Same Tree

**Problem:** Given the roots of two binary trees `p` and `q`, return `true` if they are structurally identical and all corresponding nodes have the same value.

```jai
TreeNode :: struct {
    val: int;
    left: *TreeNode;
    right: *TreeNode;
}
```

## Solution

Recursively compare nodes. Two trees are the same if the current nodes are both null, or both non-null with equal values and identical left and right subtrees.

```jai
is_same_tree :: (p: *TreeNode, q: *TreeNode) -> bool {
    if !p && !q {
        return true;
    }
    if !p {
        return false;
    }
    if !q {
        return false;
    }
    if p.val != q.val {
        return false;
    }
    return is_same_tree(p.left, q.left) && is_same_tree(p.right, q.right);
}
```

---

# Symmetric Tree

**Problem:** Given the root of a binary tree, check whether it is a mirror of itself — that is, symmetric around its center.

## Solution

A tree is symmetric if its left and right subtrees are mirror images of each other. Define a helper that compares two subtrees: one is the left child, and the other is the right child, cross-comparing their inner and outer children at each level.

```jai
is_symmetric :: (root: *TreeNode) -> bool {
    subtrees :: (left: *TreeNode, right: *TreeNode) -> bool {
        if !left && !right {
            return true;
        }
        if !left  { return false; }
        if !right { return false; }
        if left.val != right.val {
            return false;
        }
        return subtrees(left.left, right.right) && subtrees(left.right, right.left);
    }

    if !root {
        return true;
    }
    return subtrees(root.left, root.right);
}
```

---

# Maximum Depth of Binary Tree

**Problem:** Given the root of a binary tree, return its maximum depth — the number of nodes along the longest path from the root to the farthest leaf.

```jai
TreeNode :: struct {
    val: int;
    left: *TreeNode;
    right: *TreeNode;
}
```

## Solution

Recursively find the depth of the left and right subtrees. The depth of the current node is `1` plus the greater of the two subtree depths. An empty tree has depth 0.

```jai
max_depth :: (root: *TreeNode) -> int {
    if !root {
        return 0;
    }

    left  := max_depth(root.left);
    right := max_depth(root.right);
    maximum := ifx left > right then left else right;
    return 1 + maximum;
}
```

---

# Validate Binary Search Tree

**Problem:** Given the root of a binary tree, determine if it is a valid binary search tree (BST). A valid BST requires that every node in the left subtree has a key strictly less than the node's key, and every node in the right subtree has a key strictly greater.

## Solution

Recursively validate each node against an allowed range `[minimum, maximum)`. Narrow the range as you descend: going left tightens the upper bound, going right tightens the lower bound.

```jai
TreeNode :: struct {
    val: int;
    left: *TreeNode;
    right: *TreeNode;
}

isValidBSTHelper :: (root: *TreeNode, minimum: int, maximum: int) -> bool {
    if !root {
        return true;
    }

    val := root.val;
    if val <= minimum || val >= maximum {
        return false;
    }

    if !isValidBSTHelper(root.left, minimum, min(maximum, val)) {
        return false;
    }

    if !isValidBSTHelper(root.right, max(minimum, val), maximum) {
        return false;
    }

    return true;
}

isValidBST :: (root: *TreeNode) -> bool {
    return isValidBSTHelper(root, S64_MIN, S64_MAX);
}
```

---

# Sum of Root-to-Leaf Binary Numbers

**Problem:** Each node in a binary tree holds a value of `0` or `1`. Each root-to-leaf path represents a binary number (most significant bit first). Return the sum of all such numbers.

```jai
TreeNode :: struct {
    val: int;
    left: *TreeNode;
    right: *TreeNode;
}
```

## Solution

Carry the current path value as an accumulator. At each node, left-shift the accumulator by 1 and OR in the node's value. When a leaf is reached, add the accumulated value to the running sum.

```jai
sum_root_to_leaf :: (root: *TreeNode) -> int {
    if !root {
        return 0;
    }
    sum := 0;
    sum_tree(root, *sum, 0);
    return sum;
}

sum_tree :: (root: *TreeNode, sum: *int, number: int) {
    if !root {
        return;
    }
    number <<= 1;
    number |= root.val;
    if !root.left && !root.right {
        sum.* += number;
        return;
    }
    sum_tree(root.left, sum, number);
    sum_tree(root.right, sum, number);
}
```

---

# Find Kth Bit in Nth Binary String

**Problem:** A sequence of binary strings is defined as:
- `S1 = "0"`
- `Si = S(i-1) + "1" + reverse(invert(S(i-1)))` for `i > 1`

Given `n` and `k`, return the `k`th bit (1-indexed) of `Sn`.

## Solution

Iteratively build `Sn` by concatenating the previous string, a `"1"`, and the reversed-and-inverted previous string. Return the character at index `k - 1`.

```jai
invert :: (s: string) -> string {
    for i : 0..s.count-1 {
        s[i] ^= 1;
    }
    return s;
}

reverse :: (s: string) -> string {
    i := 0;
    j := s.count - 1;
    while i < j {
        s[i], s[j] = s[j], s[i];
        i += 1;
        j -= 1;
    }
    return s;
}

findKthBit :: (n: int, k: int) -> u8 {
    s: string = "0";
    i := 1;
    while i < n {
        s = join(s, "1", reverse(invert(s)));
        i += 1;
    }
    k -= 1;
    return s[k];
}
```

---

# Linked List Cycle

**Problem:** Given the head of a linked list, determine if the linked list contains a cycle — a node that can be reached again by repeatedly following `next` pointers.

## Solution

Maintain a hash table of visited node pointers. If the current node is already in the table, a cycle exists. If the end of the list is reached without a match, there is no cycle.

```jai
has_cycle :: (head: *Node) -> bool {
    table: Table(*Node, void);
    while head {
        if table_contains(*table, head) {
            return true;
        }
        nothing: void;
        table_add(*table, head, nothing);
        head = head.next;
    }
    return false;
}
```

---

# Two Sum

**Problem:** Given an array of integers `nums` and an integer `target`, return the indices of the two numbers that add up to `target`. Each input has exactly one solution, and you may not use the same element twice.

## Naive Solution

Use two nested loops to examine every pair. This runs in O(n²) time.

```jai
two_sum :: (nums: [] int, value: int) -> int, int {
    N := nums.count - 1;
    for i : 0..N {
        for j : (i + 1)..N {
            sum := nums[i] + nums[j];
            if sum == value {
                return i, j;
            }
        }
    }
    return -1, -1;
}
```

## Optimized Hash Table Solution

For each element, compute the difference between `target` and the element. Look up that difference in a hash table. If found, the pair has been identified. Otherwise, store the element and its index. This runs in O(n) time.

```jai
two_sum :: (nums: [] int, target: int) -> int, int {
    values: Table(int, int);
    for num, i : nums {
        difference := target - num;
        success, val := table_find(*values, difference);
        if success {
            return i, val;
        } else {
            table_set(*values, num, i);
        }
    }
    return -1, -1;
}
```

---

# Three Sum

**Problem:** Given an integer array `nums`, return all unique triplets `[nums[i], nums[j], nums[k]]` such that `i`, `j`, and `k` are distinct and `nums[i] + nums[j] + nums[k] == 0`.

## Solution

Sort the array, then fix one element at a time and use two pointers to find pairs that sum to the negation of the fixed element. Skip duplicate values to avoid returning duplicate triplets.

```jai
three_sum :: (nums: [] int) -> [][] int {
    sort(nums);
    res: [..][] int;
    for i : 0..nums.count-1 {
        if nums[i] > 0 break;
        if i > 0 && nums[i] == nums[i - 1] continue;

        l := i + 1;
        r := nums.count - 1;
        while l < r {
            sum := nums[i] + nums[l] + nums[r];
            if sum > 0 {
                r -= 1;
            } else if sum < 0 {
                l += 1;
            } else {
                array_add(*res, int.[nums[i], nums[l], nums[r]]);
                l += 1;
                r -= 1;
                while l < r && nums[l] == nums[l - 1] {
                    l += 1;
                }
            }
        }
    }
    return res;
}
```

---

# Four Divisors

**Problem:** Given an integer array `nums`, return the sum of divisors of the integers that have exactly four divisors. Return 0 if no such integer exists.

## Solution

For each number, count its divisors from `2` up to `sqrt(num)`. Stop early if the count exceeds 4. Return the sum of divisors only when the count is exactly 4.

```jai
has_four_divisors :: (num: int) -> bool, int {
    max := num;
    count := 2;
    i := count;
    sum := 1 + num;
    while i < max && count <= 4 {
        if (num % i) == 0 {
            max = num / i;
            sum += i;
            sum += max;
            if max == i {
                count += 1;
            } else {
                count += 2;
            }
        }
        i += 1;
    }
    return count == 4, sum;
}

sum_four_divisors :: (nums: [] int) -> int {
    count := 0;
    for num : nums {
        success, sum := has_four_divisors(num);
        if success {
            count += sum;
        }
    }
    return count;
}
```

---

# Jump Game II

**Problem:** Given a 0-indexed integer array `nums`, where `nums[i]` is the maximum jump length from index `i`, return the minimum number of jumps needed to reach the last index.

## Solution

Use a greedy approach. Track the current reachable range `[l, r]`. At each step, scan that range to find how far the next jump can reach (`furthest`). Advance `l` and `r` to the next range and increment the jump count.

```jai
jump :: (nums: [] int) -> int {
    res := 0;
    l := 0;
    r := 0;
    furthest := 0;

    while r < nums.count - 1 {
        for i : l..r {
            furthest = max(furthest, i + nums[i]);
        }
        l = r + 1;
        r = furthest;
        res += 1;
    }

    return res;
}
```

---

# Unique Paths

**Problem:** A robot starts at the top-left corner of an `m x n` grid and wants to reach the bottom-right corner. It can only move right or down. Return the number of distinct paths.

## Solution

Use dynamic programming. The number of paths to any cell `(i, j)` is the sum of paths from `(i-1, j)` and `(i, j-1)`. Initialize all cells in the first row and column to 1 since there is only one way to reach them.

Note: `M` and `N` are compile-time constants (`$M`, `$N`), allowing the grid to be stack-allocated.

```jai
unique_paths :: ($M: int, $N: int) -> int {
    a: [M][N] int;

    for i : 0..M-1 {
        a[i][0] = 1;
    }
    for i : 0..N-1 {
        a[0][i] = 1;
    }

    for i : 1..M-1 {
        for j : 1..N-1 {
            a[i][j] = a[i-1][j] + a[i][j-1];
        }
    }

    return a[M-1][N-1];
}
```

---

# Word Search

**Problem:** Given an `m x n` character grid `board` and a string `word`, return `true` if the word can be found by traversing sequentially adjacent cells (horizontally or vertically) without reusing any cell.

## Solution

Use depth-first search from each cell. When visiting a cell, temporarily mark it as visited by zeroing it out. If the search path fails, restore the original value before backtracking.

```jai
exist :: (board: [][] u8, word: string) -> bool {

    exist_helper :: (board: [][] u8, i: int, j: int, word: string) -> bool {
        m := board.count - 1;
        n := board[0].count - 1;
        if i < 0 || i >= m { return false; }
        if j < 0 || j >= n { return false; }
        if board[i][j] == 0 || board[i][j] != word[0] { return false; }

        if word.count == 1 {
            return true;
        }

        value := board[i][j];
        board[i][j] = 0;
        advance(*word, 1);

        if exist_helper(board, i - 1, j, word) { return true; }
        if exist_helper(board, i + 1, j, word) { return true; }
        if exist_helper(board, i, j - 1, word) { return true; }
        if exist_helper(board, i, j + 1, word) { return true; }

        board[i][j] = value;
        return false;
    }

    m := board.count - 1;
    n := board[0].count - 1;
    for i : 0..m {
        for j : 0..n {
            if exist_helper(board, i, j, word) {
                return true;
            }
        }
    }

    return false;
}
```

---

# Container With Most Water

**Problem:** Given an integer array `height` of length `n` representing vertical line heights, find two lines that form a container holding the most water. Return the maximum amount of water.

## Naive Solution

Check every pair of lines. This is O(n²) and suitable only for small inputs.

```jai
max_area :: (height: [] int) -> int {
    max_value := 0;
    i := 0;
    while i < height.count {
        j := i + 1;
        while j < height.count {
            min_value := ifx height[i] < height[j] then height[i] else height[j];
            area := min_value * (j - i);
            max_value = ifx area > max_value then area else max_value;
            j += 1;
        }
        i += 1;
    }
    return max_value;
}
```

## Optimized Two-Pointer Solution

Use two pointers starting at each end of the array. At each step, compute the area and advance the pointer at the shorter line, since moving the taller line can only reduce the width without improving the height bound. This is O(n).

```jai
max_area :: (height: [] int) -> int {
    max_value := 0;
    i := 0;
    j := height.count - 1;
    while i <= j {
        area := j - i;
        if height[i] < height[j] {
            area *= height[i];
            i += 1;
        } else {
            area *= height[j];
            j -= 1;
        }
        max_value = ifx area > max_value then area else max_value;
    }
    return max_value;
}
```

---

# Trapping Rain Water

**Problem:** Given `n` non-negative integers representing an elevation map where each bar has width 1, compute how much water can be trapped after raining.

## Solution

Use two pointers starting at each end. Track `left_max` and `right_max` as the maximum heights seen from each side. Move the pointer at the lower maximum inward, adding the trapped water above it (`max - height[current]`).

```jai
trap :: (height: [] int) -> int {
    if !height return 0;

    l := 0;
    r := height.count - 1;
    left_max := height[l];
    right_max := height[r];
    answer := 0;

    while l < r {
        if left_max < right_max {
            l += 1;
            left_max = max(left_max, height[l]);
            answer += left_max - height[l];
        } else {
            r -= 1;
            right_max = max(right_max, height[r]);
            answer += right_max - height[r];
        }
    }

    return answer;
}
```

---

# Nim Game

**Problem:** Two players alternate removing 1 to 3 stones from a heap. The player who removes the last stone wins. Given `n` stones, return `true` if the first player can win with optimal play.

## Naive Recursive Solution

Simulate all possible game states with minimax. This is exponential in time and only suitable as a reference.

```jai
can_win_nim :: (n: int) -> bool {
    if n <= 1 {
        return n == 1;
    }
    return !can_win_nim(n - 1) || !can_win_nim(n - 2) || !can_win_nim(n - 3);
}
```

## Optimized O(1) Solution

A position with a multiple of 4 stones is always a losing position for the player whose turn it is. Any other count is a winning position.

```jai
can_win_nim :: (n: int) -> bool {
    return (n % 4) != 0;
}
```

---

# Bitwise AND of Numbers Range

**Problem:** Given two integers `left` and `right` representing the range `[left, right]`, return the bitwise AND of all numbers in the range (inclusive).

## Solution

For each bit that is set in both `left` and `right`, check if that bit is set in any number in the range. If so, that bit must be cleared from the result.

```jai
range_bitwise_and :: (left: int, right: int) -> int {
    added := right & left;
    bit_mask := 1;
    for i : 0..31 {
        if added & bit_mask {
            right ^= bit_mask;
            if right >= left {
                added ^= bit_mask;
            }
            right ^= bit_mask;
        }
        bit_mask <<= 1;
    }
    return added;
}
```

---

# Smallest Number with All Set Bits

**Problem:** Given a positive integer `n`, return the smallest integer `x >= n` whose binary representation consists entirely of set bits (all 1s).

## Solution

Start with `1` and repeatedly left-shift and OR with 1 to extend the sequence of set bits. Stop when the value is greater than or equal to `n`.

```jai
smallest_number :: (n: int) -> int {
    sum := 1;
    while sum < n {
        sum <<= 1;
        sum |= 1;
    }
    return sum;
}
```

---

# Complement of Base 10 Integer

**Problem:** The complement of an integer flips all its bits. Given a non-negative integer `n`, return its complement.

## Solution

Find the position of the most significant bit. Construct a mask with all bits below that position set, then XOR the mask with the NOT of `n` to isolate the relevant bits.

```jai
bitwise_complement :: (n: int) -> int {
    if n == 0 return 1;

    bit := 0x80000000;
    while (n & bit) == 0 {
        bit >>= 1;
        bit |= 0x80000000;
    }

    return (~n) & (~bit);
}
```

---

# Concatenation of Consecutive Binary Numbers

**Problem:** Given an integer `n`, return the decimal value of the binary string formed by concatenating the binary representations of `1` through `n` in order, modulo `10^9 + 7`.

## Solution

For each number `value`, shift the current result left by the number of bits in `value` and OR in `value`. Compute the shift amount by tracking when `value` crosses a power of two.

```jai
concatenated_binary :: (n: int) -> int {
    value := 1;
    shift := 1;
    answer := 0;
    while value <= n {
        answer <<= shift;
        answer |= value;
        if answer >= 1000000007 {
            answer %= 1000000007;
        }
        value += 1;
        if (value & (value - 1)) == 0 {
            shift += 1;
        }
    }
    return answer;
}
```

---

# Number of Steps to Reduce a Binary Number to One

**Problem:** Given the binary representation of an integer as a string `s`, return the number of steps to reduce it to 1. If the current number is even, divide by 2. If odd, add 1.

## Solution

Process the binary string from right to left, simulating the carry from addition. Track the number of steps required per bit depending on its value and any carry.

```jai
num_steps :: (s: string) -> int {
    num := 0;
    carry := 0;
    i := s.count - 1;
    while i >= 1 {
        if s[i] != #char "0" {
            carry += 1;
        }
        if carry & 1 {
            num += 2;
        } else {
            num += 1;
        }
        if (carry & 1) {
            carry += 1;
        }
        carry >>= 1;
        i -= 1;
    }
    carry += 1;
    while carry > 1 {
        if (carry & 1) {
            num += 2;
        } else {
            num += 1;
        }
        if (carry & 1) {
            carry += 1;
        }
        carry >>= 1;
    }
    return num;
}
```

---

# Number of Digit One

**Problem:** Given an integer `n`, count the total number of times the digit `1` appears in all non-negative integers from `0` to `n`.

## Solution

For each decimal place value `i` (1, 10, 100, ...), calculate how many times `1` appears in that digit position across all numbers from `0` to `n` using quotient-remainder analysis.

```jai
count_digit_one :: (n: int) -> int {
    if n <= 0 {
        return 0;
    }

    count := 0;
    i := 1;

    while i <= n {
        divider  := i * 10;
        quotient := n / divider;
        remainder := n % divider;

        count += quotient * i;

        if remainder >= i * 2 - 1 {
            count += i;
        } else if remainder >= i {
            count += remainder - i + 1;
        }

        i *= 10;
    }

    return count;
}
```

--- End of file: documents/11_leetcode_trees_graphs_linked_lists.md ---

--- Start of file: documents/12_linked_list_and_binary_trees.md ---
# Linked List

A linked list is a data structure in which elements are not stored such that elements can be randomly accessed in a contiguous memory block, but rather each node in a linked list points to the next. A linked list is a collection of nodes that allows for efficient insertion or removal of elemnts from any position in a sequence during iteration.

In Jai, we can define a linked list using the following syntax:
```jai
Node :: struct {
    data: int;
    next: *Node;
}
```

And we can create a simple printing function for a linked list like this:
```jai
print_linked_list :: (node: *Node) {
    print("[");
    while node {
        print("%, ", node.data);
        node = node.next;
    }
    print("]\n");
}
```

## Create a Node
This function instantiates a node using the allocator.
```jai
create_node :: (value: int) -> *Node {
    node := New(Node);
    node.data = value;
    node.next = null;
    return node;
}
```

## Appending Front
Unlike adding to the back, appending to the front is a quick four lines of code. 
```jai
append_front :: (head: **Node, data: int) {
    new_node := New(Node);
    new_node.data = data;
    new_node.next = head.*;
    head.* = new_node;
}
```

## Appending Back
This is a function to append an element to the end of a linked list. We initialize the element, traverse to the end, and append to the end. 
```jai
// create a node at the end of the list.
append :: (head: *Node, data: int) {
    assert(head != null);
    // initialize new node to append.
    new_node := New(Node);
    new_node.data = data;
    new_node.next = null;

    // traverse to the end of linked list.
    while(head.next) {
        head = head.next;
    }

    // append to the end of linked list.
    head.next = new_node;
}
```

## Insert Sorted

This function inserts a new element into an already sorted linked list.

```jai
insert_sorted :: (head: **Node, value: int) {
    new_node := create_node(value);

    // Empty list or insert at beginning
    if !head.* || head.*.data >= value {
        new_node.next = head.*;
        head.* = new_node;
        return;
    }

    // Find insertion point
    current := head.*;
    while current.next && current.next.data < value {
        current = current.next;
    }

    // Insert after current
    new_node.next = current.next;
    current.next = new_node;
}
```

## Removing Elements
A function to remove all elements of a particular value from a linked list.
```jai
remove_value :: (head: *Node, value: int) {
    if !head return;
    previous := head;
    current  := previous.next;
    while current {
        if current.data == value {
            previous.next = current.next;
        } else {
            previous = previous.next;
        }
        current = current.next;
    }
}
```
## Search Value
This function traverses all the linked list nodes and attempts to find the node with the parameter value. Returns the node if it could find it, else return null.
```jai
search :: (head: *Node, value: int) -> *Node {
    current := head;
    while current {
        if current.data == value {
            return current;
        }
        current = current.next;
    }
    return null;
}
```

## Find Index
This function finds the index of the linked list node with the value parameter. Returns -1 if no such node exists.
```jai
// Returns position (0-indexed), or -1 if not found
find_index :: (head: *Node, value: int) -> int {
    current := head;
    index := 0;

    while current {
        if current.data == value {
            return index;
        }
        current = current.next;
        index += 1;
    }

    return -1;
}
```

## Get Value at Index
These functions take as input an index position and returns the node and value found at that position.
```jai
get_at :: (head: *Node, position: int) -> *Node {
    current := head;
    index := 0;

    while current && index < position {
        current = current.next;
        index += 1;
    }

    return current;
}

// Get value at position (returns success flag and value)
get_value_at :: (head: *Node, position: int) -> found: bool, value: int {
    node := get_at(head, position);
    if !node return false, 0;
    return true, node.data;
}
```

## Length of Linked List

This function traverses the linked list in linear time O(n) and calculates the number of nodes in the list.

```jai
length :: (head: *Node) -> int {
    count := 0;
    current := head;

    while current {
        count += 1;
        current = current.next;
    }

    return count;
}
```

## Reverse Linked List
This function reverses the given linked list such that the beginning of the list becomes the end and the end becomes the beginning.
```jai
reverse :: (head: **Node) {
    previous: *Node = null;
    current := head.*;

    while current {
        next := current.next;
        current.next = previous;
        previous = current;
        current = next;
    }

    head.* = previous;
}
```

# Binary Search Tree
A binary tree is a hierarchical data structure where each node has at most two children: a left child and a right child. In Jai, we can implement this elegantly using structs and pointers.

```jai
Tree :: struct {
    data: int;
    left:  *Tree;
    right: *Tree;
}
```

## Creating a New Node
This function allocates a new tree node on the heap and initializes it with the given value.
```jai
create_node :: (value: int) -> *Tree {
    node := New(Tree);
    node.data = value;
    node.left = null;
    node.right = null;
    return node;
}
```

## Inserting into a Binary Search Tree
For a binary search tree (BST), we maintain the property that all values in the left subtree are less than the node's value, and all values in the right subtree are greater.
```jai
insert :: (root: **Tree, value: int) {
    // If tree is empty, create the root
    if !root.* {
        root.* = create_node(value);
        return;
    }
    
    // Recursively find the correct position
    if value < root.*.data {
        insert(*root.*.left, value);
    } else if value > root.*.data {
        insert(*root.*.right, value);
    }
    // If value equals data, we don't insert duplicates
}
```

## In Order Traversal

This traversal visits nodes in sorted order for a BST.

```jai
traverse_inorder :: (root: *Tree) {
    if !root return;
    
    traverse_inorder(root.left);
    print("% ", root.data);
    traverse_inorder(root.right);
}
```

## Pre-Order Traversal
This traversal visits nodes starting from the root, doing the left side, and then the right side of the Binary Search Tree.
```jai
traverse_preorder :: (root: *Tree) {
    if !root return;
    
    print("% ", root.data);
    traverse_preorder(root.left);
    traverse_preorder(root.right);
}
```

## Post-Order Traversal
This traversal visits nodes starting from the left side, the right side, and then the root of the Binary Search Tree.
```jai
traverse_postorder :: (root: *Tree) {
    if !root return;
    
    traverse_postorder(root.left);
    traverse_postorder(root.right);
    print("% ", root.data);
}
```

## Find a Value in the Binary Search Tree
This function searches for whether a node with a particular value appears in the binary search tree. It returns `null` if a value is not found. This performs a search in logarithmic time O(log n).

```jai
search :: (root: *Tree, value: int) -> *Tree {
    // Base cases: empty tree or value found
    if !root || root.data == value {
        return root;
    }
    
    // Value is smaller, search left subtree
    if value < root.data {
        return search(root.left, value);
    }
    
    // Value is larger, search right subtree
    return search(root.right, value);
}
```

## Finding the Minimum of the Binary Search Tree

This function finds the tree node with the smallest value of a binary search tree.
```jai
find_minimum :: (root: *Tree) -> *Tree {
    if !root return null;
    
    // Keep going left until we can't anymore
    while root.left {
        root = root.left;
    }
    return root;
}
```

## Finding the Maximum of the Binary Search Tree
This function finds the tree node with the largest value of a binary search tree.

```jai
find_maximum :: (root: *Tree) -> *Tree {
    if !root return null;
    
    // Keep going right until we can't anymore
    while root.right {
        root = root.right;
    }
    return root;
}
```

## Remove element from Binary Search Tree
Deletion is the most complex operation. We need to handle three cases:
* Node has no children (leaf node)
* Node has one child
* Node has two children
```jai
delete :: (root: **Tree, value: int) {
    if !root.* return;
    
    // Find the node to delete
    if value < root.*.data {
        delete(*root.*.left, value);
    } else if value > root.*.data {
        delete(*root.*.right, value);
    } else {
        // Found the node to delete
        node := root.*;
        
        // Case 1: No children (leaf node)
        if !node.left && !node.right {
            free(node);
            root.* = null;
        }
        // Case 2: Only right child
        else if !node.left {
            root.* = node.right;
            free(node);
        }
        // Case 2: Only left child
        else if !node.right {
            root.* = node.left;
            free(node);
        }
        // Case 3: Two children
        else {
            // Find the minimum value in right subtree (in-order successor)
            successor := find_minimum(node.right);
            
            // Copy the successor's value to this node
            node.data = successor.data;
            
            // Delete the successor
            delete(*node.right, successor.data);
        }
    }
}
```

## Counting Binary Search Tree Nodes

This function traverses the tree, recursively counting the number of nodes in the left and right sub-trees.
```jai
count_nodes :: (root: *Tree) -> int {
    if !root return 0;
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```

## Finding Binary Search Tree Height

This function finds the height of a tree. The height of a tree is the length of the path from the root to the deepest node in the tree.

```jai
height :: (root: *Tree) -> int {
    if !root return 0;
    
    left_height := height(root.left);
    right_height := height(root.right);
    
    return 1 + max(left_height, right_height);
}

max :: (a: int, b: int) -> int {
    if a > b return a;
    return b;
}
```

## Free the Tree

This function frees up the entire binary search tree. We recursively traverse the left and right subtrees of the root, freeing up the subtrees. At the end, we free up the root. It is best to set a fixed lifetime for the tree, allocate the tree in a temporary storage arena allocator, and free up the entire tree using `reset_temporary_storage();`. This function could be useful if the program logic is such that lifetimes of pointers is hard to track.

```jai
free_tree :: (root: *Tree) {
    if !root return;
    
    // Free children first (post-order)
    free_tree(root.left);
    free_tree(root.right);
    
    // Then free this node
    free(root);
}
```

# Trie

A Trie (pronounced "try", from retrieval) is a tree where each edge represents a character. Words are formed by following a path from the root to a node marked as a word-end. It is ideal for prefix searches, autocomplete, and dictionary lookups.
Structure

Each node holds an array of child pointers (one per possible character) and an is_end flag marking whether that position completes a valid word.

## Structure

Each node holds an array of child pointers (one per possible character) and an is_end flag marking whether that position completes a valid word.

```
// Words: "cat", "car", "card", "care", "bat"
//
//        root
//       /    \
//      c      b
//      |      |
//      a      a
//     / \     |
//    t*  r*   t*
//        |
//       / \
//      d*  e*
//
// * = is_end marker (valid word terminates here)
```

## When to use a Trie vs Hash Map
Use a Trie when you need prefix queries ("find all words starting with 'pre'"), autocomplete, or spell checking. A hash map is simpler and faster for pure exact-match lookups but cannot answer prefix queries efficiently.

## Node Definition
The Trie is defined as set of children `*Trie_Node` and a `is_end` boolean value to mark whether that position completes a valid word.

```jai
ALPHABET_SIZE :: 26;  // a-z only for simplicity

Trie_Node :: struct {
    children : [ALPHABET_SIZE]*Trie_Node;
    is_end   : bool;
}

Trie :: struct {
    root : *Trie_Node;
}
```

## Initialize and Destroy

This function initializes and frees the Trie Nodes.

```jai
trie_init :: (t: *Trie) {
    t.root = New(Trie_Node);  // zeroed: all children null, is_end false
}

node_free :: (node: *Trie_Node) {
    if !node  return;
    for node.children  node_free(it);  // recurse into children
    free(node);
}

trie_destroy :: (t: *Trie) {
    node_free(t.root);
    t.root = null;
}
```

## Contains

This function determines whether a particular word exists in the Trie.

```jai
trie_contains :: (t: *Trie, word: string) -> bool {
    node := t.root;

    for ch: word {
        index := cast(int) ch - cast(int) #char "a";
        if !node.children[index]  return false; // path doesn't exist
        node = node.children[index];
    }

    return node.is_end;  // only true if word actually ends here
}
```

## Starts With (Prefix Search)

This function determines whether a particular prefix exists within the trie.

```jai
trie_starts_with :: (t: *Trie, prefix: string) -> bool {
    node := t.root;

    for ch: prefix {
        index := cast(int) ch - cast(int) #char "a";
        if !node.children[index]  return false;
        node = node.children[index];
    }

    return true;  // reached end of prefix — it exists as a path
}
```

## Collect All Words with Prefix

This function finds all words containing a particular prefix.

```jai
collect_words :: (node: *Trie_Node, prefix: string, results: *[..]string) {
    if !node  return;
    if node.is_end  array_add(results, copy_string(prefix));

    for i: 0..ALPHABET_SIZE-1 {
        if node.children[i] {
            ch := cast(u8) (cast(int) #char "a" + i);
            collect_words(node.children[i], join(prefix, string.{1, *ch}), results);
        }
    }
}

trie_words_with_prefix :: (t: *Trie, prefix: string) -> [..]string {
    results : [..]string;
    node := t.root;

    for ch: prefix {
        index := cast(int) ch - cast(int) #char "a";
        if !node.children[index]  return results; // no match
        node = node.children[index];
    }

    collect_words(node, prefix, *results);
    return results;
}
```

## Example Usage

This example program demonstrates the functionality of the Trie.

```jai
main :: () {
    t : Trie;
    trie_init(*t);
    defer trie_destroy(*t);  // auto-cleanup when main returns

    trie_insert(*t, "cat");
    trie_insert(*t, "car");
    trie_insert(*t, "card");
    trie_insert(*t, "care");
    trie_insert(*t, "bat");

    print("contains 'car':  %\n", trie_contains(*t, "car"));    // true
    print("contains 'ca':   %\n", trie_contains(*t, "ca"));     // false
    print("starts_with 'ca':%\n", trie_starts_with(*t, "ca")); // true

    matches := trie_words_with_prefix(*t, "ca");
    for matches  print("  %\n", it); // cat, car, card, care
}

#import "Basic";
#import "String";
```

--- End of file: documents/12_linked_list_and_binary_trees.md ---

--- Start of file: documents/13_graph_algorithms.md ---
Graphs are one of the most important and unifying structures in computer science. They model relationships — and most real-world and computational problems are fundamentally about relationships.

A graph consists of:
* Vertices (nodes) -> entities
* Edges -> relationships between entities

This article seeks to document how to write different graph algorithms in Jai.

# Graph Definition
There are many valid definitions of a graph. In the next few examples, we will represent a graph as an adjacency list.
```jai
// ============================================================
//  GRAPH DATA STRUCTURE: Adjacency List
//
//  - num_vertices: total vertex count
//  - adj: a dynamic array where adj[u] is itself a dynamic
//    array containing all neighbors of vertex u.
// ============================================================

Graph :: struct {
    num_vertices: int;
    adj: [..] [..] int;   // dynamic array of dynamic arrays
}

// Create a graph with n vertices and no edges.
make_graph :: (n: int) -> Graph {
    g: Graph;
    g.num_vertices = n;
    // Add n empty neighbor lists, one per vertex.
    for 0..n-1 {
        empty: [..] int;
        array_add(*g.adj, empty);
    }
    return g;
}

// Add an undirected edge between u and v.
add_edge :: (g: *Graph, u: int, v: int) {
    array_add(*g.adj[u], v);
    array_add(*g.adj[v], u);
}

// Add a directed edge from u to v.
add_directed_edge :: (g: *Graph, u: int, v: int) {
    array_add(*g.adj[u], v);
}

// Free all memory used by the graph.
free_graph :: (g: *Graph) {
    for i: 0..g.num_vertices-1 {
        array_free(g.adj[i]);
    }
    array_free(g.adj);
}

// Helper: remove the first occurrence of val from a dynamic array.
// Uses swap-with-last then decrement count (O(1), unordered remove).
remove_from_list :: (list: *[..] int, val: int) {
    for i: 0..list.count-1 {
        if list.data[i] == val {
            list.data[i] = list.data[list.count - 1];
            list.count  -= 1;
            return;
        }
    }
}

// Remove an undirected edge between u and v.
// Used internally by Fleury's Algorithm.
remove_edge :: (g: *Graph, u: int, v: int) {
    remove_from_list(*g.adj[u], v);
    remove_from_list(*g.adj[v], u);
}
```

## Breath First Search
Breath First Search explores all vertices reachable from 'start' level by level. Uses a queue (simulated with a dynamic array and a head index). Time: O(V + E).

```jai
bfs :: (g: *Graph, start: int) {
    // visited[u] is true if vertex u has been seen.
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);

    // Use a dynamic array as a queue; 'head' is the front index.
    queue: [..] int;
    defer array_free(queue);

    visited[start] = true;
    array_add(*queue, start);

    head := 0;
    while head < queue.count {
        u := queue[head];
        head += 1;
        print("BFS visited: %\n", u);

        for v: g.adj[u] {
            if !visited[v] {
                visited[v] = true;
                array_add(*queue, v);
            }
        }
    }
}
```
## Depth First Search
Depth First Search explores as far as possible along each branch before backtracking. This depth first search is implemented recursively. Time: O(V + E).
```jai
dfs_helper :: (g: *Graph, u: int, visited: [] bool) {
    visited[u] = true;
    print("DFS visited: %\n", u);

    for v: g.adj[u] {
        if !visited[v] {
            dfs_helper(g, v, visited);
        }
    }
}

dfs :: (g: *Graph, start: int) {
    // [] bool is an array view — passing by value still lets
    // us modify elements because it contains a pointer to the
    // underlying data.
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);
    dfs_helper(g, start, visited);
}
```
## Flood Fill
Given a vertex color array, recolors the entire connected component of 'start' that shares old_color with new_color.
```jai
flood_fill :: (g: *Graph, colors: [] int, start: int, new_color: int) {
    old_color := colors[start];
    if old_color == new_color  return;  // nothing to do

    queue: [..] int;
    defer array_free(queue);

    colors[start] = new_color;
    array_add(*queue, start);

    head := 0;
    while head < queue.count {
        u := queue[head];
        head += 1;

        for v: g.adj[u] {
            if colors[v] == old_color {
                colors[v] = new_color;
                array_add(*queue, v);
            }
        }
    }
}
```
## Check for Bipartite Graph
A graph is bipartite if its vertices can be split into two sets such that every edge connects a vertex in one set to a vertex in the other. Equivalently, a graph is bipartite if and only if it contains no odd-length cycle. Uses BFS 2-coloring. Handles disconnected graphs. Returns true if bipartite, false otherwise. Time: O(V + E).
```jai
is_bipartite :: (g: *Graph) -> bool {
    // colors[u] = -1 means unvisited
    // colors[u] =  0 or 1 is the BFS 2-coloring
    colors := NewArray(g.num_vertices, int);
    defer array_free(colors);
    for i: 0..g.num_vertices-1  colors[i] = -1;

    // Try BFS from every unvisited vertex (handles disconnected graphs).
    for start: 0..g.num_vertices-1 {
        if colors[start] != -1  continue;

        queue: [..] int;
        defer array_free(queue);

        colors[start] = 0;
        array_add(*queue, start);

        head := 0;
        while head < queue.count {
            u := queue[head];
            head += 1;

            for v: g.adj[u] {
                if colors[v] == -1 {
                    // Assign the opposite color to the neighbor.
                    colors[v] = 1 - colors[u];
                    array_add(*queue, v);
                } else if colors[v] == colors[u] {
                    // Same color on both ends of an edge — not bipartite.
                    return false;
                }
            }
        }
    }
    return true;
}
```

## Clone Graph
Creates a deep copy of the graph. The new graph has its own independent adjacency lists with the same edges. Time: O(V + E).
```jai
clone_graph :: (g: *Graph) -> Graph {
    new_g := make_graph(g.num_vertices);
    for u: 0..g.num_vertices-1 {
        for v: g.adj[u] {
            array_add(*new_g.adj[u], v);
        }
    }
    return new_g;
}
```

## Cycle Detection
Use depth first search to find if a cycle exists in an undirected graph. Mark the nodes if they have been visited. If the graph node has already been visited, there is a cycle and return true. Time Complexity: O(V + E).

```jai
has_cycle_helper :: (g: *Graph, u: int, parent: int, visited: [] bool) -> bool {
    visited[u] = true;

    for v: g.adj[u] {
        if !visited[v] {
            if has_cycle_helper(g, v, u, visited)  return true;
        } else if v != parent {
            // Found a visited vertex that isn't where we came from.
            return true;
        }
    }
    return false;
}

has_cycle :: (g: *Graph) -> bool {
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);

    for u: 0..g.num_vertices-1 {
        if !visited[u] {
            if has_cycle_helper(g, u, -1, visited)  return true;
        }
    }
    return false;
}
```

## Fleury's Algorithm - Eulerian Path
Fleury's Algorithm finds Eulerian Paths and Circuits by greedily walking edges, always preferring edges that are NOT bridges, where a bridge is an edge whose removal disconnects the graph. We detect bridges by counting reachable vertices before and after a temporary edge removal.

Fleury's Algorithm functions consumes the graph, so pass a clone if you need the original preserved. Complexity Time: O(E * (V + E)) due to bridge checks inside the walk.
```jai
// Count vertices reachable from 'start' via BFS.
count_reachable :: (g: *Graph, start: int) -> int {
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);

    queue: [..] int;
    defer array_free(queue);

    visited[start] = true;
    array_add(*queue, start);
    count := 0;

    head := 0;
    while head < queue.count {
        u := queue[head];
        head += 1;
        count += 1;
        for v: g.adj[u] {
            if !visited[v] {
                visited[v] = true;
                array_add(*queue, v);
            }
        }
    }
    return count;
}

// Returns true if removing edge (u,v) would disconnect the graph.
is_bridge :: (g: *Graph, u: int, v: int) -> bool {
    before := count_reachable(g, u);
    remove_edge(g, u, v);
    after := count_reachable(g, u);
    add_edge(g, u, v);     // restore the edge
    return after < before;
}

// Find any vertex with at least one edge remaining.
find_vertex_with_edges :: (g: *Graph) -> int {
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count > 0  return u;
    }
    return -1;
}

// Count vertices in the graph that have odd degree.
count_odd_degree_vertices :: (g: *Graph) -> int {
    count := 0;
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count % 2 == 1  count += 1;
    }
    return count;
}

// Internal core of Fleury's: walk edges from 'start', building a path.
fleury_walk :: (g: *Graph, start: int) -> [..] int {
    path: [..] int;
    array_add(*path, start);

    current := start;
    while g.adj[current].count > 0 {
        chosen := -1;

        // Prefer a non-bridge edge. Only take a bridge if it's the only option.
        for v: g.adj[current] {
            if g.adj[current].count == 1 || !is_bridge(g, current, v) {
                chosen = v;
                break;
            }
        }

        // Fallback: if all edges are bridges, take the first one.
        if chosen == -1  chosen = g.adj[current][0];

        array_add(*path, chosen);
        remove_edge(g, current, chosen);
        current = chosen;
    }

    return path;
}

fleury_eulerian_path :: (g: *Graph) {
    odd_count := 0;
    start     := -1;

    for u: 0..g.num_vertices-1 {
        if g.adj[u].count % 2 == 1 {
            odd_count += 1;
            start = u;  // will end up as one of the two odd-degree vertices
        }
    }

    if odd_count != 0 && odd_count != 2 {
        print("No Eulerian Path exists (need 0 or 2 odd-degree vertices, found %).\n",
              odd_count);
        return;
    }

    // If 0 odd-degree vertices, any vertex with edges is fine.
    if odd_count == 0  start = find_vertex_with_edges(g);

    if start == -1 {
        print("Graph has no edges.\n");
        return;
    }

    path := fleury_walk(g, start);
    defer array_free(path);

    print("Eulerian Path: ");
    for i: 0..path.count-1 {
        print("%", path[i]);
        if i < path.count - 1  print(" -> ");
    }
    print("\n");
}
```
## Fleury's Algorithm - Eulerian Circuit
An Eulerian Circuit is an Eulerian Path that starts and ends at the same vertex.

Conditions for existence (undirected graph):
* The graph must be connected (ignoring isolated vertices).
* Every vertex must have even degree.

Time: O(E * (V + E)) due to bridge checks inside the walk.

```jai
// Count vertices reachable from 'start' via BFS.
count_reachable :: (g: *Graph, start: int) -> int {
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);

    queue: [..] int;
    defer array_free(queue);

    visited[start] = true;
    array_add(*queue, start);
    count := 0;

    head := 0;
    while head < queue.count {
        u := queue[head];
        head += 1;
        count += 1;
        for v: g.adj[u] {
            if !visited[v] {
                visited[v] = true;
                array_add(*queue, v);
            }
        }
    }
    return count;
}

// Returns true if removing edge (u,v) would disconnect the graph.
is_bridge :: (g: *Graph, u: int, v: int) -> bool {
    before := count_reachable(g, u);
    remove_edge(g, u, v);
    after := count_reachable(g, u);
    add_edge(g, u, v);     // restore the edge
    return after < before;
}

// Find any vertex with at least one edge remaining.
find_vertex_with_edges :: (g: *Graph) -> int {
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count > 0  return u;
    }
    return -1;
}

// Count vertices in the graph that have odd degree.
count_odd_degree_vertices :: (g: *Graph) -> int {
    count := 0;
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count % 2 == 1  count += 1;
    }
    return count;
}

// Internal core of Fleury's: walk edges from 'start', building a path.
fleury_walk :: (g: *Graph, start: int) -> [..] int {
    path: [..] int;
    array_add(*path, start);

    current := start;
    while g.adj[current].count > 0 {
        chosen := -1;

        // Prefer a non-bridge edge. Only take a bridge if it's the only option.
        for v: g.adj[current] {
            if g.adj[current].count == 1 || !is_bridge(g, current, v) {
                chosen = v;
                break;
            }
        }

        // Fallback: if all edges are bridges, take the first one.
        if chosen == -1  chosen = g.adj[current][0];

        array_add(*path, chosen);
        remove_edge(g, current, chosen);
        current = chosen;
    }

    return path;
}

fleury_eulerian_circuit :: (g: *Graph) {
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count % 2 == 1 {
            print("No Eulerian Circuit exists (vertex % has odd degree).\n", u);
            return;
        }
    }

    start := find_vertex_with_edges(g);
    if start == -1 {
        print("Graph has no edges.\n");
        return;
    }

    path := fleury_walk(g, start);
    defer array_free(path);

    print("Eulerian Circuit: ");
    for i: 0..path.count-1 {
        print("%", path[i]);
        if i < path.count - 1  print(" -> ");
    }
    print("\n");
}
```


# Prim's Algorithm
A graph is a collection of nodes (vertices) connected by edges. Each edge can have a weight — a cost associated with traversing that connection. Think of cities connected by roads, where the weight represents distance or travel time.
A spanning tree of a connected graph is a subset of edges that:

* Connects all vertices (spans the entire graph)
* Contains no cycles (it's a tree)
* Uses exactly V - 1 edges for a graph with V vertices

A Minimum Spanning Tree (MST) is a spanning tree where the total sum of edge weights is as small as possible. Real-world applications include:
* Network design (laying cable, fiber, or pipes at minimum cost)
* Cluster analysis in machine learning
* Approximation algorithms for the Traveling Salesman Problem
* Circuit board routing
* Image segmentation

## Algorithm Procedure

Prim's Algorithm builds the MST by growing it one edge at a time from a starting vertex. At each step, it greedily picks the cheapest edge that connects a vertex already in the MST to a vertex not yet in the MST. Here is the algorithm step by step:

* Start with any vertex. Mark it as "in the MST."
* Look at all edges crossing the boundary between "in MST" vertices and "not in MST" vertices.
* Pick the edge with the minimum weight.
* Add that edge and its new vertex to the MST.
* Repeat steps 2–4 until all vertices are in the MST.

**Time Complexity:** O(V^2) with an adjacency matrix, or O(E log V) with a priority queue.

```jai
#import "Basic";

// Represents the result of Prim's algorithm.
// Each entry in 'parent' says which vertex is the parent of vertex i in the MST.
// Each entry in 'key' stores the minimum edge weight to connect vertex i.
MST_Result :: struct {
    parent: [] int;   // parent[i] = parent of vertex i in the MST
    key:    [] float; // key[i]    = weight of edge connecting i to its parent
    total_cost: float;
}

// Find the vertex with the minimum key value that is not yet in the MST.
min_key_vertex :: (key: [] float, in_mst: [] bool) -> int {
    min_val := 999999.0;
    min_idx := -1;

    for i: 0..key.count - 1 {
        if !in_mst[i] && key[i] < min_val {
            min_val = key[i];
            min_idx = i;
        }
    }

    return min_idx;
}

// Prim's Algorithm.
// graph: a V x V adjacency matrix where graph[i][j] is the edge weight between i and j.
//        A value of 0 means no edge.
// V:     number of vertices
prim_mst :: (graph: [][] float, V: int) -> MST_Result {
    // key[i] = minimum weight to connect vertex i to the growing MST
    key := NewArray(V, float);

    // parent[i] = which MST vertex connects to vertex i
    parent := NewArray(V, int);

    // in_mst[i] = true if vertex i is already part of the MST
    in_mst := NewArray(V, bool);

    // Initialize: all keys are infinity, no vertex is in MST
    for i: 0..V - 1 {
        key[i]    = 999999.0; // represents "infinity"
        parent[i] = -1;
        in_mst[i] = false;
    }

    // Start from vertex 0. Its key is 0 so it gets picked first.
    key[0] = 0.0;

    // We need to pick V vertices total
    for step: 0..V - 1 {
        // Pick the vertex not yet in MST with the smallest key
        u := min_key_vertex(key, in_mst);
        in_mst[u] = true;

        // Update keys of adjacent vertices of u
        for v: 0..V - 1 {
            edge_weight := graph[u][v];

            // Only consider: edges that exist (non-zero),
            //                vertices not yet in MST,
            //                and only if this edge is cheaper than what we know
            if edge_weight > 0 && !in_mst[v] && edge_weight < key[v] {
                key[v]    = edge_weight;
                parent[v] = u;
            }
        }
    }

    // Compute total MST cost (skip vertex 0, it has no parent)
    total := 0.0;
    for i: 1..V - 1 {
        total += key[i];
    }

    result: MST_Result;
    result.parent     = parent;
    result.key        = key;
    result.total_cost = total;
    return result;
}

// Print the MST edges and total cost.
print_mst :: (result: MST_Result) {
    print("Edge      Weight\n");
    print("------------------\n");
    for i: 1..result.parent.count - 1 {
        print("% -- %    %\n", result.parent[i], i, result.key[i]);
    }
    print("\nTotal MST cost: %\n", result.total_cost);
}

main :: () {
    // Example graph with 5 vertices.
    // This is an adjacency matrix: graph[i][j] = weight of edge between i and j.
    // 0 means no edge between those two vertices.
    //
    //       0    1    2    3    4
    //   0 [ 0,   2,   0,   6,   0 ]
    //   1 [ 2,   0,   3,   8,   5 ]
    //   2 [ 0,   3,   0,   0,   7 ]
    //   3 [ 6,   8,   0,   0,   9 ]
    //   4 [ 0,   5,   7,   9,   0 ]

    V :: 5;

    // Build the adjacency matrix as a dynamic 2D array
    graph: [V][V] float;

    graph[0][1] = 2;  graph[1][0] = 2;
    graph[0][3] = 6;  graph[3][0] = 6;
    graph[1][2] = 3;  graph[2][1] = 3;
    graph[1][3] = 8;  graph[3][1] = 8;
    graph[1][4] = 5;  graph[4][1] = 5;
    graph[2][4] = 7;  graph[4][2] = 7;
    graph[3][4] = 9;  graph[4][3] = 9;

    // Convert to slice-of-slices for the function
    rows: [V] [] float;
    for i: 0..V-1 {
        rows[i].data  = *graph[i][0];
        rows[i].count = V;
    }

    graph_view: [] [] float;
    graph_view.data  = *rows[0];
    graph_view.count = V;

    result := prim_mst(graph_view, V);
    print_mst(result);
}

```
## Expected Output
```
Edge      Weight
------------------
0 -- 1    2
1 -- 2    3
0 -- 3    6
1 -- 4    5

Total MST cost: 16
```
## Step-by-Step Walkthrough

Using the graph from the example above:

```
    (2)       (3)
0 ------- 1 ------- 2
|         |         |
(6)      (8)       (7)
|         |         |
3 ------- 4 --------+
    (9)       (5)
            1 -- 4
```

| Step | Vertex Added | Via Edge | Edge Weight | Notes |
|---|---|---|---|---|
| 1 | 0 | (start) | 0 | Starting vertex |
| 2 | 1 | 0 → 1 | 2 | Cheapest edge from {0} |
| 3 | 2 | 1 → 2 | 3 | Cheapest edge from {0,1} |
| 4 | 4 | 1 → 4 | 5 | Cheaper than 2→4 (7) |
| 5 | 3 | 0 → 3 | 6 | Cheaper than 1→3 (8) or 4→3 (9) |

**Total Cost: 2 + 3 + 5 + 6 = 16**

---

## Implementation Notes

**Why the adjacency matrix?**
The adjacency matrix is the simplest representation to start with. For a graph with `V` vertices, it's a `V × V` grid where `matrix[i][j]` stores the weight of the edge from `i` to `j`. Checking whether an edge exists is O(1). The downside is it uses O(V²) memory even for sparse graphs.

**The `min_key_vertex` function**
In the simple O(V²) implementation, finding the next vertex to add requires scanning all vertices to find the one with the smallest key that isn't yet in the MST. This linear scan is why the overall algorithm is O(V²). For large sparse graphs, replacing this with a **priority queue (min-heap)** brings the complexity down to O(E log V).

**The `key` array**
Each `key[v]` represents the weight of the cheapest edge we've found so far that could connect vertex `v` to the MST. When we add a new vertex `u` to the MST, we check all of `u`'s neighbors — if we find a cheaper connection to any of them, we update their `key` and record `u` as their `parent`.

**Why does this produce a correct MST?**
Prim's algorithm is an instance of the **greedy** algorithm strategy. At each step it picks the globally cheapest edge crossing the MST boundary. It can be proven correct via the **Cut Property**: for any cut of the graph (a partition of vertices into two sets), the minimum weight edge crossing that cut must belong to some MST.




# Kruskal's Algorithm

Kruskal’s Algorithm is a greedy algorithm used to find a Minimum Spanning Tree (MST) of a connected, weighted, undirected graph. It was developed by Joseph Kruskal in 1956.

Given a graph with weighted edges where all vertices are connected, it finds a subset of edges that:
* connects all vertices
* has no cycles
* Has the minimum possible total edge weight

This subset is called a Minimum Spanning Tree.

## Algorithm Procedure
* Sort all edges in increasing order of weight.
* Start with an empty graph (no edges).
* Go through the sorted edges one by one:
* If adding the edge does not create a cycle, add it.
* If it does create a cycle → skip it.
* Stop when you have V − 1 edges (where V = number of vertices).

```jai
#import "Basic";

Edge :: struct {
    src    : int;
    dst    : int;
    weight : int;
}

// Union-Find (Disjoint Set Union) data structure.
// 'parent' and 'rank' are parallel dynamic arrays indexed by node ID.
UnionFind :: struct {
    parent : [..] int;
    rank   : [..] int;
}

init_union_find :: (uf: *UnionFind, n: int) {
    for i : 0..n-1 {
        array_add(*uf.parent, i);  // each node is its own parent
        array_add(*uf.rank, 0);
    }
}

// Walk up the parent chain until we reach the root.
// Path compression: flatten the tree so every visited node
// points directly to the root on future calls.
find :: (uf: *UnionFind, x: int) -> int {
    if uf.parent[x] != x {
        uf.parent[x] = find(uf, uf.parent[x]);
    }
    return uf.parent[x];
}

// Union by rank: attach the smaller tree under the larger tree's root.
// Returns false if both nodes share the same root (would form a cycle).
union_find :: (uf: *UnionFind, a: int, b: int) -> bool {
    root_a := find(uf, a);
    root_b := find(uf, b);

    if root_a == root_b return false;  // already connected, skip

    if uf.rank[root_a] < uf.rank[root_b] {
        uf.parent[root_a] = root_b;
    } else if uf.rank[root_a] > uf.rank[root_b] {
        uf.parent[root_b] = root_a;
    } else {
        uf.parent[root_b] = root_a;
        uf.rank[root_a] += 1;
    }
    return true;
}

bubble_sort :: (array:[] $T, $comparison: (T, T) -> bool) {

    sorted := false;

    while !sorted {
        i := 0;
        j := 1;
        sorted = true;
        while j < array.count {
            if comparison(array[j], array[i]) {
                array[j], array[i] = array[i], array[j];
                sorted = false;
            }
            i += 1;
            j += 1;
        }
    }
}

kruskal :: (num_nodes: int, edges: [] Edge) -> [..] Edge {
    // Sort all edges from cheapest to most expensive.
    bubble_sort(edges, (a: Edge, b: Edge) -> bool {
        return a.weight < b.weight;
    });

    uf: UnionFind;
    init_union_find(*uf, num_nodes);

    mst: [..] Edge;

    for edge : edges {
        // An MST for N nodes needs exactly N-1 edges.
        if mst.count == num_nodes - 1  break;

        // Only add the edge if its endpoints are in different components.
        // union() returns false when they are already connected (cycle).
        if union_find(*uf, edge.src, edge.dst) {
            array_add(*mst, edge);
        }
    }

    return mst;
}

main :: () {
    // Graph with 5 nodes (0..4) and 7 edges:
    //
    //   0 --1-- 1
    //   |  \ /  |
    //   4   X   2
    //   |  / \  |
    //   3 --9-- 4
    //
    edges := Edge.[
        .{0, 1, 1},
        .{0, 3, 4},
        .{1, 2, 2},
        .{1, 3, 5},
        .{1, 4, 8},
        .{2, 4, 3},
        .{3, 4, 9},
    ];

    mst := kruskal(5, edges);

    total_weight := 0;
    print("Minimum Spanning Tree edges:\n");
    for edge : mst {
        print("  % -- % : weight %\n", edge.src, edge.dst, edge.weight);
        total_weight += edge.weight;
    }
    print("Total MST weight: %\n", total_weight);
}
```

## Edge Representation
Each `Edge` is a flat struct holding `src`, `dst`, and `weight`. Because Jai structs are plain value types (no hidden overhead), the array of edges is a contiguous block of memory — cache-friendly for the sort that follows.

## Union-Find (Disjoint Set Union)
The algorithm needs to answer one question efficiently: *"Are these two nodes already connected?"* Union-Find answers this in near-O(1) time with two optimizations:

* **Path Compression** (`find`): When traversing the parent chain to find the root, every node along the path is rewired to point directly at the root. Future lookups on those nodes become a single-step O(1) dereference.

* **Union by Rank** (`union`): Each set tracks a `rank` (an approximate height of its tree). When merging two sets, the shallower tree is attached under the deeper tree's root, keeping the overall tree height from ballooning.

Together these give an amortized inverse-Ackermann time complexity, which is effectively constant for any practical input size.

## Sorting
Edges are sorted by weight ascending using a polymorphic `bubble_sort`.

## Greedy Selection Loop
The main loop iterates through the sorted edge list and for each edge calls `union()`. If the two endpoints were already in the same connected component, `union()` returns `false` and the edge is skipped — adding it would create a cycle. If they were in different components, `union()` merges the components and returns `true`, and the edge is appended to the MST. The loop terminates early once exactly `N - 1` edges have been collected, which is the exact count a spanning tree on `N` nodes requires.

## Expected Output for the Sample Graph
```
Minimum Spanning Tree edges:
  0 -- 1 : weight 1
  1 -- 2 : weight 2
  2 -- 4 : weight 3
  0 -- 3 : weight 4
Total MST weight: 10
```

# Dijkstra's Algorithm

Dijkstra's algorithm finds the shortest path from a starting node to all other nodes in a weighted graph where all edge weights are non-negative. It works by maintaining a priority queue of nodes to visit, always processing the node with the smallest known distance first.
The time complexity is O((V + E) log V) with a binary heap priority queue, where V is the number of vertices and E is the number of edges.

## Graph Representation

We represent the graph as an adjacency list: each node stores a dynamic array of its neighbors and the weights of the edges connecting them. This is memory-efficient for sparse graphs and fast for iterating neighbors.

```jai
// An edge connects 'to' with a given 'weight'
Edge :: struct {
    to:     int;
    weight: int;
}

// A node holds all its outgoing edges
Node :: struct {
    edges: [..] Edge;
}

// The graph is just an array of nodes
Graph :: struct {
    nodes: [..] Node;
}

// Create a graph with 'num_nodes' nodes
graph_create :: (num_nodes: int) -> Graph {
    g: Graph;
    for 0..num_nodes - 1 {
        node: Node;
        array_add(*g.nodes, node);
    }
    return g;
}

// Add a directed edge from 'from' to 'to' with the given weight
graph_add_edge :: (g: *Graph, from: int, to: int, weight: int) {
    edge := Edge.{to = to, weight = weight};
    array_add(*g.nodes[from].edges, edge);
}
```

## Priority Queue
Dijkstra's algorithm needs a priority queue to efficiently retrieve the unvisited node with the smallest tentative distance. We implement a simple min-heap using a dynamic array.
```jai
// An entry in the priority queue: which node and its current best distance
PQ_Entry :: struct {
    node:     int;
    distance: int;
}

// Priority queue (min-heap) — smallest distance at index 0
PQ :: struct {
    data: [..] PQ_Entry;
}

// Swap two entries
pq_swap :: (pq: *PQ, a: int, b: int) {
    pq.data[a], pq.data[b] = pq.data[b], pq.data[a];
}

// Sift an entry up to restore heap order
pq_sift_up :: (pq: *PQ, i: int) {
    while i > 0 {
        parent := (i - 1) / 2;
        if pq.data[i].distance < pq.data[parent].distance {
            pq_swap(pq, i, parent);
            i = parent;
        } else {
            break;
        }
    }
}

// Sift an entry down to restore heap order
pq_sift_down :: (pq: *PQ, i: int) {
    n := pq.data.count;
    while true {
        smallest := i;
        left  := 2 * i + 1;
        right := 2 * i + 2;

        if left < n && pq.data[left].distance < pq.data[smallest].distance {
            smallest = left;
        }
        if right < n && pq.data[right].distance < pq.data[smallest].distance {
            smallest = right;
        }
        if smallest == i  break;

        pq_swap(pq, i, smallest);
        i = smallest;
    }
}

// Push a new entry onto the heap
pq_push :: (pq: *PQ, node: int, dist: int) {
    array_add(*pq.data, .{node = node, distance = dist});
    pq_sift_up(pq, pq.data.count - 1);
}

// Pop the minimum-distance entry off the heap
pq_pop :: (pq: *PQ) -> PQ_Entry {
    top := pq.data[0];
    last := pq.data.count - 1;
    pq.data[0] = pq.data[last];
    pq.data.count -= 1;  // shrink without freeing memory
    if pq.data.count > 0  pq_sift_down(pq, 0);
    return top;
}
```

## Dijkstra Procedure Implementation
This function returns the array of shortest distances from 'start' to every node. Unreachable nodes have distance S64_MAX (treated as infinity).
```jai

dijkstra :: (g: *Graph, start: int) -> [] int {

    INF :: 0x7FFF_FFFF;   // large sentinel value for "infinity"
    n := g.nodes.count;

    // dist[i] = best known distance from start to node i
    dist := NewArray(n, int);
    for i : 0..n - 1  dist[i] = INF;
    dist[start] = 0;

    // visited[i] = true once node i's shortest distance is finalised
    visited := NewArray(n, bool);
    for i : 0..n - 1  visited[i] = false;

    // Initialise the priority queue with the starting node
    pq: PQ;
    pq_push(*pq, start, 0);

    while pq.data.count > 0 {
        // Always process the node with the smallest current distance
        entry := pq_pop(*pq);
        u := entry.node;

        // Skip if we already found the best path to u
        if visited[u]  continue;
        visited[u] = true;

        // Relax all outgoing edges from u
        for edge : g.nodes[u].edges {
            v := edge.to;
            new_dist := dist[u] + edge.weight;

            if new_dist < dist[v] {
                dist[v] = new_dist;
                pq_push(*pq, v, new_dist);
            }
        }
    }

    return dist;
}
```

## Example Usage
Below is a complete `main()` that builds a small weighted graph, runs Dijkstra from node 0, and prints the results.
```jai
main :: () {

    //  Graph layout:
    //
    //       2       3
    //  0 -------> 1 -------> 3
    //  |          |          ^
    //  |  6       | 1        | 1
    //  +------->  2 ---------+

    g := graph_create(4);  // 4 nodes: 0, 1, 2, 3

    graph_add_edge(*g, 0, 1, 2);  // 0 -> 1, cost 2
    graph_add_edge(*g, 0, 2, 6);  // 0 -> 2, cost 6
    graph_add_edge(*g, 1, 2, 1);  // 1 -> 2, cost 1
    graph_add_edge(*g, 1, 3, 3);  // 1 -> 3, cost 3
    graph_add_edge(*g, 2, 3, 1);  // 2 -> 3, cost 1

    dist := dijkstra(*g, 0);

    print("Shortest distances from node 0:\n");
    for i : 0..dist.count - 1 {
        print("  Node % -> %\n", i, dist[i]);
    }
    // Expected output:
    //   Node 0 -> 0
    //   Node 1 -> 2
    //   Node 2 -> 3   (via 0->1->2, cost 2+1=3, not 0->2 cost 6)
    //   Node 3 -> 4   (via 0->1->2->3, cost 2+1+1=4)
}
```

Let's trace through what happens when we call dijkstra(*g, 0):
* Start: dist = [0, INF, INF, INF]. Push (node=0, dist=0) onto the heap.
* Pop (0, 0). Mark node 0 visited. Relax edges: dist[1] = 2, dist[2] = 6. Push both.
* Pop (1, 2). Mark node 1 visited. Relax: dist[2] = min(6, 2+1) = 3. dist[3] = 5. Push updated entries.
* Pop (2, 3). Mark node 2 visited. Relax: dist[3] = min(5, 3+1) = 4. Push (3, 4).
* Pop (3, 4). Mark node 3 visited. No outgoing edges. Done.
* Final distances: [0, 2, 3, 4].

# Bellman Ford Algorithm
Bellman-Ford finds the shortest path from a single source vertex to all other vertices in a weighted graph. Unlike Dijkstra's algorithm, it handles negative edge weights correctly. It works by repeatedly "relaxing" every edge — checking if going through that edge gives a shorter path than what's currently known.
The algorithm runs in O(V * E) time, where V is the number of vertices and E is the number of edges.
It also detects negative-weight cycles: if after V-1 relaxation passes you can still relax an edge, a negative cycle exists.
```jai
#import "Basic";

// Represents a directed edge from 'src' to 'dst' with a given weight.
Edge :: struct {
    src    : int;
    dst    : int;
    weight : int;
}

// Returns the shortest distances from 'source' to all vertices.
// Returns an empty array if a negative cycle is detected.
bellman_ford :: (num_vertices: int, edges: []Edge, source: int) -> [..]int, bool {
    INF :: 1_000_000_000;

    // Step 1: Initialize all distances to infinity, source to 0.
    dist: [..]int;
    for 0..num_vertices-1  array_add(*dist, INF);
    dist[source] = 0;

    // Step 2: Relax all edges (num_vertices - 1) times.
    for pass: 1..num_vertices-1 {
        for edge: edges {
            if dist[edge.src] != INF && dist[edge.src] + edge.weight < dist[edge.dst] {
                dist[edge.dst] = dist[edge.src] + edge.weight;
            }
        }
    }

    // Step 3: Check for negative-weight cycles.
    // If we can still relax an edge, a negative cycle exists.
    for edge: edges {
        if dist[edge.src] != INF && dist[edge.src] + edge.weight < dist[edge.dst] {
            print("Negative cycle detected!\n");
            empty: [..]int;
            return empty, false;
        }
    }

    return dist, true;
}

main :: () {
    // Graph with 5 vertices (0..4)
    edges: [..]Edge;
    array_add(*edges, .{src=0, dst=1, weight= 6});
    array_add(*edges, .{src=0, dst=2, weight= 7});
    array_add(*edges, .{src=1, dst=3, weight= 5});
    array_add(*edges, .{src=2, dst=3, weight=-3});
    array_add(*edges, .{src=3, dst=4, weight= 9});

    dist, ok := bellman_ford(5, edges, source=0);

    if ok {
        for i: 0..dist.count-1 {
            print("Distance from 0 to %: %\n", i, dist[i]);
        }
    }
}
```

## Expected Output
```
Distance from 0 to 0: 0
Distance from 0 to 1: 6
Distance from 0 to 2: 7
Distance from 0 to 3: 4
Distance from 0 to 4: 13
```
## Implementation Notes
* This implementation uses `INF :: 1_000_000_000` because adding to a constant such as `S64_MAX` would overflow. A large sentinel value like one billion works cleanly for typical graph problems.
* The `INF` guard (`dist[edge.src] != INF`). Without this check, an unreachable vertex (still at INF) could produce integer overflow when you compute `INF + weight`. This guard ensures we only try to relax edges from vertices we've actually reached.
* Relaxation loop runs V-1 times. The longest possible shortest path without a cycle visits at most V-1 edges. So after V-1 passes, all shortest paths are guaranteed to be found — if no negative cycle exists.
* Negative cycle detection. The final loop is a V-th pass. Any edge that can still be relaxed after V-1 rounds must be part of a negative cycle (because a path through it would need to loop around indefinitely to keep decreasing).

# Graph Coloring Algorithm
Graph coloring assigns colors to each vertex in a graph such that no two adjacent vertices share the same color. This has practical applications in compiler register allocation, scheduling problems, and map coloring.
This implementation uses a greedy graph coloring algorithm with an adjacency list represented as a dynamic array of dynamic arrays. Each vertex has a list of neighbors it is connected to.

```jai
#import "Basic";

// The graph is represented as an adjacency list.
// adjacency_list[i] is a dynamic array of ints listing
// all vertices that vertex i is connected to.
Graph :: struct {
    num_vertices    : int;
    adjacency_list  : [..] [..] int;  // array of dynamic arrays
}

// Add an undirected edge between vertex u and vertex v.
add_edge :: (g: *Graph, u: int, v: int) {
    array_add(*g.adjacency_list[u], v);
    array_add(*g.adjacency_list[v], u);
}

// Initialize a graph with a given number of vertices.
make_graph :: (num_vertices: int) -> Graph {
    g : Graph;
    g.num_vertices = num_vertices;

    // Reserve one neighbor-list slot per vertex
    for i: 0..num_vertices - 1 {
        neighbor_list : [..] int;
        array_add(*g.adjacency_list, neighbor_list);
    }
    return g;
}

// Greedy graph coloring algorithm.
// Returns a dynamic array where result[i] is the color assigned to vertex i.
// Colors are integers starting from 0.
graph_color :: (g: *Graph) -> [..] int {
    num_vertices := g.num_vertices;

    // Initialize every vertex's color to -1 (uncolored)
    colors : [..] int;
    for i: 0..num_vertices - 1 {
        array_add(*colors, -1);
    }

    // Color the first vertex with color 0
    colors[0] = 0;

    // Assign colors to the remaining vertices one by one
    for vertex: 1..num_vertices - 1 {

        // Track which colors are already used by this vertex's neighbors.
        // neighbor_has_color[c] = true means a neighbor is using color c.
        neighbor_has_color : [..] bool;
        for c: 0..num_vertices - 1 {
            array_add(*neighbor_has_color, false);
        }

        // Mark colors used by all neighbors of this vertex
        for neighbor: g.adjacency_list[vertex] {
            neighbor_color := colors[neighbor];
            if neighbor_color != -1 {
                neighbor_has_color[neighbor_color] = true;
            }
        }

        // Assign the smallest color not used by any neighbor
        chosen_color := 0;
        while chosen_color < num_vertices && neighbor_has_color[chosen_color] {
            chosen_color += 1;
        }
        colors[vertex] = chosen_color;

        array_free(neighbor_has_color);
    }

    return colors;
}

// Print the graph's adjacency list for debugging
print_graph :: (g: *Graph) {
    print("Graph adjacency list:\n");
    for vertex: 0..g.num_vertices - 1 {
        print("  Vertex %: ", vertex);
        for neighbor: g.adjacency_list[vertex] {
            print("% ", neighbor);
        }
        print("\n");
    }
}

// Print the coloring result
print_coloring :: (colors: [..] int) {
    print("Vertex coloring:\n");
    for color, vertex: colors {
        print("  Vertex % -> Color %\n", vertex, color);
    }
}

// Count the total number of distinct colors used
count_colors :: (colors: [..] int) -> int {
    max_color := -1;
    for color: colors {
        if color > max_color  max_color = color;
    }
    return max_color + 1;
}

main :: () {
    // Build a simple example graph:
    //
    //   0 --- 1
    //   |   / |
    //   |  /  |
    //   | /   |
    //   2 --- 3
    //
    // This is a cycle of 4 nodes with a diagonal (0-1-2-3-0 + edge 1-2).
    // It requires 3 colors because of the triangle formed by 0, 1, 2.

    g := make_graph(4);
    add_edge(*g, 0, 1);
    add_edge(*g, 0, 2);
    add_edge(*g, 1, 2);
    add_edge(*g, 1, 3);
    add_edge(*g, 2, 3);

    print_graph(*g);
    print("\n");

    colors := graph_color(*g);
    print_coloring(colors);

    total := count_colors(colors);
    print("\nTotal colors used: %\n", total);

    // Clean up
    array_free(colors);
    for i: 0..g.num_vertices - 1 {
        array_free(g.adjacency_list[i]);
    }
    array_free(g.adjacency_list);
}
```

## Expected Output

```
Graph adjacency list:
  Vertex 0: 1 2
  Vertex 1: 0 2 3
  Vertex 2: 0 1 3
  Vertex 3: 1 2

Vertex coloring:
  Vertex 0 -> Color 0
  Vertex 1 -> Color 1
  Vertex 2 -> Color 2
  Vertex 3 -> Color 0

Total colors used: 3
```

## Expected Output Explained
The greedy algorithm works through the vertices in order (0, 1, 2, ...):

* Vertex 0 gets Color 0 (it's first, nothing to conflict with).
* Vertex 1 is adjacent to 0 (Color 0), so it gets Color 1.
* Vertex 2 is adjacent to 0 (Color 0) and 1 (Color 1), so it gets Color 2.
* Vertex 3 is adjacent to 1 (Color 1) and 2 (Color 2). Color 0 is free, so it gets Color 0.

Note that greedy coloring does not guarantee the globally minimum number of colors (the chromatic number). The result can depend on vertex ordering. For optimal coloring, you'd need a more complex backtracking algorithm, but greedy is fast and works well in practice.

## Notes on this Code

* `Graph :: struct { ... }` — defining a named struct as a constant
* `[..] [..] int` — a dynamic array of dynamic arrays (the adjacency list)
* `array_add(*g.adjacency_list, neighbor_list)` — adding to a dynamic array via pointer
* `for neighbor: g.adjacency_list[vertex]` — iterating directly over a dynamic array
* `array_free(...)` — explicit memory cleanup (no garbage collector!)
* `g.num_vertices` - 1 used in `for vertex: 1..num_vertices - 1` — ranges are inclusive on both ends
* `defer` could be used here to ensure `array_free` is called, but was kept explicit for clarity

# A* Pathfinding with Manhatten Distance

This is an A* pathfinding implementation using a Manhattan distance heuristic. The goal is to find the shortest route through a grid from a start point `S` to a goal `G`, navigating around walls `#`.

The key idea - `f_cost = g_cost + h_cost`
Every tile we consider gets a score made of two parts:

* `g_cost` — how many steps it took to actually reach this tile from the start
* `h_cost` — our guess of how far this tile is from the goal (the Manhattan distance — just count horizontal + vertical steps, ignoring walls)

We always explore whichever tile has the lowest combined score first. This is what makes A* smarter than a blind search — the heuristic steers us toward the goal rather than wandering everywhere.

## Definitions
We define a `Vector2i` which is a Vector of two integers, the different directions one can move in, and a definition of the Manhattan distance.
```jai
#import "Basic";

Vector2i :: struct {
    x: int;
    y: int;
}

Node :: struct {
    pos:    Vector2i;
    g_cost: int;  // cost from start
    h_cost: int;  // heuristic cost to goal
    parent: *Node;
}

f_cost :: (node: Node) -> int {
    return node.g_cost + node.h_cost;
}

abs :: (x: int) -> int {
    if x < 0 then {
        x = -x;
    }
    return x;
}

manhattan :: (a: Vector2i, b: Vector2i) -> int {
    return abs(a.x - b.x) + abs(a.y - b.y);
}

DIRS :: Vector2i.[
    .{  0, -1 },  // up
    .{  0,  1 },  // down
    .{ -1,  0 },  // left
    .{  1,  0 },  // right
];


print_grid :: (grid: [][] bool, path: [..] Vector2i, start: Vector2i, goal: Vector2i) {
    for y: 0..grid.count - 1 {
        for x: 0..grid[0].count - 1 {
            pos := Vector2i.{ x, y };

            is_start := pos.x == start.x && pos.y == start.y;
            is_goal  := pos.x == goal.x  && pos.y == goal.y;

            on_path := false;
            for path {
                if it.x == pos.x && it.y == pos.y {
                    on_path = true;
                    break;
                }
            }

            if      is_start        print("S ");
            else if is_goal         print("G ");
            else if grid[y][x]      print("# ");
            else if on_path         print(". ");
            else                    print("  ");
        }
        print("\n");
    }
}
```

## A Star Implementation
This is the algorithm procedure:
* Put the start tile in the **open list** (tiles we know about but haven't explored yet)
* Pick whichever open tile has the lowest score
* If it's the goal — we're done, trace back through parents to recover the path
* Otherwise, move it to the **closed list** (tiles we've fully explored) and look at its neighbours
* For each neighbour, skip it if it's a wall or already explored. Otherwise add it to the open list, recording the current tile as its parent
* Repeat until we find the goal or run out of tiles

Each node stores a pointer to its `parent` — the tile we came from. Once we reach the goal, we just follow those parent pointers back to the start, then reverse the result to get the path in the right order.

```jai
// Returns the path from start to goal, or an empty array if no path found.
astar :: (grid: [][] bool, start: Vector2i, goal: Vector2i) -> [..] Vector2i {
    rows := grid.count;
    cols := grid[0].count;

    in_bounds :: (pos: Vector2i, rows: int, cols: int) -> bool {
        return pos.x >= 0 && pos.x < cols && pos.y >= 0 && pos.y < rows;
    }

    open:   [..] *Node;
    closed: [..] *Node;

    start_node := New(Node);
    start_node.pos    = start;
    start_node.g_cost = 0;
    start_node.h_cost = manhattan(start, goal);
    start_node.parent = null;
    array_add(*open, start_node);

    while open.count > 0 {

        // Pick the open node with lowest f_cost.
        best_index := 0;
        for i: 1..open.count - 1 {
            if f_cost(open[i].*) < f_cost(open[best_index].*) {
                best_index = i;
            }
        }

        current := open[best_index];

        // Reconstruct path if we reached the goal.
        if current.pos.x == goal.x && current.pos.y == goal.y {
            path: [..] Vector2i;
            node := current;
            while node != null {
                array_add(*path, node.pos);
                node = node.parent;
            }

            // Reverse so path runs start -> goal.
            begin := 0;
            end   := path.count - 1;
            while begin < end {
                path[begin], path[end] = path[end], path[begin];
                begin += 1;
                end   -= 1;
            }
            return path;
        }

        // Move current from open -> closed.
        open[best_index] = open[open.count - 1];
        open.count -= 1;
        array_add(*closed, current);

        // Explore neighbours.
        for dir: DIRS {
            neighbour_pos := Vector2i.{ current.pos.x + dir.x, current.pos.y + dir.y };

            if !in_bounds(neighbour_pos, rows, cols)  continue;
            if grid[neighbour_pos.y][neighbour_pos.x] continue;  // wall

            // Skip if already in closed list.
            already_closed := false;
            for closed {
                if it.pos.x == neighbour_pos.x && it.pos.y == neighbour_pos.y {
                    already_closed = true;
                    break;
                }
            }
            if already_closed continue;

            tentative_g := current.g_cost + 1;

            // Check if neighbour is already in open list.
            existing: *Node = null;
            for open {
                if it.pos.x == neighbour_pos.x && it.pos.y == neighbour_pos.y {
                    existing = it;
                    break;
                }
            }

            if existing {
                // Update if we found a cheaper route.
                if tentative_g < existing.g_cost {
                    existing.g_cost = tentative_g;
                    existing.parent = current;
                }
            } else {
                neighbour := New(Node);
                neighbour.pos    = neighbour_pos;
                neighbour.g_cost = tentative_g;
                neighbour.h_cost = manhattan(neighbour_pos, goal);
                neighbour.parent = current;
                array_add(*open, neighbour);
            }
        }
    }

    empty: [..] Vector2i;
    return empty;  // no path found
}

main :: () {
    // true = wall, false = open
    map: [8][8] bool = .[
        .[ false, false, false, false, false, false, false, false ],
        .[ false, false, true,  false, false, false, false, false ],
        .[ false, false, true,  false, true,  true,  true,  false ],
        .[ false, false, true,  false, false, false, false, false ],
        .[ false, false, true,  true,  true,  false, false, false ],
        .[ false, false, false, false, false, false, false, false ],
        .[ false, false, false, false, false, false, false, false ],
        .[ false, false, false, false, false, false, false, false ],
    ];

    // Build a [] [] bool (array view of rows) from the fixed grid.
    rows: [8] [] bool;
    for i: 0..7  rows[i] = map[i];
    grid: [] [] bool = rows;

    start := Vector2i.{ 0, 0 };
    goal  := Vector2i.{ 7, 7 };

    path := astar(grid, start, goal);

    if path.count > 0 {
        print("Path found! % steps\n", path.count - 1);
        print_grid(grid, path, start, goal);
    } else {
        print("No path found.\n");
    }
}
```

## Expected Output
```
Path found! 14 steps
S
.   #
.   #   # # #
.   #
.   # # #
. . . . . . . .
              .
              G
```

# Directed Acyclic Word Graph

This is an implementation of a directed acyclic word graph from the paper "The World's Fastest Scrabble Program" by Appel Jaconson.

The algorithm from the paper can be described as follows:
* Insert all words into a Trie.
* Minimize the Trie bottom-up into a DAWG by merging nodes whose subtrees are structurally identical.
* Pack nodes into a flat edge array (32 bits per edge) matching the paper's compact storage format.

The Edge bit layout (32 bits) is organized in the following way:
* bits 0-4 : letter index 0-25  (5 bits)
* bits 5-28 : child node index   (24 bits)
* bit 29 : is_terminal flag   (1 bit, word ends here)
* bit 30 : is_last_edge flag  (1 bit, last edge in node)
* bits 31-32 : unused             (2 bits)

## Imports and Trie

We first insert all words into a Trie and import modules such as `Basic`, `String`, `Hash_Table`, and `File`.

```jai
#import "Basic";
#import "String";
#import "Hash_Table";
#import "File";

// ---------------------------------------------------------------------------
// Phase 1 – Trie
// ---------------------------------------------------------------------------

Trie_Node :: struct {
    children : [26] *Trie_Node;
    is_terminal : bool;
}

make_trie_node :: () -> *Trie_Node {
    return New(Trie_Node);
}

trie_insert :: (root: *Trie_Node, word: string) {
    node := root;
    for i : 0..word.count-1 {
        idx := word[i] - #char "a";
        if !node.children[idx]
            node.children[idx] = make_trie_node();
        node = node.children[idx];
    }
    node.is_terminal = true;
}
```

## Minimization Trie to Dawg
We traverse the trie bottom-up.  At each node we first canonicalize all children, then compute a signature string:
```jai
 "<terminal_flag> | a:<child_id> b:<child_id> ..."
```

If a node with an identical signature already exists in the registry we reuse it; otherwise we register this node and assign it a fresh id. After this pass many Trie_Node pointers are redirected to shared nodes, giving us the DAWG.

```jai
minimization_registry : Table(string, *Trie_Node);
next_node_id : int = 0;

// A small wrapper so we can attach a numeric id to each canonical node.
node_id_map : Table(*Trie_Node, int);

assign_or_get_id :: (node: *Trie_Node) -> int {
    id_ptr := table_find_pointer(*node_id_map, node);
    if id_ptr return id_ptr.*;

    id := next_node_id;
    next_node_id += 1;
    table_set(*node_id_map, node, id);
    return id;
}

// Returns the canonical representative for `node` (may be a different pointer).
canonicalize :: (node: *Trie_Node) -> *Trie_Node {
    // Recurse into children first (bottom-up).
    for i : 0..25 {
        if node.children[i]
            node.children[i] = canonicalize(node.children[i]);
    }

    // Build signature from canonical children ids.
    builder : String_Builder;
    if node.is_terminal  append(*builder, "T");
    else                 append(*builder, "F");

    for i : 0..25 {
        child := node.children[i];
        if child {
            child_id := assign_or_get_id(child);
            print_to_builder(*builder, "|%:%", i, child_id);
        }
    }
    sig := builder_to_string(*builder);

    existing := table_find_pointer(*minimization_registry, sig);
    if existing {
        return existing.*;          // reuse the already-registered node
    }

    // First time we see this signature – register this node.
    table_set(*minimization_registry, sig, node);
    assign_or_get_id(node);         // ensure it has an id
    return node;
}
```

## Pack into flat edge array
Each edge is stored as one 32-bit word. All edges of a node occupy a contiguous sub-array; a node is referenced by the index of its *first* edge. The special node index 0 means "no children" (a node with no out-edges).

```jai
// Packed 32-bit edge word.
Edge :: u32;

make_edge :: (letter: int, child_first_edge: int, is_terminal: bool, is_last: bool) -> Edge {
    e : u32 = 0;
    e |= cast(u32)(letter          & 0x1F);        // bits 0-4
    e |= cast(u32)(child_first_edge & 0xFF_FF_FF) << 5; // bits 5-20
    if is_terminal  e |= (1 << 29);
    if is_last      e |= (1 << 30);
    return e;
}

edge_letter        :: (e: Edge) -> int  { return cast(int)(e        & 0x1F); }
edge_child         :: (e: Edge) -> int  { return cast(int)((e >> 5) & 0xFF_FF_FF); }
edge_is_terminal   :: (e: Edge) -> bool { return (e & (1 << 29)) != 0; }
edge_is_last       :: (e: Edge) -> bool { return (e & (1 << 30)) != 0; }

Packed_DAWG :: struct {
    edges : [..] Edge;
}

// Maps canonical Trie_Node pointer -> index of its first edge in the array.
node_to_first_edge : Table(*Trie_Node, int);

// We need to serialize nodes in a stable order, so we collect them first.
all_nodes : [..] *Trie_Node;

collect_nodes_dfs :: (node: *Trie_Node) {
    if table_find_pointer(*node_to_first_edge, node)  return;  // already visited

    // Reserve a slot (filled in during packing).
    table_set(*node_to_first_edge, node, -1);
    array_add(*all_nodes, node);

    for i : 0..25 {
        child := node.children[i];
        if child  collect_nodes_dfs(child);
    }
}

pack_dawg :: (root: *Trie_Node) -> Packed_DAWG {
    dawg : Packed_DAWG;

    // Index 0 is reserved: the null / leaf node (no out-edges).
    // We represent it as a single sentinel edge that is "last" with letter=0
    // and child=0.  Lookups that arrive here know there are no children.
    array_add(*dawg.edges, make_edge(0, 0, false, true));

    // DFS to collect all reachable canonical nodes.
    collect_nodes_dfs(root);

    // --- First pass: assign first-edge indices ---
    // We iterate all_nodes in order, laying out edges sequentially.
    // We need to know child first-edge indices, so we do two passes.

    // Compute layout offsets.  Start at 1 (slot 0 is the null sentinel).
    offset := 1;
    for node : all_nodes {
        table_set(*node_to_first_edge, node, offset);
        // Count how many children this node has.
        child_count := 0;
        for i : 0..25  if node.children[i]  child_count += 1;
        // Nodes with no children get first_edge = 0 (sentinel).
        if child_count == 0 {
            table_set(*node_to_first_edge, node, 0);
        } else {
            offset += child_count;
        }
    }

    // Resize the edge array to hold everything.
    array_resize(*dawg.edges, offset);

    // --- Second pass: write edge words ---
    for node : all_nodes {
        first := table_find_pointer(*node_to_first_edge, node);
        if !first || first.* == 0  continue;   // leaf node, no edges to write

        edge_idx := first.*;
        last_child_letter := -1;
        for i : 0..25  if node.children[i]  last_child_letter = i;

        for i : 0..25 {
            child := node.children[i];
            if !child  continue;

            child_first := table_find_pointer(*node_to_first_edge, child);
            child_edge_idx := ifx child_first then child_first.* else 0;

            is_last     := (i == last_child_letter);
            is_terminal := child.is_terminal;

            dawg.edges[edge_idx] = make_edge(i, child_edge_idx, is_terminal, is_last);
            edge_idx += 1;
        }
    }

    return dawg;
}
```

## DAWG Functions
`dawg_contains` checks whether a word is contained within a dawg. If this function returns `true`, the word is contained within the DAWG. If a word cannot be found, return false. `dawg_contains_prefix` checks whether a string is a part of a word. Unlike `dawg_contains`, `dawg_contains_prefix` does not require a complete word and will accept strings that are parts of words.

```jai
dawg_contains :: (dawg: Packed_DAWG, root_first_edge: int, word: string) -> bool {
    first_edge := root_first_edge;

    for char_idx : 0..word.count-1 {
        letter := word[char_idx] - #char "a";

        if first_edge == 0  return false;   // no children

        found := false;
        idx   := first_edge;
        while true {
            e := dawg.edges[idx];
            if edge_letter(e) == letter {
                // On the last character, check the terminal flag.
                if char_idx == word.count-1  return edge_is_terminal(e);

                first_edge = edge_child(e);
                found = true;
                break;
            }
            if edge_is_last(e)  break;
            idx += 1;
        }
        if !found  return false;
    }
    return false;
}

// Returns true if `prefix` is a prefix of any word stored in the DAWG.
// Unlike dawg_contains, it does not require the path to end on a terminal edge.
dawg_contains_prefix :: (dawg: Packed_DAWG, root_first_edge: int, prefix: string) -> bool {
    first_edge := root_first_edge;

    for char_idx : 0..prefix.count-1 {
        letter := prefix[char_idx] - #char "a";

        if first_edge == 0  return false;  // no children, prefix goes nowhere

        found := false;
        idx   := first_edge;
        while true {
            e := dawg.edges[idx];
            if edge_letter(e) == letter {
                // On the final character we only need the edge to exist,
                // not to be terminal — any continuation counts.
                if char_idx == prefix.count-1  return true;

                first_edge = edge_child(e);
                found = true;
                break;
            }
            if edge_is_last(e)  break;
            idx += 1;
        }
        if !found  return false;
    }

    // Empty prefix is trivially a prefix of every word.
    return true;
}
```

## DAWG Helper Functions

`print_dawg_stats` function track the memory footprint of the DAWG and the amount of memory saved by using this optimized data structure. The `get_words` function takes in a text file full of words separated by newlines, and transforms that into an array.

```jai
// ---------------------------------------------------------------------------
// Pretty-print helpers
// ---------------------------------------------------------------------------

print_dawg_stats :: (dawg: Packed_DAWG, node_count: int) {
    print("DAWG stats:\n");
    print("  Canonical nodes : %\n", node_count);
    print("  Edge array size : % edges\n", dawg.edges.count);
    print("  Memory (edges)  : % bytes\n", dawg.edges.count * size_of(Edge));
}

print_first_n_edges :: (dawg: Packed_DAWG, n: int) {
    limit := min(n, dawg.edges.count);
    print("First % edges:\n", limit);
    for i : 0..limit-1 {
        e := dawg.edges[i];
        letter_char := cast(u8)(edge_letter(e) + #char "a");
        print("  [%] letter='%'  child=%  terminal=%  last=%\n",
              i,
              formatChar(letter_char),
              edge_child(e),
              edge_is_terminal(e),
              edge_is_last(e));
    }
}

formatChar :: (c: u8) -> string {
    s : string;
    s.data  = *c;
    s.count = 1;
    return copy_string(s);
}

/*

'get_words' takes a text file and makes an array of words represented as strings.

aa
aah
aahed
aahing
...
zymurgies
zymurgy
zyzzyva
zyzzyvas
zzz
*/

get_words :: (filename: string) -> [] string {
    words, success := read_entire_file(filename);
    assert(success);
    return split(words, #char "\n");
}
```

## Setup and Example Usage

Here is a basic example where we:
* build the trie
* minimize the trie into a DAWG
* pack the output into a flat array
* test the functionality of the DAWG against words

```jai
// ---------------------------------------------------------------------------
// main – demonstrate with a small lexicon matching Figure 1 of the paper
// ---------------------------------------------------------------------------

main :: () {
    // Get words from a text file containing words
    words := get_words("dictionary.txt");

    // -----------------------------------------------------------------------
    // Phase 1: build the trie
    // -----------------------------------------------------------------------
    root := make_trie_node();
    for w : words  trie_insert(root, w);
    print("Trie built from % words.\n", words.count);
    print("Words: %\n", words);

    // -----------------------------------------------------------------------
    // Phase 2: minimize into DAWG
    // -----------------------------------------------------------------------
    init(*minimization_registry);
    init(*node_id_map);

    dawg_root := canonicalize(root);

    canonical_count := node_id_map.count;
    print("Minimization complete. Canonical nodes: %\n", canonical_count);

    // -----------------------------------------------------------------------
    // Phase 3: pack into flat edge array
    // -----------------------------------------------------------------------
    init(*node_to_first_edge);

    dawg := pack_dawg(dawg_root);

    // Get the first-edge index for the root so we can search.
    root_first_edge_ptr := table_find_pointer(*node_to_first_edge, dawg_root);
    root_first_edge := ifx root_first_edge_ptr then root_first_edge_ptr.* else 0;

    print_dawg_stats(dawg, canonical_count);
    print("\n");
    print_first_n_edges(dawg, 16);

    // -----------------------------------------------------------------------
    // Demonstrate lookup
    // -----------------------------------------------------------------------
    print("\n--- Lookup Strings Found ---\n");

    test_words := string.[
        "car", "cars", "cat", "cats",
        "do",  "dog",  "dogs", "done",
        "ear", "ears", "eat",  "eats",
        "qi",  "queen", "vav", "zebra",
    ];
    print("%\n", root_first_edge);
    for w : test_words {
        found := dawg_contains(dawg, root_first_edge, w);
        print("  \"%\" -> %\n", w, ifx found then "FOUND" else "not found");
        assert(found, "[%] not found in the dictionary", w);
    }

    // not found in the dictionary.
    test_not_in_dictionary := string.[
        "bereshit", "daniel", "coalexander", "banananananana", "newroiualsdkfj",
        "aaii", "joyjj", "abashest", "abbacyq", "xxxxxx", "norse",
        "qiqqq", "pelge", "miama", "sheoll", "yacobq"
    ];

    print("\n--- Lookup Strings NOT Found ---\n");
    for w : test_not_in_dictionary {
        found := dawg_contains(dawg, root_first_edge, w);
        print("  \"%\" -> %\n", w, ifx found then "FOUND" else "not found");
        assert(!found, "function incorrect, false positive on [%]", w);
    }

    print("DAWG tested thoroughly. DAWG initialization successful.\n");
}
```




--- End of file: documents/13_graph_algorithms.md ---

--- Start of file: documents/14_assembly_language_examples.md ---
# Basic Add Function
This basic add function demonstrates how to add using assembly language. This add function is a didactic example meant to demonstrate how to use assembly at a basic level.
```jai
add :: (a: int, b: int) -> int {
    #asm {
       add a, b;
    }
    return a;
}
```

# Basic Sub Function
This basic add function demonstrates how to subtract using assembly language. This sub function is a didactic example meant to demonstrate how to use assembly at a basic level.

```jai
sub :: (a: int, b: int) -> int {
    #asm {
       sub a, b;
    }
    return a;
}
```

# Basic Multiply Function

Multiplying two numbers using the `imul` is more complex compared with the basic add. `imul` places the product of the two integers in either the `RAX` or `RDX` registers depending on how it is called. To specify which variable name represents a particular register, we can take advantage of 'pinning'. We pin variables `a` and `b` to the registers `RAX` and `RDX` respectively.

```jai
mul :: (a: int, b: int) -> int {
    #asm {
        a === a; // a = RAX register
        b === d; // b = RDX register
        imul.64 a, b;
    }
    return a;
}
```

# Basic Divide Function

Dividing two numbers using the `idiv` is more complex compared with the basic add. `idiv` places the division of the two integers in either the `RAX` or `RDX` registers depending on how it is called. To specify which variable name represents a particular register, we can take advantage of 'pinning'. We pin variable `a` to the registers `RAX` and declare a dummy `rdx` set to zero and pin it to `RDX`. We perform the division and return the return in `a`, in accordance with the `idiv` x86-64 assembly instruction behavior.

```jai
div :: (a: int, b: int) -> int {
    #asm {
        rdx: gpr === d;
        a === a;
        xor.64  rdx, rdx;
        idiv.64 rdx, a, b;
    }
    return a;
}
```

# Paddb
This code uses `paddb` SSE assembly instruction to add 16 element u8 arrays in parallel.

```jai
paddb :: (a: [16] u8, b: [16] u8) -> [16] u8 {
    c := a;
    #asm {
        paddb.128 c, b;
    }
    return c;
}
```

# Paddw
This code uses `paddw` SSE assembly instruction to add 8 element u16 arrays in parallel.

```jai
paddw :: (a: [8] u16, b: [8] u16) -> [8] u16 {
    c := a;
    #asm {
        paddw.128 c, b;
    }
    return c;
}
```

# Paddd
This code uses `paddd` SSE assembly instruction to add 4 element u32 arrays in parallel.
```jai
paddd :: (a: [4] u32, b: [4] u32) -> [4] u32 {
    c := a;
    #asm {
        paddd.128 c, b;
    }
    return c;
}
```


# Addps
This code uses `addps` assembly instruction to add 4 element float arrays in parallel.

```jai
movps :: (a: [4] float, b: [4] float) -> [4] float {
    c: [4] float;
    pointer_a := a.data;
    pointer_b := a.data;
    pointer_c := c.data;

    #asm {
        xmm0: vec;
        xmm1: vec;
        movups.128 xmm0, [pointer_a];
        movups.128 xmm1, [pointer_b];
        addps.128  xmm0, xmm1;
        movups.128 [pointer_c], xmm0;
    }

    return c;

}
```

Here is another way to write the same function. The inline assembly has a by-reference / by-value distinction (like high level code) as well as allowing by-value moves of structs into and out of vector registers. The goal here is to let the compiler manage some moves such that they can be avoided during code gen. This let's you drop single `#asm` instructions in small composable functions that will be properly collapsed by LLVM (release mode).

```jai
addps :: (a: [4] float, b: [4] float) -> [4] float {
    c := a;
    #asm {
        addps c, b;
    }
    return c;
}
```

# Min using cmovle

This code example makes use of the `cmovle` assembly instruction to compare two 64-bit integer values and return the minimum between integer variables `a` and `b`. This code can be useful to reduce branch prediction misses.

```jai
min :: (a: int, b: int) -> int {
    ret: int;
    #asm {
        cmp.64     a, b;
        mov.64     ret, b;
        cmovle.64  ret, a;
    }
    return ret;
}
```


# Max using cmovge

This code example makes use of the `cmovge` assembly instruction to compare two 64-bit integer values and return the maximum between integer variables `a` and `b`. This code can be useful to reduce branch prediction misses.
```jai
max :: (a: int, b: int) -> int {
    ret: int;
    #asm {
        cmp.64     a, b;
        mov.64     ret, b;
        cmovge.64  ret, a;
    }
    return ret;
}
```

# Abs with cmovs
This code example makes use of the `cmovs` assembly instruction to compare a value with its negation and return the absolute value of a particular integer number. This code can be useful to reduce branch prediction misses.
```jai
abs :: (a: int) -> int {
    ret: int;
    #asm {
        mov     ret, a;
        neg     ret;
        cmovs   ret, a;
    }
    return ret;
}
```

# Read and Write to an Array

In the following example below, we have a high level language code. We translate it into a low level assembly language code in order to elaborate on how to read/write from address in assembly language.

This is the high level language example. The piece of code adds 10 to each individual element of the array.
```jai
high_level_code :: () {

    array := int.[1,2,3,4];

    for i: 0..3 {
        array[i] = array[i] + 10;
    }

    print("%\n", array);
}
```
This is the low level assembly language example. The piece of code adds 10 to each individual element of the array, producing the same exact output as the previous example. However, this assembly language example makes use of read/write memory from addresses and uses assembly language directly as opposed to compiling high level language into assembly.
```jai
assembly_language_code :: () {

    array := int.[1,2,3,4];

    array_data := array.data;
    for 0..3 {
        #asm {
            register: gpr;
            mov.64 register, [array_data];
            add.64 register, 10;
            mov.64 [array_data], register;
            add.64 array_data, 8;
        }
    }

    print("%\n", array);
}
```


# Popcount

One can use the CPU builtin assembly language instruction `popcount` to speedup the computation of bits.

## Popcount u8

This code example utilizes the x86-64 assembly language to do a popcount on a `u8`.

```jai
popcount_u8 :: (value: u8) -> int {
    result: int;
    #asm {
        bytes: gpr;                // declare a register
        movzxbw    bytes,  value;  // bytes = value
        popcnt.16  result, bytes;  // result = popcount(bytes);
    }
    return result;
}
```

## Popcount u16

This code example utilizes the x86-64 assembly language to do a popcount on a `u16`.
```jai
popcount_u16 :: (value: u16) -> int {
    result: int;
    #asm {
        popcnt.16  result, value;  // result = popcount(value);
    }
    return result;
}
```

## Popcount u32

This code example utilizes the x86-64 assembly language to do a popcount on a `u32`.

```jai
popcount_u32 :: (value: u32) -> int {
    result: int;
    #asm {
        popcnt.32  result, value;  // result = popcount(value);
    }
    return result;
}
```

## Popcount u64

This code example utilizes the x86-64 assembly language to do a popcount on a `u64`.

```jai
popcount_u64 :: (value: u64) -> int {
    result: int;
    #asm {
        popcnt.64  result, value;  // result = popcount(result);
    }
    return result;
}
```

## Polymorphic Popcount

One can combine `popcount_u8`, `popcount_u16`, `popcount_u32`, and `popcount_u64` together into one single polymorphic `popcount` function which handles all cases in one polymorphic function. This reduces redundant code across all integer data types.

```jai
popcount :: (value: $T) -> int {
    result: int;
    assert(CPU == .X64);
    #if T == u8 {
        #asm {
            // There is no popcnt.8, so we need to move into 16 bits.
            movzxbw    two_bytes:, value;
            popcnt.16  result, two_bytes;
        }
    } else {
        #asm {
            popcnt?T   result, value;
        }
    }

    return result;
}
```

# Byte Swap
One can use `bwap` assembly instruction to swap the bytes of an integer.

## Byte Swap 32
This code example utilizes the x86-64 assembly language to do a `bswap` on a `u32`.
```jai
byte_swap_u32 :: (value: u32) -> u32 {
    #asm {
        bswap.32 value;
    }
    return value;
}
```

## Byte Swap 64
This code example utilizes the x86-64 assembly language to do a `bswap` on a `u64`.
```jai
byte_swap_u64 :: (value: u64) -> u64 {
    #asm {
        bswap.64 value;
    }
    return value;
}
```

# Bit Scan Forward

One can use the CPU builtin assembly language instruction `bsf` to speedup the computation of bit scan forward on a CPU.

## Bit Scan Forward u8
This code example utilizes the x86-64 assembly language to do a bit scan forward on a `u8`.
```jai
bit_scan_forward_u8 :: (number: u8) -> int {
    result: int;
    #asm {
        temp: gpr;
        movzxbw   temp, number;
        bsf.16    result, temp;
    }
    return result;
}
```

## Bit Scan Forward u16
This code example utilizes the x86-64 assembly language to do a bit scan forward on a `u16`.
```jai
bit_scan_forward_u16 :: (number: u16) -> int {
    result: int;
    #asm {
        bsf.16    result, number;
    }
    return result;
}
```

## Bit Scan Forward u32
This code example utilizes the x86-64 assembly language to do a bit scan forward on a `u32`.
```jai
bit_scan_forward_u32 :: (number: u32) -> int {
    result: int;
    #asm {
        bsf.32    result, number;
    }
    return result;
}
```


## Bit Scan Forward u64
This code example utilizes the x86-64 assembly language to do a bit scan forward on a `u64`.
```jai
bit_scan_forward_u64 :: (number: u64) -> int {
    result: int;
    #asm {
        bsf.64    result, number;
    }
    return result;
}
```

## Polymorphic Bit Scan Forward

One can combine `bit_scan_forward_u8`, `bit_scan_forward_u16`, `bit_scan_forward_u32`, and `bit_scan_forward_u64` together into one single polymorphic `bit_scan_forward` function which handles all cases in one polymorphic function. This reduces redundant code across all integer data types.

```jai
bit_scan_forward :: (input: $T) -> int {
    assert(CPU == .X64);
    result: int = -1;
    #if T == u8 {  // There's no bsf for 8 bits. Sad.
        #asm {
            movzxbw   temp:, input;
            bsf.16    result, temp;
        }
    } else {
        #asm {
            bsf?T     result, input;
        }
    }

    return result;
}
```

# Count Leading Zeros
One can use the CPU builtin assembly language instruction `lzcnt` to count leading zeros on a CPU.

## Count Leading Zeros u16
This code example utilizes the x86-64 assembly language to count leading zeros on a `u16`.
```jai
count_leading_zeros_u16 :: (value: u16) -> int {
    result: int;
    #asm {
        lzcnt.16 result, value;
    }
    return result;
}
```

## Count Leading Zeros u32
This code example utilizes the x86-64 assembly language to count leading zeros on a `u32`.
```jai
count_leading_zeros_u32 :: (value: u32) -> int {
    result: int;
    #asm {
        lzcnt.32 result, value;
    }
    return result;
}
```

## Count Leading Zeros u64
This code example utilizes the x86-64 assembly language to count leading zeros on a `u64`.
```jai
count_leading_zeros_u64 :: (value: u64) -> int {
    result: int;
    #asm {
        lzcnt.64 result, value;
    }
    return result;
}
```
## Count Leading Zeros Polymorphic

One can generalize `count_leading_zeros_u16`, `count_leading_zeros_u32`, and `count_leading_zeros_u64` together into one single polymorphic `count_leading_zeros` function which handles all cases in one polymorphic function. This reduces redundant code across all integer data types.
```jai
count_leading_zeros :: (value: $T) -> int {
    result: int;
    #asm {
        lzcnt?T result, value;
    }
    return result;
}
```

# Newton's Method Fast Square Root

This algorithm uses assembly for the core arithmetic while keeping the loop structure in high-level code.

```jai
sqrt_fast :: (n: u64) -> u64 {
    if n == 0 return 0;
    if n == 1 return 1;

    // Initial guess
    x := n;
    y: u64 = (x + 1) >> 1;

    while y < x {
        x = y;
        // y = (x + n/x) / 2  using assembly
        #asm {
            mov.q   rax: gpr === a, n;
            xor.q   rdx: gpr === d, rdx;
            div.q   rdx, rax, x;   // rax = n / x
            add.q   rax, x;        // rax = x + n/x
            shr.q   rax, 1;        // rax = (x + n/x) / 2
            mov.q   y, rax;
        }
    }

    return x;
}
```
# SIMD Parallel Byte Comparison

This function compares 16 bytes in parallel using SIMD SSE instructions.

```jai
compare_16_bytes :: (a: [16] u8, b: [16] u8) -> bool {
    result: u32;
    #asm {
        // Compare all bytes
        pcmpeqb.128 a, b;

        // Create mask from comparison
        pmovmskb result, a;
    }

    // If all bytes matched, result will be 0xFFFF
    return result == 0xFFFF;
}
```

# Efficiently Updatable Neural Network SIMD Calculation

The following code snippets show a serious usage of Jai assembly language to do a complex low level calculation of neural network sparse matrix multiplication. This is a highly specialized task perfect to demonstrate the power of the Jai assembly language to do SIMD.


## Efficiently Updatable Neural Network Sparse Matrix Multiplication AVX2

This code snippet shows how to perform a NNUE Sparse Matrix Multiplication AVX2 for the first quantized linear layer. The output is 128 16-bit quantized integers that represent the neurons. We transfer the entire 128 16-bit integers into 8 YMM registers, manipulate the YMM registers through parallel add and subtract, then write back to the data structure.

```jai
Features :: struct {
  values: [32] *s16;
  count: int;
}

append_feature :: inline (f: *Features, value: *s16) {
  f.values[f.count] = value;
  f.count += 1;
}

for_expansion :: (features: *Features, body: Code, f: For_Flags) #expand {
  `it_index := 0;
  while it_index < features.count {
    `it := features.values[it_index];
    #insert body;
    it_index += 1;
  }
}

compute_features :: (accum: *s16, biases: *s16, added_features: Features, subtracted_features: Features) {
  // load the values.
  #asm AVX, AVX2 {
    movdqa.y ymm0:  vec, [biases + 0x00];
    movdqa.y ymm1:  vec, [biases + 0x20];
    movdqa.y ymm2:  vec, [biases + 0x40];
    movdqa.y ymm3:  vec, [biases + 0x60];
    movdqa.y ymm4:  vec, [biases + 0x80];
    movdqa.y ymm5:  vec, [biases + 0xa0];
    movdqa.y ymm6:  vec, [biases + 0xc0];
    movdqa.y ymm7:  vec, [biases + 0xe0];
  }

  for feature : subtracted_features {
    #asm AVX, AVX2 {
      psubw.y ymm0, ymm0, [feature + 0x00];
      psubw.y ymm1, ymm1, [feature + 0x20];
      psubw.y ymm2, ymm2, [feature + 0x40];
      psubw.y ymm3, ymm3, [feature + 0x60];
      psubw.y ymm4, ymm4, [feature + 0x80];
      psubw.y ymm5, ymm5, [feature + 0xa0];
      psubw.y ymm6, ymm6, [feature + 0xc0];
      psubw.y ymm7, ymm7, [feature + 0xe0];
    }
  }

  // add the values up.
  for feature : added_features {
    #asm AVX, AVX2 {
      paddw.y ymm0, ymm0, [feature + 0x00];
      paddw.y ymm1, ymm1, [feature + 0x20];
      paddw.y ymm2, ymm2, [feature + 0x40];
      paddw.y ymm3, ymm3, [feature + 0x60];
      paddw.y ymm4, ymm4, [feature + 0x80];
      paddw.y ymm5, ymm5, [feature + 0xa0];
      paddw.y ymm6, ymm6, [feature + 0xc0];
      paddw.y ymm7, ymm7, [feature + 0xe0];
    }
  }

  // store back the values in the accumulator.
  #asm AVX, AVX2 {
    movdqa.y [accum + 0x00], ymm0;
    movdqa.y [accum + 0x20], ymm1;
    movdqa.y [accum + 0x40], ymm2;
    movdqa.y [accum + 0x60], ymm3;
    movdqa.y [accum + 0x80], ymm4;
    movdqa.y [accum + 0xa0], ymm5;
    movdqa.y [accum + 0xc0], ymm6;
    movdqa.y [accum + 0xe0], ymm7;
  }
}
```

## Efficiently Updatable Neural Network Sparse Matrix Multiplication SSE
This code snippet shows how to perform a NNUE Sparse Matrix Multiplication AVX2 for the first quantized linear layer. The output is 128 16-bit quantized integers that represent the neurons. We transfer the entire 128 16-bit integers into 16 XMM registers, manipulate the XMM registers through parallel add and subtract, then write back to the data structure.
```jai
Features :: struct {
  values: [32] *s16;
  count: int;
}

append_feature :: inline (f: *Features, value: *s16) {
  f.values[f.count] = value;
  f.count += 1;
}

for_expansion :: (features: *Features, body: Code, f: For_Flags) #expand {
  `it_index := 0;
  while it_index < features.count {
    `it := features.values[it_index];
    #insert body;
    it_index += 1;
  }
}

compute_features :: (accum: *s16, biases: *s16, added_features: Features, subtracted_features: Features) {
  // load the values.
  #asm SSE {
    movdqa.x xmm0:  vec, [biases + 0x00];
    movdqa.x xmm1:  vec, [biases + 0x10];
    movdqa.x xmm2:  vec, [biases + 0x20];
    movdqa.x xmm3:  vec, [biases + 0x30];
    movdqa.x xmm4:  vec, [biases + 0x40];
    movdqa.x xmm5:  vec, [biases + 0x50];
    movdqa.x xmm6:  vec, [biases + 0x60];
    movdqa.x xmm7:  vec, [biases + 0x70];
    movdqa.x xmm8:  vec, [biases + 0x80];
    movdqa.x xmm9:  vec, [biases + 0x90];
    movdqa.x xmm10: vec, [biases + 0xa0];
    movdqa.x xmm11: vec, [biases + 0xb0];
    movdqa.x xmm12: vec, [biases + 0xc0];
    movdqa.x xmm13: vec, [biases + 0xd0];
    movdqa.x xmm14: vec, [biases + 0xe0];
    movdqa.x xmm15: vec, [biases + 0xf0];
  }

  for feature : subtracted_features {
    #asm SSE {
      psubw.x xmm0,  [feature + 0x00];
      psubw.x xmm1,  [feature + 0x10];
      psubw.x xmm2,  [feature + 0x20];
      psubw.x xmm3,  [feature + 0x30];
      psubw.x xmm4,  [feature + 0x40];
      psubw.x xmm5,  [feature + 0x50];
      psubw.x xmm6,  [feature + 0x60];
      psubw.x xmm7,  [feature + 0x70];
      psubw.x xmm8,  [feature + 0x80];
      psubw.x xmm9,  [feature + 0x90];
      psubw.x xmm10, [feature + 0xa0];
      psubw.x xmm11, [feature + 0xb0];
      psubw.x xmm12, [feature + 0xc0];
      psubw.x xmm13, [feature + 0xd0];
      psubw.x xmm14, [feature + 0xe0];
      psubw.x xmm15, [feature + 0xf0];
    }
  }

  // add the values up.
  for feature : added_features {
    #asm SSE {
      paddw.x xmm0,  [feature + 0x00];
      paddw.x xmm1,  [feature + 0x10];
      paddw.x xmm2,  [feature + 0x20];
      paddw.x xmm3,  [feature + 0x30];
      paddw.x xmm4,  [feature + 0x40];
      paddw.x xmm5,  [feature + 0x50];
      paddw.x xmm6,  [feature + 0x60];
      paddw.x xmm7,  [feature + 0x70];
      paddw.x xmm8,  [feature + 0x80];
      paddw.x xmm9,  [feature + 0x90];
      paddw.x xmm10, [feature + 0xa0];
      paddw.x xmm11, [feature + 0xb0];
      paddw.x xmm12, [feature + 0xc0];
      paddw.x xmm13, [feature + 0xd0];
      paddw.x xmm14, [feature + 0xe0];
      paddw.x xmm15, [feature + 0xf0];
    }
  }

  // store back the values in the accumulator.
  #asm SSE {
    movdqa.x [accum + 0x00], xmm0;
    movdqa.x [accum + 0x10], xmm1;
    movdqa.x [accum + 0x20], xmm2;
    movdqa.x [accum + 0x30], xmm3;
    movdqa.x [accum + 0x40], xmm4;
    movdqa.x [accum + 0x50], xmm5;
    movdqa.x [accum + 0x60], xmm6;
    movdqa.x [accum + 0x70], xmm7;
    movdqa.x [accum + 0x80], xmm8;
    movdqa.x [accum + 0x90], xmm9;
    movdqa.x [accum + 0xa0], xmm10;
    movdqa.x [accum + 0xb0], xmm11;
    movdqa.x [accum + 0xc0], xmm12;
    movdqa.x [accum + 0xd0], xmm13;
    movdqa.x [accum + 0xe0], xmm14;
    movdqa.x [accum + 0xf0], xmm15;
  }
}
```

## Efficiently Updatable Neural Networks RELU and MADD AVX2

To compute the output layer, we utilize `pmaxsw` to clamp the values to 0 in parallel. We use a mixture of `pmaddwd` and `paddd` to multiply and accumulate the neural network weights with the hidden layer inputs to obtain the final evaluation score.

```jai
NNUE :: struct {
  feature_weights: [2][9][90][HIDDEN] s16;
  feature_biases:  [HIDDEN] s16;
  output_weights:  [2][HIDDEN] s16;
  output_bias:     s32;
}

nnue: NNUE #align 64;

compute_output_layer :: (turn: int, accum: [2][128] s16) -> int {
  biases := nnue.output_bias;
  oppo := turn ^ 1;
  acc0 := *accum[turn][0];
  acc1 := *accum[oppo][0];
  weights0 := *nnue.output_weights[0][0];
  weights1 := *nnue.output_weights[1][0];
  eax: s32 = 0x0001_0001;

  #asm AVX, AVX2 {
    // Zero out the accumulator using AVX2
    pxor.y   zeroes:, zeroes, zeroes;
    pxor.y   sum:,    sum,    sum;
  }

  // Process 8 iterations instead of 16 (since we're using 256-bit registers)
  for 0..7 {
    #asm AVX, AVX2 {
      // Load 16x s16 values (256 bits) from each accumulator
      movdqa.y     ymm0:, [acc0];
      movdqa.y     ymm1:, [acc1];

      // Clamp to zero (ReLU activation): max(0, value)
      pmaxsw.y     ymm0,  ymm0, zeroes;
      pmaxsw.y     ymm1,  ymm1, zeroes;

      // Multiply and add adjacent pairs of s16 values to produce s32 results
      // This produces 8x s32 values from 16x s16 values
      pmaddwd.y    ymm0,  ymm0, [weights0];
      pmaddwd.y    ymm1,  ymm1, [weights1];

      // Accumulate the results
      paddd.y      sum,   sum,  ymm0;
      paddd.y      sum,   sum,  ymm1;

      // Advance pointers by 32 bytes (16 s16 values)
      add           acc0,      0x20;
      add           acc1,      0x20;
      add           weights0,  0x20;
      add           weights1,  0x20;
    }
  }

  // Horizontal addition to sum all 8 s32 values in the YMM register
  #asm AVX, AVX2 {
    // Extract high 128 bits and add to low 128 bits
    extracti128 xmm0:, sum, 1;
    extracti128 xmm1:, sum, 0;
    paddd.x       xmm0,  xmm0, xmm1;

    // Now we have 4 s32 values in xmm0
    // Shuffle and add to reduce to 2 values
    pshufd.x      xmm1,  xmm0, 0x1b;
    paddd.x       xmm0,  xmm0, xmm1;

    // Extract the two s32 values and add them
    movd          eax,   xmm0;
    pextrd        val: gpr, xmm0, 1;
    add            eax,   val;
    add            eax,   biases;
  }

  return eax / 32 / 128;
}
```

## Efficiently Updatable Neural Networks RELU and MADD SSE

To compute the output layer, we utilize `pmaxsw` to clamp the values to 0 in parallel. We use a mixture of `pmaddwd` and `paddd` to multiply and accumulate the neural network weights with the hidden layer inputs to obtain the final evaluation score.

```jai
NNUE :: struct {
  feature_weights: [2][9][90][HIDDEN] s16;
  feature_biases:  [HIDDEN] s16;
  output_weights:  [2][HIDDEN] s16;
  output_bias:     s32;
}

nnue: NNUE #align 64;

compute_output_layer :: (turn: int, accum: [2][128] s16) -> int {
  biases := nnue.output_bias;
  oppo := turn ^ 1;
  acc0 := *accum[turn][0];
  acc1 := *accum[oppo][0];
  weights0 := *nnue.output_weights[0][0];
  weights1 := *nnue.output_weights[1][0];
  eax: s32 = 0x0001_0001;
  #asm SSE {
    pxor.x   zeroes:, zeroes;
    movdqa.x sum:, zeroes;
  }

  for 0..15 {
    #asm SSE {
      movdqa.x     xmm0:, [acc0];
      movdqa.x     xmm1:, [acc1];
      pmaxsw.x     xmm0,  zeroes;
      pmaxsw.x     xmm1,  zeroes;
      pmaddwd.x    xmm0,  [weights0];
      pmaddwd.x    xmm1,  [weights1];
      paddd.x      sum,   xmm0;
      paddd.x      sum,   xmm1;
      add          acc0,  0x10;
      add          acc1,  0x10;
      add          weights0, 0x10;
      add          weights1, 0x10;
    }
  }

  #asm SSE {
    pshufd  xmm0:, sum, 0x1b;
    paddd.x sum, xmm0;
    movd eax, sum;
    pextrd val: gpr, sum, 1;
    add         eax, val;
    add         eax, biases;
  }

  return eax / 32 / 128;
}
```



--- End of file: documents/14_assembly_language_examples.md ---

--- Start of file: documents/15_ai_with_tic_tac_toe.md ---
# Minimax with Alpha Beta Pruning

This is a Tic Tac Toe console application that lets a human player compete against an AI using the Minimax algorithm with Alpha-Beta pruning.

Alpha-Beta pruning works by passing two running bounds — `alpha` and `beta` — into each recursive call. When `beta <= alpha`, the current branch cannot possibly affect the final result, so the search stops early and prunes that subtree. This reduces the worst-case search from `O(b^d)` to roughly `O(b^(d/2))`, a dramatic speedup.

## Imports

The application imports `Basic` for `print` and `String_Builder` to build and manipulate strings. For reading console input, it imports `Windows` and `ReadConsoleA` on Windows, and `POSIX` on Linux and macOS.

```jai
#import "Basic";   // print, read_entire_file, etc.

#if OS == .WINDOWS {
    #import "Windows";
    kernel32 :: #system_library "kernel32";
    ReadConsoleA  :: (hConsoleHandle: HANDLE, buff : *u8, 
                      chars_to_read : s32,  chars_read : *s32,
                      lpInputControl := *void ) -> bool #foreign kernel32;
} else {
    #import "POSIX";
}
```

## Constants

`PLAYER_X` is `1` and `PLAYER_O` is `-1`. This signed encoding makes it easy to switch the current player with a single multiplication: `current_player *= -1`. An empty cell is represented by `EMPTY`, which equals zero.

```jai
BOARD_SIZE  :: 9;   // 3x3 = 9 cells
EMPTY       :: 0;
PLAYER_X    :: 1;   // Human
PLAYER_O    :: -1;  // AI

// Win conditions: every possible winning line (row, col, diagonal)
WIN_LINES :: int.[
    0, 1, 2,   // top row
    3, 4, 5,   // middle row
    6, 7, 8,   // bottom row
    0, 3, 6,   // left column
    1, 4, 7,   // middle column
    2, 5, 8,   // right column
    0, 4, 8,   // diagonal top-left -> bottom-right
    2, 4, 6,   // diagonal top-right -> bottom-left
];
```

## Data Structures

`Board` is a plain struct containing a static `[9] int` array. It is zero-initialized by default, meaning all cells start as `EMPTY`.

```jai
// In Jai, structs are plain data containers — no member functions, no
// constructors. Everything is a plain procedural function operating on data.
Board :: struct {
    cells: [BOARD_SIZE] int;  // Static array of 9 ints, all zero-initialised
}
```

## Board Utilities

The board utilities handle printing the board state, checking for a winner, reading and parsing console input, checking whether the board is full, and making or undoing a move. These functions provide all the core behavior needed to run the Tic Tac Toe game.

```jai
print_board :: (board: Board) {
    print("\n");
    for row: 0..2 {
        for col: 0..2 {
            idx   := row * 3 + col;
            cell  := board.cells[idx];

            // ifx is Jai's ternary operator:  ifx condition then_val else else_val
            symbol: string;
            if cell == PLAYER_X then {
                symbol = "X";
            } else if cell == PLAYER_O then {
                symbol = "O";
            } else {
                symbol = tprint("%", idx + 1);
            }

            print(" %", symbol);

            // Print column separators
            if col < 2  print(" |");
        }
        print("\n");
        if row < 2  print("---+---+---\n");
    }
    print("\n");
}

// Check if a particular player has won.
// Returns true if any winning line belongs entirely to 'player'.
check_winner :: (board: Board, player: int) -> bool {
    // Iterate over every group of 3 indices that form a winning line.
    // WIN_LINES has 8 lines × 3 cells = 24 entries.
    for i: 0..7 {
        a := WIN_LINES[i * 3 + 0];
        b := WIN_LINES[i * 3 + 1];
        c := WIN_LINES[i * 3 + 2];

        if board.cells[a] == player &&
           board.cells[b] == player &&
           board.cells[c] == player {
            return true;
        }
    }
    return false;
}

// Returns true when no empty cell remains.
is_board_full :: (board: Board) -> bool {
    for cell: board.cells {
        if cell == EMPTY  return false;
    }
    return true;
}

// Apply a move. In Jai, *Board means "pointer to Board" — we pass by pointer
// so we can mutate the caller's data directly.
make_move :: (board: *Board, index: int, player: int) {
    board.cells[index] = player;
}

// Undo a move (used inside the recursive AI search).
undo_move :: (board: *Board, index: int) {
    board.cells[index] = EMPTY;
}

// Read a single line from stdin and strip the trailing newline.
// Jai strings are NOT null-terminated; they carry an explicit length.
read_line :: () -> string {
    builder: String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);   // 'defer' runs at scope close, like Go

    while true {
        ch: u8;
        bytes_read := read_from_standard_input(*ch, 1);
        if bytes_read <= 0       break;
        if ch == #char "\n"      break;
        if ch == #char "\r"      continue;
        append(*builder, ch);
    }
    return builder_to_string(*builder);
}

read_from_standard_input :: (ch: *u8, n: u64) -> int {
    #if OS == .WINDOWS { 
        stdin := GetStdHandle( STD_INPUT_HANDLE );
        bytes_read: s32 = 0;
        ReadConsoleA(stdin, ch, cast(s32)n, *bytes_read);
        return bytes_read;
    } else {
        bytes_read := read(STDIN_FILENO, ch, n);
        return bytes_read;
    }
}

// Parse a string as an integer. Returns (value, ok).
// Multiple return values are a first-class Jai feature.
parse_int :: (s: string) -> (int, bool) {
    if s.count == 0  return 0, false;

    result   := 0;
    negative := false;
    start    := 0;

    if s[0] == #char "-" {
        negative = true;
        start    = 1;
    }

    for i: start..s.count - 1 {
        ch := s[i];
        if ch < #char "0" || ch > #char "9"  return 0, false;
        result = result * 10 + (cast(int)(ch - #char "0"));
    }

    if negative  result = -result;
    return result, true;
}
```

## Minimax with Alpha-Beta Pruning

The AI plays as `PLAYER_O`, so lower scores are better for it. Alpha-Beta pruning tracks two bounds throughout the search:

* `alpha` — the best score the maximizing player `(X)` is guaranteed so far
* `beta` — the best score the minimizing player `(O)` is guaranteed so far

When `beta <= alpha`, we can stop searching the current branch — the opponent will never allow it to be reached.

```jai
minimax :: (board: *Board, depth: int, is_maximising: bool, alpha: int, beta: int) -> int {
    // Terminal state checks — these are the base cases of the recursion.
    if check_winner(board.*, PLAYER_X)  return  10 - depth;   // X wins
    if check_winner(board.*, PLAYER_O)  return -10 + depth;   // O wins (AI)
    if is_board_full(board.*)           return  0;             // Draw

    // Use mutable copies of alpha/beta for this stack frame.
    a := alpha;
    b := beta;

    if is_maximising {
        best := -1000;
        for i: 0..BOARD_SIZE - 1 {
            if board.cells[i] != EMPTY  continue;

            make_move(board, i, PLAYER_X);
            score := minimax(board, depth + 1, false, a, b);
            undo_move(board, i);

            if score > best  best = score;
            if best > a      a    = best;
            if b <= a        break;   // Alpha-Beta cutoff
        }
        return best;
    } else {
        best := 1000;
        for i: 0..BOARD_SIZE - 1 {
            if board.cells[i] != EMPTY  continue;

            make_move(board, i, PLAYER_O);
            score := minimax(board, depth + 1, true, a, b);
            undo_move(board, i);

            if score < best  best = score;
            if best < b      b    = best;
            if b <= a        break;   // Alpha-Beta cutoff
        }
        return best;
    }
}

// Find the single best move for PLAYER_O and return its board index.
find_best_move :: (board: *Board) -> int {
    best_score := 1000;
    best_move  := -1;

    for i: 0..BOARD_SIZE - 1 {
        if board.cells[i] != EMPTY  continue;

        make_move(board, i, PLAYER_O);
        // Minimax starts at depth 0; human (maximiser) moves next.
        score := minimax(board, 0, true, -1000, 1000);
        undo_move(board, i);

        if score < best_score {
            best_score = score;
            best_move  = i;
        }
    }
    return best_move;
}
```

## Main Game Loop

The main game loop initializes the Tic Tac Toe board, reads input from the console, and alternates turns between the human player and the AI. When the game ends, the loop breaks and the program exits.

```jai
main :: () {
    board: Board;   // Zero-initialised by default — all cells are EMPTY.

    print("=== Tic-Tac-Toe ===\n");
    print("You are X. AI is O.\n");
    print("Enter a number 1-9 matching the board position:\n");
    print(" 1 | 2 | 3\n---+---+---\n 4 | 5 | 6\n---+---+---\n 7 | 8 | 9\n\n");

    current_player := PLAYER_X;   // Human goes first.

    while true {
        print_board(board);

        if current_player == PLAYER_X {
            // ----- Human turn -----
            move := -1;
            while true {
                print("Your move (1-9): ");
                input := read_line();
                defer free(input);   // Free heap-allocated string when done.

                value, ok := parse_int(input);
                if !ok || value < 1 || value > 9 {
                    print("Invalid input. Enter a number between 1 and 9.\n");
                    continue;
                }

                idx := value - 1;   // Convert 1-based UI to 0-based index.
                if board.cells[idx] != EMPTY {
                    print("That cell is already taken. Try again.\n");
                    continue;
                }

                move = idx;
                break;
            }
            make_move(*board, move, PLAYER_X);

        } else {
            // ----- AI turn -----
            print("AI is thinking...\n");
            ai_move := find_best_move(*board);
            make_move(*board, ai_move, PLAYER_O);
            print("AI played at position %\n", ai_move + 1);
        }

        // Check game end conditions.
        if check_winner(board, current_player) {
            print_board(board);
            if current_player == PLAYER_X
                print("You win! Congratulations!\n");
            else
                print("AI wins! Better luck next time.\n");
            break;
        }

        if is_board_full(board) {
            print_board(board);
            print("It's a draw!\n");
            break;
        }

        // Flip player: multiplying by -1 toggles between PLAYER_X (1) and
        // PLAYER_O (-1). A neat trick using the signed encoding.
        current_player *= -1;
    }
}
```

# Monte Carlo Tree Search

Monte Carlo Tree Search (MCTS) builds a search tree incrementally by running thousands of random game simulations. Each iteration has four phases:

* **Selection** — Starting from the root, walk down the tree by always picking the child with the highest UCB1 score. UCB1 = `wins/visits + C·√(ln(parent_visits)/visits)`. The constant `C=√2` balances exploration and exploitation, preventing the AI from committing too strongly to one branch before it has enough evidence.
* **Expansion** — When we reach a node that still has unexplored moves, pick one at random and create a new child node for it. The `unexplored` array uses a shrink-swap trick: swap the chosen entry to the end and decrement the count, avoiding any extra memory allocation.
* **Simulation** — From the new child node, play randomly until the game ends. No tree is built during this phase — it is a fast, cheap way to estimate whether a position is roughly good or bad.
* **Backpropagation** — Walk from the expanded node back up to the root, incrementing the visit count on every ancestor. Add `1.0` for a win, `0.5` for a draw, and `0.0` for a loss, always relative to the player who made the move leading to each node.

After all iterations, the root selects the most-visited child rather than the child with the highest win rate. Visit count is a more robust signal because the algorithm naturally spends more iterations on promising branches.

## Imports

The application imports `Basic` for `print` and `String_Builder`. It also imports `Random` for random number generation during simulations, and `Math` for `log` and `sqrt`, which are needed by the UCB1 formula. For console input, it imports `Windows` and `ReadConsoleA` on Windows, and `POSIX` on Linux and macOS.

```jai
#import "Basic";
#import "Random";
#import "Math";     // for log, sqrt
#if OS == .WINDOWS {
    #import "Windows";
    kernel32 :: #system_library "kernel32";
    ReadConsoleA  :: (hConsoleHandle: HANDLE, buff : *u8,
                      chars_to_read : s32,  chars_read : *s32,
                      lpInputControl := *void ) -> bool #foreign kernel32;
} else {
    #import "POSIX";
}
```

## Constants

`PLAYER_X` is `1` and `PLAYER_O` is `2`. `MCTS_ITERATIONS` controls how many simulation cycles the AI runs per move — more iterations produce stronger play but take longer. `UCB_C` is the exploration constant `√2` used in the UCB1 formula.

```jai
BOARD_SIZE    :: 9;
EMPTY         :: 0;
PLAYER_X      :: 1;   // Human
PLAYER_O      :: 2;   // AI (MCTS)

MCTS_ITERATIONS :: 10000;   // Higher = stronger AI, but slower response
UCB_C           :: 1.41421; // sqrt(2) exploration constant

// Win-line table: 8 lines × 3 cell indices each
WIN_LINES :: int.[
    0,1,2,  3,4,5,  6,7,8,  // rows
    0,3,6,  1,4,7,  2,5,8,  // cols
    0,4,8,  2,4,6,           // diagonals
];
```

## Board Utilities

The board utilities handle printing the board, checking for a winner, determining the game result, finding empty cells, and reading and parsing console input. These functions provide all the core behavior needed to run the game and support the MCTS search.

```jai
Board :: struct {
    cells : [BOARD_SIZE] int;   // 0=empty, 1=X, 2=O
}

// Check if 'player' has won. Returns true on the first matching line found.
check_winner :: (board: Board, player: int) -> bool {
    for i : 0..7 {
        a := WIN_LINES[i*3+0];
        b := WIN_LINES[i*3+1];
        c := WIN_LINES[i*3+2];
        if board.cells[a] == player &&
           board.cells[b] == player &&
           board.cells[c] == player   return true;
    }
    return false;
}

is_board_full :: (board: Board) -> bool {
    for cell : board.cells {
        if cell == EMPTY return false;
    }
    return true;
}

// Returns PLAYER_X, PLAYER_O, -1 for draw, or 0 if the game is still in progress.
game_result :: (board: Board) -> int {
    if check_winner(board, PLAYER_X) return PLAYER_X;
    if check_winner(board, PLAYER_O) return PLAYER_O;
    if is_board_full(board)          return -1;   // draw
    return 0;                                      // ongoing
}

// Fill 'out' with the indices of all empty cells.
// Returns the number of empty cells found.
get_empty_cells :: (board: Board, out: *[BOARD_SIZE] int) -> int {
    count := 0;
    for i : 0..BOARD_SIZE-1 {
        if board.cells[i] == EMPTY {
            out.*[count] = i;
            count += 1;
        }
    }
    return count;
}

print_board :: (board: Board) {
    print("\n");
    for row : 0..2 {
        for col : 0..2 {
            idx  := row * 3 + col;
            cell := board.cells[idx];
            // ifx is Jai's ternary operator
            sym  := ifx cell == PLAYER_X then "X"
                    else ifx cell == PLAYER_O then "O"
                    else cast(string)(tprint("%", idx + 1));
            print(" %", sym);
            if col < 2 print(" |");
        }
        print("\n");
        if row < 2 print("---+---+---\n");
    }
    print("\n");
}

read_from_standard_input :: (ch: *u8, n: u64) -> int {
    #if OS == .WINDOWS {
        stdin := GetStdHandle( STD_INPUT_HANDLE );
        bytes_read: s32 = 0;
        ReadConsoleA(stdin, ch, cast(s32)n, *bytes_read);
        return bytes_read;
    } else {
        bytes_read := read(STDIN_FILENO, ch, n);
        return bytes_read;
    }
}

read_line :: () -> string {
    builder: String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);

    while true {
        ch: u8;
        bytes_read := read_from_standard_input(*ch, 1);
        if bytes_read <= 0     break;
        if ch == #char "\n"    break;
        if ch == #char "\r"    continue;
        append(*builder, ch);
    }
    return builder_to_string(*builder);
}

// Returns (value, ok). Multiple return values are a first-class Jai feature.
parse_int :: (s: string) -> (int, bool) {
    if s.count == 0 return 0, false;
    result   := 0;
    negative := false;
    start    := 0;
    if s[0] == #char "-" { negative = true; start = 1; }
    for i : start..s.count-1 {
        ch := s[i];
        if ch < #char "0" || ch > #char "9" return 0, false;
        result = result * 10 + cast(int)(ch - #char "0");
    }
    if negative result = -result;
    return result, true;
}
```

## Monte Carlo Tree Search Implementation

MCTS is a decision-making algorithm that finds good moves by combining random simulation with incremental learning. Rather than evaluating every possible game state (which is computationally infeasible in complex games), MCTS:

* Runs many random playthroughs from the current position
* Learns which moves tend to lead to better outcomes
* Gradually builds a tree of promising decisions

The algorithm repeats the four phases — selection, expansion, simulation, and backpropagation — for many iterations. More iterations produce stronger, more reliable decisions.

```jai
// -----------------------------------------------------------------------------
//  MCTS Node
//
//  In Jai, structs are plain data. Self-referential pointers (*MCTS_Node) are
//  fine; the struct is declared at file scope so the compiler knows its full
//  layout before any procedures reference it.
// -----------------------------------------------------------------------------

MCTS_Node :: struct {
    board         : Board;       // board state at this node
    move          : int;         // which cell index led to this state (-1 = root)
    player        : int;         // which player moves NEXT from this node
    parent        : *MCTS_Node;

    // Children are stored in a dynamic array [..] — grows on demand
    children      : [..] *MCTS_Node;

    // Unexplored moves for this node (filled at creation, shrinks as we expand)
    unexplored     : [BOARD_SIZE] int;
    unexplored_count : int;

    visits        : int;
    wins          : float;       // fractional: win=1, draw=0.5, loss=0
}

// Allocate and initialize a new node.
// 'New(T)' in Jai heap-allocates one T (like C's malloc + memset 0).
new_node :: (board: Board, move: int, player: int, parent: *MCTS_Node) -> *MCTS_Node {
    node := New(MCTS_Node);
    node.board   = board;
    node.move    = move;
    node.player  = player;
    node.parent  = parent;
    node.visits  = 0;
    node.wins    = 0.0;

    // Populate unexplored moves from the board's empty cells
    node.unexplored_count = get_empty_cells(board, *node.unexplored);
    return node;
}

// Recursively free the entire subtree rooted at 'node'.
// 'free(ptr)' is the Jai Basic-module equivalent of C's free().
free_tree :: (node: *MCTS_Node) {
    for child : node.children  free_tree(child);
    array_free(node.children);
    free(node);
}

// Returns true once every legal move from this node has a corresponding child.
is_fully_expanded :: (node: *MCTS_Node) -> bool {
    return node.unexplored_count == 0;
}

is_terminal :: (node: *MCTS_Node) -> bool {
    return game_result(node.board) != 0;
}

// -----------------------------------------------------------------------------
//  UCB1 — Upper Confidence Bound (exploration / exploitation trade-off)
// -----------------------------------------------------------------------------

ucb1_score :: (node: *MCTS_Node, parent_visits: int) -> float {
    if node.visits == 0 return 1.0e30;   // unvisited nodes get infinite priority

    exploitation := node.wins / cast(float) node.visits;
    exploration  := UCB_C * sqrt(log(cast(float) parent_visits) /
                                 cast(float) node.visits);
    return exploitation + exploration;
}

// Choose the child with the highest UCB1 value.
best_uct_child :: (node: *MCTS_Node) -> *MCTS_Node {
    best      : *MCTS_Node = null;
    best_score := -1.0e30;

    for child : node.children {
        score := ucb1_score(child, node.visits);
        if score > best_score {
            best_score = score;
            best       = child;
        }
    }
    return best;
}

// -----------------------------------------------------------------------------
//  PHASE 1 — Selection
//  Walk down the tree using UCB1 until we reach a node that is either
//  terminal or not yet fully expanded.
// -----------------------------------------------------------------------------

select_node :: (root: *MCTS_Node) -> *MCTS_Node {
    node := root;
    while !is_terminal(node) && is_fully_expanded(node) {
        node = best_uct_child(node);
    }
    return node;
}

// -----------------------------------------------------------------------------
//  PHASE 2 — Expansion
//  Pick one random unexplored move and create a new child node for it.
// -----------------------------------------------------------------------------

expand :: (node: *MCTS_Node) -> *MCTS_Node {
    if is_terminal(node) return node;  // can't expand a finished game

    // Pick a random unexplored move by swapping it to the end and shrinking
    // the unexplored slice — avoids the need for a separate visited-flag array.
    r   := cast(int)(random_get() % cast(u32) node.unexplored_count);
    move := node.unexplored[r];

    // Swap chosen move with the last unexplored entry, then shrink
    node.unexplored[r]                         = node.unexplored[node.unexplored_count - 1];
    node.unexplored_count -= 1;

    // Build the child board by applying the move
    new_board        := node.board;
    new_board.cells[move] = node.player;

    // Next player: toggle between PLAYER_X (1) and PLAYER_O (2)
    next_player := ifx node.player == PLAYER_X then PLAYER_O else PLAYER_X;

    child := new_node(new_board, move, next_player, node);
    array_add(*node.children, child);
    return child;
}

// -----------------------------------------------------------------------------
//  PHASE 3 — Simulation (Rollout)
//  Play randomly until the game ends. Returns the winner (PLAYER_X, PLAYER_O,
//  or -1 for a draw).
// -----------------------------------------------------------------------------

simulate :: (node: *MCTS_Node) -> int {
    board  := node.board;
    player := node.player;

    while true {
        result := game_result(board);
        if result != 0 return result;

        // Gather empty cells and pick one at random
        empties   : [BOARD_SIZE] int;
        emp_count := get_empty_cells(board, *empties);

        r    := cast(int)(random_get() % cast(u32) emp_count);
        move := empties[r];

        board.cells[move] = player;
        player = ifx player == PLAYER_X then PLAYER_O else PLAYER_X;
    }

    return -1;   // unreachable, but satisfies the compiler
}

// -----------------------------------------------------------------------------
//  PHASE 4 — Backpropagation
//  Walk from 'node' back to the root, updating visits and wins.
//  The score is always recorded from the perspective of the node's *parent*
//  (i.e. the player who just moved to reach this node).
// -----------------------------------------------------------------------------

backpropagate :: (node: *MCTS_Node, result: int, ai_player: int) {
    current := node;
    while current != null {
        current.visits += 1;

        // The player who made the move that led TO 'current' is the *parent's*
        // current player. We award the win to whoever owns this node's move.
        mover := ifx current.parent != null then current.parent.player else -99;

        if result == -1 {
            current.wins += 0.5;   // draw — both sides share half a point
        } else if result == mover {
            current.wins += 1.0;   // the player who moved here won
        }
        // else: opponent won — no points added for this node

        current = current.parent;
    }
}

// -----------------------------------------------------------------------------
//  Top-level MCTS search
//  Runs MCTS_ITERATIONS selection/expansion/simulation/backpropagation cycles,
//  then returns the index of the move with the most visits at the root.
// -----------------------------------------------------------------------------

mcts_best_move :: (board: Board, ai_player: int) -> int {
    // The root node represents the state *before* the AI moves.
    // 'ai_player' is the player whose turn it is at the root.
    root := new_node(board, -1, ai_player, null);
    defer free_tree(root);   // 'defer' runs when this scope closes — clean up

    for 0..MCTS_ITERATIONS-1 {
        // --- Selection ---
        selected := select_node(root);

        // --- Expansion ---
        expanded := ifx is_terminal(selected) then selected else expand(selected);

        // --- Simulation ---
        result := simulate(expanded);

        // --- Backpropagation ---
        backpropagate(expanded, result, ai_player);
    }

    // Pick the child with the most visits (most robust policy)
    best_move   := -1;
    best_visits := -1;
    for child : root.children {
        if child.visits > best_visits {
            best_visits = child.visits;
            best_move   = child.move;
        }
    }

    return best_move;
}

// Seed the RNG using the current wall-clock time so each run differs.
seed_rng :: () {
    t := cast(u32)(seconds_since_init() * 1_000_000.0);
    random_seed(t);
}

```

## Main Game Loop

The main game loop initializes the board, prints instructions, and alternates turns between the human player and the MCTS AI. When the game ends — by a win or a draw — the loop breaks and the program exits.

```jai
main :: () {
    seed_rng();

    board : Board;   // zero-initialised — all cells are EMPTY

    print("=== Tic-Tac-Toe (MCTS AI) ===\n");
    print("You are X. The AI is O.\n");
    print("Enter a number 1-9 matching the board position:\n");
    print(" 1 | 2 | 3\n---+---+---\n 4 | 5 | 6\n---+---+---\n 7 | 8 | 9\n");
    print("AI will run % simulations per move.\n\n", MCTS_ITERATIONS);

    current_player := PLAYER_X;   // Human goes first

    while true {
        print_board(board);

        if current_player == PLAYER_X {
            // ---- Human turn ----
            move := -1;
            while true {
                print("Your move (1-9): ");
                input := read_line();
                defer free(input);

                value, ok := parse_int(input);
                if !ok || value < 1 || value > 9 {
                    print("Invalid input. Please enter a number from 1 to 9.\n");
                    continue;
                }

                idx := value - 1;
                if board.cells[idx] != EMPTY {
                    print("Cell % is already taken. Try again.\n", value);
                    continue;
                }
                move = idx;
                break;
            }
            board.cells[move] = PLAYER_X;

        } else {
            // ---- AI turn (MCTS) ----
            print("AI is thinking (running % iterations)...\n", MCTS_ITERATIONS);

            t0       := seconds_since_init();
            ai_move  := mcts_best_move(board, PLAYER_O);
            elapsed  := seconds_since_init() - t0;

            board.cells[ai_move] = PLAYER_O;
            print("AI played position % (took %.3fs)\n", ai_move + 1, elapsed);
        }

        // Check end conditions
        result := game_result(board);
        if result != 0 {
            print_board(board);
            if result == PLAYER_X         print("You win! Congratulations!\n");
            else if result == PLAYER_O    print("AI wins! Better luck next time.\n");
            else                          print("It's a draw!\n");
            break;
        }

        // Toggle player
        current_player = ifx current_player == PLAYER_X then PLAYER_O else PLAYER_X;
    }
}
```

--- End of file: documents/15_ai_with_tic_tac_toe.md ---

--- Start of file: documents/16_sorting_and_searching.md ---
# Bubble Sort

Bubble Sort is a simple sorting algorithm that repeatedly steps through the array, compares adjacent elements, and swaps them if they are in the wrong order. This process is repeated until the list is sorted.

The following bubble sort algorithm below sorts all the elements in an array in ascending order.
```jai
bubble_sort :: (array: [] int) {

    sorted := false;

    while !sorted {
        i := 0;
        j := 1;
        sorted = true;
        while j < array.count {
            if array[j] < array[i] {
                array[j], array[i] = array[i], array[j];
                sorted = false;
            }
            i += 1;
            j += 1;
        }
    }
}
```

# Insertion Sort
Insertion sort that builds a sorted array one element at a time. Insertion sort iterates, consuming one input element each repetition, and grows a sorted output list. At each iteration, insertion sort removes one element from the input data, finds the correct location within the sorted list, and inserts it there. It repeats until no input elements remain.

The following insertion sort algorithm below sorts all the elements in an array in ascending order.
```jai
insertion_sort :: (array: [] int) {
    i := 1;
    while i < array.count {
        key := array[i];
        j := i - 1;
        while j >= 0 && key < array[j] {
            array[j + 1] = array[j];
            j -= 1;
        }
        array[j + 1] = key;
        i += 1;
    }
}
```

# Selection Sort
Selection Sort is a simple comparison-based sorting algorithm. It works by dividing the input list into two parts: the sorted portion and the unsorted portion. The algorithm repeatedly selects the smallest (or largest, depending on the order) element from the unsorted portion and swaps it with the first unsorted element, gradually growing the sorted portion.

The following selection sort algorithm below sorts all the elements in an array in ascending order.
```jai
selection_sort :: (array: [] int) {
    N := array.count - 1;
    for i : 0..N {
        ele := i;
        for j : (i+1)..N {
            if array[j] < array[ele] {
                ele = j;
            }
        }
        array[ele], array[i] = array[i], array[ele];
    }

}
```

# Heapsort

Heapsort is an efficient sorting algorithm that transforms an input array into a heap data structure. In a heap, each node is greater than its children. The largest node is repeatedly removed from that heap, and placed at the end of the array.

```jai
heapsort :: (array: [] int) {
    heapify(array);
    end := array.count;
    while end > 1 {
        end -= 1;
        array[end], array[0] = array[0], array[end];
        sift_down(array, 0, end);
    }
}

heapify :: (array: [] int) {
    start := parent(array.count - 1) + 1;
    while start > 0 {
        start -= 1;
        sift_down(array, start, array.count);
    }
}

sift_down :: (array: [] int, root: int, end: int) {
    while left_child(root) < end {
        child := left_child(root);
        if (child + 1) < end && array[child] < array[child + 1] {
             child += 1;
        }

        if array[root] < array[child] {
            array[root], array[child] = array[child], array[root];
            root = child;
        } else {
            return;
        }
    }
}

left_child :: (i: int) -> int {
    return (2 * i) + 1;
}

right_child :: (i: int) -> int {
    return (2 * i) + 2;
}

parent :: (i: int) -> int {
    return (i - 1) / 2;
}
```

# Mergesort

Mergesort is an efficient and general purpose sorting algorithm. The algorithm time complexity of mergesort is O(n log n).

A merge sort works as follows:
* Divide the unsorted list into n sub-lists, each containing one element.
* Repeatedly merge sublists to produce new sorted sublists until there is only one sublist remaining. This will be the sorted list.

```jai
merge_sort :: (arr: [] int) {
    // Merge two subarrays L and M into arr
    merge :: (arr: [] int, p: int, q: int, r: int) {
        n1 := q - p + 1;
        n2 := r - q;
        L := NewArray(n1, int);
        M := NewArray(n2, int);

        for i : 0..(n1-1) {
            L[i] = arr[p + i];
        }

        for j : 0..(n2-1) {
            M[j] = arr[q + 1 + j];
        }

        // Maintain current index of sub-arrays and main array
        i := 0;
        j := 0;
        k := p;
        while i < n1 && j < n2 {
            if L[i] <= M[j] {
                arr[k] = L[i];
                i += 1;
            } else {
                arr[k] = M[j];
                j += 1;
            }
            k += 1;
        }

        while i < n1 {
            arr[k] = L[i];
            i += 1;
            k += 1;
        }

        while (j < n2) {
            arr[k] = M[j];
            j += 1;
            k += 1;
        }
    }

    merge_sort_helper :: (arr: [] int, l: int, r: int) {
        if l < r {
            m := l + (r - l) / 2;
            merge_sort_helper(arr, l, m);
            merge_sort_helper(arr, m + 1, r);
            merge(arr, l, m, r);
        }
    }

    merge_sort_helper(arr, 0, arr.count - 1);
}
```

# Radix Sort
The Radix Sort algorithm sorts the elements by grouping the individual digits of the same place value. Then, sort the elements according to their increasing/decreasing order. The time complexity of radix sort is O(d⋅n), where:
* n is the number of elements in the array.
* d is the number of digits in the largest number.
This makes radix sort efficient for sorting large datasets with a fixed number of digits.

```jai
radixsort :: (array: [] int) {
    // get the largest element from an array
    max_value := array[0];
    for ele : array {
        max_value = max(max_value, ele);
    }

    place := 1;
    while max_value / place > 0 {
        countingSort(array, array.count, place);
        place *= 10;
    }
}

countingSort :: (array: [] int, size: int, place: int) {
    maximum :: 10;
    output := NewArray(size, int);
    count := NewArray(maximum, int);

    for *val : count {
        val.* = 0;
    }

    for i : 0..size-1 {
        count[(array[i] / place) % 10] += 1;
    }

    for i : 1..maximum - 1 {
        count[i] += count[i - 1];
    }

    i := size - 1;
    while i >= 0 {
        output[count[(array[i] / place) % 10] - 1] = array[i];
        count[(array[i] / place) % 10] -= 1;
        i -= 1;
    }

    i = 0;
    while i < size {
        array[i] = output[i];
        i += 1;
    }
}
```

# Quicksort
Quicksort is an efficient, general-purpose sorting algorithm with a time complexity of O(n log n). It is one of the most commonly used algorithms for sorting.

## Steps Involved in quicksort
Quicksort selects a pivot element from the array and partitions the other elements into two sub-arrays:
* Elements less than the pivot
* Elements greater than the pivot
It then recursively applies the same logic to the sub-arrays.

```jai
quicksort :: (array: [] int) {

    partition :: (array: [] int, low: int, high: int) -> int {
        pivot := array[high];

        i := low;
        j := low;
        while j < high {
            if array[j] < pivot {
                array[i], array[j] = array[j], array[i];
                i += 1;
            }
            j += 1;
        }
        array[i], array[high] = array[high], array[i];
        return i;
    }

    quicksort_helper :: (array: [] int, low: int, high: int) {
        if (low >= high || low < 0) {
            return;
        }

        p := partition(array, low, high);
        quicksort_helper(array, low, p - 1);
        quicksort_helper(array, p + 1, high);
    }

    quicksort_helper(array, 0, array.count - 1);
}
```

# Linear Search
A linear search is a basic search algorithm that examines each element of an array one by one until it finds the correct value. This is a O(n) algorithm.

## While Loop Linear Search
An example of a linear search with a while loop.
```jai
linear_search :: (array: [] int, value: int) -> found: bool, index: int {
    index := -1;
    i := 0;
    while i < array.count {
        if array[i] == value {
            return true, i;
        }
        i += 1;
    }
    return false, -1;
}
```

## For Loop Linear Search
An example of a linear search with a for loop.
```jai
linear_search :: (array: [] int, value: int) -> found: bool, index: int {
    for element, i : array {
        if element == value {
            return true, i;
        }
    }
    return false, -1;
}

```

# Binary Search
Binary search is a search algorithm that efficiently finds the position of a target value within a sorted array within **O(log n)** time.

## Iterative Binary Search
```jai
binary_search :: (array: [] int, value: int) -> found: bool, index: int {
    low := 0;
    high := array.count - 1;
    while low <= high {
        mid := (low + high) / 2;
        if array[mid] == value {
            return true, mid;
        } else if array[mid] < value {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    return false, -1;
}
```

## Recursive Binary Search
```jai
binary_search :: (array: [] int, value: int) -> found: bool, index: int {
    binary_search_helper :: (array: [] int, value: int, low: int, high: int) -> found: bool, index: int {
        if low > high {
            return false, -1;
        }

        mid := (low + high) / 2;
        if array[mid] == value {
            return true, mid;
        } else if array[mid] < value {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
        found, index := binary_search_helper(array, value, low, high);
        return found, index;
    }

    found, index := binary_search_helper(array, value, 0, array.count - 1);
    return found, index;
}
```


--- End of file: documents/16_sorting_and_searching.md ---

--- Start of file: documents/17_operator_overloading_for_math.md ---
When programming, there are many occasions where one wants to define addition/multiplication and different kinds of operations for a mathematical object. For example, one might define a vector or matrix and some addition/subtraction/multiplication functions to go with it.

# Vector3 Struct Definition

One can define a `Vec3` in the following way:
```jai
Vec3 :: struct {
    x: float;
    y: float;
    z: float;
}
```
We use `x, y, z` to represent the 3D coordinates.

## Vector Addition

Given the above definition, one can overload the addition operator as follows:
```jai
operator + :: (a: Vec3, b: Vec3) -> Vec3 {
    c: Vec3;
    c.x = a.x + b.x;
    c.y = a.y + b.y;
    c.z = a.z + b.z;
    return c;
}
```

This is a short example demonstrating vector addition:
```jai
a := Vec3.{1, 2, 3};
b := Vec3.{3, 4, 5};
c := a + b;
print("c = %\n", c);
```

## Vector Subtraction

Here is how one can overload the subtraction operator for `Vec3`.
```jai
operator - :: (a: Vec3, b: Vec3) -> Vec3 {
    c: Vec3;
    c.x = a.x - b.x;
    c.y = a.y - b.y;
    c.z = a.z - b.z;
    return c;
}
```

This is a short example demonstrating vector subtraction:
```jai
a := Vec3.{1, 2, 3};
b := Vec3.{3, 4, 5};
c := a - b;
print("c = %\n", c);
```

## Vector Negation
Here is how one can overload the negation operator for `Vec3`.
```jai
operator - :: (a: Vec3) -> Vec3 {
    b: Vec3;
    b.x = -a.x;
    b.y = -a.y;
    b.z = -a.z;
    return b;
}
```
This is a short example demonstrating vector negation:
```jai
a := Vec3.{1, 2, 3};
b := -a;
print("b = %\n", b);
```

## Vector Scalar Multiplication

One can overload the multiplication operator so that `Vec3` can support scalar multiplication. We can attach the `#symmetric` keyword to the function so that the scalar `float` value is swappable with the `Vec3`; in this way, we do not need to define two different functions to represent scalar multiplication.

```jai
operator * :: (a: Vec3, b: float) -> Vec3 #symmetric {
    c: Vec3 = a;
    c.x *= b;
    c.y *= b;
    c.z *= b;
    return c;
}
```

When we compile the example below, the ordering of the `Vec3` and scalar `float` value does not need matter.
```jai
a: Vec3 = Vec3.{1, 2, 3};
b: float = 3.0;
c := a * b; 
d := b * a; // <- perform commutative scalar multiplication 
print("c = %\n", c);
print("d = %\n", d);
```

## Vector Dot Product

Dot Product for `Vec3` can be written as follows:
```jai
dot :: (a: Vec3, b: Vec3) -> float {
    c := (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
    return c;
}
```
This is a short example demonstrating dot product:
```jai
a := Vec3.{1, 2, 3};
b := Vec3.{2, 4, 6};
c := dot(a, b);
print("c = %\n", c); // <- answer should be 'c = 28.0'
```

## Vector4 Dot Product
We can write a dot product using assembly language for a `Vector4` in the following way.
```jai
#import "Basic";
Vector4 :: struct {
    x: float;
    y: float;
    z: float;
    w: float;
}

dot_asm :: (a: *Vector4, b: *Vector4) -> float {
    result : float;
    #asm {
        xmm0: vec;
        xmm1: vec;
        movaps.x xmm0, [a];
        movaps.x xmm1, [b];
        mulps.x  xmm0, xmm1;
        haddps.x xmm0, xmm0;
        haddps.x xmm0, xmm0;
        movd  result, xmm0;
    }

    return result;
}

main :: () {
    v1 := Vector4.{1, 2, 3, 4} #align 16;
    v2 := Vector4.{5, 6, 7, 8} #align 16;
    print("dot_asm(v1,v2) = %\n", dot_asm(*v1, *v2)); // 70
}
```

## Vector4 Dot Product Version 2
Here is another way we can write the same dot product using assembly language for a `Vector4`. This version is more succinct.
```jai
dot_asm :: (a: Vector4, b: Vector4) -> float {
    c := a;
    result : float;
    #asm {
        mulps.128  c, b;
        haddps.128 c, c;
        haddps.128 c, c;
        movd  result, c;
    }

    return result;
}
```

# Matrix Struct Definition
There are many possible implementations of a matrix that have many pros and cons. This is one possible implementation of a matrix.
```jai
Matrix :: struct(M: int, N: int) {
    data: [M][N] float;
}
```
In this definition, a matrix is a 2D array of data, which takes M and N as a parameter for the struct for the rows and columns of the matrix, respectively.

## Matrix Addition
Given the definition, one can implement matrix addition by adding up the corresponding elements between matrix `A` and matrix `B` to get matrix `C`.
```jai
operator + :: (a: Matrix($M, $N), b: Matrix(M, N)) -> Matrix(M, N) {
    c: Matrix(M, N);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] + b.data[i][j];
        }
    }
    return c;
}
```
## Matrix Subtraction
Given the definition, one can implement matrix subtraction by subtracting the corresponding elements between matrix `A` and matrix `B` to get matrix `C`.
```jai
operator - :: (a: Matrix($M, $N), b: Matrix(M, N)) -> Matrix(M, N) {
    c: Matrix(M, N);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] - b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Multiplication
Given the definition, one can implement matrix multiplication of two matrices in the following way.
```jai
operator * :: (a: Matrix($M, $X), b: Matrix(X, $N)) -> Matrix(M, N) {
    c: Matrix(M, N);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            value: float = 0.0;
            for k : 0..(X-1) {
                value += a.data[i][k] * b.data[k][j];
            }
            c.data[i][j] = value;
        }
    }
    return c;
}
```

## Matrix Scalar Multiplication
One can overload the multiplication operator so that `Matrix` can support scalar multiplication. We can attach the `#symmetric` keyword to the function so that the scalar `float` value is swappable with the `Matrix`; in this way, we do not need to define two different functions to represent scalar multiplication.
```jai
operator * :: (a: Matrix($M, $N), b: float) -> Matrix(M, N) #symmetric {
    c: Matrix(M, N);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] * b;
        }
    }
    return c;
}
```

## Matrix Transpose
The transpose of a matrix is obtained by flipping it over its diagonal, which means switching its rows with its columns.
```jai
transpose :: (matrix: Matrix($M, $N)) -> Matrix(N, M) {
    answer: Matrix(N, M);
    for i : 0..M-1 {
        for j : 0..N-1 {
            answer.data[j][i] = matrix.data[i][j];
        }
    }
    return answer;
}
```

# Matrix SIMD

We can write an optimized SIMD matrix addition and subtraction given the following `Matrix4` struct definition:
```jai
Matrix4 :: struct {
    data: [4][4] float #align 16;
}
```

## Matrix SIMD Addition

We use SSE 128 bit SIMD operations to add matrix elements in parallel. We align all matrix elements to the 16 byte address such that SIMD operations may happen quickly. 
```jai
// SIMD-optimized addition for 4x4 matrices
operator + :: (a: Matrix4, b: Matrix4) -> Matrix4 {
    result: Matrix4 #align 16;

    a_ptr := *a.data[0][0];
    b_ptr := *b.data[0][0];
    r_ptr := *result.data[0][0];

    #asm SSE, SSE2 {
        // Process all 4 rows (16 floats) using SIMD
        row0_b: vec;
        row0_r: vec;

        // Row 0
        movaps.x row0_r, [a_ptr];
        movaps.x row0_b, [b_ptr];
        addps.x  row0_r, row0_b;
        movaps.x [r_ptr], row0_r;

        // Row 1
        movaps.x row0_r, [a_ptr + 16];
        movaps.x row0_b, [b_ptr + 16];
        addps.x  row0_r, row0_b;
        movaps.x [r_ptr + 16], row0_r;

        // Row 2
        movaps.x row0_r, [a_ptr + 32];
        movaps.x row0_b, [b_ptr + 32];
        addps.x  row0_r, row0_b;
        movaps.x [r_ptr + 32], row0_r;

        // Row 3
        movaps.x row0_r, [a_ptr + 48];
        movaps.x row0_b, [b_ptr + 48];
        addps.x  row0_r, row0_b;
        movaps.x [r_ptr + 48], row0_r;
    }

    return result;
}
```

## Matrix SIMD Addition Concise

We use SSE 128 bit SIMD operations to add matrix elements in parallel. We align all matrix elements to the 16 byte address such that SIMD operations may happen quickly. This is a more concise version compared to the previous Matrix SIMD Addition.
```jai
// SIMD-optimized addition for 4x4 matrices
operator + :: (a: Matrix4, b: Matrix4) -> Matrix4 {
    add_row :: inline (a: [4] float, b: [4] float) -> [4] float #expand {
        c := a;
        #asm {
             addps.128 c, b;
        }
        return c;
    }

    result: Matrix4 #align 16;
    result.data[0] = add_row(a.data[0], b.data[0]);
    result.data[1] = add_row(a.data[1], b.data[1]);
    result.data[2] = add_row(a.data[2], b.data[2]);
    result.data[3] = add_row(a.data[3], b.data[3]);
    return result;
}
```



## Matrix SIMD Subtraction
We use SSE 128 bit SIMD operations to subtract matrix elements in parallel. We align all matrix elements to the 16 byte address such that SIMD operations may happen quickly. 
```jai
operator - :: (a: Matrix4, b: Matrix4) -> Matrix4 {
    result: Matrix4 #align 16;

    a_ptr := *a.data[0][0];
    b_ptr := *b.data[0][0];
    r_ptr := *result.data[0][0];

    #asm SSE, SSE2 {
        row_b: vec;
        row_r: vec;

        // Row 0
        movaps.x row_r, [a_ptr];
        movaps.x row_b, [b_ptr];
        subps.x  row_r, row_b;
        movaps.x [r_ptr], row_r;

        // Row 1
        movaps.x row_r, [a_ptr + 16];
        movaps.x row_b, [b_ptr + 16];
        subps.x  row_r, row_b;
        movaps.x [r_ptr + 16], row_r;

        // Row 2
        movaps.x row_r, [a_ptr + 32];
        movaps.x row_b, [b_ptr + 32];
        subps.x  row_r, row_b;
        movaps.x [r_ptr + 32], row_r;

        // Row 3
        movaps.x row_r, [a_ptr + 48];
        movaps.x row_b, [b_ptr + 48];
        subps.x  row_r, row_b;
        movaps.x [r_ptr + 48], row_r;
    }

    return result;
}
```


## Matrix SIMD Subtraction Concise

We use SSE 128 bit SIMD operations to subtract matrix elements in parallel. We align all matrix elements to the 16 byte address such that SIMD operations may happen quickly. This is a more concise version compared to the previous Matrix SIMD Addition.

```jai
// SIMD-optimized addition for 4x4 matrices
operator - :: (a: Matrix4, b: Matrix4) -> Matrix4 {
    sub_row :: inline (a: [4] float, b: [4] float) -> [4] float #expand {
        c := a;
        #asm {
             subps.128 c, b;
        }
        return c;
    }

    result: Matrix4 #align 16;
    result.data[0] = sub_row(a.data[0], b.data[0]);
    result.data[1] = sub_row(a.data[1], b.data[1]);
    result.data[2] = sub_row(a.data[2], b.data[2]);
    result.data[3] = sub_row(a.data[3], b.data[3]);
    return result;
}
```


## Calling SIMD Matrix Operations
```jai
main :: () {
    a: Matrix4 #align 16;
    b: Matrix4 #align 16;

    // Initialize matrices
    for i: 0..3 {
        for j: 0..3 {
            a.data[i][j] = cast(float)(i * 4 + j + 1);
            b.data[i][j] = cast(float)((i * 4 + j + 1) * 2);
        }
    }

    print("Matrix A:\n");
    print_matrix4(*a);

    print("\nMatrix B:\n");
    print_matrix4(*b);

    // SIMD-optimized operations
    c := a + b;
    print("\nA + B (SIMD):\n");
    print_matrix4(*c);

    d := a - b;
    print("\nA - B (SIMD):\n");
    print_matrix4(*d);
}

print_matrix4 :: (m: *Matrix4) {
    for i: 0..3 {
        for j: 0..3 {
            print("% ", formatFloat(m.data[i][j], width=8, trailing_width=1));
        }
        print("\n");
    }
}
```

# Matrix Transpose SIMD
Matrix transpose is an operation that flips a matrix over its diagonal, converting rows into columns and vice versa. Using SIMD (Single Instruction, Multiple Data) instructions, we can perform this operation more efficiently by processing multiple elements simultaneously.

Here's a straightforward implementation using SSE instructions to transpose a 4x4 matrix of floats.

How It Works
The SIMD transpose works in two stages:

First Stage: We use unpcklps and unpckhps to interleave elements from pairs of rows:

`unpcklps` interleaves the lower halves
`unpckhps` interleaves the upper halves


Second Stage: We use movlhps and movhlps to complete the transpose:

`movlhps` moves the low part of one register to the high part of another
`movhlps` moves the high part of one register to the low part of another

```jai
transpose_4x4 :: (matrix: *Matrix4) {
    // Load the 4 rows into SIMD registers
    ptr := *matrix.data[0][0];

    #asm {
        // Load all 4 rows
        row0: vec;
        row1: vec;
        row2: vec;
        row3: vec;

        movups.x row0, [ptr];
        add ptr, 16;
        movups.x row1, [ptr];
        add ptr, 16;
        movups.x row2, [ptr];
        add ptr, 16;
        movups.x row3, [ptr];

        // Transpose using shuffle operations
        tmp0: vec;
        tmp1: vec;
        tmp2: vec;
        tmp3: vec;

        // First stage: interleave low and high elements
        // unpcklps interleaves the low parts
        // unpckhps interleaves the high parts
        movaps.x tmp0, row0;
        movaps.x tmp2, row2;
        unpcklps.x tmp0, row1;  // tmp0 = [a0 b0 a1 b1]
        unpckhps.x row0, row1;  // row0 = [a2 b2 a3 b3]
        unpcklps.x tmp2, row3;  // tmp2 = [c0 d0 c1 d1]
        unpckhps.x row2, row3;  // row2 = [c2 d2 c3 d3]

        // Second stage: complete the transpose
        movaps.x tmp1, tmp0;
        movaps.x tmp3, row0;

        movlhps tmp0, tmp2;   // Final row 0
        movhlps tmp2, tmp1;   // Final row 1
        movlhps row0, row2;   // Final row 2
        movhlps row2, tmp3;   // Final row 3

        // Store results back
        sub ptr, 48;  // Reset pointer to start
        movups.x [ptr], tmp0;
        add ptr, 16;
        movups.x [ptr], tmp2;
        add ptr, 16;
        movups.x [ptr], row0;
        add ptr, 16;
        movups.x [ptr], row2;
    }
}
```


# Complex Numbers

A complex number is a number that combines a real part and an imaginary part. It is expressed in the form: `a + bi` where:
* a is the real part
* b is the imaginary part
* i is the imaginary unit, defined as the square root of -1

We can define complex numbers using the following struct:
```jai
Complex :: struct {
    real: float;
    imaginary: float;
}
```

## Complex Number Addition
We can define complex number addition using operator overloading. Add the corresponding real and imaginary member fields together.
```jai
operator + :: (a: Complex, b: Complex) -> Complex {
    c: Complex;
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```
## Complex Number Subtraction
We can define complex number subtraction using operator overloading. Subtract the corresponding real and imaginary member fields together.
```jai
operator - :: (a: Complex, b: Complex) -> Complex {
    c: Complex;
    c.real = a.real - b.real;
    c.imaginary = a.imaginary - b.imaginary;
    return c;
}
```

## Complex Number Multiplication
We can define complex number multiplication using operator overloading. Calculate the multiplication of the square roots of -1 and the multiplication of real and imaginary values when multiplying.
```jai
operator * :: (a: Complex, b: Complex) -> Complex {
    c: Complex;
    c.real = (a.real * b.real) - (a.imaginary * b.imaginary);
    c.imaginary = (a.real * b.imaginary) + (a.imaginary * b.real);
    return c;
}
```

# Integer 128
For most cases, 64 bit integer values are enough to represent a number range. However, some programs need to represent integer values that go beyond the normal 64 bit range.

We can define a unsigned 128 bit integer as a struct of two 64 bit integers.
```jai
U128 :: struct {
    low: u64;
    high: u64;
}
```

## 128 Bit Integer Addition
We can use the `adc` x86-64 assembly instruction and utilize the carry flag to carry over any significant bits that were dropped by the integer overflow of the low portion of `U128`.
```jai
operator + :: (a: U128, b: U128) -> U128 {
    c_low  := a.low;
    c_high := a.high;
    b_low  := b.low;
    b_high := b.high;
    #asm {
         add c_low, b_low;
         adc c_high, b_high;
    }
    c: U128;
    c.low = c_low;
    c.high = c_high;
    return c;
}
```
We can use the `adc` x86-64 assembly instruction and utilize the carry flag to carry over any significant bits that were dropped by the integer overflow of adding a `U128` and `U64`.
```jai
operator + :: (a: U128, b: u64) -> U128 {
    c_low  := a.low;
    c_high := a.high;
    #asm {
         add c_low, b;
         adc c_high, 0;
    }
    c: U128;
    c.low = c_low;
    c.high = c_high;
    return c;
}
```
## 128 Bit Integer Subtraction
We can use the `sbb` x86-64 assembly instruction and utilize the carry flag to carry over any significant bits that were dropped by the integer underflow of the low portion of `U128`.
```jai
operator - :: (a: U128, b: U128) -> U128 {
    c_low  := a.low;
    c_high := a.high;
    b_low  := b.low;
    b_high := b.high;
    #asm {
         sub c_low, b_low;
         sbb c_high, b_high;
    }
    c: U128;
    c.low = c_low;
    c.high = c_high;
    return c;
}
```
We can use the `sbb` x86-64 assembly instruction and utilize the carry flag to carry over any significant bits that were dropped by the integer underflow of subtracting a `U128` and `U64`.
```jai
operator - :: (a: U128, b: u64) -> U128 {
    c_low  := a.low;
    c_high := a.high;
    #asm {
         sub c_low, b;
         sbb c_high, 0;
    }
    c: U128;
    c.low = c_low;
    c.high = c_high;
    return c;
}
```

## 128 Bit Integer AND
We can define a bitwise AND overload by applying AND on each values' respectively low and high integer data members.
```jai
operator & :: (a: U128, b: U128) -> U128 {
    c: U128;
    c.low = a.low & b.low;
    c.high = a.high & b.high;
    return c;
}
```

## 128 Bit Integer OR
We can define a bitwise OR overload by applying OR on each values' respectively low and high integer data members.
```jai
operator | :: (a: U128, b: U128) -> U128 {
    c: U128;
    c.low = a.low | b.low;
    c.high = a.high | b.high;
    return c;
}
```

## 128 Bit Integer XOR
We can define a bitwise OR overload by applying OR on each values' respectively low and high integer data members.
```jai
operator ^ :: (a: U128, b: U128) -> U128 {
    c: U128;
    c.low = a.low ^ b.low;
    c.high = a.high ^ b.high;
    return c;
}
```

## 128 Bit Integer Equals
We can define a equality operator `==` overload by checking if both values' respective low and high integer data members are equivalent.

```jai
operator == :: inline (a: U128, b: U128) -> bool {
    return (a.low == b.low) && (a.high == b.high);
}
```

## 128 Bit Integer Not
We can define a Not operator `!` overload by checking if low and high integer data members are both zero. If both are zero, return true, else return false.
```jai
operator ! :: inline (a: S128) -> bool {
    return a.low == 0 && a.high == 0;
}
```

--- End of file: documents/17_operator_overloading_for_math.md ---

--- Start of file: documents/18_polymorphic_algorithms.md ---
# Basic Polymorphism

## Polymorphic Add
A polymorphic add returns the sum of two elements of the same datatype. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
add :: (a: $T, b: T) -> T {
    return a + b;
}
```
## Polymorphic Sub
A polymorphic sub returns the difference of two elements of the same datatype. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
sub :: (a: $T, b: T) -> T {
    return a + b;
}
```
## Polymorphic Multiply
A polymorphic multiply returns the product of two elements of the same datatype. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
multiply :: (a: $T, b: T) -> T {
    return a * b;
}
```

## Polymorphic Divide
A polymorphic divide returns the division of two elements of the same datatype. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
divide :: (a: $T, b: T) -> T {
    return a / b;
}
```

## Polymorphic Max
A polymorphic max returns the greater of two elements. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
max :: (a: $T, b: T) -> T {
    if a > b return a;
    return b;
}
```

## Polymorphic Min
A polymorphic min returns the greater of two elements. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
min :: (a: $T, b: T) -> T {
    if a < b return a;
    return b;
}
```

## Polymorphic Absolute Value
A polymorphic absolute value function that transforms a negative value into a positive value and leaves the positive value alone. This function generalizes across all sorts of different number types such as `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
abs :: (x: $T) -> T {
    if x < 0 {
        x = -x;
    }

    return x;
}
```

## Polymorphic Linear Search

A linear search that iterates across an array to find a value that is equivalent to the provided given parameter.
```jai
linear_search :: (array: [] $T, value: T) -> int {
    for ele, i : array {
        if ele == value {
            return i;
        }
    }
    return -1;
}
```

## Polymorphic Clamp
Clamping is the process of limiting a value to a range between a minimum and a maximum value. As a polymorphic procedure, this function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
clamp :: (a: $T, min: T, max: T) -> T {
    if a < min {
        return min;
    }
    if a > max {
        return max;
    }
    return a;
}
```

## Polymorphic Reverse

A function to reverse all elements in the array such that the first element is the last element and vice versa.
```jai
reverse :: (array: [] $T) {
    begin := 0;
    end := array.count - 1;
    while begin < end {
        array[begin], array[end] = array[end], array[begin];
        begin += 1;
        end -= 1;
    }
}
```

## Polymorphic Fill
This function fills an entire array with a specified value.
```jai
fill :: (array: [] $T, value: T) {
    for *element: array {
        element.* = value;
    }
}
```

## Polymorphic Count Occurances
This function counts how many times a value appears in an array.
```jai
count_occurrences :: (array: []$T, value: T) -> int {
    count := 0;
    for element: array {
        if element == value {
            count += 1;
        }
    }
    return count;
}
```

## Polymorphic Sum of Array Elements
This function calculates the sum of all elements in an array.
```jai
sum :: (array: []$T) -> T {
    total: T = 0;
    for element: array {
        total += element;
    }
    return total;
}
```

## Polymorphic Average of Array Elements
This function calculates the average value of array elements.
```jai
average :: (array: []$T) -> T {
    if array.count == 0 return 0;
    
    total: T = 0;
    for element: array {
        total += element;
    }
    return total / cast(T)array.count;
}
```


## Polymorphic Array Shuffle

This is some code to shuffle an array using the Fischer-Yates shuffle algorithm. One can define a `random_s64` function to make the casting to make the code more aesthetically pleasing to read. This algorithm works across of sorts of different data types, e.g. floats, integers, strings, user defined objects, etc.

```jai
random_s64 :: () -> s64 {
    r := (random_get() & 0x7FFF_FFFF);
    return cast(s64)r;
}

shuffle :: (array: [] $T) {
    N := array.count - 1;
    for < i : 1..N {
        r := random_s64() % i;
        array[i], array[r] = array[r], array[i];
    }
}
```

Here is a while loop version of the code:
```jai
shuffle :: (array: [] $T) {
    i := array.count - 1;
    while i >= 1 {
        r := random_s64() % i;
        array[i], array[r] = array[r], array[i];
        i -= 1;
    }
}
```

# Polymorphic Sorting Algorithms

## Bubble Sort

We can use the `$T` to indicate that a type is polymorphic. We can transform a bubble sort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.

```jai
bubble_sort :: (array:[] $T, $comparison: (T, T) -> bool) {

    sorted := false;

    while !sorted {
        i := 0;
        j := 1;
        sorted = true;
        while j < array.count {
            if comparison(array[j], array[i]) {
                array[j], array[i] = array[i], array[j];
                sorted = false;
            }
            i += 1;
            j += 1;
        }
    }
}
```

We call the same bubble sort for both integer and float types, and do both ascending and descending sort.
```jai
main :: () {
    // array of integers
    array_integers := int.[1, 3, 2, 5, 4, 6, 9, 8, 7];

    // sort ascending
    bubble_sort(array_integers, (a,b) => a < b);
    print("%\n", array_integers);

    // sort descending
    bubble_sort(array_integers, (a,b) => a > b);
    print("%\n", array_integers);

    // array of floats
    array_floats := float.[1.5, 3.2, 2.1, 0.75, 4.8, 9.6, 10.9, 8.3, 7.2];

    // sort ascending
    bubble_sort(array_floats, (a,b) => a < b);
    print("%\n", array_floats);

    // sort descending
    bubble_sort(array_floats, (a,b) => a > b);
    print("%\n", array_floats);

    // array of strings
    array_strings := string.["zoo", "apple", "boy", "mummy", "king", "camel"];

    // sort strings in alphabetical order.
    bubble_sort(array_strings, (a,b) => compare(a,b) == -1);
    print("%\n", array_strings);
}
```

We can apply our sort on custom structs such as the follow `Person` struct and use bubble sort to sort the `Person` arrays by age or arrange the `Person` array in alphabetical order.
```jai
Person :: struct {
    name: string;
    age: int;
}

main :: () {
    people: [5] Person;
    people[0] = .{"Alice", 30};
    people[1] = .{"Bob", 25};
    people[2] = .{"Charlie", 35};
    people[3] = .{"Diana", 28};
    people[4] = .{"Eve", 22};

    // Sort by age
    print("Original:\n");
    for people {
        print("  % (age %)\n", it.name, it.age);
    }

    bubble_sort(people, (a, b) => a.age < b.age);
    print("\nSorted by age:\n");
    for people {
        print("  % (age %)\n", it.name, it.age);
    }

    // Sort by name
    bubble_sort(people, (a, b) => compare(a.name, b.name) == -1);
    print("\nSorted by name:\n");
    for people {
        print("  % (age %)\n", it.name, it.age);
    }
}

```


## Insertion Sort

We can use the `$T` to indicate that a type is polymorphic. We can transform an insertion sort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.

```jai
insertion_sort :: (array: [] $T, $compare: (T, T) -> bool) {
    i := 1;
    while i < array.count {
        key := array[i];
        j := i - 1;
        while j >= 0 && compare(key, array[j]) {
            array[j + 1] = array[j];
            j -= 1;
        }
        array[j + 1] = key;
        i += 1;
    }
}
```

We call the same insertion sort for both integer and float types.

```jai
main :: () {
    array_integers := int.[5,3,6,7,1,2];
    insertion_sort(array_integers, (a,b) => a < b);
    print("%\n", array_integers);

    array_floats := float.[3.14, 97.3, 60.3, 4.5, 1.2];
    insertion_sort(array_floats, (a,b) => a < b);
    print("%\n", array_floats);
}
```
## Selection Sort

We can use the `$T` to indicate that a type is polymorphic. We can transform a selection sort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.
```jai
selection_sort :: (array: [] $T, $compare: (T, T) -> bool) {
    N := array.count - 1;
    for i : 0..N {
        ele := i;
        for j : (i+1)..N {
            if compare(array[j], array[ele]) {
                ele = j;
            }
        }
        array[ele], array[i] = array[i], array[ele];
    }

}
```
We call the same selection sort for both integer and float types.
```jai
main :: () {
    array_integers := int.[5,3,6,7,1,2];
    selection_sort(array_integers, (a,b) => a < b);
    print("%\n", array_integers);

    array_floats := float.[3.14, 97.3, 60.3, 4.5, 1.2];
    selection_sort(array_floats, (a,b) => a < b);
    print("%\n", array_floats);
}
```

## Heapsort
We can use the `$T` to indicate that a type is polymorphic. We can transform a heapsort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.
```jai
heapsort :: (array: [] $T, $compare: (T,T)->bool) {
    heapify(array, compare);
    end := array.count;
    while end > 1 {
        end -= 1;
        array[end], array[0] = array[0], array[end];
        sift_down(array, 0, end, compare);
    }
}

heapify :: (array: [] $T, $compare: (T,T)->bool) {
    start := parent(array.count - 1) + 1;
    while start > 0 {
        start -= 1;
        sift_down(array, start, array.count, compare);
    }
}

sift_down :: (array: [] $T, root: int, end: int, $compare: (T,T)->bool) {
    while left_child(root) < end {
        child := left_child(root);
        if (child + 1) < end && compare(array[child], array[child + 1]) {
             child += 1;
        }

        if compare(array[root], array[child]) {
            array[root], array[child] = array[child], array[root];
            root = child;
        } else {
            return;
        }
    }
}

left_child :: (i: int) -> int {
    return (2 * i) + 1;
}

right_child :: (i: int) -> int {
    return (2 * i) + 2;
}

parent :: (i: int) -> int {
    return (i - 1) / 2;
}
```
We call the same polymorphic merge sort code for both floats and integers. This mergesort generalizes across many different types and avoids code duplication across different data types.
```jai
main :: () {
    array_integers := int.[5, 1, 7, 2, 4, 3, 6, 8, 9];
    heapsort(array_integers, (a,b) => a < b);
    print("array_integers = %\n", array_integers);

    array_floats := float.[5.9, 1.23, 7.3, 2.4, 4.8, 6.99, 9.3, 21.1, 3.3];
    heapsort(array_floats, (a,b) => a < b);
    print("array_floats = %\n", array_floats);

}
```


## Mergesort
We can use the `$T` to indicate that a type is polymorphic. We can transform a mergesort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.
```jai
merge_sort :: (arr: [] $T, $compare: (T,T) -> bool) {
    // Merge two subarrays L and M into arr
    merge :: (arr: [] $T, p: int, q: int, r: int, $compare: (T,T) -> bool) {
        n1 := q - p + 1;
        n2 := r - q;
        L := NewArray(n1, int);
        M := NewArray(n2, int);

        for i : 0..(n1-1) {
            L[i] = arr[p + i];
        }

        for j : 0..(n2-1) {
            M[j] = arr[q + 1 + j];
        }

        // Maintain current index of sub-arrays and main array
        i := 0;
        j := 0;
        k := p;
        while i < n1 && j < n2 {
            if compare(L[i], M[j]) {
                arr[k] = L[i];
                i += 1;
            } else {
                arr[k] = M[j];
                j += 1;
            }
            k += 1;
        }

        while i < n1 {
            arr[k] = L[i];
            i += 1;
            k += 1;
        }

        while (j < n2) {
            arr[k] = M[j];
            j += 1;
            k += 1;
        }
    }

    merge_sort_helper :: (arr: [] $T, l: int, r: int, $compare: (T,T) -> bool) {
        if l < r {
            m := l + (r - l) / 2;
            merge_sort_helper(arr, l, m, compare);
            merge_sort_helper(arr, m + 1, r, compare);
            merge(arr, l, m, r, compare);
        }
    }

    merge_sort_helper(arr, 0, arr.count - 1, compare);
}
```
We call the same polymorphic merge sort code for both ascending and descending arrays. This mergesort generalizes across many different types and avoids code duplication.
```jai
main :: () {
  arr := int.[6, 5, 12, 10, 9, 1];
  merge_sort(arr, (a,b) => a < b);
  print("Sort Ascending: %\n", arr);

  merge_sort(arr, (a,b) => a > b);
  print("Sort Descending: %\n", arr);
}
```

## Quicksort
We can use the `$T` to indicate that a type is polymorphic. We can transform a quicksort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.
```jai
quicksort :: (array: [] $T, $compare: (T,T) -> bool) {

    partition :: (array: [] $T, low: int, high: int, $compare: (T,T) -> bool) -> int {
        pivot := array[high];

        i := low;
        j := low;
        while j < high {
            if compare(array[j], pivot) {
                array[i], array[j] = array[j], array[i];
                i += 1;
            }
            j += 1;
        }
        array[i], array[high] = array[high], array[i];
        return i;
    }

    quicksort_helper :: (array: [] $T, low: int, high: int, $compare: (T,T) -> bool) {
        if (low >= high || low < 0) {
            return;
        }

        p := partition(array, low, high, compare);
        quicksort_helper(array, low, p - 1, compare);
        quicksort_helper(array, p + 1, high, compare);
    }

    quicksort_helper(array, 0, array.count - 1, compare);
}
```
We call the same quicksort for both integer and float types.
```jai
main :: () {
    array_integers := int.[5,3,6,7,1,2];
    quicksort(array_integers, (a,b) => a < b);
    print("%\n", array_integers);

    array_floats := float.[3.14, 97.3, 60.3, 4.5, 1.2];
    quicksort(array_floats, (a,b) => a < b);
    print("%\n", array_floats);
}
```

# Higher Order Functions

## Map
Map is a higher-order function that applies a given function to each element of a data structure. One can write a basic map in the following way. 

```jai
map :: (array: [] $T, $function: (T) -> T) -> [] T {
    answer := NewArray(array.count, T);
    N := array.count - 1;
    for i : 0..N {
        answer[i] = function(array[i]);
    }
    return answer;
}

main :: () {
    array := map(int.[1,2,3,4,5], (x) => (x + 1));
    print("%\n", array);

    array = map(int.[1,2,3,4,5], (x) => (x * 2));
    print("%\n", array);
}
```

## Filter

Filter is a higher-order function that iterates through a data structure and produces a new data structure containing only the elements that satisfies the given function conditional as `true`.

```jai
filter :: (array: [] $T, $function: (T) -> bool) -> [] T {
    answer: [..] T;
    for ele : array {
        if function(ele) {
            array_add(*answer, ele);
        }
    }
    return answer;
}


main :: () {
    // filter to get only odd numbers
    array := filter(int.[1,2,3,4,5,6,7,8,9,10], (x) => (x % 2) != 0);
    print("%\n", array);

    // filter to get only even numbers
    array = filter(int.[1,2,3,4,5,6,7,8,9,10], (x) => (x % 2) == 0);
    print("%\n", array);
}
```

## Reduce

Reduce is a higher-order function that iterates through a data structure and produces a value based the interaction of the elements of the array and the element being computed.

```jai
reduce :: (array: [] $T, $function: (T,T) -> T) -> T {
    answer: T;
    for ele : array {
        answer = function(answer, ele);
    }
    return answer;
}

main :: () {
    array_integer := int.[1,2,3,4,5];
    answer1 := reduce(array_integer, (a,b) => (a + b));
    print("%\n", answer1);

    array_string := string.["The", "lazy", "fox"];
    answer2 := reduce(array_string, (a,b) => join(a, b, " "));
    print("%\n", answer2);
}
```


--- End of file: documents/18_polymorphic_algorithms.md ---

--- Start of file: documents/19_polymorphic_data_structures.md ---
# Polymorphic Linked List

A polymorphic linked list can be defined by using a parenthesized struct with type parameters `T: Type`. To specify a different linked list type, just change the `T: Type` parameter to match what one desires. This approach allows one to create linked lists of integers, floats, strings, etc. and generalize the linked list data structure across all different types.
```jai
Node :: struct(T: Type) {
    data: T;
    next: *Node(T);
}
```

## Print Linked List 1

Given Linked List definition above, one can write a polymorphic print linked list function and specific `$T` parameter to allow the type of the function to be determined at compile time.
```jai
print_linked_list :: (node: *Node($T)) {
    print("[");
    while node {
        print("%, ", node.data);
        node = node.next;
    }
    print("]\n");
}
```
## Print Linked List 2

This is another polymorphic print linked list, but instead of parameterizing the Node parameter the `$T`, one parameterizes the entire struct. This has the same functionality of the previous print, but slightly different error messages.
```jai
print_linked_list :: (node: *$T/Node) {
    print("[");
    while node {
        print("%, ", node.data);
        node = node.next;
    }
    print("]\n");
}
```

## Print Linked List 3
This is a implicit polymorphism version of the print linked list function. This functions exactly the same as previous functions, except the polymorphism is implicit rather than explicit. Implicit polymorphism allows easy conversion of functions manipulating data structures into polymorphic functions, reducing friction when refactoring code into more polymorphic code.
```jai
print_linked_list :: (node: *Node) {
    print("[");
    while node {
        print("%, ", node.data);
        node = node.next;
    }
    print("]\n");
}
```

## Instantiating a node
This function instantiates a polymorphic linked list node. This function generalizes across all different types of nodes.
```jai
create_node :: (value: $T) -> *Node(T) {
    node := New(Node(T));
    node.data = value;
    node.next = null;
    return node;
}
```

## Append Front 1
Append front can be transformed into a polymorphic function in the following way.
```jai
append_front :: (head: **Node($T), data: T) {
    new_node := New(Node(T));
    new_node.data = data;
    new_node.next = head.*;
    head.* = new_node;
}
```

## Append Front 2
One can switch around the `$T` to the second parameter if one wants to.
```jai
append_front :: (head: **Node(T), data: $T) {
    new_node := New(Node(T));
    new_node.data = data;
    new_node.next = head.*;
    head.* = new_node;
}
```

## Append Front 3
This is another way of writing a polymorphic append front.
```jai
append_front :: (head: **$T/Node, data: T.T) {
    new_node := New(Node(T.T));
    new_node.data = data;
    new_node.next = head.*;
    head.* = new_node;
}
```

## Append 1
Append can be made into a polymorphic function using the following method.
```jai
// create a node at the end of the list.
append :: (head: *Node($T), data: T) {
    assert(head != null);
    // initialize new node to append.
    new_node := New(Node(T));
    new_node.data = data;
    new_node.next = null;

    // traverse to the end of linked list.
    while(head.next) {
        head = head.next;
    }

    // append to the end of linked list.
    head.next = new_node;
}
```

## Append 2
Append can be made into a polymorphic function using the following method.
```jai
// create a node at the end of the list.
append :: (head: *Node, data: head.T) {
    assert(head != null);
    // initialize new node to append.
    new_node := New(Node(head.T));
    new_node.data = data;
    new_node.next = null;

    // traverse to the end of linked list.
    while(head.next) {
        head = head.next;
    }

    // append to the end of linked list.
    head.next = new_node;
}
```

## Insert Sorted 1
This function inserts an element into a sorted linked list. This polymorphic function applies the `$T` on the Node parameterized struct.
```jai
insert_sorted :: (head: **Node($T), value: T) {
    new_node := create_node(value);

    // Empty list or insert at beginning
    if !head.* || head.*.data >= value {
        new_node.next = head.*;
        head.* = new_node;
        return;
    }

    // Find insertion point
    current := head.*;
    while current.next && current.next.data < value {
        current = current.next;
    }

    // Insert after current
    new_node.next = current.next;
    current.next = new_node;
}
```

## Insert Sorted 2
This is another function that inserts an element into a sorted linked list.
```jai
insert_sorted2 :: (head: **$T/Node, value: T.T) {
    new_node := create_node(value);

    // Empty list or insert at beginning
    if !head.* || head.*.data >= value {
        new_node.next = head.*;
        head.* = new_node;
        return;
    }

    // Find insertion point
    current := head.*;
    while current.next && current.next.data < value {
        current = current.next;
    }

    // Insert after current
    new_node.next = current.next;
    current.next = new_node;
}
```

## Remove Value 1
This function traverses a linked list and removes all occurrences of a value from a linked list. This is a polymorphic function that uses `$T` polymorphism.
```jai
remove_value :: (head: *Node($T), value: T) {
    if !head return;
    previous := head;
    current  := previous.next;
    while current {
        if current.data == value {
            previous.next = current.next;
        } else {
            previous = previous.next;
        }
        current = current.next;
    }
}
```
## Remove Value 2
This function traverses a linked list and removes all occurrences of a value from a linked list. This is another version of the polymorphic function.
```jai
remove_value :: (head: *$T/Node, value: T.T) {
    if !head return;
    previous := head;
    current  := previous.next;
    while current {
        if current.data == value {
            previous.next = current.next;
        } else {
            previous = previous.next;
        }
        current = current.next;
    }
}
```
## Remove Value 3
This function traverses a linked list and removes all occurrences of a value from a linked list. This is function that takes advantage of implicit polymorphism.
```jai
remove_value3 :: (head: *Node, value: head.T) {
    if !head return;
    previous := head;
    current  := previous.next;
    while current {
        if current.data == value {
            previous.next = current.next;
        } else {
            previous = previous.next;
        }
        current = current.next;
    }
}
```
## Search 1
This is a polymorphic linked list search function where the Node has a polymorphic parameter `$T`.
```jai
search :: (head: *Node($T), value: T) -> *Node(T) {
    current := head;
    while current {
        if current.data == value {
            return current;
        }
        current = current.next;
    }
    return null;
}
```

## Search 2
This is a polymorphic linked list search function where `$T` must be a parameterized struct of type `Node`.
```jai
search :: (head: *$T/Node, value: T.T) -> *T {
    current := head;
    while current {
        if current.data == value {
            return current;
        }
        current = current.next;
    }
    return null;
}
```

## Search 3
This is a polymorphic linked list search function using implicit polymorphism.
```jai
search :: (head: *Node, value: head.T) -> type_of(head) {
    current := head;
    while current {
        if current.data == value {
            return current;
        }
        current = current.next;
    }
    return null;
}
```

## Length 1
This is a polymorphic linked list length function where the Node has a polymorphic parameter `$T`.
```jai
length :: (head: *Node($T)) -> int {
    count := 0;
    current := head;
    while current {
        count += 1;
        current = current.next;
    }
    return count;
}
```

## Length 2
This is a polymorphic linked list length function where `$T` must be a parameterized struct of type `Node`.
```jai
length :: (head: *$T/Node) -> int {
    count := 0;
    current := head;
    while current {
        count += 1;
        current = current.next;
    }
    return count;
}
```

## Length 3
This is a polymorphic linked list length function using implicit polymorphism.
```jai
length :: (head: *Node) -> int {
    count := 0;
    current := head;
    while current {
        count += 1;
        current = current.next;
    }
    return count;
}
```

## Reverse 1
This is a polymorphic linked list reverse function where the Node has a polymorphic parameter `$T`.
```jai
reverse1 :: (head: **Node($T)) {
    previous: *Node(T) = null;
    current := head.*;
    while current {
        next := current.next;
        current.next = previous;
        previous = current;
        current = next;
    }
    head.* = previous;
}
```
## Reverse 2
This is a polymorphic linked list reverse function where `$T` must be a parameterized struct of type `Node`.
```jai
reverse :: (head: **$T/Node) {
    previous: *T = null;
    current := head.*;

    while current {
        next := current.next;
        current.next = previous;
        previous = current;
        current = next;
    }
    head.* = previous;
}
```
## Reverse 3
This is a polymorphic linked list reverse function using implicit polymorphism.
```jai
reverse :: (head: **Node) {
    previous: type_of(head.*) = null;
    current := head.*;
    while current {
        next := current.next;
        current.next = previous;
        previous = current;
        current = next;
    }
    head.* = previous;
}
```

# Polymorphic Tree
A binary tree is a hierarchical data structure where each node has at most two children: a left child and a right child. In Jai, we can implement this elegantly using structs and pointers.

```jai
Tree :: struct(T: Type) {
    data: T;
    left:  *Tree(T);
    right: *Tree(T);
}
```

## Create Node
This function allocates a new tree node on the heap and initializes it with the given value.
```jai
create_node :: (value: $T) -> *Tree(T) {
    node := New(Tree(T));
    node.data = value;
    node.left = null;
    node.right = null;
    return node;
}
```

## Insert 1
This is a polymorphic tree insert function where the Node has a polymorphic parameter `$T`.
```jai
insert :: (root: **Tree($T), value: T) {
    // If tree is empty, create the root
    if !root.* {
        root.* = create_node(value);
        return;
    }

    // Recursively find the correct position
    if value < root.*.data {
        insert(*root.*.left, value);
    } else if value > root.*.data {
        insert(*root.*.right, value);
    }
    // If value equals data, we don't insert duplicates
}
```

## Insert 2
This is a polymorphic insert function where `$T` must be a parameterized struct of type `Tree`.
```jai
insert :: (root: **$T/Tree, value: T.T) {
    // If tree is empty, create the root
    if !root.* {
        root.* = create_node(value);
        return;
    }

    // Recursively find the correct position
    if value < root.*.data {
        insert(*root.*.left, value);
    } else if value > root.*.data {
        insert(*root.*.right, value);
    }
    // If value equals data, we don't insert duplicates
}
```

## Insert 3
This is a polymorphic insert function which uses implicit polymorphism.
```jai
insert :: (root: **Tree, value: type_of(root.*.data)) {
    // If tree is empty, create the root
    if !root.* {
        root.* = create_node(value);
        return;
    }

    // Recursively find the correct position
    if value < root.*.data {
        insert(*root.*.left, value);
    } else if value > root.*.data {
        insert(*root.*.right, value);
    }
    // If value equals data, we don't insert duplicates
}
```

## Traverse Inorder 1
This is a polymorphic inorder tree traversal where the Tree has a polymorphic parameter `$T`.
```jai
traverse_inorder :: (root: *Tree($T)) {
    if !root return;
    traverse_inorder(root.left);
    print("% ", root.data);
    traverse_inorder(root.right);
}
```
## Traverse Inorder 2
This is a polymorphic inorder tree traversal where `$T` must be a parameterized struct of type `Tree`.
```jai
traverse_inorder :: (root: *$T/Tree) {
    if !root return;
    traverse_inorder(root.left);
    print("% ", root.data);
    traverse_inorder(root.right);
}
```
## Traverse Inorder 3
This is a polymorphic inorder tree traversal function which uses implicit polymorphism.
```jai
traverse_inorder :: (root: *Tree) {
    if !root return;
    traverse_inorder(root.left);
    print("% ", root.data);
    traverse_inorder(root.right);
}
```
## Traverse Preorder 1
This is a polymorphic preorder tree traversal where the Tree has a polymorphic parameter `$T`.
```jai
traverse_preorder :: (root: *Tree($T)) {
    if !root return;
    print("% ", root.data);
    traverse_preorder(root.left);
    traverse_preorder(root.right);
}
```
## Traverse Preorder 2
This is a polymorphic preorder tree traversal where `$T` must be a parameterized struct of type `Tree`.
```jai
traverse_preorder :: (root: *$T/Tree) {
    if !root return;
    print("% ", root.data);
    traverse_preorder(root.left);
    traverse_preorder(root.right);
}
```
## Traverse Preorder 3
This is a polymorphic preorder tree traversal function which uses implicit polymorphism.
```jai
traverse_preorder :: (root: *Tree) {
    if !root return;
    print("% ", root.data);
    traverse_preorder(root.left);
    traverse_preorder(root.right);
}
```
## Traverse Postorder 1
This is a polymorphic postorder tree traversal where the Tree has a polymorphic parameter `$T`.
```jai
traverse_postorder :: (root: *Tree($T)) {
    if !root return;
    traverse_postorder(root.left);
    traverse_postorder(root.right);
    print("% ", root.data);
}
```
## Traverse Postorder 2
This is a polymorphic postorder tree traversal where `$T` must be a parameterized struct of type `Tree`.
```jai
traverse_postorder :: (root: *$T/Tree) {
    if !root return;
    traverse_postorder(root.left);
    traverse_postorder(root.right);
    print("% ", root.data);
}
```
## Traverse Postorder 3
This is a polymorphic postorder tree traversal function which uses implicit polymorphism.
```jai
traverse_postorder :: (root: *Tree) {
    if !root return;
    traverse_postorder(root.left);
    traverse_postorder(root.right);
    print("% ", root.data);
}
```

## Search 1
This is a polymorphic tree search where the Tree has a polymorphic parameter `$T`.
```jai
search :: (root: *Tree($T), value: T) -> *Tree(T) {
    // Base cases: empty tree or value found
    if !root || root.data == value {
        return root;
    }

    // Value is smaller, search left subtree
    if value < root.data {
        return search(root.left, value);
    }

    // Value is larger, search right subtree
    return search(root.right, value);
}
```
## Search 2
This is a polymorphic tree search where `$T` must be a parameterized struct of type `Tree`.
```jai
search :: (root: *$T/Tree, value: T.T) -> *T {
    // Base cases: empty tree or value found
    if !root || root.data == value {
        return root;
    }

    // Value is smaller, search left subtree
    if value < root.data {
        return search(root.left, value);
    }

    // Value is larger, search right subtree
    return search(root.right, value);
}
```
## Search 3
This is a polymorphic tree search function which uses implicit polymorphism.
```jai
search :: (root: *Tree, value: root.T) -> type_of(root) {
    // Base cases: empty tree or value found
    if !root || root.data == value {
        return root;
    }

    // Value is smaller, search left subtree
    if value < root.data {
        return search(root.left, value);
    }

    // Value is larger, search right subtree
    return search(root.right, value);
}
```

## Find Minimum 1
This function finds the tree node with the smallest value of a binary search tree. This is a polymorphic function where the Tree has a polymorphic parameter `$T`.
```jai
find_minimum :: (root: *Tree($T)) -> *Tree(T) {
    if !root return null;
    // Keep going left until we can't anymore
    while root.left {
        root = root.left;
    }
    return root;
}
```
## Find Minimum 2
This function finds the tree node with the smallest value of a binary search tree. This is a polymorphic tree search where `$T` must be a parameterized struct of type `Tree`.
```jai
find_minimum :: (root: *$T/Tree) -> *T {
    if !root return null;
    // Keep going left until we can't anymore
    while root.left {
        root = root.left;
    }
    return root;
}
```
## Find Minimum 3
This function finds the tree node with the smallest value of a binary search tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
find_minimum :: (root: *Tree) -> type_of(root) {
    if !root return null;
    // Keep going left until we can't anymore
    while root.left {
        root = root.left;
    }
    return root;
}
```

## Find Maximum 1
This function finds the tree node with the largest value of a binary search tree. This is a polymorphic function where the Tree has a polymorphic parameter `$T`.
```jai
find_maximum :: (root: *Tree($T)) -> *Tree(T) {
    if !root return null;
    // Keep going right until we can't anymore
    while root.right {
        root = root.right;
    }
    return root;
}
```
## Find Maximum 2
This function finds the tree node with the largest value of a binary search tree. This is a polymorphic tree search where `$T` must be a parameterized struct of type `Tree`.
```jai
find_maximum :: (root: *$T/Tree) -> *T {
    if !root return null;
    // Keep going right until we can't anymore
    while root.right {
        root = root.right;
    }
    return root;
}
```
## Find Maximum 3
This function finds the tree node with the largest value of a binary search tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
find_maximum :: (root: *Tree) -> type_of(root) {
    if !root return null;
    // Keep going right until we can't anymore
    while root.right {
        root = root.right;
    }
    return root;
}
```

## Delete Node
Delete a node from the tree while maintaining the binary search tree correctness. This takes advantage of implicit polymorphism to generalize this function across all polymorphic Tree data structures.
```jai
delete :: (root: **Tree, value: type_of(root.*.data)) {
    if !root.* return;
    if value < root.*.data {
        delete(*root.*.left, value);
    } else if value > root.*.data {
        delete(*root.*.right, value);
    } else {
        node := root.*;
        // Case 1: No children (leaf node)
        if !node.left && !node.right {
            free(node);
            root.* = null;
        }
        // Case 2: Only right child
        else if !node.left {
            root.* = node.right;
            free(node);
        }
        // Case 2: Only left child
        else if !node.right {
            root.* = node.left;
            free(node);
        }
        // Case 3: Two children
        else {
            // Find the minimum value in right subtree (in-order successor)
            successor := find_minimum(node.right);

            // Copy the successor's value to this node
            node.data = successor.data;

            // Delete the successor
            delete(*node.right, successor.data);
        }
    }
}
```

## Count Nodes 1
This function counts the number of nodes in a tree. This is a polymorphic function where the Tree has a polymorphic parameter `$T`.
```jai
count_nodes :: (root: *Tree($T)) -> int {
    if !root return 0;
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```
## Count Nodes 2
This function counts the number of nodes in a tree. This is a polymorphic function where `$T` must be a parameterized struct of type `Tree`.
```jai
count_nodes :: (root: *$T/Tree) -> int {
    if !root return 0;
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```
## Count Nodes 3
This function counts the number of node in a tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
count_nodes :: (root: *Tree) -> int {
    if !root return 0;
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```
## Height 1
This function computes the height of a tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
height :: (root: *Tree($T)) -> int {
    if !root return 0;
    left_height := height(root.left);
    right_height := height(root.right);
    return 1 + max(left_height, right_height);
}
```
## Height 2
This function computes the height of a tree. This is a polymorphic function where `$T` must be a parameterized struct of type `Tree`.
```jai
height :: (root: *$T/Tree) -> int {
    if !root return 0;
    left_height := height(root.left);
    right_height := height(root.right);
    return 1 + max(left_height, right_height);
}
```

## Height 3
This function computes the height of a tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
height :: (root: *Tree) -> int {
    if !root return 0;
    left_height := height(root.left);
    right_height := height(root.right);
    return 1 + max(left_height, right_height);
}
```

# Polymorphic Vec3
A polymorphic Vec3 struct that allows for any parameter type for data members `x`, `y`, and `z`.
```jai
Vec3 :: struct(T: Type) {
    x: T;
    y: T;
    z: T;
}
```

## Operator Add 1
This is an operator overloaded `+` for `Vec3`. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
operator + :: (a: Vec3($T), b: Vec3(T)) -> Vec3(T) {
    c: Vec3(T);
    c.x = a.x + b.x;
    c.y = a.y + b.y;
    c.z = a.z + b.z;
    return c;
}
```

## Operator Add 2
This is an operator overloaded `+` for `Vec3`. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec`.
```jai
operator + :: (a: $T/Vec3, b: T) -> T {
    c: Vec3(T.T);
    c.x = a.x + b.x;
    c.y = a.y + b.y;
    c.z = a.z + b.z;
    return c;
}
```

## Operator Sub 1
This is an operator overloaded `-` for `Vec3`. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
operator - :: (a: Vec3($T), b: Vec3(T)) -> Vec3(T) {
    c: Vec3(T);
    c.x = a.x - b.x;
    c.y = a.y - b.y;
    c.z = a.z - b.z;
    return c;
}
```
## Operator Sub 2
This is an operator overloaded `-` for `Vec3`. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec`.
```jai
operator - :: (a: $T/Vec3, b: T) -> T {
    c: Vec3(T.T);
    c.x = a.x - b.x;
    c.y = a.y - b.y;
    c.z = a.z - b.z;
    return c;
}
```

## Operator Negation 1
This is an operator overloaded `-` for `Vec3`. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
operator - :: (a: Vec3($T)) -> Vec3(T) {
    b: Vec3(T);
    b.x = -a.x;
    b.y = -a.y;
    b.z = -a.z;
    return b;
}
```
## Operator Negation 2
This is an operator overloaded `-` for `Vec3`. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec`.
```jai
operator - :: (a: $T/Vec3) -> T {
    b: T;
    b.x = -a.x;
    b.y = -a.y;
    b.z = -a.z;
    return b;
}
```

## Scalar Multiply 1
One can overload the multiplication operator so that Vec3 can support scalar multiplication. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
operator * :: (a: Vec3($T), b: T) -> Vec3(T) #symmetric {
    c: Vec3(T) = a;
    c.x *= b;
    c.y *= b;
    c.z *= b;
    return c;
}
```
## Scalar Multiply 2
One can overload the multiplication operator so that Vec3 can support scalar multiplication. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec3`.
```jai
operator * :: (a: $T/Vec3, b: T.T) -> T #symmetric {
    c: T = a;
    c.x *= b;
    c.y *= b;
    c.z *= b;
    return c;
}
```

## Dot Product 1
Dot Product for Vec3 can be written in the following way. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
dot :: (a: Vec3($T), b: Vec3(T)) -> T {
    c := (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
    return c;
}
```
## Dot Product 2
Dot Product for Vec3 can be written in the following way. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec3`.
```jai
dot :: (a: $T/Vec3, b: T) -> T.T {
    c := (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
    return c;
}
```

# Polymorphic Matrix
A 2D matrix capable of generalizing across different number types `T` such as int, floating point, and complex numbers.
```jai
Matrix :: struct(M: int, N: int, T: Type) {
    data: [M][N] T;
}
```

## Matrix Add 1
Matrix addition can be written in the following way. This is a polymorphic function where the Matrix has a polymorphic parameters `$M`, `$N`, and `$T`.
```jai
operator + :: (a: Matrix($M, $N, $T), b: Matrix(M, N, T)) -> Matrix(M, N, T) {
    c: Matrix(M, N, T);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] + b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Add 2
Matrix addition can be written in the following way. This is a polymorphic function where `$T` must be a parameterized struct of type `Matrix`. Due to the multiple parameters on `Matrix`, writing it in this way compared to Matrix Add 1 is a lot less verbose.
```jai
operator + :: (a: $T/Matrix, b: T) -> T {
    c: T;
    for i : 0..(T.M-1) {
        for j : 0..(T.N-1) {
            c.data[i][j] = a.data[i][j] + b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Sub 1
Matrix subtraction can be written in the following way. This is a polymorphic function where the Matrix has a polymorphic parameters `$M`, `$N`, and `$T`.
```jai
operator - :: (a: Matrix($M, $N, $T), b: Matrix(M, N, T)) -> Matrix(M, N, T) {
    c: Matrix(M, N, T);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] - b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Sub 2
Matrix subtraction can be written in the following way. This is a polymorphic function where `$T` must be a parameterized struct of type `Matrix`. Due to the multiple parameters on `Matrix`, writing it in this way compared to Matrix Sub 1 is a lot less verbose.
```jai
operator - :: (a: $T/Matrix, b: T) -> T {
    c: T;
    for i : 0..(T.M-1) {
        for j : 0..(T.N-1) {
            c.data[i][j] = a.data[i][j] - b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Multiplication 1
Given the definition, one can implement matrix multiplication of two matrices in the following way. This multiplication generalizes across all different matrices of Type `T`.
```jai
operator * :: (a: Matrix($M, $X, $T), b: Matrix(X, $N, T)) -> Matrix(M, N, T) {
    c: Matrix(M, N, T);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            value: T;
            for k : 0..(X-1) {
                value += a.data[i][k] * b.data[k][j];
            }
            c.data[i][j] = value;
        }
    }
    return c;
}
```

## Matrix Multiplication 2
Another matrix multiplication function implementation where `$T` must be a parameterized struct of type `Matrix`.. This multiplication generalizes across all different matrices of Type `T`.
```jai
operator * :: (a: $T/Matrix, b: Matrix(T.N, $N, T.T)) -> Matrix(T.M, N, T.T) {
    c: Matrix(T.M, N, T.T);
    for i : 0..(T.M-1) {
        for j : 0..(T.N-1) {
            value: T.T;
            for k : 0..(T.N-1) {
                value += a.data[i][k] * b.data[k][j];
            }
            c.data[i][j] = value;
        }
    }
    return c;
}
```

## Matrix Scalar Multiplication 1
One can overload the multiplication operator so that Matrix can support scalar multiplication. We can attach the #symmetric keyword to the function so that the scalar float value is swappable with the Matrix; in this way, we do not need to define two different functions to represent scalar multiplication.
```jai
operator * :: (a: Matrix($M, $N, $T), b: T) -> Matrix(M, N, T) #symmetric {
    c: Matrix(M, N, T);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] * b;
        }
    }
    return c;
}
```

## Matrix Scalar Multiplication 2
Another matrix scalar multiplication function implementation where `$T` must be a parameterized struct of type `Matrix`. This scalar multiplication generalizes across all different matrices of Type `T`.
```jai
operator * :: (a: $T/Matrix, b: T.T) -> T #symmetric {
    c: T;
    for i : 0..(T.M-1) {
        for j : 0..(T.N-1) {
            c.data[i][j] = a.data[i][j] * b;
        }
    }
    return c;
}
```

## Matrix Transpose 1
The transpose of a matrix is obtained by flipping it over its diagonal, which means switching its rows with its columns.
```jai
transpose :: (matrix: Matrix($M, $N, $T)) -> Matrix(N, M, T) {
    answer: Matrix(N, M, T);
    for i : 0..M-1 {
        for j : 0..N-1 {
            answer.data[j][i] = matrix.data[i][j];
        }
    }
    return answer;
}
```

## Matrix Transpose 2
Another matrix transpose function implementation where `$T` must be a parameterized struct of type `Matrix`. This transpose function generalizes across all different matrices of Type `T`.
```jai
transpose :: (matrix: $T/Matrix) -> Matrix(T.N, T.M, T.T) {
    answer: Matrix(T.N, T.M, T.T);
    for i : 0..T.M-1 {
        for j : 0..T.N-1 {
            answer.data[j][i] = matrix.data[i][j];
        }
    }
    return answer;
}
```

# Polymorphic Complex Numbers
A complex number is a number that combines a real part and an imaginary part. It is expressed in the form: a + bi where:

    a is the real part
    b is the imaginary part
    i is the imaginary unit, defined as the square root of -1

We can define complex numbers using the following struct:
```jai
Complex :: struct(T: Type) {
    real: T;
    imaginary: T;
}
```
By making the struct polymorphic, one can make Complex numbers more flexible. For example, if one needs more bits for precision, one can have a `Complex(float64)` instead of a `Complex(float)`.

## Complex Add 1
We can define complex number addition using operator overloading. Adds the corresponding real and imaginary member fields together.
```jai
operator + :: (a: Complex($T), b: Complex(T)) -> Complex(T) {
    c: Complex(T);
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```

## Complex Add 2
Another complex number addition created where `$T` must be a parameterized struct of type `Complex`. Adds the corresponding real and imaginary member fields together.
```jai
operator + :: (a: $T/Complex($T), b: T) -> T {
    c: T;
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```
## Complex Add 3
Another complex number addition that utilizes implicit polymorphism. Adds the corresponding real and imaginary member fields together.
```jai
operator + :: (a: Complex, b: type_of(a)) -> type_of(a) {
    c: type_of(a);
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```
## Complex Sub 1
We can define complex number subtraction using operator overloading. Subtracts the corresponding real and imaginary member fields together.
```jai
operator - :: (a: Complex($T), b: Complex(T)) -> Complex(T) {
    c: Complex(T);
    c.real = a.real - b.real;
    c.imaginary = a.imaginary - b.imaginary;
    return c;
}
```

## Complex Sub 2
Another complex number subtraction created where `$T` must be a parameterized struct of type `Complex`. Subtracts the corresponding real and imaginary member fields together.
```jai
operator - :: (a: $T/Complex($T), b: T) -> T {
    c: T;
    c.real = a.real - b.real;
    c.imaginary = a.imaginary - b.imaginary;
    return c;
}
```
## Complex Sub 3
Another complex number subtraction that utilizes implicit polymorphism. Subtracts the corresponding real and imaginary member fields together.
```jai
operator + :: (a: Complex, b: type_of(a)) -> type_of(a) {
    c: type_of(a);
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```
## Complex Multiplication 1
We can define complex number multiplication using operator overloading. Calculate the multiplication of the square roots of -1 and the multiplication of real and imaginary values when multiplying.
```jai
operator * :: (a: Complex($T), b: Complex(T)) -> Complex(T) {
    c: Complex(T);
    c.real = (a.real * b.real) - (a.imaginary * b.imaginary);
    c.imaginary = (a.real * b.imaginary) + (a.imaginary * b.real);
    return c;
}
```

## Complex Multiplication 2
Another complex number multiplication created where `$T` must be a parameterized struct of type `Complex`. 
```jai
operator * :: (a: $T/Complex, b: T) -> T {
    c: T;
    c.real = (a.real * b.real) - (a.imaginary * b.imaginary);
    c.imaginary = (a.real * b.imaginary) + (a.imaginary * b.real);
    return c;
}
```
## Complex Multiplication 3
Another complex number multiplication using implicit polymorphism. 
```jai
operator * :: (a: Complex, b: type_of(a)) -> type_of(a) {
    c: type_of(a);
    c.real = (a.real * b.real) - (a.imaginary * b.imaginary);
    c.imaginary = (a.real * b.imaginary) + (a.imaginary * b.real);
    return c;
}
```

--- End of file: documents/19_polymorphic_data_structures.md ---

--- Start of file: documents/20_metaprogramming.md ---
# Generate Getters and Setters
One can use the insert directive to automatically generate getter and setter functions. This is an elementary example for didactic purposes, but one can extrapolate this example to do much more complex metaprogramming.
```jai
generate_getters_and_setters :: ($T: Type) -> string {
    builder: String_Builder;
    info := type_info(T);
    for member: info.members {
        print("%\n", type_of(member.type));
        print_to_builder(*builder, "get_% :: (s: %) -> type_of(s.%) { return s.%; }\n",
            member.name, T, member.name, member.name);
        print_to_builder(*builder, "set_% :: (s: *%, val: type_of(s.%)) { s.% = val; }\n",
            member.name, T, member.name, member.name);
    }

    s := builder_to_string(*builder);
    return s;
}

#insert -> string {
    return generate_getters_and_setters(Person);
}
```

Given the following Person struct as an example:
```jai
Person :: struct {
    name: string;
    age: int;
}
```
The following code generated by the function would result in this:
```jai
get_name :: (s: Person) -> type_of(s.name) { return s.name; }
set_name :: (s: *Person, val: type_of(s.name)) { s.name = val; }
get_age :: (s: Person) -> type_of(s.age) { return s.age; }
set_age :: (s: *Person, val: type_of(s.age)) { s.age = val; }
```

# Struct of Arrays
Structs of Arrays is a way of rearranging the layout of the data fields of a struct. Specifically, Structs of Arrays (SoA) is a data layout separating elements of a struct into one parallel array per field. Take the following example:
```jai
// this is just a normal struct, no SOA
Vec3 :: struct {
  x: float;
  y: float;
  z: float;
}

// this is a SOA Vec3 struct
SOA_Vec3 :: struct {
  x: [100] float;
  y: [100] float;
  z: [100] float;
}
```
Using an `#insert` directive and generating code at compile time, we can generalize the concept of SOA to any structs using the following:
```jai
Vec3 :: struct {
    x: float;
    y: float;
    z: float;
}

Person :: struct {
    age: int;
    is_cool: bool;
}

SOA :: struct(T: Type, count: int) {
    #insert -> string {
        t_info := type_info(T);
        builder: String_Builder;
        defer free_buffers(*builder);
        for fields: t_info.members {
            print_to_builder(*builder, "  %1: [%2] type_of(T.%1);\n", fields.name, count);
        }
        result := builder_to_string(*builder);
        return result;
    }
}

#import "Basic";

main :: () {

    // create an soa_vec3
    soa_vec: SOA(Vec3, 10);
    for i: 0..soa_vec.count-1 {
        print("soa_vec.x[i]=%, soa_vec.y[i]=%, soa_vec.z[i]=%\n", soa_vec.x[i], soa_vec.y[i], soa_vec.z[i]);
    }

    // create an soa_person
    soa_person: SOA(Person, 10);
    for i: 0..soa_person.count-1 {
        print("soa_person.age[i]=%, soa_person.is_cool[i]=%\n", soa_person.age[i], soa_person.is_cool[i]);
    }

}
```

# Initialize Data with No Reset
Applying `#no_reset` macro allows one to initialize complex data structures at compile time easily without the need of complex assembly language macros like in C++. Here is a simple example of `#no_reset` directive.
```jai
#no_reset array: [5] int;

#run {
    array[0] = 1;
    array[1] = 10;
    array[2] = 3;
    array[3] = 5;
    array[4] = 700;
}

```

# Initialize NNUE No Reset

Applying `#no_reset` macro allows one to initialize complex data structures at compile time easily without the need of complex assembly language macros like in C++. In this example, one can load a binary NNUE file into memory and populate the data structures at compile time.

```jai
#run load_model("orange7_8_24.nnue");

#no_reset nnue: NNUE #align 64;

NNUE :: struct {
  feature_weights: [2][9][90][128] s16;
  feature_biases:  [128] s16;
  output_weights:  [2][128] s16;
  output_bias:     s32;
}

load_model :: (filename: string) {
  print("loading file %\n", filename);
  weights, success := read_entire_file(filename);
  assert(success, "File % not found.", filename);
  memcpy(*nnue, *weights[0], size_of(NNUE));
  free(weights);
}
```



--- End of file: documents/20_metaprogramming.md ---

--- Start of file: documents/21_common_mistakes.md ---
# Section 1: Syntax and Declaration Errors

Mistakes rooted in Jai's unique syntax — variable declarations, operators, and statement formatting that differ from C, C++, or other languages.

---

## Incorrect Variable Declaration
**Problem:** Placing the variable type declaration before the variable identifier.
```
// ❌ WRONG - Placing the variable type declaration before the variable identifier
int x;
```

**Solution:** Place the variable identifier before the type declaration.
```jai
// ✅ CORRECT
x: int;
```

---

## Incorrect Function Declaration
**Problem:** Using C-style function syntax in Jai.
```
// ❌ WRONG - This is not valid Jai syntax
int function(int a, int b) {

}
```

**Solution:** Format functions using the correct Jai syntax, placing identifiers before types.
```jai
// ✅ CORRECT
function :: (a: int, b: int) -> int {

}
```

---

## Forgetting the Semicolon
**Problem:** Forgetting to end a statement with a semicolon.
```
// ❌ WRONG - missing semicolon
z := x + y
```

**Solution:** End every statement with a semicolon.
```jai
// ✅ CORRECT
z := x + y;
```

---

## Confusing `:=` and `::` for Procedures
**Problem:** Using `:=` to define a function creates a variable holding a function value, not a named constant procedure.
```jai
// ❌ WRONG - this declares a variable, not a constant procedure
func := () {
    print("hello\n");
}
```

**Solution:** Use `::` to declare a constant procedure.
```jai
// ✅ CORRECT
func :: () {
    print("hello\n");
}
```

---

## Using `:=` Instead of `=` When Assigning to Existing Variables
**Problem:** Using `:=` everywhere out of habit creates a new shadowing variable in the current scope instead of assigning to an existing one.
```jai
x := 10;
if true {
    // ❌ WRONG - creates a NEW x, shadows the outer x
    x := 99;
}
```

**Solution:** Use `=` to assign to an existing variable.
```jai
x := 10;
if true {
    // ✅ CORRECT
    x = 99;
}
```

---

## No `++` or `--` Operators
**Problem:** Attempting to use C-style increment/decrement operators.
```
// ❌ WRONG - ++/-- are not in the language
i++;
i--;
```

**Solution:** Use `+= 1` and `-= 1` instead.
```jai
// ✅ CORRECT
i += 1;
i -= 1;
```

---

## Incorrect Ternary Operator
**Problem:** Using C++-style ternary operator syntax.
```
// ❌ WRONG - C++ style ternary
int x = 1 < 2 ? 1 : 2;
```

**Solution:** Use the `ifx` keyword.
```jai
// ✅ CORRECT
x: int = ifx 1 < 2 then 1 else 2;
```

---

## Incorrect Variable Type Inference
**Problem:** Using the C++ `auto` keyword for type inference.
```
// ❌ WRONG - 'auto' is not valid Jai syntax
auto x = 10;
```

**Solution:** Use `:=` for type inference.
```jai
// ✅ CORRECT
x := 10;
```

---

## Using Commas Instead of Semicolons in Struct Bodies
**Problem:** Separating struct members with commas instead of semicolons.
```jai
// ❌ WRONG - commas between struct members
Vec3 :: struct {
    x: float,
    y: float,
    z: float
}
```

**Solution:** Separate struct members with semicolons.
```jai
// ✅ CORRECT
Vec3 :: struct {
    x: float;
    y: float;
    z: float;
}
```

---

## No Header Files, No `#include`
**Problem:** There is no preprocessing step and no header/implementation split in Jai.
```
// ❌ WRONG - no #include directive in Jai
#include <stdio.h>
```

**Solution:** Use `#import` for modules and `#load` for other `.jai` files.
```jai
// ✅ CORRECT
#import "Basic";
#load "my_utils.jai";
```

---

## Incorrect Notes Placement
**Problem:** Placing a note annotation before the function body like in Java or Python.
```jai
// ❌ WRONG - note must not be placed before the function
@note
function :: () {
    // function body...
}
```

**Solution:** Place the note after the closing curly brace of the function body.
```jai
// ✅ CORRECT
function :: () {
    // function body...
} @note
```

---

# Section 2: Type System and Casting Errors

Mistakes related to Jai's strict type system — casting, type mismatches, and implicit conversion rules.

---

## Type Mismatch
**Problem:** Assigning a value of the wrong type to a variable.
```jai
// ❌ WRONG - cannot assign a string to an int
x: int = "Pacman";
```

**Solution:** Match the value to the declared type.
```jai
// ✅ CORRECT
x: int = 10;
```

---

## Incorrect Casting Syntax
**Problem:** Using C-style or C++-style cast syntax.
```
// ❌ WRONG - C++ casting syntax
float f = (float)some_int;
float f2 = static_cast<float>(some_int);
```

**Solution:** Use `cast(type)` or `xx` for autocast.
```jai
// ✅ CORRECT
f := cast(float) some_int;
f2 := xx some_int;  // autocast
```

---

## Not Casting Function Parameters
**Problem:** Passing a value to a function without casting it to the required type.
```jai
function :: (a: u8) {
    // function body...
}

a: int = 127;
// ❌ WRONG - passing an int where u8 is expected
function(a);
```

**Solution:** Cast the value to the correct type before passing it.
```jai
// ✅ CORRECT
function(cast(u8) a);
```

---

## Implicit Type Conversions
**Problem:** Expecting C-style implicit narrowing conversions to work silently.
```jai
// ❌ WRONG - s64 is bigger than s32
x: s64 = 1000000000000;
y: s32 = x;
```

**Solution:** Use an explicit cast and be aware of value ranges.
```jai
// ✅ CORRECT - explicit cast with range awareness
x: s64 = 1000000000000;
if x >= S32_MIN && x <= S32_MAX {
    y: s32 = cast(s32) x;
} else {
    // handle error
}
```

---

## Unsigned/Signed Type Mismatch
**Problem:** Jai does not allow implicit signed-to-unsigned conversions like C does.
```jai
// ❌ WRONG - comparing s32 and u32 directly
a: s32 = -1;
b: u32 = 1;
if a < b { ... }
```

**Solution:** Make types consistent or handle the sign explicitly.
```jai
// ✅ CORRECT
a: s32 = -1;
b: u32 = 1;
if a < 0 || cast(u32) a < b {
    print("Clear intent\n");
}
```

---

## No `const` Keyword
**Problem:** Attempting to use `const` on function parameters like in C++.
```
// ❌ WRONG - 'const' is not a keyword in Jai
void foo(const int x) { ... }
```

**Solution:** Simply declare the parameter normally. Constants use `::` at declaration time.
```jai
// ✅ CORRECT
foo :: (x: int) { ... }
```

---

## Function Pointer Type Mixup
**Problem:** Mistaking a function pointer type `(int)` for an integer type.
```jai
// ❌ WRONG - this is a function pointer, not an integer
a: (int) = (1);
```

**Solution:** Assign a function with the matching signature to the function pointer.
```jai
// ✅ CORRECT
function :: (a: int) { }

a: (int) = function;
```

---

## No Tuple Type
**Problem:** Assuming `(int, int)` is a tuple. In Jai it is a function pointer type.
```jai
// ❌ WRONG - this is a function pointer, not a tuple
a: (int, int) = (1, 2);
```

**Solution:** Assign a matching function to the function pointer variable.
```jai
// ✅ CORRECT
function :: (a: int, b: int) { }

a: (int, int) = function;
```

---

## Forgetting That Jai Strings Are Not Null-Terminated
**Problem:** Passing a raw Jai string's `.data` pointer to a C function expecting a null-terminated string. Jai strings carry a `count` and a `data` pointer with no null byte at the end.
```jai
// ❌ WRONG - s.data is NOT null-terminated
s := "hello";
c_style_strlen(s.data);
```

**Solution:** Use `to_c_string` to convert to a null-terminated string first.
```jai
// ✅ CORRECT
s := "hello";
c_style_strlen(to_c_string(s));
```

---

## Accessing Enum Members Without the Type Prefix
**Problem:** Referencing an enum value by its bare name without qualification.
```jai
Direction :: enum { NORTH; SOUTH; EAST; WEST; }

// ❌ WRONG - bare name does not resolve
d := NORTH;
```

**Solution:** Use full qualification, or the `.` shorthand when the type is known from context.
```jai
// ✅ CORRECT - full qualification
d := Direction.NORTH;

// ✅ CORRECT - shorthand when type is known
d: Direction = .NORTH;
```

---

# Section 3: Control Flow and Scoping Errors

Mistakes involving loops, branching, `if-case` statements, `defer`, and scope behavior.

---

## Writing `switch` Instead of `if-case`
**Problem:** Jai has no `switch` keyword.
```
// ❌ WRONG - switch does not exist in Jai
switch x {
    case 0: print("zero\n");
    case 1: print("one\n");
}
```

**Solution:** Use `if variable == {` followed by `case` statements. Note that each `case` ends with a semicolon, not a colon.
```jai
// ✅ CORRECT
if x == {
case 0;  print("zero\n");
case 1;  print("one\n");
case;    print("other\n");  // default
}
```

---

## Putting `break` Inside `if-case` to Exit the Case
**Problem:** In Jai, `break` inside an `if-case` breaks out of an enclosing loop, not the case block. Cases don't fall through by default, so no `break` is ever needed.
```jai
for 0..5 {
    if it == {
    case 2;
        print("two\n");
        break;  // ❌ WRONG - this breaks the for loop, not the case!
    case 3;
        print("three\n");
    }
}
```

**Solution:** Remove the `break`. If you want C-style fallthrough, use `#through;` explicitly.
```jai
// ✅ CORRECT
for 0..5 {
    if it == {
    case 2;  print("two\n");
    case 3;  print("three\n");
    }
}
```

---

## Forgetting the `==` in an `if-case` Block
**Problem:** The `if-case` syntax requires `if variable == {`. Omitting `==` causes a compile error or unexpected behavior.
```jai
// ❌ WRONG - missing '=='
if x {
case 0;  print("zero\n");
}
```

**Solution:** Always include `==` after the variable.
```jai
// ✅ CORRECT
if x == {
case 0;  print("zero\n");
}
```

---

## Writing `else if` Inside an `if-case` Block
**Problem:** There is no `else if` inside a `if x == {}` block. Only `case` statements are valid there.
```jai
// ❌ WRONG - mixing if-else with if-case
if x == {
case 0;
    print("zero\n");
else if x == 1     // syntax error
    print("one\n");
}
```

**Solution:** Add another `case` statement instead.
```jai
// ✅ CORRECT
if x == {
case 0;  print("zero\n");
case 1;  print("one\n");
}
```

---

## Incorrect For Loop Range (Off-By-One)
**Problem:** Jai's for loop range `a..b` is inclusive on both ends. Using `for i : 0..arr.count` will attempt to access `arr[arr.count]`, which is out of bounds.
```jai
// ❌ WRONG - range is inclusive, so this accesses arr[10]
arr: [10] int;
for i : 0..arr.count {
    print("%\n", arr[i]);
}
```

**Solution:** Use `arr.count - 1` as the upper bound.
```jai
// ✅ CORRECT
arr: [10] int;
for i : 0..arr.count-1 {
    print("%\n", arr[i]);
}
```

---

## Iterating by Value and Expecting to Modify the Array
**Problem:** When you `for` over an array normally, `it` is a copy of the element. Modifications to `it` don't affect the original array.
```jai
array := int.[1, 2, 3, 4, 5];
// ❌ WRONG - modifies a copy, original is unchanged
for array {
    it *= 2;
}
```

**Solution:** Iterate by pointer using `for *` to modify elements in place.
```jai
// ✅ CORRECT
for * array {
    it.* *= 2;
}
```

---

## Misunderstanding `defer` Inside Loops
**Problem:** `defer` executes at the end of the current *scope*, not the end of the function. Inside a loop body, a deferred statement runs at the end of each iteration, not when the function returns.
```jai
for 0..2 {
    defer print("deferred\n");
    print("loop body\n");
}
// Output order: loop body, deferred, loop body, deferred, loop body, deferred
```

Keep this in mind when using `defer` for cleanup: a `defer free(ptr)` inside a loop frees the pointer every iteration.

---

## Using a Variable from an Outer Function (No Closures)
**Problem:** Inner functions cannot access variables from their outer function. Closures are not supported in Jai.
```jai
function :: () {
    a := 0;
    inner_function :: () {
        // ❌ WRONG - cannot capture variable from outer scope
        a += 1;
    }
    inner_function();
}
```

**Solution:** Pass the variable explicitly as a pointer parameter.
```jai
// ✅ CORRECT
function :: () {
    a := 0;
    inner_function :: (a: *int) {
        a.* += 1;
    }
    inner_function(*a);
}
```

---

## Capturing Values with Lambda Expressions
**Problem:** Lambda expressions in Jai do not support closures — they cannot capture variables from the surrounding scope.
```jai
function :: () {
    a := 0;
    // ❌ WRONG - lambdas cannot capture outer variables
    lambda :: () => a;
}
```

**Solution:** Pass the value as a parameter to the lambda instead.
```jai
// ✅ CORRECT
function :: () {
    a := 0;
    lambda :: (a: int) => a;
}
```

---

# Section 4: Memory and Pointer Errors

Mistakes involving pointers, heap allocation, dynamic arrays, and memory management.

---

## Wrong Pointer Address-Of Operator
**Problem:** Using C++'s `&` operator to take the address of a variable.
```
// ❌ WRONG - '&' is not the address-of operator in Jai
int a = 5;
int* b = &a;
```

**Solution:** Use `*` to take the address of a variable in Jai.
```jai
// ✅ CORRECT
a : int = 5;
b : *int = *a;
```

---

## Wrong Pointer Dereference Operator
**Problem:** Using C's `*b` prefix syntax to dereference a pointer.
```
// ❌ WRONG - C-style pointer dereference
int *b;
int val = *b;
```

**Solution:** Use the postfix `b.*` syntax to dereference a pointer in Jai.
```jai
// ✅ CORRECT
b: *int;
val := b.*;
```

---

## Using `->` for Pointer Member Access
**Problem:** C++ uses `->` to access struct members through a pointer. Jai uses `.` everywhere.
```
// ❌ WRONG - '->' is not valid in Jai
person->name = "Alice";
```

**Solution:** Use `.` whether `person` is a value or a pointer.
```jai
// ✅ CORRECT
person.name = "Alice";
```

---

## No `new` Keyword — It's a Regular Function
**Problem:** In Jai, `New` is a regular function, not a built-in keyword like in C++.
```
// ❌ WRONG - 'new' is not a keyword in Jai
Object* obj = new Object();
delete obj;
```

**Solution:** Call `New()` to heap-allocate, and `free()` to release.
```jai
// ✅ CORRECT
obj := New(Object);
free(obj);
```

---

## Dangling Pointers After Scope
**Problem:** Returning a pointer to a stack-allocated variable. The variable goes out of scope when the function returns, leaving the pointer dangling.
```jai
// ❌ WRONG - v goes out of scope, pointer dangles
create_vector :: () -> *Vector3 {
    v: Vector3;
    v.x = 1.0;
    return *v;
}
```

**Solution:** Return by value, or heap-allocate with `New`.
```jai
// ✅ CORRECT - return by value
create_vector :: () -> Vector3 {
    v: Vector3;
    v.x = 1.0;
    return v;
}
```

---

## Double Free
**Problem:** Calling `free` on the same pointer twice causes a crash.
```jai
// ❌ WRONG - double free
data := alloc(size_of(MyStruct));
free(data);
free(data);  // CRASH
```

**Solution:** Free the memory only once.
```jai
// ✅ CORRECT
data := alloc(size_of(MyStruct));
free(data);
```

---

## Forgetting to Free Dynamic Arrays
**Problem:** Dynamic arrays allocate heap memory that is not automatically freed when they go out of scope.
```jai
// ❌ WRONG - memory leak
process_data :: () {
    items: [..] int;
    array_add(*items, 1);
    array_add(*items, 2);
    // Function ends — memory leaked!
}
```

**Solution:** Use `defer array_free` to guarantee cleanup.
```jai
// ✅ CORRECT
process_data :: () {
    items: [..] int;
    defer array_free(items);

    array_add(*items, 1);
    array_add(*items, 2);
}
```

---

## Forgetting to Pass Dynamic Arrays by Pointer
**Problem:** Passing a dynamic array by value to a function means `array_add` modifies a copy, not the original.
```jai
// ❌ WRONG - modifies a copy
function :: (arr: [..] int) {
    array_add(*arr, 42);
}
```

**Solution:** Pass the array by pointer so modifications affect the original.
```jai
// ✅ CORRECT
function :: (arr: *[..] int) {
    array_add(arr, 42);
}
```

---

## Not Using `array_reserve` Before Large Batch Additions
**Problem:** Adding items to a dynamic array one at a time without reserving space causes repeated reallocations as the array grows.
```jai
// ❌ WRONG - many allocations as the array grows
arr: [..] int;
for 0..999  array_add(*arr, it);
```

**Solution:** Reserve space upfront when the count is known.
```jai
// ✅ CORRECT - one allocation up front
arr: [..] int;
array_reserve(*arr, 1000);
for 0..999  array_add(*arr, it);
```

---

## Using Uninitialized Variables (`---`)
**Problem:** The `= ---` syntax explicitly marks a variable as uninitialized for performance. Reading such a variable before writing to it is undefined behavior.
```jai
// ❌ WRONG - undefined behavior if read before assignment
x: int = ---;
print("%\n", x);
```

**Solution:** Let Jai zero-initialize by default unless you have a specific performance reason.
```jai
// ✅ CORRECT - safely zero-initialized
x: int;
```

---

# Section 5: Object-Oriented Habits and Language Differences

Mistakes that come from applying C++, Java, or Rust mental models to Jai's deliberate design choices around OOP, metaprogramming, and assembly.

---

## No Member Functions
**Problem:** In Jai, functions do not "belong" to objects. There is no implicit `self` or `this`.
```jai
Object :: struct {
    x: int;
    // ❌ WRONG - no concept of self/this in Jai
    set_x :: (x: int) {
        self.x = x;
    }
}
```

**Solution:** Write a regular function that takes a pointer to the struct as an explicit parameter.
```jai
// ✅ CORRECT
Object :: struct {
    x: int;
}

set_x :: (self: *Object, x: int) {
    self.x = x;
}
```

---

## No Constructors Fire on Struct Declaration
**Problem:** Assuming struct initialization works like a C++ constructor. Jai has no constructors.
```
// ❌ WRONG - assuming a constructor is called automatically
Object obj;
```

**Solution:** Write an explicit `init` function and call it yourself.
```jai
// ✅ CORRECT
obj: Object;
init(*obj);
```

---

## Print Using C-Style Format Specifiers
**Problem:** Jai's `print` does not use C-style format specifiers like `%d` or `%f`. `%` is a universal placeholder for any type.
```
// ❌ WRONG - C-style format specifiers are not valid in Jai
printf("Value: %d, float: %f\n", x, y);
```

**Solution:** Use `%` for all values regardless of type.
```jai
// ✅ CORRECT
print("Value: %, float: %\n", x, y);
```

---

## Cannot Jump in Assembly
**Problem:** Jai's `#asm` blocks do not support `jmp`, labels, or `call` instructions.
```jai
#asm {
   // ❌ WRONG - labels and jmp are not supported
   label:
   jmp label;
}
```

**Solution:** Use Jai's high-level control flow (`while`, `for`, `if`) for branching. Reserve `#asm` for arithmetic and SIMD operations.
```jai
// ✅ CORRECT
while true {
    // loop body
}
```

---

## Forgetting to declare register identifier
**Problem:** Jai's `#asm` blocks require you to define and declare a register identifier before using it.
```jai
#asm {
    // ❌ WRONG - unidentified register
    mov.64 the_register, 10;
}
```

**Solution:** Declare the register, then use it in the `#asm` block.
```jai
#asm {
    // ✅ CORRECT
    the_register: gpr;
    mov.64 the_register, 10;
}
```

---

## Assembly Statements Missing Semicolons
**Problem:** Forgetting that assembly statements inside `#asm` blocks also require a semicolon.
```jai
#asm {
   // ❌ WRONG - missing semicolon
   add x, y, z
}
```

**Solution:** End every assembly statement with a semicolon.
```jai
// ✅ CORRECT
#asm {
    add x, y, z;
}
```

---

## AVX2 By-Reference/By-Value Semantics Not Supported for 256-bit Registers
**Problem:** The compiler's by-value move optimization for `#asm` only works with 128-bit `xmm` registers. Attempting to use it with 256-bit `ymm` registers is not supported.
```jai
// ❌ WRONG - 256-bit by-value moves are not supported
add :: (a: [8] float, b: [8] float) -> [8] float {
    result := a;
    #asm AVX2 {
        addps.256 result, b;
    }
    return result;
}
```

**Solution:** Use 128-bit `xmm` registers for by-value moves, or use pointer-based memory operands for 256-bit operations.
```jai
// ✅ CORRECT - 128-bit xmm registers supported
add :: (a: [4] float, b: [4] float) -> [4] float {
    result := a;
    #asm {
        addps.128 result, b;
    }
    return result;
}
```

---

## String Concatenation in Loops
**Problem:** Repeatedly building strings with `sprint` in a loop causes quadratic allocations — each call allocates a new string and discards the old one.
```jai
// ❌ WRONG - reallocates every iteration
build_message :: (items: [] string) -> string {
    result := "";
    for item: items {
        result = sprint("%% ", result, item);
    }
    return result;
}
```

**Solution:** Use `String_Builder` to append incrementally and convert once at the end.
```jai
// ✅ CORRECT
build_message :: (items: [] string) -> string {
    builder: String_Builder;
    defer free_buffers(*builder);

    for item: items {
        append(*builder, item);
        append(*builder, " ");
    }

    return builder_to_string(*builder);
}
```

---

## Unnecessary Polymorphic Dispatch
**Problem:** Using `$T` polymorphism when you only ever call the function with one concrete type adds compile-time overhead and generates unnecessary specializations.
```jai
// ❌ WRONG - unnecessary generic when only floats are used
add :: (a: $T, b: T) -> T {
    return a + b;
}
result := add(1.0, 2.0);
```

**Solution:** Use a concrete type when the set of types is small and known.
```jai
// ✅ CORRECT - simple and direct
add :: (a: float, b: float) -> float {
    return a + b;
}
```

--- End of file: documents/21_common_mistakes.md ---

--- Start of file: documents/22_miscellaneous_code_examples.md ---
# Swap

You can swap two numbers using `a, b = b, a;` 
```jai
#import "Basic";

main :: () {
    a := 5;
    b := 9;

    print("Before swap: a = %, b = %\n", a, b);
    a, b = b, a;
    print("After swap:  a = %, b = %\n", a, b);
}
```

# Perfect Numbers

A perfect number is an integer that is equal to the sum of its positive proper divisors, that is, divisors excluding the number itself. For instance, 6 has proper divisors 1, 2, and 3, and 1 + 2 + 3 = 6, so 6 is a perfect number. The next perfect number is 28, because 1 + 2 + 4 + 7 + 14 = 28.

We can create a function to determine if a number is perfect or not. Add up all the factors of the number, and if the sum of all factors is equal to the number, then return true.
```jai
#import "Basic";

is_perfect :: (n: int) -> bool {
    if n <= 1 return false;

    sum := 1;
    for i: 2..n/2 + 1 {
        if n % i == 0 {
            sum += i;
        }
    }

    return sum == n;
}

main :: () {
    for i: 1..10000 {
        if is_perfect(i) {
            print("% is a perfect number.\n", i);
        }
    }
}
```

# XOR Swap

The XOR swap is an algorithm that uses the XOR bitwise operation to swap the values of two variables without using the temporary variable which is normally required.

```jai
#import "Basic";

main :: () {
    a := 5;
    b := 9;

    print("Before swap: a = %, b = %\n", a, b);

    // XOR swap
    a = a ^ b;
    b = a ^ b;
    a = a ^ b;

    print("After swap:  a = %, b = %\n", a, b);
}
```
# Set a Bit

To set a specific bit in a number, perform the Bitwise OR operation on the given number with a bit mask in which only the bit you want to set is set to 1, and all other bits are set to 0.

```jai
set_bit :: (number: int, k: int) -> int {
    bit := 1 << k;
    return number | bit;
}
```

# Unset a Bit
To clear a specific bit in a number to 0, perform the Bitwise AND operation on the given number with a bit mask in which only the bit you want to clear is set to 0, and all other bits are set to 1.

```jai
unset_bit :: (number: int, k: int) -> int {
    bit := ~(1 << k);
    return number & bit;
}
```

# Toggle a Bit
To toggle a specific bit in a number, perform the Bitwise XOR operation on the given number with a bit mask in which only the bit you want to toggle is set to 1, and all other bits are set to 0.

```jai
toggle_bit :: (number: int, k: int) -> int {
    bit := 1 << k;
    return number ^ bit;
}
```

# Recursive Factorial

A recursive factorial function to demonstrate Jai's ability to handle recursion. 

```jai
factorial :: (n: int) -> int {
    if n <= 1 {
        return 1;
    }

    return n * factorial(n - 1);
}
```

# Recursive Fibonacci

A recursive Fibonacci function to demonstrate Jai's ability to handle recursion. In this function, we calculate the nth Fibonacci number in the Fibonacci sequence. The nth Fibonacci is defined as the sum of the previous two numbers in the Fibonacci sequence.

```jai
fibonacci :: (n: int) -> int {
    if n <= 0 {
        return 0;
    }

    if n <= 1 {
        return 1;
    }

    return fibonacci(n - 1) + fibonacci(n - 2);
}
```

# Reverse Integer Bits
This code reverses the bits of a `u64` integer.

```jai
reverse_u64 :: (bits: u64) -> u64 {
    result: u64 = 0;
    bit: u64 = 1;
    rbit: u64 = 0x8000_0000_0000_0000;
    for i : 0..63 {
        if bits & bit {
            result |= rbit;
        }
        bit <<= 1;
        rbit >>= 1;
    }
    return result;
}
```

# Reverse an Array
This code reverses all the elements in an array.
```jai
reverse :: (array: [] int) {
    begin := 0;
    end := array.count - 1;
    while begin < end {
        array[begin], array[end] = array[end], array[begin];
        begin += 1;
        end -= 1;
    }
}
```

# Integer to String Conversion
This algorithm repeatedly taking the last digit of the number, converting that digit to its ASCII character representation, and building the string in reverse order. If the number is negative, we negate the negative number such that the number becomes positive.
```jai
int_to_string :: (n: int) -> string {
    builder: String_Builder;
    if n == 0 {
        append(*builder, cast(u8)(#char "0"));
        return builder_to_string(*builder);
    }

    is_negative := false;
    if n < 0 {
        is_negative = true;
        n = -n;
    }

    while (n > 0) {
        digit := n % 10;
        digit_char: u8 = cast(u8)(#char "0" + digit);
        append(*builder, digit_char);
        n /= 10; // Remove the last digit from the number
    }

    if is_negative {
        append(*builder, cast(u8)(#char "-")); //Append the negative sign
    }

    result := builder_to_string(*builder);

    // reverse string
    begin := 0;
    end := result.count - 1;
    while begin < end {
        result[begin], result[end] = result[end], result[begin];
        begin += 1;
        end -= 1;
    }

    return result;
}
```

# Shuffle an Array

This is some code to shuffle an array using the Fischer-Yates shuffle algorithm. One can define a `random_s64` function to make the casting to make the code more aesthetically pleasing to read.

```jai
random_s64 :: () -> s64 {
    r := (random_get() & 0x7FFF_FFFF);
    return cast(s64)r;
}

shuffle :: (array: [] int) {
    N := array.count - 1;
    for < i : 1..N {
        r := random_s64() % i;
        array[i], array[r] = array[r], array[i];
    }
}
```

Here is a while loop version of the code:
```jai
shuffle :: (array: [] int) {
    i := array.count - 1;
    while i >= 1 {
        r := random_s64() % i;
        array[i], array[r] = array[r], array[i];
        i -= 1;
    }
}
```

# Popcount
This algorithm performs a popcount based off of Brian Kernighan's algorithm. One only considers the set bits of an integer. One turns off the rightmost set bit after counting it, and we iterate until no more bits are left. The expression `n-1` flips all the bits after the rightmost set bit of `n`, including the rightmost set bit itself.

```jai
popcount :: (number: u64) -> int {
    result := 0;
    while number != 0 {
        result += 1;
        number &= (number - 1);
    }
}
```

# Palindrome
A palindrome is a word, number, phrase, or other sequence of symbols that reads the same backwards as forwards. This is a function to compute whether a string is a palindrome.
```jai
#import "Basic";
#import "String";

is_palindrome :: (s: string) -> bool {
    left := 0;
    right := s.count - 1;

    while left < right {
        if s[left] != s[right] return false;
        left += 1;
        right -= 1;
    }

    return true;
}

main :: () {
    words := string.[ "racecar", "hello", "level", "banana", "madam" ];

    for word: words {
        if is_palindrome(word)
            print("\"%\" is a palindrome.\n", word);
        else
            print("\"%\" is not a palindrome.\n", word);
    }
}
```

# Ackermann Function

The Ackermann function is a classic example of a recursive function. It grows very quickly in value, as does the size of its call tree. Its arguments are never negative and it always terminates. 

This is a straightforward implementation based off the definition of the Ackermann function.

```jai
ackermann :: (m: int, n: int) -> int {
    if !m {
        return n + 1;
    }

    if !n {
        return ackermann(m - 1, 1);
    }

    return ackermann(m - 1, ackermann(m, n - 1));
}
```

# Sudan Function

In the theory of computation, the Sudan function is an example of a function that is recursive, but not primitive recursive. This is also true of the better-known Ackermann function.

```jai
sudan_function :: (n: int, x: int, y: int) -> int {
    if n == 0 {
        return x + y;
    }

    else if y == 0 {
        return x;
    }

    return sudan_function(n - 1, sudan_function(n, x, y - 1), sudan_function(n, x, y - 1) + y);
}
```

# Bit Scan Forward

A bit scan forward implementation using De Bruijn Multiplication based off of [this implementation](https://www.chessprogramming.org/BitScan#DeBruijnMultiplation).
```jai
index64 :: int.[
     0,    1,   48,    2,   57,   49,   28,    3,
    61,   58,   50,   42,   38,   29,   17,    4,
    62,   55,   59,   36,   53,   51,   43,   22,
    45,   39,   33,   30,   24,   18,   12,    5,
    63,   47,   56,   27,   60,   41,   37,   16,
    54,   35,   52,   21,   44,   32,   23,   11,
    46,   26,   40,   15,   34,   20,   31,   10,
    25,   14,   19,    9,   13,    8,    7,    6,
];

bit_scan_forward :: (value: u64) -> int {
    DEBRUIJN64 : u64 : 0x03f79d71b4cb0a89;
    value = value & (cast,no_check(u64) -(cast(int)value));
    return index64[ (value * DEBRUIJN64) >> 58];
}
```

# Euclidean Algorithm to find Greatest Common Denominator

## GCD using Subtraction
This code performs GCD using recursion. This is a subtraction-based method to find the GCD and will help you find the GCD of two numbers, a and b.
```jai
gcd :: (a: int, b: int) -> int {
    // Everything divides 0
    if a == 0 {
        return b;
    }

    if b == 0 {
        return a;
    }

    // base case
    if a == b {
        return a;
    }

    // a is greater
    if a > b {
        return gcd(a - b, b);
    }

    return gcd(a, b - a);
}
```

## GCD using Modulo
A more efficient version uses modulo instead of subtraction as it reduces the steps to a fewer number of steps.

```jai
gcd :: (a: int, b: int) -> int {
    // Base case, if the second number becomes 0, the first number is the GCD
    if b == 0 {
        return a;
    }

    // Recursive step to call gcd with the smaller pair
    return gcd(b, a % b);
}
```

## GCD using Iterative Method

We can perform the same recursive function using iterative methods.
```jai
gcd :: (a: int, b: int) -> int {
  r := 0;
  while ((a % b) > 0)  {
    r = a % b;
    a = b;
    b = r;
  }

  return b;

}
```

# Least Common Multiple

Compute the least common multiple of two integers `m` and `n`. 

```jai
gcd :: (m: int, n: int) -> int
{
    while m {
        tmp := m;
        m = n % m;
        n = tmp;
    }

    return n;
}

lcm :: (m: int, n: int) -> int
{
    return m / gcd(m, n) * n;
}
```

# Pi Calculation

This piece of code computes the value of Pi using the Leibniz Formula.
```jai
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

# Towers of Hanoi

The Tower of Hanoi is a game where the objective is to move the entire stack to one of the other rods, obeying the following rules:

* Only one disk may be moved at a time.
* Each move consists of taking the upper disk from one of the stacks and placing it on top of another stack or on an empty rod.
* No disk may be placed on top of a disk that is smaller than it.

This is a solver for the Towers of Hanoi written in Jai:

```jai
move :: (n: int, from: int, via: int, to: int) {
    if n > 1 {
        move(n - 1, from, to, via);
        print("Move disk from pole % to pole %\n", from, to);
        move(n - 1, via, from, to);
    } else {
        print("Move disk from pole % to pole %\n", from, to);
    }
}
```

# Newton Square Root Calculation
Newton's method (also known as the Newton-Raphson method) is an efficient way to calculate square roots iteratively.

```jai
newton_sqrt :: (number: float, epsilon: float) -> float {
    assert(number >= 0.0);
    if (number == 0) {
        return 0.0;
    }

    x := number; // Initial guess
    previous: float;

    while abs(x - previous) > epsilon {
        previous = x;
        x = 0.5 * (x + number / x); // Newton's method formula
    }

    return x;
}
```

# Conversion of Numbers to English 

This function converts integer numerical values into its respective English word representation. For example, the integer value 99 becomes the string "ninty nine" and the integer value 1689 becomes the string "one thousand six hundred and eighty nine". This function handles numbers from 0 to 999,999,999. It does not handle billions, but billions can be easily added if one knows what to do.

```jai
number_to_english :: (number: int) -> string {
    builder: String_Builder;
    assert(number >= 0 && number <= 1_000_000_000);

    place :: (builder: *String_Builder, number: int) {
        if number >= 100 {
            digit := number / 100;
            append(builder, English_Ones[digit]);
            append(builder, " hundred");
            number %= 100;
            if number > 0 {
                append(builder, " and ");
            } else {
                return;
            }
        }

        if number <= 19 {
            append(builder, English_Ones[number]);
            return;
        }

        digit := number / 10;
        append(builder, English_Tens[digit]);
        number %= 10;
        if number > 0 {
            append(builder, " ");
            append(builder, English_Ones[number]);
        }
    }

    if number >= 1_000_000 {
        place(*builder, (number / 1_000_000) % 1000);
        append(*builder, " million ");
        number %= 1_000_000;
    }

    if number >= 1_000 {
        place(*builder, (number / 1_000) % 1000);
        append(*builder, " thousand ");
        number %= 1_000;
    }

    place(*builder, number % 1000);
    return builder_to_string(*builder);
}



English_Ones :: string.[
    "zero",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "eleven",
    "twelve",
    "thirteen",
    "fourteen",
    "fifteen",
    "sixteen",
    "seventeen",
    "eighteen",
    "nineteen",
];

English_Tens :: string.[
    "",
    "ten",
    "twenty",
    "thirty",
    "forty",
    "fifty",
    "sixty",
    "seventy",
    "eighty",
    "ninty",
];
```
The following is the output result of inputting the respective numbers into the function:
```
78 => seventy eight
313 => three hundred and thirteen
621 => six hundred and twenty one
755 => seven hundred and fifty five
751 => seven hundred and fifty one
926 => nine hundred and twenty six
281 => two hundred and eighty one
873 => eight hundred and seventy three
62 => sixty two
```

--- End of file: documents/22_miscellaneous_code_examples.md ---
