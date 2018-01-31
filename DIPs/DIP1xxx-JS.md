# The Deprecation Process

| Field | Value |
|-----------------|-----------------------------------------------------------------|
| DIP:            | xxxx |
| Review Count:   | 0 |
| Author:         | Jack Stouffer |
| Implementation: | N/A |
| Status:         | Draft |

## Abstract

In order to incrementally improve D or it's standard library, it's often necessary to
mark features or functions for future removal. This document proposes a standardized
process for language maintainers to remove public features. This process would be 
used across DMD, Druntime, and Phobos.

## Rationale

There is general disagreement on the best and/or accepted way to remove public
features. Each deprecation ends being handled slightly differently depending on
who's handling the pull requests. Standardizing the process makes sure that
deprecations are done very publicly and carefully, as to minimize breakage and
to provide clear fixes for user code.

## Description

The following lays out the rules to follow to deprecate a part of D.

A symbol or feature must not be marked for removal on a specific date, but rather on a
specific release. This allows users to easily know if upgrading will break their
code or not.

Both at the time of deprecation and removal, a changelog entry must be made.

### Public Functions, Types, and Modules

The symbol(s) must be marked using the `deprecated` keyword with a message containing
the planned removal period and/or a pointer to more information pertaining to the
deprecation. The documentation of the symbol(s) must be updated noting the
deprecation and removal plan. The documentation should contain information to help
the users using the symbol(s) transition their code away from the symbol(s).

Users must be given at least four major releases before the deprecated symbols
are removed. More releases should be given if the removed code is commonly used.

On the third release, the documentation for the symbol should be removed while
keeping it public.

If there is no equivalent for the functionality of the removed symbol in the
standard library or the runtime, the code should be moved to
[undeaD](https://github.com/dlang/undeaD) to allow users to keep their current
code if refactoring is not possible.

### Language Features

If the language feature is determined to be common, a command line flag should
be added in the form of `-transition=[name]` which gives the deprecation message
in advance of yielding a deprecation message by default. If this approach is used,
users must be given at least two major releases before not using the flag gives
deprecation messages. The transition flag would then have no effect, and turn
into an error when the deprecated feature is finally removed.

Users must be given at least four major releases before the deprecated features
are removed. More releases should be given if the removed code is commonly used.

Warnings should NOT be used in the deprecation process. Warnings are set as errors
in many build systems (including DUB), and would therefore prematurely break many
user's code.

## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
