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

