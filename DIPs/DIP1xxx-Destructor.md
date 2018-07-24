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

The current “official” way of calling the D class deconstrutor is to call the destroy function.
However, the destroy function cannot be called in the context of system default attributes (such as @safe or @nogc) regardless of the class attributes, thus severely restrict the usage of classes without resorting to workarounds/hack
such as calling the hidden symbol .__dtor directly. This limitation hinders the development of custom deallocation functions that have classes involved.
A reasonable solution to this is to have the programmer opt-in the static type checking for the given class. The reason for the opt-in is to avoid code breakage, and to avoided unneeded static checking in cases where it is not suitable or needed. No need for static checking for @nogc in a non-@nogc context for example. The static checking will be determined by a constant string that contain the names of the attributes.

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
 Destructor_hook function behaves similarly to the destroy function, only it calls functions that are marked with the given attribute.
 The reason for this function is for situations where you don't have source code access to the API that your class is inherent from, and you know that not calling them won't causes any issues for your 
 program.
### Reference

The bug in question.
https://issues.dlang.org/show_bug.cgi?id=15246

Example of workarounds/hack
* https://github.com/atilaneves/automem/blob/master/source/automem/utils.d
* https://www.auburnsounds.com/blog/2016-11-10_Running-D-without-its-runtime.html

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
