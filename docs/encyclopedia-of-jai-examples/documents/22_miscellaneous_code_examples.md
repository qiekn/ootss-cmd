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
