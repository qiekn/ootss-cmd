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
