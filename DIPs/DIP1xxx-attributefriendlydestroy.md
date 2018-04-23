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
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Acknowledgements](#acknowledgements)
* [Reviews](#reviews)

## Rationale

*TODO

## List of possible solutions with descriptions with the possibility of breaking changes and Deprecations

*TODO

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
