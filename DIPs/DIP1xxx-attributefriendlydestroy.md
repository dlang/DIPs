# destroy should be attribute friendly for classes.

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Alexander Heistermann (alexanderheisterman@gmail.com)           |
| Implementation: | None                                                            |
| Status:         | Draft                                                           |

## Abstract

The current “official” way of calling the D class deconstrutor is to call the destroy function. However the destroy function cannot be called in the context of system default attributes (such as @safe or @nogc) irregardless of the class attributes, thus severely restrict the usage of classes without resorting to workarounds/hack such as calling the hidden symbol .__dtor directly
### Reference

The bug in question.
https://issues.dlang.org/show_bug.cgi?id=15246

Examples of workarounds/hack
https://github.com/atilaneves/automem/blob/master/source/automem/utils.d

## Contents
* [Description](#description)
* [List of possible solutions] (#solutions)
* [Reviews](#reviews)

## List of possible solutions

-Separate the destructor and finalizer
Pros:
Destructor for deterministic memory, finalizer for non-deterministic memory.
Cons:
May introduce breaking changes

-Make the destructor an actual virtual function like c++ destructor
Pros: Years of experiences regrading usage of c++ destructor
Cons: Will introduce breaking changes

-Extend the functionality of destroy by only calling symobls that is marked with a given attribute.(Example: destroy(@safe))
Pros: No breaking changes
Cons: Possibility that an object may not have all its destructors called. 
## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
