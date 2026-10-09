# Basic Polymorphism

## Polymorphic Add
A polymorphic add returns the sum of two elements of the same datatype. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
add :: (a: $T, b: T) -> T {
    return a + b;
}
```
## Polymorphic Sub
A polymorphic sub returns the difference of two elements of the same datatype. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
sub :: (a: $T, b: T) -> T {
    return a + b;
}
```
## Polymorphic Multiply
A polymorphic multiply returns the product of two elements of the same datatype. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
multiply :: (a: $T, b: T) -> T {
    return a * b;
}
```

## Polymorphic Divide
A polymorphic divide returns the division of two elements of the same datatype. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
divide :: (a: $T, b: T) -> T {
    return a / b;
}
```

## Polymorphic Max
A polymorphic max returns the greater of two elements. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
max :: (a: $T, b: T) -> T {
    if a > b return a;
    return b;
}
```

## Polymorphic Min
A polymorphic min returns the greater of two elements. This function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
min :: (a: $T, b: T) -> T {
    if a < b return a;
    return b;
}
```

## Polymorphic Absolute Value
A polymorphic absolute value function that transforms a negative value into a positive value and leaves the positive value alone. This function generalizes across all sorts of different number types such as `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
abs :: (x: $T) -> T {
    if x < 0 {
        x = -x;
    }

    return x;
}
```

## Polymorphic Linear Search

A linear search that iterates across an array to find a value that is equivalent to the provided given parameter.
```jai
linear_search :: (array: [] $T, value: T) -> int {
    for ele, i : array {
        if ele == value {
            return i;
        }
    }
    return -1;
}
```

## Polymorphic Clamp
Clamping is the process of limiting a value to a range between a minimum and a maximum value. As a polymorphic procedure, this function generalizes across all sorts of different types like `s64`, `s32`, `s8`, `float32`, and `float64`.
```jai
clamp :: (a: $T, min: T, max: T) -> T {
    if a < min {
        return min;
    }
    if a > max {
        return max;
    }
    return a;
}
```

## Polymorphic Reverse

A function to reverse all elements in the array such that the first element is the last element and vice versa.
```jai
reverse :: (array: [] $T) {
    begin := 0;
    end := array.count - 1;
    while begin < end {
        array[begin], array[end] = array[end], array[begin];
        begin += 1;
        end -= 1;
    }
}
```

## Polymorphic Fill
This function fills an entire array with a specified value.
```jai
fill :: (array: [] $T, value: T) {
    for *element: array {
        element.* = value;
    }
}
```

## Polymorphic Count Occurances
This function counts how many times a value appears in an array.
```jai
count_occurrences :: (array: []$T, value: T) -> int {
    count := 0;
    for element: array {
        if element == value {
            count += 1;
        }
    }
    return count;
}
```

## Polymorphic Sum of Array Elements
This function calculates the sum of all elements in an array.
```jai
sum :: (array: []$T) -> T {
    total: T = 0;
    for element: array {
        total += element;
    }
    return total;
}
```

## Polymorphic Average of Array Elements
This function calculates the average value of array elements.
```jai
average :: (array: []$T) -> T {
    if array.count == 0 return 0;
    
    total: T = 0;
    for element: array {
        total += element;
    }
    return total / cast(T)array.count;
}
```


## Polymorphic Array Shuffle

This is some code to shuffle an array using the Fischer-Yates shuffle algorithm. One can define a `random_s64` function to make the casting to make the code more aesthetically pleasing to read. This algorithm works across of sorts of different data types, e.g. floats, integers, strings, user defined objects, etc.

```jai
random_s64 :: () -> s64 {
    r := (random_get() & 0x7FFF_FFFF);
    return cast(s64)r;
}

shuffle :: (array: [] $T) {
    N := array.count - 1;
    for < i : 1..N {
        r := random_s64() % i;
        array[i], array[r] = array[r], array[i];
    }
}
```

Here is a while loop version of the code:
```jai
shuffle :: (array: [] $T) {
    i := array.count - 1;
    while i >= 1 {
        r := random_s64() % i;
        array[i], array[r] = array[r], array[i];
        i -= 1;
    }
}
```

# Polymorphic Sorting Algorithms

## Bubble Sort

We can use the `$T` to indicate that a type is polymorphic. We can transform a bubble sort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.

```jai
bubble_sort :: (array:[] $T, $comparison: (T, T) -> bool) {

    sorted := false;

    while !sorted {
        i := 0;
        j := 1;
        sorted = true;
        while j < array.count {
            if comparison(array[j], array[i]) {
                array[j], array[i] = array[i], array[j];
                sorted = false;
            }
            i += 1;
            j += 1;
        }
    }
}
```

We call the same bubble sort for both integer and float types, and do both ascending and descending sort.
```jai
main :: () {
    // array of integers
    array_integers := int.[1, 3, 2, 5, 4, 6, 9, 8, 7];

    // sort ascending
    bubble_sort(array_integers, (a,b) => a < b);
    print("%\n", array_integers);

    // sort descending
    bubble_sort(array_integers, (a,b) => a > b);
    print("%\n", array_integers);

    // array of floats
    array_floats := float.[1.5, 3.2, 2.1, 0.75, 4.8, 9.6, 10.9, 8.3, 7.2];

    // sort ascending
    bubble_sort(array_floats, (a,b) => a < b);
    print("%\n", array_floats);

    // sort descending
    bubble_sort(array_floats, (a,b) => a > b);
    print("%\n", array_floats);

    // array of strings
    array_strings := string.["zoo", "apple", "boy", "mummy", "king", "camel"];

    // sort strings in alphabetical order.
    bubble_sort(array_strings, (a,b) => compare(a,b) == -1);
    print("%\n", array_strings);
}
```

We can apply our sort on custom structs such as the follow `Person` struct and use bubble sort to sort the `Person` arrays by age or arrange the `Person` array in alphabetical order.
```jai
Person :: struct {
    name: string;
    age: int;
}

main :: () {
    people: [5] Person;
    people[0] = .{"Alice", 30};
    people[1] = .{"Bob", 25};
    people[2] = .{"Charlie", 35};
    people[3] = .{"Diana", 28};
    people[4] = .{"Eve", 22};

    // Sort by age
    print("Original:\n");
    for people {
        print("  % (age %)\n", it.name, it.age);
    }

    bubble_sort(people, (a, b) => a.age < b.age);
    print("\nSorted by age:\n");
    for people {
        print("  % (age %)\n", it.name, it.age);
    }

    // Sort by name
    bubble_sort(people, (a, b) => compare(a.name, b.name) == -1);
    print("\nSorted by name:\n");
    for people {
        print("  % (age %)\n", it.name, it.age);
    }
}

```


## Insertion Sort

We can use the `$T` to indicate that a type is polymorphic. We can transform an insertion sort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.

```jai
insertion_sort :: (array: [] $T, $compare: (T, T) -> bool) {
    i := 1;
    while i < array.count {
        key := array[i];
        j := i - 1;
        while j >= 0 && compare(key, array[j]) {
            array[j + 1] = array[j];
            j -= 1;
        }
        array[j + 1] = key;
        i += 1;
    }
}
```

We call the same insertion sort for both integer and float types.

```jai
main :: () {
    array_integers := int.[5,3,6,7,1,2];
    insertion_sort(array_integers, (a,b) => a < b);
    print("%\n", array_integers);

    array_floats := float.[3.14, 97.3, 60.3, 4.5, 1.2];
    insertion_sort(array_floats, (a,b) => a < b);
    print("%\n", array_floats);
}
```
## Selection Sort

We can use the `$T` to indicate that a type is polymorphic. We can transform a selection sort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.
```jai
selection_sort :: (array: [] $T, $compare: (T, T) -> bool) {
    N := array.count - 1;
    for i : 0..N {
        ele := i;
        for j : (i+1)..N {
            if compare(array[j], array[ele]) {
                ele = j;
            }
        }
        array[ele], array[i] = array[i], array[ele];
    }

}
```
We call the same selection sort for both integer and float types.
```jai
main :: () {
    array_integers := int.[5,3,6,7,1,2];
    selection_sort(array_integers, (a,b) => a < b);
    print("%\n", array_integers);

    array_floats := float.[3.14, 97.3, 60.3, 4.5, 1.2];
    selection_sort(array_floats, (a,b) => a < b);
    print("%\n", array_floats);
}
```

## Heapsort
We can use the `$T` to indicate that a type is polymorphic. We can transform a heapsort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.
```jai
heapsort :: (array: [] $T, $compare: (T,T)->bool) {
    heapify(array, compare);
    end := array.count;
    while end > 1 {
        end -= 1;
        array[end], array[0] = array[0], array[end];
        sift_down(array, 0, end, compare);
    }
}

heapify :: (array: [] $T, $compare: (T,T)->bool) {
    start := parent(array.count - 1) + 1;
    while start > 0 {
        start -= 1;
        sift_down(array, start, array.count, compare);
    }
}

sift_down :: (array: [] $T, root: int, end: int, $compare: (T,T)->bool) {
    while left_child(root) < end {
        child := left_child(root);
        if (child + 1) < end && compare(array[child], array[child + 1]) {
             child += 1;
        }

        if compare(array[root], array[child]) {
            array[root], array[child] = array[child], array[root];
            root = child;
        } else {
            return;
        }
    }
}

left_child :: (i: int) -> int {
    return (2 * i) + 1;
}

right_child :: (i: int) -> int {
    return (2 * i) + 2;
}

parent :: (i: int) -> int {
    return (i - 1) / 2;
}
```
We call the same polymorphic merge sort code for both floats and integers. This mergesort generalizes across many different types and avoids code duplication across different data types.
```jai
main :: () {
    array_integers := int.[5, 1, 7, 2, 4, 3, 6, 8, 9];
    heapsort(array_integers, (a,b) => a < b);
    print("array_integers = %\n", array_integers);

    array_floats := float.[5.9, 1.23, 7.3, 2.4, 4.8, 6.99, 9.3, 21.1, 3.3];
    heapsort(array_floats, (a,b) => a < b);
    print("array_floats = %\n", array_floats);

}
```


## Mergesort
We can use the `$T` to indicate that a type is polymorphic. We can transform a mergesort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.
```jai
merge_sort :: (arr: [] $T, $compare: (T,T) -> bool) {
    // Merge two subarrays L and M into arr
    merge :: (arr: [] $T, p: int, q: int, r: int, $compare: (T,T) -> bool) {
        n1 := q - p + 1;
        n2 := r - q;
        L := NewArray(n1, int);
        M := NewArray(n2, int);

        for i : 0..(n1-1) {
            L[i] = arr[p + i];
        }

        for j : 0..(n2-1) {
            M[j] = arr[q + 1 + j];
        }

        // Maintain current index of sub-arrays and main array
        i := 0;
        j := 0;
        k := p;
        while i < n1 && j < n2 {
            if compare(L[i], M[j]) {
                arr[k] = L[i];
                i += 1;
            } else {
                arr[k] = M[j];
                j += 1;
            }
            k += 1;
        }

        while i < n1 {
            arr[k] = L[i];
            i += 1;
            k += 1;
        }

        while (j < n2) {
            arr[k] = M[j];
            j += 1;
            k += 1;
        }
    }

    merge_sort_helper :: (arr: [] $T, l: int, r: int, $compare: (T,T) -> bool) {
        if l < r {
            m := l + (r - l) / 2;
            merge_sort_helper(arr, l, m, compare);
            merge_sort_helper(arr, m + 1, r, compare);
            merge(arr, l, m, r, compare);
        }
    }

    merge_sort_helper(arr, 0, arr.count - 1, compare);
}
```
We call the same polymorphic merge sort code for both ascending and descending arrays. This mergesort generalizes across many different types and avoids code duplication.
```jai
main :: () {
  arr := int.[6, 5, 12, 10, 9, 1];
  merge_sort(arr, (a,b) => a < b);
  print("Sort Ascending: %\n", arr);

  merge_sort(arr, (a,b) => a > b);
  print("Sort Descending: %\n", arr);
}
```

## Quicksort
We can use the `$T` to indicate that a type is polymorphic. We can transform a quicksort algorithm such that it can take in integer, string, float, and many other different kinds of types as input. We can generalize the function across many different types and avoid code duplication.
```jai
quicksort :: (array: [] $T, $compare: (T,T) -> bool) {

    partition :: (array: [] $T, low: int, high: int, $compare: (T,T) -> bool) -> int {
        pivot := array[high];

        i := low;
        j := low;
        while j < high {
            if compare(array[j], pivot) {
                array[i], array[j] = array[j], array[i];
                i += 1;
            }
            j += 1;
        }
        array[i], array[high] = array[high], array[i];
        return i;
    }

    quicksort_helper :: (array: [] $T, low: int, high: int, $compare: (T,T) -> bool) {
        if (low >= high || low < 0) {
            return;
        }

        p := partition(array, low, high, compare);
        quicksort_helper(array, low, p - 1, compare);
        quicksort_helper(array, p + 1, high, compare);
    }

    quicksort_helper(array, 0, array.count - 1, compare);
}
```
We call the same quicksort for both integer and float types.
```jai
main :: () {
    array_integers := int.[5,3,6,7,1,2];
    quicksort(array_integers, (a,b) => a < b);
    print("%\n", array_integers);

    array_floats := float.[3.14, 97.3, 60.3, 4.5, 1.2];
    quicksort(array_floats, (a,b) => a < b);
    print("%\n", array_floats);
}
```

# Higher Order Functions

## Map
Map is a higher-order function that applies a given function to each element of a data structure. One can write a basic map in the following way. 

```jai
map :: (array: [] $T, $function: (T) -> T) -> [] T {
    answer := NewArray(array.count, T);
    N := array.count - 1;
    for i : 0..N {
        answer[i] = function(array[i]);
    }
    return answer;
}

main :: () {
    array := map(int.[1,2,3,4,5], (x) => (x + 1));
    print("%\n", array);

    array = map(int.[1,2,3,4,5], (x) => (x * 2));
    print("%\n", array);
}
```

## Filter

Filter is a higher-order function that iterates through a data structure and produces a new data structure containing only the elements that satisfies the given function conditional as `true`.

```jai
filter :: (array: [] $T, $function: (T) -> bool) -> [] T {
    answer: [..] T;
    for ele : array {
        if function(ele) {
            array_add(*answer, ele);
        }
    }
    return answer;
}


main :: () {
    // filter to get only odd numbers
    array := filter(int.[1,2,3,4,5,6,7,8,9,10], (x) => (x % 2) != 0);
    print("%\n", array);

    // filter to get only even numbers
    array = filter(int.[1,2,3,4,5,6,7,8,9,10], (x) => (x % 2) == 0);
    print("%\n", array);
}
```

## Reduce

Reduce is a higher-order function that iterates through a data structure and produces a value based the interaction of the elements of the array and the element being computed.

```jai
reduce :: (array: [] $T, $function: (T,T) -> T) -> T {
    answer: T;
    for ele : array {
        answer = function(answer, ele);
    }
    return answer;
}

main :: () {
    array_integer := int.[1,2,3,4,5];
    answer1 := reduce(array_integer, (a,b) => (a + b));
    print("%\n", answer1);

    array_string := string.["The", "lazy", "fox"];
    answer2 := reduce(array_string, (a,b) => join(a, b, " "));
    print("%\n", answer2);
}
```

