# Add an `in` operator for arrays

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 1013                                                            |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Elijah Stone <elronnd@elronnd.net>                              |
| Implementation: | None yet (TODO)                                                 |
| Status:         | Draft  |

## Abstract

Asociative arrays and redblacktrees have an `in` operator which will check if a
variable is present within those data structures.  This operator is also
present in python for lists, with this syntax:

    lis = [1, 2, 3, 7]
    3 in lis # True
    4 in lis # False



### Reference

The `in` operator was [recently added](https://github.com/dlang/phobos/pull/5629) to `std.range.iota`, showing support for
useage of the operator in general.


## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Acknowledgements](#acknowledgements)
* [Reviews](#reviews)

## Rationale

Although the effects of the proposed `in` operator can be replicated using
[std.algorithm.searching.canFind](https://dlang.org/library/std/algorithm/searching/can_find.html), the process of importing and calling it is
cumbersome, and there is a language inconsistency in that AAs and redblacktrees
have an `in` operator but arrays do not.  Having a simple, quick way of
checking if an array contains an object in a way that is consistent with the
rest of the language should be essential.  In addition, the lack of such an
operator could be jarring to newcomers from such languages as python.  Previous
criticism of said operator has been that there should not be built-in language
features with worse than O(1) complexity, but AAs already have the `in` operator,
which provides worst-case O(log(n)) complexity; and, besides, people who
actually care about the complexity of their code will know not to use the `in`
operator, and those who want operators of higher complexity will have an easier
time using them.


## Description

The `in` operator for arrays will take a needle, of type `T`, and a haystack,
of type `T[]`.  If any of the elements of the haystack are equal to the needle,
then it will return true.  Otherwise, it will return false.  No new grammar
changes will be made

Simple example:

    import std.algorithm.iteration: canFind;
    string tmp;
    auto legalgreetings = ["hello", "hi", "hey"];

    do {
        tmp = stdin.read();
    } while (!(legalgreetings.canFind(tmp.lower)));

Can be replaced with the following which, while similar, is significantly more
readable.  This is because it represents a very different idea which is much
closer to the actual intent of the code:

    string tmp;
    auto legalgreetings = ["hello", "hi", "hey"];

    do {
        tmp = stdin.read();
    } while (tmp.lower !in legalgreetings);


## Breaking Changes and Deprecations

The overload of canFind that takes a Range and an Element should be deprecated
in favour of the `in` operator.  Other overloads of `canFind` should be
preserved as they do not fit into the scope of an `in` operator.


## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
