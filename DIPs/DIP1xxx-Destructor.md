# Destructor Tools

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Alexander Heistermann (alexanderheisterman@gmail.com)           |
| Implementation: | None                                                            |
| Status:         | Draft                                                           |

## Abstract
Opt-in static checking for destroy function and weaker destroy function named destructor_hook for classes.

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Reviews](#reviews)


## Rational 

The current “official” way of calling the D class deconstrutor is to call the `destroy()` function.
However, the `destroy()` function cannot be called in the context of system default attributes (such as `@safe` or `@nogc`) regardless of the class attributes.
The reason for this promblem is the current implementation of `destroy()`:

```d
    void destroy(T)(T obj) if (is(T == class))
    {
        static if(__traits(getLinkage, T) == "C++")
        {
            obj.__xdtor();

            enum classSize = __traits(classInstanceSize, T);
            (cast(void*)obj)[0 .. classSize] = typeid(T).initializer[];
        }
        else
            rt_finalize(cast(void*)obj);
    }
```
The class object `obj` is being cast into a void type which causes the lost of type information that can be used for type checking for system default attributes to see if it is ok for `rt_finalize()` to be called in any of the system default attributes marked functions.
This severely restrict the usage of classes without resorting to workarounds/hack such as calling the hidden symbol `.__dtor` directly. This limitation hinders the development of custom deallocation functions that have classes involved.
A reasonable solution to this is to have the programmer opt-in the static type checking for the given class. The reason for the opt-in is to avoid code breakage, and to avoid unneeded static checking in cases where it is not suitable or needed. No need for static checking for `@nogc` in a non-`@nogc` context for example. The other reason for this is to give meaningful compiler errors if the static checking had failed. If the static type checking is done automatically and the programmer did something unintentional to cause the `destory` function to lose one of the attributes, it can be very potentially difficult for the programmer to find the source of the compile error. Having the `destroy` function automaticly generating compile messages for failed static checking isn't very helpful as it can clutter up the compiler output window    The static checking will be determined by a constant string that contain the names of the attributes. The reason for this is readability and clarification  

## Description
```d
@nogc fun(C c)
{
  destroy(c, "@nogc"); // Static type checking C for @nogc attributes
}
```
There are 3 phases of the static checking:
* Checks the destructors of parents that the current class have inheranted
* Checks the destructors of existing child classes that inherent the current class
* Checks the member variables of the current class for class/struct types and static type check them dynamically to avoid infinite recursion.

 `Destructor_hook()` function behaves similarly to the destroy function, only it calls functions that are marked with the given attribute.
 The reason for this function is for situations where you don't have source code access to the API that your class is inherent from, and you know that not calling them won't causes any issues for your 
 program. A prime example of this is external c++ classes with empty destructors
## Reference

The bug in question.
https://issues.dlang.org/show_bug.cgi?id=15246

Example of workarounds/hack
* https://github.com/atilaneves/automem/blob/master/source/automem/utils.d
* https://www.auburnsounds.com/blog/2016-11-10_Running-D-without-its-runtime.html
* https://p0nce.github.io/d-idioms/#Bypassing-@nogc

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
