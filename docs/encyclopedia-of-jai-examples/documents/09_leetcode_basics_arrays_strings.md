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
