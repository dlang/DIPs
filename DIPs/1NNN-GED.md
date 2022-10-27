# Remove Support for Small Octals

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Garrett D'Amore garrett@damore.org                              |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

We propose to remove support for octal integer literals less than 8.
Support for octal literals 8 or larger has already been removed.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

It is perverse, and surprising, that octal values less than 8 are supported,
while those that are larger than 8 are not.  The rationale for this is likely
that there is no risk of confusion, since 07 and 7 are the same value.

However, supporting octal constants of such a limited range (1 through 7) brings
very little value, since the most common contemporary use of octals is for
file permissions on POSIX systems (e.g. 0644).

Expressing these constants in decimal is actually more compact (1 character
instead of 2).

Additionally support for only this limited range violates the principal of
least surprise.

It also requires explicit handling during the lex phase, to properly sort out,
creating a very small bit of additional complexity with no tangible value.

The formal grammar specification at https://dlang.org/spec/lex.html#integerliteral
does not have any provision to allow for octal constants of any kind, but
rather explicitly prohibits them with a rationale:

> C-style octal integer notation was deemed too easy to mix up with decimal notation;
> it is only fully supported in string literals. D still supports octal integer literals
> interpreted at compile time through the std.conv.octal template, as in octal!167.

(This DIP is not intended to change the handling of octal character constants nor
of `std.conv.octal`.)

Thus, this proposal intends to harmonize the behavior of DMD with the specified
grammar.

The author has a Tree-Sitter grammar for D at https://github.com/gdamore/tree-sitter-d,
which was written following the online specification, and that grammar therefore does
not include support for tiny octal constants.  The author would like to avoid adding
support for them, since they aren't part of the official grammar.

## Prior Work

D has already removed support for ordinary octal constants larger than 7,
but a solution for users who need it using `std.conv.octal` is provided
for the rare use cases where an octal value will be more readable.

(In the author's 30 year career doing systems level work, the only cases
where octals have been useful has been for the aforementioned file permissions.)

## Description

The parsing of a value like '03' should be treated in the same way as a literal
like '033'.

There are no grammar changes required, but the DMD compiler behavior should
be changed to match the specified grammar.

## Breaking Changes and Deprecations

This is of course a breaking change, although it's hard to imagine (for the
author of this DIP at least) an actual use of tiny octal values in the field.

Support for handling these can permitted through a deprecation period
with an associated compiler switch.

## Reference

https://dlang.org/spec/lex.html#integerliteral

## Copyright & License
Copyright (c) 2022 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
