# Linked List

A linked list is a data structure in which elements are not stored such that elements can be randomly accessed in a contiguous memory block, but rather each node in a linked list points to the next. A linked list is a collection of nodes that allows for efficient insertion or removal of elemnts from any position in a sequence during iteration.

In Jai, we can define a linked list using the following syntax:
```jai
Node :: struct {
    data: int;
    next: *Node;
}
```

And we can create a simple printing function for a linked list like this:
```jai
print_linked_list :: (node: *Node) {
    print("[");
    while node {
        print("%, ", node.data);
        node = node.next;
    }
    print("]\n");
}
```

## Create a Node
This function instantiates a node using the allocator.
```jai
create_node :: (value: int) -> *Node {
    node := New(Node);
    node.data = value;
    node.next = null;
    return node;
}
```

## Appending Front
Unlike adding to the back, appending to the front is a quick four lines of code. 
```jai
append_front :: (head: **Node, data: int) {
    new_node := New(Node);
    new_node.data = data;
    new_node.next = head.*;
    head.* = new_node;
}
```

## Appending Back
This is a function to append an element to the end of a linked list. We initialize the element, traverse to the end, and append to the end. 
```jai
// create a node at the end of the list.
append :: (head: *Node, data: int) {
    assert(head != null);
    // initialize new node to append.
    new_node := New(Node);
    new_node.data = data;
    new_node.next = null;

    // traverse to the end of linked list.
    while(head.next) {
        head = head.next;
    }

    // append to the end of linked list.
    head.next = new_node;
}
```

## Insert Sorted

This function inserts a new element into an already sorted linked list.

```jai
insert_sorted :: (head: **Node, value: int) {
    new_node := create_node(value);

    // Empty list or insert at beginning
    if !head.* || head.*.data >= value {
        new_node.next = head.*;
        head.* = new_node;
        return;
    }

    // Find insertion point
    current := head.*;
    while current.next && current.next.data < value {
        current = current.next;
    }

    // Insert after current
    new_node.next = current.next;
    current.next = new_node;
}
```

## Removing Elements
A function to remove all elements of a particular value from a linked list.
```jai
remove_value :: (head: *Node, value: int) {
    if !head return;
    previous := head;
    current  := previous.next;
    while current {
        if current.data == value {
            previous.next = current.next;
        } else {
            previous = previous.next;
        }
        current = current.next;
    }
}
```
## Search Value
This function traverses all the linked list nodes and attempts to find the node with the parameter value. Returns the node if it could find it, else return null.
```jai
search :: (head: *Node, value: int) -> *Node {
    current := head;
    while current {
        if current.data == value {
            return current;
        }
        current = current.next;
    }
    return null;
}
```

## Find Index
This function finds the index of the linked list node with the value parameter. Returns -1 if no such node exists.
```jai
// Returns position (0-indexed), or -1 if not found
find_index :: (head: *Node, value: int) -> int {
    current := head;
    index := 0;

    while current {
        if current.data == value {
            return index;
        }
        current = current.next;
        index += 1;
    }

    return -1;
}
```

## Get Value at Index
These functions take as input an index position and returns the node and value found at that position.
```jai
get_at :: (head: *Node, position: int) -> *Node {
    current := head;
    index := 0;

    while current && index < position {
        current = current.next;
        index += 1;
    }

    return current;
}

// Get value at position (returns success flag and value)
get_value_at :: (head: *Node, position: int) -> found: bool, value: int {
    node := get_at(head, position);
    if !node return false, 0;
    return true, node.data;
}
```

## Length of Linked List

This function traverses the linked list in linear time O(n) and calculates the number of nodes in the list.

```jai
length :: (head: *Node) -> int {
    count := 0;
    current := head;

    while current {
        count += 1;
        current = current.next;
    }

    return count;
}
```

## Reverse Linked List
This function reverses the given linked list such that the beginning of the list becomes the end and the end becomes the beginning.
```jai
reverse :: (head: **Node) {
    previous: *Node = null;
    current := head.*;

    while current {
        next := current.next;
        current.next = previous;
        previous = current;
        current = next;
    }

    head.* = previous;
}
```

# Binary Search Tree
A binary tree is a hierarchical data structure where each node has at most two children: a left child and a right child. In Jai, we can implement this elegantly using structs and pointers.

```jai
Tree :: struct {
    data: int;
    left:  *Tree;
    right: *Tree;
}
```

## Creating a New Node
This function allocates a new tree node on the heap and initializes it with the given value.
```jai
create_node :: (value: int) -> *Tree {
    node := New(Tree);
    node.data = value;
    node.left = null;
    node.right = null;
    return node;
}
```

## Inserting into a Binary Search Tree
For a binary search tree (BST), we maintain the property that all values in the left subtree are less than the node's value, and all values in the right subtree are greater.
```jai
insert :: (root: **Tree, value: int) {
    // If tree is empty, create the root
    if !root.* {
        root.* = create_node(value);
        return;
    }
    
    // Recursively find the correct position
    if value < root.*.data {
        insert(*root.*.left, value);
    } else if value > root.*.data {
        insert(*root.*.right, value);
    }
    // If value equals data, we don't insert duplicates
}
```

## In Order Traversal

This traversal visits nodes in sorted order for a BST.

```jai
traverse_inorder :: (root: *Tree) {
    if !root return;
    
    traverse_inorder(root.left);
    print("% ", root.data);
    traverse_inorder(root.right);
}
```

## Pre-Order Traversal
This traversal visits nodes starting from the root, doing the left side, and then the right side of the Binary Search Tree.
```jai
traverse_preorder :: (root: *Tree) {
    if !root return;
    
    print("% ", root.data);
    traverse_preorder(root.left);
    traverse_preorder(root.right);
}
```

## Post-Order Traversal
This traversal visits nodes starting from the left side, the right side, and then the root of the Binary Search Tree.
```jai
traverse_postorder :: (root: *Tree) {
    if !root return;
    
    traverse_postorder(root.left);
    traverse_postorder(root.right);
    print("% ", root.data);
}
```

## Find a Value in the Binary Search Tree
This function searches for whether a node with a particular value appears in the binary search tree. It returns `null` if a value is not found. This performs a search in logarithmic time O(log n).

```jai
search :: (root: *Tree, value: int) -> *Tree {
    // Base cases: empty tree or value found
    if !root || root.data == value {
        return root;
    }
    
    // Value is smaller, search left subtree
    if value < root.data {
        return search(root.left, value);
    }
    
    // Value is larger, search right subtree
    return search(root.right, value);
}
```

## Finding the Minimum of the Binary Search Tree

This function finds the tree node with the smallest value of a binary search tree.
```jai
find_minimum :: (root: *Tree) -> *Tree {
    if !root return null;
    
    // Keep going left until we can't anymore
    while root.left {
        root = root.left;
    }
    return root;
}
```

## Finding the Maximum of the Binary Search Tree
This function finds the tree node with the largest value of a binary search tree.

```jai
find_maximum :: (root: *Tree) -> *Tree {
    if !root return null;
    
    // Keep going right until we can't anymore
    while root.right {
        root = root.right;
    }
    return root;
}
```

## Remove element from Binary Search Tree
Deletion is the most complex operation. We need to handle three cases:
* Node has no children (leaf node)
* Node has one child
* Node has two children
```jai
delete :: (root: **Tree, value: int) {
    if !root.* return;
    
    // Find the node to delete
    if value < root.*.data {
        delete(*root.*.left, value);
    } else if value > root.*.data {
        delete(*root.*.right, value);
    } else {
        // Found the node to delete
        node := root.*;
        
        // Case 1: No children (leaf node)
        if !node.left && !node.right {
            free(node);
            root.* = null;
        }
        // Case 2: Only right child
        else if !node.left {
            root.* = node.right;
            free(node);
        }
        // Case 2: Only left child
        else if !node.right {
            root.* = node.left;
            free(node);
        }
        // Case 3: Two children
        else {
            // Find the minimum value in right subtree (in-order successor)
            successor := find_minimum(node.right);
            
            // Copy the successor's value to this node
            node.data = successor.data;
            
            // Delete the successor
            delete(*node.right, successor.data);
        }
    }
}
```

## Counting Binary Search Tree Nodes

This function traverses the tree, recursively counting the number of nodes in the left and right sub-trees.
```jai
count_nodes :: (root: *Tree) -> int {
    if !root return 0;
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```

## Finding Binary Search Tree Height

This function finds the height of a tree. The height of a tree is the length of the path from the root to the deepest node in the tree.

```jai
height :: (root: *Tree) -> int {
    if !root return 0;
    
    left_height := height(root.left);
    right_height := height(root.right);
    
    return 1 + max(left_height, right_height);
}

max :: (a: int, b: int) -> int {
    if a > b return a;
    return b;
}
```

## Free the Tree

This function frees up the entire binary search tree. We recursively traverse the left and right subtrees of the root, freeing up the subtrees. At the end, we free up the root. It is best to set a fixed lifetime for the tree, allocate the tree in a temporary storage arena allocator, and free up the entire tree using `reset_temporary_storage();`. This function could be useful if the program logic is such that lifetimes of pointers is hard to track.

```jai
free_tree :: (root: *Tree) {
    if !root return;
    
    // Free children first (post-order)
    free_tree(root.left);
    free_tree(root.right);
    
    // Then free this node
    free(root);
}
```

# Trie

A Trie (pronounced "try", from retrieval) is a tree where each edge represents a character. Words are formed by following a path from the root to a node marked as a word-end. It is ideal for prefix searches, autocomplete, and dictionary lookups.
Structure

Each node holds an array of child pointers (one per possible character) and an is_end flag marking whether that position completes a valid word.

## Structure

Each node holds an array of child pointers (one per possible character) and an is_end flag marking whether that position completes a valid word.

```
// Words: "cat", "car", "card", "care", "bat"
//
//        root
//       /    \
//      c      b
//      |      |
//      a      a
//     / \     |
//    t*  r*   t*
//        |
//       / \
//      d*  e*
//
// * = is_end marker (valid word terminates here)
```

## When to use a Trie vs Hash Map
Use a Trie when you need prefix queries ("find all words starting with 'pre'"), autocomplete, or spell checking. A hash map is simpler and faster for pure exact-match lookups but cannot answer prefix queries efficiently.

## Node Definition
The Trie is defined as set of children `*Trie_Node` and a `is_end` boolean value to mark whether that position completes a valid word.

```jai
ALPHABET_SIZE :: 26;  // a-z only for simplicity

Trie_Node :: struct {
    children : [ALPHABET_SIZE]*Trie_Node;
    is_end   : bool;
}

Trie :: struct {
    root : *Trie_Node;
}
```

## Initialize and Destroy

This function initializes and frees the Trie Nodes.

```jai
trie_init :: (t: *Trie) {
    t.root = New(Trie_Node);  // zeroed: all children null, is_end false
}

node_free :: (node: *Trie_Node) {
    if !node  return;
    for node.children  node_free(it);  // recurse into children
    free(node);
}

trie_destroy :: (t: *Trie) {
    node_free(t.root);
    t.root = null;
}
```

## Contains

This function determines whether a particular word exists in the Trie.

```jai
trie_contains :: (t: *Trie, word: string) -> bool {
    node := t.root;

    for ch: word {
        index := cast(int) ch - cast(int) #char "a";
        if !node.children[index]  return false; // path doesn't exist
        node = node.children[index];
    }

    return node.is_end;  // only true if word actually ends here
}
```

## Starts With (Prefix Search)

This function determines whether a particular prefix exists within the trie.

```jai
trie_starts_with :: (t: *Trie, prefix: string) -> bool {
    node := t.root;

    for ch: prefix {
        index := cast(int) ch - cast(int) #char "a";
        if !node.children[index]  return false;
        node = node.children[index];
    }

    return true;  // reached end of prefix — it exists as a path
}
```

## Collect All Words with Prefix

This function finds all words containing a particular prefix.

```jai
collect_words :: (node: *Trie_Node, prefix: string, results: *[..]string) {
    if !node  return;
    if node.is_end  array_add(results, copy_string(prefix));

    for i: 0..ALPHABET_SIZE-1 {
        if node.children[i] {
            ch := cast(u8) (cast(int) #char "a" + i);
            collect_words(node.children[i], join(prefix, string.{1, *ch}), results);
        }
    }
}

trie_words_with_prefix :: (t: *Trie, prefix: string) -> [..]string {
    results : [..]string;
    node := t.root;

    for ch: prefix {
        index := cast(int) ch - cast(int) #char "a";
        if !node.children[index]  return results; // no match
        node = node.children[index];
    }

    collect_words(node, prefix, *results);
    return results;
}
```

## Example Usage

This example program demonstrates the functionality of the Trie.

```jai
main :: () {
    t : Trie;
    trie_init(*t);
    defer trie_destroy(*t);  // auto-cleanup when main returns

    trie_insert(*t, "cat");
    trie_insert(*t, "car");
    trie_insert(*t, "card");
    trie_insert(*t, "care");
    trie_insert(*t, "bat");

    print("contains 'car':  %\n", trie_contains(*t, "car"));    // true
    print("contains 'ca':   %\n", trie_contains(*t, "ca"));     // false
    print("starts_with 'ca':%\n", trie_starts_with(*t, "ca")); // true

    matches := trie_words_with_prefix(*t, "ca");
    for matches  print("  %\n", it); // cat, car, card, care
}

#import "Basic";
#import "String";
```
