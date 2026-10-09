# Bubble Sort

Bubble Sort is a simple sorting algorithm that repeatedly steps through the array, compares adjacent elements, and swaps them if they are in the wrong order. This process is repeated until the list is sorted.

The following bubble sort algorithm below sorts all the elements in an array in ascending order.
```jai
bubble_sort :: (array: [] int) {

    sorted := false;

    while !sorted {
        i := 0;
        j := 1;
        sorted = true;
        while j < array.count {
            if array[j] < array[i] {
                array[j], array[i] = array[i], array[j];
                sorted = false;
            }
            i += 1;
            j += 1;
        }
    }
}
```

# Insertion Sort
Insertion sort that builds a sorted array one element at a time. Insertion sort iterates, consuming one input element each repetition, and grows a sorted output list. At each iteration, insertion sort removes one element from the input data, finds the correct location within the sorted list, and inserts it there. It repeats until no input elements remain.

The following insertion sort algorithm below sorts all the elements in an array in ascending order.
```jai
insertion_sort :: (array: [] int) {
    i := 1;
    while i < array.count {
        key := array[i];
        j := i - 1;
        while j >= 0 && key < array[j] {
            array[j + 1] = array[j];
            j -= 1;
        }
        array[j + 1] = key;
        i += 1;
    }
}
```

# Selection Sort
Selection Sort is a simple comparison-based sorting algorithm. It works by dividing the input list into two parts: the sorted portion and the unsorted portion. The algorithm repeatedly selects the smallest (or largest, depending on the order) element from the unsorted portion and swaps it with the first unsorted element, gradually growing the sorted portion.

The following selection sort algorithm below sorts all the elements in an array in ascending order.
```jai
selection_sort :: (array: [] int) {
    N := array.count - 1;
    for i : 0..N {
        ele := i;
        for j : (i+1)..N {
            if array[j] < array[ele] {
                ele = j;
            }
        }
        array[ele], array[i] = array[i], array[ele];
    }

}
```

# Heapsort

Heapsort is an efficient sorting algorithm that transforms an input array into a heap data structure. In a heap, each node is greater than its children. The largest node is repeatedly removed from that heap, and placed at the end of the array.

```jai
heapsort :: (array: [] int) {
    heapify(array);
    end := array.count;
    while end > 1 {
        end -= 1;
        array[end], array[0] = array[0], array[end];
        sift_down(array, 0, end);
    }
}

heapify :: (array: [] int) {
    start := parent(array.count - 1) + 1;
    while start > 0 {
        start -= 1;
        sift_down(array, start, array.count);
    }
}

sift_down :: (array: [] int, root: int, end: int) {
    while left_child(root) < end {
        child := left_child(root);
        if (child + 1) < end && array[child] < array[child + 1] {
             child += 1;
        }

        if array[root] < array[child] {
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

# Mergesort

Mergesort is an efficient and general purpose sorting algorithm. The algorithm time complexity of mergesort is O(n log n).

A merge sort works as follows:
* Divide the unsorted list into n sub-lists, each containing one element.
* Repeatedly merge sublists to produce new sorted sublists until there is only one sublist remaining. This will be the sorted list.

```jai
merge_sort :: (arr: [] int) {
    // Merge two subarrays L and M into arr
    merge :: (arr: [] int, p: int, q: int, r: int) {
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
            if L[i] <= M[j] {
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

    merge_sort_helper :: (arr: [] int, l: int, r: int) {
        if l < r {
            m := l + (r - l) / 2;
            merge_sort_helper(arr, l, m);
            merge_sort_helper(arr, m + 1, r);
            merge(arr, l, m, r);
        }
    }

    merge_sort_helper(arr, 0, arr.count - 1);
}
```

# Radix Sort
The Radix Sort algorithm sorts the elements by grouping the individual digits of the same place value. Then, sort the elements according to their increasing/decreasing order. The time complexity of radix sort is O(d⋅n), where:
* n is the number of elements in the array.
* d is the number of digits in the largest number.
This makes radix sort efficient for sorting large datasets with a fixed number of digits.

```jai
radixsort :: (array: [] int) {
    // get the largest element from an array
    max_value := array[0];
    for ele : array {
        max_value = max(max_value, ele);
    }

    place := 1;
    while max_value / place > 0 {
        countingSort(array, array.count, place);
        place *= 10;
    }
}

countingSort :: (array: [] int, size: int, place: int) {
    maximum :: 10;
    output := NewArray(size, int);
    count := NewArray(maximum, int);

    for *val : count {
        val.* = 0;
    }

    for i : 0..size-1 {
        count[(array[i] / place) % 10] += 1;
    }

    for i : 1..maximum - 1 {
        count[i] += count[i - 1];
    }

    i := size - 1;
    while i >= 0 {
        output[count[(array[i] / place) % 10] - 1] = array[i];
        count[(array[i] / place) % 10] -= 1;
        i -= 1;
    }

    i = 0;
    while i < size {
        array[i] = output[i];
        i += 1;
    }
}
```

# Quicksort
Quicksort is an efficient, general-purpose sorting algorithm with a time complexity of O(n log n). It is one of the most commonly used algorithms for sorting.

## Steps Involved in quicksort
Quicksort selects a pivot element from the array and partitions the other elements into two sub-arrays:
* Elements less than the pivot
* Elements greater than the pivot
It then recursively applies the same logic to the sub-arrays.

```jai
quicksort :: (array: [] int) {

    partition :: (array: [] int, low: int, high: int) -> int {
        pivot := array[high];

        i := low;
        j := low;
        while j < high {
            if array[j] < pivot {
                array[i], array[j] = array[j], array[i];
                i += 1;
            }
            j += 1;
        }
        array[i], array[high] = array[high], array[i];
        return i;
    }

    quicksort_helper :: (array: [] int, low: int, high: int) {
        if (low >= high || low < 0) {
            return;
        }

        p := partition(array, low, high);
        quicksort_helper(array, low, p - 1);
        quicksort_helper(array, p + 1, high);
    }

    quicksort_helper(array, 0, array.count - 1);
}
```

# Linear Search
A linear search is a basic search algorithm that examines each element of an array one by one until it finds the correct value. This is a O(n) algorithm.

## While Loop Linear Search
An example of a linear search with a while loop.
```jai
linear_search :: (array: [] int, value: int) -> found: bool, index: int {
    index := -1;
    i := 0;
    while i < array.count {
        if array[i] == value {
            return true, i;
        }
        i += 1;
    }
    return false, -1;
}
```

## For Loop Linear Search
An example of a linear search with a for loop.
```jai
linear_search :: (array: [] int, value: int) -> found: bool, index: int {
    for element, i : array {
        if element == value {
            return true, i;
        }
    }
    return false, -1;
}

```

# Binary Search
Binary search is a search algorithm that efficiently finds the position of a target value within a sorted array within **O(log n)** time.

## Iterative Binary Search
```jai
binary_search :: (array: [] int, value: int) -> found: bool, index: int {
    low := 0;
    high := array.count - 1;
    while low <= high {
        mid := (low + high) / 2;
        if array[mid] == value {
            return true, mid;
        } else if array[mid] < value {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    return false, -1;
}
```

## Recursive Binary Search
```jai
binary_search :: (array: [] int, value: int) -> found: bool, index: int {
    binary_search_helper :: (array: [] int, value: int, low: int, high: int) -> found: bool, index: int {
        if low > high {
            return false, -1;
        }

        mid := (low + high) / 2;
        if array[mid] == value {
            return true, mid;
        } else if array[mid] < value {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
        found, index := binary_search_helper(array, value, low, high);
        return found, index;
    }

    found, index := binary_search_helper(array, value, 0, array.count - 1);
    return found, index;
}
```

