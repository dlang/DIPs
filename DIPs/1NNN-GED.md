# Deprecate Trailing Decimal Point

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Garrett D'Amore garrett@damore.org                              |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

This proposes to deprecate the floating point syntax
where a floating number may use a trailing decimal point
by itself.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
The syntax for floating points permits a trailing decimal point with no further
value afterwards, which complicates lexing and parsing D source code involving
these literals.

It also leads to potential ambiguity, such as in the following syntax:

  `z = x[123..y];`

This could be naively parsed as a range expression (from 123 to the value contained in y),
or as a reference to property y of the floating point literal 123.0.

The lexical grammar also has a special rule to insist that 1.f is not legal (or
rather it can only mean the f property of integer 1), but this requires special
handling in the grammar.

This ambiguity makes it much harder for naive tooling (such as regular expression
based syntax highlighters) to discriminate, and requires lexers to perform extra
lookahead and processing when encountering a bare decimal.  This adds a very small,
but non-zero, extra cost to processing D source code.

This is further complicated by the fact that whitespace in a property expression is legal.
For example, consider the following:

```d
auto a1 = 1 . sizeof; // legal, evaluates to sizeof int    
auto a2 = 1. sizeof;  // compilation error
auto a3 = 'c' . sizeof; // legal, evaluates to sizeof char 
auto a4 = 'c'. sizeof; // also legal, evaluates to sizeof char
```

This ambiguity makes writing tools harder, and makes it harder for humans to
understand the resulting code, while oferring no tangible benefit of its own.

As another tidbit of inconsistency, the syntax for hexadecimal floating points
does not permit a lone trailing decimal point.  Consider:

```d
    auto a1 = 1.; // legal same as 1.0f
    auto a2 = 0x1.0; // legal, also 1.0f
    auto a3 = 0x1.; // compilation error
```

The author of this DIP encountered these problems and had to write special
code to workaround them while creating a Tree-Sitter grammar for D. 
(That grammar can be found at https://github.com/gdamore/tree-sitter-d/ and
the workarounds for this problem are to be found in the `src/scanner.c` file
located therein.)

## Prior Work

N/A.

## Description

The current grammar for floating point decimal literals (2.13) is:

```
DecimalFloat:
    LeadingDecimal .
    LeadingDecimal . DecimalDigitsNoStartingUS
    LeadingDecimal . DecimalDigitsNoStartingUS DecimalExponent
    . DecimalDigitsNoStartingUS
    . DecimalDigitsNoStartingUS DecimalExponent
    LeadingDecimal DecimalExponent
```

This should be broken into two separate rules:

```
DecimalFloat:
    LeadingDecimal . DecimalDigitsNoStartingUS
    LeadingDecimal . DecimalDigitsNoStartingUS DecimalExponent
    . DecimalDigitsNoStartingUS
    . DecimalDigitsNoStartingUS DecimalExponent
    LeadingDecimal DecimalExponent
```  

and

```
DecimalFloatDeprecated:
    LeadingDecimal .
```

The `DecimalFloatDeprecated` rule should be linked to a deprecation warning
when it is encountered, and may at some point in the future ultimately be
removed. 

## Breaking Changes and Deprecations

As proposed above, we would mark the use of a trailing decimal for floating
points deprecated, and issue a warning.

The resolution for most users would simply be to add a zero after the
decimal point.  The deprecation warning could (should) suggest that.

As with all deprecations, making this enforced would be opt-in for the user,
at least until such time as it is actually removed.

## Reference

The author's Tree-Sitter Grammar for D is located at
https://github.com/gdamore/tree-sitter-d. 

## Copyright & License
Copyright (c) 2022 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
