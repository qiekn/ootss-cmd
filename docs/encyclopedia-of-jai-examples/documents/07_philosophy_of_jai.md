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





