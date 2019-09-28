# Dynamic-size static arrays for D
| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | James Lu (jamtlu@gmail.com)                                     |
| Status:         | Draft                                                           |
## Abstract
Often, it is necessary to allocate a data structure on the stack based on a
size known at runtime, and possibly return that data structure. This proposal
suggests adding dynamic-size static arrays to D. The goal here is an
easy-to-use dynamically sized array without a GC. It should give the programmer
the tools to avoid dynamic memory allocation.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
`@nogc` programming is useful in many contexts. For example, currently WASM
does not have a garbage collector, limiting D applications to `-betterC`
mode. 

It is often important to be able to quickly write `@nogc` code for
performance-critical paths. After identifying hot functions using a profile,
one should be able to alter a dynamic array that is only used within a single
function to be allocated and deallocated automatically with `@nogc`.

What is missing is an ergonomic way to dynamically allocate a static array on
the stack built-in to D. You can take slices of static array as parameters

```dlang
/** A well-known algorithm for finding the topological sorting of a (possibly
cyclic) directed graph. It deletes edges from its input as it runs, meaning
adjacency_list is modified from within the function body.

Because dynamic-size static arrays are value types, even when the function body
modifies adjacency_list, the caller does not see the modifications.
*/
@nogc auto kahnsAlgorithm(int[][?] adjacency_list);
```

## Prior Work
* `alloca`
* `malloc` and `scope(exit) free`
* Wait for D to support more C++ headers or use Calypso
* Just use C++ 
#### Use a dynamic array and copy the contents
#### Templated code
Make this legal:
```dlang
@nogc void example(N)(int[][N] adjacency_list) {
return N;
}
unittest {
int[][100] array;
assert(example(array) == 100);
}
```
Templated code is an alternative to having to hardcode the size into a function
while keeping it `@nogc`. However, this would not work for arrays whose maximum
size is unknown at runtime. 

#### Copy parameters
```dlang
@nogc auto bfs(copy int[][] adjacency_list);
```
*Background:* It is already legal to receive a dynamic array in `@nogc` code.

The `copy` parameter attribute creates a deep copy of the function parameter.
In this case, the parameter `adjacency_list` is a static array of dynamic
arrays. 

When passing in a copy parameter, a copy is created at the entrance to the
function body. Copy parameters are always implicitly `const copy`, since to the
external caller, the passed in parameter is never modified.

#### `scope T[]`
Compared to scoped dynamic arrays, dynamic-size static arrays can be passed in
by value. Unlike, dynamic-size static arrays, scoped dynamic arrays are
primarily useful for initializing a data store to be used within a single
function. 

## Description

<!-- rephrase: use the word "arguments" for inside the body, "parameters" for
outside it -->
<!-- Todo: add unit tests -->
<!-- Todo: write Kahn's Algorithm in D and showcase the various solutions -->

Like normal D static arrays, dynamic-size static arrays are pass-by-value: 

```dlang
@nogc void no_op(int[?] list) {
for (int i = 0; i < list.length; ++i) {
list[i] = 0;
}
}
unittest {
int[5] array = [1, 2, 3, 4, 5];
no_op(array);
assert(array == [1, 2, 3, 4, 5]);
}
```

A dynamic array can be implicitly converted to a dynamic-size static array as a
copy:

```
unittest {
int[] array = [1, 2, 3, 4, 5];
no_op(array);
assert(array == [1, 2, 3, 4, 5]);
int[?] another_array = array;
another_array[0] = 999;
assert(array[0] != 999);
}
unittest {
int[][] array = [[1, 2], [3, 4], [5, 6]];
int[?][?] secondarray = array;
}
```

Dynamic-size static arrays have a `.length` property. The `.length` property
may be changed arbitrarily, just like for a dynamic array. 

**Implementation Defined:** Enough space to hold the original length of the
array is allocated on the stack.

**Implementation Defined:** Shrinking a dynamic-size static array does not free
or deallocate the memory held by a dynamic-size static array.

**Implementation Defined:** Expanding a dynamic-sized array's `.length`
property beyond its *original length* may allocate memory on the heap. 

**Implementation Defined:** The compiler should avoid generating code for heap
allocation when it can prove that a particular statement will not change the
`.length` of the array beyond its original length. For example, `int[n] array;
for (int i = 0; i < n; ++i) { array[i] = rand(); }` should never generate code
that uses heap allocation. That's because the compiler can see that the array
is never accessed beyond its original size. Similarly for `int[n] array;
array.length = 0; while (array.length < n) { array ~= rand(); }`.

**Undefined behavior:** Accessing a dynamic-size static array by index beyond
its `.length`.


A declaration of the form `T[?] identifier;` has an *original length* of
zero. 

`int[expr] a;`

When `expr` is not always known at compile-time, declares a dynamic-size static
array. `expr` is the *original length* of the dynamic-size static array. 

```
unittest {
int[][] array = [[1, 2], [3, 4], [5, 6]];
int[?][?] secondarray = array;
}
```

Like static arrays, the memory of a dynamic-size static array is automatically
deallocated when exiting the scope where they were allocated. 

It is illegal to return a slice of a dynamic-size static array, because the
dynamic-size static array would be deallocated on function return. 

<!-- It is illegal to create a dynamic-size static array on the heap, for
example with the `new` keyword. -->

The `.length` property of a dynamic-size static array shall be taken into
consideration by `foreach` and `static foreach`.

If the `.length` property of a dynamic-sized static array is never set or read,
the  `.sizeof` is the size of each element multiplied by the *original length*
of the array. Otherwise, the `.sizeof` of the dynamic-size static array is the
size of each element multiplied by the *original length* of the array plus the
size of size_t.

Like dynamic arrays, dynamic-sized static arrays support the `~=` operator. `a
~= b` where a is a dynamic-sized static array is rewritten as `a[a.length++] =
b;`

## `-vdynamicalloc` flag 
### Motivation
This is slow:[^All quoted times are for N = 1000000.] (13ms)

```
std::vector vec;
for (int i = 0; i < N; ++i) {
vec.push_back(i)
}
```

This is also slow: (9ms)

```
std::vector vec;
vec.reserve(N);
for (int i = 0; i < N; ++i) {
vec.push_back(i)
}
```

This is fast: (4ms)

```
std::vector vec(N);
for (int i = 0; i < N; ++i) {
vec[i] = i;
}
```

Yet, C++ makes it hard to distinguish between the three cases. Adding a
`-vdynamicalloc` flag will help programmers avoid and identify locations where
memory is potentially being dynamically allocated during inner loops.

### Definition
`-vdynamicalloc` flags all heap allocation in `@nodynamic` functions:

* Expanding a dynamic-sized static array beyond its original length
* Calls to malloc and realloc (however, alloca is allowed)

`@nodynamic` implies `@nogc`.

### Alternative syntaxes
`void kahnsAlgorithm(int[][@] adjacency_list);`

`void kahnsAlgorithm(int[][!] adjacency_list);` Rejected because it looks like
a template instantiation when scanning.

`void kahnsAlgorithm(int[][%] adjacency_list);`

`void kahnsAlgorithm(int[][$] adjacency_list);`

`void kahnsAlgorithm(int[][*] adjacency_list);`

### Related issues
Associative arrays with @nogc are a related issue.
### Copyright & License

Copyright (c) 2019 by the D Language Foundation

Licensed under Creative Commons Zero 1.0

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
