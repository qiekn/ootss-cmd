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


