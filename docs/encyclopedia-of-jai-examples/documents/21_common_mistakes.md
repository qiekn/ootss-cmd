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
