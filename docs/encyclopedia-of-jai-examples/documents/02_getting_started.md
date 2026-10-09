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




