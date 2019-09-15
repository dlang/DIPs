# Deprecate Brace-Style Struct Initializers

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Walter Bright walter@digitalmars.com                            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

With the adoption of named argument lists, the brace-style struct initializer
syntax is redundant with that of function-style struct literals. Removing
the brace-style will reduce the complexity of the language.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Having two equivalent ways to do the same thing is a pointless redundancy in a language.
Even worse, it engenders bikeshedding debates about which is "better". It's better
to have one way of doing things, which reduces the complexity of the compiler, the specification,
and efforts to teach the language.

## Prior Work

This DIP presumes the acceptance of [DIP: Named Arguments](https://github.com/dlang/DIPs/pull/168).

## Description

Deprecate support for the brace-style struct initializer syntax.

### Grammar

The syntax for [StructInitializer](https://dlang.org/spec/declaration.html#StructInitializer)
will be deprecated and eventually removed.

## Breaking Changes and Deprecations

Suggest users replace:

```
struct S { int a, b; }

S s = { 1, 2 }; // Deprecated: use S(1, 2) instead
```

## Reference

1. [StructInitializer](https://dlang.org/spec/declaration.html#StructInitializer)
2. [DIP: Named Arguments](https://github.com/dlang/DIPs/pull/168)

## Copyright & License
Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
