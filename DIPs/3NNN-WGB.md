# Dynamic Arrays Only Shrink, Never Grow

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Walter Bright walter@digitalmars.com                            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |


## Abstract

Disable growing the length of a dynamic array (aka slice), either via the `~=` operator
or by setting the `.length` property. Slices can be shrunk, but
not enlarged.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)


## Rationale

Enlarging a slice using the `~=` operator or by setting the length uses
the garbage collector to do it, fostering the incorrect notion that D slices
require the GC. Worse, if the slice is not on the heap already, and is managed
explicitly, growing it via the append operator or the length puts it onto the
heap, thereby greatly complicating any other memory management technique.
There is no way to detect or prevent the user of a slice from doing this.


Problematic uses:
```
int[] slice = cast(int*)malloc(10 * int.sizeof)[0 .. 10];
slice ~= 1;
free(slice.ptr); // Oops!
```

```
enum { dead, alive }
int[] cat = new int[6];
cat[5] = alive;
int[] b = cat;
b ~= 1;      // may or may not move b to new location
b[5] = dead; // indeterminate whether cat[5] is dead or alive
```


By restricting changing the size to shrinking it only, these problems are avoided.
Coming with it is the notion that slices do not manage their own memory -
the memory is managed by the memory object that the slice was carved from.

This change is a necessary part of D evolving towards being memory safe without using
a GC.


## Prior Work

Don't know of any slices in other languages that don't also carry a .capacity
property to keep track of how much the slice can grow before it must be reallocated.

Rust's notion of pointers owning the memory they point to, unless the pointer is
borrowed, fits in with this DIP's notion of a slice "borrowing" a reference to
another object which manages the memory.


## Description

Using the `~=` operator with a slice as the lvalue will no longer be allowed.
Setting the .length property can only be used to shrink a slice.

Slices can still be allocated by operator new, or sliced out of existing
arrays. Building a dynamic array by appending can be performed using
[std.array.appender](https://dlang.org/phobos/std_array.html#appender).


### Grammar Changes

None.


## Breaking Changes and Deprecations

Any use of `~=` or `.length` which tries to grow the slice will fail, the former
at compile time and the latter at runtime (as a dynamic check is necessary).
Hence, a long deprecation period will be necessary.
The switch used to initially enable the new behavior will be `-preview=nogrowslice`

A workaround for deprecating:

```
a ~= b;
```
is to use:
```
a = a ~ b;
```
although that will generate more GC garbage if used in a loop.

## Reference

[D Dynamic Arrays](https://dlang.org/spec/arrays.html#dynamic-arrays]


## Copyright & License

Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
