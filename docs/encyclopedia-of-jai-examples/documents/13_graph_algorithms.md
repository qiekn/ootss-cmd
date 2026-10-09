Graphs are one of the most important and unifying structures in computer science. They model relationships — and most real-world and computational problems are fundamentally about relationships.

A graph consists of:
* Vertices (nodes) -> entities
* Edges -> relationships between entities

This article seeks to document how to write different graph algorithms in Jai.

# Graph Definition
There are many valid definitions of a graph. In the next few examples, we will represent a graph as an adjacency list.
```jai
// ============================================================
//  GRAPH DATA STRUCTURE: Adjacency List
//
//  - num_vertices: total vertex count
//  - adj: a dynamic array where adj[u] is itself a dynamic
//    array containing all neighbors of vertex u.
// ============================================================

Graph :: struct {
    num_vertices: int;
    adj: [..] [..] int;   // dynamic array of dynamic arrays
}

// Create a graph with n vertices and no edges.
make_graph :: (n: int) -> Graph {
    g: Graph;
    g.num_vertices = n;
    // Add n empty neighbor lists, one per vertex.
    for 0..n-1 {
        empty: [..] int;
        array_add(*g.adj, empty);
    }
    return g;
}

// Add an undirected edge between u and v.
add_edge :: (g: *Graph, u: int, v: int) {
    array_add(*g.adj[u], v);
    array_add(*g.adj[v], u);
}

// Add a directed edge from u to v.
add_directed_edge :: (g: *Graph, u: int, v: int) {
    array_add(*g.adj[u], v);
}

// Free all memory used by the graph.
free_graph :: (g: *Graph) {
    for i: 0..g.num_vertices-1 {
        array_free(g.adj[i]);
    }
    array_free(g.adj);
}

// Helper: remove the first occurrence of val from a dynamic array.
// Uses swap-with-last then decrement count (O(1), unordered remove).
remove_from_list :: (list: *[..] int, val: int) {
    for i: 0..list.count-1 {
        if list.data[i] == val {
            list.data[i] = list.data[list.count - 1];
            list.count  -= 1;
            return;
        }
    }
}

// Remove an undirected edge between u and v.
// Used internally by Fleury's Algorithm.
remove_edge :: (g: *Graph, u: int, v: int) {
    remove_from_list(*g.adj[u], v);
    remove_from_list(*g.adj[v], u);
}
```

## Breath First Search
Breath First Search explores all vertices reachable from 'start' level by level. Uses a queue (simulated with a dynamic array and a head index). Time: O(V + E).

```jai
bfs :: (g: *Graph, start: int) {
    // visited[u] is true if vertex u has been seen.
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);

    // Use a dynamic array as a queue; 'head' is the front index.
    queue: [..] int;
    defer array_free(queue);

    visited[start] = true;
    array_add(*queue, start);

    head := 0;
    while head < queue.count {
        u := queue[head];
        head += 1;
        print("BFS visited: %\n", u);

        for v: g.adj[u] {
            if !visited[v] {
                visited[v] = true;
                array_add(*queue, v);
            }
        }
    }
}
```
## Depth First Search
Depth First Search explores as far as possible along each branch before backtracking. This depth first search is implemented recursively. Time: O(V + E).
```jai
dfs_helper :: (g: *Graph, u: int, visited: [] bool) {
    visited[u] = true;
    print("DFS visited: %\n", u);

    for v: g.adj[u] {
        if !visited[v] {
            dfs_helper(g, v, visited);
        }
    }
}

dfs :: (g: *Graph, start: int) {
    // [] bool is an array view — passing by value still lets
    // us modify elements because it contains a pointer to the
    // underlying data.
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);
    dfs_helper(g, start, visited);
}
```
## Flood Fill
Given a vertex color array, recolors the entire connected component of 'start' that shares old_color with new_color.
```jai
flood_fill :: (g: *Graph, colors: [] int, start: int, new_color: int) {
    old_color := colors[start];
    if old_color == new_color  return;  // nothing to do

    queue: [..] int;
    defer array_free(queue);

    colors[start] = new_color;
    array_add(*queue, start);

    head := 0;
    while head < queue.count {
        u := queue[head];
        head += 1;

        for v: g.adj[u] {
            if colors[v] == old_color {
                colors[v] = new_color;
                array_add(*queue, v);
            }
        }
    }
}
```
## Check for Bipartite Graph
A graph is bipartite if its vertices can be split into two sets such that every edge connects a vertex in one set to a vertex in the other. Equivalently, a graph is bipartite if and only if it contains no odd-length cycle. Uses BFS 2-coloring. Handles disconnected graphs. Returns true if bipartite, false otherwise. Time: O(V + E).
```jai
is_bipartite :: (g: *Graph) -> bool {
    // colors[u] = -1 means unvisited
    // colors[u] =  0 or 1 is the BFS 2-coloring
    colors := NewArray(g.num_vertices, int);
    defer array_free(colors);
    for i: 0..g.num_vertices-1  colors[i] = -1;

    // Try BFS from every unvisited vertex (handles disconnected graphs).
    for start: 0..g.num_vertices-1 {
        if colors[start] != -1  continue;

        queue: [..] int;
        defer array_free(queue);

        colors[start] = 0;
        array_add(*queue, start);

        head := 0;
        while head < queue.count {
            u := queue[head];
            head += 1;

            for v: g.adj[u] {
                if colors[v] == -1 {
                    // Assign the opposite color to the neighbor.
                    colors[v] = 1 - colors[u];
                    array_add(*queue, v);
                } else if colors[v] == colors[u] {
                    // Same color on both ends of an edge — not bipartite.
                    return false;
                }
            }
        }
    }
    return true;
}
```

## Clone Graph
Creates a deep copy of the graph. The new graph has its own independent adjacency lists with the same edges. Time: O(V + E).
```jai
clone_graph :: (g: *Graph) -> Graph {
    new_g := make_graph(g.num_vertices);
    for u: 0..g.num_vertices-1 {
        for v: g.adj[u] {
            array_add(*new_g.adj[u], v);
        }
    }
    return new_g;
}
```

## Cycle Detection
Use depth first search to find if a cycle exists in an undirected graph. Mark the nodes if they have been visited. If the graph node has already been visited, there is a cycle and return true. Time Complexity: O(V + E).

```jai
has_cycle_helper :: (g: *Graph, u: int, parent: int, visited: [] bool) -> bool {
    visited[u] = true;

    for v: g.adj[u] {
        if !visited[v] {
            if has_cycle_helper(g, v, u, visited)  return true;
        } else if v != parent {
            // Found a visited vertex that isn't where we came from.
            return true;
        }
    }
    return false;
}

has_cycle :: (g: *Graph) -> bool {
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);

    for u: 0..g.num_vertices-1 {
        if !visited[u] {
            if has_cycle_helper(g, u, -1, visited)  return true;
        }
    }
    return false;
}
```

## Fleury's Algorithm - Eulerian Path
Fleury's Algorithm finds Eulerian Paths and Circuits by greedily walking edges, always preferring edges that are NOT bridges, where a bridge is an edge whose removal disconnects the graph. We detect bridges by counting reachable vertices before and after a temporary edge removal.

Fleury's Algorithm functions consumes the graph, so pass a clone if you need the original preserved. Complexity Time: O(E * (V + E)) due to bridge checks inside the walk.
```jai
// Count vertices reachable from 'start' via BFS.
count_reachable :: (g: *Graph, start: int) -> int {
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);

    queue: [..] int;
    defer array_free(queue);

    visited[start] = true;
    array_add(*queue, start);
    count := 0;

    head := 0;
    while head < queue.count {
        u := queue[head];
        head += 1;
        count += 1;
        for v: g.adj[u] {
            if !visited[v] {
                visited[v] = true;
                array_add(*queue, v);
            }
        }
    }
    return count;
}

// Returns true if removing edge (u,v) would disconnect the graph.
is_bridge :: (g: *Graph, u: int, v: int) -> bool {
    before := count_reachable(g, u);
    remove_edge(g, u, v);
    after := count_reachable(g, u);
    add_edge(g, u, v);     // restore the edge
    return after < before;
}

// Find any vertex with at least one edge remaining.
find_vertex_with_edges :: (g: *Graph) -> int {
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count > 0  return u;
    }
    return -1;
}

// Count vertices in the graph that have odd degree.
count_odd_degree_vertices :: (g: *Graph) -> int {
    count := 0;
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count % 2 == 1  count += 1;
    }
    return count;
}

// Internal core of Fleury's: walk edges from 'start', building a path.
fleury_walk :: (g: *Graph, start: int) -> [..] int {
    path: [..] int;
    array_add(*path, start);

    current := start;
    while g.adj[current].count > 0 {
        chosen := -1;

        // Prefer a non-bridge edge. Only take a bridge if it's the only option.
        for v: g.adj[current] {
            if g.adj[current].count == 1 || !is_bridge(g, current, v) {
                chosen = v;
                break;
            }
        }

        // Fallback: if all edges are bridges, take the first one.
        if chosen == -1  chosen = g.adj[current][0];

        array_add(*path, chosen);
        remove_edge(g, current, chosen);
        current = chosen;
    }

    return path;
}

fleury_eulerian_path :: (g: *Graph) {
    odd_count := 0;
    start     := -1;

    for u: 0..g.num_vertices-1 {
        if g.adj[u].count % 2 == 1 {
            odd_count += 1;
            start = u;  // will end up as one of the two odd-degree vertices
        }
    }

    if odd_count != 0 && odd_count != 2 {
        print("No Eulerian Path exists (need 0 or 2 odd-degree vertices, found %).\n",
              odd_count);
        return;
    }

    // If 0 odd-degree vertices, any vertex with edges is fine.
    if odd_count == 0  start = find_vertex_with_edges(g);

    if start == -1 {
        print("Graph has no edges.\n");
        return;
    }

    path := fleury_walk(g, start);
    defer array_free(path);

    print("Eulerian Path: ");
    for i: 0..path.count-1 {
        print("%", path[i]);
        if i < path.count - 1  print(" -> ");
    }
    print("\n");
}
```
## Fleury's Algorithm - Eulerian Circuit
An Eulerian Circuit is an Eulerian Path that starts and ends at the same vertex.

Conditions for existence (undirected graph):
* The graph must be connected (ignoring isolated vertices).
* Every vertex must have even degree.

Time: O(E * (V + E)) due to bridge checks inside the walk.

```jai
// Count vertices reachable from 'start' via BFS.
count_reachable :: (g: *Graph, start: int) -> int {
    visited := NewArray(g.num_vertices, bool);
    defer array_free(visited);

    queue: [..] int;
    defer array_free(queue);

    visited[start] = true;
    array_add(*queue, start);
    count := 0;

    head := 0;
    while head < queue.count {
        u := queue[head];
        head += 1;
        count += 1;
        for v: g.adj[u] {
            if !visited[v] {
                visited[v] = true;
                array_add(*queue, v);
            }
        }
    }
    return count;
}

// Returns true if removing edge (u,v) would disconnect the graph.
is_bridge :: (g: *Graph, u: int, v: int) -> bool {
    before := count_reachable(g, u);
    remove_edge(g, u, v);
    after := count_reachable(g, u);
    add_edge(g, u, v);     // restore the edge
    return after < before;
}

// Find any vertex with at least one edge remaining.
find_vertex_with_edges :: (g: *Graph) -> int {
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count > 0  return u;
    }
    return -1;
}

// Count vertices in the graph that have odd degree.
count_odd_degree_vertices :: (g: *Graph) -> int {
    count := 0;
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count % 2 == 1  count += 1;
    }
    return count;
}

// Internal core of Fleury's: walk edges from 'start', building a path.
fleury_walk :: (g: *Graph, start: int) -> [..] int {
    path: [..] int;
    array_add(*path, start);

    current := start;
    while g.adj[current].count > 0 {
        chosen := -1;

        // Prefer a non-bridge edge. Only take a bridge if it's the only option.
        for v: g.adj[current] {
            if g.adj[current].count == 1 || !is_bridge(g, current, v) {
                chosen = v;
                break;
            }
        }

        // Fallback: if all edges are bridges, take the first one.
        if chosen == -1  chosen = g.adj[current][0];

        array_add(*path, chosen);
        remove_edge(g, current, chosen);
        current = chosen;
    }

    return path;
}

fleury_eulerian_circuit :: (g: *Graph) {
    for u: 0..g.num_vertices-1 {
        if g.adj[u].count % 2 == 1 {
            print("No Eulerian Circuit exists (vertex % has odd degree).\n", u);
            return;
        }
    }

    start := find_vertex_with_edges(g);
    if start == -1 {
        print("Graph has no edges.\n");
        return;
    }

    path := fleury_walk(g, start);
    defer array_free(path);

    print("Eulerian Circuit: ");
    for i: 0..path.count-1 {
        print("%", path[i]);
        if i < path.count - 1  print(" -> ");
    }
    print("\n");
}
```


# Prim's Algorithm
A graph is a collection of nodes (vertices) connected by edges. Each edge can have a weight — a cost associated with traversing that connection. Think of cities connected by roads, where the weight represents distance or travel time.
A spanning tree of a connected graph is a subset of edges that:

* Connects all vertices (spans the entire graph)
* Contains no cycles (it's a tree)
* Uses exactly V - 1 edges for a graph with V vertices

A Minimum Spanning Tree (MST) is a spanning tree where the total sum of edge weights is as small as possible. Real-world applications include:
* Network design (laying cable, fiber, or pipes at minimum cost)
* Cluster analysis in machine learning
* Approximation algorithms for the Traveling Salesman Problem
* Circuit board routing
* Image segmentation

## Algorithm Procedure

Prim's Algorithm builds the MST by growing it one edge at a time from a starting vertex. At each step, it greedily picks the cheapest edge that connects a vertex already in the MST to a vertex not yet in the MST. Here is the algorithm step by step:

* Start with any vertex. Mark it as "in the MST."
* Look at all edges crossing the boundary between "in MST" vertices and "not in MST" vertices.
* Pick the edge with the minimum weight.
* Add that edge and its new vertex to the MST.
* Repeat steps 2–4 until all vertices are in the MST.

**Time Complexity:** O(V^2) with an adjacency matrix, or O(E log V) with a priority queue.

```jai
#import "Basic";

// Represents the result of Prim's algorithm.
// Each entry in 'parent' says which vertex is the parent of vertex i in the MST.
// Each entry in 'key' stores the minimum edge weight to connect vertex i.
MST_Result :: struct {
    parent: [] int;   // parent[i] = parent of vertex i in the MST
    key:    [] float; // key[i]    = weight of edge connecting i to its parent
    total_cost: float;
}

// Find the vertex with the minimum key value that is not yet in the MST.
min_key_vertex :: (key: [] float, in_mst: [] bool) -> int {
    min_val := 999999.0;
    min_idx := -1;

    for i: 0..key.count - 1 {
        if !in_mst[i] && key[i] < min_val {
            min_val = key[i];
            min_idx = i;
        }
    }

    return min_idx;
}

// Prim's Algorithm.
// graph: a V x V adjacency matrix where graph[i][j] is the edge weight between i and j.
//        A value of 0 means no edge.
// V:     number of vertices
prim_mst :: (graph: [][] float, V: int) -> MST_Result {
    // key[i] = minimum weight to connect vertex i to the growing MST
    key := NewArray(V, float);

    // parent[i] = which MST vertex connects to vertex i
    parent := NewArray(V, int);

    // in_mst[i] = true if vertex i is already part of the MST
    in_mst := NewArray(V, bool);

    // Initialize: all keys are infinity, no vertex is in MST
    for i: 0..V - 1 {
        key[i]    = 999999.0; // represents "infinity"
        parent[i] = -1;
        in_mst[i] = false;
    }

    // Start from vertex 0. Its key is 0 so it gets picked first.
    key[0] = 0.0;

    // We need to pick V vertices total
    for step: 0..V - 1 {
        // Pick the vertex not yet in MST with the smallest key
        u := min_key_vertex(key, in_mst);
        in_mst[u] = true;

        // Update keys of adjacent vertices of u
        for v: 0..V - 1 {
            edge_weight := graph[u][v];

            // Only consider: edges that exist (non-zero),
            //                vertices not yet in MST,
            //                and only if this edge is cheaper than what we know
            if edge_weight > 0 && !in_mst[v] && edge_weight < key[v] {
                key[v]    = edge_weight;
                parent[v] = u;
            }
        }
    }

    // Compute total MST cost (skip vertex 0, it has no parent)
    total := 0.0;
    for i: 1..V - 1 {
        total += key[i];
    }

    result: MST_Result;
    result.parent     = parent;
    result.key        = key;
    result.total_cost = total;
    return result;
}

// Print the MST edges and total cost.
print_mst :: (result: MST_Result) {
    print("Edge      Weight\n");
    print("------------------\n");
    for i: 1..result.parent.count - 1 {
        print("% -- %    %\n", result.parent[i], i, result.key[i]);
    }
    print("\nTotal MST cost: %\n", result.total_cost);
}

main :: () {
    // Example graph with 5 vertices.
    // This is an adjacency matrix: graph[i][j] = weight of edge between i and j.
    // 0 means no edge between those two vertices.
    //
    //       0    1    2    3    4
    //   0 [ 0,   2,   0,   6,   0 ]
    //   1 [ 2,   0,   3,   8,   5 ]
    //   2 [ 0,   3,   0,   0,   7 ]
    //   3 [ 6,   8,   0,   0,   9 ]
    //   4 [ 0,   5,   7,   9,   0 ]

    V :: 5;

    // Build the adjacency matrix as a dynamic 2D array
    graph: [V][V] float;

    graph[0][1] = 2;  graph[1][0] = 2;
    graph[0][3] = 6;  graph[3][0] = 6;
    graph[1][2] = 3;  graph[2][1] = 3;
    graph[1][3] = 8;  graph[3][1] = 8;
    graph[1][4] = 5;  graph[4][1] = 5;
    graph[2][4] = 7;  graph[4][2] = 7;
    graph[3][4] = 9;  graph[4][3] = 9;

    // Convert to slice-of-slices for the function
    rows: [V] [] float;
    for i: 0..V-1 {
        rows[i].data  = *graph[i][0];
        rows[i].count = V;
    }

    graph_view: [] [] float;
    graph_view.data  = *rows[0];
    graph_view.count = V;

    result := prim_mst(graph_view, V);
    print_mst(result);
}

```
## Expected Output
```
Edge      Weight
------------------
0 -- 1    2
1 -- 2    3
0 -- 3    6
1 -- 4    5

Total MST cost: 16
```
## Step-by-Step Walkthrough

Using the graph from the example above:

```
    (2)       (3)
0 ------- 1 ------- 2
|         |         |
(6)      (8)       (7)
|         |         |
3 ------- 4 --------+
    (9)       (5)
            1 -- 4
```

| Step | Vertex Added | Via Edge | Edge Weight | Notes |
|---|---|---|---|---|
| 1 | 0 | (start) | 0 | Starting vertex |
| 2 | 1 | 0 → 1 | 2 | Cheapest edge from {0} |
| 3 | 2 | 1 → 2 | 3 | Cheapest edge from {0,1} |
| 4 | 4 | 1 → 4 | 5 | Cheaper than 2→4 (7) |
| 5 | 3 | 0 → 3 | 6 | Cheaper than 1→3 (8) or 4→3 (9) |

**Total Cost: 2 + 3 + 5 + 6 = 16**

---

## Implementation Notes

**Why the adjacency matrix?**
The adjacency matrix is the simplest representation to start with. For a graph with `V` vertices, it's a `V × V` grid where `matrix[i][j]` stores the weight of the edge from `i` to `j`. Checking whether an edge exists is O(1). The downside is it uses O(V²) memory even for sparse graphs.

**The `min_key_vertex` function**
In the simple O(V²) implementation, finding the next vertex to add requires scanning all vertices to find the one with the smallest key that isn't yet in the MST. This linear scan is why the overall algorithm is O(V²). For large sparse graphs, replacing this with a **priority queue (min-heap)** brings the complexity down to O(E log V).

**The `key` array**
Each `key[v]` represents the weight of the cheapest edge we've found so far that could connect vertex `v` to the MST. When we add a new vertex `u` to the MST, we check all of `u`'s neighbors — if we find a cheaper connection to any of them, we update their `key` and record `u` as their `parent`.

**Why does this produce a correct MST?**
Prim's algorithm is an instance of the **greedy** algorithm strategy. At each step it picks the globally cheapest edge crossing the MST boundary. It can be proven correct via the **Cut Property**: for any cut of the graph (a partition of vertices into two sets), the minimum weight edge crossing that cut must belong to some MST.




# Kruskal's Algorithm

Kruskal’s Algorithm is a greedy algorithm used to find a Minimum Spanning Tree (MST) of a connected, weighted, undirected graph. It was developed by Joseph Kruskal in 1956.

Given a graph with weighted edges where all vertices are connected, it finds a subset of edges that:
* connects all vertices
* has no cycles
* Has the minimum possible total edge weight

This subset is called a Minimum Spanning Tree.

## Algorithm Procedure
* Sort all edges in increasing order of weight.
* Start with an empty graph (no edges).
* Go through the sorted edges one by one:
* If adding the edge does not create a cycle, add it.
* If it does create a cycle → skip it.
* Stop when you have V − 1 edges (where V = number of vertices).

```jai
#import "Basic";

Edge :: struct {
    src    : int;
    dst    : int;
    weight : int;
}

// Union-Find (Disjoint Set Union) data structure.
// 'parent' and 'rank' are parallel dynamic arrays indexed by node ID.
UnionFind :: struct {
    parent : [..] int;
    rank   : [..] int;
}

init_union_find :: (uf: *UnionFind, n: int) {
    for i : 0..n-1 {
        array_add(*uf.parent, i);  // each node is its own parent
        array_add(*uf.rank, 0);
    }
}

// Walk up the parent chain until we reach the root.
// Path compression: flatten the tree so every visited node
// points directly to the root on future calls.
find :: (uf: *UnionFind, x: int) -> int {
    if uf.parent[x] != x {
        uf.parent[x] = find(uf, uf.parent[x]);
    }
    return uf.parent[x];
}

// Union by rank: attach the smaller tree under the larger tree's root.
// Returns false if both nodes share the same root (would form a cycle).
union_find :: (uf: *UnionFind, a: int, b: int) -> bool {
    root_a := find(uf, a);
    root_b := find(uf, b);

    if root_a == root_b return false;  // already connected, skip

    if uf.rank[root_a] < uf.rank[root_b] {
        uf.parent[root_a] = root_b;
    } else if uf.rank[root_a] > uf.rank[root_b] {
        uf.parent[root_b] = root_a;
    } else {
        uf.parent[root_b] = root_a;
        uf.rank[root_a] += 1;
    }
    return true;
}

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

kruskal :: (num_nodes: int, edges: [] Edge) -> [..] Edge {
    // Sort all edges from cheapest to most expensive.
    bubble_sort(edges, (a: Edge, b: Edge) -> bool {
        return a.weight < b.weight;
    });

    uf: UnionFind;
    init_union_find(*uf, num_nodes);

    mst: [..] Edge;

    for edge : edges {
        // An MST for N nodes needs exactly N-1 edges.
        if mst.count == num_nodes - 1  break;

        // Only add the edge if its endpoints are in different components.
        // union() returns false when they are already connected (cycle).
        if union_find(*uf, edge.src, edge.dst) {
            array_add(*mst, edge);
        }
    }

    return mst;
}

main :: () {
    // Graph with 5 nodes (0..4) and 7 edges:
    //
    //   0 --1-- 1
    //   |  \ /  |
    //   4   X   2
    //   |  / \  |
    //   3 --9-- 4
    //
    edges := Edge.[
        .{0, 1, 1},
        .{0, 3, 4},
        .{1, 2, 2},
        .{1, 3, 5},
        .{1, 4, 8},
        .{2, 4, 3},
        .{3, 4, 9},
    ];

    mst := kruskal(5, edges);

    total_weight := 0;
    print("Minimum Spanning Tree edges:\n");
    for edge : mst {
        print("  % -- % : weight %\n", edge.src, edge.dst, edge.weight);
        total_weight += edge.weight;
    }
    print("Total MST weight: %\n", total_weight);
}
```

## Edge Representation
Each `Edge` is a flat struct holding `src`, `dst`, and `weight`. Because Jai structs are plain value types (no hidden overhead), the array of edges is a contiguous block of memory — cache-friendly for the sort that follows.

## Union-Find (Disjoint Set Union)
The algorithm needs to answer one question efficiently: *"Are these two nodes already connected?"* Union-Find answers this in near-O(1) time with two optimizations:

* **Path Compression** (`find`): When traversing the parent chain to find the root, every node along the path is rewired to point directly at the root. Future lookups on those nodes become a single-step O(1) dereference.

* **Union by Rank** (`union`): Each set tracks a `rank` (an approximate height of its tree). When merging two sets, the shallower tree is attached under the deeper tree's root, keeping the overall tree height from ballooning.

Together these give an amortized inverse-Ackermann time complexity, which is effectively constant for any practical input size.

## Sorting
Edges are sorted by weight ascending using a polymorphic `bubble_sort`.

## Greedy Selection Loop
The main loop iterates through the sorted edge list and for each edge calls `union()`. If the two endpoints were already in the same connected component, `union()` returns `false` and the edge is skipped — adding it would create a cycle. If they were in different components, `union()` merges the components and returns `true`, and the edge is appended to the MST. The loop terminates early once exactly `N - 1` edges have been collected, which is the exact count a spanning tree on `N` nodes requires.

## Expected Output for the Sample Graph
```
Minimum Spanning Tree edges:
  0 -- 1 : weight 1
  1 -- 2 : weight 2
  2 -- 4 : weight 3
  0 -- 3 : weight 4
Total MST weight: 10
```

# Dijkstra's Algorithm

Dijkstra's algorithm finds the shortest path from a starting node to all other nodes in a weighted graph where all edge weights are non-negative. It works by maintaining a priority queue of nodes to visit, always processing the node with the smallest known distance first.
The time complexity is O((V + E) log V) with a binary heap priority queue, where V is the number of vertices and E is the number of edges.

## Graph Representation

We represent the graph as an adjacency list: each node stores a dynamic array of its neighbors and the weights of the edges connecting them. This is memory-efficient for sparse graphs and fast for iterating neighbors.

```jai
// An edge connects 'to' with a given 'weight'
Edge :: struct {
    to:     int;
    weight: int;
}

// A node holds all its outgoing edges
Node :: struct {
    edges: [..] Edge;
}

// The graph is just an array of nodes
Graph :: struct {
    nodes: [..] Node;
}

// Create a graph with 'num_nodes' nodes
graph_create :: (num_nodes: int) -> Graph {
    g: Graph;
    for 0..num_nodes - 1 {
        node: Node;
        array_add(*g.nodes, node);
    }
    return g;
}

// Add a directed edge from 'from' to 'to' with the given weight
graph_add_edge :: (g: *Graph, from: int, to: int, weight: int) {
    edge := Edge.{to = to, weight = weight};
    array_add(*g.nodes[from].edges, edge);
}
```

## Priority Queue
Dijkstra's algorithm needs a priority queue to efficiently retrieve the unvisited node with the smallest tentative distance. We implement a simple min-heap using a dynamic array.
```jai
// An entry in the priority queue: which node and its current best distance
PQ_Entry :: struct {
    node:     int;
    distance: int;
}

// Priority queue (min-heap) — smallest distance at index 0
PQ :: struct {
    data: [..] PQ_Entry;
}

// Swap two entries
pq_swap :: (pq: *PQ, a: int, b: int) {
    pq.data[a], pq.data[b] = pq.data[b], pq.data[a];
}

// Sift an entry up to restore heap order
pq_sift_up :: (pq: *PQ, i: int) {
    while i > 0 {
        parent := (i - 1) / 2;
        if pq.data[i].distance < pq.data[parent].distance {
            pq_swap(pq, i, parent);
            i = parent;
        } else {
            break;
        }
    }
}

// Sift an entry down to restore heap order
pq_sift_down :: (pq: *PQ, i: int) {
    n := pq.data.count;
    while true {
        smallest := i;
        left  := 2 * i + 1;
        right := 2 * i + 2;

        if left < n && pq.data[left].distance < pq.data[smallest].distance {
            smallest = left;
        }
        if right < n && pq.data[right].distance < pq.data[smallest].distance {
            smallest = right;
        }
        if smallest == i  break;

        pq_swap(pq, i, smallest);
        i = smallest;
    }
}

// Push a new entry onto the heap
pq_push :: (pq: *PQ, node: int, dist: int) {
    array_add(*pq.data, .{node = node, distance = dist});
    pq_sift_up(pq, pq.data.count - 1);
}

// Pop the minimum-distance entry off the heap
pq_pop :: (pq: *PQ) -> PQ_Entry {
    top := pq.data[0];
    last := pq.data.count - 1;
    pq.data[0] = pq.data[last];
    pq.data.count -= 1;  // shrink without freeing memory
    if pq.data.count > 0  pq_sift_down(pq, 0);
    return top;
}
```

## Dijkstra Procedure Implementation
This function returns the array of shortest distances from 'start' to every node. Unreachable nodes have distance S64_MAX (treated as infinity).
```jai

dijkstra :: (g: *Graph, start: int) -> [] int {

    INF :: 0x7FFF_FFFF;   // large sentinel value for "infinity"
    n := g.nodes.count;

    // dist[i] = best known distance from start to node i
    dist := NewArray(n, int);
    for i : 0..n - 1  dist[i] = INF;
    dist[start] = 0;

    // visited[i] = true once node i's shortest distance is finalised
    visited := NewArray(n, bool);
    for i : 0..n - 1  visited[i] = false;

    // Initialise the priority queue with the starting node
    pq: PQ;
    pq_push(*pq, start, 0);

    while pq.data.count > 0 {
        // Always process the node with the smallest current distance
        entry := pq_pop(*pq);
        u := entry.node;

        // Skip if we already found the best path to u
        if visited[u]  continue;
        visited[u] = true;

        // Relax all outgoing edges from u
        for edge : g.nodes[u].edges {
            v := edge.to;
            new_dist := dist[u] + edge.weight;

            if new_dist < dist[v] {
                dist[v] = new_dist;
                pq_push(*pq, v, new_dist);
            }
        }
    }

    return dist;
}
```

## Example Usage
Below is a complete `main()` that builds a small weighted graph, runs Dijkstra from node 0, and prints the results.
```jai
main :: () {

    //  Graph layout:
    //
    //       2       3
    //  0 -------> 1 -------> 3
    //  |          |          ^
    //  |  6       | 1        | 1
    //  +------->  2 ---------+

    g := graph_create(4);  // 4 nodes: 0, 1, 2, 3

    graph_add_edge(*g, 0, 1, 2);  // 0 -> 1, cost 2
    graph_add_edge(*g, 0, 2, 6);  // 0 -> 2, cost 6
    graph_add_edge(*g, 1, 2, 1);  // 1 -> 2, cost 1
    graph_add_edge(*g, 1, 3, 3);  // 1 -> 3, cost 3
    graph_add_edge(*g, 2, 3, 1);  // 2 -> 3, cost 1

    dist := dijkstra(*g, 0);

    print("Shortest distances from node 0:\n");
    for i : 0..dist.count - 1 {
        print("  Node % -> %\n", i, dist[i]);
    }
    // Expected output:
    //   Node 0 -> 0
    //   Node 1 -> 2
    //   Node 2 -> 3   (via 0->1->2, cost 2+1=3, not 0->2 cost 6)
    //   Node 3 -> 4   (via 0->1->2->3, cost 2+1+1=4)
}
```

Let's trace through what happens when we call dijkstra(*g, 0):
* Start: dist = [0, INF, INF, INF]. Push (node=0, dist=0) onto the heap.
* Pop (0, 0). Mark node 0 visited. Relax edges: dist[1] = 2, dist[2] = 6. Push both.
* Pop (1, 2). Mark node 1 visited. Relax: dist[2] = min(6, 2+1) = 3. dist[3] = 5. Push updated entries.
* Pop (2, 3). Mark node 2 visited. Relax: dist[3] = min(5, 3+1) = 4. Push (3, 4).
* Pop (3, 4). Mark node 3 visited. No outgoing edges. Done.
* Final distances: [0, 2, 3, 4].

# Bellman Ford Algorithm
Bellman-Ford finds the shortest path from a single source vertex to all other vertices in a weighted graph. Unlike Dijkstra's algorithm, it handles negative edge weights correctly. It works by repeatedly "relaxing" every edge — checking if going through that edge gives a shorter path than what's currently known.
The algorithm runs in O(V * E) time, where V is the number of vertices and E is the number of edges.
It also detects negative-weight cycles: if after V-1 relaxation passes you can still relax an edge, a negative cycle exists.
```jai
#import "Basic";

// Represents a directed edge from 'src' to 'dst' with a given weight.
Edge :: struct {
    src    : int;
    dst    : int;
    weight : int;
}

// Returns the shortest distances from 'source' to all vertices.
// Returns an empty array if a negative cycle is detected.
bellman_ford :: (num_vertices: int, edges: []Edge, source: int) -> [..]int, bool {
    INF :: 1_000_000_000;

    // Step 1: Initialize all distances to infinity, source to 0.
    dist: [..]int;
    for 0..num_vertices-1  array_add(*dist, INF);
    dist[source] = 0;

    // Step 2: Relax all edges (num_vertices - 1) times.
    for pass: 1..num_vertices-1 {
        for edge: edges {
            if dist[edge.src] != INF && dist[edge.src] + edge.weight < dist[edge.dst] {
                dist[edge.dst] = dist[edge.src] + edge.weight;
            }
        }
    }

    // Step 3: Check for negative-weight cycles.
    // If we can still relax an edge, a negative cycle exists.
    for edge: edges {
        if dist[edge.src] != INF && dist[edge.src] + edge.weight < dist[edge.dst] {
            print("Negative cycle detected!\n");
            empty: [..]int;
            return empty, false;
        }
    }

    return dist, true;
}

main :: () {
    // Graph with 5 vertices (0..4)
    edges: [..]Edge;
    array_add(*edges, .{src=0, dst=1, weight= 6});
    array_add(*edges, .{src=0, dst=2, weight= 7});
    array_add(*edges, .{src=1, dst=3, weight= 5});
    array_add(*edges, .{src=2, dst=3, weight=-3});
    array_add(*edges, .{src=3, dst=4, weight= 9});

    dist, ok := bellman_ford(5, edges, source=0);

    if ok {
        for i: 0..dist.count-1 {
            print("Distance from 0 to %: %\n", i, dist[i]);
        }
    }
}
```

## Expected Output
```
Distance from 0 to 0: 0
Distance from 0 to 1: 6
Distance from 0 to 2: 7
Distance from 0 to 3: 4
Distance from 0 to 4: 13
```
## Implementation Notes
* This implementation uses `INF :: 1_000_000_000` because adding to a constant such as `S64_MAX` would overflow. A large sentinel value like one billion works cleanly for typical graph problems.
* The `INF` guard (`dist[edge.src] != INF`). Without this check, an unreachable vertex (still at INF) could produce integer overflow when you compute `INF + weight`. This guard ensures we only try to relax edges from vertices we've actually reached.
* Relaxation loop runs V-1 times. The longest possible shortest path without a cycle visits at most V-1 edges. So after V-1 passes, all shortest paths are guaranteed to be found — if no negative cycle exists.
* Negative cycle detection. The final loop is a V-th pass. Any edge that can still be relaxed after V-1 rounds must be part of a negative cycle (because a path through it would need to loop around indefinitely to keep decreasing).

# Graph Coloring Algorithm
Graph coloring assigns colors to each vertex in a graph such that no two adjacent vertices share the same color. This has practical applications in compiler register allocation, scheduling problems, and map coloring.
This implementation uses a greedy graph coloring algorithm with an adjacency list represented as a dynamic array of dynamic arrays. Each vertex has a list of neighbors it is connected to.

```jai
#import "Basic";

// The graph is represented as an adjacency list.
// adjacency_list[i] is a dynamic array of ints listing
// all vertices that vertex i is connected to.
Graph :: struct {
    num_vertices    : int;
    adjacency_list  : [..] [..] int;  // array of dynamic arrays
}

// Add an undirected edge between vertex u and vertex v.
add_edge :: (g: *Graph, u: int, v: int) {
    array_add(*g.adjacency_list[u], v);
    array_add(*g.adjacency_list[v], u);
}

// Initialize a graph with a given number of vertices.
make_graph :: (num_vertices: int) -> Graph {
    g : Graph;
    g.num_vertices = num_vertices;

    // Reserve one neighbor-list slot per vertex
    for i: 0..num_vertices - 1 {
        neighbor_list : [..] int;
        array_add(*g.adjacency_list, neighbor_list);
    }
    return g;
}

// Greedy graph coloring algorithm.
// Returns a dynamic array where result[i] is the color assigned to vertex i.
// Colors are integers starting from 0.
graph_color :: (g: *Graph) -> [..] int {
    num_vertices := g.num_vertices;

    // Initialize every vertex's color to -1 (uncolored)
    colors : [..] int;
    for i: 0..num_vertices - 1 {
        array_add(*colors, -1);
    }

    // Color the first vertex with color 0
    colors[0] = 0;

    // Assign colors to the remaining vertices one by one
    for vertex: 1..num_vertices - 1 {

        // Track which colors are already used by this vertex's neighbors.
        // neighbor_has_color[c] = true means a neighbor is using color c.
        neighbor_has_color : [..] bool;
        for c: 0..num_vertices - 1 {
            array_add(*neighbor_has_color, false);
        }

        // Mark colors used by all neighbors of this vertex
        for neighbor: g.adjacency_list[vertex] {
            neighbor_color := colors[neighbor];
            if neighbor_color != -1 {
                neighbor_has_color[neighbor_color] = true;
            }
        }

        // Assign the smallest color not used by any neighbor
        chosen_color := 0;
        while chosen_color < num_vertices && neighbor_has_color[chosen_color] {
            chosen_color += 1;
        }
        colors[vertex] = chosen_color;

        array_free(neighbor_has_color);
    }

    return colors;
}

// Print the graph's adjacency list for debugging
print_graph :: (g: *Graph) {
    print("Graph adjacency list:\n");
    for vertex: 0..g.num_vertices - 1 {
        print("  Vertex %: ", vertex);
        for neighbor: g.adjacency_list[vertex] {
            print("% ", neighbor);
        }
        print("\n");
    }
}

// Print the coloring result
print_coloring :: (colors: [..] int) {
    print("Vertex coloring:\n");
    for color, vertex: colors {
        print("  Vertex % -> Color %\n", vertex, color);
    }
}

// Count the total number of distinct colors used
count_colors :: (colors: [..] int) -> int {
    max_color := -1;
    for color: colors {
        if color > max_color  max_color = color;
    }
    return max_color + 1;
}

main :: () {
    // Build a simple example graph:
    //
    //   0 --- 1
    //   |   / |
    //   |  /  |
    //   | /   |
    //   2 --- 3
    //
    // This is a cycle of 4 nodes with a diagonal (0-1-2-3-0 + edge 1-2).
    // It requires 3 colors because of the triangle formed by 0, 1, 2.

    g := make_graph(4);
    add_edge(*g, 0, 1);
    add_edge(*g, 0, 2);
    add_edge(*g, 1, 2);
    add_edge(*g, 1, 3);
    add_edge(*g, 2, 3);

    print_graph(*g);
    print("\n");

    colors := graph_color(*g);
    print_coloring(colors);

    total := count_colors(colors);
    print("\nTotal colors used: %\n", total);

    // Clean up
    array_free(colors);
    for i: 0..g.num_vertices - 1 {
        array_free(g.adjacency_list[i]);
    }
    array_free(g.adjacency_list);
}
```

## Expected Output

```
Graph adjacency list:
  Vertex 0: 1 2
  Vertex 1: 0 2 3
  Vertex 2: 0 1 3
  Vertex 3: 1 2

Vertex coloring:
  Vertex 0 -> Color 0
  Vertex 1 -> Color 1
  Vertex 2 -> Color 2
  Vertex 3 -> Color 0

Total colors used: 3
```

## Expected Output Explained
The greedy algorithm works through the vertices in order (0, 1, 2, ...):

* Vertex 0 gets Color 0 (it's first, nothing to conflict with).
* Vertex 1 is adjacent to 0 (Color 0), so it gets Color 1.
* Vertex 2 is adjacent to 0 (Color 0) and 1 (Color 1), so it gets Color 2.
* Vertex 3 is adjacent to 1 (Color 1) and 2 (Color 2). Color 0 is free, so it gets Color 0.

Note that greedy coloring does not guarantee the globally minimum number of colors (the chromatic number). The result can depend on vertex ordering. For optimal coloring, you'd need a more complex backtracking algorithm, but greedy is fast and works well in practice.

## Notes on this Code

* `Graph :: struct { ... }` — defining a named struct as a constant
* `[..] [..] int` — a dynamic array of dynamic arrays (the adjacency list)
* `array_add(*g.adjacency_list, neighbor_list)` — adding to a dynamic array via pointer
* `for neighbor: g.adjacency_list[vertex]` — iterating directly over a dynamic array
* `array_free(...)` — explicit memory cleanup (no garbage collector!)
* `g.num_vertices` - 1 used in `for vertex: 1..num_vertices - 1` — ranges are inclusive on both ends
* `defer` could be used here to ensure `array_free` is called, but was kept explicit for clarity

# A* Pathfinding with Manhatten Distance

This is an A* pathfinding implementation using a Manhattan distance heuristic. The goal is to find the shortest route through a grid from a start point `S` to a goal `G`, navigating around walls `#`.

The key idea - `f_cost = g_cost + h_cost`
Every tile we consider gets a score made of two parts:

* `g_cost` — how many steps it took to actually reach this tile from the start
* `h_cost` — our guess of how far this tile is from the goal (the Manhattan distance — just count horizontal + vertical steps, ignoring walls)

We always explore whichever tile has the lowest combined score first. This is what makes A* smarter than a blind search — the heuristic steers us toward the goal rather than wandering everywhere.

## Definitions
We define a `Vector2i` which is a Vector of two integers, the different directions one can move in, and a definition of the Manhattan distance.
```jai
#import "Basic";

Vector2i :: struct {
    x: int;
    y: int;
}

Node :: struct {
    pos:    Vector2i;
    g_cost: int;  // cost from start
    h_cost: int;  // heuristic cost to goal
    parent: *Node;
}

f_cost :: (node: Node) -> int {
    return node.g_cost + node.h_cost;
}

abs :: (x: int) -> int {
    if x < 0 then {
        x = -x;
    }
    return x;
}

manhattan :: (a: Vector2i, b: Vector2i) -> int {
    return abs(a.x - b.x) + abs(a.y - b.y);
}

DIRS :: Vector2i.[
    .{  0, -1 },  // up
    .{  0,  1 },  // down
    .{ -1,  0 },  // left
    .{  1,  0 },  // right
];


print_grid :: (grid: [][] bool, path: [..] Vector2i, start: Vector2i, goal: Vector2i) {
    for y: 0..grid.count - 1 {
        for x: 0..grid[0].count - 1 {
            pos := Vector2i.{ x, y };

            is_start := pos.x == start.x && pos.y == start.y;
            is_goal  := pos.x == goal.x  && pos.y == goal.y;

            on_path := false;
            for path {
                if it.x == pos.x && it.y == pos.y {
                    on_path = true;
                    break;
                }
            }

            if      is_start        print("S ");
            else if is_goal         print("G ");
            else if grid[y][x]      print("# ");
            else if on_path         print(". ");
            else                    print("  ");
        }
        print("\n");
    }
}
```

## A Star Implementation
This is the algorithm procedure:
* Put the start tile in the **open list** (tiles we know about but haven't explored yet)
* Pick whichever open tile has the lowest score
* If it's the goal — we're done, trace back through parents to recover the path
* Otherwise, move it to the **closed list** (tiles we've fully explored) and look at its neighbours
* For each neighbour, skip it if it's a wall or already explored. Otherwise add it to the open list, recording the current tile as its parent
* Repeat until we find the goal or run out of tiles

Each node stores a pointer to its `parent` — the tile we came from. Once we reach the goal, we just follow those parent pointers back to the start, then reverse the result to get the path in the right order.

```jai
// Returns the path from start to goal, or an empty array if no path found.
astar :: (grid: [][] bool, start: Vector2i, goal: Vector2i) -> [..] Vector2i {
    rows := grid.count;
    cols := grid[0].count;

    in_bounds :: (pos: Vector2i, rows: int, cols: int) -> bool {
        return pos.x >= 0 && pos.x < cols && pos.y >= 0 && pos.y < rows;
    }

    open:   [..] *Node;
    closed: [..] *Node;

    start_node := New(Node);
    start_node.pos    = start;
    start_node.g_cost = 0;
    start_node.h_cost = manhattan(start, goal);
    start_node.parent = null;
    array_add(*open, start_node);

    while open.count > 0 {

        // Pick the open node with lowest f_cost.
        best_index := 0;
        for i: 1..open.count - 1 {
            if f_cost(open[i].*) < f_cost(open[best_index].*) {
                best_index = i;
            }
        }

        current := open[best_index];

        // Reconstruct path if we reached the goal.
        if current.pos.x == goal.x && current.pos.y == goal.y {
            path: [..] Vector2i;
            node := current;
            while node != null {
                array_add(*path, node.pos);
                node = node.parent;
            }

            // Reverse so path runs start -> goal.
            begin := 0;
            end   := path.count - 1;
            while begin < end {
                path[begin], path[end] = path[end], path[begin];
                begin += 1;
                end   -= 1;
            }
            return path;
        }

        // Move current from open -> closed.
        open[best_index] = open[open.count - 1];
        open.count -= 1;
        array_add(*closed, current);

        // Explore neighbours.
        for dir: DIRS {
            neighbour_pos := Vector2i.{ current.pos.x + dir.x, current.pos.y + dir.y };

            if !in_bounds(neighbour_pos, rows, cols)  continue;
            if grid[neighbour_pos.y][neighbour_pos.x] continue;  // wall

            // Skip if already in closed list.
            already_closed := false;
            for closed {
                if it.pos.x == neighbour_pos.x && it.pos.y == neighbour_pos.y {
                    already_closed = true;
                    break;
                }
            }
            if already_closed continue;

            tentative_g := current.g_cost + 1;

            // Check if neighbour is already in open list.
            existing: *Node = null;
            for open {
                if it.pos.x == neighbour_pos.x && it.pos.y == neighbour_pos.y {
                    existing = it;
                    break;
                }
            }

            if existing {
                // Update if we found a cheaper route.
                if tentative_g < existing.g_cost {
                    existing.g_cost = tentative_g;
                    existing.parent = current;
                }
            } else {
                neighbour := New(Node);
                neighbour.pos    = neighbour_pos;
                neighbour.g_cost = tentative_g;
                neighbour.h_cost = manhattan(neighbour_pos, goal);
                neighbour.parent = current;
                array_add(*open, neighbour);
            }
        }
    }

    empty: [..] Vector2i;
    return empty;  // no path found
}

main :: () {
    // true = wall, false = open
    map: [8][8] bool = .[
        .[ false, false, false, false, false, false, false, false ],
        .[ false, false, true,  false, false, false, false, false ],
        .[ false, false, true,  false, true,  true,  true,  false ],
        .[ false, false, true,  false, false, false, false, false ],
        .[ false, false, true,  true,  true,  false, false, false ],
        .[ false, false, false, false, false, false, false, false ],
        .[ false, false, false, false, false, false, false, false ],
        .[ false, false, false, false, false, false, false, false ],
    ];

    // Build a [] [] bool (array view of rows) from the fixed grid.
    rows: [8] [] bool;
    for i: 0..7  rows[i] = map[i];
    grid: [] [] bool = rows;

    start := Vector2i.{ 0, 0 };
    goal  := Vector2i.{ 7, 7 };

    path := astar(grid, start, goal);

    if path.count > 0 {
        print("Path found! % steps\n", path.count - 1);
        print_grid(grid, path, start, goal);
    } else {
        print("No path found.\n");
    }
}
```

## Expected Output
```
Path found! 14 steps
S
.   #
.   #   # # #
.   #
.   # # #
. . . . . . . .
              .
              G
```

# Directed Acyclic Word Graph

This is an implementation of a directed acyclic word graph from the paper "The World's Fastest Scrabble Program" by Appel Jaconson.

The algorithm from the paper can be described as follows:
* Insert all words into a Trie.
* Minimize the Trie bottom-up into a DAWG by merging nodes whose subtrees are structurally identical.
* Pack nodes into a flat edge array (32 bits per edge) matching the paper's compact storage format.

The Edge bit layout (32 bits) is organized in the following way:
* bits 0-4 : letter index 0-25  (5 bits)
* bits 5-28 : child node index   (24 bits)
* bit 29 : is_terminal flag   (1 bit, word ends here)
* bit 30 : is_last_edge flag  (1 bit, last edge in node)
* bits 31-32 : unused             (2 bits)

## Imports and Trie

We first insert all words into a Trie and import modules such as `Basic`, `String`, `Hash_Table`, and `File`.

```jai
#import "Basic";
#import "String";
#import "Hash_Table";
#import "File";

// ---------------------------------------------------------------------------
// Phase 1 – Trie
// ---------------------------------------------------------------------------

Trie_Node :: struct {
    children : [26] *Trie_Node;
    is_terminal : bool;
}

make_trie_node :: () -> *Trie_Node {
    return New(Trie_Node);
}

trie_insert :: (root: *Trie_Node, word: string) {
    node := root;
    for i : 0..word.count-1 {
        idx := word[i] - #char "a";
        if !node.children[idx]
            node.children[idx] = make_trie_node();
        node = node.children[idx];
    }
    node.is_terminal = true;
}
```

## Minimization Trie to Dawg
We traverse the trie bottom-up.  At each node we first canonicalize all children, then compute a signature string:
```jai
 "<terminal_flag> | a:<child_id> b:<child_id> ..."
```

If a node with an identical signature already exists in the registry we reuse it; otherwise we register this node and assign it a fresh id. After this pass many Trie_Node pointers are redirected to shared nodes, giving us the DAWG.

```jai
minimization_registry : Table(string, *Trie_Node);
next_node_id : int = 0;

// A small wrapper so we can attach a numeric id to each canonical node.
node_id_map : Table(*Trie_Node, int);

assign_or_get_id :: (node: *Trie_Node) -> int {
    id_ptr := table_find_pointer(*node_id_map, node);
    if id_ptr return id_ptr.*;

    id := next_node_id;
    next_node_id += 1;
    table_set(*node_id_map, node, id);
    return id;
}

// Returns the canonical representative for `node` (may be a different pointer).
canonicalize :: (node: *Trie_Node) -> *Trie_Node {
    // Recurse into children first (bottom-up).
    for i : 0..25 {
        if node.children[i]
            node.children[i] = canonicalize(node.children[i]);
    }

    // Build signature from canonical children ids.
    builder : String_Builder;
    if node.is_terminal  append(*builder, "T");
    else                 append(*builder, "F");

    for i : 0..25 {
        child := node.children[i];
        if child {
            child_id := assign_or_get_id(child);
            print_to_builder(*builder, "|%:%", i, child_id);
        }
    }
    sig := builder_to_string(*builder);

    existing := table_find_pointer(*minimization_registry, sig);
    if existing {
        return existing.*;          // reuse the already-registered node
    }

    // First time we see this signature – register this node.
    table_set(*minimization_registry, sig, node);
    assign_or_get_id(node);         // ensure it has an id
    return node;
}
```

## Pack into flat edge array
Each edge is stored as one 32-bit word. All edges of a node occupy a contiguous sub-array; a node is referenced by the index of its *first* edge. The special node index 0 means "no children" (a node with no out-edges).

```jai
// Packed 32-bit edge word.
Edge :: u32;

make_edge :: (letter: int, child_first_edge: int, is_terminal: bool, is_last: bool) -> Edge {
    e : u32 = 0;
    e |= cast(u32)(letter          & 0x1F);        // bits 0-4
    e |= cast(u32)(child_first_edge & 0xFF_FF_FF) << 5; // bits 5-20
    if is_terminal  e |= (1 << 29);
    if is_last      e |= (1 << 30);
    return e;
}

edge_letter        :: (e: Edge) -> int  { return cast(int)(e        & 0x1F); }
edge_child         :: (e: Edge) -> int  { return cast(int)((e >> 5) & 0xFF_FF_FF); }
edge_is_terminal   :: (e: Edge) -> bool { return (e & (1 << 29)) != 0; }
edge_is_last       :: (e: Edge) -> bool { return (e & (1 << 30)) != 0; }

Packed_DAWG :: struct {
    edges : [..] Edge;
}

// Maps canonical Trie_Node pointer -> index of its first edge in the array.
node_to_first_edge : Table(*Trie_Node, int);

// We need to serialize nodes in a stable order, so we collect them first.
all_nodes : [..] *Trie_Node;

collect_nodes_dfs :: (node: *Trie_Node) {
    if table_find_pointer(*node_to_first_edge, node)  return;  // already visited

    // Reserve a slot (filled in during packing).
    table_set(*node_to_first_edge, node, -1);
    array_add(*all_nodes, node);

    for i : 0..25 {
        child := node.children[i];
        if child  collect_nodes_dfs(child);
    }
}

pack_dawg :: (root: *Trie_Node) -> Packed_DAWG {
    dawg : Packed_DAWG;

    // Index 0 is reserved: the null / leaf node (no out-edges).
    // We represent it as a single sentinel edge that is "last" with letter=0
    // and child=0.  Lookups that arrive here know there are no children.
    array_add(*dawg.edges, make_edge(0, 0, false, true));

    // DFS to collect all reachable canonical nodes.
    collect_nodes_dfs(root);

    // --- First pass: assign first-edge indices ---
    // We iterate all_nodes in order, laying out edges sequentially.
    // We need to know child first-edge indices, so we do two passes.

    // Compute layout offsets.  Start at 1 (slot 0 is the null sentinel).
    offset := 1;
    for node : all_nodes {
        table_set(*node_to_first_edge, node, offset);
        // Count how many children this node has.
        child_count := 0;
        for i : 0..25  if node.children[i]  child_count += 1;
        // Nodes with no children get first_edge = 0 (sentinel).
        if child_count == 0 {
            table_set(*node_to_first_edge, node, 0);
        } else {
            offset += child_count;
        }
    }

    // Resize the edge array to hold everything.
    array_resize(*dawg.edges, offset);

    // --- Second pass: write edge words ---
    for node : all_nodes {
        first := table_find_pointer(*node_to_first_edge, node);
        if !first || first.* == 0  continue;   // leaf node, no edges to write

        edge_idx := first.*;
        last_child_letter := -1;
        for i : 0..25  if node.children[i]  last_child_letter = i;

        for i : 0..25 {
            child := node.children[i];
            if !child  continue;

            child_first := table_find_pointer(*node_to_first_edge, child);
            child_edge_idx := ifx child_first then child_first.* else 0;

            is_last     := (i == last_child_letter);
            is_terminal := child.is_terminal;

            dawg.edges[edge_idx] = make_edge(i, child_edge_idx, is_terminal, is_last);
            edge_idx += 1;
        }
    }

    return dawg;
}
```

## DAWG Functions
`dawg_contains` checks whether a word is contained within a dawg. If this function returns `true`, the word is contained within the DAWG. If a word cannot be found, return false. `dawg_contains_prefix` checks whether a string is a part of a word. Unlike `dawg_contains`, `dawg_contains_prefix` does not require a complete word and will accept strings that are parts of words.

```jai
dawg_contains :: (dawg: Packed_DAWG, root_first_edge: int, word: string) -> bool {
    first_edge := root_first_edge;

    for char_idx : 0..word.count-1 {
        letter := word[char_idx] - #char "a";

        if first_edge == 0  return false;   // no children

        found := false;
        idx   := first_edge;
        while true {
            e := dawg.edges[idx];
            if edge_letter(e) == letter {
                // On the last character, check the terminal flag.
                if char_idx == word.count-1  return edge_is_terminal(e);

                first_edge = edge_child(e);
                found = true;
                break;
            }
            if edge_is_last(e)  break;
            idx += 1;
        }
        if !found  return false;
    }
    return false;
}

// Returns true if `prefix` is a prefix of any word stored in the DAWG.
// Unlike dawg_contains, it does not require the path to end on a terminal edge.
dawg_contains_prefix :: (dawg: Packed_DAWG, root_first_edge: int, prefix: string) -> bool {
    first_edge := root_first_edge;

    for char_idx : 0..prefix.count-1 {
        letter := prefix[char_idx] - #char "a";

        if first_edge == 0  return false;  // no children, prefix goes nowhere

        found := false;
        idx   := first_edge;
        while true {
            e := dawg.edges[idx];
            if edge_letter(e) == letter {
                // On the final character we only need the edge to exist,
                // not to be terminal — any continuation counts.
                if char_idx == prefix.count-1  return true;

                first_edge = edge_child(e);
                found = true;
                break;
            }
            if edge_is_last(e)  break;
            idx += 1;
        }
        if !found  return false;
    }

    // Empty prefix is trivially a prefix of every word.
    return true;
}
```

## DAWG Helper Functions

`print_dawg_stats` function track the memory footprint of the DAWG and the amount of memory saved by using this optimized data structure. The `get_words` function takes in a text file full of words separated by newlines, and transforms that into an array.

```jai
// ---------------------------------------------------------------------------
// Pretty-print helpers
// ---------------------------------------------------------------------------

print_dawg_stats :: (dawg: Packed_DAWG, node_count: int) {
    print("DAWG stats:\n");
    print("  Canonical nodes : %\n", node_count);
    print("  Edge array size : % edges\n", dawg.edges.count);
    print("  Memory (edges)  : % bytes\n", dawg.edges.count * size_of(Edge));
}

print_first_n_edges :: (dawg: Packed_DAWG, n: int) {
    limit := min(n, dawg.edges.count);
    print("First % edges:\n", limit);
    for i : 0..limit-1 {
        e := dawg.edges[i];
        letter_char := cast(u8)(edge_letter(e) + #char "a");
        print("  [%] letter='%'  child=%  terminal=%  last=%\n",
              i,
              formatChar(letter_char),
              edge_child(e),
              edge_is_terminal(e),
              edge_is_last(e));
    }
}

formatChar :: (c: u8) -> string {
    s : string;
    s.data  = *c;
    s.count = 1;
    return copy_string(s);
}

/*

'get_words' takes a text file and makes an array of words represented as strings.

aa
aah
aahed
aahing
...
zymurgies
zymurgy
zyzzyva
zyzzyvas
zzz
*/

get_words :: (filename: string) -> [] string {
    words, success := read_entire_file(filename);
    assert(success);
    return split(words, #char "\n");
}
```

## Setup and Example Usage

Here is a basic example where we:
* build the trie
* minimize the trie into a DAWG
* pack the output into a flat array
* test the functionality of the DAWG against words

```jai
// ---------------------------------------------------------------------------
// main – demonstrate with a small lexicon matching Figure 1 of the paper
// ---------------------------------------------------------------------------

main :: () {
    // Get words from a text file containing words
    words := get_words("dictionary.txt");

    // -----------------------------------------------------------------------
    // Phase 1: build the trie
    // -----------------------------------------------------------------------
    root := make_trie_node();
    for w : words  trie_insert(root, w);
    print("Trie built from % words.\n", words.count);
    print("Words: %\n", words);

    // -----------------------------------------------------------------------
    // Phase 2: minimize into DAWG
    // -----------------------------------------------------------------------
    init(*minimization_registry);
    init(*node_id_map);

    dawg_root := canonicalize(root);

    canonical_count := node_id_map.count;
    print("Minimization complete. Canonical nodes: %\n", canonical_count);

    // -----------------------------------------------------------------------
    // Phase 3: pack into flat edge array
    // -----------------------------------------------------------------------
    init(*node_to_first_edge);

    dawg := pack_dawg(dawg_root);

    // Get the first-edge index for the root so we can search.
    root_first_edge_ptr := table_find_pointer(*node_to_first_edge, dawg_root);
    root_first_edge := ifx root_first_edge_ptr then root_first_edge_ptr.* else 0;

    print_dawg_stats(dawg, canonical_count);
    print("\n");
    print_first_n_edges(dawg, 16);

    // -----------------------------------------------------------------------
    // Demonstrate lookup
    // -----------------------------------------------------------------------
    print("\n--- Lookup Strings Found ---\n");

    test_words := string.[
        "car", "cars", "cat", "cats",
        "do",  "dog",  "dogs", "done",
        "ear", "ears", "eat",  "eats",
        "qi",  "queen", "vav", "zebra",
    ];
    print("%\n", root_first_edge);
    for w : test_words {
        found := dawg_contains(dawg, root_first_edge, w);
        print("  \"%\" -> %\n", w, ifx found then "FOUND" else "not found");
        assert(found, "[%] not found in the dictionary", w);
    }

    // not found in the dictionary.
    test_not_in_dictionary := string.[
        "bereshit", "daniel", "coalexander", "banananananana", "newroiualsdkfj",
        "aaii", "joyjj", "abashest", "abbacyq", "xxxxxx", "norse",
        "qiqqq", "pelge", "miama", "sheoll", "yacobq"
    ];

    print("\n--- Lookup Strings NOT Found ---\n");
    for w : test_not_in_dictionary {
        found := dawg_contains(dawg, root_first_edge, w);
        print("  \"%\" -> %\n", w, ifx found then "FOUND" else "not found");
        assert(!found, "function incorrect, false positive on [%]", w);
    }

    print("DAWG tested thoroughly. DAWG initialization successful.\n");
}
```



