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
