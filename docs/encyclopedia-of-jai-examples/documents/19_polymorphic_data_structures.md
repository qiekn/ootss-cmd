# Polymorphic Linked List

A polymorphic linked list can be defined by using a parenthesized struct with type parameters `T: Type`. To specify a different linked list type, just change the `T: Type` parameter to match what one desires. This approach allows one to create linked lists of integers, floats, strings, etc. and generalize the linked list data structure across all different types.
```jai
Node :: struct(T: Type) {
    data: T;
    next: *Node(T);
}
```

## Print Linked List 1

Given Linked List definition above, one can write a polymorphic print linked list function and specific `$T` parameter to allow the type of the function to be determined at compile time.
```jai
print_linked_list :: (node: *Node($T)) {
    print("[");
    while node {
        print("%, ", node.data);
        node = node.next;
    }
    print("]\n");
}
```
## Print Linked List 2

This is another polymorphic print linked list, but instead of parameterizing the Node parameter the `$T`, one parameterizes the entire struct. This has the same functionality of the previous print, but slightly different error messages.
```jai
print_linked_list :: (node: *$T/Node) {
    print("[");
    while node {
        print("%, ", node.data);
        node = node.next;
    }
    print("]\n");
}
```

## Print Linked List 3
This is a implicit polymorphism version of the print linked list function. This functions exactly the same as previous functions, except the polymorphism is implicit rather than explicit. Implicit polymorphism allows easy conversion of functions manipulating data structures into polymorphic functions, reducing friction when refactoring code into more polymorphic code.
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

## Instantiating a node
This function instantiates a polymorphic linked list node. This function generalizes across all different types of nodes.
```jai
create_node :: (value: $T) -> *Node(T) {
    node := New(Node(T));
    node.data = value;
    node.next = null;
    return node;
}
```

## Append Front 1
Append front can be transformed into a polymorphic function in the following way.
```jai
append_front :: (head: **Node($T), data: T) {
    new_node := New(Node(T));
    new_node.data = data;
    new_node.next = head.*;
    head.* = new_node;
}
```

## Append Front 2
One can switch around the `$T` to the second parameter if one wants to.
```jai
append_front :: (head: **Node(T), data: $T) {
    new_node := New(Node(T));
    new_node.data = data;
    new_node.next = head.*;
    head.* = new_node;
}
```

## Append Front 3
This is another way of writing a polymorphic append front.
```jai
append_front :: (head: **$T/Node, data: T.T) {
    new_node := New(Node(T.T));
    new_node.data = data;
    new_node.next = head.*;
    head.* = new_node;
}
```

## Append 1
Append can be made into a polymorphic function using the following method.
```jai
// create a node at the end of the list.
append :: (head: *Node($T), data: T) {
    assert(head != null);
    // initialize new node to append.
    new_node := New(Node(T));
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

## Append 2
Append can be made into a polymorphic function using the following method.
```jai
// create a node at the end of the list.
append :: (head: *Node, data: head.T) {
    assert(head != null);
    // initialize new node to append.
    new_node := New(Node(head.T));
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

## Insert Sorted 1
This function inserts an element into a sorted linked list. This polymorphic function applies the `$T` on the Node parameterized struct.
```jai
insert_sorted :: (head: **Node($T), value: T) {
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

## Insert Sorted 2
This is another function that inserts an element into a sorted linked list.
```jai
insert_sorted2 :: (head: **$T/Node, value: T.T) {
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

## Remove Value 1
This function traverses a linked list and removes all occurrences of a value from a linked list. This is a polymorphic function that uses `$T` polymorphism.
```jai
remove_value :: (head: *Node($T), value: T) {
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
## Remove Value 2
This function traverses a linked list and removes all occurrences of a value from a linked list. This is another version of the polymorphic function.
```jai
remove_value :: (head: *$T/Node, value: T.T) {
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
## Remove Value 3
This function traverses a linked list and removes all occurrences of a value from a linked list. This is function that takes advantage of implicit polymorphism.
```jai
remove_value3 :: (head: *Node, value: head.T) {
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
## Search 1
This is a polymorphic linked list search function where the Node has a polymorphic parameter `$T`.
```jai
search :: (head: *Node($T), value: T) -> *Node(T) {
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

## Search 2
This is a polymorphic linked list search function where `$T` must be a parameterized struct of type `Node`.
```jai
search :: (head: *$T/Node, value: T.T) -> *T {
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

## Search 3
This is a polymorphic linked list search function using implicit polymorphism.
```jai
search :: (head: *Node, value: head.T) -> type_of(head) {
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

## Length 1
This is a polymorphic linked list length function where the Node has a polymorphic parameter `$T`.
```jai
length :: (head: *Node($T)) -> int {
    count := 0;
    current := head;
    while current {
        count += 1;
        current = current.next;
    }
    return count;
}
```

## Length 2
This is a polymorphic linked list length function where `$T` must be a parameterized struct of type `Node`.
```jai
length :: (head: *$T/Node) -> int {
    count := 0;
    current := head;
    while current {
        count += 1;
        current = current.next;
    }
    return count;
}
```

## Length 3
This is a polymorphic linked list length function using implicit polymorphism.
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

## Reverse 1
This is a polymorphic linked list reverse function where the Node has a polymorphic parameter `$T`.
```jai
reverse1 :: (head: **Node($T)) {
    previous: *Node(T) = null;
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
## Reverse 2
This is a polymorphic linked list reverse function where `$T` must be a parameterized struct of type `Node`.
```jai
reverse :: (head: **$T/Node) {
    previous: *T = null;
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
## Reverse 3
This is a polymorphic linked list reverse function using implicit polymorphism.
```jai
reverse :: (head: **Node) {
    previous: type_of(head.*) = null;
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

# Polymorphic Tree
A binary tree is a hierarchical data structure where each node has at most two children: a left child and a right child. In Jai, we can implement this elegantly using structs and pointers.

```jai
Tree :: struct(T: Type) {
    data: T;
    left:  *Tree(T);
    right: *Tree(T);
}
```

## Create Node
This function allocates a new tree node on the heap and initializes it with the given value.
```jai
create_node :: (value: $T) -> *Tree(T) {
    node := New(Tree(T));
    node.data = value;
    node.left = null;
    node.right = null;
    return node;
}
```

## Insert 1
This is a polymorphic tree insert function where the Node has a polymorphic parameter `$T`.
```jai
insert :: (root: **Tree($T), value: T) {
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

## Insert 2
This is a polymorphic insert function where `$T` must be a parameterized struct of type `Tree`.
```jai
insert :: (root: **$T/Tree, value: T.T) {
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

## Insert 3
This is a polymorphic insert function which uses implicit polymorphism.
```jai
insert :: (root: **Tree, value: type_of(root.*.data)) {
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

## Traverse Inorder 1
This is a polymorphic inorder tree traversal where the Tree has a polymorphic parameter `$T`.
```jai
traverse_inorder :: (root: *Tree($T)) {
    if !root return;
    traverse_inorder(root.left);
    print("% ", root.data);
    traverse_inorder(root.right);
}
```
## Traverse Inorder 2
This is a polymorphic inorder tree traversal where `$T` must be a parameterized struct of type `Tree`.
```jai
traverse_inorder :: (root: *$T/Tree) {
    if !root return;
    traverse_inorder(root.left);
    print("% ", root.data);
    traverse_inorder(root.right);
}
```
## Traverse Inorder 3
This is a polymorphic inorder tree traversal function which uses implicit polymorphism.
```jai
traverse_inorder :: (root: *Tree) {
    if !root return;
    traverse_inorder(root.left);
    print("% ", root.data);
    traverse_inorder(root.right);
}
```
## Traverse Preorder 1
This is a polymorphic preorder tree traversal where the Tree has a polymorphic parameter `$T`.
```jai
traverse_preorder :: (root: *Tree($T)) {
    if !root return;
    print("% ", root.data);
    traverse_preorder(root.left);
    traverse_preorder(root.right);
}
```
## Traverse Preorder 2
This is a polymorphic preorder tree traversal where `$T` must be a parameterized struct of type `Tree`.
```jai
traverse_preorder :: (root: *$T/Tree) {
    if !root return;
    print("% ", root.data);
    traverse_preorder(root.left);
    traverse_preorder(root.right);
}
```
## Traverse Preorder 3
This is a polymorphic preorder tree traversal function which uses implicit polymorphism.
```jai
traverse_preorder :: (root: *Tree) {
    if !root return;
    print("% ", root.data);
    traverse_preorder(root.left);
    traverse_preorder(root.right);
}
```
## Traverse Postorder 1
This is a polymorphic postorder tree traversal where the Tree has a polymorphic parameter `$T`.
```jai
traverse_postorder :: (root: *Tree($T)) {
    if !root return;
    traverse_postorder(root.left);
    traverse_postorder(root.right);
    print("% ", root.data);
}
```
## Traverse Postorder 2
This is a polymorphic postorder tree traversal where `$T` must be a parameterized struct of type `Tree`.
```jai
traverse_postorder :: (root: *$T/Tree) {
    if !root return;
    traverse_postorder(root.left);
    traverse_postorder(root.right);
    print("% ", root.data);
}
```
## Traverse Postorder 3
This is a polymorphic postorder tree traversal function which uses implicit polymorphism.
```jai
traverse_postorder :: (root: *Tree) {
    if !root return;
    traverse_postorder(root.left);
    traverse_postorder(root.right);
    print("% ", root.data);
}
```

## Search 1
This is a polymorphic tree search where the Tree has a polymorphic parameter `$T`.
```jai
search :: (root: *Tree($T), value: T) -> *Tree(T) {
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
## Search 2
This is a polymorphic tree search where `$T` must be a parameterized struct of type `Tree`.
```jai
search :: (root: *$T/Tree, value: T.T) -> *T {
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
## Search 3
This is a polymorphic tree search function which uses implicit polymorphism.
```jai
search :: (root: *Tree, value: root.T) -> type_of(root) {
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

## Find Minimum 1
This function finds the tree node with the smallest value of a binary search tree. This is a polymorphic function where the Tree has a polymorphic parameter `$T`.
```jai
find_minimum :: (root: *Tree($T)) -> *Tree(T) {
    if !root return null;
    // Keep going left until we can't anymore
    while root.left {
        root = root.left;
    }
    return root;
}
```
## Find Minimum 2
This function finds the tree node with the smallest value of a binary search tree. This is a polymorphic tree search where `$T` must be a parameterized struct of type `Tree`.
```jai
find_minimum :: (root: *$T/Tree) -> *T {
    if !root return null;
    // Keep going left until we can't anymore
    while root.left {
        root = root.left;
    }
    return root;
}
```
## Find Minimum 3
This function finds the tree node with the smallest value of a binary search tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
find_minimum :: (root: *Tree) -> type_of(root) {
    if !root return null;
    // Keep going left until we can't anymore
    while root.left {
        root = root.left;
    }
    return root;
}
```

## Find Maximum 1
This function finds the tree node with the largest value of a binary search tree. This is a polymorphic function where the Tree has a polymorphic parameter `$T`.
```jai
find_maximum :: (root: *Tree($T)) -> *Tree(T) {
    if !root return null;
    // Keep going right until we can't anymore
    while root.right {
        root = root.right;
    }
    return root;
}
```
## Find Maximum 2
This function finds the tree node with the largest value of a binary search tree. This is a polymorphic tree search where `$T` must be a parameterized struct of type `Tree`.
```jai
find_maximum :: (root: *$T/Tree) -> *T {
    if !root return null;
    // Keep going right until we can't anymore
    while root.right {
        root = root.right;
    }
    return root;
}
```
## Find Maximum 3
This function finds the tree node with the largest value of a binary search tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
find_maximum :: (root: *Tree) -> type_of(root) {
    if !root return null;
    // Keep going right until we can't anymore
    while root.right {
        root = root.right;
    }
    return root;
}
```

## Delete Node
Delete a node from the tree while maintaining the binary search tree correctness. This takes advantage of implicit polymorphism to generalize this function across all polymorphic Tree data structures.
```jai
delete :: (root: **Tree, value: type_of(root.*.data)) {
    if !root.* return;
    if value < root.*.data {
        delete(*root.*.left, value);
    } else if value > root.*.data {
        delete(*root.*.right, value);
    } else {
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

## Count Nodes 1
This function counts the number of nodes in a tree. This is a polymorphic function where the Tree has a polymorphic parameter `$T`.
```jai
count_nodes :: (root: *Tree($T)) -> int {
    if !root return 0;
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```
## Count Nodes 2
This function counts the number of nodes in a tree. This is a polymorphic function where `$T` must be a parameterized struct of type `Tree`.
```jai
count_nodes :: (root: *$T/Tree) -> int {
    if !root return 0;
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```
## Count Nodes 3
This function counts the number of node in a tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
count_nodes :: (root: *Tree) -> int {
    if !root return 0;
    return 1 + count_nodes(root.left) + count_nodes(root.right);
}
```
## Height 1
This function computes the height of a tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
height :: (root: *Tree($T)) -> int {
    if !root return 0;
    left_height := height(root.left);
    right_height := height(root.right);
    return 1 + max(left_height, right_height);
}
```
## Height 2
This function computes the height of a tree. This is a polymorphic function where `$T` must be a parameterized struct of type `Tree`.
```jai
height :: (root: *$T/Tree) -> int {
    if !root return 0;
    left_height := height(root.left);
    right_height := height(root.right);
    return 1 + max(left_height, right_height);
}
```

## Height 3
This function computes the height of a tree. This is a polymorphic tree search that utilizes implicit polymorphism.
```jai
height :: (root: *Tree) -> int {
    if !root return 0;
    left_height := height(root.left);
    right_height := height(root.right);
    return 1 + max(left_height, right_height);
}
```

# Polymorphic Vec3
A polymorphic Vec3 struct that allows for any parameter type for data members `x`, `y`, and `z`.
```jai
Vec3 :: struct(T: Type) {
    x: T;
    y: T;
    z: T;
}
```

## Operator Add 1
This is an operator overloaded `+` for `Vec3`. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
operator + :: (a: Vec3($T), b: Vec3(T)) -> Vec3(T) {
    c: Vec3(T);
    c.x = a.x + b.x;
    c.y = a.y + b.y;
    c.z = a.z + b.z;
    return c;
}
```

## Operator Add 2
This is an operator overloaded `+` for `Vec3`. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec`.
```jai
operator + :: (a: $T/Vec3, b: T) -> T {
    c: Vec3(T.T);
    c.x = a.x + b.x;
    c.y = a.y + b.y;
    c.z = a.z + b.z;
    return c;
}
```

## Operator Sub 1
This is an operator overloaded `-` for `Vec3`. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
operator - :: (a: Vec3($T), b: Vec3(T)) -> Vec3(T) {
    c: Vec3(T);
    c.x = a.x - b.x;
    c.y = a.y - b.y;
    c.z = a.z - b.z;
    return c;
}
```
## Operator Sub 2
This is an operator overloaded `-` for `Vec3`. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec`.
```jai
operator - :: (a: $T/Vec3, b: T) -> T {
    c: Vec3(T.T);
    c.x = a.x - b.x;
    c.y = a.y - b.y;
    c.z = a.z - b.z;
    return c;
}
```

## Operator Negation 1
This is an operator overloaded `-` for `Vec3`. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
operator - :: (a: Vec3($T)) -> Vec3(T) {
    b: Vec3(T);
    b.x = -a.x;
    b.y = -a.y;
    b.z = -a.z;
    return b;
}
```
## Operator Negation 2
This is an operator overloaded `-` for `Vec3`. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec`.
```jai
operator - :: (a: $T/Vec3) -> T {
    b: T;
    b.x = -a.x;
    b.y = -a.y;
    b.z = -a.z;
    return b;
}
```

## Scalar Multiply 1
One can overload the multiplication operator so that Vec3 can support scalar multiplication. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
operator * :: (a: Vec3($T), b: T) -> Vec3(T) #symmetric {
    c: Vec3(T) = a;
    c.x *= b;
    c.y *= b;
    c.z *= b;
    return c;
}
```
## Scalar Multiply 2
One can overload the multiplication operator so that Vec3 can support scalar multiplication. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec3`.
```jai
operator * :: (a: $T/Vec3, b: T.T) -> T #symmetric {
    c: T = a;
    c.x *= b;
    c.y *= b;
    c.z *= b;
    return c;
}
```

## Dot Product 1
Dot Product for Vec3 can be written in the following way. This is a polymorphic function where the Vec3 has a polymorphic parameter `$T`.
```jai
dot :: (a: Vec3($T), b: Vec3(T)) -> T {
    c := (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
    return c;
}
```
## Dot Product 2
Dot Product for Vec3 can be written in the following way. This is a polymorphic function where `$T` must be a parameterized struct of type `Vec3`.
```jai
dot :: (a: $T/Vec3, b: T) -> T.T {
    c := (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
    return c;
}
```

# Polymorphic Matrix
A 2D matrix capable of generalizing across different number types `T` such as int, floating point, and complex numbers.
```jai
Matrix :: struct(M: int, N: int, T: Type) {
    data: [M][N] T;
}
```

## Matrix Add 1
Matrix addition can be written in the following way. This is a polymorphic function where the Matrix has a polymorphic parameters `$M`, `$N`, and `$T`.
```jai
operator + :: (a: Matrix($M, $N, $T), b: Matrix(M, N, T)) -> Matrix(M, N, T) {
    c: Matrix(M, N, T);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] + b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Add 2
Matrix addition can be written in the following way. This is a polymorphic function where `$T` must be a parameterized struct of type `Matrix`. Due to the multiple parameters on `Matrix`, writing it in this way compared to Matrix Add 1 is a lot less verbose.
```jai
operator + :: (a: $T/Matrix, b: T) -> T {
    c: T;
    for i : 0..(T.M-1) {
        for j : 0..(T.N-1) {
            c.data[i][j] = a.data[i][j] + b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Sub 1
Matrix subtraction can be written in the following way. This is a polymorphic function where the Matrix has a polymorphic parameters `$M`, `$N`, and `$T`.
```jai
operator - :: (a: Matrix($M, $N, $T), b: Matrix(M, N, T)) -> Matrix(M, N, T) {
    c: Matrix(M, N, T);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] - b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Sub 2
Matrix subtraction can be written in the following way. This is a polymorphic function where `$T` must be a parameterized struct of type `Matrix`. Due to the multiple parameters on `Matrix`, writing it in this way compared to Matrix Sub 1 is a lot less verbose.
```jai
operator - :: (a: $T/Matrix, b: T) -> T {
    c: T;
    for i : 0..(T.M-1) {
        for j : 0..(T.N-1) {
            c.data[i][j] = a.data[i][j] - b.data[i][j];
        }
    }
    return c;
}
```

## Matrix Multiplication 1
Given the definition, one can implement matrix multiplication of two matrices in the following way. This multiplication generalizes across all different matrices of Type `T`.
```jai
operator * :: (a: Matrix($M, $X, $T), b: Matrix(X, $N, T)) -> Matrix(M, N, T) {
    c: Matrix(M, N, T);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            value: T;
            for k : 0..(X-1) {
                value += a.data[i][k] * b.data[k][j];
            }
            c.data[i][j] = value;
        }
    }
    return c;
}
```

## Matrix Multiplication 2
Another matrix multiplication function implementation where `$T` must be a parameterized struct of type `Matrix`.. This multiplication generalizes across all different matrices of Type `T`.
```jai
operator * :: (a: $T/Matrix, b: Matrix(T.N, $N, T.T)) -> Matrix(T.M, N, T.T) {
    c: Matrix(T.M, N, T.T);
    for i : 0..(T.M-1) {
        for j : 0..(T.N-1) {
            value: T.T;
            for k : 0..(T.N-1) {
                value += a.data[i][k] * b.data[k][j];
            }
            c.data[i][j] = value;
        }
    }
    return c;
}
```

## Matrix Scalar Multiplication 1
One can overload the multiplication operator so that Matrix can support scalar multiplication. We can attach the #symmetric keyword to the function so that the scalar float value is swappable with the Matrix; in this way, we do not need to define two different functions to represent scalar multiplication.
```jai
operator * :: (a: Matrix($M, $N, $T), b: T) -> Matrix(M, N, T) #symmetric {
    c: Matrix(M, N, T);
    for i : 0..(M-1) {
        for j : 0..(N-1) {
            c.data[i][j] = a.data[i][j] * b;
        }
    }
    return c;
}
```

## Matrix Scalar Multiplication 2
Another matrix scalar multiplication function implementation where `$T` must be a parameterized struct of type `Matrix`. This scalar multiplication generalizes across all different matrices of Type `T`.
```jai
operator * :: (a: $T/Matrix, b: T.T) -> T #symmetric {
    c: T;
    for i : 0..(T.M-1) {
        for j : 0..(T.N-1) {
            c.data[i][j] = a.data[i][j] * b;
        }
    }
    return c;
}
```

## Matrix Transpose 1
The transpose of a matrix is obtained by flipping it over its diagonal, which means switching its rows with its columns.
```jai
transpose :: (matrix: Matrix($M, $N, $T)) -> Matrix(N, M, T) {
    answer: Matrix(N, M, T);
    for i : 0..M-1 {
        for j : 0..N-1 {
            answer.data[j][i] = matrix.data[i][j];
        }
    }
    return answer;
}
```

## Matrix Transpose 2
Another matrix transpose function implementation where `$T` must be a parameterized struct of type `Matrix`. This transpose function generalizes across all different matrices of Type `T`.
```jai
transpose :: (matrix: $T/Matrix) -> Matrix(T.N, T.M, T.T) {
    answer: Matrix(T.N, T.M, T.T);
    for i : 0..T.M-1 {
        for j : 0..T.N-1 {
            answer.data[j][i] = matrix.data[i][j];
        }
    }
    return answer;
}
```

# Polymorphic Complex Numbers
A complex number is a number that combines a real part and an imaginary part. It is expressed in the form: a + bi where:

    a is the real part
    b is the imaginary part
    i is the imaginary unit, defined as the square root of -1

We can define complex numbers using the following struct:
```jai
Complex :: struct(T: Type) {
    real: T;
    imaginary: T;
}
```
By making the struct polymorphic, one can make Complex numbers more flexible. For example, if one needs more bits for precision, one can have a `Complex(float64)` instead of a `Complex(float)`.

## Complex Add 1
We can define complex number addition using operator overloading. Adds the corresponding real and imaginary member fields together.
```jai
operator + :: (a: Complex($T), b: Complex(T)) -> Complex(T) {
    c: Complex(T);
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```

## Complex Add 2
Another complex number addition created where `$T` must be a parameterized struct of type `Complex`. Adds the corresponding real and imaginary member fields together.
```jai
operator + :: (a: $T/Complex($T), b: T) -> T {
    c: T;
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```
## Complex Add 3
Another complex number addition that utilizes implicit polymorphism. Adds the corresponding real and imaginary member fields together.
```jai
operator + :: (a: Complex, b: type_of(a)) -> type_of(a) {
    c: type_of(a);
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```
## Complex Sub 1
We can define complex number subtraction using operator overloading. Subtracts the corresponding real and imaginary member fields together.
```jai
operator - :: (a: Complex($T), b: Complex(T)) -> Complex(T) {
    c: Complex(T);
    c.real = a.real - b.real;
    c.imaginary = a.imaginary - b.imaginary;
    return c;
}
```

## Complex Sub 2
Another complex number subtraction created where `$T` must be a parameterized struct of type `Complex`. Subtracts the corresponding real and imaginary member fields together.
```jai
operator - :: (a: $T/Complex($T), b: T) -> T {
    c: T;
    c.real = a.real - b.real;
    c.imaginary = a.imaginary - b.imaginary;
    return c;
}
```
## Complex Sub 3
Another complex number subtraction that utilizes implicit polymorphism. Subtracts the corresponding real and imaginary member fields together.
```jai
operator + :: (a: Complex, b: type_of(a)) -> type_of(a) {
    c: type_of(a);
    c.real = a.real + b.real;
    c.imaginary = a.imaginary + b.imaginary;
    return c;
}
```
## Complex Multiplication 1
We can define complex number multiplication using operator overloading. Calculate the multiplication of the square roots of -1 and the multiplication of real and imaginary values when multiplying.
```jai
operator * :: (a: Complex($T), b: Complex(T)) -> Complex(T) {
    c: Complex(T);
    c.real = (a.real * b.real) - (a.imaginary * b.imaginary);
    c.imaginary = (a.real * b.imaginary) + (a.imaginary * b.real);
    return c;
}
```

## Complex Multiplication 2
Another complex number multiplication created where `$T` must be a parameterized struct of type `Complex`. 
```jai
operator * :: (a: $T/Complex, b: T) -> T {
    c: T;
    c.real = (a.real * b.real) - (a.imaginary * b.imaginary);
    c.imaginary = (a.real * b.imaginary) + (a.imaginary * b.real);
    return c;
}
```
## Complex Multiplication 3
Another complex number multiplication using implicit polymorphism. 
```jai
operator * :: (a: Complex, b: type_of(a)) -> type_of(a) {
    c: type_of(a);
    c.real = (a.real * b.real) - (a.imaginary * b.imaginary);
    c.imaginary = (a.real * b.imaginary) + (a.imaginary * b.real);
    return c;
}
```
