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
