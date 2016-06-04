# Add @nogc Function Attribute

| Section         | Value                  |
|-----------------|------------------------|
| DIP:            | 60                     |
| Version:        | 1.2                    |
| Status:         | Implemented            |
| Author:         | Walter Bright          |
| Implementation: | <https://github.com/D-Programming-Language/dmd/pull/3455> |
|                 | <https://github.com/D-Programming-Language/dmd/pull/3490> |

## Abstract

The @nogc function attribute will mark a function as not making any allocations using the GC.

### Links

* [forum discussion](http://forum.dlang.org/post/lijoli$2jma$1@digitalmars.com)

## Description

@nogc goes in the same way that the nothrow attribute does, and is quite
similar in behavior. It affects inheritance in that it is covariant. The name
mangling for it will be "Ni". @nogc will be inferred for template functions in
the same manner as nothrow is. @nogc will be transitive, in that all functions
called by an @nogc function must also be @nogc. GC allocations in a @nogc
function will be disallowed, and that means calls to operator new, closures
that allocate on the GC, array concatenation, array appends, and some array
literals.

No functions in the GC implementation will be marked @nogc.

### Rationale

Many users want to be able to guarantee that code will not allocate using the GC.

### Examples

``` D
@nogc int func(int a) { ... }
```

#### Static allocations should be ignored

This code (and its mutable \_\_gshared variants) should work since the beginning:

``` D
void foo() @nogc nothrow {
    static const err = new Error("error");
    throw err;
}
```

The situation is similar to this code, that is allowed (text is not nothrow,
but here it's called at compile-time):

``` D
void foo() nothrow
{
    import std.conv;
    enum msg = text(10);
}
```

#### Behaviour in presence of optimizations

Using Escape Analysis the LDC2 compiler is able to remove the heap allocation
from this main function when full optimizations are used. However, validity of
code should not be affected by optimization settings. (Nor can it be, without
intertwining the compiler front-end with each back-end in rather complicated
ways.) Hence the following main function cannot be annotated with @nogc even
when Escape Analysis removes the heap allocation:

``` D
__gshared int x = 5;
int main()
{
    int[] a = [x, x + 10, x * x];
    return a[0] + a[1] + a[2];
}
```

In a successive development phase of @nogc we can perhaps relax some of its
strictness introducing some standard (required by all conformant D compilers
and performed at all optimization levels) common cases of escape analysis, that
allow to use @nogc annotations in more cases, perhaps also like the one above.
One possible disadvantage of this idea is that such escape analysis could slow
down a little all D compilations, even the fastest debug builds.

## Copyright & License

Copyright (c) 2016 by the D Language Foundation
Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
