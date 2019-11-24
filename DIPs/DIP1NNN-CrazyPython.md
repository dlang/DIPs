# Dynamic-size static arrays for D
| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | James Lu (jamtlu@gmail.com)                                     |
| Status:         | Draft                                                           |

## Abstract
Often, it is necessary to allocate a data structure on the stack based on a
size known at runtime. This proposal suggests adding dynamic-size static arrays,
which are destroyed when they go out of scope. Dynamic-size static arrays and
slices of them may be passed up the stack. The syntax is designed to encourage
function signatures to use slices as much as possible, in contrast to the C
convention of passing an array length and then a VLA. The overall goal is to
help evolve D into a fewer-GC language.

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
An array declared with the form:
```
int[expr] array;
```
where `expr` uses information not available to CTFE, creates a dynamic-size
static array.

Dynamic-size static arrays may be freely shrunk and expanded. They own the data
they refer to. When a dynamic-size static array goes out of scope, the destructor
is automatically called. It is safe to pass a dynamic-size static array up the
stack. Like static arrays, dynamic-size static arrays may be implicitly cast to
slices.

Dynamic-size static arrays may not be declared as function parameters. To
interface with C code, pass a pointer instead. To declare a function that uses
arrays of variable size, declare the parameter as a slice. Dynamic-size static
arrays have a `.ptr` property just like other array types do.

The implementation may allocate more space for the static array than `expr` to
achieve a better stack layout. Thus, the `.capacity` of a dynamic-size static
array is implementation defined.

The `.sizeof` of a dynamic-size static array is implementation-defined. Use 
`.length` and `typeof(arr[0]).sizeof` appropriately to calculate the desired 
information instead.

## Breaking Changes and Deprecations

It is now undefined behavior to access a slice beyond its `.length`, regardless 
of whether or not there is data beyond that point. In other words, if you pass 
a function a slice of length X that was created from a dynamic-size static
array of length X+1, and that function tries to access that index X, it is UB. 

```
int fun(int[] arr) {
    // always triggers UB
    return arr[$ + 1];
}
int a(int n) {
    int a[n];
    fun(a[0 .. $-1]);
}
```

<!-- DISCUSS: Should you be allowed to cast a slice to a larger length in
@safe code? If it *is* allowed, casts will force an optimizing compiler to
add extra tag-along data indicating the original length of the array. -->

This applies to all slices and is a breaking change.

This new case of undefined behavior will be hidden behind a DIP flag, of the
form `-dipNNNN`. When a range error is thrown, the runtime will attempt to
check if the memory access would have been valid if the slice were longer.
If that is determined to be true or possibly true, the runtime will print
out a deprecation message along the lines of "Warning: Slice access beyond
original dynamic array is undefined behavior in DIPNNNN. See https://<...>
for more information."

Eventually, when adoption is high, the DIP flag and the deprecation message
will themselves become deprecated, the DIP will become the default behavior,
the flag itself becoming a no-op.

<!-- I am not sure if this is already considered UB under the spec; section
12.14.4 is unclear about if it is. -->

### Related issues
Associative arrays with `@nogc` (and possibly `scope`) are a related issue.

### Copyright & License

Copyright (c) 2019 by the D Language Foundation

Licensed under Creative Commons Zero 1.0

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
