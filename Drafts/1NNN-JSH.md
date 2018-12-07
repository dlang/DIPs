# String Interpolation

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Jason Hansen                                                    |
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

Required.

Detailed technical description of the new semantics. Language grammar changes
(per https://dlang.org/spec/grammar.html) needed to support the new syntax
(or change) must be mentioned. Examples demonstrating the new semantics will
strengthen the proposal and should be considered mandatory.

## Breaking Changes and Deprecations
None. :)

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
