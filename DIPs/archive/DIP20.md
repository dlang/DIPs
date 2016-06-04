# Volatile read/write intrinsics

| Sectin         | Value                                                         |
|----------------|---------------------------------------------------------------|
| DIP:           | 20                                                            |
| Status:        | Implemented                                                   |
| Author:        | Alex Rønne Petersen (alex (AT) lycus.org)                     |
| Implementation:| <https://github.com/D-Programming-Language/druntime/pull/892> |

## Abstract

This document describes a couple of simple compiler intrinsics that D compilers
should implement. These are necessary for low-level, embedded, kernel, and
driver developers. These intrinsics will ensure that a compiler cannot reorder
volatile loads and stores with regards to each other.

### Links

* <https://issues.dlang.org/show_bug.cgi?id=13138>

## Description

Two intrinsics shall be declared in the core.bitop module.

The first one, volatileLoad is used to perform volatile read operations from memory:

``` D
T volatileLoad(T)(T* ptr);
```

A call to this function, such as:

``` D
T* p = ...;
T i = volatileLoad(p);
```

Shall be equivalent to:

``` D
T* p = ...;
T i = *p;
```

However, with the exception that the compiler is not allowed to optimize out
seemingly dead calls to volatileLoad, nor reorder calls to volatileLoad with
respect to other calls to it or volatileStore. The second, volatileStore is
used to perform volatile write operations to memory:

``` D
void volatileStore(T)(T* ptr, T val);
```

A call to this function, such as:

``` D
T* p = ...;
T i = ...;
volatileStore(p, i);
```

Shall be equivalent to:

``` D
T* p = ...;
T i = ...;
*p = i;
```

However, with the exception that the compiler is not allowed to optimize out
seemingly dead calls to volatileStore, nor reorder calls to volatileStore with
respect to other calls to it or volatileLoad.

### Detection

Compilers that support these intrinsics should define the D\_Volatile version
identifier. Compilers are free to support the intrinsics without defining this
version identifier, but programmers should not rely on the presence of the
intrinsics if it is not defined.

### Rationale

D currently has no way to do safe memory-mapped I/O. The reason for that is
that the language has no well-defined means to do volatile memory loads and
stores. This means that a compiler is free to reorder memory operations as it
sees fit and even erase some loads/stores that it thinks are dead (but which
have actual impact on program semantics).

These intrinsics will be essential for low-level development in D. D cannot
truly replace C and/or C++ until it can perform the same low-level operations
that developers who use those languages are accustomed to.

### Implementation

#### DMD

DMD does not currently reorder loads and stores, so no particular change needs
to happen in this area of the compiler. However, it is quite likely that the
back end eliminates dead loads and stores, so calls to the intrinsics must be
flagged as volatile in whatever way DMD's back end allows it.

#### GDC

GCC's internal code representation allows volatile statements in the C sense,
which is sufficient.

#### LDC

[LLVM trivially allows marking loads and stores as volatile](http://llvm.org/docs/LangRef.html#volatile)

#### Other compilers

Other compilers presumably have similar means to flag loads and stores as volatile.

### Alternatives

A number of alternatives to volatile intrinsics have been suggested. They are,
however, not good enough to actually replace a volatile intrinsics for the
reasons outlined below.

#### Shared qualifier

The shared type qualifier has been suggested as a solution to the problems
volatile intrinsics try to solve. However:

- It is not implemented in any compiler, so practically using it now is not
  possible at all.
- It does not have any well-defined semantics yet.
- It will most likely not be portable because it's designed for the x86
  memory model.
- If ever implemented, it will result in memory fences and/or atomic
  operations, which is \*\*not\*\* what volatile memory operations \* are
  about. This will severely affect pipelining and performance in general.

#### Inline assembly

It was suggested to use inline assembly to perform volatile memory operations. While a correct solution, it is not reasonable:

- It leads to unportable programs.
- It leads to a dependency on the compiler's inline assembly syntax.
- Some compilers may even decide to optimize the assembly itself.
- Memory-mapped I/O is too common in low-level programming for a systems
  language to require the programmer to drop to assembly.

## Copyright & License

Copyright (c) 2016 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
