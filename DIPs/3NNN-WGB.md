# Dynamic Arrays Only Shrink, Never Grow

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Walter Bright walter@digitalmars.com                            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |


## Abstract

Disable growing the length of a dynamic array (a.k.a. a slice) via the append operator (`~=`)
and by setting the `.length` property. Slices can be shrunk, but never enlarged.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)


## Rationale

Enlarging a slice, using the append operator or by setting the `.length` property,
makes use of the garbage collector. This fosters the incorrect notion that D slices
_require_ the GC. Worse, if the slice is not on the GC heap already, and is managed
explicitly, growing it via the append operator or `.length` puts it onto the
GC heap, thereby complicating any other memory management technique.
There is no way to detect if such has occurred or to prevent the user of a slice
from doing it.


Problematic uses:
```d
int[] slice = cast(int*)malloc(10 * int.sizeof)[0 .. 10];
slice ~= 1;
free(slice.ptr); // Oops!
```

```d
enum { dead, alive }
int[] cat = new int[6];
cat[5] = alive;
int[] b = cat;
b ~= 1;      // may or may not move b to new location
b[5] = dead; // indeterminate whether cat[5] is dead or alive
```

Prohibiting size changes from growing a slice will avoid these problems.
This approach also fosters the notion that slices do not manage their own
memory; it is instead managed by the memory object from which the slice was taken.

This change is a necessary part of evolving D toward being memory safe without using
a GC.


## Prior Work

The author is unaware of any slices in other languages that don't also carry a `.capacity`
property to keep track of how much the slice can grow before it must be reallocated.

Rust's notion of pointers owning the memory they point to, unless the pointer is
borrowed, is equivalent with this DIP's notion of a slice "borrowing" a reference to
another object which manages the memory.


## Description

Using the append operator with a slice as the lvalue will no longer be allowed.
Setting the `.length` property can only be used to shrink a slice.

Slices can still be allocated by operator `new` or sliced out of existing
arrays. [std.array.appender](https://dlang.org/phobos/std_array.html#appender)
can be used instead of the append operator to build dynamic arrays by appending elements.


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
is to use `std.array.appender` or array concatenation:
```d
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
