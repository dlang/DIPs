# String Interpolation

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Jason Hansen, Jonathan Marler                                   |
| Implementation: | https://git.io/fpSUA                                            |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

This DIP proposes adding a "tuple/sequence literal" to D, which opens up tons up possibities, including string interpolation.

### Reference

- https://forum.dlang.org/thread/khcmbtzhoouszkheqaob@forum.dlang.org
- https://forum.dlang.org/thread/c2q7dt$67t$1@digitaldaemon.com
- https://forum.dlang.org/thread/qpuxtedsiowayrhgyell@forum.dlang.org
- https://forum.dlang.org/thread/ncwpezwlgeajdrigegee@forum.dlang.org
- https://dlang.typeform.com/report/H1GTak/PY9NhHkcBFG0t6ig (#3 in "What language features do you miss?")
- Exploration: https://github.com/marler8997/interpolated_strings
- Example Library Solution: https://github.com/dlang/phobos/pull/6339/files
- Implementation: https://github.com/dlang/dmd/pull/7988

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

(we should find some examples in the phobos or dmd source that would benefit a lot from SI and put them here)

A short motivation about the importance and benefits of the proposed change.  An existing,
well-known issue or a use case for an existing projects can greatly increase the
chances of the DIP being understood and carefully evaluated.

## Description

Lexer Change:

Current:

```
Token:
   ...
   StringLiteral
   ...
```
New:

```
Token:
   ...
   StringLiteral
   i StringLiteral
   ...
```

No change to grammar. Implementation consists of a small change to `lex.d` to detect when string literals are prefixed with the `i` character.  It adds a boolean flag to string literals to keep track of which ones are "interpolated".  Then in the parse stage, if a string literal is marked as "interpolated" then it lowers it to a tuple of strings and expressions.

Implementation and tests can be found here: https://github.com/dlang/dmd/pull/7988/files


## Breaking Changes and Deprecations
None. :)

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
